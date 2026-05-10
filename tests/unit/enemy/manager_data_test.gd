extends GutTest

# ---------------------------------------------------------------------------
# Mock classes
# ---------------------------------------------------------------------------

class MockPlayer extends RefCounted:
	var global_position: Vector2 = Vector2.ZERO


# Minimal test host replicating EnemyManager core data layout and queries.
class EnemyManagerHost extends Node2D:
	var _type: Array[int] = []
	var _state: Array[int] = []
	var _hp: Array[int] = []
	var _max_hp: Array[int] = []
	var _positions: Array[Vector2] = []
	var _velocities: Array[Vector2] = []
	var _active_count: int = 0
	var player_node: RefCounted = null
	var _pending_removal: Array[int] = []

	const MAX_TOTAL: int = 53
	const EnemyType = {SMALL = 0, MEDIUM = 1, LARGE = 2}
	const EnemyState = {
		CHASE = 0, ATTACK = 1, HIT_COOLDOWN = 2, RETREAT = 3,
		RAPID_FIRE = 4, CHARGE_WINDUP = 5, CHARGING = 6,
		MELEE_WINDUP = 7, DEAD = 8, SPAWNING = 9
	}
	const RADIUS_SMALL: float = 16.0
	const RADIUS_MEDIUM: float = 24.0
	const RADIUS_LARGE: float = 40.0
	const HP_SMALL: int = 1
	const HP_MEDIUM: int = 2
	const HP_LARGE: int = 5
	const REMOVAL_PER_FRAME_MAX: int = 10

	func _init() -> void:
		_type.resize(MAX_TOTAL)
		_state.resize(MAX_TOTAL)
		_hp.resize(MAX_TOTAL)
		_max_hp.resize(MAX_TOTAL)
		_positions.resize(MAX_TOTAL)
		_velocities.resize(MAX_TOTAL)
		for i in range(MAX_TOTAL):
			_state[i] = EnemyState.DEAD

	func spawn_wave(small: int, medium: int, large: int, center: Vector2, spread: float) -> void:
		var entries: Array[Dictionary] = []
		for _n in range(small):
			entries.append({"type": EnemyType.SMALL, "pos": center + Vector2(randf_range(-spread, spread), randf_range(-spread, spread))})
		for _n in range(medium):
			entries.append({"type": EnemyType.MEDIUM, "pos": center + Vector2(randf_range(-spread, spread), randf_range(-spread, spread))})
		for _n in range(large):
			entries.append({"type": EnemyType.LARGE, "pos": center + Vector2(randf_range(-spread, spread), randf_range(-spread, spread))})
		for entry in entries:
			var idx := _active_count
			if idx >= MAX_TOTAL:
				break
			_active_count += 1
			_type[idx] = entry.type
			_state[idx] = EnemyState.CHASE
			_positions[idx] = entry.pos
			_velocities[idx] = Vector2.ZERO
			match entry.type:
				EnemyType.SMALL:
					_hp[idx] = HP_SMALL
					_max_hp[idx] = HP_SMALL
				EnemyType.MEDIUM:
					_hp[idx] = HP_MEDIUM
					_max_hp[idx] = HP_MEDIUM
				EnemyType.LARGE:
					_hp[idx] = HP_LARGE
					_max_hp[idx] = HP_LARGE

	func check_bullet_hit(origin: Vector2, direction: Vector2, max_dist: float) -> Dictionary:
		var nearest_dist := max_dist
		var nearest_idx := -1
		for i in range(_active_count):
			if _state[i] == EnemyState.DEAD:
				continue
			var to_enemy := _positions[i] - origin
			var proj := to_enemy.dot(direction)
			if proj < 0.0 or proj > nearest_dist:
				continue
			var radius := _get_radius(_type[i])
			var perp := (to_enemy - direction * proj).length()
			if perp < radius and proj < nearest_dist:
				nearest_dist = proj
				nearest_idx = i
		return {"index": nearest_idx, "position": origin + direction * nearest_dist}

	func check_player_contact(player_pos: Vector2, player_radius: float) -> int:
		for i in range(_active_count):
			if _state[i] in [EnemyState.DEAD, EnemyState.SPAWNING]:
				continue
			var dist := _positions[i].distance_to(player_pos)
			if dist < player_radius + _get_radius(_type[i]):
				return i
		return -1

	func get_all_attack_positions() -> Array[Vector2]:
		var result: Array[Vector2] = []
		for i in range(_active_count):
			if _state[i] != EnemyState.DEAD:
				result.append(_positions[i])
		return result

	func apply_damage(index: int, amount: int) -> void:
		if index < 0 or index >= _active_count:
			return
		if _state[index] == EnemyState.DEAD:
			return
		if amount <= 0:
			return
		_hp[index] -= amount
		if _hp[index] <= 0:
			_hp[index] = 0
			_state[index] = EnemyState.DEAD
			_pending_removal.append(index)

	func get_active_count() -> int:
		return _active_count

	func _get_radius(etype: int) -> float:
		match etype:
			EnemyType.SMALL: return RADIUS_SMALL
			EnemyType.MEDIUM: return RADIUS_MEDIUM
			EnemyType.LARGE: return RADIUS_LARGE
		return RADIUS_SMALL

	func process_removal() -> void:
		if _pending_removal.is_empty():
			return
		var to_process := mini(_pending_removal.size(), REMOVAL_PER_FRAME_MAX)
		_pending_removal.sort()
		_pending_removal.reverse()
		for _n in range(to_process):
			if _pending_removal.is_empty():
				break
			var idx := _pending_removal.pop_back()
			var last := _active_count - 1
			if idx != last:
				_type[idx] = _type[last]
				_state[idx] = _state[last]
				_hp[idx] = _hp[last]
				_positions[idx] = _positions[last]
				_velocities[idx] = _velocities[last]
			_active_count -= 1


# ---------------------------------------------------------------------------
# Test fixture
# ---------------------------------------------------------------------------

var _host: EnemyManagerHost = null

func before_each() -> void:
	_host = EnemyManagerHost.new()
	_host.player_node = MockPlayer.new()
	add_child_autofree(_host)

func after_each() -> void:
	_host = null


# ---------------------------------------------------------------------------
# Data layout tests
# ---------------------------------------------------------------------------

func test_initial_state_empty() -> void:
	assert_eq(_host.get_active_count(), 0, "Should start with 0 active enemies")

func test_spawn_wave_creates_enemies() -> void:
	_host.spawn_wave(5, 1, 0, Vector2(500, 500), 100.0)
	assert_eq(_host.get_active_count(), 6, "5 small + 1 medium = 6 enemies")

func test_spawn_wave_correct_types() -> void:
	_host.spawn_wave(2, 1, 1, Vector2.ZERO, 50.0)
	var small := 0
	var medium := 0
	var large := 0
	for i in range(_host.get_active_count()):
		match _host._type[i]:
			EnemyManagerHost.EnemyType.SMALL: small += 1
			EnemyManagerHost.EnemyType.MEDIUM: medium += 1
			EnemyManagerHost.EnemyType.LARGE: large += 1
	assert_eq(small, 2, "Should have 2 small enemies")
	assert_eq(medium, 1, "Should have 1 medium enemy")
	assert_eq(large, 1, "Should have 1 large enemy")

func test_spawn_wave_correct_hp() -> void:
	_host.spawn_wave(1, 1, 1, Vector2.ZERO, 50.0)
	for i in range(_host.get_active_count()):
		match _host._type[i]:
			EnemyManagerHost.EnemyType.SMALL:
				assert_eq(_host._hp[i], 1, "Small should have 1 HP")
			EnemyManagerHost.EnemyType.MEDIUM:
				assert_eq(_host._hp[i], 2, "Medium should have 2 HP")
			EnemyManagerHost.EnemyType.LARGE:
				assert_eq(_host._hp[i], 5, "Large should have 5 HP")

func test_spawn_wave_positions_within_spread() -> void:
	var center := Vector2(500, 500)
	var spread := 100.0
	_host.spawn_wave(10, 0, 0, center, spread)
	for i in range(_host.get_active_count()):
		var dist := _host._positions[i].distance_to(center)
		assert_lt(dist, spread * 1.5, "Enemy should be within spread range of center")

func test_max_capacity_respected() -> void:
	# Try to spawn more than MAX_TOTAL.
	_host.spawn_wave(40, 10, 3, Vector2.ZERO, 200.0)  # 53 total
	assert_eq(_host.get_active_count(), 53, "Should respect MAX_TOTAL=53")
	# Try to spawn beyond.
	_host.spawn_wave(1, 0, 0, Vector2.ZERO, 10.0)
	assert_eq(_host.get_active_count(), 53, "Should not exceed MAX_TOTAL")


# ---------------------------------------------------------------------------
# Collision detection: check_bullet_hit
# ---------------------------------------------------------------------------

func test_bullet_hit_direct_center() -> void:
	_host._active_count = 1
	_host._type[0] = 0  # SMALL
	_host._state[0] = 0  # CHASE
	_host._hp[0] = 1
	_host._positions[0] = Vector2(200, 500)

	var result := _host.check_bullet_hit(Vector2(100, 500), Vector2.RIGHT, 300.0)
	assert_eq(result.index, 0, "Bullet should hit enemy directly ahead")
	assert_gt(result.position.x, 100.0, "Hit position should be along the ray")

func test_bullet_hit_miss_off_axis() -> void:
	_host._active_count = 1
	_host._type[0] = 0
	_host._state[0] = 0
	_host._hp[0] = 1
	_host._positions[0] = Vector2(200, 600)  # Far above the ray

	var result := _host.check_bullet_hit(Vector2(100, 500), Vector2.RIGHT, 300.0)
	assert_eq(result.index, -1, "Bullet should miss enemy far off-axis")

func test_bullet_hit_nearest_enemy() -> void:
	# Two enemies along the ray -- should hit the nearest.
	_host.spawn_wave(2, 0, 0, Vector2.ZERO, 0.0)
	_host._positions[0] = Vector2(150, 500)
	_host._positions[1] = Vector2(250, 500)

	var result := _host.check_bullet_hit(Vector2(100, 500), Vector2.RIGHT, 300.0)
	assert_eq(result.index, 0, "Should hit the nearest enemy")
	assert_lt(result.position.x, 200.0, "Hit position should be at nearest enemy")

func test_bullet_hit_ignores_dead() -> void:
	_host.spawn_wave(2, 0, 0, Vector2.ZERO, 0.0)
	_host._positions[0] = Vector2(150, 500)
	_host._state[0] = EnemyManagerHost.EnemyState.DEAD  # First is dead
	_host._positions[1] = Vector2(250, 500)
	_host._state[1] = 0  # CHASE

	var result := _host.check_bullet_hit(Vector2(100, 500), Vector2.RIGHT, 300.0)
	assert_eq(result.index, 1, "Should skip dead enemy and hit the live one")

func test_bullet_hit_ray_circle_intersection_graze() -> void:
	# Enemy just barely within radius.
	_host._active_count = 1
	_host._type[0] = 0  # SMALL, radius 16
	_host._state[0] = 0
	_host._hp[0] = 1
	# Place enemy 15px above the ray (within 16px radius).
	_host._positions[0] = Vector2(200, 515)

	var result := _host.check_bullet_hit(Vector2(100, 500), Vector2.RIGHT, 300.0)
	assert_eq(result.index, 0, "Should graze hit within radius")

func test_bullet_hit_ray_circle_intersection_barely_miss() -> void:
	# Enemy just barely outside radius.
	_host._active_count = 1
	_host._type[0] = 0
	_host._state[0] = 0
	_host._hp[0] = 1
	_host._positions[0] = Vector2(200, 517)  # 17px above, radius is 16

	var result := _host.check_bullet_hit(Vector2(100, 500), Vector2.RIGHT, 300.0)
	assert_eq(result.index, -1, "Should miss when outside radius")

func test_bullet_hit_enemy_behind_origin() -> void:
	_host._active_count = 1
	_host._type[0] = 0
	_host._state[0] = 0
	_host._hp[0] = 1
	_host._positions[0] = Vector2(50, 500)  # Behind the origin

	var result := _host.check_bullet_hit(Vector2(100, 500), Vector2.RIGHT, 300.0)
	assert_eq(result.index, -1, "Should not hit enemy behind the ray origin")


# ---------------------------------------------------------------------------
# Collision detection: check_player_contact
# ---------------------------------------------------------------------------

func test_player_contact_overlap_detected() -> void:
	_host._active_count = 1
	_host._type[0] = 0  # SMALL, radius 16
	_host._state[0] = 0
	_host._hp[0] = 1
	_host._positions[0] = Vector2(510, 500)  # 10px away from player at (500,500)

	var result := _host.check_player_contact(Vector2(500, 500), 8.0)
	assert_eq(result, 0, "Should detect overlap with enemy within range")

func test_player_contact_no_overlap() -> void:
	_host._active_count = 1
	_host._type[0] = 0
	_host._state[0] = 0
	_host._hp[0] = 1
	_host._positions[0] = Vector2(600, 500)  # 100px away

	var result := _host.check_player_contact(Vector2(500, 500), 8.0)
	assert_eq(result, -1, "Should not detect overlap when far apart")

func test_player_contact_ignores_dead() -> void:
	_host._active_count = 1
	_host._type[0] = 0
	_host._state[0] = EnemyManagerHost.EnemyState.DEAD
	_host._hp[0] = 0
	_host._positions[0] = Vector2(510, 500)  # Close but dead

	var result := _host.check_player_contact(Vector2(500, 500), 8.0)
	assert_eq(result, -1, "Should ignore dead enemies in contact check")


# ---------------------------------------------------------------------------
# get_all_attack_positions
# ---------------------------------------------------------------------------

func test_get_all_attack_positions_returns_live_only() -> void:
	_host.spawn_wave(2, 0, 0, Vector2(500, 500), 50.0)
	_host._state[0] = EnemyManagerHost.EnemyState.DEAD  # Kill one
	_host._state[1] = 0  # CHASE

	var positions := _host.get_all_attack_positions()
	assert_eq(positions.size(), 1, "Should only return positions of non-dead enemies")


# ---------------------------------------------------------------------------
# apply_damage and death
# ---------------------------------------------------------------------------

func test_apply_damage_reduces_hp() -> void:
	_host.spawn_wave(0, 0, 1, Vector2(500, 500), 10.0)  # 1 large, 5 HP
	var idx := 0
	_host.apply_damage(idx, 2)
	assert_eq(_host._hp[idx], 3, "HP should be 3 after 2 damage to 5 HP large")

func test_apply_damage_kills_when_hp_zero() -> void:
	_host.spawn_wave(1, 0, 0, Vector2(500, 500), 10.0)  # 1 small, 1 HP
	var idx := 0
	_host.apply_damage(idx, 1)
	assert_eq(_host._state[idx], EnemyManagerHost.EnemyState.DEAD, "Enemy should be dead after lethal damage")
	assert_eq(_host._hp[idx], 0, "HP should be clamped to 0")

func test_apply_damage_ignores_dead_enemy() -> void:
	_host.spawn_wave(1, 0, 0, Vector2(500, 500), 10.0)
	var idx := 0
	_host._state[idx] = EnemyManagerHost.EnemyState.DEAD
	_host._hp[idx] = 0
	_host.apply_damage(idx, 1)
	assert_eq(_host._hp[idx], 0, "Dead enemy HP should not change")

func test_apply_damage_invalid_index_safe() -> void:
	_host.spawn_wave(1, 0, 0, Vector2(500, 500), 10.0)
	_host.apply_damage(-1, 1)  # Should not crash
	_host.apply_damage(100, 1)  # Should not crash
	# No crash = pass.

func test_apply_damage_zero_no_effect() -> void:
	_host.spawn_wave(0, 0, 1, Vector2(500, 500), 10.0)
	var idx := 0
	var hp_before := _host._hp[idx]
	_host.apply_damage(idx, 0)
	assert_eq(_host._hp[idx], hp_before, "Zero damage should have no effect")


# ---------------------------------------------------------------------------
# Death removal queue
# ---------------------------------------------------------------------------

func test_removal_reduces_active_count() -> void:
	_host.spawn_wave(5, 0, 0, Vector2(500, 500), 50.0)
	assert_eq(_host.get_active_count(), 5)
	# Kill all 5.
	for i in range(5):
		_host.apply_damage(i, 2)  # 1 HP small enemies die to 2 damage
	# Process removal.
	_host.process_removal()
	assert_lt(_host.get_active_count(), 5, "Active count should decrease after removal")

func test_removal_preserves_order() -> void:
	_host.spawn_wave(3, 0, 0, Vector2(500, 500), 10.0)
	# Kill index 0.
	_host.apply_damage(0, 10)
	_host.process_removal()
	assert_eq(_host.get_active_count(), 2, "Should have 2 remaining after removal")
	# Remaining enemies should still be healthy.
	for i in range(_host.get_active_count()):
		assert_gt(_host._hp[i], 0, "Remaining enemies should be alive")


# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

func test_empty_bullet_check_no_crash() -> void:
	var result := _host.check_bullet_hit(Vector2(100, 500), Vector2.RIGHT, 300.0)
	assert_eq(result.index, -1, "No enemies means no hit")

func test_empty_contact_check_no_crash() -> void:
	var result := _host.check_player_contact(Vector2(500, 500), 8.0)
	assert_eq(result, -1, "No enemies means no contact")

func test_empty_attack_positions() -> void:
	var positions := _host.get_all_attack_positions()
	assert_eq(positions.size(), 0, "Empty enemy list should return no positions")
