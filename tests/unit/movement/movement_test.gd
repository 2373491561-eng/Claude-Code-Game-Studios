extends GutTest

func before_all() -> void:
	InputSystem.register_input_map()

func after_each() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_up")
	Input.action_release("move_down")

func test_movement_w_key_moves_up() -> void:
	var player := PlayerMovement.new()
	add_child_autofree(player)
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	input_sys._physics_process(0.0)
	Input.action_press("move_up")
	input_sys._physics_process(0.0)
	var axis := input_sys.get_move_axis()
	assert_true(axis.y < 0.0, "W should produce negative y (up)")

func test_movement_diagonal_normalized() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	Input.action_press("move_right")
	Input.action_press("move_up")
	input_sys._physics_process(0.0)
	var axis := input_sys.get_move_axis()
	assert_true(axis.length() <= 1.0, "Diagonal axis should be normalized, got length %f" % axis.length())

func test_movement_zero_by_default() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	input_sys._physics_process(0.0)
	assert_eq(input_sys.get_move_axis(), Vector2.ZERO)

func test_movement_reverse_instant() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	Input.action_press("move_up")
	input_sys._physics_process(0.0)
	assert_true(input_sys.get_move_axis().y < 0.0)
	Input.action_release("move_up")
	Input.action_press("move_down")
	input_sys._physics_process(0.0)
	assert_true(input_sys.get_move_axis().y > 0.0, "Instant reverse should work")
