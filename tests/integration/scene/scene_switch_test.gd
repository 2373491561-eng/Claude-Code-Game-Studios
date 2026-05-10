extends GutTest

# Integration tests for SceneManager (Story 002).
#
# Validates:
#   1. SceneID enum has 3 distinct values
#   2. SCENE_PATHS maps all 3 SceneIDs to valid res:// paths
#   3. Default current scene is MAIN_MENU
#   4. Debounce blocks calls within 500ms (AC: rapid clicks only fire once)
#   5. switch_to(GAME) sets the correct pending scene ID
#   6. SCENE_PATHS use .tscn extension for all entries
#
# Note: Full scene transition tests (fade animations, actual change_scene_to_file,
# GameManager.start_new_run side effect) require the Godot runtime with real scenes
# loaded. Those are validated through manual playtesting per the testing standards
# for integration-type stories.

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

var _sm: SceneManager

func before_each() -> void:
	_sm = SceneManager.new()
	add_child_autofree(_sm)

func after_each() -> void:
	# Kill any in-progress tweens to prevent callbacks from firing
	# after the test node is freed.
	if _sm != null and is_instance_valid(_sm):
		_sm._destroy_overlay()

# ---------------------------------------------------------------------------
# AC 1: SceneID enum has 3 distinct values
# ---------------------------------------------------------------------------

func test_scene_manager_scene_id_enum_has_three_values() -> void:
	var ids := [
		SceneManager.SceneID.MAIN_MENU,
		SceneManager.SceneID.GAME,
		SceneManager.SceneID.DEATH_SCREEN,
	]
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			assert_ne(ids[i], ids[j],
				"SceneID values %d and %d should be distinct" % [ids[i], ids[j]])

# ---------------------------------------------------------------------------
# AC 2: SCENE_PATHS maps all 3 SceneIDs
# ---------------------------------------------------------------------------

func test_scene_manager_scene_paths_covers_all_ids() -> void:
	assert_eq(SceneManager.SCENE_PATHS.size(), 3,
		"SCENE_PATHS should map exactly 3 scenes")
	assert_true(SceneManager.SCENE_PATHS.has(SceneManager.SceneID.MAIN_MENU),
		"SCENE_PATHS should contain MAIN_MENU")
	assert_true(SceneManager.SCENE_PATHS.has(SceneManager.SceneID.GAME),
		"SCENE_PATHS should contain GAME")
	assert_true(SceneManager.SCENE_PATHS.has(SceneManager.SceneID.DEATH_SCREEN),
		"SCENE_PATHS should contain DEATH_SCREEN")

func test_scene_manager_scene_paths_use_res_and_tscn() -> void:
	for scene_id in SceneManager.SCENE_PATHS.keys():
		var path: String = SceneManager.SCENE_PATHS[scene_id]
		assert_true(path.begins_with("res://"),
			"Path should start with res:// -- got: " + path)
		assert_true(path.ends_with(".tscn"),
			"Path should end with .tscn -- got: " + path)

# ---------------------------------------------------------------------------
# AC 3: Default current scene is MAIN_MENU
# ---------------------------------------------------------------------------

func test_scene_manager_default_scene_is_main_menu() -> void:
	assert_eq(_sm.get_current_scene(), SceneManager.SceneID.MAIN_MENU,
		"Default scene should be MAIN_MENU before any switch_to() call")

# ---------------------------------------------------------------------------
# AC 4: Debounce blocks calls within 500ms
# ---------------------------------------------------------------------------

func test_scene_manager_debounce_accepts_first_call() -> void:
	# First call should be accepted and set _last_switch_ms
	_sm.switch_to(SceneManager.SceneID.MAIN_MENU)
	assert_true(_sm._last_switch_ms > 0,
		"First switch_to() call should set _last_switch_ms to a positive value")

func test_scene_manager_debounce_blocks_immediate_second_call() -> void:
	# First call -- accepted
	_sm.switch_to(SceneManager.SceneID.MAIN_MENU)
	var first_ms := _sm._last_switch_ms
	var first_pending := _sm._pending_scene_id
	assert_eq(first_pending, SceneManager.SceneID.MAIN_MENU)

	# Second call immediately after -- should be debounced
	_sm.switch_to(SceneManager.SceneID.GAME)

	# _last_switch_ms should NOT have been updated (debounce blocked it)
	assert_eq(_sm._last_switch_ms, first_ms,
		"Debounced call should NOT update _last_switch_ms")
	# _pending_scene_id should still be the first call's target
	assert_eq(_sm._pending_scene_id, first_pending,
		"Debounced call should NOT change _pending_scene_id")

func test_scene_manager_debounce_allows_call_after_window() -> void:
	# First call
	_sm.switch_to(SceneManager.SceneID.MAIN_MENU)
	var first_ms := _sm._last_switch_ms

	# Simulate debounce window having passed (>500ms ago)
	_sm._last_switch_ms = Time.get_ticks_msec() - 501

	# Second call should be accepted now
	_sm.switch_to(SceneManager.SceneID.GAME)
	assert_ne(_sm._last_switch_ms, first_ms,
		"Second call after debounce window should update _last_switch_ms")
	assert_eq(_sm._pending_scene_id, SceneManager.SceneID.GAME,
		"Second call after debounce window should update _pending_scene_id")

# ---------------------------------------------------------------------------
# AC 5: switch_to(GAME) sets the correct pending scene
# ---------------------------------------------------------------------------

func test_scene_manager_switch_to_game_sets_pending_scene() -> void:
	_sm.switch_to(SceneManager.SceneID.GAME)
	assert_eq(_sm._pending_scene_id, SceneManager.SceneID.GAME,
		"switch_to(GAME) should set _pending_scene_id to GAME")

# ---------------------------------------------------------------------------
# AC 6: get_pending_death_data returns empty dict before any switch
# ---------------------------------------------------------------------------

func test_scene_manager_get_pending_death_data_defaults_empty() -> void:
	var data := _sm.get_pending_death_data()
	assert_eq(data, {}, "get_pending_death_data() should return empty dict by default")
