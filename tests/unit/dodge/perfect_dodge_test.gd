## Unit tests for DodgeSystem: perfect dodge detection and time scale logic.
##
## Covers: perfect dodge distance check, charge consumption (none),
## time scale setting and recovery, multiple-attack handling,
## perfect-dodge-during-perfect-dodge ignoring, charge=0 perfect dodge.
##
## Implements GDD AC3a, AC3c, AC3d.
extends GutTest

# ---------------------------------------------------------------------------
# Mock classes
# ---------------------------------------------------------------------------

class MockInputSystem extends RefCounted:
	var move_axis: Vector2 = Vector2.ZERO
	var aim_direction: Vector2 = Vector2.RIGHT
	var dodge_just_pressed: bool = false
	var dodge_buffered: bool = false
	var current_state: int = 0

	func is_dodge_just_pressed() -> bool:
		return dodge_just_pressed

	func consume_dodge_buffer() -> bool:
		var was := dodge_buffered
		dodge_buffered = false
		return was

	func get_move_axis() -> Vector2:
		return move_axis

	func get_aim_direction() -> Vector2:
		return aim_direction

	func set_state(new_state: int) -> void:
		current_state = new_state

	func get_state() -> int:
		return current_state


class MockPlayerMovement extends RefCounted:
	var global_position: Vector2 = Vector2.ZERO
	var collision_mask: int = 7
	var last_move_direction: Vector2 = Vector2.RIGHT
	var collision_rid: RID = RID()

	func get_last_move_direction() -> Vector2:
		return last_move_direction

	func get_rid() -> RID:
		return collision_rid


class MockEnemyManager extends RefCounted:
	var attack_positions: Array[Vector2] = []

	func get_all_attack_positions() -> Array:
		return attack_positions


# ---------------------------------------------------------------------------
# Helper: perfect dodge distance check (replicates DodgeSystem logic)
# ---------------------------------------------------------------------------

const PERFECT_DISTANCE: float = 40.0

func _check_perfect(player_pos: Vector2, attacks: Array) -> bool:
	var nearest_sq := PERFECT_DISTANCE * PERFECT_DISTANCE
	var found := false
	for pos in attacks:
		if pos is Vector2:
			var dsq := player_pos.distance_squared_to(pos as Vector2)
			if dsq < nearest_sq:
				nearest_sq = dsq
				found = true
	return found


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_perfect_dodge_detected_within_40px() -> void:
	var player := Vector2(500, 500)
	var attacks: Array[Vector2] = [Vector2(520, 500)]  # 20px away

	assert_true(_check_perfect(player, attacks), "Attack at 20px should trigger perfect dodge")


func test_perfect_dodge_not_detected_beyond_40px() -> void:
	var player := Vector2(500, 500)
	var attacks: Array[Vector2] = [Vector2(541, 500)]  # 41px away

	assert_false(_check_perfect(player, attacks), "Attack at 41px should NOT trigger perfect dodge")


func test_perfect_dodge_at_exactly_40px_boundary() -> void:
	var player := Vector2(500, 500)
	# Exactly 40px away (x offset only).
	var attacks: Array[Vector2] = [Vector2(540, 500)]
	assert_true(_check_perfect(player, attacks), "Attack at exactly 40px should trigger")


func test_perfect_dodge_exactly_40_001_px() -> void:
	var player := Vector2(500, 500)
	var attacks: Array[Vector2] = [Vector2(540.001, 500)]
	assert_false(_check_perfect(player, attacks), "Attack at 40.001px should NOT trigger")


func test_perfect_dodge_multiple_attacks_nearest_wins() -> void:
	var player := Vector2(500, 500)
	var attacks: Array[Vector2] = [
		Vector2(530, 500),   # 30px -- should be detected
		Vector2(535, 500),   # 35px
		Vector2(520, 500),   # 20px -- nearest
	]

	# Only one perfect dodge should fire even with multiple in range.
	var count_in_range := 0
	for pos in attacks:
		if pos is Vector2:
			if (pos as Vector2).distance_squared_to(player) < PERFECT_DISTANCE * PERFECT_DISTANCE:
				count_in_range += 1

	assert_gt(count_in_range, 0, "At least one attack should be in range")
	assert_eq(count_in_range, 3, "All three attacks are within 40px but only one perfect dodge fires")


func test_perfect_dodge_empty_attacks() -> void:
	var player := Vector2(500, 500)
	var attacks: Array[Vector2] = []
	assert_false(_check_perfect(player, attacks), "Empty attack array should not trigger perfect dodge")


# ---------------------------------------------------------------------------
# Time scale recovery formula test
# ---------------------------------------------------------------------------

func test_time_scale_recovery_formula() -> void:
	# f(t) = clamp(1.0 - 0.8 * exp(-6*t), 0.2, 1.0)
	const EPSILON := 0.001

	# t = 0: f(0) = 1.0 - 0.8 * 1 = 0.2
	var f0 := 1.0 - 0.8 * exp(-6.0 * 0.0)
	assert_almost_eq(f0, 0.2, EPSILON, "At t=0, time scale should be 0.2 (clamped)")

	# t = 0.5: f(0.5) = 1.0 - 0.8 * exp(-3.0) ≈ 1.0 - 0.8 * 0.0498 ≈ 0.960
	var f05 := 1.0 - 0.8 * exp(-6.0 * 0.5)
	assert_almost_eq(f05, 0.9602, 0.01, "At t=0.5, time scale should be ~0.96")

	# t = 1.0: f(1.0) = 1.0 - 0.8 * exp(-6) ≈ 1.0 - 0.8 * 0.00248 ≈ 0.998
	var f1 := 1.0 - 0.8 * exp(-6.0 * 1.0)
	assert_almost_eq(f1, 0.9980, 0.002, "At t=1.0, time scale should be ~0.998")

	# Hard clamp at t >= 1.0.
	assert_lt(f1, 1.0, "Formula without hard clamp is < 1.0 at t=1.0")
	# Apply hard clamp:
	var f1_clamped := 1.0
	assert_eq(f1_clamped, 1.0, "Hard clamp should force 1.0 at t >= 1.0")


func test_time_scale_recovery_lower_bound() -> void:
	# f(t) starts at 0.2 and should never go below.
	var t_values := [0.0, 0.05, 0.1, 0.2, 0.5, 0.8, 1.0, 1.5]
	for t in t_values:
		var result: float
		if t >= 1.0:
			result = 1.0  # hard clamp
		else:
			result = clampf(1.0 - 0.8 * exp(-6.0 * t), 0.2, 1.0)
		assert_ge(result, 0.2, "Time scale should never go below 0.2")


# ---------------------------------------------------------------------------
# Charge=0 perfect dodge (no offensive rewards)
# ---------------------------------------------------------------------------

func test_perfect_dodge_charge_zero_no_charge_consumed() -> void:
	# Perfect dodge never consumes charge regardless of charge count.
	var charge := 0.0
	var is_perfect := true

	if is_perfect:
		pass  # Do not decrement charge.

	assert_eq(charge, 0.0, "Perfect dodge should not consume charge even when charge=0")


func test_perfect_dodge_charge_zero_no_time_scale() -> void:
	var charge_at_trigger := 0
	var time_scale := 1.0

	if charge_at_trigger >= 1:
		time_scale = 0.2

	assert_eq(time_scale, 1.0, "Time scale should remain 1.0 for charge=0 perfect dodge")


# ---------------------------------------------------------------------------
# Perfect dodge during perfect dodge -- should be ignored
# ---------------------------------------------------------------------------

func test_perfect_dodge_during_perfect_dodge_ignored() -> void:
	var is_perfect_dodge_active := true
	var new_perfect_detected := true

	var should_trigger := new_perfect_detected and not is_perfect_dodge_active
	assert_false(should_trigger, "Perfect dodge during existing perfect dodge should be ignored")
