##
extends GutTest

# ---------------------------------------------------------------------------
# Minimal host replicating MetaProgression core logic for unit testing.
# ---------------------------------------------------------------------------

class MetaProgressionHost extends RefCounted:
	var _total_points: int = 0
	var _highest_wave: int = 0
	var _unlocks: Array[String] = []

	const UNLOCK_THRESHOLDS: Dictionary = {
		5: "weapon_fire_rate",
		15: "weapon_damage",
		25: "skill_cd",
		40: "skill2_damage",
		60: "dodge_charge",
	}
	const SORTED_THRESHOLDS: Array[int] = [5, 15, 25, 40, 60]

	func calculate_run_points(kills: int, wave_reached: int) -> int:
		return floori(kills * 0.1 + wave_reached * 1.0)

	func add_run_points(kills: int, wave_reached: int) -> void:
		var points := calculate_run_points(kills, wave_reached)
		_total_points += points
		if wave_reached > _highest_wave:
			_highest_wave = wave_reached
		_check_unlocks()

	func _check_unlocks() -> void:
		for threshold in SORTED_THRESHOLDS:
			if _total_points >= threshold:
				var upgrade_id: String = UNLOCK_THRESHOLDS.get(threshold, "")
				if upgrade_id != "" and upgrade_id not in _unlocks:
					_unlocks.append(upgrade_id)

	func get_total_points() -> int:
		return _total_points

	func get_highest_wave() -> int:
		return _highest_wave

	func get_unlocks() -> Array[String]:
		return _unlocks

	func is_unlocked(upgrade_id: String) -> bool:
		return upgrade_id in _unlocks

	func get_next_threshold() -> int:
		for threshold in SORTED_THRESHOLDS:
			if _total_points < threshold:
				return threshold
		return -1


# ---------------------------------------------------------------------------
# Points calculation formula tests
# ---------------------------------------------------------------------------

func test_formula_zero_kills_wave_zero() -> void:
	var host := MetaProgressionHost.new()
	var points := host.calculate_run_points(0, 0)
	assert_eq(points, 0, "0 kills at wave 0 should give 0 points")


func test_formula_wave_10_with_no_kills() -> void:
	var host := MetaProgressionHost.new()
	# floor(0 + 10 * 1.0) = 10
	var points := host.calculate_run_points(0, 10)
	assert_eq(points, 10)


func test_formula_100_kills_wave_10() -> void:
	var host := MetaProgressionHost.new()
	# floor(100 * 0.1 + 10 * 1.0) = floor(10 + 10) = 20
	var points := host.calculate_run_points(100, 10)
	assert_eq(points, 20)


func test_formula_15_kills_wave_5() -> void:
	var host := MetaProgressionHost.new()
	# floor(15 * 0.1 + 5 * 1.0) = floor(1.5 + 5) = 6
	var points := host.calculate_run_points(15, 5)
	assert_eq(points, 6)


func test_formula_9_kills_wave_3() -> void:
	var host := MetaProgressionHost.new()
	# floor(9 * 0.1 + 3 * 1.0) = floor(0.9 + 3) = 3
	var points := host.calculate_run_points(9, 3)
	assert_eq(points, 3)


func test_formula_always_returns_integer() -> void:
	var host := MetaProgressionHost.new()
	for kills in range(0, 100, 7):
		for wave in range(1, 20, 3):
			var points := host.calculate_run_points(kills, wave)
			assert_eq(typeof(points), TYPE_INT, "Points should always be an integer")


func test_formula_points_never_negative() -> void:
	var host := MetaProgressionHost.new()
	# Even with edge case inputs, points should never be negative.
	var points := host.calculate_run_points(0, 0)
	assert_true(points >= 0, "Points should never be negative")


# ---------------------------------------------------------------------------
# Accumulation tests
# ---------------------------------------------------------------------------

func test_total_points_accumulate_over_multiple_runs() -> void:
	var host := MetaProgressionHost.new()

	# Run 1: 100 kills, wave 10 = 20 points
	host.add_run_points(100, 10)
	assert_eq(host.get_total_points(), 20)

	# Run 2: 50 kills, wave 15 = floor(5 + 15) = 20 points
	host.add_run_points(50, 15)
	assert_eq(host.get_total_points(), 40)

	# Run 3: 200 kills, wave 20 = floor(20 + 20) = 40 points
	host.add_run_points(200, 20)
	assert_eq(host.get_total_points(), 80)


func test_highest_wave_tracks_maximum() -> void:
	var host := MetaProgressionHost.new()

	host.add_run_points(10, 5)
	assert_eq(host.get_highest_wave(), 5)

	host.add_run_points(10, 3)
	assert_eq(host.get_highest_wave(), 5, "Highest wave should not decrease")

	host.add_run_points(10, 12)
	assert_eq(host.get_highest_wave(), 12, "Highest wave should update when exceeded")


# ---------------------------------------------------------------------------
# Unlock threshold tests
# ---------------------------------------------------------------------------

func test_unlock_at_5_points() -> void:
	var host := MetaProgressionHost.new()

	# Points = floor(50 * 0.1 + 0 * 1.0) = 5
	host.add_run_points(50, 0)
	assert_eq(host.get_total_points(), 5)
	assert_true(host.is_unlocked("weapon_fire_rate"), "Should unlock weapon_fire_rate at 5 points")


func test_unlock_at_15_points() -> void:
	var host := MetaProgressionHost.new()

	# One big run: 150 kills, 0 waves = 15 points
	host.add_run_points(150, 0)
	assert_eq(host.get_total_points(), 15)
	assert_true(host.is_unlocked("weapon_fire_rate"), "Should unlock at 5")
	assert_true(host.is_unlocked("weapon_damage"), "Should unlock at 15")


func test_unlock_at_25_points() -> void:
	var host := MetaProgressionHost.new()

	# 250 kills = 25 points
	host.add_run_points(250, 0)
	assert_true(host.is_unlocked("weapon_fire_rate"))
	assert_true(host.is_unlocked("weapon_damage"))
	assert_true(host.is_unlocked("skill_cd"))


func test_unlock_at_40_points() -> void:
	var host := MetaProgressionHost.new()

	# 400 kills = 40 points
	host.add_run_points(400, 0)
	assert_true(host.is_unlocked("skill2_damage"))


func test_unlock_at_60_points() -> void:
	var host := MetaProgressionHost.new()

	# 600 kills = 60 points
	host.add_run_points(600, 0)
	assert_true(host.is_unlocked("dodge_charge"))


func test_all_thresholds_unlocked_at_60_plus() -> void:
	var host := MetaProgressionHost.new()

	host.add_run_points(600, 0)
	assert_eq(host.get_unlocks().size(), 5, "All 5 unlocks should be active at 60+ points")
	assert_eq(host.get_next_threshold(), -1, "No next threshold when all unlocked")


# ---------------------------------------------------------------------------
# Next threshold tests
# ---------------------------------------------------------------------------

func test_next_threshold_at_zero_points() -> void:
	var host := MetaProgressionHost.new()
	assert_eq(host.get_next_threshold(), 5, "Next threshold at 0 points should be 5")


func test_next_threshold_after_partial_unlocks() -> void:
	var host := MetaProgressionHost.new()

	host.add_run_points(200, 0)  # 20 points -> unlocks at 5 and 15
	assert_eq(host.get_total_points(), 20)
	assert_eq(host.get_next_threshold(), 25, "Next threshold should be 25")


func test_next_threshold_negative_when_all_unlocked() -> void:
	var host := MetaProgressionHost.new()

	host.add_run_points(1000, 0)  # 100 points -> all unlocked
	assert_eq(host.get_next_threshold(), -1)


# ---------------------------------------------------------------------------
# Edge case tests
# ---------------------------------------------------------------------------

func test_single_run_crosses_multiple_thresholds() -> void:
	var host := MetaProgressionHost.new()

	# 600 kills = 60 points -> crosses all 5 thresholds in one run
	host.add_run_points(600, 0)
	assert_eq(host.get_unlocks().size(), 5, "One big run should unlock all 5 thresholds")


func test_duplicate_unlock_not_added() -> void:
	var host := MetaProgressionHost.new()

	# Multiple runs that re-cross thresholds should not duplicate unlocks.
	host.add_run_points(100, 0)   # 10 points -> unlocks fire_rate, not damage yet
	host.add_run_points(100, 0)   # another 10 -> 20 total, unlocks damage
	host.add_run_points(100, 0)   # another 10 -> 30 total, unlocks skill_cd

	assert_eq(host.get_unlocks().size(), 3, "Should have exactly 3 unique unlocks")

	# Verify no duplicate IDs.
	var seen: Array[String] = []
	for id in host.get_unlocks():
		assert_false(id in seen, "Unlock ID should not be duplicated: " + id)
		seen.append(id)


func test_wave_contribution_matters() -> void:
	var host := MetaProgressionHost.new()

	# High kills + zero wave vs zero kills + high wave.
	# Scenario A: 100 kills, wave 0 = 10 points
	host.add_run_points(100, 0)
	assert_eq(host.get_total_points(), 10)

	# Scenario B (separate test): 0 kills, wave 10 = 10 points
	var host2 := MetaProgressionHost.new()
	host2.add_run_points(0, 10)
	assert_eq(host2.get_total_points(), 10)
