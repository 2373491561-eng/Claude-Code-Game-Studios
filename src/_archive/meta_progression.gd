class_name MetaProgression
extends Node

# ---------------------------------------------------------------------------
# Constants -- unlock thresholds
# ---------------------------------------------------------------------------

## Unlock thresholds: total accumulated points -> upgrade ID.
## When total_points reaches or exceeds a threshold, the corresponding
## upgrade is unlocked (if not already unlocked).
const UNLOCK_THRESHOLDS: Dictionary = {
	5: "weapon_fire_rate",
	15: "weapon_damage",
	25: "skill_cd",
	40: "skill2_damage",
	60: "dodge_charge",
}

## Sorted list of threshold values for efficient iteration.
const SORTED_THRESHOLDS: Array[int] = [5, 15, 25, 40, 60]

# ---------------------------------------------------------------------------
# Exported references
# ---------------------------------------------------------------------------

## Reference to the BuildSystem node. Used to call unlock_upgrade() when
## a threshold is reached.
@export var build_system: Node = null

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

## Total accumulated points across all runs.
var _total_points: int = 0

## Highest wave reached across all runs.
var _highest_wave: int = 0

## List of upgrade IDs that have been unlocked.
var _unlocks: Array[String] = []

## Total kills across all runs (informational).
var _total_kills: int = 0

## Total runs played (informational).
var _total_runs: int = 0

## True when the save has been loaded (or defaulted).
var _loaded: bool = false

# ---------------------------------------------------------------------------
# Node lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_load_save_data()

	# Connect to player_death for points calculation.
	var eb := get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("player_death"):
		if not eb.player_death.is_connected(_on_player_death):
			eb.player_death.connect(_on_player_death)

# ---------------------------------------------------------------------------
# Save/load (SaveManager duck-typing)
# ---------------------------------------------------------------------------

## Loads save data from SaveManager if available, otherwise uses defaults.
func _load_save_data() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm == null or not sm.has_method("save"):
		# No SaveManager available -- use defaults (in-memory only).
		_loaded = true
		return

	# Try to read data from SaveManager.
	var data: Dictionary = {}
	if sm.has_method("get_data"):
		data = sm.get_data()
	elif sm.get("data") != null:
		data = sm.data

	var mp_data: Dictionary = data.get("meta_progression", {})
	if mp_data.is_empty():
		_loaded = true
		return

	_total_points = int(mp_data.get("total_points", 0))
	_highest_wave = int(mp_data.get("highest_wave", 0))
	_unlocks.clear()
	for unlock_id in mp_data.get("unlocks", []):
		if unlock_id is String:
			_unlocks.append(unlock_id)

	_loaded = true

	# Apply already-unlocked upgrades to the BuildSystem.
	_apply_unlocks_to_build_system()

## Saves current state to SaveManager if available.
func _save_data() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm == null:
		return

	var mp_update := {
		"meta_progression": {
			"total_points": _total_points,
			"highest_wave": _highest_wave,
			"unlocks": _unlocks.duplicate(),
		}
	}

	# Try to merge with existing data.
	if sm.has_method("save"):
		if sm.get("data") != null:
			sm.data.merge(mp_update, true)
		sm.save()
	elif sm.get("data") != null:
		sm.data.merge(mp_update, true)
		if sm.has_method("save"):
			sm.save()

# ---------------------------------------------------------------------------
# Points calculation
# ---------------------------------------------------------------------------

## Calculates points earned for a single run.
##
## Formula: floor(kills * 0.1 + wave_reached * 1.0)
##
## Returns the calculated points as an integer.
func calculate_run_points(kills: int, wave_reached: int) -> int:
	return floori(kills * 0.1 + wave_reached * 1.0)

# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

## Called when the player dies. Calculates points, updates totals, and
## checks unlock thresholds.
func _on_player_death() -> void:
	if GameManager.current_run == null:
		return

	var kills := GameManager.current_run.kills
	var wave_reached := GameManager.current_run.wave

	var run_points := calculate_run_points(kills, wave_reached)
	_total_points += run_points
	_total_kills += kills
	_total_runs += 1

	if wave_reached > _highest_wave:
		_highest_wave = wave_reached

	# Check unlock thresholds.
	_check_unlocks()

	# Persist.
	_save_data()

# ---------------------------------------------------------------------------
# Unlock logic
# ---------------------------------------------------------------------------

## Checks all threshold values against total accumulated points and unlocks
## any upgrades whose threshold has been met.
func _check_unlocks() -> void:
	for threshold in SORTED_THRESHOLDS:
		if _total_points >= threshold:
			var upgrade_id: String = UNLOCK_THRESHOLDS.get(threshold, "")
			if upgrade_id != "" and upgrade_id not in _unlocks:
				_unlocks.append(upgrade_id)
				_apply_unlock_to_build_system(upgrade_id)

## Applies a single unlock to the BuildSystem.
func _apply_unlock_to_build_system(upgrade_id: String) -> void:
	if build_system != null and build_system.has_method("unlock_upgrade"):
		build_system.unlock_upgrade(upgrade_id)

## Applies all already-unlocked upgrades to the BuildSystem (on load).
func _apply_unlocks_to_build_system() -> void:
	if build_system == null or not build_system.has_method("unlock_upgrade"):
		return
	for unlock_id in _unlocks:
		build_system.unlock_upgrade(unlock_id)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns the total accumulated points across all runs.
func get_total_points() -> int:
	return _total_points

## Returns the highest wave reached across all runs.
func get_highest_wave() -> int:
	return _highest_wave

## Returns the list of unlocked upgrade IDs.
func get_unlocks() -> Array[String]:
	return _unlocks

## Returns the total kills across all runs.
func get_total_kills() -> int:
	return _total_kills

## Returns the total number of runs played.
func get_total_runs() -> int:
	return _total_runs

## Returns true if the given upgrade ID is unlocked.
func is_unlocked(upgrade_id: String) -> bool:
	return upgrade_id in _unlocks

## Returns the next threshold required for the next unlock, or -1 if all
## upgrades are unlocked.
func get_next_threshold() -> int:
	for threshold in SORTED_THRESHOLDS:
		if _total_points < threshold:
			return threshold
	return -1

## Returns the next upgrade name to be unlocked, or empty string if all
## upgrades are unlocked.
func get_next_unlock_name() -> String:
	var next_threshold := get_next_threshold()
	if next_threshold < 0:
		return ""
	var upgrade_id: String = UNLOCK_THRESHOLDS.get(next_threshold, "")
	return upgrade_id

## Forces a save (useful for manual save triggers).
func force_save() -> void:
	_save_data()
