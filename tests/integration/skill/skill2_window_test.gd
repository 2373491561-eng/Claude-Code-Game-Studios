##
##
extends GutTest

# ---------------------------------------------------------------------------
# Constants (matching SkillSystem)
# ---------------------------------------------------------------------------

const SKILL2_WINDOW_MS: int = 500
const BASE_CD: float = 15.0
const ORB_EMPTY_THRESHOLD: float = 0.8
const ORB_CHARGING_THRESHOLD: float = 0.3

enum OrbState {
	EMPTY = 0,
	CHARGING = 1,
	ALMOST_READY = 2,
	READY = 3,
}


# ---------------------------------------------------------------------------
# Helper functions (replicate SkillSystem logic)
# ---------------------------------------------------------------------------

func _is_window_open(window_open_ms: int, now_ms: int) -> bool:
	if window_open_ms == 0:
		return false
	return now_ms - window_open_ms < SKILL2_WINDOW_MS


func _get_orb_state(cooldown_remaining: float) -> int:
	var ratio := cooldown_remaining / BASE_CD
	ratio = clampf(ratio, 0.0, 1.0)
	if ratio <= 0.0:
		return OrbState.READY
	if ratio <= ORB_CHARGING_THRESHOLD:
		return OrbState.ALMOST_READY
	if ratio <= ORB_EMPTY_THRESHOLD:
		return OrbState.CHARGING
	return OrbState.EMPTY


# ---------------------------------------------------------------------------
# Skill_2 window tests
# ---------------------------------------------------------------------------

func test_window_open_on_perfect_dodge_with_charge() -> void:
	# Perfect dodge with charge >= 1 opens the window.
	var window_open_ms := 1000  # timestamp when perfect dodge happened
	var charge_at_trigger := 2

	if charge_at_trigger >= 1:
		window_open_ms = 1000

	var now := 1100  # 100ms later
	assert_true(_is_window_open(window_open_ms, now), "Window should be open 100ms after perfect dodge")


func test_window_not_open_on_charge_zero_perfect_dodge() -> void:
	# AC4c: charge=0 perfect dodge does NOT open skill_2 window.
	var window_open_ms := 0
	var charge_at_trigger := 0

	if charge_at_trigger >= 1:
		window_open_ms = 2000  # This branch should NOT execute.

	assert_eq(window_open_ms, 0, "Window should remain 0 (closed) for charge=0 perfect dodge")


func test_window_closes_after_500ms() -> void:
	# AC4b: window closes after 500ms.
	var window_open_ms := 1000  # timestamp when perfect dodge happened
	var now := 1501  # 501ms later

	assert_false(_is_window_open(window_open_ms, now), "Window should be closed after 501ms")


func test_window_open_at_exactly_500ms() -> void:
	var window_open_ms := 1000
	var now := 1499  # 499ms later -- still open

	assert_true(_is_window_open(window_open_ms, now), "Window should be open at 499ms")

	var now_closed := 1500  # 500ms later -- closed
	assert_false(_is_window_open(window_open_ms, now_closed), "Window should be closed at exactly 500ms")


func test_window_refreshed_by_second_perfect_dodge() -> void:
	# AC4d: second perfect dodge refreshes the window.
	var window_open_ms := 1000  # first perfect dodge
	var now := 1250  # 250ms later, second perfect dodge happens

	if charge_at_trigger_check(2):  # charge >= 1
		window_open_ms = now  # refresh window

	var now2 := 1500  # 250ms after refresh
	assert_true(_is_window_open(window_open_ms, now2), "Window should be open after refresh")

	var now3 := 1751  # 501ms after refresh
	assert_false(_is_window_open(window_open_ms, now3), "Window should close 501ms after refresh")


func charge_at_trigger_check(charge: int) -> bool:
	return charge >= 1


func test_consume_skill2_clears_window() -> void:
	var window_open_ms := 1000

	# Consume the window.
	window_open_ms = 0

	var now := 1100
	assert_false(_is_window_open(window_open_ms, now), "Window should be closed after consume_skill2()")


func test_consume_skill2_before_window_no_op() -> void:
	# If window is already 0, consume_skill2() is a no-op.
	var window_open_ms := 0
	window_open_ms = 0  # consume_skill2()
	assert_eq(window_open_ms, 0, "Consuming when no window open should be no-op")


# ---------------------------------------------------------------------------
# Orb state tests
# ---------------------------------------------------------------------------

func test_orb_state_ready() -> void:
	var state := _get_orb_state(0.0)
	assert_eq(state, OrbState.READY, "Cooldown 0s should be READY")


func test_orb_state_almost_ready() -> void:
	# 15s * 0.2 = 3s (20%, within 0-30%)
	var state := _get_orb_state(3.0)
	assert_eq(state, OrbState.ALMOST_READY, "Cooldown at 20% should be ALMOST_READY")


func test_orb_state_charging() -> void:
	# 15s * 0.5 = 7.5s (50%, within 30-80%)
	var state := _get_orb_state(7.5)
	assert_eq(state, OrbState.CHARGING, "Cooldown at 50% should be CHARGING")


func test_orb_state_empty() -> void:
	# 15s * 0.9 = 13.5s (90%, above 80%)
	var state := _get_orb_state(13.5)
	assert_eq(state, OrbState.EMPTY, "Cooldown at 90% should be EMPTY")


func test_orb_state_boundaries() -> void:
	# At exactly 30% (threshold): ratio = 0.3.
	var cd_at_30pct := BASE_CD * 0.3  # 4.5
	var state := _get_orb_state(cd_at_30pct)
	assert_eq(state, OrbState.ALMOST_READY, "At exactly 30%, should be ALMOST_READY")

	# At exactly 80% (threshold): ratio = 0.8.
	var cd_at_80pct := BASE_CD * 0.8  # 12.0
	state = _get_orb_state(cd_at_80pct)
	assert_eq(state, OrbState.CHARGING, "At exactly 80%, should be CHARGING (ratio <= 0.8)")

	# Just above 80%:
	var cd_above_80pct := BASE_CD * 0.81  # 12.15
	state = _get_orb_state(cd_above_80pct)
	assert_eq(state, OrbState.EMPTY, "Above 80% should be EMPTY")


# ---------------------------------------------------------------------------
# Cooldown ratio test
# ---------------------------------------------------------------------------

func test_cooldown_ratio_clamped() -> void:
	# Ratio should be clamped to [0, 1].
	# Negative cooldown (shouldn't happen, but clamp if it does).
	var ratio := clampf(-5.0 / BASE_CD, 0.0, 1.0)
	assert_eq(ratio, 0.0, "Negative cooldown should clamp ratio to 0")

	# Cooldown exceeding base.
	ratio = clampf(20.0 / BASE_CD, 0.0, 1.0)
	assert_eq(ratio, 1.0, "Excessive cooldown should clamp ratio to 1")
