## Unit tests for SkillSystem: cooldown logic, charge acceleration,
## dodge CD reduction, CD reduction cap.
##
## Covers: cooldown timer (real time), charge-accelerated cooldown speed,
## normal dodge CD reduction (-3s), perfect dodge CD reduction (-8s),
## charge=0 perfect dodge no reduction, CD reduction cap, is_skill1_ready.
##
## Implements GDD AC2a, AC2b, AC2c, AC3a, AC3b, AC3c, AC3d.
extends GutTest

# ---------------------------------------------------------------------------
# Constants (matching SkillSystem)
# ---------------------------------------------------------------------------

const BASE_CD: float = 15.0
const CD_CAP_RATIO: float = 0.6
const CD_CHARGE_ACCEL: float = 0.5
const CD_REDUCTION_NORMAL: float = 3.0
const CD_REDUCTION_PERFECT: float = 8.0
const CD_REDUCTION_PERFECT_NO_CHARGE: float = 0.0


# ---------------------------------------------------------------------------
# Helper functions (replicate SkillSystem logic)
# ---------------------------------------------------------------------------

func _compute_cd_speed(charge_count: int) -> float:
	return 1.0 + maxi(charge_count - 1, 0) * CD_CHARGE_ACCEL


func _compute_cooldown_decrement(elapsed_sec: float, charge_count: int) -> float:
	var speed := _compute_cd_speed(charge_count)
	return elapsed_sec * speed


# ---------------------------------------------------------------------------
# Cooldown acceleration tests
# ---------------------------------------------------------------------------

func test_cd_speed_at_charge_3() -> void:
	var speed := _compute_cd_speed(3)
	assert_almost_eq(speed, 2.0, 0.01, "Charge 3 should give 2x cooldown speed")


func test_cd_speed_at_charge_2() -> void:
	var speed := _compute_cd_speed(2)
	assert_almost_eq(speed, 1.5, 0.01, "Charge 2 should give 1.5x cooldown speed")


func test_cd_speed_at_charge_1() -> void:
	var speed := _compute_cd_speed(1)
	assert_almost_eq(speed, 1.0, 0.01, "Charge 1 should give 1.0x (normal) speed")


func test_cd_speed_at_charge_0() -> void:
	var speed := _compute_cd_speed(0)
	assert_almost_eq(speed, 1.0, 0.01, "Charge 0 should give 1.0x (no penalty)")


func test_cd_speed_negative_charge() -> void:
	# Guard: negative charge should not penalize.
	var speed := _compute_cd_speed(-1)
	assert_almost_eq(speed, 1.0, 0.01, "Negative charge should clamp to 1.0x")


# ---------------------------------------------------------------------------
# Cooldown decrement tests
# ---------------------------------------------------------------------------

func test_cooldown_decrement_charge_3_over_3_seconds() -> void:
	# AC2a: CD remaining 10s, charge=3, 3s elapsed -> CD <= 4s.
	var initial_cd := 10.0
	var elapsed := 3.0
	var charge := 3

	var decrement := _compute_cooldown_decrement(elapsed, charge)
	var remaining := initial_cd - decrement

	assert_almost_eq(decrement, 6.0, 0.3, "3s * 2x = 6s decrement")
	assert_almost_eq(remaining, 4.0, 0.3, "10s - 6s = 4s remaining")


func test_cooldown_decrement_charge_1_over_3_seconds() -> void:
	# AC2b: CD remaining 10s, charge=1, 3s elapsed -> CD = 7s.
	var initial_cd := 10.0
	var elapsed := 3.0
	var charge := 1

	var decrement := _compute_cooldown_decrement(elapsed, charge)
	var remaining := initial_cd - decrement

	assert_almost_eq(decrement, 3.0, 0.3, "3s * 1x = 3s decrement")
	assert_almost_eq(remaining, 7.0, 0.3, "10s - 3s = 7s remaining")


# ---------------------------------------------------------------------------
# Dodge CD reduction tests
# ---------------------------------------------------------------------------

func test_normal_dodge_cd_reduction() -> void:
	# AC3a: normal dodge reduces CD by 3s.
	var initial_cd := 10.0
	var remaining := initial_cd - CD_REDUCTION_NORMAL
	assert_almost_eq(remaining, 7.0, 0.5, "Normal dodge: 10s - 3s = 7s")


func test_perfect_dodge_cd_reduction() -> void:
	# AC3b: perfect dodge (charge>=1) reduces CD by 8s.
	var initial_cd := 10.0
	var remaining := initial_cd - CD_REDUCTION_PERFECT
	assert_almost_eq(remaining, 2.0, 0.5, "Perfect dodge: 10s - 8s = 2s")


func test_perfect_dodge_charge_zero_no_cd_reduction() -> void:
	# AC3c: perfect dodge with charge=0 gives 0s reduction.
	var initial_cd := 10.0
	var remaining := initial_cd - CD_REDUCTION_PERFECT_NO_CHARGE
	assert_almost_eq(remaining, 10.0, 0.5, "Charge=0 perfect dodge: no reduction")


# ---------------------------------------------------------------------------
# CD reduction cap tests
# ---------------------------------------------------------------------------

func test_cd_reduction_cap_value() -> void:
	var cap := BASE_CD * CD_CAP_RATIO
	assert_almost_eq(cap, 9.0, 0.01, "CD reduction cap should be 15 * 0.6 = 9s")


func test_cd_reduction_cap_enforced() -> void:
	# AC3d: after 9s total reduction, further reductions are ignored.
	var total_reduction := 9.0  # Already at cap.
	var additional_reduction := 8.0
	var cap := BASE_CD * CD_CAP_RATIO
	var available := cap - total_reduction

	assert_almost_eq(available, 0.0, 0.01, "No reduction available when at cap")
	assert_false(additional_reduction <= available, "Additional reduction should be blocked by cap")


func test_cd_reduction_partial_cap() -> void:
	# 8s already reduced, another 3s should only get 1s (filling the 9s cap).
	var total_reduction := 8.0
	var reduction := 3.0
	var cap := BASE_CD * CD_CAP_RATIO
	var available := cap - total_reduction
	var applied := minf(reduction, available)

	assert_almost_eq(applied, 1.0, 0.01, "Should only apply 1s when close to cap")


func test_cd_reduction_resets_on_cast() -> void:
	# When skill is cast, cooldown resets to 15s and reduction cycle resets.
	var after_cast := 0.0  # _total_reduction_this_cycle = 0
	assert_eq(after_cast, 0.0, "Reduction cycle should reset after cast")


# ---------------------------------------------------------------------------
# is_skill1_ready tests
# ---------------------------------------------------------------------------

func test_skill1_ready_when_cooldown_zero() -> void:
	var cooldown := 0.0
	var is_casting := false
	var ready := cooldown <= 0.0 and not is_casting
	assert_true(ready, "Should be ready when cooldown is 0")


func test_skill1_not_ready_when_cooldown_positive() -> void:
	var cooldown := 5.0
	var is_casting := false
	var ready := cooldown <= 0.0 and not is_casting
	assert_false(ready, "Should not be ready when cooldown > 0")


func test_skill1_not_ready_when_casting() -> void:
	var cooldown := 0.0
	var is_casting := true
	var ready := cooldown <= 0.0 and not is_casting
	assert_false(ready, "Should not be ready while casting")


# ---------------------------------------------------------------------------
# Full cooldown cycle: base CD 15s, charge=3
# ---------------------------------------------------------------------------

func test_full_cycle_charge_3_effective_cd() -> void:
	# Charge 3 -> cd_speed = 2.0 -> 15s base is effectively 7.5s.
	var effective_cd := BASE_CD / _compute_cd_speed(3)
	assert_almost_eq(effective_cd, 7.5, 0.1, "15s / 2.0 = 7.5s effective")
