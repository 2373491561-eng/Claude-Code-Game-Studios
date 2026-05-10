extends GutTest

# Acceptance criteria tests for Story 002: Dodge debounce / buffer pipeline.
#
# These tests validate:
#   1. Debounce blocks re-trigger within 50ms (AC 1)
#   2. Debounce allows press after 50ms window (AC 2)
#   3. Buffer stores input during dodge cooldown (AC 3)
#   4. Buffered dodge fires when availability restored within 100ms (AC 4)
#   5. Buffered dodge expires silently after 100ms window (AC 5)
#   6. Dodge executes immediately when available and no debounce blocks (AC 6)

# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------

func before_all() -> void:
	# Ensure actions exist for the entire test suite.
	InputSystem.register_input_map()

func after_each() -> void:
	# Release all actions to avoid state leaking between tests.
	Input.action_release("dodge")

# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

## Creates an InputEventKey that will match the dodge action (KEY_SHIFT).
func _make_dodge_press_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_SHIFT
	event.pressed = true
	return event

# ---------------------------------------------------------------------------
# AC 1: Debounce blocks re-trigger within 50ms
# ---------------------------------------------------------------------------

func test_dodge_debounce_blocks_second_press_within_50ms() -> void:
	# Arrange
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	var event := _make_dodge_press_event()

	# Act — first press
	input_sys._input(event)
	input_sys._physics_process(0.0)

	# Assert — first press fires
	assert_true(input_sys.is_dodge_just_pressed(),
		"First dodge press should fire when dodge is available")

	# Act — second press immediately (well within 50ms debounce)
	input_sys._input(event)
	input_sys._physics_process(0.0)

	# Assert — second press is debounced
	assert_false(input_sys.is_dodge_just_pressed(),
		"Second dodge press within 50ms debounce window must be discarded")

# ---------------------------------------------------------------------------
# AC 2: Debounce allows press after 50ms window
# ---------------------------------------------------------------------------

func test_dodge_debounce_allows_press_after_50ms() -> void:
	# Arrange — simulate last dodge having fired 51ms ago
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	input_sys._last_dodge_ms = Time.get_ticks_msec() - 51
	var event := _make_dodge_press_event()

	# Act
	input_sys._input(event)
	input_sys._physics_process(0.0)

	# Assert
	assert_true(input_sys.is_dodge_just_pressed(),
		"Dodge press after 50ms debounce window should fire")

# ---------------------------------------------------------------------------
# AC 3: Buffer stores input during dodge cooldown
# ---------------------------------------------------------------------------

func test_dodge_buffer_stores_press_during_cooldown() -> void:
	# Arrange
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	input_sys.set_dodge_availability(false, 500)
	var event := _make_dodge_press_event()

	# Act
	input_sys._input(event)
	input_sys._physics_process(0.0)

	# Assert
	assert_false(input_sys.is_dodge_just_pressed(),
		"Dodge should NOT fire when unavailable")
	assert_true(input_sys.is_dodge_buffered(),
		"Dodge press during cooldown should be buffered")

# ---------------------------------------------------------------------------
# AC 4: Buffered dodge fires when availability restored within 100ms
# ---------------------------------------------------------------------------

func test_dodge_buffer_fires_when_availability_restored_within_window() -> void:
	# Arrange — press while unavailable
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	input_sys.set_dodge_availability(false, 500)
	var event := _make_dodge_press_event()
	input_sys._input(event)
	input_sys._physics_process(0.0)
	assert_true(input_sys.is_dodge_buffered(),
		"Setup: dodge should be buffered")

	# Act — restore availability (simulates cooldown ending within buffer window)
	input_sys.set_dodge_availability(true, 0)
	input_sys._physics_process(0.0)

	# Assert
	assert_true(input_sys.is_dodge_just_pressed(),
		"Buffered dodge should fire when availability is restored within buffer window")
	assert_false(input_sys.is_dodge_buffered(),
		"Buffer should be cleared after firing")

# ---------------------------------------------------------------------------
# AC 5: Buffered dodge expires silently after 100ms
# ---------------------------------------------------------------------------

func test_dodge_buffer_expires_after_100ms_window() -> void:
	# Arrange — press while unavailable
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	input_sys.set_dodge_availability(false, 500)
	var event := _make_dodge_press_event()
	input_sys._input(event)
	input_sys._physics_process(0.0)
	assert_true(input_sys.is_dodge_buffered(),
		"Setup: dodge should be buffered")

	# Arrange — simulate buffer window having elapsed (101ms)
	input_sys._dodge_buffered_time_ms = Time.get_ticks_msec() - 101
	input_sys.set_dodge_availability(true, 0)

	# Act
	input_sys._physics_process(0.0)

	# Assert
	assert_false(input_sys.is_dodge_just_pressed(),
		"Expired buffer should NOT fire even if dodge is now available")
	assert_false(input_sys.is_dodge_buffered(),
		"Expired buffer should be cleared")

# ---------------------------------------------------------------------------
# AC 5b: Buffered dodge expires when still unavailable and window elapses
# ---------------------------------------------------------------------------

func test_dodge_buffer_expires_when_still_unavailable_and_window_elapses() -> void:
	# Arrange — press while unavailable
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	input_sys.set_dodge_availability(false, 500)
	var event := _make_dodge_press_event()
	input_sys._input(event)
	input_sys._physics_process(0.0)
	assert_true(input_sys.is_dodge_buffered(),
		"Setup: dodge should be buffered")

	# Arrange — simulate buffer window having elapsed, still unavailable
	input_sys._dodge_buffered_time_ms = Time.get_ticks_msec() - 101

	# Act
	input_sys._physics_process(0.0)

	# Assert
	assert_false(input_sys.is_dodge_buffered(),
		"Buffer should be cleared when window elapses while still unavailable")

# ---------------------------------------------------------------------------
# AC 6: Dodge executes immediately when available (no debounce, no cooldown)
# ---------------------------------------------------------------------------

func test_dodge_executes_immediately_when_available() -> void:
	# Arrange
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	var event := _make_dodge_press_event()

	# Act
	input_sys._input(event)
	input_sys._physics_process(0.0)

	# Assert
	assert_true(input_sys.is_dodge_just_pressed(),
		"Dodge should execute immediately when available and no debounce applies")

# ---------------------------------------------------------------------------
# Public API: is_dodge_buffered() default state
# ---------------------------------------------------------------------------

func test_is_dodge_buffered_returns_false_by_default() -> void:
	# Arrange
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)

	# Act + Assert
	assert_false(input_sys.is_dodge_buffered(),
		"is_dodge_buffered() should return false when no dodge has been queued")

# ---------------------------------------------------------------------------
# Public API: consume_dodge_buffer()
# ---------------------------------------------------------------------------

func test_consume_dodge_buffer_clears_and_returns_previous_state() -> void:
	# Arrange — press while unavailable to create a buffer
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	input_sys.set_dodge_availability(false, 500)
	var event := _make_dodge_press_event()
	input_sys._input(event)
	input_sys._physics_process(0.0)
	assert_true(input_sys.is_dodge_buffered(),
		"Setup: dodge should be buffered")

	# Act
	var was_buffered := input_sys.consume_dodge_buffer()

	# Assert
	assert_true(was_buffered,
		"consume_dodge_buffer() should return true when buffer was active")
	assert_false(input_sys.is_dodge_buffered(),
		"Buffer should be cleared after consume_dodge_buffer()")

# ---------------------------------------------------------------------------
# Public API: set_dodge_availability()
# ---------------------------------------------------------------------------

func test_set_dodge_availability_controls_execution() -> void:
	# Arrange
	var input_sys := InputSystem.new()
	add_child_autofree(input_sys)
	var event := _make_dodge_press_event()

	# Act — make dodge unavailable
	input_sys.set_dodge_availability(false, 500)
	input_sys._input(event)
	input_sys._physics_process(0.0)

	# Assert — should not fire
	assert_false(input_sys.is_dodge_just_pressed(),
		"Dodge should NOT fire when set_dodge_availability(false)")

	# Act — restore availability and press again
	input_sys.set_dodge_availability(true, 0)
	input_sys._input(event)
	input_sys._physics_process(0.0)

	# Assert — should fire now
	assert_true(input_sys.is_dodge_just_pressed(),
		"Dodge should fire when set_dodge_availability(true)")
