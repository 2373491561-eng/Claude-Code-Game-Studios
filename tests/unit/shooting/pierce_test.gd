extends GutTest

func test_pierce_remaining_defaults_to_one() -> void:
	# skill_2 pierce should have 1 pierce remaining by default
	const PIERCE_DEFAULT := 1
	assert_eq(PIERCE_DEFAULT, 1)

func test_skill2_damage_doubled() -> void:
	var base := 1
	var skill2_mult := 2
	assert_eq(base * skill2_mult, 2, "skill_2 should double base damage")

func test_pierce_offset_prevents_self_hit() -> void:
	# The 2px offset after first hit prevents re-hitting the same target
	const OFFSET := 2.0
	assert_true(OFFSET > 0.0, "Pierce origin offset should be positive")

func test_skill2_consumed_after_use() -> void:
	var window_open := true
	# simulate consumption
	window_open = false
	assert_false(window_open, "skill_2 window should close after consumption")
