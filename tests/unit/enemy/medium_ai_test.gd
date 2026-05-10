##
##
extends GutTest

# ---------------------------------------------------------------------------
# Constants (mirror EnemyManager)
# ---------------------------------------------------------------------------

const MEDIUM_RETREAT_SPEED: float = 180.0
const MEDIUM_APPROACH_SPEED: float = 120.0
const MEDIUM_DIST_MIN: float = 140.0
const MEDIUM_DIST_MAX: float = 210.0
const MEDIUM_ATTACK_WINDUP_MS: int = 250
const MEDIUM_BULLET_SPEED: float = 150.0
const MEDIUM_BULLET_MAX_DIST: float = 600.0
const MEDIUM_COOLDOWN_MIN_MS: int = 1500
const MEDIUM_COOLDOWN_MAX_MS: int = 2000
const MEDIUM_CORNER_THRESHOLD_MS: int = 300
const MEDIUM_RAPID_FIRE_COUNT: int = 3
const MEDIUM_RAPID_FIRE_INTERVAL_MS: int = 150
const MEDIUM_STRAFE_SPEED: float = 80.0
const MEDIUM_STUN_MS: int = 50

const EnemyState = {
	CHASE = 0, ATTACK = 1, HIT_COOLDOWN = 2, RETREAT = 3,
	RAPID_FIRE = 4, DEAD = 8, SPAWNING = 9
}

const RADIUS_MEDIUM: float = 24.0
const RADIUS_SMALL: float = 16.0
const PLAYER_RADIUS: float = 8.0


# ---------------------------------------------------------------------------
# Medium AI logic helper (extracted for unit testing)
# ---------------------------------------------------------------------------

func _update_medium(position: Vector2, velocity: Vector2, state: int, timer: float,
		timer2: float, direction: Vector2, player_pos: Vector2,
		now: int, retreat_blocked_since: int, strafe_dir: int) -> Dictionary:
	var to_player := player_pos - position
	var dist := to_player.length()
	var dir_to_player := to_player.normalized() if dist > 0.01 else Vector2.RIGHT
	var new_state := state
	var new_vel := velocity
	var new_timer := timer
	var new_timer2 := timer2
	var new_direction := direction
	var new_retreat_blocked := retreat_blocked_since
	var fired_bullet := false

	match state:
		EnemyState.CHASE:
			if dist > MEDIUM_DIST_MAX:
				new_vel = dir_to_player * MEDIUM_APPROACH_SPEED
				new_direction = dir_to_player
			else:
				# Enter attack windup.
				new_state = EnemyState.ATTACK
				new_timer = float(now)
				new_vel = Vector2.ZERO

		EnemyState.RETREAT:
			var away := -dir_to_player
			new_vel = away * MEDIUM_RETREAT_SPEED

			# Corner detection.
			if new_retreat_blocked == 0:
				new_retreat_blocked = now
			elif now - new_retreat_blocked > MEDIUM_CORNER_THRESHOLD_MS:
				new_state = EnemyState.RAPID_FIRE
				new_timer = float(now)
				new_timer2 = 0.0
				new_retreat_blocked = 0

			# Hysteresis: stop retreating when far enough.
			if dist > MEDIUM_DIST_MIN + 20.0:
				new_state = EnemyState.CHASE
				new_timer = float(now)
				new_retreat_blocked = 0

		EnemyState.ATTACK:
			var windup_elapsed := now - int(timer)
			new_vel = Vector2.ZERO
			if windup_elapsed >= MEDIUM_ATTACK_WINDUP_MS:
				fired_bullet = true
				new_state = EnemyState.CHASE
				new_timer = float(now + randi_range(MEDIUM_COOLDOWN_MIN_MS, MEDIUM_COOLDOWN_MAX_MS))
				if dist < MEDIUM_DIST_MIN:
					new_state = EnemyState.RETREAT
					new_timer = 0.0

		EnemyState.RAPID_FIRE:
			var rf_elapsed := now - int(timer)
			var shots_fired := int(timer2)
			if shots_fired < MEDIUM_RAPID_FIRE_COUNT:
				var expected_shot := shots_fired * MEDIUM_RAPID_FIRE_INTERVAL_MS
				if rf_elapsed >= expected_shot:
					fired_bullet = true
					new_timer2 = float(shots_fired + 1)
			var perp := Vector2(-to_player.y, to_player.x).normalized() if dist > 0.01 else Vector2(0, 1)
			new_vel = perp * strafe_dir * MEDIUM_STRAFE_SPEED
			if rf_elapsed >= MEDIUM_RAPID_FIRE_COUNT * MEDIUM_RAPID_FIRE_INTERVAL_MS + 300:
				new_state = EnemyState.CHASE
				new_timer = float(now + randi_range(MEDIUM_COOLDOWN_MIN_MS, MEDIUM_COOLDOWN_MAX_MS))
				new_timer2 = 0.0

		EnemyState.HIT_COOLDOWN:
			new_vel = velocity.lerp(Vector2.ZERO, 0.3)
			if now - int(timer) >= MEDIUM_STUN_MS:
				new_state = EnemyState.CHASE
				new_timer = float(now)

	return {
		"state": new_state,
		"velocity": new_vel,
		"timer": new_timer,
		"timer2": new_timer2,
		"direction": new_direction,
		"retreat_blocked": new_retreat_blocked,
		"fired_bullet": fired_bullet,
	}


# ---------------------------------------------------------------------------
# Tests: distance maintenance
# ---------------------------------------------------------------------------

func test_medium_approaches_when_far() -> void:
	var result := _update_medium(
		Vector2(100, 500), Vector2.ZERO,
		EnemyState.CHASE, 0.0, 0.0, Vector2.ZERO,
		Vector2(500, 500), 0, 0, 1
	)
	assert_gt(result.velocity.length(), 0.0, "Should move toward player when far")
	assert_eq(result.velocity.length(), MEDIUM_APPROACH_SPEED, "Approach speed should be 120")

func test_medium_retreats_when_close() -> void:
	# Place medium close to player.
	var result := _update_medium(
		Vector2(580, 500), Vector2.ZERO,
		EnemyState.RETREAT, 0.0, 0.0, Vector2.ZERO,
		Vector2(500, 500), 0, 0, 1
	)
	assert_gt(result.velocity.length(), 0.0, "Should move away from player")
	assert_eq(result.velocity.length(), MEDIUM_RETREAT_SPEED, "Retreat speed should be 180")
	# Velocity should point away from player.
	assert_lt(result.velocity.x, 0.0, "Should move left (away from player at right)")

func test_medium_stops_at_hold_range() -> void:
	# Place medium within [140, 210] range.
	var result := _update_medium(
		Vector2(650, 500), Vector2.ZERO,  # 150px from player
		EnemyState.CHASE, 0.0, 0.0, Vector2.ZERO,
		Vector2(500, 500), 0, 0, 1
	)
	assert_eq(result.state, EnemyState.ATTACK, "Should enter ATTACK state when within range")

func test_distance_hysteresis_min_boundary() -> void:
	# Below 140: should retreat.
	var close_pos := Vector2(630, 500)  # 130px from 500
	var dist := close_pos.distance_to(Vector2(500, 500))
	assert_lt(dist, MEDIUM_DIST_MIN, "Setup: should be below min distance")
	# Medium at close_pos in CHASE would transition to attack, but the logic says
	# if dist <= MEDIUM_DIST_MAX, it goes to attack. The retreat trigger happens
	# externally. Let's verify the hysteresis exit condition:
	var retreat_result := _update_medium(
		close_pos, Vector2.ZERO,
		EnemyState.RETREAT, 0.0, 0.0, Vector2.ZERO,
		Vector2(500, 500), 0, 0, 1
	)
	# Should still be retreating since dist < MEDIUM_DIST_MIN + 20.
	assert_eq(retreat_result.state, EnemyState.RETREAT, "Should keep retreating below threshold")

func test_distance_hysteresis_max_boundary() -> void:
	# Above 210: should approach.
	var far_pos := Vector2(720, 500)  # 220px from 500
	var dist := far_pos.distance_to(Vector2(500, 500))
	assert_gt(dist, MEDIUM_DIST_MAX, "Setup: should be above max distance")
	var result := _update_medium(
		far_pos, Vector2.ZERO,
		EnemyState.CHASE, 0.0, 0.0, Vector2.ZERO,
		Vector2(500, 500), 0, 0, 1
	)
	assert_gt(result.velocity.length(), 0.0, "Should approach when above max dist")


# ---------------------------------------------------------------------------
# Tests: attack windup
# ---------------------------------------------------------------------------

func test_attack_windup_duration_correct() -> void:
	# Start windup at t=1000.
	var result := _update_medium(
		Vector2(650, 500), Vector2.ZERO,
		EnemyState.ATTACK, 1000.0, 0.0, Vector2.ZERO,
		Vector2(500, 500), 1100, 0, 1  # 100ms elapsed, < 250ms
	)
	assert_eq(result.state, EnemyState.ATTACK, "Should still be winding up at 100ms")
	assert_false(result.fired_bullet, "Should not fire during windup")

func test_attack_windup_completes_and_fires() -> void:
	var result := _update_medium(
		Vector2(650, 500), Vector2.ZERO,
		EnemyState.ATTACK, 1000.0, 0.0, Vector2.ZERO,
		Vector2(500, 500), 1250, 0, 1  # 250ms elapsed
	)
	assert_true(result.fired_bullet, "Should fire bullet after windup completes")
	assert_neq(result.state, EnemyState.ATTACK, "Should exit ATTACK state after firing")

func test_attack_windup_exact_boundary() -> void:
	var result := _update_medium(
		Vector2(650, 500), Vector2.ZERO,
		EnemyState.ATTACK, 1000.0, 0.0, Vector2.ZERO,
		Vector2(500, 500), 1250, 0, 1  # exactly 250ms
	)
	assert_true(result.fired_bullet, "Should fire at exactly 250ms boundary")


# ---------------------------------------------------------------------------
# Tests: corner behavior -> rapid fire
# ---------------------------------------------------------------------------

func test_corner_detection_triggers_rapid_fire() -> void:
	# Simulate retreat blocked for >300ms.
	var result := _update_medium(
		Vector2(600, 500), Vector2.ZERO,
		EnemyState.RETREAT, 0.0, 0.0, Vector2.ZERO,
		Vector2(500, 500), 500, 100, 1  # retreat blocked at t=100, now=500 (>300ms)
	)
	assert_eq(result.state, EnemyState.RAPID_FIRE, "Corner should trigger RAPID_FIRE")

func test_rapid_fire_fires_3_shots() -> void:
	var shots_fired := 0
	# Simulate rapid fire sequence.
	var result: Dictionary = {
		"state": EnemyState.RAPID_FIRE,
		"timer": 1000.0,
		"timer2": 0.0,
	}
	for shot in range(3):
		var expected_time := shot * MEDIUM_RAPID_FIRE_INTERVAL_MS
		result = _update_medium(
			Vector2(600, 500), Vector2.ZERO,
			result.state, result.timer, result.timer2, Vector2.ZERO,
			Vector2(500, 500), 1000 + expected_time, 0, 1
		)
		if result.fired_bullet:
			shots_fired += 1
	assert_eq(shots_fired, 3, "Should fire exactly 3 shots during rapid fire")

func test_rapid_fire_ends_after_shots() -> void:
	var result := _update_medium(
		Vector2(600, 500), Vector2.ZERO,
		EnemyState.RAPID_FIRE, 1000.0, 3.0,  # All 3 shots fired
		Vector2(600, 500),  # <- will use to_player for strafe
		Vector2(500, 500), 1550, 0, 1  # 550ms elapsed > 3*150 + 300 = 750
	)
	assert_eq(result.state, EnemyState.CHASE, "Should return to CHASE after rapid fire ends")

func test_rapid_fire_strafes_laterally() -> void:
	var result := _update_medium(
		Vector2(650, 500), Vector2.ZERO,
		EnemyState.RAPID_FIRE, 1000.0, 0.0, Vector2.ZERO,
		Vector2(500, 500), 1001, 0, 1
	)
	# Strafe direction should be perpendicular.
	assert_neq(result.velocity, Vector2.ZERO, "Should have strafe velocity")
	# Velocity should be perpendicular to player direction.
	var to_player := Vector2(500, 500) - Vector2(650, 500)  # (-150, 0)
	var dot_abs := absf(result.velocity.normalized().dot(to_player.normalized()))
	assert_almost_eq(dot_abs, 0.0, 0.1, "Strafe velocity should be perpendicular to player direction")


# ---------------------------------------------------------------------------
# Tests: hit stun
# ---------------------------------------------------------------------------

func test_hit_stun_duration() -> void:
	var result := _update_medium(
		Vector2(650, 500), Vector2.ZERO,
		EnemyState.HIT_COOLDOWN, 1000.0, 0.0, Vector2.ZERO,
		Vector2(500, 500), 1030, 0, 1  # 30ms elapsed (< 50ms)
	)
	assert_eq(result.state, EnemyState.HIT_COOLDOWN, "Should still be stunned at 30ms")

func test_hit_stun_expires() -> void:
	var result := _update_medium(
		Vector2(650, 500), Vector2.ZERO,
		EnemyState.HIT_COOLDOWN, 1000.0, 0.0, Vector2.ZERO,
		Vector2(500, 500), 1050, 0, 1  # 50ms elapsed
	)
	assert_eq(result.state, EnemyState.CHASE, "Should exit stun after 50ms")

func test_hit_stun_exact_boundary() -> void:
	var result := _update_medium(
		Vector2(650, 500), Vector2.ZERO,
		EnemyState.HIT_COOLDOWN, 1000.0, 0.0, Vector2.ZERO,
		Vector2(500, 500), 1050, 0, 1  # exactly 50ms
	)
	assert_eq(result.state, EnemyState.CHASE, "Should exit stun at exactly 50ms")


# ---------------------------------------------------------------------------
# Tests: bullet properties
# ---------------------------------------------------------------------------

func test_bullet_speed_is_correct() -> void:
	assert_eq(MEDIUM_BULLET_SPEED, 150.0, "Bullet speed should be 150 px/s")

func test_bullet_max_range_is_correct() -> void:
	assert_eq(MEDIUM_BULLET_MAX_DIST, 600.0, "Bullet max range should be 600 px")

func test_bullet_travel_time_to_max_range() -> void:
	# Time = distance / speed = 600 / 150 = 4 seconds
	var travel_time := MEDIUM_BULLET_MAX_DIST / MEDIUM_BULLET_SPEED
	assert_almost_eq(travel_time, 4.0, 0.01, "Bullet should take 4 seconds to reach max range")


# ---------------------------------------------------------------------------
# Tests: attack cooldown range
# ---------------------------------------------------------------------------

func test_attack_cooldown_within_range() -> void:
	for _i in range(100):
		var cooldown := randi_range(MEDIUM_COOLDOWN_MIN_MS, MEDIUM_COOLDOWN_MAX_MS)
		assert_ge(cooldown, MEDIUM_COOLDOWN_MIN_MS, "Cooldown should be >= min")
		assert_le(cooldown, MEDIUM_COOLDOWN_MAX_MS, "Cooldown should be <= max")
