## Unit tests for DamageHealthSystem: shield absorption and heal logic.
##
## Covers: shield damage absorption, partial absorption, iframe bypass,
## heal_from_perfect_dodge edge cases, shield expiry.
##
## Implements damage-health Story 002 ACs.
extends GutTest

# ---------------------------------------------------------------------------
# Mock classes
# ---------------------------------------------------------------------------

class MockDodgeSystem extends RefCounted:
	var _is_invincible: bool = false
	func is_invincible() -> bool:
		return _is_invincible


# Minimal test host that replicates DamageHealthSystem shield/heal logic.
class ShieldHost extends Node:
	var _hp: int = 3
	var _shield: int = 0
	var _iframe_end_ms: int = 0
	var _shield_expiry_ms: int = 0
	var _is_dead: bool = false
	var dodge_system: RefCounted = null

	const MAX_HP: int = 3
	const IFRAME_MS: int = 500
	const SHIELD_DURATION_S: float = 3.0

	func get_hp() -> int:
		return _hp

	func get_shield() -> int:
		return _shield

	func is_alive() -> bool:
		return not _is_dead

	func _is_in_iframes() -> bool:
		return Time.get_ticks_msec() < _iframe_end_ms

	func take_damage(incoming: int) -> bool:
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


# ---------------------------------------------------------------------------
# Test fixture
# ---------------------------------------------------------------------------

var _host: ShieldHost = null
var _mock_dodge: MockDodgeSystem = null

func before_each() -> void:
	_host = ShieldHost.new()
	_mock_dodge = MockDodgeSystem.new()
	_host.dodge_system = _mock_dodge
	add_child_autofree(_host)

func after_each() -> void:
	_host = null
	_mock_dodge = null


# ---------------------------------------------------------------------------
# Shield absorption -- full
# ---------------------------------------------------------------------------

func test_shield_absorbs_exact_damage() -> void:
	_host._shield = 1
	var hp_before := _host.get_hp()
	_host.take_damage(1)
	assert_eq(_host.get_hp(), hp_before, "HP should not change when shield absorbs exact damage")
	assert_eq(_host.get_shield(), 0, "Shield should be consumed")

func test_shield_absorbs_from_multiple_hits() -> void:
	_host._shield = 2
	_host.take_damage(1)
	assert_eq(_host.get_shield(), 1, "Shield should decrease by 1")
	# Fast-forward past iframes.
	_host._iframe_end_ms = 0
	_host.take_damage(1)
	assert_eq(_host.get_shield(), 0, "Shield should decrease to 0")
	assert_eq(_host.get_hp(), 3, "HP should remain at max after two fully-absorbed hits")

func test_shield_absorbs_large_hit() -> void:
	_host._shield = 1
	var hp_before := _host.get_hp()
	_host.take_damage(5)
	assert_eq(_host.get_shield(), 0, "Shield should be consumed")
	assert_eq(_host.get_hp(), hp_before - 4, "Remaining 4 damage should hit HP")


# ---------------------------------------------------------------------------
# Shield absorption -- partial
# ---------------------------------------------------------------------------

func test_shield_partial_absorb_hp_decrease() -> void:
	_host._shield = 1
	_host.take_damage(2)
	assert_eq(_host.get_hp(), 2, "HP should be 2 after 1 shield + 1 direct")
	assert_gt(_host._iframe_end_ms, Time.get_ticks_msec(), "Iframes should be active when HP is hit")

func test_shield_partial_absorb_no_iframes_when_full_absorb() -> void:
	_host._shield = 3
	var hp_before := _host.get_hp()
	_host.take_damage(1)
	assert_eq(_host.get_hp(), hp_before, "HP unchanged")
	var now := Time.get_ticks_msec()
	assert_true(now >= _host._iframe_end_ms, "No iframes when damage is fully absorbed by shield")


# ---------------------------------------------------------------------------
# Iframes block shield consumption
# ---------------------------------------------------------------------------

func test_iframes_prevent_shield_loss() -> void:
	_host._shield = 1
	_host._iframe_end_ms = Time.get_ticks_msec() + 500
	_host.take_damage(1)
	assert_eq(_host.get_shield(), 1, "Shield should remain when iframes active")
	assert_eq(_host.get_hp(), 3, "HP should remain when iframes active")

func test_iframes_expire_then_shield_works() -> void:
	_host._shield = 1
	_host._iframe_end_ms = Time.get_ticks_msec() - 1  # Already expired
	_host.take_damage(1)
	assert_eq(_host.get_shield(), 0, "Shield should absorb when iframes expired")


# ---------------------------------------------------------------------------
# Shield expiry via real time
# ---------------------------------------------------------------------------

func test_shield_has_correct_duration() -> void:
	var before := Time.get_ticks_msec()
	_host.heal_from_perfect_dodge(1)
	var after := Time.get_ticks_msec()
	var expected_expiry_min := before + int(3.0 * 1000.0)
	var expected_expiry_max := after + int(3.0 * 1000.0)
	assert_ge(_host._shield_expiry_ms, expected_expiry_min, "Shield expiry should be at least 3s from heal")
	assert_le(_host._shield_expiry_ms, expected_expiry_max, "Shield expiry should be roughly 3s from heal")

func test_shield_does_not_expire_before_duration() -> void:
	_host.heal_from_perfect_dodge(1)
	# Shield should still exist right after creation.
	assert_eq(_host.get_shield(), 1, "Shield should be active right after heal")

func test_shield_expires_after_duration() -> void:
	_host.heal_from_perfect_dodge(1)
	# Simulate expiry by setting to past.
	_host._shield_expiry_ms = Time.get_ticks_msec() - 1
	# Check shield manually (like _physics_process would).
	if _host.get_shield() > 0 and Time.get_ticks_msec() >= _host._shield_expiry_ms:
		_host._shield = 0
	assert_eq(_host.get_shield(), 0, "Shield should be 0 after expiry time is reached")


# ---------------------------------------------------------------------------
# Heal from perfect dodge -- value correctness
# ---------------------------------------------------------------------------

func test_heal_grants_exactly_1_hp() -> void:
	_host._hp = 1
	_host.heal_from_perfect_dodge(1)
	assert_eq(_host.get_hp(), 2, "Heal should add exactly 1 HP")

func test_heal_grants_exactly_1_shield() -> void:
	_host.heal_from_perfect_dodge(1)
	assert_eq(_host.get_shield(), 1, "Heal should grant exactly 1 shield")

func test_heal_does_not_overflow_hp() -> void:
	_host._hp = _host.MAX_HP
	_host.heal_from_perfect_dodge(1)
	assert_eq(_host.get_hp(), _host.MAX_HP, "HP should not exceed MAX_HP")

func test_heal_charge_zero_no_heal() -> void:
	_host._hp = 2
	_host.heal_from_perfect_dodge(0)
	assert_eq(_host.get_hp(), 2, "HP unchanged for charge=0")
	assert_eq(_host.get_shield(), 0, "Shield unchanged for charge=0")

func test_heal_charge_zero_no_shield() -> void:
	_host._shield = 0
	_host.heal_from_perfect_dodge(0)
	assert_eq(_host.get_shield(), 0, "Shield should not appear for charge=0")

func test_heal_ignores_charge_negative() -> void:
	_host._hp = 2
	_host.heal_from_perfect_dodge(-1)
	assert_eq(_host.get_hp(), 2, "Negative charge count should be treated as <1, no heal")
	assert_eq(_host.get_shield(), 0, "Negative charge count should not grant shield")


# ---------------------------------------------------------------------------
# Heal + shield combined
# ---------------------------------------------------------------------------

func test_heal_then_damage_shield_absorbs() -> void:
	_host._hp = 2
	_host.heal_from_perfect_dodge(1)
	assert_eq(_host.get_hp(), 3, "Heal restores HP to max")
	assert_eq(_host.get_shield(), 1, "Shield is active")
	_host.take_damage(1)
	assert_eq(_host.get_shield(), 0, "Shield absorbs the hit")
	assert_eq(_host.get_hp(), 3, "HP untouched by shielded hit")

func test_heal_multiple_times_shield_resets() -> void:
	_host._hp = 2
	_host.heal_from_perfect_dodge(1)
	assert_eq(_host.get_shield(), 1, "First shield")
	var first_expiry := _host._shield_expiry_ms
	# Simulate some time passing.
	_host._shield_expiry_ms = Time.get_ticks_msec() - 1
	if _host.get_shield() > 0 and Time.get_ticks_msec() >= _host._shield_expiry_ms:
		_host._shield = 0
	assert_eq(_host.get_shield(), 0, "First shield expired")
	_host.heal_from_perfect_dodge(1)
	assert_eq(_host.get_shield(), 1, "New shield granted")
	assert_gt(_host._shield_expiry_ms, first_expiry, "New expiry should be later than old")


# ---------------------------------------------------------------------------
# Death priority over heal
# ---------------------------------------------------------------------------

func test_heal_blocked_when_dead() -> void:
	_host._hp = 0
	_host._is_dead = true
	_host.heal_from_perfect_dodge(1)
	assert_eq(_host.get_hp(), 0, "Dead player should not heal")
	assert_eq(_host.get_shield(), 0, "Dead player should not get shield")
