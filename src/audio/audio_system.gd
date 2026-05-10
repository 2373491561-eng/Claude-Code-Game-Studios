## AudioSystem -- manages audio buses, SFX playback, ducking, and time-scale pitch.
##
## This node is owned by game.tscn. It creates and manages 8 audio buses
## via AudioServer, plays one-shot SFX on the appropriate bus with a pool of
## AudioStreamPlayer nodes, handles ducking during skill bursts (ADR-0008),
## and applies pitch modulation on perfect dodge (ADR-0007 time-scale effect).
##
## Ducking timeline: Attack 50ms -> Hold 450ms -> Release 500ms (ease-out).
## All ducking tweens use set_ignore_time_scale(true) per ADR-0001.
##
## Continuous fire: a dedicated looping AudioStreamPlayer starts on the first
## bullet_hit signal and stops when bullet_hit signals cease (timeout-based
## release detection).
##
## Usage:
##   [codeblock]
##   # In game.tscn _ready():
##   var audio_sys := $AudioSystem
##   audio_sys.set_shoot_loop_stream(preloaded("res://assets/audio/shoot_loop.tres"))
##
##   # Playing a one-shot SFX:
##   audio_sys.play_sfx("SFX/Weapon", some_stream)
##
##   # Ducking triggers automatically via EventBus.skill_1_cast signal.
##   [/codeblock]
class_name AudioSystem
extends Node

# ---------------------------------------------------------------------------
# Constants -- bus names in creation order
# ---------------------------------------------------------------------------

## All audio buses managed by this system. Master always exists at index 0
## in Godot; the remaining 7 are created in _ready() if they do not already
## exist.
const BUS_NAMES: Array[String] = [
	"Master",
	"BGM",
	"SFX/Weapon",
	"SFX/Impact",
	"SFX/Dodge",
	"SFX/Skill",
	"SFX/Enemy",
	"UI",
]

## Maximum number of simultaneous one-shot SFX players.
## If play_sfx() is called while MAX_SIMULTANEOUS_SFX players are active,
## the oldest player is stopped and reused.
const MAX_SIMULTANEOUS_SFX: int = 8

## Default volume for all buses in dB.
const DEFAULT_VOLUME_DB: float = 0.0

## Time in seconds after the last bullet_hit signal before the shoot loop
## is stopped. This approximates "stop on release" without a dedicated
## shoot_stopped signal.
const SHOOT_LOOP_TIMEOUT: float = 0.15

# ---------------------------------------------------------------------------
# Ducking configuration (ADR-0008)
# ---------------------------------------------------------------------------

## Per-bus ducking target volumes in dB.
## SFX/Skill is intentionally absent -- it is NEVER ducked.
const DUCK_CONFIG: Dictionary = {
	"BGM": -12.0,
	"SFX/Weapon": -9.0,
	"SFX/Dodge": -6.0,
	"SFX/Impact": -6.0,
	"SFX/Enemy": -9.0,
	"UI": -6.0,
}

## Ducking timeline durations in seconds.
const DUCK_ATTACK_S: float = 0.05
const DUCK_HOLD_S: float = 0.45
const DUCK_RELEASE_S: float = 0.5

# ---------------------------------------------------------------------------
# Perfect dodge pitch configuration (ADR-0007 / Story 002)
# ---------------------------------------------------------------------------

## Pitch scale applied to world SFX buses on perfect dodge.
## 0.25 = 2 octaves down, matching the time_scale=0.2 slow-motion effect.
const PERFECT_DODGE_PITCH: float = 0.25

## Default pitch scale (normal playback speed).
const DEFAULT_PITCH: float = 1.0

## Buses affected by perfect dodge pitch modulation.
## SFX/Skill is excluded -- skill audio stays at normal pitch.
const PERFECT_DODGE_PITCH_BUSES: Array[String] = [
	"SFX/Weapon",
	"SFX/Impact",
	"SFX/Enemy",
]

## Duration in seconds that perfect dodge pitch stays active before
## automatic restoration. Matches the DodgeSystem real-time slow-mo window.
const PERFECT_DODGE_PITCH_DURATION: float = 0.6

# ---------------------------------------------------------------------------
# State -- SFX pool
# ---------------------------------------------------------------------------

## Pool of AudioStreamPlayer nodes for one-shot SFX playback.
## Pre-allocated in _ready() to avoid runtime allocation in the hot path.
var _sfx_pool: Array[AudioStreamPlayer] = []

## Maps each AudioStreamPlayer in _sfx_pool to its start time (seconds,
## from Time.get_ticks_msec() / 1000.0). Used to identify the oldest
## player for eviction when MAX_SIMULTANEOUS_SFX is exceeded.
var _sfx_start_times: Dictionary = {}

# ---------------------------------------------------------------------------
# State -- shoot loop (continuous fire)
# ---------------------------------------------------------------------------

## Dedicated looping AudioStreamPlayer for continuous fire.
## Not counted toward MAX_SIMULTANEOUS_SFX.
var _shoot_loop_player: AudioStreamPlayer = null

## Timestamp (seconds) of the most recent bullet_hit signal.
## Used by _process() to detect when firing has stopped.
var _last_bullet_hit_time: float = -1.0

# ---------------------------------------------------------------------------
# State -- ducking
# ---------------------------------------------------------------------------

## Active ducking tweens. Killed before starting a new duck cycle to
## prevent overlapping volume fights (ADR-0008 requirement).
var _duck_tweens: Array[Tween] = []

# ---------------------------------------------------------------------------
# State -- per-bus pitch scale
# ---------------------------------------------------------------------------

## Per-bus pitch scale multiplier. Defaults to 1.0 for all buses.
## Modified by perfect dodge (0.25 on world buses) and restored after
## the pitch effect duration expires. Applied to AudioStreamPlayers
## when they are assigned to a bus.
var _bus_pitch_scale: Dictionary = {}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_create_audio_buses()
	_init_pitch_scales()
	_create_sfx_pool()
	_create_shoot_loop_player()
	_connect_event_bus_signals()

## Checks whether the shoot loop should be stopped due to inactivity.
## Runs every idle frame; the check is skipped when the shoot loop is not
## playing (minimal overhead).
func _process(_delta: float) -> void:
	_check_shoot_loop_timeout()

# ---------------------------------------------------------------------------
# Bus creation
# ---------------------------------------------------------------------------

## Creates all audio buses defined in BUS_NAMES if they do not already exist.
##
## Master always exists in Godot (index 0). Each remaining bus is checked
## via AudioServer.get_bus_index() and created if the lookup returns -1.
## Buses are created at the end of the bus list (add_bus with no argument)
## and named via set_bus_name(). Volume is initialized to DEFAULT_VOLUME_DB.
func _create_audio_buses() -> void:
	for bus_name in BUS_NAMES:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_volume_db(idx, DEFAULT_VOLUME_DB)

## Initializes _bus_pitch_scale to 1.0 for all bus names.
func _init_pitch_scales() -> void:
	for bus_name in BUS_NAMES:
		_bus_pitch_scale[bus_name] = DEFAULT_PITCH

# ---------------------------------------------------------------------------
# SFX pool
# ---------------------------------------------------------------------------

## Pre-allocates MAX_SIMULTANEOUS_SFX AudioStreamPlayer children.
##
## Each player is added as a child of this node and initialized with
## default settings. The pool is indexed by position in _sfx_pool.
func _create_sfx_pool() -> void:
	for _i in range(MAX_SIMULTANEOUS_SFX):
		var player := AudioStreamPlayer.new()
		player.bus = &"Master"
		add_child(player)
		_sfx_pool.append(player)

# ---------------------------------------------------------------------------
# Shoot loop player
# ---------------------------------------------------------------------------

## Creates the dedicated AudioStreamPlayer for continuous fire.
##
## This player is set to looping mode and placed on the SFX/Weapon bus.
## The actual AudioStream is assigned via set_shoot_loop_stream().
func _create_shoot_loop_player() -> void:
	_shoot_loop_player = AudioStreamPlayer.new()
	_shoot_loop_player.bus = &"SFX/Weapon"
	_shoot_loop_player.set_meta(&"loop_mode", true)
	add_child(_shoot_loop_player)

## Assigns the AudioStream used for the continuous fire loop.
##
## [param stream]: The looping audio stream (e.g., a machine gun sound).
## If null, the shoot loop will be silent (graceful degradation).
func set_shoot_loop_stream(stream: AudioStream) -> void:
	if _shoot_loop_player == null:
		return
	_shoot_loop_player.stream = stream

# ---------------------------------------------------------------------------
# Public API -- play_sfx
# ---------------------------------------------------------------------------

## Plays a one-shot sound effect on the specified audio bus.
##
## Finds an available AudioStreamPlayer from the pool, assigns it to
## [param bus_name] with [param stream], and starts playback. If all
## MAX_SIMULTANEOUS_SFX players are active, the oldest player is stopped
## and reused.
##
## [param bus_name]: The target audio bus (e.g., "SFX/Weapon", "UI").
##                   Must be one of the buses created in _ready().
## [param stream]:   The AudioStream to play. If null, this method is a
##                   no-op (graceful degradation).
##
## Returns the AudioStreamPlayer used, or null if no stream was provided.
##
## Usage:
##   [codeblock]
##   audio_sys.play_sfx("SFX/Impact", hit_stream)
##   audio_sys.play_sfx("SFX/Dodge", dodge_stream)
##   [/codeblock]
func play_sfx(bus_name: String, stream: AudioStream = null) -> AudioStreamPlayer:
	if stream == null:
		return null

	var player: AudioStreamPlayer = null

	# Count active players and find the oldest if we need to evict.
	var active_count := 0
	var oldest_player: AudioStreamPlayer = null
	var oldest_time: float = INF
	var now := Time.get_ticks_msec() / 1000.0

	for p in _sfx_pool:
		if p.playing:
			active_count += 1
			var start_time: float = _sfx_start_times.get(p, 0.0)
			if start_time < oldest_time:
				oldest_time = start_time
				oldest_player = p

	if active_count >= MAX_SIMULTANEOUS_SFX:
		# Evict the oldest player.
		oldest_player.stop()
		player = oldest_player
	else:
		# Find a free (non-playing) player.
		for p in _sfx_pool:
			if not p.playing:
				player = p
				break

	if player == null:
		return null

	# Configure and play.
	player.bus = StringName(bus_name)
	player.stream = stream
	player.pitch_scale = _bus_pitch_scale.get(bus_name, DEFAULT_PITCH)
	_sfx_start_times[player] = now
	player.play()
	return player

# ---------------------------------------------------------------------------
# EventBus signal connections
# ---------------------------------------------------------------------------

## Connects to all required EventBus signals with has_signal() safety checks.
##
## Per the spec: "EventBus signals may not all exist yet -- connect safely
## with has_signal() checks." Each connection is guarded; missing signals
## are silently skipped so AudioSystem works with a partial EventBus.
##
## Signal handler signatures match the EventBus signal definitions from
## ADR-0005.
func _connect_event_bus_signals() -> void:
	var eb := get_node_or_null("/root/EventBus")
	if eb == null:
		return

	# bullet_hit(hit_pos: Vector2, is_skill2: bool)
	if eb.has_signal("bullet_hit"):
		eb.bullet_hit.connect(_on_bullet_hit)

	# dodge_perfect(pos: Vector2, charge_count: int)
	if eb.has_signal("dodge_perfect"):
		eb.dodge_perfect.connect(_on_dodge_perfect)

	# dodge_normal(pos: Vector2, direction: Vector2)
	if eb.has_signal("dodge_normal"):
		eb.dodge_normal.connect(_on_dodge_normal)

	# skill_1_cast(pos: Vector2)
	if eb.has_signal("skill_1_cast"):
		eb.skill_1_cast.connect(_on_skill_1_cast)

	# enemy_killed(type: int, pos: Vector2)
	if eb.has_signal("enemy_killed"):
		eb.enemy_killed.connect(_on_enemy_killed)

	# player_hit(damage: float, source_pos: Vector2)
	if eb.has_signal("player_hit"):
		eb.player_hit.connect(_on_player_hit)

	# player_death(stats: Dictionary)
	if eb.has_signal("player_death"):
		eb.player_death.connect(_on_player_death)

# ---------------------------------------------------------------------------
# Signal handlers -- shoot
# ---------------------------------------------------------------------------

## Called when a bullet hits something.
##
## Resets the shoot loop timeout and starts the loop if it is not already
## playing. The loop continues while bullet_hit signals arrive within
## SHOOT_LOOP_TIMEOUT seconds of each other.
func _on_bullet_hit(_hit_pos: Vector2, _is_skill2: bool) -> void:
	_last_bullet_hit_time = Time.get_ticks_msec() / 1000.0
	if _shoot_loop_player != null and not _shoot_loop_player.playing:
		_start_shoot_loop()

# ---------------------------------------------------------------------------
# Signal handlers -- dodge
# ---------------------------------------------------------------------------

## Called on a perfect dodge.
##
## Sets pitch_scale = 0.25 on world SFX buses (Weapon, Impact, Enemy)
## to create the slow-motion audio effect. SFX/Skill stays at 1.0.
## A real-time timer restores pitch after PERFECT_DODGE_PITCH_DURATION.
func _on_dodge_perfect(_pos: Vector2, _charge_count: int) -> void:
	for bus_name in PERFECT_DODGE_PITCH_BUSES:
		_bus_pitch_scale[bus_name] = PERFECT_DODGE_PITCH
		_apply_pitch_to_active_players(bus_name)

	# Schedule pitch restoration after the slow-mo window.
	if is_inside_tree():
		var timer := get_tree().create_timer(PERFECT_DODGE_PITCH_DURATION, false, false, true)
		timer.timeout.connect(_restore_pitch_scales)

## Restores pitch_scale to 1.0 on all world SFX buses.
##
## Called automatically after PERFECT_DODGE_PITCH_DURATION seconds
## (real time, ignoring Engine.time_scale).
func _restore_pitch_scales() -> void:
	for bus_name in PERFECT_DODGE_PITCH_BUSES:
		_bus_pitch_scale[bus_name] = DEFAULT_PITCH
		_apply_pitch_to_active_players(bus_name)

## Applies the current _bus_pitch_scale for [param bus_name] to all
## active AudioStreamPlayers assigned to that bus.
func _apply_pitch_to_active_players(bus_name: String) -> void:
	var target_pitch: float = _bus_pitch_scale.get(bus_name, DEFAULT_PITCH)
	for player in _sfx_pool:
		if player.bus == bus_name:
			player.pitch_scale = target_pitch
	# Also apply to the shoot loop player if it is on this bus.
	if _shoot_loop_player != null and _shoot_loop_player.bus == bus_name:
		_shoot_loop_player.pitch_scale = target_pitch

## Called on a normal dodge.
##
## Restores pitch_scales to default. This handles the case where a normal
## dodge fires after a perfect dodge (providing an early pitch restoration
## point). If no pitch modulation is active, this is a harmless no-op.
func _on_dodge_normal(_pos: Vector2, _direction: Vector2) -> void:
	# Restore pitch scales if they were modified by a perfect dodge.
	# This provides an early restoration point while the timer provides
	# a safety net.
	for bus_name in PERFECT_DODGE_PITCH_BUSES:
		if _bus_pitch_scale.get(bus_name, DEFAULT_PITCH) != DEFAULT_PITCH:
			_bus_pitch_scale[bus_name] = DEFAULT_PITCH
			_apply_pitch_to_active_players(bus_name)

# ---------------------------------------------------------------------------
# Signal handlers -- skill
# ---------------------------------------------------------------------------

## Called when skill_1 is cast.
##
## Triggers the audio ducking cycle (ADR-0008):
##   Attack 50ms -> Hold 450ms -> Release 500ms (ease-out)
##
## SFX/Skill bus is NOT ducked (stays at 0 dB).
## All ducking tweens use set_ignore_time_scale(true) per ADR-0001.
func _on_skill_1_cast(_pos: Vector2) -> void:
	_apply_ducking()

## Applies the ducking volume ramp to all configured buses.
##
## Kills any in-progress ducking tweens before starting a new cycle.
## Uses tween_method() with AudioServer.set_bus_volume_db.bind(bus_idx)
## to ramp bus volumes per the ADR-0008 specification.
##
## IMPORTANT: Does NOT use AudioServer.get_bus_effect(). Uses
## get_bus_index() + set_bus_volume_db() instead, as confirmed by
## ADR-0008 engine compatibility verification.
func _apply_ducking() -> void:
	# Kill any in-progress ducking tweens to prevent overlapping volume
	# fights when skill_1_cast fires during an existing duck cycle.
	for t in _duck_tweens:
		if t.is_valid():
			t.kill()
	_duck_tweens.clear()

	var configs: Array[Dictionary] = [
		{"bus": "BGM",         "target": -12.0},
		{"bus": "SFX/Weapon",  "target": -9.0},
		{"bus": "SFX/Dodge",   "target": -6.0},
		{"bus": "SFX/Impact",  "target": -6.0},
		{"bus": "SFX/Enemy",   "target": -9.0},
		{"bus": "UI",          "target": -6.0},
	]

	for cfg in configs:
		var bus_name: String = cfg["bus"]
		var target_db: float = cfg["target"]
		var bus_idx := AudioServer.get_bus_index(bus_name)
		if bus_idx == -1:
			continue

		var current_db := AudioServer.get_bus_volume_db(bus_idx)
		var tween := create_tween()
		tween.set_ignore_time_scale(true)

		# Attack phase: ramp volume down over DUCK_ATTACK_S seconds.
		tween.tween_method(
			AudioServer.set_bus_volume_db.bind(bus_idx),
			current_db,
			target_db,
			DUCK_ATTACK_S
		)

		# Hold phase: maintain ducked volume.
		tween.tween_interval(DUCK_HOLD_S)

		# Release phase: ramp volume back to 0 dB over DUCK_RELEASE_S seconds
		# using ease-out for a smooth recovery.
		tween.tween_method(
			AudioServer.set_bus_volume_db.bind(bus_idx),
			target_db,
			DEFAULT_VOLUME_DB,
			DUCK_RELEASE_S
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

		_duck_tweens.append(tween)

# ---------------------------------------------------------------------------
# Signal handlers -- enemy / player
# ---------------------------------------------------------------------------

## Called when an enemy is killed.
func _on_enemy_killed(_type: int, _pos: Vector2) -> void:
	pass  # Placeholder -- SFX triggered via play_sfx() by the caller.

## Called when the player takes damage.
func _on_player_hit(_damage: float, _source_pos: Vector2) -> void:
	pass  # Placeholder -- SFX triggered via play_sfx() by the caller.

## Called when the player dies.
func _on_player_death(_stats: Dictionary) -> void:
	pass  # Placeholder -- SFX triggered via play_sfx() by the caller.

# ---------------------------------------------------------------------------
# Shoot loop helpers
# ---------------------------------------------------------------------------

## Starts the looping shoot sound.
##
## Applies the current pitch_scale for the SFX/Weapon bus before playing.
func _start_shoot_loop() -> void:
	if _shoot_loop_player == null or _shoot_loop_player.stream == null:
		return
	_shoot_loop_player.pitch_scale = _bus_pitch_scale.get("SFX/Weapon", DEFAULT_PITCH)
	_shoot_loop_player.play()

## Stops the looping shoot sound.
func _stop_shoot_loop() -> void:
	if _shoot_loop_player != null and _shoot_loop_player.playing:
		_shoot_loop_player.stop()

## Checks whether the shoot loop should be stopped due to inactivity.
##
## If SHOOT_LOOP_TIMEOUT seconds have elapsed since the last bullet_hit
## signal, the loop is stopped. This approximates "stop on release" without
## requiring a dedicated shoot_stopped EventBus signal.
func _check_shoot_loop_timeout() -> void:
	if _shoot_loop_player == null or not _shoot_loop_player.playing:
		return
	if _last_bullet_hit_time < 0.0:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_bullet_hit_time > SHOOT_LOOP_TIMEOUT:
		_stop_shoot_loop()
