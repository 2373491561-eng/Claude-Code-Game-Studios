extends GutTest

# Smoke test — validates that GUT framework and CI pipeline work.
# This file serves as both a CI canary and a template for future test files.

const MAX_FRAME_BUDGET_MS = 4.17

func before_all() -> void:
	# Verify engine is accessible
	assert_not_null(Engine.get_version_info(), "Godot engine should be accessible")

func test_smoke_engine_version() -> void:
	var version = Engine.get_version_info()
	assert_true(version.major >= 4, "Godot 4.x required")
	assert_true(version.minor >= 4, "Godot 4.4+ required (project targets 4.6.2)")

func test_smoke_time_api() -> void:
	# ADR-0001: Time.get_ticks_msec() must be available and monotonic
	var t0 = Time.get_ticks_msec()
	assert_true(t0 > 0, "Time.get_ticks_msec() should return positive value")
	var t1 = Time.get_ticks_msec()
	assert_true(t1 >= t0, "Time.get_ticks_msec() should be monotonic (non-decreasing)")

func test_smoke_engine_time_scale_independent() -> void:
	# ADR-0001: Time.get_ticks_msec() must NOT be affected by Engine.time_scale
	var saved = Engine.time_scale
	Engine.time_scale = 0.2
	var t0 = Time.get_ticks_msec()
	OS.delay_msec(10)  # Wait 10ms real time
	var t1 = Time.get_ticks_msec()
	var elapsed = t1 - t0
	Engine.time_scale = saved
	# At time_scale=0.2, if get_ticks_msec were affected, elapsed would be ~2ms
	# Real elapsed should be >= 8ms (OS.delay_msec(10) with tolerance)
	assert_true(elapsed >= 5, "Time.get_ticks_msec() should not be scaled by Engine.time_scale (got %d ms)" % elapsed)

func test_smoke_frame_budget_reasonable() -> void:
	# Verify we're not already over budget with an empty scene
	var dt = get_physics_process_delta_time()
	assert_true(dt * 1000.0 < MAX_FRAME_BUDGET_MS,
		"Physics delta should be within frame budget (%.2f ms > %.2f ms)" % [dt * 1000.0, MAX_FRAME_BUDGET_MS])

func test_smoke_input_map_has_actions() -> void:
	# Verify core input actions are registered (ADR-0002)
	var actions = ["move", "aim", "shoot", "dodge", "skill_1", "pause"]
	for action in actions:
		assert_true(InputMap.has_action(action),
			"InputMap should have action: %s" % action)

func test_smoke_json_parse() -> void:
	# ADR-0014: JSON serialization for save system
	var test_dict = {"version": 1, "hp": 3, "name": "test"}
	var json_str = JSON.stringify(test_dict)
	assert_not_null(json_str, "JSON.stringify should produce a string")
	var parsed = JSON.parse_string(json_str)
	assert_eq(parsed.version, 1, "Parsed JSON should match original")
	assert_eq(parsed.hp, 3, "Parsed JSON should match original")
