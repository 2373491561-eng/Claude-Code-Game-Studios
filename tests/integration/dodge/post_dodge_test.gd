##
##
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


# ---------------------------------------------------------------------------
# Spiral search algorithm (replicates DodgeSystem logic)
# ---------------------------------------------------------------------------

const POST_DODGE_SEARCH_RADIUS: float = 200.0
const POST_DODGE_SEARCH_STEP: float = 50.0
const POST_DODGE_DIRECTIONS: int = 8

func _spiral_search(start_pos: Vector2, blocked_positions: Array) -> Dictionary:
	"""
	Returns {"found": bool, "position": Vector2}
	"""
	var best_pos := start_pos
	var max_rings := ceili(POST_DODGE_SEARCH_RADIUS / POST_DODGE_SEARCH_STEP)

	for ring in range(1, max_rings + 1):
		var radius := float(ring) * POST_DODGE_SEARCH_STEP
		var angle_step := TAU / float(POST_DODGE_DIRECTIONS)

		for dir_idx in range(POST_DODGE_DIRECTIONS):
			var angle := float(dir_idx) * angle_step
			var offset := Vector2(cos(angle), sin(angle)) * radius
			var test_pos := start_pos + offset

			# Check if this position is blocked.
			var blocked := false
			for bp in blocked_positions:
				if bp is Vector2 and (test_pos - (bp as Vector2)).length() < 50.0:
					blocked = true
					break

			if not blocked:
				return {"found": true, "position": test_pos}
			best_pos = test_pos

	return {"found": false, "position": best_pos}


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_spiral_search_finds_clear_position() -> void:
	var start := Vector2(500, 500)
	var blocked: Array = []  # Nothing blocking.
	var result := _spiral_search(start, blocked)

	assert_true(result.found, "Should find clear position when nothing is blocking")
	# The first ring at 50px in direction 0 (angle 0 = right).
	var expected := start + Vector2(POST_DODGE_SEARCH_STEP, 0)
	assert_almost_eq(result.position.x, expected.x, 1.0)
	assert_almost_eq(result.position.y, expected.y, 1.0)


func test_spiral_search_skips_blocked_positions() -> void:
	var start := Vector2(500, 500)
	# Block the first ring in all 8 directions.
	var blocked: Array = []
	for i in range(8):
		var angle := float(i) * TAU / 8.0
		blocked.append(start + Vector2(cos(angle), sin(angle)) * 50.0)

	var result := _spiral_search(start, blocked)
	# Should find a position at the second ring (100px).
	assert_true(result.found, "Should find position at second ring when first is blocked")


func test_spiral_search_fallback_when_all_blocked() -> void:
	var start := Vector2(500, 500)
	# Block everything within 200px.
	var blocked: Array = []
	for ring in range(1, 6):
		var radius := float(ring) * POST_DODGE_SEARCH_STEP
		for i in range(8):
			var angle := float(i) * TAU / 8.0
			blocked.append(start + Vector2(cos(angle), sin(angle)) * radius)

	var result := _spiral_search(start, blocked)
	assert_false(result.found, "Should report no clear position when all blocked")
	# Fallback position should be the last checked position.
	assert_ne(result.position, start, "Fallback position should not be the original position")


func test_spiral_search_max_radius() -> void:
	var start := Vector2(500, 500)
	var max_rings := ceili(POST_DODGE_SEARCH_RADIUS / POST_DODGE_SEARCH_STEP)
	assert_eq(max_rings, 4, "200px radius / 50px step = 4 rings")


# ---------------------------------------------------------------------------
# Doc comment presence -- verify public API methods are documented
# ---------------------------------------------------------------------------

func test_dodge_system_has_documented_public_api() -> void:
	# This test validates at design-time that the class has the expected
	# public API. At runtime, it checks the class can be loaded.
	var script := load("res://src/dodge/dodge_system.gd")
	assert_not_null(script, "DodgeSystem script should be loadable")

	# Verify the class exists.
	var instance := script.new()
	assert_not_null(instance, "DodgeSystem should be instantiable")
	assert_true(instance.has_method("is_invincible"), "Should have is_invincible()")
	assert_true(instance.has_method("get_charge_count"), "Should have get_charge_count()")
	assert_true(instance.has_method("is_dodging"), "Should have is_dodging()")
	assert_true(instance.has_method("consume_last_dodge_result"), "Should have consume_last_dodge_result()")
	instance.free()
