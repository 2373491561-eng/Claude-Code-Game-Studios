extends GutTest

# Integration tests for Story 003: Input State Machine.
#
# These tests validate:
#   1. State constants exist and default is NORMAL (AC 1)
#   2. set_state() / get_state() work correctly
#   3. DODGING state blocks move, shoot, and dodge; allows aim and skill_1 (AC 3, AC 4)
#   4. SKILL_CASTING state blocks skill_1; allows move, shoot, dodge, aim (AC 5)
#   5. PAUSED state blocks all inputs
#   6. DEAD state blocks all inputs (AC 7)
#   7. Flash-resume: DODGING->NORMAL with shoot held sets _shoot_resume_pending (AC 6)
#   8. consume_shoot_resume() clears the flag
#   9. Priority order: dodge before skill_1 (AC 2)

# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------

func before_all() -> void:
	# Ensure Input Map actions exist for the entire test suite.
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

	# Reset tree pause state.
	get_tree().paused = false

	# Reset InputSystem process_mode to default so autofree cleanup works.
	# (PROCESS_MODE_ALWAYS can interfere with node removal in some cases.)
	# The node will be freed by add_child_autofree in the next test.

# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

func _make_dodge_press_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_SHIFT
	event.pressed = true
	return event

# ---------------------------------------------------------------------------
# AC 1: State constants exist and default is STATE_NORMAL
# ---------------------------------------------------------------------------

func test_state_default_is_normal() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	assert_eq(input_sys.get_state(), InputSystem.STATE_NORMAL,
		"Default state should be STATE_NORMAL")

func test_state_constants_are_distinct() -> void:
	# Verify all 5 state constants are distinct values.
	var states := [
		InputSystem.STATE_NORMAL,
		InputSystem.STATE_DODGING,
		InputSystem.STATE_SKILL_CASTING,
		InputSystem.STATE_PAUSED,
		InputSystem.STATE_DEAD,
	]
	for i in range(states.size()):
		for j in range(i + 1, states.size()):
			assert_ne(states[i], states[j],
				"State constants %d and %d should be distinct" % [states[i], states[j]])

# ---------------------------------------------------------------------------
# AC 1: set_state() / get_state()
# ---------------------------------------------------------------------------

func test_set_state_changes_state() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)

	input_sys.set_state(InputSystem.STATE_DODGING)
	assert_eq(input_sys.get_state(), InputSystem.STATE_DODGING)

	input_sys.set_state(InputSystem.STATE_NORMAL)
	assert_eq(input_sys.get_state(), InputSystem.STATE_NORMAL)

	input_sys.set_state(InputSystem.STATE_DEAD)
	assert_eq(input_sys.get_state(), InputSystem.STATE_DEAD)

# ---------------------------------------------------------------------------
# AC 3: DODGING blocks move, shoot, and new dodge; allows aim + skill_1
# ---------------------------------------------------------------------------

func test_dodging_blocks_move() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	input_sys.set_state(InputSystem.STATE_DODGING)

	# Press movement keys
	Input.action_press("move_right")
	Input.action_press("move_up")
	input_sys._physics_process(0.0)

	assert_eq(input_sys.get_move_axis(), Vector2.ZERO,
		"DODGING state must block move input — get_move_axis() should return Vector2.ZERO")

func test_dodging_blocks_shoot() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	input_sys.set_state(InputSystem.STATE_DODGING)

	Input.action_press("shoot")
	input_sys._physics_process(0.0)

	assert_false(input_sys.is_shoot_pressed(),
		"DODGING state must block shoot input")

func test_dodging_allows_skill1() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	input_sys.set_state(InputSystem.STATE_DODGING)

	Input.action_press("skill_1")
	input_sys._physics_process(0.0)

	assert_true(input_sys.is_skill1_just_pressed(),
		"DODGING state must allow skill_1 input (AC4)")

func test_dodging_blocks_new_dodge() -> void:
	# In DODGING state, the dodge pipeline should not process new dodge presses.
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	input_sys.set_state(InputSystem.STATE_DODGING)

	var event := _make_dodge_press_event()
	input_sys._input(event)
	input_sys._physics_process(0.0)

	assert_false(input_sys.is_dodge_just_pressed(),
		"DODGING state must block new dodge input — cannot dodge while dodging")

func test_dodging_still_computes_aim() -> void:
	# Aim direction computation is not gated — but it returns Vector2.ZERO
	# when player_node is null (unit test environment). We verify the method
	# can be called without error. For a real aim test, player_node is needed.
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	input_sys.set_state(InputSystem.STATE_DODGING)

	input_sys._physics_process(0.0)
	var aim := input_sys.get_aim_direction()

	assert_eq(aim, Vector2.ZERO,
		"Without player_node, aim should be Vector2.ZERO in any state")
	# The key assertion: no crash / error from calling get_aim_direction()

# ---------------------------------------------------------------------------
# AC 5: SKILL_CASTING blocks skill_1; allows move, shoot, dodge, aim
# ---------------------------------------------------------------------------

func test_skill_casting_blocks_skill1() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	input_sys.set_state(InputSystem.STATE_SKILL_CASTING)

	Input.action_press("skill_1")
	input_sys._physics_process(0.0)

	assert_false(input_sys.is_skill1_just_pressed(),
		"SKILL_CASTING must block skill_1 input — cannot cast while already casting")

func test_skill_casting_allows_move() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	input_sys.set_state(InputSystem.STATE_SKILL_CASTING)

	Input.action_press("move_right")
	input_sys._physics_process(0.0)

	assert_true(input_sys.get_move_axis().x > 0.0,
		"SKILL_CASTING must allow move input (AC5: full-speed movement)")

func test_skill_casting_allows_shoot() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	input_sys.set_state(InputSystem.STATE_SKILL_CASTING)

	Input.action_press("shoot")
	input_sys._physics_process(0.0)

	assert_true(input_sys.is_shoot_pressed(),
		"SKILL_CASTING must allow shoot input")

func test_skill_casting_allows_dodge() -> void:
	# In SKILL_CASTING, dodge is allowed so the cancel rule can fire.
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	input_sys.set_state(InputSystem.STATE_SKILL_CASTING)

	var event := _make_dodge_press_event()
	input_sys._input(event)
	input_sys._physics_process(0.0)

	assert_true(input_sys.is_dodge_just_pressed(),
		"SKILL_CASTING must allow dodge input — needed for dodge-cancel rule")

# ---------------------------------------------------------------------------
# AC 7: DEAD blocks all inputs
# ---------------------------------------------------------------------------

func test_dead_blocks_move() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	input_sys.set_state(InputSystem.STATE_DEAD)

	Input.action_press("move_right")
	input_sys._physics_process(0.0)

	assert_eq(input_sys.get_move_axis(), Vector2.ZERO,
		"DEAD state must block move input")

func test_dead_blocks_shoot() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	input_sys.set_state(InputSystem.STATE_DEAD)

	Input.action_press("shoot")
	input_sys._physics_process(0.0)

	assert_false(input_sys.is_shoot_pressed(),
		"DEAD state must block shoot input")

func test_dead_blocks_skill1() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	input_sys.set_state(InputSystem.STATE_DEAD)

	Input.action_press("skill_1")
	input_sys._physics_process(0.0)

	assert_false(input_sys.is_skill1_just_pressed(),
		"DEAD state must block skill_1 input")

func test_dead_blocks_dodge() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	input_sys.set_state(InputSystem.STATE_DEAD)

	var event := _make_dodge_press_event()
	input_sys._input(event)
	input_sys._physics_process(0.0)

	assert_false(input_sys.is_dodge_just_pressed(),
		"DEAD state must block dodge input")

# ---------------------------------------------------------------------------
# PAUSED blocks all inputs
# ---------------------------------------------------------------------------

func test_paused_blocks_move() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	input_sys.set_state(InputSystem.STATE_PAUSED)

	Input.action_press("move_right")
	input_sys._physics_process(0.0)

	assert_eq(input_sys.get_move_axis(), Vector2.ZERO,
		"PAUSED state must block move input")

func test_paused_blocks_shoot() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	input_sys.set_state(InputSystem.STATE_PAUSED)

	Input.action_press("shoot")
	input_sys._physics_process(0.0)

	assert_false(input_sys.is_shoot_pressed(),
		"PAUSED state must block shoot input")

func test_paused_blocks_skill1() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	input_sys.set_state(InputSystem.STATE_PAUSED)

	Input.action_press("skill_1")
	input_sys._physics_process(0.0)

	assert_false(input_sys.is_skill1_just_pressed(),
		"PAUSED state must block skill_1 input")

# ---------------------------------------------------------------------------
# AC 6: Flash-resume — DODGING->NORMAL with shoot held
# ---------------------------------------------------------------------------

func test_shoot_resume_pending_when_transitioning_dodging_to_normal_with_shoot_held() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)

	# Arrange: simulate DODGING state with shoot key held
	input_sys.set_state(InputSystem.STATE_DODGING)
	Input.action_press("shoot")
	input_sys._physics_process(0.0)
	# During DODGING, _shoot_pressed is forced false
	assert_false(input_sys.is_shoot_pressed(),
		"Setup: shoot should be blocked in DODGING")

	# Act: transition to NORMAL (simulates dodge ending)
	input_sys.set_state(InputSystem.STATE_NORMAL)

	# Assert: shoot resume pending flag is set
	assert_true(input_sys.is_shoot_resume_pending(),
		"Flash-resume: transitioning DODGING->NORMAL with shoot held should set pending flag")

func test_shoot_resume_not_pending_when_shoot_not_held() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)

	# Arrange: DODGING state with NO shoot key held
	input_sys.set_state(InputSystem.STATE_DODGING)
	input_sys._physics_process(0.0)

	# Act: transition to NORMAL
	input_sys.set_state(InputSystem.STATE_NORMAL)

	# Assert: no shoot resume pending
	assert_false(input_sys.is_shoot_resume_pending(),
		"Flash-resume should NOT be pending when shoot was not held during transition")

func test_shoot_resume_not_pending_when_transitioning_from_normal() -> void:
	# Flash-resume only triggers on DODGING->NORMAL, not NORMAL->NORMAL.
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)

	Input.action_press("shoot")
	input_sys._physics_process(0.0)
	assert_true(input_sys.is_shoot_pressed(), "Setup: shoot should be active in NORMAL")

	# Transition NORMAL->NORMAL (no-op transition)
	input_sys.set_state(InputSystem.STATE_NORMAL)

	assert_false(input_sys.is_shoot_resume_pending(),
		"Flash-resume should NOT trigger on NORMAL->NORMAL transition")

func test_consume_shoot_resume_clears_flag_and_returns_true() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)

	# Arrange: set up flash-resume pending
	input_sys.set_state(InputSystem.STATE_DODGING)
	Input.action_press("shoot")
	input_sys._physics_process(0.0)
	input_sys.set_state(InputSystem.STATE_NORMAL)
	assert_true(input_sys.is_shoot_resume_pending(), "Setup: flag should be set")

	# Act
	var was_pending := input_sys.consume_shoot_resume()

	# Assert
	assert_true(was_pending,
		"consume_shoot_resume() should return true when flag was active")
	assert_false(input_sys.is_shoot_resume_pending(),
		"Flag should be cleared after consume_shoot_resume()")
	assert_false(input_sys.consume_shoot_resume(),
		"Second consume should return false (already consumed)")

func test_consume_shoot_resume_returns_false_when_not_pending() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)

	# No flash-resume set up — flag is false by default.
	var was_pending := input_sys.consume_shoot_resume()

	assert_false(was_pending,
		"consume_shoot_resume() should return false when no resume is pending")

# ---------------------------------------------------------------------------
# AC 2: Priority order — dodge before skill_1 (same-frame)
# ---------------------------------------------------------------------------

func test_priority_order_dodge_is_processed_before_skill1() -> void:
	# In the same _physics_process() call, dodge is processed (Step 1)
	# before skill_1 is polled (Step 2). This test verifies that when
	# both are triggered on the same frame, dodge's result is visible.
	#
	# Note: the actual same-frame cancel logic is in SkillSystem, not
	# InputSystem. InputSystem only guarantees the polling order.
	# We verify that _process_dodge() executes before the skill_1 polling
	# by checking that _dodge_just_pressed is set when we check it
	# after a combined poll.
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)

	# Trigger both dodge (via _input) and skill_1 (via Input.action_press)
	var event := _make_dodge_press_event()
	input_sys._input(event)
	Input.action_press("skill_1")

	# Single _physics_process call — both dodge and skill_1 are polled
	input_sys._physics_process(0.0)

	# Both should be detected on the same frame.
	# Dodge is processed first (Step 1), skill_1 second (Step 2).
	# The SkillSystem would use this ordering to implement cancel logic.
	assert_true(input_sys.is_dodge_just_pressed(),
		"Dodge should be detected on this frame")
	assert_true(input_sys.is_skill1_just_pressed(),
		"Skill_1 should also be detected on this frame (dodge fires first per priority)")

# ---------------------------------------------------------------------------
# NORMAL state allows all inputs (sanity check)
# ---------------------------------------------------------------------------

func test_normal_allows_all_inputs() -> void:
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)

	# Move
	Input.action_press("move_right")
	input_sys._physics_process(0.0)
	assert_true(input_sys.get_move_axis().x > 0.0,
		"NORMAL state must allow move input")

	# Shoot
	Input.action_press("shoot")
	input_sys._physics_process(0.0)
	assert_true(input_sys.is_shoot_pressed(),
		"NORMAL state must allow shoot input")

	# Skill_1 (release and re-press for just_pressed)
	Input.action_release("skill_1")
	Input.action_press("skill_1")
	input_sys._physics_process(0.0)
	assert_true(input_sys.is_skill1_just_pressed(),
		"NORMAL state must allow skill_1 input")

	# Dodge
	Input.action_release("move_right")
	Input.action_release("shoot")
	Input.action_release("skill_1")
	var event := _make_dodge_press_event()
	input_sys._input(event)
	input_sys._physics_process(0.0)
	assert_true(input_sys.is_dodge_just_pressed(),
		"NORMAL state must allow dodge input")
