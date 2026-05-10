class_name DamageHealthSystem
extends Node

# ---------------------------------------------------------------------------
# Constants -- all gameplay values are data-driven (tuning knobs from GDD)
# ---------------------------------------------------------------------------

## Maximum player hit points.
const MAX_HP: int = 3

## Invincibility frame duration after taking damage, in milliseconds (real time).
const IFRAME_MS: int = 500

## Shield duration from perfect dodge heal, in seconds (real time).
const SHIELD_DURATION_S: float = 3.0

## Base damage the player deals to enemies (before bonuses and multipliers).
const BASE_DAMAGE: int = 1

## Delay in milliseconds between death and death screen transition.
const DEATH_SCREEN_DELAY_MS: int = 500

# ---------------------------------------------------------------------------
# Exported references
# ---------------------------------------------------------------------------

## Reference to the DodgeSystem node. Used to check is_invincible() and
## get_charge_count() for perfect dodge healing.
@export var dodge_system: DodgeSystem = null

## Reference to the SkillSystem node. Used to check is_skill2_window_open()
## for the damage multiplier in compute_player_damage().
@export var skill_system: SkillSystem = null

## Reference to the InputSystem node. Used to set STATE_DEAD on player death.
@export var input_system: InputSystem = null

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

## Current hit points. Range 0..MAX_HP.
var _hp: int = MAX_HP

## Current shield points. Absorbs damage before HP.
var _shield: int = 0

## Timestamp (Time.get_ticks_msec()) when iframes expire, or 0 if not active.
var _iframe_end_ms: int = 0

## Timestamp (Time.get_ticks_msec()) when shield expires, or 0 if no shield.
var _shield_expiry_ms: int = 0

## True after _on_death() is called. Prevents duplicate death processing.
var _is_dead: bool = false

## Timestamp when death was triggered, used for death freeze and transition delay.
var _death_freeze_start_ms: int = 0

## True after the death screen transition has been initiated.
## Prevents duplicate scene switch calls.
var _death_transition_started: bool = false

## Bonus damage added to BASE_DAMAGE from build choices (tuned by game-designer).
var _build_bonus: int = 0

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when HP changes (including due to damage or healing).
signal hp_changed(new_hp: int)

## Emitted when shield value changes (including gain or expiry).
signal shield_changed(new_shield: int)

# ---------------------------------------------------------------------------
# Node lifecycle
# ---------------------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	# --- Shield expiry check (real-time, Story 002) ---
	if _shield > 0:
		if Time.get_ticks_msec() >= _shield_expiry_ms:
			_shield = 0
			shield_changed.emit(0)

	# --- Death screen transition (Story 003) ---
	if _is_dead and not _death_transition_started:
		if Time.get_ticks_msec() - _death_freeze_start_ms >= DEATH_SCREEN_DELAY_MS:
			_transition_to_death_screen()

# ---------------------------------------------------------------------------
# Public API -- damage and state queries
# ---------------------------------------------------------------------------

## Applies [param incoming] damage to the player.
##
## Guards (checked in order, first match returns):
##   1. Player is dead -- no further damage.
##   2. Dodge invincibility active -- damage ignored.
##   3. Iframes active -- damage ignored.
##
## Shield absorbs damage first. If shield fully absorbs the hit, no iframes
## are triggered. If damage penetrates the shield, iframes are triggered
## for [constant IFRAME_MS] milliseconds.
##
## [param source_pos] is the world-space position of the damage source,
## forwarded to the EventBus.player_hit signal for VFX/camera systems.
func take_damage(incoming: int, source_pos: Vector2 = Vector2.ZERO) -> void:
	# Guard 1: Death priority -- dead players take no damage.
	if not is_alive():
		return

	# Guard 2: Dodge invincibility.
	if dodge_system != null and dodge_system.is_invincible():
		return

	# Guard 3: Iframes block damage AND shield consumption.
	if _is_in_iframes():
		return

	var remaining := incoming

	# Shield absorbs first. Iframes block shield consumption (guard 3 above).
	if _shield > 0:
		var absorbed := mini(_shield, remaining)
		_shield -= absorbed
		remaining -= absorbed
		shield_changed.emit(_shield)

	if remaining > 0:
		var old_hp := _hp
		_hp -= remaining
		if _hp <= 0:
			_hp = 0
			_on_death()
		else:
			# Iframes only trigger when HP actually decreases.
			_iframe_end_ms = Time.get_ticks_msec() + IFRAME_MS

		hp_changed.emit(_hp)

		# Emit player_hit for downstream systems (VFX, camera shake, audio).
		var eb := get_node_or_null("/root/EventBus")
		if eb and eb.has_signal("player_hit"):
			eb.player_hit.emit(remaining, source_pos)

## Heals 1 HP and grants 1 shield after a perfect dodge.
##
## [param charge_count]: the dodge charge count at the time of the perfect dodge.
##   If charge_count >= 1: HP += 1 (capped at MAX_HP), shield = 1 (3s real-time).
##   If charge_count == 0: no heal, no shield (defensive-only perfect dodge).
##
## Guard: if the player is dead, healing is ignored (death priority).
func heal_from_perfect_dodge(charge_count: int) -> void:
	if not is_alive():
		return

	if charge_count >= 1:
		_hp = mini(_hp + 1, MAX_HP)
		_shield = 1
		_shield_expiry_ms = Time.get_ticks_msec() + int(SHIELD_DURATION_S * 1000.0)
		hp_changed.emit(_hp)
		shield_changed.emit(_shield)
	# charge_count == 0: no-op (defensive-only perfect dodge).

## Computes damage dealt by the player to an enemy.
##
## Formula: (BASE_DAMAGE + build_bonus) * (2 if skill_2_window else 1)
##
## If skill_system is not assigned or skill_2 window is not open, the
## multiplier is 1 (no bonus damage).
##
## Returns the computed damage as an integer.
func compute_player_damage() -> int:
	var base := BASE_DAMAGE + _build_bonus
	var mult := 1
	if skill_system != null and skill_system.is_skill2_window_open():
		mult = 2
		skill_system.consume_skill2()
	return base * mult

# ---------------------------------------------------------------------------
# Public getters
# ---------------------------------------------------------------------------

## Returns current hit points (0..MAX_HP).
func get_hp() -> int:
	return _hp

## Returns current shield points.
func get_shield() -> int:
	return _shield

## Returns true if the player is alive (not dead).
func is_alive() -> bool:
	return not _is_dead

## Returns true if the player is invincible via iframes or dodge.
##
## Checked by damage sources before applying damage. Covers:
##   - Iframes after taking a hit (500ms).
##   - Dodge invincibility (300ms during dodge displacement).
func is_invincible() -> bool:
	if _is_in_iframes():
		return true
	if dodge_system != null and dodge_system.is_invincible():
		return true
	return false

## Returns true if the player is dead.
func is_dead() -> bool:
	return _is_dead

## Returns the current build bonus (for HUD/debug display).
func get_build_bonus() -> int:
	return _build_bonus

## Sets the build bonus from build choices.
func set_build_bonus(bonus: int) -> void:
	_build_bonus = maxi(bonus, 0)

# ---------------------------------------------------------------------------
# Private -- iframe logic
# ---------------------------------------------------------------------------

## Returns true if the player is currently in iframes.
##
## Uses real-time Time.get_ticks_msec() per ADR-0001 -- iframes are
## unaffected by Engine.time_scale.
func _is_in_iframes() -> bool:
	return Time.get_ticks_msec() < _iframe_end_ms

# ---------------------------------------------------------------------------
# Private -- death handling (Story 003)
# ---------------------------------------------------------------------------

## Called when HP drops to 0 or below.
##
## Sets the dead flag, records the death timestamp for the 500ms delay,
## emits EventBus.player_death, and sets the input state to STATE_DEAD.
##
## The actual scene transition happens in _physics_process() after the
## DEATH_SCREEN_DELAY_MS delay.
func _on_death() -> void:
	_is_dead = true
	_death_freeze_start_ms = Time.get_ticks_msec()

	# Set input state to DEAD so no further player actions are processed.
	if input_system != null:
		input_system.set_state(InputSystem.STATE_DEAD)

	# Emit player_death signal for downstream systems.
	#   - EnemyManager: freezes all AI
	#   - ShootingSystem: stops firing
	#   - VFX: death particles
	#   - Audio: death sound, BGM stop
	var eb := get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("player_death"):
		eb.player_death.emit()

## Initiates the scene transition to the death screen.
##
## Uses SceneManager autoload. Guarded by has_method to allow testing
## without the full autoload tree.
func _transition_to_death_screen() -> void:
	_death_transition_started = true
	var sm := get_node_or_null("/root/SceneManager")
	if sm and sm.has_method("switch_to"):
		# SceneManager.SceneID.DEATH_SCREEN = 2
		sm.switch_to(2)  # SceneID.DEATH_SCREEN
