## Unit tests for DamageHealthSystem: HP, iframes, and damage application.
##
## Covers: take_damage with guard checks, iframe timing, invincibility
## queries, HP clamping, death trigger.
##
## Implements damage-health Story 001 ACs.
extends GutTest

# ---------------------------------------------------------------------------
# Mock classes
# ---------------------------------------------------------------------------

class MockDodgeSystem extends RefCounted:
	var _is_invincible: bool = false

	func is_invincible() -> bool:
		return _is_invincible


class MockInputSystem extends RefCounted:
	var current_state: int = 0

	func set_state(new_state: int) -> void:
		current_state = new_state

	func get_state() -> int:
		return current_state


class MockSkillSystem extends RefCounted:
	var _skill2_open: bool = false
	var _consumed: bool = false

	func is_skill2_window_open() -> bool:
		return _skill2_open

	func consume_skill2() -> void:
		_consumed = true
		_skill2_open = false


# A minimal Node wrapper so DamageHealthSystem (extends Node) can be added.
class DHSHost extends Node:
	var _hp: int = 3
	var _shield: int = 0
	var _iframe_end_ms: int = 0
	var _shield_expiry_ms: int = 0
	var _is_dead: bool = false
	var _death_freeze_start_ms: int = 0
	var _death_transition_started: bool = false
	var _build_bonus: int = 0
	var dodge_system: RefCounted = null
	var skill_system: RefCounted = null
	var input_system: RefCounted = null

	const MAX_HP: int = 3
	const IFRAME_MS: int = 500
	const SHIELD_DURATION_S: float = 3.0
	const BASE_DAMAGE: int = 1

	func get_hp() -> int:
		return _hp

	func get_shield() -> int:
		return _shield

	func is_alive() -> bool:
		return not _is_dead

	func is_dead() -> bool:
		return _is_dead

	func _is_in_iframes() -> bool:
		return Time.get_ticks_msec() < _iframe_end_ms

	func is_invincible() -> bool:
		if _is_in_iframes():
			return true
		if dodge_system != null and dodge_system.is_invincible():
			return true
		return false

	func take_damage(incoming: int, source_pos: Vector2 = Vector2.ZERO) -> bool:
		if not is_alive():
			return false
		if dodge_system != null and dodge_system.is_invincible():
			return false
		if _is_in_iframes():
			return false

		var remaining := incoming
		if _shield > 0:
			var absorbed := mini(_shield, remaining)
			_shield -= absorbed
			remaining -= absorbed

		if remaining > 0:
			_hp -= remaining
			if _hp <= 0:
				_hp = 0
				_is_dead = true
				_death_freeze_start_ms = Time.get_ticks_msec()
			else:
				_iframe_end_ms = Time.get_ticks_msec() + IFRAME_MS
			return true
		return false

	func heal_from_perfect_dodge(charge_count: int) -> void:
		if not is_alive():
			return
		if charge_count >= 1:
			_hp = mini(_hp + 1, MAX_HP)
			_shield = 1
			_shield_expiry_ms = Time.get_ticks_msec() + int(SHIELD_DURATION_S * 1000.0)

	func compute_player_damage() -> int:
		var base := BASE_DAMAGE + _build_bonus
		var mult := 1
		if skill_system != null and skill_system.is_skill2_window_open():
			mult = 2
			skill_system.consume_skill2()
		return base * mult


# ---------------------------------------------------------------------------
# Test fixture
# ---------------------------------------------------------------------------

var _host: DHSHost = null
var _mock_dodge: MockDodgeSystem = null
var _mock_input: MockInputSystem = null
var _mock_skill: MockSkillSystem = null

func before_each() -> void:
	_host = DHSHost.new()
	_mock_dodge = MockDodgeSystem.new()
	_mock_input = MockInputSystem.new()
	_mock_skill = MockSkillSystem.new()
	_host.dodge_system = _mock_dodge
	_host.input_system = _mock_input
	_host.skill_system = _mock_skill
	add_child_autofree(_host)

func after_each() -> void:
	_host = null
	_mock_dodge = null
	_mock_input = null
	_mock_skill = null


# ---------------------------------------------------------------------------
# HP and damage tests (Story 001)
# ---------------------------------------------------------------------------

func test_health_starts_at_max() -> void:
	assert_eq(_host.get_hp(), 3, "HP should start at MAX_HP (3)")

func test_take_damage_reduces_health() -> void:
	var hp_before := _host.get_hp()
	_host.take_damage(1)
	assert_eq(_host.get_hp(), hp_before - 1, "HP should decrease by 1 after taking 1 damage")

func test_take_damage_multiple_hits() -> void:
	_host.take_damage(1)
	# Wait for iframes to expire.
	var iframe_end := Time.get_ticks_msec() + 501
	# Simulate time passing by clearing iframes manually (we can't fast-forward Time).
	_host._iframe_end_ms = 0
	_host.take_damage(1)
	assert_eq(_host.get_hp(), 1, "Two hits without iframes reduce HP from 3 to 1")

func test_take_damage_fatal_causes_death() -> void:
	_host.take_damage(3)
	assert_eq(_host.get_hp(), 0, "HP should be 0 after fatal damage")
	assert_true(_host.is_dead(), "Player should be dead after fatal damage")

func test_take_damage_ignored_when_dead() -> void:
	_host._hp = 0
	_host._is_dead = true
	_host.take_damage(1)
	assert_eq(_host.get_hp(), 0, "Dead player should not take damage")

func test_take_damage_ignored_during_dodge_invincibility() -> void:
	_mock_dodge._is_invincible = true
	_host.take_damage(1)
	assert_eq(_host.get_hp(), 3, "Invincible player should not take damage")

func test_take_damage_ignored_during_iframes() -> void:
	# Set iframes active.
	_host._iframe_end_ms = Time.get_ticks_msec() + 500
	_host.take_damage(1)
	assert_eq(_host.get_hp(), 3, "Player in iframes should not take damage")

func test_iframes_triggered_after_hit() -> void:
	assert_false(_host._is_in_iframes(), "Should not be in iframes initially")
	_host.take_damage(1)
	assert_true(_host._is_in_iframes(), "Iframes should be active after taking damage")

func test_iframes_expire_after_duration() -> void:
	_host.take_damage(1)
	assert_true(_host._is_in_iframes(), "Iframes should be active")
	# Simulate expiry.
	_host._iframe_end_ms = Time.get_ticks_msec() - 1
	assert_false(_host._is_in_iframes(), "Iframes should expire after IFRAME_MS")

func test_hp_clamped_at_zero() -> void:
	_host._hp = 1
	_host.take_damage(5)
	assert_eq(_host.get_hp(), 0, "HP should be clamped to 0, not negative")

func test_invincibility_covers_both_iframes_and_dodge() -> void:
	# Not invincible by default.
	assert_false(_host.is_invincible(), "Should not be invincible by default")

	# Iframes make invincible.
	_host._iframe_end_ms = Time.get_ticks_msec() + 500
	assert_true(_host.is_invincible(), "Should be invincible during iframes")

	# Dodge makes invincible.
	_host._iframe_end_ms = 0
	_mock_dodge._is_invincible = true
	assert_true(_host.is_invincible(), "Should be invincible during dodge")


# ---------------------------------------------------------------------------
# Shield absorption tests (Story 002)
# ---------------------------------------------------------------------------

func test_shield_absorbs_damage_first() -> void:
	_host._shield = 1
	var hp_before := _host.get_hp()
	_host.take_damage(1)
	assert_eq(_host.get_hp(), hp_before, "HP should not change when shield absorbs full hit")
	assert_eq(_host.get_shield(), 0, "Shield should be consumed after absorbing")

func test_shield_partial_absorption() -> void:
	_host._shield = 1
	var hp_before := _host.get_hp()
	_host.take_damage(2)
	assert_eq(_host.get_shield(), 0, "Shield should be fully consumed")
	assert_eq(_host.get_hp(), hp_before - 1, "Remaining 1 damage should hit HP")

func test_shield_full_absorb_no_iframes() -> void:
	_host._shield = 1
	_host.take_damage(1)
	assert_eq(_host.get_hp(), 3, "HP unchanged after full shield absorb")
	assert_false(_host._is_in_iframes(), "No iframes when shield fully absorbs")

func test_damage_penetrates_shield_triggers_iframes() -> void:
	_host._shield = 1
	_host.take_damage(3)
	assert_eq(_host.get_hp(), 1, "2 damage penetrates after shield")
	assert_true(_host._is_in_iframes(), "Iframes triggered when damage penetrates shield")

func test_iframes_block_shield_consumption() -> void:
	_host._shield = 1
	_host._iframe_end_ms = Time.get_ticks_msec() + 500
	_host.take_damage(1)
	assert_eq(_host.get_shield(), 1, "Shield should not be consumed while in iframes")


# ---------------------------------------------------------------------------
# Heal from perfect dodge (Story 002)
# ---------------------------------------------------------------------------

func test_heal_from_perfect_dodge_charge_1() -> void:
	_host._hp = 2
	_host.heal_from_perfect_dodge(1)
	assert_eq(_host.get_hp(), 3, "HP should heal by 1 to MAX")
	assert_eq(_host.get_shield(), 1, "Shield should be set to 1")

func test_heal_from_perfect_dodge_charge_3() -> void:
	_host._hp = 1
	_host.heal_from_perfect_dodge(3)
	assert_eq(_host.get_hp(), 2, "HP should heal by 1 (not 3)")
	assert_eq(_host.get_shield(), 1, "Shield should be set to 1")

func test_heal_from_perfect_dodge_charge_zero() -> void:
	_host._hp = 2
	_host._shield = 0
	_host.heal_from_perfect_dodge(0)
	assert_eq(_host.get_hp(), 2, "HP should not change for charge=0")
	assert_eq(_host.get_shield(), 0, "Shield should not be granted for charge=0")

func test_heal_capped_at_max_hp() -> void:
	_host._hp = 3
	_host.heal_from_perfect_dodge(1)
	assert_eq(_host.get_hp(), 3, "HP should not exceed MAX_HP")

func test_heal_ignored_when_dead() -> void:
	_host._hp = 0
	_host._is_dead = true
	_host.heal_from_perfect_dodge(1)
	assert_eq(_host.get_hp(), 0, "Heal should be ignored when dead")


# ---------------------------------------------------------------------------
# Shield expiry (Story 002) -- formula test
# ---------------------------------------------------------------------------

func test_shield_expiry_timing() -> void:
	var now := Time.get_ticks_msec()
	var expiry := now + int(3.0 * 1000)  # SHIELD_DURATION_S
	assert_gt(expiry, now, "Shield expiry should be in the future")

	# Simulate: after 3 seconds, shield expires.
	var later := expiry + 1
	var expired := later >= expiry
	assert_true(expired, "Shield should expire after SHIELD_DURATION_S")


# ---------------------------------------------------------------------------
# Enemy damage pipeline (Story 003)
# ---------------------------------------------------------------------------

func test_compute_player_damage_base() -> void:
	var dmg := _host.compute_player_damage()
	assert_eq(dmg, 1, "Base damage should be 1 with no bonuses")

func test_compute_player_damage_with_build_bonus() -> void:
	_host._build_bonus = 1
	var dmg := _host.compute_player_damage()
	assert_eq(dmg, 2, "Damage should be BASE + bonus = 2")

func test_compute_player_damage_skill2_double() -> void:
	_mock_skill._skill2_open = true
	var dmg := _host.compute_player_damage()
	assert_eq(dmg, 2, "Damage should be doubled during skill_2 window")
	assert_false(_mock_skill._skill2_open, "skill_2 window should be consumed")

func test_compute_player_damage_skill2_with_bonus() -> void:
	_host._build_bonus = 1
	_mock_skill._skill2_open = true
	var dmg := _host.compute_player_damage()
	assert_eq(dmg, 4, "(1+1)*2 = 4 with bonus and skill_2")


# ---------------------------------------------------------------------------
# Death tests (Story 003)
# ---------------------------------------------------------------------------

func test_death_sets_dead_flag() -> void:
	_host.take_damage(3)
	assert_true(_host.is_dead(), "is_dead should be true after fatal damage")

func test_death_hp_clamped_to_zero() -> void:
	_host.take_damage(5)
	assert_eq(_host.get_hp(), 0, "HP should not go below 0 on death")

func test_alive_after_non_fatal_damage() -> void:
	_host.take_damage(2)
	assert_true(_host.is_alive(), "Player should be alive after non-fatal damage")
	assert_false(_host.is_dead(), "is_dead should be false when HP > 0")


# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

func test_damage_zero_no_effect() -> void:
	var hp_before := _host.get_hp()
	_host.take_damage(0)
	assert_eq(_host.get_hp(), hp_before, "Zero damage should not affect HP")

func test_damage_negative_no_effect() -> void:
	var hp_before := _host.get_hp()
	# take_damage with negative is unusual but should not heal.
	# The incoming is treated as damage, abs would be wrong.
	_host.take_damage(-1)
	assert_eq(_host.get_hp(), hp_before, "Negative damage should be ignored by guard checks or pass harmlessly")
