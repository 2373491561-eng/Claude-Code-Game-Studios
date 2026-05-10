extends GutTest

# Unit tests for GameManager autoload (Story 001).
#
# Validates:
#   1. current_run is null by default
#   2. start_new_run() creates a RunState and records start_time_ms
#   3. start_new_run() resets all fields to defaults
#   4. end_run() sets end_time_ms
#   5. end_run() is a no-op when no run exists
#   6. get_run_duration_seconds() returns 0.0 when no run exists
#   7. get_run_duration_seconds() precision to 0.1s (rounded)
#   8. get_run_duration_seconds() uses current time when end not called
#   9. record_kill() increments kills counter
#  10. record_kill() is a no-op when no run exists

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

var _gm: GameManager

func before_each() -> void:
	_gm = GameManager.new()
	add_child_autofree(_gm)

# ---------------------------------------------------------------------------
# AC 1: current_run null by default
# ---------------------------------------------------------------------------

func test_game_manager_current_run_null_by_default() -> void:
	assert_null(_gm.current_run,
		"current_run should be null before start_new_run() is called")

# ---------------------------------------------------------------------------
# AC 2: start_new_run() creates RunState and records start_time
# ---------------------------------------------------------------------------

func test_game_manager_start_new_run_creates_run_state() -> void:
	_gm.start_new_run()
	assert_not_null(_gm.current_run,
		"current_run should not be null after start_new_run()")
	assert_true(_gm.current_run is GameManager.RunState,
		"current_run should be a RunState instance")

func test_game_manager_start_new_run_sets_start_time() -> void:
	var before_ms := Time.get_ticks_msec()
	_gm.start_new_run()
	var start_ms := _gm.current_run.start_time_ms
	assert_true(start_ms >= before_ms,
		"start_time_ms should be >= the time just before start_new_run()")
	assert_true(start_ms <= Time.get_ticks_msec(),
		"start_time_ms should be <= current time after start_new_run()")

# ---------------------------------------------------------------------------
# AC 3: start_new_run() resets all fields to defaults
# ---------------------------------------------------------------------------

func test_game_manager_start_new_run_resets_fields_to_defaults() -> void:
	_gm.start_new_run()
	assert_eq(_gm.current_run.wave, 0, "wave should start at 0")
	assert_eq(_gm.current_run.kills, 0, "kills should start at 0")
	assert_eq(_gm.current_run.build_choices.size(), 0, "build_choices should start empty")
	assert_eq(_gm.current_run.perfect_dodges, 0, "perfect_dodges should start at 0")
	assert_eq(_gm.current_run.total_damage_dealt, 0, "total_damage_dealt should start at 0")
	assert_eq(_gm.current_run.end_time_ms, 0, "end_time_ms should start at 0")

# ---------------------------------------------------------------------------
# AC 4: end_run() sets end_time_ms
# ---------------------------------------------------------------------------

func test_game_manager_end_run_sets_end_time() -> void:
	_gm.start_new_run()
	_gm.end_run()
	assert_true(_gm.current_run.end_time_ms > 0,
		"end_time_ms should be > 0 after end_run()")
	assert_true(_gm.current_run.end_time_ms >= _gm.current_run.start_time_ms,
		"end_time_ms should be >= start_time_ms")

# ---------------------------------------------------------------------------
# AC 5: end_run() no-op when no run exists
# ---------------------------------------------------------------------------

func test_game_manager_end_run_no_op_when_no_current_run() -> void:
	# Should not crash when current_run is null
	_gm.end_run()
	assert_null(_gm.current_run, "current_run should remain null after end_run() with no run")
	# No exception thrown = pass

# ---------------------------------------------------------------------------
# AC 6: get_run_duration_seconds() returns 0.0 when no run exists
# ---------------------------------------------------------------------------

func test_game_manager_get_run_duration_seconds_returns_zero_when_no_run() -> void:
	assert_eq(_gm.get_run_duration_seconds(), 0.0,
		"get_run_duration_seconds() should return 0.0 when no run exists")

# ---------------------------------------------------------------------------
# AC 7: get_run_duration_seconds() precision to 0.1s
# ---------------------------------------------------------------------------

func test_game_manager_get_run_duration_seconds_precision_rounds_up() -> void:
	_gm.start_new_run()
	# 150ms -> round(150/100)=round(1.5)=2 -> 2/10=0.2
	_gm.current_run.start_time_ms = 0
	_gm.current_run.end_time_ms = 150
	assert_eq(_gm.get_run_duration_seconds(), 0.2,
		"150ms should round to 0.2s")

func test_game_manager_get_run_duration_seconds_precision_rounds_down() -> void:
	_gm.start_new_run()
	# 1249ms -> round(1249/100)=round(12.49)=12 -> 12/10=1.2
	_gm.current_run.start_time_ms = 0
	_gm.current_run.end_time_ms = 1249
	assert_eq(_gm.get_run_duration_seconds(), 1.2,
		"1249ms should round to 1.2s")

func test_game_manager_get_run_duration_seconds_exactly_on_boundary() -> void:
	_gm.start_new_run()
	# Godot 4's round() uses banker's rounding (round-half-to-even).
	# 1250ms / 100 = 12.5 -> round(12.5) = 12 (even) -> 12/10 = 1.2
	_gm.current_run.start_time_ms = 0
	_gm.current_run.end_time_ms = 1250
	assert_eq(_gm.get_run_duration_seconds(), 1.2,
		"1250ms with banker's rounding: round(12.5)=12 -> 1.2s")

func test_game_manager_get_run_duration_seconds_rounds_up_from_251ms() -> void:
	_gm.start_new_run()
	# 251ms / 100 = 2.51 -> round(2.51) = 3 -> 0.3
	_gm.current_run.start_time_ms = 0
	_gm.current_run.end_time_ms = 251
	assert_eq(_gm.get_run_duration_seconds(), 0.3,
		"251ms should round up to 0.3s")

func test_game_manager_get_run_duration_seconds_zero_duration() -> void:
	_gm.start_new_run()
	_gm.current_run.end_time_ms = _gm.current_run.start_time_ms
	assert_eq(_gm.get_run_duration_seconds(), 0.0,
		"Zero-duration run should return 0.0s")

# ---------------------------------------------------------------------------
# AC 8: get_run_duration_seconds() uses current time when end not called
# ---------------------------------------------------------------------------

func test_game_manager_get_run_duration_seconds_uses_current_time_when_not_ended() -> void:
	_gm.start_new_run()
	# Simulate run having started 2 seconds ago
	_gm.current_run.start_time_ms = Time.get_ticks_msec() - 2000
	var result := _gm.get_run_duration_seconds()
	assert_true(result >= 1.9 and result <= 2.1,
		("get_run_duration_seconds() should use current time when end_run() " +
		 "not called, got %.1f") % result)

# ---------------------------------------------------------------------------
# AC 9: record_kill() increments kills
# ---------------------------------------------------------------------------

func test_game_manager_record_kill_increments_kills() -> void:
	_gm.start_new_run()
	_gm.record_kill()
	assert_eq(_gm.current_run.kills, 1, "kills should be 1 after one record_kill()")
	_gm.record_kill()
	_gm.record_kill()
	assert_eq(_gm.current_run.kills, 3, "kills should be 3 after three record_kill() calls")

# ---------------------------------------------------------------------------
# AC 10: record_kill() no-op when no run exists
# ---------------------------------------------------------------------------

func test_game_manager_record_kill_no_op_when_no_run() -> void:
	_gm.record_kill()
	assert_null(_gm.current_run,
		"record_kill() should not crash or create a run when current_run is null")

# ---------------------------------------------------------------------------
# RunState can be instantiated independently
# ---------------------------------------------------------------------------

func test_game_manager_run_state_can_be_created_directly() -> void:
	var rs := GameManager.RunState.new()
	assert_eq(rs.wave, 0)
	assert_eq(rs.kills, 0)
	assert_eq(rs.build_choices, [])
	assert_eq(rs.perfect_dodges, 0)
	assert_eq(rs.total_damage_dealt, 0)
	assert_eq(rs.start_time_ms, 0)
	assert_eq(rs.end_time_ms, 0)
