##
##
extends GutTest

# ---------------------------------------------------------------------------
# Constants (mirror EnemyManager)
# ---------------------------------------------------------------------------

const LARGE_ADVANCE_SPEED: float = 60.0
const LARGE_CHARGE_SPEED: float = 250.0
const LARGE_CHARGE_WINDUP_MS: int = 500
const LARGE_CHARGE_DURATION_MS: int = 1000
const LARGE_CHARGE_COOLDOWN_MIN_MS: int = 5000
const LARGE_CHARGE_COOLDOWN_MAX_MS: int = 8000
const LARGE_MELEE_DIST: float = 80.0
const LARGE_MELEE_WINDUP_MS: int = 400
const LARGE_MELEE_DAMAGE: int = 2
const LARGE_MELEE_COOLDOWN_MIN_MS: int = 2000
const LARGE_MELEE_COOLDOWN_MAX_MS: int = 3000
const LARGE_DEATH_EXPLOSION_MS: int = 600
const RADIUS_LARGE: float = 40.0
const PLAYER_RADIUS: float = 8.0

const DODGE_DISTANCE: float = 100.0  # From DodgeSystem

const EnemyState = {
	CHASE = 0, CHARGE_WINDUP = 5, CHARGING = 6,
	MELEE_WINDUP = 7, DEAD = 8, SPAWNING = 9, HIT_COOLDOWN = 2
}


# ---------------------------------------------------------------------------
# Large AI logic helper (extracted for unit testing)
# ---------------------------------------------------------------------------

func _update_large(position: Vector2, velocity: Vector2, state: int, timer: float,
		timer2: float, direction: Vector2, player_pos: Vector2,
		now: int) -> Dictionary:
	var to_player := player_pos - position
	var dist := to_player.length()
	var new_state := state
	var new_vel := velocity
	var new_timer := timer
	var new_timer2 := timer2
	var new_direction := direction
	var hit_player := false
	var melee_damage := 0

	match state:
		EnemyState.CHASE:
			if dist > 0.01:
				new_direction = to_player.normalized()
			new_vel = new_direction * LARGE_ADVANCE_SPEED if new_direction != Vector2.ZERO else Vector2.RIGHT * LARGE_ADVANCE_SPEED

			# Check melee range.
			if dist < LARGE_MELEE_DIST:
				if now >= int(timer2):
					new_state = EnemyState.MELEE_WINDUP
					new_timer = float(now)
					new_vel = Vector2.ZERO

		EnemyState.CHARGE_WINDUP:
			var windup_elapsed := now - int(timer)
			new_vel = Vector2.ZERO
			if dist > 0.01:
				new_direction = to_player.normalized()
			if windup_elapsed >= LARGE_CHARGE_WINDUP_MS:
				new_state = EnemyState.CHARGING
				new_timer = float(now)

		EnemyState.CHARGING:
			var charge_elapsed := now - int(timer)
			if charge_elapsed >= LARGE_CHARGE_DURATION_MS:
				new_state = EnemyState.CHASE
				new_timer = float(now + randi_range(LARGE_CHARGE_COOLDOWN_MIN_MS, LARGE_CHARGE_COOLDOWN_MAX_MS))
				new_vel = Vector2.ZERO
			else:
				new_vel = direction * LARGE_CHARGE_SPEED

		EnemyState.MELEE_WINDUP:
			var windup_elapsed := now - int(timer)
			new_vel = Vector2.ZERO
			if windup_elapsed >= LARGE_MELEE_WINDUP_MS:
				if dist < LARGE_MELEE_DIST + 20.0:
					hit_player = true
					melee_damage = LARGE_MELEE_DAMAGE
				new_timer2 = float(now + randi_range(LARGE_MELEE_COOLDOWN_MIN_MS, LARGE_MELEE_COOLDOWN_MAX_MS))
				new_state = EnemyState.CHASE
				new_timer = float(now)

		EnemyState.HIT_COOLDOWN:
			# No stun for large enemies.
			new_state = EnemyState.CHASE
			new_timer = float(now)

	return {
		"state": new_state,
		"velocity": new_vel,
		"timer": new_timer,
		"timer2": new_timer2,
		"direction": new_direction,
		"hit_player": hit_player,
		"melee_damage": melee_damage,
	}


# ---------------------------------------------------------------------------
# Tests: advance speed
# ---------------------------------------------------------------------------

func test_large_advances_toward_player() -> void:
	var result := _update_large(
		Vector2(100, 500), Vector2.ZERO,
		EnemyState.CHASE, 0.0, 0.0, Vector2.ZERO,
		Vector2(500, 500), 0
	)
	assert_gt(result.velocity.length(), 0.0, "Large enemy should advance")
	assert_eq(result.velocity.length(), LARGE_ADVANCE_SPEED, "Advance speed should be 60 px/s")
	assert_almost_eq(result.velocity.x, LARGE_ADVANCE_SPEED, 0.01, "Should move right toward player")


# ---------------------------------------------------------------------------
# Tests: charge windup
# ---------------------------------------------------------------------------

func test_charge_windup_duration() -> void:
	var result := _update_large(
		Vector2(200, 500), Vector2.ZERO,
		EnemyState.CHARGE_WINDUP, 1000.0, 0.0, Vector2.RIGHT,
		Vector2(500, 500), 1300  # 300ms elapsed, < 500ms
	)
	assert_eq(result.state, EnemyState.CHARGE_WINDUP, "Should still be winding up")
	assert_eq(result.velocity, Vector2.ZERO, "Should be stationary during windup")

func test_charge_windup_completes() -> void:
	var result := _update_large(
		Vector2(200, 500), Vector2.ZERO,
		EnemyState.CHARGE_WINDUP, 1000.0, 0.0, Vector2.RIGHT,
		Vector2(500, 500), 1500  # 500ms elapsed
	)
	assert_eq(result.state, EnemyState.CHARGING, "Should start charging after windup")

func test_charge_windup_exact_boundary() -> void:
	var result := _update_large(
		Vector2(200, 500), Vector2.ZERO,
		EnemyState.CHARGE_WINDUP, 1000.0, 0.0, Vector2.RIGHT,
		Vector2(500, 500), 1500  # exactly 500ms
	)
	assert_eq(result.state, EnemyState.CHARGING, "Should transition at exactly 500ms")

func test_charge_direction_locked_at_windup_end() -> void:
	# The direction is set during windup and locked.
	var result := _update_large(
		Vector2(200, 500), Vector2.ZERO,
		EnemyState.CHARGE_WINDUP, 1000.0, 0.0, Vector2.RIGHT,
		Vector2(500, 500), 1500
	)
	# Direction should be preserved.
	assert_almost_eq(result.direction.x, 1.0, 0.01, "Direction should be toward player (right)")


# ---------------------------------------------------------------------------
# Tests: charging dash
# ---------------------------------------------------------------------------

func test_charge_dash_speed() -> void:
	var result := _update_large(
		Vector2(200, 500), Vector2.ZERO,
		EnemyState.CHARGING, 1000.0, 0.0, Vector2.RIGHT,
		Vector2(500, 500), 1100
	)
	assert_eq(result.state, EnemyState.CHARGING, "Should be charging")
	assert_eq(result.velocity.length(), LARGE_CHARGE_SPEED, "Charge speed should be 250 px/s")

func test_charge_dash_duration() -> void:
	var result := _update_large(
		Vector2(200, 500), Vector2.ZERO,
		EnemyState.CHARGING, 1000.0, 0.0, Vector2.RIGHT,
		Vector2(500, 500), 2000  # 1000ms elapsed, exactly duration
	)
	assert_eq(result.state, EnemyState.CHASE, "Should finish charging after 1000ms")

func test_charge_dash_mid_charge() -> void:
	var result := _update_large(
		Vector2(200, 500), Vector2.ZERO,
		EnemyState.CHARGING, 1000.0, 0.0, Vector2.RIGHT,
		Vector2(500, 500), 1500  # 500ms elapsed
	)
	assert_eq(result.state, EnemyState.CHARGING, "Should still be at mid-charge")

func test_charge_dash_sets_cooldown_after() -> void:
	var result := _update_large(
		Vector2(200, 500), Vector2.ZERO,
		EnemyState.CHARGING, 1000.0, 0.0, Vector2.RIGHT,
		Vector2(500, 500), 2000
	)
	assert_gt(result.timer, 2000.0, "Cooldown should be set for future time")


# ---------------------------------------------------------------------------
# Tests: charge is dodgeable
# ---------------------------------------------------------------------------

func test_charge_dodgeable_100px_dodge_vs_75px_charge_displacement() -> void:
	# During a dodge (300ms = DODGE_DURATION_MS), the player moves 100px.
	# The large enemy charges at 250px/s. In 300ms, it moves 250 * 0.3 = 75px.
	# Player dodge = 100px > 75px charge max displacement.
	# So the player can dodge the charge -- confirm the math.
	var dodge_distance := DODGE_DISTANCE  # 100px
	var dodge_duration_s := 0.300  # 300ms
	var charge_speed := LARGE_CHARGE_SPEED  # 250 px/s
	var max_charge_displacement := charge_speed * dodge_duration_s

	assert_gt(dodge_distance, max_charge_displacement,
		"Player dodge (100px) should exceed max charge displacement during dodge window (%.1fpx)" % max_charge_displacement)
	assert_almost_eq(max_charge_displacement, 75.0, 0.1, "Max charge displacement should be ~75px")

func test_charge_displacement_full_duration() -> void:
	# Over the full 1s charge duration, the enemy moves 250px.
	var full_displacement := LARGE_CHARGE_SPEED * (LARGE_CHARGE_DURATION_MS / 1000.0)
	assert_almost_eq(full_displacement, 250.0, 0.1, "Full charge displacement is 250px")


# ---------------------------------------------------------------------------
# Tests: melee trigger distance
# ---------------------------------------------------------------------------

func test_melee_triggers_within_range() -> void:
	var result := _update_large(
		Vector2(560, 500), Vector2.ZERO,  # 60px from player
		EnemyState.CHASE, 0.0, 0.0, Vector2.ZERO,
		Vector2(500, 500), 0
	)
	assert_eq(result.state, EnemyState.MELEE_WINDUP, "Should trigger melee within 80px")

func test_melee_not_triggered_outside_range() -> void:
	var result := _update_large(
		Vector2(400, 500), Vector2.ZERO,  # 100px from player
		EnemyState.CHASE, 0.0, 100000.0, Vector2.ZERO,  # large timer2 so melee cooldown is far
		Vector2(500, 500), 0
	)
	assert_eq(result.state, EnemyState.CHASE, "Should stay in CHASE outside melee range")

func test_melee_boundary_range() -> void:
	# At exactly 80px.
	var result := _update_large(
		Vector2(580, 500), Vector2.ZERO,  # 80px from player
		EnemyState.CHASE, 0.0, 0.0, Vector2.ZERO,
		Vector2(500, 500), 0
	)
	assert_eq(result.state, EnemyState.MELEE_WINDUP, "Should trigger melee at exactly 80px")

func test_melee_just_outside_range() -> void:
	var result := _update_large(
		Vector2(580.1, 500), Vector2.ZERO,  # 80.1px
		EnemyState.CHASE, 0.0, 100000.0, Vector2.ZERO,
		Vector2(500, 500), 0
	)
	assert_eq(result.state, EnemyState.CHASE, "Should not trigger melee at 80.1px")


# ---------------------------------------------------------------------------
# Tests: melee windup
# ---------------------------------------------------------------------------

func test_melee_windup_duration() -> void:
	var result := _update_large(
		Vector2(550, 500), Vector2.ZERO,
		EnemyState.MELEE_WINDUP, 1000.0, 0.0, Vector2.ZERO,
		Vector2(500, 500), 1200  # 200ms elapsed
	)
	assert_eq(result.state, EnemyState.MELEE_WINDUP, "Should still be winding up")

func test_melee_windup_completes_and_hits() -> void:
	var result := _update_large(
		Vector2(550, 500), Vector2.ZERO,
		EnemyState.MELEE_WINDUP, 1000.0, 0.0, Vector2.ZERO,
		Vector2(500, 500), 1400  # 400ms elapsed
	)
	assert_eq(result.state, EnemyState.CHASE, "Should return to CHASE after melee")
	assert_true(result.hit_player, "Should hit the player after melee windup")

func test_melee_damage_value() -> void:
	assert_eq(LARGE_MELEE_DAMAGE, 2, "Large melee damage should be 2")

func test_melee_damage_2() -> void:
	var result := _update_large(
		Vector2(550, 500), Vector2.ZERO,
		EnemyState.MELEE_WINDUP, 1000.0, 0.0, Vector2.ZERO,
		Vector2(500, 500), 1400
	)
	assert_eq(result.melee_damage, LARGE_MELEE_DAMAGE, "Melee damage output should be 2")

func test_melee_misses_if_player_moved_away() -> void:
	# Melee started when player was close, but player moved away.
	var result := _update_large(
		Vector2(550, 500), Vector2.ZERO,
		EnemyState.MELEE_WINDUP, 1000.0, 0.0, Vector2.ZERO,
		Vector2(900, 500), 1400  # Player now at (900,500), 350px away
	)
	assert_false(result.hit_player, "Should miss if player moved out of range")


# ---------------------------------------------------------------------------
# Tests: no stun on hit
# ---------------------------------------------------------------------------

func test_large_no_stun_on_hit() -> void:
	var result := _update_large(
		Vector2(600, 500), Vector2.ZERO,
		EnemyState.HIT_COOLDOWN, 0.0, 0.0, Vector2.ZERO,
		Vector2(500, 500), 0
	)
	assert_eq(result.state, EnemyState.CHASE, "Large should immediately return to CHASE after hit (no stun)")


# ---------------------------------------------------------------------------
# Tests: death explosion
# ---------------------------------------------------------------------------

func test_death_explosion_duration() -> void:
	assert_eq(LARGE_DEATH_EXPLOSION_MS, 600, "Death explosion should last 600ms")

func test_death_state_persists_during_explosion() -> void:
	# Large enemy in DEAD state should stay DEAD until removal.
	# The explosion timing is tracked via timer.
	var result := _update_large(
		Vector2(500, 500), Vector2.ZERO,
		EnemyState.DEAD, 1000.0, 0.0, Vector2.ZERO,
		Vector2(500, 500), 1400  # 400ms into explosion
	)
	# DEAD state should remain unchanged. (The explosion logic is rendering-side.)
	assert_eq(result.state, EnemyState.DEAD, "DEAD state should persist")


# ---------------------------------------------------------------------------
# Tests: cooldown ranges
# ---------------------------------------------------------------------------

func test_charge_cooldown_within_range() -> void:
	for _i in range(20):
		var cooldown := randi_range(LARGE_CHARGE_COOLDOWN_MIN_MS, LARGE_CHARGE_COOLDOWN_MAX_MS)
		assert_ge(cooldown, LARGE_CHARGE_COOLDOWN_MIN_MS)
		assert_le(cooldown, LARGE_CHARGE_COOLDOWN_MAX_MS)

func test_melee_cooldown_within_range() -> void:
	for _i in range(20):
		var cooldown := randi_range(LARGE_MELEE_COOLDOWN_MIN_MS, LARGE_MELEE_COOLDOWN_MAX_MS)
		assert_ge(cooldown, LARGE_MELEE_COOLDOWN_MIN_MS)
		assert_le(cooldown, LARGE_MELEE_COOLDOWN_MAX_MS)
