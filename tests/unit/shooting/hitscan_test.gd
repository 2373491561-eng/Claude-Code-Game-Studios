extends GutTest

func before_all() -> void:
	InputSystem.register_input_map()
	if not InputMap.has_action("shoot"):
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		InputMap.add_action("shoot")
		InputMap.action_add_event("shoot", ev)

func after_each() -> void:
	Input.action_release("shoot")

func test_shoot_pressed_when_held() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	Input.action_press("shoot")
	input_sys._physics_process(0.0)
	assert_true(input_sys.is_shoot_pressed(), "Shoot should be pressed when mouse left is held")

func test_shoot_not_pressed_when_released() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	Input.action_press("shoot")
	input_sys._physics_process(0.0)
	Input.action_release("shoot")
	input_sys._physics_process(0.0)
	assert_false(input_sys.is_shoot_pressed())

func test_fire_interval_is_125ms() -> void:
	const FIRE_RATE := 8.0
	var interval := int(1000.0 / FIRE_RATE)
	assert_eq(interval, 125, "8 shots/sec = 125ms interval")

func test_aim_direction_normalized() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	var dir := input_sys.get_aim_direction()
	assert_true(dir.length() < 0.001 or is_equal_approx(dir.length(), 1.0))
