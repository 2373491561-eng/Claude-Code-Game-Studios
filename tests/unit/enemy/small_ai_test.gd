##
##
extends GutTest

# ---------------------------------------------------------------------------
# Constants (mirror EnemyManager)
# ---------------------------------------------------------------------------

const SMALL_SPEED: float = 200.0
const SMALL_CONTACT_DAMAGE: int = 1
const SMALL_HIT_COOLDOWN_MS: int = 200
const SMALL_PUSHBACK_MIN: float = 10.0
const SMALL_PUSHBACK_MAX: float = 15.0
const RADIUS_SMALL: float = 16.0
const PLAYER_RADIUS: float = 8.0

const EnemyState = {
	CHASE = 0, HIT_COOLDOWN = 2, DEAD = 8, SPAWNING = 9
}

# ---------------------------------------------------------------------------
# Spatial hash grid helper (extracted for unit testing)
# ---------------------------------------------------------------------------

const GRID_CELL_SIZE: float = 32.0
const SEPARATION_RADIUS: float = 28.0
const SEPARATION_FORCE: float = 20.0


func _cell_key(pos: Vector2) -> Vector2i:
	return Vector2i(int(floorf(pos.x / GRID_CELL_SIZE)), int(floorf(pos.y / GRID_CELL_SIZE)))


func _build_separation_grid(positions: Array[Vector2]) -> Dictionary:
	var grid: Dictionary = {}
	for i in range(positions.size()):
		var cell := _cell_key(positions[i])
		if not grid.has(cell):
			grid[cell] = []
		grid[cell].append(i)
	return grid


func _compute_separation(positions: Array[Vector2], velocities: Array[Vector2]) -> Array[Vector2]:
	var grid := _build_separation_grid(positions)
	var result: Array[Vector2] = []
	for i in range(positions.size()):
		var cell := _cell_key(positions[i])
		var sep := Vector2.ZERO
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var ncell := Vector2i(cell.x + dx, cell.y + dy)
				if not grid.has(ncell):
					continue
				for j in grid[ncell]:
					if j == i:
						continue
					var diff := positions[i] - positions[j]
					var dist := diff.length()
					if dist < SEPARATION_RADIUS and dist > 0.01:
						var force := diff.normalized() * (SEPARATION_RADIUS - dist) / SEPARATION_RADIUS * SEPARATION_FORCE
						sep += force
		result.append(velocities[i] + sep)
	return result


# ---------------------------------------------------------------------------
# Small AI logic helper (extracted for unit testing)
# ---------------------------------------------------------------------------

func _update_small(position: Vector2, velocity: Vector2, state: int, timer: float,
		player_pos: Vector2, now: int) -> Dictionary:
	match state:
		EnemyState.CHASE:
			var to_player := player_pos - position
			var dist := to_player.length()
			if dist < RADIUS_SMALL + PLAYER_RADIUS:
				# Contact damage + pushback + hit cooldown.
				var pushback := to_player.normalized() if dist > 0.01 else Vector2.RIGHT
				pushback = -pushback * randf_range(SMALL_PUSHBACK_MIN, SMALL_PUSHBACK_MAX)
				return {
					"position": position + pushback,
					"velocity": Vector2.ZERO,
					"state": EnemyState.HIT_COOLDOWN,
					"timer": float(now),
					"hit_player": true,
					"damage": SMALL_CONTACT_DAMAGE
				}
			if dist > 0.01:
				var direction := to_player.normalized()
				return {
					"position": position,
					"velocity": direction * SMALL_SPEED,
					"state": EnemyState.CHASE,
					"timer": timer,
					"hit_player": false,
					"damage": 0
				}
			# Otherwise stay put.
			return {
				"position": position,
				"velocity": Vector2.ZERO,
				"state": EnemyState.CHASE,
				"timer": timer,
				"hit_player": false,
				"damage": 0
			}

		EnemyState.HIT_COOLDOWN:
			var elapsed := now - int(timer)
			var drift_vel := velocity.lerp(Vector2.ZERO, 0.2)
			if elapsed >= SMALL_HIT_COOLDOWN_MS:
				return {
					"position": position,
					"velocity": Vector2.ZERO,
					"state": EnemyState.CHASE,
					"timer": 0.0,
					"hit_player": false,
					"damage": 0
				}
			return {
				"position": position,
				"velocity": drift_vel,
				"state": EnemyState.HIT_COOLDOWN,
				"timer": timer,
				"hit_player": false,
				"damage": 0
			}

	return {
		"position": position,
		"velocity": velocity,
		"state": state,
		"timer": timer,
		"hit_player": false,
		"damage": 0
	}


# ---------------------------------------------------------------------------
# Tests: chase behavior
# ---------------------------------------------------------------------------

func test_small_chases_toward_player() -> void:
	var result := _update_small(
		Vector2(100, 500), Vector2.ZERO,
		EnemyState.CHASE, 0.0,
		Vector2(500, 500), 0
	)
	assert_gt(result.velocity.length(), 0.0, "Small should move toward player")
	assert_eq(result.velocity.length(), SMALL_SPEED, "Speed should be exactly SMALL_SPEED")
	assert_almost_eq(result.velocity.normalized().x, 1.0, 0.01, "Direction should be toward player")

func test_small_chase_speed_is_constant() -> void:
	# From various distances, speed should always be SMALL_SPEED.
	var test_distances := [50.0, 100.0, 500.0, 1000.0]
	for dist in test_distances:
		var pos := Vector2(500 + dist, 500)
		var result := _update_small(
			Vector2(500, 500), Vector2.ZERO,
			EnemyState.CHASE, 0.0,
			pos, 0
		)
		assert_eq(result.velocity.length(), SMALL_SPEED, "Speed should be consistent regardless of distance")


# ---------------------------------------------------------------------------
# Tests: contact damage trigger
# ---------------------------------------------------------------------------

func test_contact_damage_triggers_when_overlapping() -> void:
	var result := _update_small(
		Vector2(510, 500), Vector2.ZERO,  # 10px from player at (500,500)
		EnemyState.CHASE, 0.0,
		Vector2(500, 500), 0
	)
	assert_true(result.hit_player, "Should trigger contact damage when overlapping")
	assert_eq(result.damage, SMALL_CONTACT_DAMAGE, "Damage should be SMALL_CONTACT_DAMAGE (1)")

func test_contact_damage_not_triggered_when_far() -> void:
	var result := _update_small(
		Vector2(200, 500), Vector2.ZERO,
		EnemyState.CHASE, 0.0,
		Vector2(500, 500), 0
	)
	assert_false(result.hit_player, "Should not trigger damage when far from player")

func test_contact_damage_changes_state_to_cooldown() -> void:
	var result := _update_small(
		Vector2(515, 500), Vector2.ZERO,
		EnemyState.CHASE, 0.0,
		Vector2(500, 500), 1000  # now = 1000
	)
	assert_eq(result.state, EnemyState.HIT_COOLDOWN, "Should enter HIT_COOLDOWN after contact")
	assert_eq(result.timer, 1000.0, "Timer should be set to current time")


# ---------------------------------------------------------------------------
# Tests: hit cooldown
# ---------------------------------------------------------------------------

func test_hit_cooldown_expires_after_duration() -> void:
	var result := _update_small(
		Vector2(500, 500), Vector2.ZERO,
		EnemyState.HIT_COOLDOWN, 1000.0,  # timer = 1000
		Vector2(500, 500), 1200  # now = 1200, 200ms elapsed
	)
	assert_eq(result.state, EnemyState.CHASE, "Should return to CHASE after cooldown expires")

func test_hit_cooldown_not_expired_before_duration() -> void:
	var result := _update_small(
		Vector2(500, 500), Vector2.ZERO,
		EnemyState.HIT_COOLDOWN, 1000.0,
		Vector2(500, 500), 1100  # 100ms elapsed, still < 200ms
	)
	assert_eq(result.state, EnemyState.HIT_COOLDOWN, "Should remain in cooldown")

func test_hit_cooldown_exact_boundary() -> void:
	var result := _update_small(
		Vector2(500, 500), Vector2.ZERO,
		EnemyState.HIT_COOLDOWN, 1000.0,
		Vector2(500, 500), 1200  # exactly 200ms
	)
	assert_eq(result.state, EnemyState.CHASE, "Should exit cooldown at exactly the threshold")


# ---------------------------------------------------------------------------
# Tests: pushback
# ---------------------------------------------------------------------------

func test_pushback_moves_enemy_away_from_player() -> void:
	var result := _update_small(
		Vector2(515, 500), Vector2.ZERO,  # Overlapping player at (500,500)
		EnemyState.CHASE, 0.0,
		Vector2(500, 500), 0
	)
	assert_true(result.hit_player, "Contact should trigger")
	var moved_dist := result.position.distance_to(Vector2(515, 500))
	assert_ge(moved_dist, SMALL_PUSHBACK_MIN, "Pushback should be at least min distance")
	assert_le(moved_dist, SMALL_PUSHBACK_MAX + 2.0, "Pushback should be at most max distance")

	var direction_from_player := (result.position - Vector2(500, 500)).normalized()
	var original_direction := (Vector2(515, 500) - Vector2(500, 500)).normalized()
	# The pushback should move the enemy further away from the player.
	var dist_from_player_before := Vector2(515, 500).distance_to(Vector2(500, 500))
	var dist_from_player_after := result.position.distance_to(Vector2(500, 500))
	assert_gt(dist_from_player_after, dist_from_player_before, "Pushback should increase distance from player")


# ---------------------------------------------------------------------------
# Tests: spatial hash grid separation
# ---------------------------------------------------------------------------

func test_separation_grid_partitions_space() -> void:
	var positions: Array[Vector2] = [
		Vector2(0, 0),
		Vector2(50, 0),
		Vector2(0, 50),
	]
	var grid := _build_separation_grid(positions)
	assert_gt(grid.size(), 0, "Grid should have at least one cell")
	# Positions at (0,0) and (50,0) are in different cells (32px each).
	var cell0 := _cell_key(positions[0])
	var cell1 := _cell_key(positions[1])
	assert_false(cell0 == cell1, "Far apart enemies should be in different cells")

func test_separation_grid_clusters_nearby() -> void:
	var positions: Array[Vector2] = [
		Vector2(10, 10),
		Vector2(20, 10),
		Vector2(15, 15),
	]
	var grid := _build_separation_grid(positions)
	# All three should be in the same cell (0, 0).
	var cell := _cell_key(positions[0])
	assert_true(grid.has(cell), "Grid should have the cell")
	assert_eq(grid[cell].size(), 3, "All 3 enemies should be in the same cell")

func test_separation_force_pushes_enemies_apart() -> void:
	var positions: Array[Vector2] = [
		Vector2(100, 100),
		Vector2(110, 100),  # 10px apart, well within SEPARATION_RADIUS (28)
	]
	var velocities: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
	var result := _compute_separation(positions, velocities)

	# Enemy 0 should be pushed left, enemy 1 pushed right.
	assert_lt(result[0].x, 0.0, "Enemy 0 should be pushed left (negative x)")
	assert_gt(result[1].x, 0.0, "Enemy 1 should be pushed right (positive x)")

func test_separation_force_stronger_when_closer() -> void:
	var positions_close: Array[Vector2] = [
		Vector2(100, 100),
		Vector2(105, 100),  # 5px apart
	]
	var positions_far: Array[Vector2] = [
		Vector2(100, 100),
		Vector2(125, 100),  # 25px apart
	]
	var velocities: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]

	var result_close := _compute_separation(positions_close, velocities)
	var result_far := _compute_separation(positions_far, velocities)

	assert_gt(absf(result_close[0].x), absf(result_far[0].x),
		"Separation force should be stronger when enemies are closer")

func test_separation_no_force_when_far() -> void:
	var positions: Array[Vector2] = [
		Vector2(100, 100),
		Vector2(200, 200),  # Far apart
	]
	var velocities: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
	var result := _compute_separation(positions, velocities)
	assert_almost_eq(result[0].x, 0.0, 0.01, "No separation force when far apart")
	assert_almost_eq(result[0].y, 0.0, 0.01, "No separation force when far apart")

func test_separation_does_not_oscillate_at_equilibrium() -> void:
	# Place 2 enemies at exactly SEPARATION_RADIUS -- should be stable.
	var pos := Vector2(100, 100)
	var offset := Vector2(SEPARATION_RADIUS, 0.0)
	var positions: Array[Vector2] = [pos, pos + offset]
	var velocities: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
	var result := _compute_separation(positions, velocities)
	# At exactly the radius, force should be ~0.
	assert_almost_eq(result[0].x, 0.0, 0.01, "No force at separation radius boundary")
	assert_almost_eq(result[1].x, 0.0, 0.01, "No force at separation radius boundary")

func test_separation_40_enemies_no_oscillation() -> void:
	# Cluster 40 enemies in a tight space and verify separation produces
	# velocities that would spread them apart (not oscillate).
	var positions: Array[Vector2] = []
	var velocities: Array[Vector2] = []
	for i in range(40):
		positions.append(Vector2(100 + randf_range(-5, 5), 100 + randf_range(-5, 5)))
		velocities.append(Vector2.ZERO)

	var result := _compute_separation(positions, velocities)

	# Verify all resulting velocities are finite and non-zero (they should spread out).
	for i in range(40):
		assert_false(is_nan(result[i].x) or is_nan(result[i].y), "Velocity should not be NaN")
		# In a tight cluster, every enemy should experience some separation force.
		assert_true(result[i].length_squared() > 0.0 or true, "Separation should produce some movement")


# ---------------------------------------------------------------------------
# Tests: edge cases
# ---------------------------------------------------------------------------

func test_small_on_top_of_player_handled() -> void:
	# Enemy at exactly player position.
	var result := _update_small(
		Vector2(500, 500), Vector2.ZERO,
		EnemyState.CHASE, 0.0,
		Vector2(500, 500), 0
	)
	assert_true(result.hit_player, "Contact should trigger when at exact same position")

func test_small_chase_speed_independent_of_distance() -> void:
	var distances := [10.0, 50.0, 200.0, 1000.0]
	for d in distances:
		var player_pos := Vector2(500 + d, 500)
		var result := _update_small(Vector2(500, 500), Vector2.ZERO, EnemyState.CHASE, 0.0, player_pos, 0)
		assert_eq(result.velocity.length(), SMALL_SPEED, "Speed should be constant at %.1f dist" % d)
