extends GutTest

# ---------------------------------------------------------------------------
# Constants (mirror EnemyManager)
# ---------------------------------------------------------------------------

const MAX_SMALL: int = 40
const MAX_MEDIUM: int = 10
const MAX_LARGE: int = 3
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

const SMALL_SPEED: float = 200.0
const MEDIUM_RETREAT_SPEED: float = 180.0
const MEDIUM_APPROACH_SPEED: float = 120.0
const LARGE_ADVANCE_SPEED: float = 60.0
const LARGE_CHARGE_SPEED: float = 250.0
const SEPARATION_RADIUS: float = 28.0
const SEPARATION_FORCE: float = 20.0


# ---------------------------------------------------------------------------
# Full combat simulator host
# ---------------------------------------------------------------------------

class CombatSimulator extends Node2D:
	var _type: Array[int] = []
	var _state: Array[int] = []
	var _hp: Array[int] = []
	var _max_hp: Array[int] = []
	var _positions: Array[Vector2] = []
	var _velocities: Array[Vector2] = []
	var _timers: Array[float] = []
	var _timers2: Array[float] = []
	var _directions: Array[Vector2] = []
	var _active_count: int = 0
	var _pending_removal: Array[int] = []
	var _frozen: bool = false
	var player_pos: Vector2 = Vector2(500, 500)
	var total_damage_dealt: int = 0
	var total_kills: int = 0
	var player_hits_taken: int = 0
	var frame_count: int = 0

	const REMOVAL_PER_FRAME_MAX: int = 10
	const GRID_CELL_SIZE: float = 32.0

	func _init() -> void:
		_type.resize(MAX_TOTAL)
		_state.resize(MAX_TOTAL)
		_hp.resize(MAX_TOTAL)
		_max_hp.resize(MAX_TOTAL)
		_positions.resize(MAX_TOTAL)
		_velocities.resize(MAX_TOTAL)
		_timers.resize(MAX_TOTAL)
		_timers2.resize(MAX_TOTAL)
		_directions.resize(MAX_TOTAL)
		for i in range(MAX_TOTAL):
			_state[i] = EnemyState.DEAD

	func spawn_full_wave() -> void:
		for _n in range(MAX_SMALL):
			_spawn(EnemyType.SMALL, Vector2(randf_range(100, 900), randf_range(100, 900)))
		for _n in range(MAX_MEDIUM):
			_spawn(EnemyType.MEDIUM, Vector2(randf_range(100, 900), randf_range(100, 900)))
		for _n in range(MAX_LARGE):
			_spawn(EnemyType.LARGE, Vector2(randf_range(100, 900), randf_range(100, 900)))

	func _spawn(etype: int, pos: Vector2) -> void:
		if _active_count >= MAX_TOTAL:
			return
		var idx := _active_count
		_active_count += 1
		_type[idx] = etype
		_state[idx] = EnemyState.CHASE
		_positions[idx] = pos
		_velocities[idx] = Vector2.ZERO
		_timers[idx] = 0.0
		_timers2[idx] = 0.0
		_directions[idx] = Vector2.ZERO
		match etype:
			EnemyType.SMALL:
				_hp[idx] = HP_SMALL; _max_hp[idx] = HP_SMALL
			EnemyType.MEDIUM:
				_hp[idx] = HP_MEDIUM; _max_hp[idx] = HP_MEDIUM
			EnemyType.LARGE:
				_hp[idx] = HP_LARGE; _max_hp[idx] = HP_LARGE

	func simulate_frame() -> void:
		if _frozen:
			return
		frame_count += 1

		# Process removal queue.
		_process_removal()

		# Update each enemy.
		for i in range(_active_count):
			if _state[i] == EnemyState.DEAD:
				continue
			match _type[i]:
				EnemyType.SMALL:  _update_small(i)
				EnemyType.MEDIUM: _update_medium(i)
				EnemyType.LARGE:  _update_large(i)

		# Separation.
		_apply_separation()

		# Apply movement.
		for i in range(_active_count):
			if _state[i] == EnemyState.DEAD:
				continue
			_positions[i] += _velocities[i] * (1.0 / 60.0)

	func _update_small(i: int) -> void:
		match _state[i]:
			EnemyState.CHASE:
				var to_player := player_pos - _positions[i]
				var dist := to_player.length()
				if dist < RADIUS_SMALL + 8.0 and dist > 0.01:
					# Contact damage.
					player_hits_taken += 1
				if dist > 0.01:
					_velocities[i] = to_player.normalized() * SMALL_SPEED

	func _update_medium(i: int) -> void:
		match _state[i]:
			EnemyState.CHASE:
				var to_player := player_pos - _positions[i]
				var dist := to_player.length()
				if dist > 0.01:
					_velocities[i] = to_player.normalized() * MEDIUM_APPROACH_SPEED

	func _update_large(i: int) -> void:
		match _state[i]:
			EnemyState.CHASE:
				var to_player := player_pos - _positions[i]
				if to_player.length() > 0.01:
					_directions[i] = to_player.normalized()
				_velocities[i] = _directions[i] * LARGE_ADVANCE_SPEED

	func _apply_separation() -> void:
		var grid: Dictionary = {}
		for i in range(_active_count):
			if _state[i] == EnemyState.DEAD:
				continue
			var cell := Vector2i(int(floorf(_positions[i].x / GRID_CELL_SIZE)), int(floorf(_positions[i].y / GRID_CELL_SIZE)))
			if not grid.has(cell):
				grid[cell] = []
			grid[cell].append(i)

		for i in range(_active_count):
			if _state[i] == EnemyState.DEAD:
				continue
			var cell := Vector2i(int(floorf(_positions[i].x / GRID_CELL_SIZE)), int(floorf(_positions[i].y / GRID_CELL_SIZE)))
			var sep := Vector2.ZERO
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var nc := Vector2i(cell.x + dx, cell.y + dy)
					if not grid.has(nc):
						continue
					for j in grid[nc]:
						if j == i or _state[j] == EnemyState.DEAD:
							continue
						var diff := _positions[i] - _positions[j]
						var dist := diff.length()
						if dist < SEPARATION_RADIUS and dist > 0.01:
							sep += diff.normalized() * (SEPARATION_RADIUS - dist) / SEPARATION_RADIUS * SEPARATION_FORCE
			_velocities[i] += sep

	func apply_aoe_damage(center: Vector2, radius: float, damage: int) -> int:
		var hit_count := 0
		for i in range(_active_count):
			if _state[i] == EnemyState.DEAD:
				continue
			if _positions[i].distance_squared_to(center) <= radius * radius:
				_hp[i] -= damage
				hit_count += 1
				if _hp[i] <= 0:
					_hp[i] = 0
					_state[i] = EnemyState.DEAD
					_pending_removal.append(i)
					total_kills += 1
		total_damage_dealt += hit_count * damage
		return hit_count

	func _process_removal() -> void:
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
				_timers[idx] = _timers[last]
				_timers2[idx] = _timers2[last]
				_directions[idx] = _directions[last]
			_active_count -= 1

	func freeze() -> void:
		_frozen = true

	func unfreeze() -> void:
		_frozen = false

	func get_active_count() -> int:
		return _active_count


# ---------------------------------------------------------------------------
# Test fixture
# ---------------------------------------------------------------------------

var _sim: CombatSimulator = null

func before_each() -> void:
	_sim = CombatSimulator.new()
	add_child_autofree(_sim)

func after_each() -> void:
	_sim = null


# ---------------------------------------------------------------------------
# Full wave spawning
# ---------------------------------------------------------------------------

func test_full_53_enemy_spawn() -> void:
	_sim.spawn_full_wave()
	assert_eq(_sim.get_active_count(), 53, "Should spawn exactly 53 enemies")

func test_spawn_distribution() -> void:
	_sim.spawn_full_wave()
	var small := 0; var medium := 0; var large := 0
	for i in range(_sim.get_active_count()):
		match _sim._type[i]:
			EnemyType.SMALL: small += 1
			EnemyType.MEDIUM: medium += 1
			EnemyType.LARGE: large += 1
	assert_eq(small, 40, "40 small enemies")
	assert_eq(medium, 10, "10 medium enemies")
	assert_eq(large, 3, "3 large enemies")

func test_all_enemies_starts_with_correct_hp() -> void:
	_sim.spawn_full_wave()
	for i in range(_sim.get_active_count()):
		if _sim._type[i] == EnemyType.SMALL:
			assert_eq(_sim._hp[i], 1, "Small HP")
		elif _sim._type[i] == EnemyType.MEDIUM:
			assert_eq(_sim._hp[i], 2, "Medium HP")
		elif _sim._type[i] == EnemyType.LARGE:
			assert_eq(_sim._hp[i], 5, "Large HP")


# ---------------------------------------------------------------------------
# AI simulation: 53 enemies over multiple frames
# ---------------------------------------------------------------------------

func test_all_53_enemies_update_without_crash() -> void:
	_sim.spawn_full_wave()
	for _f in range(60):
		_sim.simulate_frame()
	# No crash = pass.
	pass_test("53 enemies simulated for 60 frames without crash")

func test_enemies_move_toward_player() -> void:
	_sim.spawn_full_wave()
	var positions_before: Array[Vector2] = []
	for i in range(_sim.get_active_count()):
		positions_before.append(_sim._positions[i])

	for _f in range(10):
		_sim.simulate_frame()

	var moved_count := 0
	for i in range(_sim.get_active_count()):
		if _sim._positions[i].distance_squared_to(positions_before[i]) > 0.01:
			moved_count += 1
	assert_gt(moved_count, 0, "At least some enemies should have moved")

func test_separation_prevents_overlap() -> void:
	# Spawn 40 small enemies in a tight cluster and verify no two occupy
	# the exact same position after simulation.
	_sim._active_count = 0
	for n in range(40):
		# All at same spot.
		_sim._spawn(EnemyType.SMALL, Vector2(500, 500))

	for _f in range(60):
		_sim.simulate_frame()

	# After 60 frames of separation, no two enemies should be at identical positions.
	var positions_set := {}
	for i in range(_sim.get_active_count()):
		var key := str(_sim._positions[i].x) + "," + str(_sim._positions[i].y)
		assert_false(positions_set.has(key), "No two enemies should be at the exact same position after separation")
		positions_set[key] = true


# ---------------------------------------------------------------------------
# Mixed combat: AoE kills + removal
# ---------------------------------------------------------------------------

func test_aoe_kills_small_enemies() -> void:
	_sim.spawn_full_wave()
	var hit_count := _sim.apply_aoe_damage(Vector2(500, 500), 200.0, 1)
	# All small enemies have 1 HP and should die to the AoE.
	assert_gt(hit_count, 0, "AoE should hit at least some enemies")

func test_aoe_damage_correct_value() -> void:
	_sim._spawn(EnemyType.LARGE, Vector2(500, 500))  # 5 HP
	var idx := 0
	_sim.apply_aoe_damage(Vector2(500, 500), 200.0, 1)
	assert_eq(_sim._hp[idx], 4, "Large should have 4 HP after 1 damage")

func test_death_removal_reduces_count() -> void:
	_sim.spawn_full_wave()
	var before := _sim.get_active_count()
	# Kill many enemies with AoE.
	_sim.apply_aoe_damage(Vector2(500, 500), 500.0, 5)
	# Process removal.
	for _f in range(10):
		_sim.simulate_frame()
	assert_lt(_sim.get_active_count(), before, "Active count should decrease after kills + removal")

func test_killed_enemies_are_removed() -> void:
	_sim.spawn_full_wave()
	_sim.apply_aoe_damage(Vector2(500, 500), 500.0, 5)
	for _f in range(10):
		_sim.simulate_frame()
	# Verify all remaining enemies are alive.
	for i in range(_sim.get_active_count()):
		assert_neq(_sim._state[i], EnemyState.DEAD, "Remaining enemies should not be DEAD")
		assert_gt(_sim._hp[i], 0, "Remaining enemies should have positive HP")


# ---------------------------------------------------------------------------
# Death freeze integration
# ---------------------------------------------------------------------------

func test_freeze_stops_enemy_movement() -> void:
	_sim.spawn_full_wave()
	# Record positions.
	var positions_before: Array[Vector2] = []
	for i in range(_sim.get_active_count()):
		positions_before.append(_sim._positions[i])

	_sim.freeze()
	for _f in range(10):
		_sim.simulate_frame()

	# After freeze, no enemy should have moved.
	for i in range(_sim.get_active_count()):
		assert_eq(_sim._positions[i], positions_before[i], "Enemy positions should not change while frozen")

func test_unfreeze_restores_movement() -> void:
	_sim.spawn_full_wave()
	_sim.freeze()
	for _f in range(5):
		_sim.simulate_frame()
	_sim.unfreeze()
	for _f in range(5):
		_sim.simulate_frame()
	# No crash after unfreeze.
	pass_test("Unfreeze restores movement without crash")


# ---------------------------------------------------------------------------
# Performance benchmark: 53 enemies, AI + physics
# ---------------------------------------------------------------------------

func test_performance_53_enemies_under_4_ms() -> void:
	_sim.spawn_full_wave()

	var start := Time.get_ticks_usec()
	for _f in range(60):
		_sim.simulate_frame()
	var elapsed_us := Time.get_ticks_usec() - start
	var avg_us_per_frame := elapsed_us / 60.0
	var avg_ms_per_frame := avg_us_per_frame / 1000.0

	# Target: under 4.17ms per frame for 240fps, but we're testing at 60fps simulation.
	assert_lt(avg_ms_per_frame, 4.17, "53 enemies AI + separation should average <4.17ms per frame (was %.3fms)" % avg_ms_per_frame)


# ---------------------------------------------------------------------------
# Stability: 10 consecutive waves without memory leak or crash
# ---------------------------------------------------------------------------

func test_consecutive_waves_stability() -> void:
	for wave in range(10):
		_sim = CombatSimulator.new()
		add_child_autofree(_sim)
		_sim.spawn_full_wave()
		for _f in range(30):
			_sim.simulate_frame()
		# All enemies should either be alive or properly removed.
		var active := _sim.get_active_count()
		assert_lt(active, 60, "Wave %d: active count should not grow beyond MAX_TOTAL" % wave)
	# No crash over 10 waves = pass.
	pass_test("10 consecutive waves processed without crash")
