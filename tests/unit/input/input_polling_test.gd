extends GutTest

# Acceptance criteria tests for Story 001: Input Map + Core Polling.
#
# These tests validate:
#   1. Input Map registration creates all expected actions (AC 1)
#   2. get_move_axis() returns correct Vector2 for WASD (AC 2)
#   3. Action mappings are correct (AC 3)
#   4. _physics_process() polls all actions (AC 4)
#   5. All 6 public methods return correct types (AC 5)
#   6. get_aim_direction() normalization + zero-vector safety (AC 6)

# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------

func before_all() -> void:
	# Ensure actions exist for the entire test suite.
	InputSystem.register_input_map()

func after_each() -> void:
	# Release all actions to avoid state leaking between tests.
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_up")
	Input.action_release("move_down")
	Input.action_release("shoot")
	Input.action_release("dodge")
	Input.action_release("skill_1")
	Input.action_release("pause")

# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

func _make_dodge_press_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_SHIFT
	event.pressed = true
	return event

# ---------------------------------------------------------------------------
# AC 1: Input Map registration
# ---------------------------------------------------------------------------

func test_input_map_register_creates_all_move_actions() -> void:
	assert_true(InputMap.has_action("move_left"))
	assert_true(InputMap.has_action("move_right"))
	assert_true(InputMap.has_action("move_up"))
	assert_true(InputMap.has_action("move_down"))

func test_input_map_register_creates_all_game_actions() -> void:
	assert_true(InputMap.has_action("shoot"))
	assert_true(InputMap.has_action("dodge"))
	assert_true(InputMap.has_action("skill_1"))
	assert_true(InputMap.has_action("pause"))

func test_input_map_register_is_idempotent() -> void:
	var dodge_events_before := InputMap.action_get_events("dodge").size()
	InputSystem.register_input_map()
	var dodge_events_after := InputMap.action_get_events("dodge").size()
	assert_eq(dodge_events_after, dodge_events_before)

func test_dodge_action_has_dual_channel_bindings() -> void:
	var events := InputMap.action_get_events("dodge")
	var has_shift := false
	var has_right_click := false
	for ev in events:
		if ev is InputEventKey and ev.keycode == KEY_SHIFT:
			has_shift = true
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_RIGHT:
			has_right_click = true
	assert_true(has_shift)
	assert_true(has_right_click)

# ---------------------------------------------------------------------------
# AC 2: move axis output
# ---------------------------------------------------------------------------

func test_get_move_axis_returns_zero_by_default() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	input_sys._physics_process(0.0)
	assert_eq(input_sys.get_move_axis(), Vector2.ZERO)

func test_get_move_axis_right_returns_positive_x() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	Input.action_press("move_right")
	input_sys._physics_process(0.0)
	assert_true(input_sys.get_move_axis().x > 0.0)
	assert_eq(input_sys.get_move_axis().y, 0.0)

func test_get_move_axis_diagonal_returns_both_axes() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	Input.action_press("move_right")
	Input.action_press("move_up")
	input_sys._physics_process(0.0)
	var axis := input_sys.get_move_axis()
	assert_true(axis.x > 0.0)
	assert_true(axis.y < 0.0)

# ---------------------------------------------------------------------------
# AC 3: Action bindings
# ---------------------------------------------------------------------------

func test_shoot_action_bound_to_mouse_left() -> void:
	var has_left := false
	for ev in InputMap.action_get_events("shoot"):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			has_left = true
	assert_true(has_left)

func test_skill1_action_bound_to_space() -> void:
	var has_space := false
	for ev in InputMap.action_get_events("skill_1"):
		if ev is InputEventKey and ev.keycode == KEY_SPACE:
			has_space = true
	assert_true(has_space)

func test_pause_action_bound_to_escape() -> void:
	var has_esc := false
	for ev in InputMap.action_get_events("pause"):
		if ev is InputEventKey and ev.keycode == KEY_ESCAPE:
			has_esc = true
	assert_true(has_esc)

# ---------------------------------------------------------------------------
# AC 4: _physics_process() polls all actions
# ---------------------------------------------------------------------------

func test_physics_process_polls_shoot_pressed() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	Input.action_press("shoot")
	input_sys._physics_process(0.0)
	assert_true(input_sys.is_shoot_pressed())

func test_physics_process_polls_shoot_released() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	Input.action_press("shoot")
	input_sys._physics_process(0.0)
	Input.action_release("shoot")
	input_sys._physics_process(0.0)
	assert_false(input_sys.is_shoot_pressed())

func test_physics_process_polls_dodge_just_pressed() -> void:
	# Per ADR-0002, dodge is detected via _input() → _process_dodge(),
	# not via direct Input.action_press(). Pass an InputEventKey to
	# _input() to surface the press through the debounce pipeline.
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	var event := _make_dodge_press_event()
	input_sys._input(event)
	input_sys._physics_process(0.0)
	assert_true(input_sys.is_dodge_just_pressed())

func test_physics_process_dodge_not_just_pressed_second_tick() -> void:
	# Per ADR-0002, _dodge_just_pressed is reset at the top of each
	# _physics_process(). Without a new _input() event between ticks,
	# _process_dodge() has nothing queued and the flag stays false.
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	var event := _make_dodge_press_event()
	input_sys._input(event)
	input_sys._physics_process(0.0)
	input_sys._physics_process(0.0)
	assert_false(input_sys.is_dodge_just_pressed())

func test_physics_process_polls_skill1_just_pressed() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	Input.action_press("skill_1")
	input_sys._physics_process(0.0)
	assert_true(input_sys.is_skill1_just_pressed())

func test_physics_process_polls_pause_just_pressed() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	Input.action_press("pause")
	input_sys._physics_process(0.0)
	assert_true(input_sys.is_pause_just_pressed())

# ---------------------------------------------------------------------------
# AC 5: Return types
# ---------------------------------------------------------------------------

func test_all_public_methods_return_correct_types() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	input_sys._physics_process(0.0)
	assert_true(input_sys.get_move_axis() is Vector2)
	assert_true(input_sys.get_aim_direction() is Vector2)
	assert_true(input_sys.is_shoot_pressed() is bool)
	assert_true(input_sys.is_dodge_just_pressed() is bool)
	assert_true(input_sys.is_skill1_just_pressed() is bool)
	assert_true(input_sys.is_pause_just_pressed() is bool)

func test_aim_direction_in_range() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	var result := input_sys.get_aim_direction()
	assert_true(result.x >= -1.0 and result.x <= 1.0)
	assert_true(result.y >= -1.0 and result.y <= 1.0)

# ---------------------------------------------------------------------------
# AC 6: Aim direction zero-vector safety
# ---------------------------------------------------------------------------

func test_aim_direction_zero_when_no_player() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	input_sys._physics_process(0.0)
	assert_eq(input_sys.get_aim_direction(), Vector2.ZERO)

func test_aim_direction_zero_for_zero_length() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	var player := Node2D.new()
	player.position = Vector2.ZERO
	add_child_autofree(player)
	input_sys.player_node = player
	input_sys._physics_process(0.0)
	assert_eq(input_sys.get_aim_direction(), Vector2.ZERO)

func test_aim_direction_normalized_when_nonzero() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	var player := Node2D.new()
	player.position = Vector2.ZERO
	add_child_autofree(player)
	input_sys.player_node = player
	input_sys._physics_process(0.0)
	var length := input_sys.get_aim_direction().length()
	assert_true(length < 0.001 or is_equal_approx(length, 1.0))
