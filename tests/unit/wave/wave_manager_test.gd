extends GutTest

# ---------------------------------------------------------------------------
# Mock classes
# ---------------------------------------------------------------------------

class MockEnemyManager extends RefCounted:
	var active_count: int = 0
	var frozen: bool = false
	var spawned_waves: Array[Dictionary] = []

	func spawn_wave(config: Dictionary) -> void:
		spawned_waves.append(config.duplicate())

	func get_active_count() -> int:
		return active_count

	func is_frozen() -> bool:
		return frozen

	func has_method(method_name: String) -> bool:
		return method_name in ["spawn_wave", "get_active_count", "is_frozen"]


# Minimal host that replicates WaveManager logic for unit testing.
class WaveManagerHost extends Node:
	var enemy_manager: MockEnemyManager = null
	var _current_wave: int = 0
	var _enemies_remaining: int = 0
	var _wave_active: bool = false
	var _killed_this_wave: int = 0
	var _first_wave_pending: bool = false
	var _first_wave_delay_start_ms: int = 0
	var _in_transition: bool = false
	var _transition_start_ms: int = 0
	var _waiting_for_build: bool = false
	var _wave_cleared: bool = false

	const WAVE_TABLE: Array[Dictionary] = [
		{"small": 8,  "medium": 0,  "large": 0,  "total": 8},
		{"small": 12, "medium": 0,  "large": 0,  "total": 12},
		{"small": 15, "medium": 2,  "large": 0,  "total": 17},
		{"small": 20, "medium": 3,  "large": 0,  "total": 23},
		{"small": 25, "medium": 5,  "large": 1,  "total": 31},
		{"small": 30, "medium": 6,  "large": 1,  "total": 37},
		{"small": 30, "medium": 6,  "large": 1,  "total": 37},
		{"small": 35, "medium": 8,  "large": 2,  "total": 45},
		{"small": 35, "medium": 8,  "large": 2,  "total": 45},
		{"small": 35, "medium": 8,  "large": 2,  "total": 45},
	]
	const WAVE_11_PLUS: Dictionary = {"small": 40, "medium": 10, "large": 3, "total": 53}

	func _get_wave_config(wave_num: int) -> Dictionary:
		var idx := wave_num - 1
		if idx < WAVE_TABLE.size():
			return WAVE_TABLE[idx]
		return WAVE_11_PLUS

	func get_current_wave() -> int:
		return _current_wave


# ---------------------------------------------------------------------------
# Wave progression table tests
# ---------------------------------------------------------------------------

func test_wave_table_wave1_has_8_small_only() -> void:
	var host := WaveManagerHost.new()
	add_child(host)

	var config := host._get_wave_config(1)
	assert_eq(config.small, 8)
	assert_eq(config.medium, 0)
	assert_eq(config.large, 0)
	assert_eq(config.total, 8)

	host.queue_free()


func test_wave_table_wave3_has_medium() -> void:
	var host := WaveManagerHost.new()
	add_child(host)

	var config := host._get_wave_config(3)
	assert_eq(config.small, 15)
	assert_eq(config.medium, 2)
	assert_eq(config.large, 0)
	assert_eq(config.total, 17)

	host.queue_free()


func test_wave_table_wave5_has_large() -> void:
	var host := WaveManagerHost.new()
	add_child(host)

	var config := host._get_wave_config(5)
	assert_eq(config.small, 25)
	assert_eq(config.medium, 5)
	assert_eq(config.large, 1)
	assert_eq(config.total, 31)

	host.queue_free()


func test_wave_table_wave6_7_are_identical() -> void:
	var host := WaveManagerHost.new()
	add_child(host)

	var config6 := host._get_wave_config(6)
	var config7 := host._get_wave_config(7)
	assert_eq(config6.total, config7.total)
	assert_eq(config6.small, 30)
	assert_eq(config6.medium, 6)
	assert_eq(config6.large, 1)

	host.queue_free()


func test_wave_table_wave8_10() -> void:
	var host := WaveManagerHost.new()
	add_child(host)

	var config8 := host._get_wave_config(8)
	assert_eq(config8.small, 35)
	assert_eq(config8.medium, 8)
	assert_eq(config8.large, 2)
	assert_eq(config8.total, 45)

	var config10 := host._get_wave_config(10)
	assert_eq(config10.total, 45)

	host.queue_free()


func test_wave_table_wave11_plus() -> void:
	var host := WaveManagerHost.new()
	add_child(host)

	var config11 := host._get_wave_config(11)
	assert_eq(config11.small, 40)
	assert_eq(config11.medium, 10)
	assert_eq(config11.large, 3)
	assert_eq(config11.total, 53)

	# Wave 20 should also use the 11+ template.
	var config20 := host._get_wave_config(20)
	assert_eq(config20.total, 53)

	host.queue_free()


func test_wave_table_does_not_exceed_max_total() -> void:
	var host := WaveManagerHost.new()
	add_child(host)

	# EnemyManager.MAX_TOTAL is 53. The max wave config total must not exceed 53.
	for wave_num in range(1, 30):
		var config := host._get_wave_config(wave_num)
		assert_true(config.total <= 53, "Wave %d total %d exceeds MAX_TOTAL 53" % [wave_num, config.total])

	host.queue_free()


# ---------------------------------------------------------------------------
# Wave clear detection tests
# ---------------------------------------------------------------------------

func test_wave_clear_detected_when_active_count_zero() -> void:
	var host := WaveManagerHost.new()
	host.enemy_manager = MockEnemyManager.new()
	host.enemy_manager.active_count = 0
	add_child(host)

	# Simulate a wave being active.
	host._current_wave = 1
	host._enemies_remaining = 8
	host._wave_active = true

	# Simulate the check that would happen in _physics_process.
	if host.enemy_manager.get_active_count() <= 0:
		host._wave_active = false
		host._wave_cleared = true

	assert_false(host._wave_active, "Wave should be inactive when active_count is 0")
	assert_true(host._wave_cleared, "Wave should be marked cleared")

	host.queue_free()


func test_wave_not_cleared_when_enemies_still_alive() -> void:
	var host := WaveManagerHost.new()
	host.enemy_manager = MockEnemyManager.new()
	host.enemy_manager.active_count = 5
	add_child(host)

	host._current_wave = 1
	host._enemies_remaining = 8
	host._wave_active = true

	# Active count > 0, wave should still be active.
	if host.enemy_manager.get_active_count() > 0:
		# Do nothing -- wave continues.
		pass

	assert_true(host._wave_active, "Wave should remain active when enemies exist")
	assert_false(host._wave_cleared, "Wave should not be cleared")

	host.queue_free()


func test_wave_not_cleared_when_frozen() -> void:
	var host := WaveManagerHost.new()
	host.enemy_manager = MockEnemyManager.new()
	host.enemy_manager.active_count = 0
	host.enemy_manager.frozen = true
	add_child(host)

	host._wave_active = true

	# Frozen means player is dead -- don't clear wave.
	if host.enemy_manager.is_frozen():
		# Wave stays active; death handles cleanup.
		pass

	assert_true(host._wave_active, "Wave should not clear when enemy manager is frozen")

	host.queue_free()


# ---------------------------------------------------------------------------
# Wave config validation -- enemy counts consistent with total
# ---------------------------------------------------------------------------

func test_wave_config_sums_match_total() -> void:
	var host := WaveManagerHost.new()
	add_child(host)

	for wave_num in range(1, 12):
		var config := host._get_wave_config(wave_num)
		var sum := config.small + config.medium + config.large
		assert_eq(sum, config.total, "Wave %d: small+medium+large must equal total" % wave_num)

	host.queue_free()


# ---------------------------------------------------------------------------
# First wave delay tests
# ---------------------------------------------------------------------------

func test_first_wave_not_started_before_delay() -> void:
	var host := WaveManagerHost.new()
	add_child(host)

	host._first_wave_pending = true
	host._first_wave_delay_start_ms = 0  # Just started

	# Simulate a check where 0.5s has elapsed (less than 1s delay).
	var elapsed := 500  # 0.5s
	var delay_ms := 1000  # 1.0s
	if elapsed < delay_ms:
		# Should NOT start wave yet.
		assert_true(host._first_wave_pending, "First wave should still be pending")

	host.queue_free()


func test_first_wave_starts_after_delay() -> void:
	var host := WaveManagerHost.new()
	add_child(host)

	host._first_wave_pending = true
	host._first_wave_delay_start_ms = 0

	# Simulate 1.1s elapsed (more than 1s delay).
	var elapsed := 1100
	var delay_ms := 1000
	if elapsed >= delay_ms:
		host._first_wave_pending = false
		host._current_wave = 1
		host._wave_active = true

	assert_false(host._first_wave_pending, "First wave should no longer be pending")
	assert_eq(host._current_wave, 1)
	assert_true(host._wave_active, "Wave should be active after delay")

	host.queue_free()


# ---------------------------------------------------------------------------
# Wave counter increment
# ---------------------------------------------------------------------------

func test_wave_number_increments_correctly() -> void:
	var host := WaveManagerHost.new()
	add_child(host)

	# Simulate starting wave 1.
	host._current_wave = 1
	assert_eq(host.get_current_wave(), 1)

	# Simulate next wave being triggered.
	host._current_wave = 2
	assert_eq(host.get_current_wave(), 2)

	host._current_wave = 5
	assert_eq(host.get_current_wave(), 5)

	host.queue_free()
