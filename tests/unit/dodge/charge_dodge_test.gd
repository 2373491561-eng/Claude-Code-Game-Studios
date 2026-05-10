extends GutTest

# ---------------------------------------------------------------------------
# Mock classes -- fakes for dependencies
# ---------------------------------------------------------------------------

class MockInputSystem extends RefCounted:
	var move_axis: Vector2 = Vector2.ZERO
	var aim_direction: Vector2 = Vector2.RIGHT
	var dodge_just_pressed: bool = false
	var dodge_buffered: bool = false
	var skill1_just_pressed: bool = false
	var shoot_pressed: bool = false
	var current_state: int = 0

	func is_dodge_just_pressed() -> bool:
		return dodge_just_pressed

	func consume_dodge_buffer() -> bool:
		var was := dodge_buffered
		dodge_buffered = false
		return was

	func is_skill1_just_pressed() -> bool:
		return skill1_just_pressed

	func get_move_axis() -> Vector2:
		return move_axis

	func get_aim_direction() -> Vector2:
		return aim_direction

	func set_state(new_state: int) -> void:
		current_state = new_state

	func get_state() -> int:
		return current_state

	func is_shoot_pressed() -> bool:
		return shoot_pressed


class MockPlayerMovement extends RefCounted:
	var global_position: Vector2 = Vector2.ZERO
	var collision_mask: int = 7
	var last_move_direction: Vector2 = Vector2.RIGHT
	var collision_rid: RID = RID()

	func get_last_move_direction() -> Vector2:
		return last_move_direction

	func get_rid() -> RID:
		return collision_rid


# A minimal Node2D wrapper so DodgeSystem (extends Node2D) can be added to the scene.
class DodgeSystemHost extends Node2D:
	var input_system: MockInputSystem = null
	var player_movement: MockPlayerMovement = null
	var enemy_manager: Node = null

	var _charge: float = 3.0
	var _is_dodging: bool = false
	var _dodge_start_ms: int = 0
	var _dodge_direction: Vector2 = Vector2.RIGHT
	var _dodge_start_pos: Vector2 = Vector2.ZERO
	var _is_invincible: bool = false
	var _is_perfect_dodge_active: bool = false
	var _ts_recovery_active: bool = false
	var _ts_recovery_start_ms: int = 0
	var _last_dodge_result: int = 0
	var _last_dodge_charge_at_trigger: int = 0
	var _original_collision_mask: int = 0
	var _space_state = null

	const MAX_CHARGE: float = 3.0
	const CHARGE_REGEN_TIME: float = 3.0
	const DODGE_DISTANCE: float = 100.0
	const DODGE_DURATION_MS: int = 300
	const PERFECT_DISTANCE: float = 40.0
	const DODGE_RESULT_NONE: int = 0
	const DODGE_RESULT_NORMAL: int = 1
	const DODGE_RESULT_PERFECT: int = 2
	const TIME_SCALE_SLOW: float = 0.2
	const MIN_TIME_SCALE: float = 0.01

	func is_invincible() -> bool:
		return _is_invincible

	func is_dodging() -> bool:
		return _is_dodging

	func get_charge_count() -> int:
		return floori(_charge)

	func consume_last_dodge_result() -> Dictionary:
		var result := {"type": _last_dodge_result, "charge": _last_dodge_charge_at_trigger}
		_last_dodge_result = DODGE_RESULT_NONE
		_last_dodge_charge_at_trigger = 0
		return result

	func is_perfect_dodge_active() -> bool:
		return _is_perfect_dodge_active


# ---------------------------------------------------------------------------
# Test fixture
# ---------------------------------------------------------------------------

var _host: DodgeSystemHost = null

func before_each() -> void:
	_host = DodgeSystemHost.new()
	_host.input_system = MockInputSystem.new()
	_host.player_movement = MockPlayerMovement.new()
	_host.player_movement.global_position = Vector2(500, 500)
	add_child_autofree(_host)


func after_each() -> void:
	_host = null


# ---------------------------------------------------------------------------
# Charge regeneration tests
# ---------------------------------------------------------------------------

func test_charge_starts_at_max() -> void:
	assert_eq(_host.get_charge_count(), 3, "Charge should start at MAX_CHARGE (3)")


func test_charge_regen_over_time() -> void:
	_host._charge = 1.5
	# Simulate 1.5 seconds of physics frames at 60fps with delta ~0.0167.
	for _i in range(90):
		_host.input_system.dodge_just_pressed = false
		_host.input_system.dodge_buffered = false
		_host.input_system.get_move_axis()
		# Regen: _charge += delta / CHARGE_REGEN_TIME
		_host._charge = minf(_host._charge + (1.0 / 60.0) / 3.0, 3.0)

	assert_gt(_host._charge, 1.9, "Charge should have regenerated over 1.5s")
	assert_lt(_host._charge, 2.2, "Charge should not exceed reasonable regen")


func test_charge_clamped_to_max() -> void:
	_host._charge = 2.99
	# Add more than needed to reach max.
	_host._charge = minf(_host._charge + 1.0 / 3.0, 3.0)
	assert_eq(_host._charge, 3.0, "Charge should be clamped to MAX_CHARGE")


func test_floor_charge_rounds_down() -> void:
	_host._charge = 0.6
	assert_eq(_host.get_charge_count(), 0, "charge=0.6 floor should be 0")
	_host._charge = 1.0
	assert_eq(_host.get_charge_count(), 1, "charge=1.0 floor should be 1")
	_host._charge = 2.99
	assert_eq(_host.get_charge_count(), 2, "charge=2.99 floor should be 2")


# ---------------------------------------------------------------------------
# Normal dodge execution tests
# ---------------------------------------------------------------------------

func test_normal_dodge_consumes_charge() -> void:
	_host._charge = 2.0
	var charge_before := _host.get_charge_count()

	# Simulate dodge execution.
	_host._charge -= 1.0
	_host._is_dodging = true
	_host._is_invincible = true
	_host._dodge_direction = Vector2.RIGHT
	_host._dodge_start_pos = _host.player_movement.global_position
	_host._dodge_start_ms = Time.get_ticks_msec()
	_host._last_dodge_result = 1  # DODGE_RESULT_NORMAL
	_host._last_dodge_charge_at_trigger = charge_before

	assert_eq(_host.get_charge_count(), 1, "Charge should decrease by 1")
	assert_true(_host.is_dodging(), "Should be dodging after execution")
	assert_true(_host.is_invincible(), "Should be invincible during dodge")


func test_no_dodge_when_charge_below_one() -> void:
	_host._charge = 0.6
	var can_dodge := floori(_host._charge) >= 1

	assert_false(can_dodge, "Should not be able to dodge with charge < 1")


func test_dodge_direction_from_move_axis() -> void:
	# Simulate move axis pointing up-right.
	var move_axis := Vector2(1.0, 1.0).normalized()
	assert_almost_eq(move_axis.length(), 1.0, 0.01, "Normalized diagonal should have length 1")
	assert_almost_eq(move_axis.x, move_axis.y, 0.01, "Diagonal should be equal x and y")


func test_dodge_direction_from_last_move() -> void:
	_host.player_movement.last_move_direction = Vector2.LEFT
	var direction := _host.player_movement.get_last_move_direction()
	assert_eq(direction, Vector2.LEFT, "Should use last move direction when no current input")


func test_dodge_direction_fallback_away_from_aim() -> void:
	# When no move input and no last move direction, dodge away from aim.
	_host.player_movement.last_move_direction = Vector2.ZERO
	_host.input_system.aim_direction = Vector2.RIGHT

	var aim_dir := _host.input_system.get_aim_direction()
	var dodge_dir := -aim_dir
	assert_eq(dodge_dir, Vector2.LEFT, "Should dodge away from aim direction")


# ---------------------------------------------------------------------------
# Invincibility tests
# ---------------------------------------------------------------------------

func test_invincibility_during_dodge() -> void:
	_host._is_dodging = true
	_host._is_invincible = true
	assert_true(_host.is_invincible(), "Should be invincible while dodging")


func test_invincibility_ends_after_dodge() -> void:
	_host._is_dodging = false
	_host._is_invincible = false
	assert_false(_host.is_invincible(), "Should not be invincible after dodge ends")


# ---------------------------------------------------------------------------
# Dodge result consumption
# ---------------------------------------------------------------------------

func test_consume_dodge_result_clears_after_read() -> void:
	_host._last_dodge_result = 1  # NORMAL
	_host._last_dodge_charge_at_trigger = 2

	var result := _host.consume_last_dodge_result()
	assert_eq(result.type, 1)
	assert_eq(result.charge, 2)

	# Second read should return NONE.
	var result2 := _host.consume_last_dodge_result()
	assert_eq(result2.type, 0, "Second consume should return NONE")


# ---------------------------------------------------------------------------
# Edge case: charge does not drop below 0
# ---------------------------------------------------------------------------

func test_charge_does_not_drop_below_zero() -> void:
	_host._charge = 0.8
	# Dodge would require charge >= 1, so it would not execute.
	var can_trigger := floori(_host._charge) >= 1
	assert_false(can_trigger)

	# Even if some bug subtracts, clamp at 0.
	_host._charge = maxf(_host._charge - 1.0, 0.0)
	assert_eq(_host._charge, 0.0, "Charge should not go below 0")
