extends GutTest

func test_default_data_has_version() -> void:
	var sm := SaveManager.new()
	add_child_autofree(sm)
	sm._ready()
	assert_eq(sm.data.version, 1)

func test_default_meta_points_zero() -> void:
	var sm := SaveManager.new()
	add_child_autofree(sm)
	sm._ready()
	assert_eq(sm.get_meta_points(), 0)

func test_add_meta_points() -> void:
	var sm := SaveManager.new()
	add_child_autofree(sm)
	sm._ready()
	sm.add_meta_points(5)
	assert_eq(sm.get_meta_points(), 5)

func test_highest_wave_updated() -> void:
	var sm := SaveManager.new()
	add_child_autofree(sm)
	sm._ready()
	sm.set_highest_wave(3)
	assert_eq(sm.get_highest_wave(), 3)
	sm.set_highest_wave(2)
	assert_eq(sm.get_highest_wave(), 3, "Should keep highest")

func test_add_unlock() -> void:
	var sm := SaveManager.new()
	add_child_autofree(sm)
	sm._ready()
	sm.add_unlock("fire_rate_up")
	assert_true("fire_rate_up" in sm.get_unlocks())

func test_unlock_no_duplicate() -> void:
	var sm := SaveManager.new()
	add_child_autofree(sm)
	sm._ready()
	sm.add_unlock("test")
	sm.add_unlock("test")
	assert_eq(sm.get_unlocks().size(), 1)

func test_get_setting_default() -> void:
	var sm := SaveManager.new()
	add_child_autofree(sm)
	sm._ready()
	assert_eq(sm.get_setting("master_volume", 1.0), 1.0)

func test_set_setting() -> void:
	var sm := SaveManager.new()
	add_child_autofree(sm)
	sm._ready()
	sm.set_setting("master_volume", 0.5)
	assert_eq(sm.get_setting("master_volume", 0.0), 0.5)
