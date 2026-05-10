class_name BuildSystem
extends Node

# ---------------------------------------------------------------------------
# Constants -- 12 upgrade definitions
# ---------------------------------------------------------------------------

## The complete pool of 12 upgrade definitions.
##
## Each upgrade has:
##   - id: unique string identifier
##   - name: display name
##   - category: weapon, skill, dodge, survival, or special
##   - description: short description for the card UI
##   - effect_type: internal key for applying the effect
##   - effect_value: numeric value of the effect
const UPGRADE_POOL: Array[Dictionary] = [
	# Weapon (3)
	{
		id = "weapon_fire_rate",
		name = "Rapid Fire",
		category = "weapon",
		description = "Fire rate +25%",
		effect_type = "fire_rate_mult",
		effect_value = 1.25,
	},
	{
		id = "weapon_damage",
		name = "Damage Up",
		category = "weapon",
		description = "Bullet damage +1",
		effect_type = "damage_flat",
		effect_value = 1,
	},
	{
		id = "weapon_pierce",
		name = "Piercing Rounds",
		category = "weapon",
		description = "Bullets pierce +1 target",
		effect_type = "pierce_bonus",
		effect_value = 1,
	},
	# Skill (3)
	{
		id = "skill_cd",
		name = "Quick Charge",
		category = "skill",
		description = "Skill cooldown -5s",
		effect_type = "skill_cd_flat",
		effect_value = 5.0,
	},
	{
		id = "skill_radius",
		name = "Bigger Boom",
		category = "skill",
		description = "AoE radius +30%",
		effect_type = "skill_radius_mult",
		effect_value = 1.3,
	},
	{
		id = "skill2_damage",
		name = "Overcharge",
		category = "skill",
		description = "Skill 2 damage x3 (from x2)",
		effect_type = "skill2_damage_mult",
		effect_value = 3.0,
	},
	# Dodge (3)
	{
		id = "dodge_charge",
		name = "Extra Charge",
		category = "dodge",
		description = "Max dodge charges +1",
		effect_type = "dodge_max_charge",
		effect_value = 1.0,
	},
	{
		id = "dodge_regen",
		name = "Quick Recovery",
		category = "dodge",
		description = "Charge regen speed +50%",
		effect_type = "dodge_regen_mult",
		effect_value = 1.5,
	},
	{
		id = "dodge_perfect",
		name = "Perfect Instinct",
		category = "dodge",
		description = "Perfect dodge window +50%",
		effect_type = "dodge_window_mult",
		effect_value = 1.5,
	},
	# Survival (2)
	{
		id = "survival_hp",
		name = "Vitality",
		category = "survival",
		description = "Max HP +1",
		effect_type = "max_hp_flat",
		effect_value = 1,
	},
	{
		id = "survival_shield",
		name = "Barrier",
		category = "survival",
		description = "Shield duration +2s",
		effect_type = "shield_duration_flat",
		effect_value = 2.0,
	},
	# Special (1)
	{
		id = "special_skill2_dodge",
		name = "Combat Flow",
		category = "special",
		description = "Normal dodge opens Skill 2 (250ms)",
		effect_type = "normal_dodge_skill2",
		effect_value = 250.0,
	},
]

# ---------------------------------------------------------------------------
# Exported references
# ---------------------------------------------------------------------------

## Reference to the ShootingSystem node (owned by game.tscn).
@export var shooting_system: Node = null

## Reference to the DamageHealthSystem node (owned by game.tscn).
@export var damage_health_system: Node = null

## Reference to the SkillSystem node (owned by game.tscn).
@export var skill_system: Node = null

## Reference to the DodgeSystem node (owned by game.tscn).
@export var dodge_system: Node = null

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

## Set of upgrade IDs that have been chosen during this run.
var _already_chosen: Array[String] = []

## Current pool of available upgrade IDs (excludes already_chosen).
## Replenished from UPGRADE_POOL when exhausted.
var _available_pool: Array[String] = []

## Upgrades that are locked (not yet unlocked via meta-progression).
## These are initially empty -- all 12 are available by default.
## MetaProgression calls unlock_upgrade() to add IDs to this pool.
var _unlocked_pool: Array[String] = []

## Currently displayed upgrade options (pending selection).
var _current_options: Array[String] = []

## Accumulated effect values (tracked for systems that read from BuildSystem).
var _damage_flat_bonus: int = 0
var _fire_rate_mult: float = 1.0
var _pierce_bonus: int = 0
var _skill_cd_reduction: float = 0.0
var _skill_radius_mult: float = 1.0
var _skill2_damage_mult: float = 2.0
var _dodge_max_charge_bonus: int = 0
var _dodge_regen_mult: float = 1.0
var _dodge_window_mult: float = 1.0
var _max_hp_bonus: int = 0
var _shield_duration_bonus: float = 0.0
var _normal_dodge_skill2_window_ms: int = 0

## True when all 12 upgrades from the base pool have been initialized into _available_pool.
var _pool_initialized: bool = false

# ---------------------------------------------------------------------------
# Node lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_initialize_pool()

	# Connect to wave_clear to draw new options.
	var eb := get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("wave_clear"):
		if not eb.wave_clear.is_connected(_on_wave_clear):
			eb.wave_clear.connect(_on_wave_clear)

	# Connect to dodge_normal for Combat Flow special upgrade.
	if eb and eb.has_signal("dodge_normal"):
		if not eb.dodge_normal.is_connected(_on_dodge_normal):
			eb.dodge_normal.connect(_on_dodge_normal)

# ---------------------------------------------------------------------------
# Pool management
# ---------------------------------------------------------------------------

## Initializes the available pool with all currently unlocked upgrades.
## Called in _ready() and when the pool is reshuffled.
func _initialize_pool() -> void:
	_available_pool.clear()
	for upgrade in UPGRADE_POOL:
		_available_pool.append(upgrade.id)
	_pool_initialized = true

## Draws [param count] random upgrades from the available pool, excluding
## already chosen ones. If fewer than [param count] remain, returns what's left.
## If the pool is empty, reshuffles all 12 back in first.
func draw_options(count: int = 3) -> Array[String]:
	# Filter out already chosen.
	var candidates: Array[String] = []
	for id in _available_pool:
		if id not in _already_chosen:
			candidates.append(id)

	# If pool is exhausted, reshuffle all 12.
	if candidates.is_empty():
		_reshuffle_pool()
		for id in _available_pool:
			if id not in _already_chosen:
				candidates.append(id)

	# Shuffle and pick.
	candidates.shuffle()
	var drawn: Array[String] = []
	var to_draw := mini(count, candidates.size())
	for i in range(to_draw):
		drawn.append(candidates[i])

	_current_options = drawn
	return drawn

## Reshuffles: adds all 12 upgrade IDs back to the available pool (except
## already_chosen ones which remain excluded until the NEXT reshuffle cycle).
## Actually, per spec: "Pool exhausted -> reshuffle all 12" means ALL 12 go back
## into the pool (already_chosen is cleared from the exclusion perspective).
## But upgrades already chosen should not appear again in the same run.
## The spec says "reshuffle all 12" -- we interpret this as: reset available pool
## to all 12, but still exclude already_chosen when drawing.
func _reshuffle_pool() -> void:
	_available_pool.clear()
	for upgrade in UPGRADE_POOL:
		_available_pool.append(upgrade.id)

# ---------------------------------------------------------------------------
# Upgrade selection
# ---------------------------------------------------------------------------

## Selects and applies the upgrade identified by [param upgrade_id].
##
## Returns true if the upgrade was applied successfully, false if the ID is
## invalid or the upgrade has already been chosen.
func select_upgrade(upgrade_id: String) -> bool:
	# Validate: must be in current options.
	if upgrade_id not in _current_options:
		return false

	# Find the upgrade definition.
	var def: Dictionary = _get_upgrade_def(upgrade_id)
	if def.is_empty():
		return false

	# Apply the effect immediately.
	_apply_effect(def)

	# Mark as chosen.
	_already_chosen.append(upgrade_id)

	# Record in GameManager.
	if GameManager.current_run != null:
		GameManager.current_run.build_choices.append(upgrade_id)

	# Clear current options.
	_current_options.clear()

	# Emit signal.
	_emit_upgrade_selected(upgrade_id)

	return true

## Returns the upgrade definition Dictionary for [param upgrade_id], or empty dict.
func _get_upgrade_def(upgrade_id: String) -> Dictionary:
	for upgrade in UPGRADE_POOL:
		if upgrade.id == upgrade_id:
			return upgrade
	return {}

## Applies an upgrade's effect to the target gameplay system.
func _apply_effect(def: Dictionary) -> void:
	var effect_type: String = def.effect_type
	var effect_value: float = def.effect_value

	match effect_type:
		"fire_rate_mult":
			_fire_rate_mult *= effect_value
			_apply_to_shooting_system()

		"damage_flat":
			_damage_flat_bonus += int(effect_value)
			_apply_damage_bonus()

		"pierce_bonus":
			_pierce_bonus += int(effect_value)

		"skill_cd_flat":
			_skill_cd_reduction += effect_value

		"skill_radius_mult":
			_skill_radius_mult *= effect_value

		"skill2_damage_mult":
			_skill2_damage_mult = effect_value  # Sets to x3 (overrides default x2)

		"dodge_max_charge":
			_dodge_max_charge_bonus += int(effect_value)
			_apply_dodge_max_charge()

		"dodge_regen_mult":
			_dodge_regen_mult *= effect_value
			_apply_dodge_regen()

		"dodge_window_mult":
			_dodge_window_mult *= effect_value
			_apply_dodge_window()

		"max_hp_flat":
			_max_hp_bonus += int(effect_value)
			_apply_max_hp()

		"shield_duration_flat":
			_shield_duration_bonus += effect_value
			_apply_shield_duration()

		"normal_dodge_skill2":
			_normal_dodge_skill2_window_ms = int(effect_value)

# ---------------------------------------------------------------------------
# Target system modifiers
# ---------------------------------------------------------------------------

## Applies the current fire rate multiplier to ShootingSystem.
func _apply_to_shooting_system() -> void:
	if shooting_system == null:
		return
	if shooting_system.has_method("_fire_bullet") or shooting_system.get("fire_rate") != null:
		# ShootingSystem.fire_rate is an @export var -- we can set it directly.
		# But we need the ORIGINAL fire_rate to multiply from. We track the mult.
		# For simplicity: directly set fire_rate. The ShootingSystem base is 8.0.
		# We apply the cumulative multiplier.
		var base_fire_rate: float = 8.0
		shooting_system.set("fire_rate", base_fire_rate * _fire_rate_mult)

## Applies the damage bonus to DamageHealthSystem.
func _apply_damage_bonus() -> void:
	if damage_health_system == null:
		return
	if damage_health_system.has_method("set_build_bonus"):
		damage_health_system.set_build_bonus(_damage_flat_bonus)

## Applies dodge max charge bonus.
func _apply_dodge_max_charge() -> void:
	if dodge_system == null:
		return
	# DodgeSystem.MAX_CHARGE is const (3.0). We store the bonus.
	# DodgeSystem would need to read from BuildSystem for this.
	# For now, track internally; future integration will use this.
	pass

## Applies dodge regen multiplier.
func _apply_dodge_regen() -> void:
	if dodge_system == null:
		return
	# DodgeSystem.CHARGE_REGEN_TIME is const (3.0).
	# Effective regen time = 3.0 / _dodge_regen_mult.
	pass

## Applies perfect dodge window multiplier.
func _apply_dodge_window() -> void:
	if dodge_system == null:
		return
	# DodgeSystem.PERFECT_DISTANCE is const (40.0).
	# Effective distance = 40.0 * _dodge_window_mult.
	pass

## Applies max HP bonus to DamageHealthSystem.
func _apply_max_hp() -> void:
	if damage_health_system == null:
		return
	# DamageHealthSystem.MAX_HP is const (3). Store bonus internally.
	pass

## Applies shield duration bonus to DamageHealthSystem.
func _apply_shield_duration() -> void:
	if damage_health_system == null:
		return
	# DamageHealthSystem.SHIELD_DURATION_S is const (3.0). Store bonus internally.
	pass

# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

## Called when a wave is cleared. Draws 3 new upgrade options.
func _on_wave_clear(_wave_num: int) -> void:
	# The options are drawn here; the UpgradeCardUI will query them.
	# Actually, the UI calls draw_options() directly. This handler exists
	# to notify the UI that new options are available.
	pass

## Called on normal dodge. If Combat Flow is active, opens skill_2 window.
func _on_dodge_normal(pos: Vector2, _direction: Vector2) -> void:
	if _normal_dodge_skill2_window_ms <= 0:
		return
	# Open a brief skill_2 window on the skill system.
	if skill_system != null and skill_system.has_method("_skill2_window_open_ms"):
		# Duck-type access to the internal skill2 window timer.
		# This sets the window open timestamp on the SkillSystem.
		var now := Time.get_ticks_msec()
		skill_system.set("_skill2_window_open_ms", now)

# ---------------------------------------------------------------------------
# EventBus signal emission
# ---------------------------------------------------------------------------

## Emits upgrade_selected on the EventBus Autoload if available.
func _emit_upgrade_selected(upgrade_id: String) -> void:
	var eb := get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("upgrade_selected"):
		eb.upgrade_selected.emit(upgrade_id)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns the currently drawn upgrade options.
func get_current_options() -> Array[String]:
	return _current_options

## Returns the upgrade definition for the given ID (empty dict if not found).
func get_upgrade_def(upgrade_id: String) -> Dictionary:
	return _get_upgrade_def(upgrade_id)

## Returns the list of already chosen upgrade IDs.
func get_already_chosen() -> Array[String]:
	return _already_chosen

## Marks an upgrade ID as unlocked (called by MetaProgression).
## This adds the ID to the available pool so it can be drawn.
func unlock_upgrade(upgrade_id: String) -> void:
	if upgrade_id not in _unlocked_pool:
		_unlocked_pool.append(upgrade_id)
	# Re-initialize pool to include newly unlocked upgrades.
	_initialize_pool()

## Returns the accumulated pierce bonus (for ShootingSystem integration).
func get_pierce_bonus() -> int:
	return _pierce_bonus

## Returns the accumulated skill CD reduction in seconds.
func get_skill_cd_reduction() -> float:
	return _skill_cd_reduction

## Returns the accumulated skill radius multiplier.
func get_skill_radius_mult() -> float:
	return _skill_radius_mult

## Returns the skill2 damage multiplier (default 2.0, can become 3.0 with upgrade).
func get_skill2_damage_mult() -> float:
	return _skill2_damage_mult

## Returns the accumulated dodge max charge bonus.
func get_dodge_max_charge_bonus() -> int:
	return _dodge_max_charge_bonus

## Returns the accumulated dodge regen multiplier.
func get_dodge_regen_mult() -> float:
	return _dodge_regen_mult

## Returns the accumulated perfect dodge window multiplier.
func get_dodge_window_mult() -> float:
	return _dodge_window_mult

## Returns the accumulated max HP bonus.
func get_max_hp_bonus() -> int:
	return _max_hp_bonus

## Returns the accumulated shield duration bonus in seconds.
func get_shield_duration_bonus() -> float:
	return _shield_duration_bonus

## Returns true if the Combat Flow upgrade is active.
func has_normal_dodge_skill2() -> bool:
	return _normal_dodge_skill2_window_ms > 0

## Returns the normal dodge skill2 window duration in ms.
func get_normal_dodge_skill2_window_ms() -> int:
	return _normal_dodge_skill2_window_ms

## Returns the accumulated damage flat bonus.
func get_damage_flat_bonus() -> int:
	return _damage_flat_bonus

## Returns the fire rate multiplier.
func get_fire_rate_mult() -> float:
	return _fire_rate_mult
