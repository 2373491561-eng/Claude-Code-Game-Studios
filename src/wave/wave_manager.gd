class_name WaveManager
extends Node

# ---------------------------------------------------------------------------
# Constants -- wave progression table
# ---------------------------------------------------------------------------

## Wave progression: maps wave number to enemy counts {small, medium, large, total}.
## Wave 1: 8s, 0m, 0L = 8 total
## Wave 2: 12s, 0m, 0L = 12 total
## Wave 3: 15s, 2m, 0L = 17 total
## Wave 4: 20s, 3m, 0L = 23 total
## Wave 5: 25s, 5m, 1L = 31 total
## Wave 6-7: 30s, 6m, 1L = 37 total
## Wave 8-10: 35s, 8m, 2L = 45 total
## Wave 11+: 40s, 10m, 3L = 53 total
const WAVE_TABLE: Array[Dictionary] = [
	{"small": 8,  "medium": 0,  "large": 0,  "total": 8},
	{"small": 12, "medium": 0,  "large": 0,  "total": 12},
	{"small": 15, "medium": 2,  "large": 0,  "total": 17},
	{"small": 20, "medium": 3,  "large": 0,  "total": 23},
	{"small": 25, "medium": 5,  "large": 1,  "total": 31},
	{"small": 30, "medium": 6,  "large": 1,  "total": 37},
	{"small": 30, "medium": 6,  "large": 1,  "total": 37},
	{"small": 35, "medium": 8,  "large": 2,  "total": 45},
	{"small": 35, "medium": 8,  "large": 2,  "total": 45},
	{"small": 35, "medium": 8,  "large": 2,  "total": 45},
]

## Waves 11+ use this template.
const WAVE_11_PLUS: Dictionary = {"small": 40, "medium": 10, "large": 3, "total": 53}

## Delay in seconds before the first wave begins after scene load.
const FIRST_WAVE_DELAY_S: float = 1.0

## Delay in seconds after wave clear before the next wave can begin (transition window).
const WAVE_TRANSITION_DELAY_S: float = 1.5

## Time in seconds for the vignette to deepen during wave transition.
const VIGNETTE_TRANSITION_S: float = 0.6

# ---------------------------------------------------------------------------
# Exported references
# ---------------------------------------------------------------------------

## Reference to the EnemyManager node (owned by game.tscn).
@export var enemy_manager: Node = null

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

## Current wave number (1-indexed). 0 means no wave has started yet.
var _current_wave: int = 0

## Number of enemies remaining in the current wave.
## This is the total spawned minus the count killed. When it reaches 0,
## the wave is considered cleared.
var _enemies_remaining: int = 0

## True when the wave has been cleared and we are in the transition window.
var _wave_cleared: bool = false

## True while the first wave delay timer is active.
var _first_wave_pending: bool = false

## Timestamp when the first wave delay began.
var _first_wave_delay_start_ms: int = 0

## Timestamp when the wave was cleared (for transition delay).
var _wave_clear_time_ms: int = 0

## True when a wave is currently active (enemies spawned and not all dead).
var _wave_active: bool = false

## Track how many enemy_killed signals we've received this wave.
## This is a secondary counter used as a sanity check.
var _killed_this_wave: int = 0

## True when transitioning between waves (vignette deepen period).
var _in_transition: bool = false

## Timestamp when the transition began.
var _transition_start_ms: int = 0

## True when waiting for build selection to complete before starting next wave.
var _waiting_for_build: bool = false

# ---------------------------------------------------------------------------
# Node lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Start the first wave delay timer.
	_first_wave_pending = true
	_first_wave_delay_start_ms = Time.get_ticks_msec()

	# Connect to enemy_killed signal for wave clear detection.
	var eb := get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("enemy_killed"):
		if not eb.enemy_killed.is_connected(_on_enemy_killed):
			eb.enemy_killed.connect(_on_enemy_killed)

	if eb and eb.has_signal("upgrade_selected"):
		if not eb.upgrade_selected.is_connected(_on_upgrade_selected):
			eb.upgrade_selected.connect(_on_upgrade_selected)

func _physics_process(_delta: float) -> void:
	# Handle first wave delay.
	if _first_wave_pending:
		var elapsed := Time.get_ticks_msec() - _first_wave_delay_start_ms
		if elapsed >= FIRST_WAVE_DELAY_S * 1000.0:
			_first_wave_pending = false
			_start_wave(1)
		return

	# Handle wave transition vignette period.
	if _in_transition:
		var transition_elapsed := Time.get_ticks_msec() - _transition_start_ms
		if transition_elapsed >= VIGNETTE_TRANSITION_S * 1000.0:
			_in_transition = false
			# Emit wave_clear signal (vignette has deepened).
			_emit_wave_clear(_current_wave)
			# Enter wait-for-build state.
			_waiting_for_build = true
		return

	# If waiting for build selection, do nothing -- next wave starts after
	# upgrade_selected is received (or after timeout).
	if _waiting_for_build:
		return

	# If a wave is active, check if all enemies are dead.
	if _wave_active:
		_check_wave_clear()

# ---------------------------------------------------------------------------
# Wave lifecycle
# ---------------------------------------------------------------------------

## Starts wave [param wave_num] by spawning the configured enemies.
func _start_wave(wave_num: int) -> void:
	_current_wave = wave_num
	_wave_active = true
	_wave_cleared = false
	_killed_this_wave = 0

	# Get the wave config.
	var config := _get_wave_config(wave_num)
	_enemies_remaining = config.total

	# Update GameManager wave counter if available.
	if GameManager.current_run != null:
		GameManager.current_run.wave = wave_num

	# Spawn enemies via EnemyManager.
	if enemy_manager != null and enemy_manager.has_method("spawn_wave"):
		var spawn_config := {
			"small": config.small,
			"medium": config.medium,
			"large": config.large,
		}
		enemy_manager.spawn_wave(spawn_config)

	# Emit wave_start signal.
	_emit_wave_start(wave_num)

## Returns the wave configuration for the given wave number.
func _get_wave_config(wave_num: int) -> Dictionary:
	var idx := wave_num - 1
	if idx < WAVE_TABLE.size():
		return WAVE_TABLE[idx]
	return WAVE_11_PLUS

## Checks whether the current wave has been cleared (all enemies dead).
##
## Uses two methods in parallel:
##   1. Signal-based: count enemy_killed signals received vs total spawned.
##   2. Active-count: query EnemyManager.get_active_count().
##
## The wave is cleared when either method reports 0 enemies remaining.
func _check_wave_clear() -> void:
	var active_count := _enemies_remaining - _killed_this_wave

	# Method 2: query EnemyManager directly (more accurate).
	if enemy_manager != null and enemy_manager.has_method("get_active_count"):
		active_count = enemy_manager.get_active_count()

	# Also check if enemy_manager is frozen (player dead) -- don't clear wave.
	if enemy_manager != null and enemy_manager.has_method("is_frozen"):
		if enemy_manager.is_frozen():
			return

	if active_count <= 0 and _wave_active:
		_wave_active = false
		_wave_cleared = true
		_wave_clear_time_ms = Time.get_ticks_msec()
		# Begin vignette transition.
		_in_transition = true
		_transition_start_ms = Time.get_ticks_msec()

# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

## Called when an enemy is killed. Decrements the remaining count.
func _on_enemy_killed(_type: int, _position: Vector2, _index: int) -> void:
	if _wave_active:
		_killed_this_wave += 1

## Called when the player selects an upgrade from the build card UI.
## Triggers the start of the next wave.
func _on_upgrade_selected(_upgrade_id: String) -> void:
	if _waiting_for_build:
		_waiting_for_build = false
		_start_wave(_current_wave + 1)

# ---------------------------------------------------------------------------
# EventBus signal emission
# ---------------------------------------------------------------------------

## Emits wave_start on the EventBus Autoload if available.
func _emit_wave_start(wave_num: int) -> void:
	var eb := get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("wave_start"):
		eb.wave_start.emit(wave_num)

## Emits wave_clear on the EventBus Autoload if available.
func _emit_wave_clear(wave_num: int) -> void:
	var eb := get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("wave_clear"):
		eb.wave_clear.emit(wave_num)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns the current wave number (1-indexed). 0 if no wave has started yet.
func get_current_wave() -> int:
	return _current_wave

## Returns true if a wave is currently active (enemies spawned, not all dead).
func is_wave_active() -> bool:
	return _wave_active

## Returns true if currently in the wave transition (vignette deepening).
func is_in_transition() -> bool:
	return _in_transition

## Returns true if waiting for the player to select a build upgrade.
func is_waiting_for_build() -> bool:
	return _waiting_for_build

## Returns the number of enemies remaining in the current wave.
func get_enemies_remaining() -> int:
	return maxi(_enemies_remaining - _killed_this_wave, 0)

## Forces the next wave to start (bypasses build selection wait).
## Used for debugging or when the player chooses to skip upgrades.
func force_next_wave() -> void:
	if _waiting_for_build:
		_waiting_for_build = false
		_start_wave(_current_wave + 1)
