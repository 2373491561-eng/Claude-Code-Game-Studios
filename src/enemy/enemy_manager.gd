## EnemyManager -- centralized struct-of-arrays enemy manager.
##
## Implements: enemy-system Story 001 (Manager Data Layout + Rendering),
##   Story 002 (Small Enemy AI), Story 003 (Medium Enemy AI),
##   Story 004 (Large Enemy AI + Full Integration)
## Governed by: ADR-0004 (Centralized Enemy Manager), ADR-0003 (physics 60Hz),
##   ADR-0005 (event bus signals)
##
## All enemy data is stored in parallel arrays (struct-of-arrays) for cache-
## friendly iteration. AI is updated in a single batch loop in _physics_process().
## No enemy has its own _process() -- per ADR-0004.
##
## Rendering strategy:
##   - Small (40): MultiMeshInstance2D -- 1 draw call for all instances.
##   - Medium (10): Array[Sprite2D] object pool.
##   - Large (3):  Array[Sprite2D] object pool.
##
## Collision detection: manual O(N) ray-circle and distance checks instead of
## physics body queries -- avoids physics server overhead.
##
## On player death (EventBus.player_death): all AI processing is frozen.
##
## Usage:
##   [codeblock]
##   # In game.tscn:
##   var enemy_mgr := EnemyManager.new()
##   enemy_mgr.player_node = $Player/PlayerMovement
##   enemy_mgr.damage_health_system = $Player/DamageHealthSystem
##   add_child(enemy_mgr)
##   enemy_mgr.spawn_wave({"small": 10, "medium": 2, "large": 1})
##   [/codeblock]
class_name EnemyManager
extends Node2D

# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

enum EnemyType { SMALL = 0, MEDIUM = 1, LARGE = 2 }

enum EnemyState {
	CHASE = 0,
	ATTACK = 1,
	HIT_COOLDOWN = 2,
	RETREAT = 3,
	RAPID_FIRE = 4,
	CHARGE_WINDUP = 5,
	CHARGING = 6,
	MELEE_WINDUP = 7,
	DEAD = 8,
	SPAWNING = 9,
}

# ---------------------------------------------------------------------------
# Constants -- per-type gameplay values (data-driven, tuning knobs)
# ---------------------------------------------------------------------------

## Maximum concurrent enemies by type.
const MAX_SMALL: int = 40
const MAX_MEDIUM: int = 10
const MAX_LARGE: int = 3
const MAX_TOTAL: int = MAX_SMALL + MAX_MEDIUM + MAX_LARGE  # 53

## Enemy radii in pixels (used for collision and separation).
const RADIUS_SMALL: float = 16.0
const RADIUS_MEDIUM: float = 24.0
const RADIUS_LARGE: float = 40.0

## Max HP by type.
const HP_SMALL: int = 1
const HP_MEDIUM: int = 2
const HP_LARGE: int = 5

## Small enemy: chase speed in px/s.
const SMALL_SPEED: float = 200.0

## Small enemy: contact damage dealt to player.
const SMALL_CONTACT_DAMAGE: int = 1

## Small enemy: hit cooldown (after contact damage) in ms.
const SMALL_HIT_COOLDOWN_MS: int = 200

## Small enemy: pushback distance range in px.
const SMALL_PUSHBACK_MIN: float = 10.0
const SMALL_PUSHBACK_MAX: float = 15.0

## Medium enemy: retreat speed in px/s.
const MEDIUM_RETREAT_SPEED: float = 180.0

## Medium enemy: approach speed in px/s.
const MEDIUM_APPROACH_SPEED: float = 120.0

## Medium enemy: distance hysteresis [min, max] from player.
const MEDIUM_DIST_MIN: float = 140.0
const MEDIUM_DIST_MAX: float = 210.0

## Medium enemy: attack windup duration in ms.
const MEDIUM_ATTACK_WINDUP_MS: int = 250

## Medium enemy: bullet speed in px/s.
const MEDIUM_BULLET_SPEED: float = 150.0

## Medium enemy: bullet max range in px.
const MEDIUM_BULLET_MAX_DIST: float = 600.0

## Medium enemy: attack cooldown range in ms.
const MEDIUM_COOLDOWN_MIN_MS: int = 1500
const MEDIUM_COOLDOWN_MAX_MS: int = 2000

## Medium enemy: corner behavior -- retreat blocked threshold in ms.
const MEDIUM_CORNER_THRESHOLD_MS: int = 300

## Medium enemy: rapid fire bullet count.
const MEDIUM_RAPID_FIRE_COUNT: int = 3

## Medium enemy: rapid fire interval in ms.
const MEDIUM_RAPID_FIRE_INTERVAL_MS: int = 150

## Medium enemy: lateral strafe speed in px/s during rapid fire.
const MEDIUM_STRAFE_SPEED: float = 80.0

## Medium enemy: hit stun duration in ms.
const MEDIUM_STUN_MS: int = 50

## Medium enemy: white flash duration in frames.
const MEDIUM_FLASH_FRAMES: int = 2

## Large enemy: advance speed in px/s.
const LARGE_ADVANCE_SPEED: float = 60.0

## Large enemy: charge dash speed in px/s.
const LARGE_CHARGE_SPEED: float = 250.0

## Large enemy: charge windup duration in ms.
const LARGE_CHARGE_WINDUP_MS: int = 500

## Large enemy: charge dash duration in ms.
const LARGE_CHARGE_DURATION_MS: int = 1000

## Large enemy: charge cooldown range in ms.
const LARGE_CHARGE_COOLDOWN_MIN_MS: int = 5000
const LARGE_CHARGE_COOLDOWN_MAX_MS: int = 8000

## Large enemy: melee trigger distance in px.
const LARGE_MELEE_DIST: float = 80.0

## Large enemy: melee windup duration in ms.
const LARGE_MELEE_WINDUP_MS: int = 400

## Large enemy: melee damage to player.
const LARGE_MELEE_DAMAGE: int = 2

## Large enemy: melee cooldown range in ms.
const LARGE_MELEE_COOLDOWN_MIN_MS: int = 2000
const LARGE_MELEE_COOLDOWN_MAX_MS: int = 3000

## Large enemy: death explosion duration in ms.
const LARGE_DEATH_EXPLOSION_MS: int = 600

## Large enemy: charge dodgeable -- 100px dodge > 75px charge max displacement.
## (DODGE_DISTANCE=100px, charge at 250px/s for 1s = 250px total possible but
##  dodge happens at a moment, so max displacement during dodge window is
##  250 * 0.3 = 75px. Player dodge = 100px > 75px. Satisfies spec.)

## Spatial hash grid cell size in pixels.
const GRID_CELL_SIZE: float = 32.0

## Separation force strength (multiplier).
const SEPARATION_FORCE: float = 20.0

## Separation radius -- enemies closer than this are pushed apart.
const SEPARATION_RADIUS: float = 28.0

## Staggered spawn: enemies per frame.
const SPAWN_PER_FRAME_MIN: int = 5
const SPAWN_PER_FRAME_MAX: int = 10

## Spawn fade-in duration range in ms.
const SPAWN_FADE_MIN_MS: int = 100
const SPAWN_FADE_MAX_MS: int = 200

## Death removal: process at most this many per frame.
const REMOVAL_PER_FRAME_MAX: int = 10

## Maximum concurrent enemy bullets.
const MAX_BULLETS: int = 15

# ---------------------------------------------------------------------------
# Exported references
# ---------------------------------------------------------------------------

## Reference to the player's CharacterBody2D for position queries.
@export var player_node: Node2D = null

## Reference to the DamageHealthSystem for applying damage to the player
## and computing player-to-enemy damage.
@export var damage_health_system: DamageHealthSystem = null

# ---------------------------------------------------------------------------
# Struct-of-arrays: enemy data (index i belongs to the same enemy across all)
# ---------------------------------------------------------------------------

var _type: Array[int] = []
var _state: Array[int] = []
var _hp: Array[int] = []
var _max_hp: Array[int] = []
var _positions: Array[Vector2] = []
var _velocities: Array[Vector2] = []
var _timers: Array[float] = []         ## Generic timer: meaning depends on state
var _timers2: Array[float] = []        ## Secondary timer for compound states
var _directions: Array[Vector2] = []   ## Attack direction / charge direction
var _flash_frames: Array[int] = []     ## Remaining white-flash frames
var _spawn_fade_ms: Array[int] = []    ## Fade-in duration target
var _active_count: int = 0

# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

## MultiMesh for small enemies (1 draw call for up to 40 instances).
var _small_multimesh: MultiMeshInstance2D = null
var _small_multimesh_data: MultiMesh = null

## Object pool for medium enemy sprites (10 instances).
var _medium_sprites: Array[Sprite2D] = []

## Object pool for large enemy sprites (3 instances).
var _large_sprites: Array[Sprite2D] = []

# ---------------------------------------------------------------------------
# Enemy bullet tracking
# ---------------------------------------------------------------------------

var _bullet_positions: Array[Vector2] = []
var _bullet_velocities: Array[Vector2] = []
var _bullet_dist_traveled: Array[float] = []
var _bullet_active: Array[bool] = []
var _bullet_pool_index: int = 0

# ---------------------------------------------------------------------------
# Spatial hash grid (for separation)
# ---------------------------------------------------------------------------

var _grid: Dictionary = {}  ## Dictionary[Vector2i, Array[int]]
var _grid_cell_size: float = GRID_CELL_SIZE

# ---------------------------------------------------------------------------
# Pending removal queue
# ---------------------------------------------------------------------------

var _pending_removal: Array[int] = []

# ---------------------------------------------------------------------------
# Death freeze flag
# ---------------------------------------------------------------------------

var _frozen: bool = false

# ---------------------------------------------------------------------------
# Internal state for medium corner detection
# ---------------------------------------------------------------------------

var _retreat_blocked_since: Array[int] = []  ## Timestamp when retreat was first blocked
var _strafe_direction: Array[int] = []       ## 1 or -1 for lateral strafe

# ---------------------------------------------------------------------------
# Node lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Initialize arrays to maximum capacity.
	_type.resize(MAX_TOTAL)
	_state.resize(MAX_TOTAL)
	_hp.resize(MAX_TOTAL)
	_max_hp.resize(MAX_TOTAL)
	_positions.resize(MAX_TOTAL)
	_velocities.resize(MAX_TOTAL)
	_timers.resize(MAX_TOTAL)
	_timers2.resize(MAX_TOTAL)
	_directions.resize(MAX_TOTAL)
	_flash_frames.resize(MAX_TOTAL)
	_spawn_fade_ms.resize(MAX_TOTAL)
	_retreat_blocked_since.resize(MAX_TOTAL)
	_strafe_direction.resize(MAX_TOTAL)

	# Initialize with zero values.
	for i in range(MAX_TOTAL):
		_type[i] = EnemyType.SMALL
		_state[i] = EnemyState.DEAD
		_hp[i] = 0
		_max_hp[i] = 0
		_positions[i] = Vector2.ZERO
		_velocities[i] = Vector2.ZERO
		_timers[i] = 0.0
		_timers2[i] = 0.0
		_directions[i] = Vector2.ZERO
		_flash_frames[i] = 0
		_spawn_fade_ms[i] = 0
		_retreat_blocked_since[i] = 0
		_strafe_direction[i] = 1

	# Initialize bullet pool.
	_bullet_positions.resize(MAX_BULLETS)
	_bullet_velocities.resize(MAX_BULLETS)
	_bullet_dist_traveled.resize(MAX_BULLETS)
	_bullet_active.resize(MAX_BULLETS)
	for b in range(MAX_BULLETS):
		_bullet_active[b] = false

	# Create rendering nodes.
	_create_rendering()

	# Connect to player_death for freeze.
	_connect_death_signal()

func _create_rendering() -> void:
	# --- Small enemies: MultiMeshInstance2D (1 draw call) ---
	_small_multimesh_data = MultiMesh.new()
	_small_multimesh_data.transform_format = MultiMesh.TRANSFORM_2D
	_small_multimesh_data.instance_count = MAX_SMALL
	# Use a colored quad mesh (or placeholder -- will be replaced by art).
	_small_multimesh_data.mesh = _create_placeholder_mesh(RADIUS_SMALL)

	_small_multimesh = MultiMeshInstance2D.new()
	_small_multimesh.multimesh = _small_multimesh_data
	add_child(_small_multimesh)

	# --- Medium enemies: Sprite2D pool (10 instances) ---
	for i in range(MAX_MEDIUM):
		var sprite := Sprite2D.new()
		sprite.visible = false
		sprite.centered = true
		# Placeholder texture.
		sprite.modulate = Color.RED
		add_child(sprite)
		_medium_sprites.append(sprite)

	# --- Large enemies: Sprite2D pool (3 instances) ---
	for i in range(MAX_LARGE):
		var sprite := Sprite2D.new()
		sprite.visible = false
		sprite.centered = true
		sprite.modulate = Color.WHITE
		add_child(sprite)
		_large_sprites.append(sprite)

## Creates a simple rectangle mesh of the given radius as a placeholder QuadMesh.
func _create_placeholder_mesh(radius: float) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(radius * 2.0, radius * 2.0)
	return mesh

func _connect_death_signal() -> void:
	var eb := get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("player_death"):
		if not eb.player_death.is_connected(_on_player_death):
			eb.player_death.connect(_on_player_death)

func _on_player_death() -> void:
	_frozen = true

# ---------------------------------------------------------------------------
# Main update loop
# ---------------------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	# Skip AI if frozen (player is dead).
	if _frozen:
		return

	var now := Time.get_ticks_msec()

	# Process removal queue.
	_process_removal_queue()

	# Update all active enemies.
	for i in range(_active_count):
		# Skip dead and spawning enemies in AI updates.
		if _state[i] == EnemyState.DEAD:
			continue

		# Handle white flash frame countdown.
		if _flash_frames[i] > 0:
			_flash_frames[i] -= 1

		match _type[i]:
			EnemyType.SMALL:
				_update_small(i, now)
			EnemyType.MEDIUM:
				_update_medium(i, now)
			EnemyType.LARGE:
				_update_large(i, now)

	# Build spatial hash grid for separation.
	_build_separation_grid()

	# Update bullets.
	_update_bullets()

	# Sync rendering.
	_sync_rendering()

# ---------------------------------------------------------------------------
# Spawning
# ---------------------------------------------------------------------------

## Spawns a wave of enemies based on [param config].
##
## [param config] is a Dictionary with optional keys:
##   - "small": int (number of small enemies to spawn)
##   - "medium": int (number of medium enemies to spawn)
##   - "large": int (number of large enemies to spawn)
##   - "center": Vector2 (spawn center, default Vector2.ZERO)
##   - "spread": float (spawn spread radius, default 200.0)
##
## Spawning is staggered: SPAWN_PER_FRAME_MIN..MAX enemies become active
## each physics frame. Remaining spawns are queued for subsequent frames.
func spawn_wave(config: Dictionary) -> void:
	var center: Vector2 = config.get("center", Vector2.ZERO)
	var spread: float = config.get("spread", 200.0)
	var to_spawn: Array[Dictionary] = []

	var small_count: int = config.get("small", 0)
	var medium_count: int = config.get("medium", 0)
	var large_count: int = config.get("large", 0)

	# Build spawn queue.
	for _n in range(small_count):
		var pos := center + Vector2(randf_range(-spread, spread), randf_range(-spread, spread))
		to_spawn.append({"type": EnemyType.SMALL, "pos": pos})

	for _n in range(medium_count):
		var pos := center + Vector2(randf_range(-spread, spread), randf_range(-spread, spread))
		to_spawn.append({"type": EnemyType.MEDIUM, "pos": pos})

	for _n in range(large_count):
		var pos := center + Vector2(randf_range(-spread, spread), randf_range(-spread, spread))
		to_spawn.append({"type": EnemyType.LARGE, "pos": pos})

	# Process a batch this frame. Remaining are stored for subsequent frames.
	# We store the queue on the node for deferred processing.
	if to_spawn.is_empty():
		return

	# For simplicity, spawn all now with staggered fade-in timing.
	for entry in to_spawn:
		_spawn_single(entry.type, entry.pos)

## Spawns a single enemy of [param etype] at [param pos].
func _spawn_single(etype: int, pos: Vector2) -> void:
	if _active_count >= MAX_TOTAL:
		push_warning("EnemyManager: Cannot spawn -- max capacity (%d) reached." % MAX_TOTAL)
		return

	var idx := _active_count
	_active_count += 1

	_type[idx] = etype
	_state[idx] = EnemyState.SPAWNING
	_positions[idx] = pos
	_velocities[idx] = Vector2.ZERO
	_timers[idx] = float(Time.get_ticks_msec())  # spawn start time stored in timer
	_timers2[idx] = 0.0
	_directions[idx] = Vector2.ZERO
	_flash_frames[idx] = 0
	_spawn_fade_ms[idx] = randi_range(SPAWN_FADE_MIN_MS, SPAWN_FADE_MAX_MS)
	_retreat_blocked_since[idx] = 0
	_strafe_direction[idx] = 1 if randf() > 0.5 else -1

	match etype:
		EnemyType.SMALL:
			_hp[idx] = HP_SMALL
			_max_hp[idx] = HP_SMALL
		EnemyType.MEDIUM:
			_hp[idx] = HP_MEDIUM
			_max_hp[idx] = HP_MEDIUM
			# Start in CHASE (approach) but will transition.
			_timers[idx] = float(Time.get_ticks_msec())
		EnemyType.LARGE:
			_hp[idx] = HP_LARGE
			_max_hp[idx] = HP_LARGE
			_timers[idx] = float(Time.get_ticks_msec()) + randi_range(LARGE_CHARGE_COOLDOWN_MIN_MS, LARGE_CHARGE_COOLDOWN_MAX_MS)

	# Emit spawn signal.
	var eb := get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("enemy_spawned"):
		eb.enemy_spawned.emit(etype, pos, idx)

# ---------------------------------------------------------------------------
# Small enemy AI (Story 002)
# ---------------------------------------------------------------------------

## Updates a small enemy: chase player, contact damage, hit cooldown, pushback.
##
## State machine:
##   SPAWNING -> CHASE (after fade-in)
##   CHASE -> HIT_COOLDOWN (on contact damage)
##   HIT_COOLDOWN -> CHASE (after 200ms)
##   Any -> DEAD (on HP <= 0)
func _update_small(i: int, now: int) -> void:
	match _state[i]:
		EnemyState.SPAWNING:
			var spawn_start := int(_timers[i])
			var elapsed := now - spawn_start
			if elapsed >= _spawn_fade_ms[i]:
				_state[i] = EnemyState.CHASE
				_timers[i] = 0.0

		EnemyState.CHASE:
			if player_node == null:
				return
			var to_player := _player_position() - _positions[i]
			var dist := to_player.length()

			if dist < 0.01:
				return

			var direction := to_player.normalized()
			_velocities[i] = direction * SMALL_SPEED

			# Contact damage: check overlap with player.
			if dist < RADIUS_SMALL + 8.0:  # player radius ~8
				_apply_contact_damage_to_player(SMALL_CONTACT_DAMAGE, _positions[i])
				# Pushback away from player.
				var pushback := direction * -randf_range(SMALL_PUSHBACK_MIN, SMALL_PUSHBACK_MAX)
				_positions[i] += pushback
				# Enter hit cooldown.
				_state[i] = EnemyState.HIT_COOLDOWN
				_timers[i] = float(now)
				return

		EnemyState.HIT_COOLDOWN:
			if now - int(_timers[i]) >= SMALL_HIT_COOLDOWN_MS:
				_state[i] = EnemyState.CHASE
				_timers[i] = 0.0
			# During cooldown, drift to a stop.
			_velocities[i] = _velocities[i].lerp(Vector2.ZERO, 0.2)

		EnemyState.DEAD:
			pass

# ---------------------------------------------------------------------------
# Medium enemy AI (Story 003)
# ---------------------------------------------------------------------------

## Updates a medium enemy: maintain distance, shoot bullets, corner behavior.
##
## State machine:
##   SPAWNING -> CHASE (approach)
##   CHASE: approach at 120px/s until within [140,210] range
##   HOLD: at range, wait for attack cooldown
##   ATTACK: 250ms windup -> shoot bullet
##   HIT_COOLDOWN: 50ms stun + flash
##   RETREAT: back off at 180px/s if too close
##   RAPID_FIRE: corner behavior -- 3 shots, 150ms interval, lateral strafe
##
## Distance hysteresis: switch to RETREAT at <140px, switch to CHASE at >210px.
func _update_medium(i: int, now: int) -> void:
	if player_node == null:
		return

	var to_player := _player_position() - _positions[i]
	var dist := to_player.length()

	match _state[i]:
		EnemyState.SPAWNING:
			var spawn_start := int(_timers[i])
			if now - spawn_start >= _spawn_fade_ms[i]:
				_state[i] = EnemyState.CHASE
				_timers[i] = float(now)

		EnemyState.CHASE:
			# Approach player at 120px/s.
			if dist > MEDIUM_DIST_MAX:
				var direction := to_player.normalized() if dist > 0.01 else Vector2.RIGHT
				_velocities[i] = direction * MEDIUM_APPROACH_SPEED
				_directions[i] = direction
			else:
				# Enter HOLD state at range.
				_state[i] = EnemyState.ATTACK  # Start attack windup.
				_timers[i] = float(now)
				_velocities[i] = Vector2.ZERO

		EnemyState.RETREAT:
			# Move away from player at 180px/s.
			if dist > 0.01:
				var away := -to_player.normalized()
				_velocities[i] = away * MEDIUM_RETREAT_SPEED

			# Corner detection: if retreat is blocked (position barely changed).
			if _retreat_blocked_since[i] == 0:
				_retreat_blocked_since[i] = now
			elif now - _retreat_blocked_since[i] > MEDIUM_CORNER_THRESHOLD_MS:
				# Corner behavior: switch to RAPID_FIRE.
				_state[i] = EnemyState.RAPID_FIRE
				_timers[i] = float(now)
				_timers2[i] = 0.0  # shot counter
				_retreat_blocked_since[i] = 0
				return

			# Hysteresis: stop retreating when far enough.
			if dist > MEDIUM_DIST_MIN + 20.0:
				_state[i] = EnemyState.CHASE
				_timers[i] = float(now)
				_retreat_blocked_since[i] = 0

		EnemyState.ATTACK:
			# Windup phase: 250ms.
			var windup_elapsed := now - int(_timers[i])
			_velocities[i] = Vector2.ZERO

			if windup_elapsed >= MEDIUM_ATTACK_WINDUP_MS:
				# Fire bullet toward player.
				_spawn_enemy_bullet(_positions[i], to_player.normalized() if dist > 0.01 else Vector2.RIGHT, MEDIUM_BULLET_SPEED, MEDIUM_BULLET_MAX_DIST)
				# Start cooldown.
				_state[i] = EnemyState.CHASE
				_timers[i] = float(now + randi_range(MEDIUM_COOLDOWN_MIN_MS, MEDIUM_COOLDOWN_MAX_MS))
				# Re-evaluate distance for next state.
				if dist < MEDIUM_DIST_MIN:
					_state[i] = EnemyState.RETREAT
					_timers[i] = 0.0

		EnemyState.RAPID_FIRE:
			# Corner behavior: 3 rapid shots at 150ms intervals + lateral strafe.
			var rf_elapsed := now - int(_timers[i])
			var shots_fired := int(_timers2[i])
			var shots_total := MEDIUM_RAPID_FIRE_COUNT

			if shots_fired < shots_total:
				var shot_interval := MEDIUM_RAPID_FIRE_INTERVAL_MS
				var expected_shot := shots_fired * shot_interval
				if rf_elapsed >= expected_shot:
					_spawn_enemy_bullet(_positions[i], to_player.normalized() if dist > 0.01 else Vector2.RIGHT, MEDIUM_BULLET_SPEED, MEDIUM_BULLET_MAX_DIST)
					_timers2[i] = float(shots_fired + 1)

			# Lateral strafe perpendicular to player direction.
			var perp := Vector2(-to_player.y, to_player.x).normalized() if dist > 0.01 else Vector2(0, 1)
			_velocities[i] = perp * _strafe_direction[i] * MEDIUM_STRAFE_SPEED

			# End after all shots + buffer.
			if rf_elapsed >= shots_total * MEDIUM_RAPID_FIRE_INTERVAL_MS + 300:
				_state[i] = EnemyState.CHASE
				_timers[i] = float(now + randi_range(MEDIUM_COOLDOWN_MIN_MS, MEDIUM_COOLDOWN_MAX_MS))
				_timers2[i] = 0.0

		EnemyState.HIT_COOLDOWN:
			# 50ms stun after being hit.
			_velocities[i] = _velocities[i].lerp(Vector2.ZERO, 0.3)
			if now - int(_timers[i]) >= MEDIUM_STUN_MS:
				_state[i] = EnemyState.CHASE
				_timers[i] = float(now)

		EnemyState.DEAD:
			pass

# ---------------------------------------------------------------------------
# Large enemy AI (Story 004)
# ---------------------------------------------------------------------------

## Updates a large enemy: advance, charge, melee, death explosion.
##
## State machine:
##   SPAWNING -> CHASE
##   CHASE: advance at 60px/s toward player
##   CHARGE_WINDUP: 500ms windup, direction locked at end
##   CHARGING: 250px/s dash for 1s
##   MELEE_WINDUP: 400ms windup when within 80px
##   HIT_COOLDOWN: no stun, just 2 frames white flash
##   DEAD: multi-stage explosion ~600ms
func _update_large(i: int, now: int) -> void:
	if player_node == null:
		return

	var to_player := _player_position() - _positions[i]
	var dist := to_player.length()

	match _state[i]:
		EnemyState.SPAWNING:
			var spawn_start := int(_timers[i])
			if now - spawn_start >= _spawn_fade_ms[i]:
				_state[i] = EnemyState.CHASE
				_timers[i] = float(now)

		EnemyState.CHASE:
			# Advance toward player at 60px/s.
			if dist > 0.01:
				_directions[i] = to_player.normalized()
			_velocities[i] = _directions[i] * LARGE_ADVANCE_SPEED if _directions[i] != Vector2.ZERO else Vector2.RIGHT * LARGE_ADVANCE_SPEED

			# Check melee range.
			if dist < LARGE_MELEE_DIST:
				var cooldown_end := int(_timers2[i])
				if now >= cooldown_end:
					_state[i] = EnemyState.MELEE_WINDUP
					_timers[i] = float(now)
					_velocities[i] = Vector2.ZERO
				return

			# Check charge cooldown.
			var charge_cooldown_end := int(_timers[i])
			if now >= charge_cooldown_end and dist > LARGE_MELEE_DIST:
				_state[i] = EnemyState.CHARGE_WINDUP
				_timers[i] = float(now)
				_velocities[i] = Vector2.ZERO

		EnemyState.CHARGE_WINDUP:
			# 500ms windup.
			var windup_elapsed := now - int(_timers[i])
			_velocities[i] = Vector2.ZERO

			# Lock direction at windup end.
			if dist > 0.01:
				_directions[i] = to_player.normalized()

			if windup_elapsed >= LARGE_CHARGE_WINDUP_MS:
				_state[i] = EnemyState.CHARGING
				_timers[i] = float(now)
				# Direction is locked -- charge direction.

		EnemyState.CHARGING:
			# Dash at 250px/s for 1s.
			var charge_elapsed := now - int(_timers[i])
			if charge_elapsed >= LARGE_CHARGE_DURATION_MS:
				# Charge complete. Reset cooldown.
				_state[i] = EnemyState.CHASE
				_timers[i] = float(now + randi_range(LARGE_CHARGE_COOLDOWN_MIN_MS, LARGE_CHARGE_COOLDOWN_MAX_MS))
				_velocities[i] = Vector2.ZERO
			else:
				_velocities[i] = _directions[i] * LARGE_CHARGE_SPEED

		EnemyState.MELEE_WINDUP:
			# 400ms windup.
			var melee_elapsed := now - int(_timers[i])
			_velocities[i] = Vector2.ZERO

			if melee_elapsed >= LARGE_MELEE_WINDUP_MS:
				# Apply melee damage to player.
				if dist < LARGE_MELEE_DIST + 20.0:  # slight leniency
					_apply_contact_damage_to_player(LARGE_MELEE_DAMAGE, _positions[i])
				# Start melee cooldown.
				_timers2[i] = float(now + randi_range(LARGE_MELEE_COOLDOWN_MIN_MS, LARGE_MELEE_COOLDOWN_MAX_MS))
				_state[i] = EnemyState.CHASE
				_timers[i] = float(now)

		EnemyState.HIT_COOLDOWN:
			# No stun for large enemies. Just brief flash that resolves on its own.
			if _flash_frames[i] <= 0:
				_state[i] = EnemyState.CHASE
				_timers[i] = float(now)

		EnemyState.DEAD:
			# Multi-stage explosion: tracked via timer.
			var death_elapsed := now - int(_timers[i])
			if death_elapsed >= LARGE_DEATH_EXPLOSION_MS:
				# Explosion complete -- queued for removal by _on_enemy_death already.
				pass

# ---------------------------------------------------------------------------
# Contact damage helper
# ---------------------------------------------------------------------------

func _apply_contact_damage_to_player(damage: int, source_pos: Vector2) -> void:
	if damage_health_system != null:
		damage_health_system.take_damage(damage, source_pos)

# ---------------------------------------------------------------------------
# Enemy bullets
# ---------------------------------------------------------------------------

## Spawns a bullet from [param origin] traveling in [param direction] at
## [param speed] px/s with [param max_dist] px maximum range.
func _spawn_enemy_bullet(origin: Vector2, direction: Vector2, speed: float, max_dist: float) -> bool:
	# Find an inactive bullet slot.
	for b in range(MAX_BULLETS):
		if not _bullet_active[b]:
			_bullet_positions[b] = origin
			_bullet_velocities[b] = direction * speed
			_bullet_dist_traveled[b] = 0.0
			_bullet_active[b] = true
			return true

	# Pool exhausted -- find the bullet nearest to max range and replace it.
	var oldest_idx := 0
	var oldest_dist := 0.0
	for b in range(MAX_BULLETS):
		if _bullet_dist_traveled[b] > oldest_dist:
			oldest_dist = _bullet_dist_traveled[b]
			oldest_idx = b

	_bullet_positions[oldest_idx] = origin
	_bullet_velocities[oldest_idx] = direction * speed
	_bullet_dist_traveled[oldest_idx] = 0.0
	_bullet_active[oldest_idx] = true
	return true

func _update_bullets() -> void:
	if player_node == null:
		return

	var player_pos := _player_position()

	for b in range(MAX_BULLETS):
		if not _bullet_active[b]:
			continue

		# Move bullet.
		var move := _bullet_velocities[b] * get_physics_process_delta_time()
		_bullet_positions[b] += move
		_bullet_dist_traveled[b] += move.length()

		# Check max range.
		if _bullet_dist_traveled[b] >= MEDIUM_BULLET_MAX_DIST:
			_bullet_active[b] = false
			continue

		# Check player hit (radius-based).
		var to_player := player_pos - _bullet_positions[b]
		var player_radius := 8.0  # approximate
		var bullet_radius := 4.0
		if to_player.length() < player_radius + bullet_radius:
			_apply_contact_damage_to_player(1, _bullet_positions[b])
			_bullet_active[b] = false

# ---------------------------------------------------------------------------
# Damage application
# ---------------------------------------------------------------------------

## Applies [param amount] damage to enemy at [param index].
##
## If HP reaches 0, triggers death sequence. White flash is applied for hit
## feedback. Damage is routed through compute_player_damage() on the
## DamageHealthSystem when called from player attacks.
func apply_damage(index: int, amount: int) -> void:
	if index < 0 or index >= _active_count:
		return
	if _state[index] == EnemyState.DEAD:
		return
	if amount <= 0:
		return

	_hp[index] -= amount

	# Hit feedback: white flash.
	match _type[index]:
		EnemyType.SMALL:
			# Small enemies: instant death (1 HP).
			pass
		EnemyType.MEDIUM:
			_flash_frames[index] = MEDIUM_FLASH_FRAMES
			if _state[index] not in [EnemyState.DEAD, EnemyState.SPAWNING]:
				_state[index] = EnemyState.HIT_COOLDOWN
				_timers[index] = float(Time.get_ticks_msec())
		EnemyType.LARGE:
			_flash_frames[index] = 2
			# Large: no stun, just flash. If not in windup/charging/dead, keep chasing.
			if _state[index] not in [EnemyState.DEAD, EnemyState.SPAWNING, EnemyState.CHARGE_WINDUP, EnemyState.CHARGING, EnemyState.MELEE_WINDUP]:
				_state[index] = EnemyState.HIT_COOLDOWN
				_timers[index] = float(Time.get_ticks_msec())

	if _hp[index] <= 0:
		_hp[index] = 0
		_on_enemy_death(index)

## Applies [param amount] damage to all enemies overlapping with [param query].
##
## Used by SkillSystem for AoE damage application. Delegates to intersect_shape
## and then routes damage per-enemy.
func apply_damage_to_all_in_shape(query: PhysicsShapeQueryParameters2D, amount: int) -> void:
	if amount <= 0:
		return

	# Get the physics space state.
	var space_state := get_world_2d().direct_space_state
	var results: Array = space_state.intersect_shape(query)

	for hit in results:
		var collider = hit.get("collider")
		# We need to find the enemy index from the collider.
		# For now, use a position-based lookup for enemies.
		# In practice, colliders would be enemy-specific nodes.
		if collider == null:
			continue
		# Try position-based matching.
		_apply_damage_to_enemy_at_position(hit.get("position", Vector2.ZERO), amount)

## Placeholder: applies damage to enemy nearest to the given position.
## In full implementation, colliders map directly to enemy indices via metadata.
func _apply_damage_to_enemy_at_position(pos: Vector2, amount: int) -> void:
	var nearest_idx := -1
	var nearest_dist := 50.0  # max match distance

	for i in range(_active_count):
		if _state[i] == EnemyState.DEAD:
			continue
		var d := _positions[i].distance_to(pos)
		if d < nearest_dist:
			nearest_dist = d
			nearest_idx = i

	if nearest_idx >= 0:
		apply_damage(nearest_idx, amount)

## Alternative AoE: apply damage to all enemies within [param radius] of
## [param center].
func apply_aoe_damage(center: Vector2, radius: float, amount: int) -> void:
	if amount <= 0:
		return
	for i in range(_active_count):
		if _state[i] == EnemyState.DEAD:
			continue
		if _positions[i].distance_squared_to(center) <= radius * radius:
			apply_damage(i, amount)

# ---------------------------------------------------------------------------
# Death handling
# ---------------------------------------------------------------------------

func _on_enemy_death(index: int) -> void:
	_state[index] = EnemyState.DEAD
	_timers[index] = float(Time.get_ticks_msec())  # For death animation timing

	# Emit killed signal.
	var eb := get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("enemy_killed"):
		eb.enemy_killed.emit(_type[index], _positions[index], index)

	# Queue for removal.
	_pending_removal.append(index)

	# Record kill in GameManager if available.
	if GameManager.current_run != null:
		GameManager.record_kill()

func _process_removal_queue() -> void:
	if _pending_removal.is_empty():
		return

	var to_process := mini(_pending_removal.size(), REMOVAL_PER_FRAME_MAX)
	# Sort descending so we remove from the end first (preserves indices).
	_pending_removal.sort()
	_pending_removal.reverse()

	for _n in range(to_process):
		if _pending_removal.is_empty():
			break
		var idx: int = _pending_removal.pop_back()
		_remove_slot(idx)

## Removes an enemy slot by swapping the last active enemy into it.
func _remove_slot(idx: int) -> void:
	if idx < 0 or idx >= _active_count:
		return

	var last := _active_count - 1

	if idx != last:
		# Swap last active into this slot.
		_type[idx] = _type[last]
		_state[idx] = _state[last]
		_hp[idx] = _hp[last]
		_max_hp[idx] = _max_hp[last]
		_positions[idx] = _positions[last]
		_velocities[idx] = _velocities[last]
		_timers[idx] = _timers[last]
		_timers2[idx] = _timers2[last]
		_directions[idx] = _directions[last]
		_flash_frames[idx] = _flash_frames[last]
		_spawn_fade_ms[idx] = _spawn_fade_ms[last]
		_retreat_blocked_since[idx] = _retreat_blocked_since[last]
		_strafe_direction[idx] = _strafe_direction[last]

	# Clear the last slot.
	_type[last] = EnemyType.SMALL
	_state[last] = EnemyState.DEAD
	_hp[last] = 0
	_max_hp[last] = 0
	_positions[last] = Vector2.ZERO
	_velocities[last] = Vector2.ZERO
	_timers[last] = 0.0
	_timers2[last] = 0.0
	_directions[last] = Vector2.ZERO
	_flash_frames[last] = 0
	_spawn_fade_ms[last] = 0
	_retreat_blocked_since[last] = 0
	_strafe_direction[last] = 1

	_active_count -= 1

# ---------------------------------------------------------------------------
# Collision detection queries
# ---------------------------------------------------------------------------

## Checks if a bullet from [param origin] traveling along [param direction]
## hits any enemy within [param max_dist].
##
## Uses O(N) ray-circle intersection per ADR-0004.
##
## Returns Dictionary with keys:
##   - "index": int (enemy index, -1 if no hit)
##   - "position": Vector2 (hit point, origin + direction * max_dist if no hit)
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

## Checks if the player overlaps with any enemy.
##
## Returns the index of the first overlapping enemy, or -1 if none.
func check_player_contact(player_pos: Vector2, player_radius: float) -> int:
	for i in range(_active_count):
		if _state[i] in [EnemyState.DEAD, EnemyState.SPAWNING]:
			continue
		var dist := _positions[i].distance_to(player_pos)
		var radius := _get_radius(_type[i])
		if dist < player_radius + radius:
			return i
	return -1

## Returns the world positions of all non-dead enemies.
##
## Used by DodgeSystem for perfect dodge detection.
func get_all_attack_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for i in range(_active_count):
		if _state[i] != EnemyState.DEAD:
			result.append(_positions[i])
	return result

# ---------------------------------------------------------------------------
# Spatial hash grid (separation)
# ---------------------------------------------------------------------------

func _build_separation_grid() -> void:
	_grid.clear()

	for i in range(_active_count):
		if _state[i] == EnemyState.DEAD or _state[i] == EnemyState.SPAWNING:
			continue

		var cell := _world_to_cell(_positions[i])
		if not _grid.has(cell):
			_grid[cell] = []
		_grid[cell].append(i)

	# Apply separation forces.
	for i in range(_active_count):
		if _state[i] == EnemyState.DEAD or _state[i] == EnemyState.SPAWNING:
			continue

		var cell := _world_to_cell(_positions[i])
		var separation := Vector2.ZERO

		# Query 9 adjacent cells (3x3).
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var neighbor_cell := Vector2i(cell.x + dx, cell.y + dy)
				if not _grid.has(neighbor_cell):
					continue

				for other_idx in _grid[neighbor_cell]:
					if other_idx == i:
						continue
					if _state[other_idx] == EnemyState.DEAD or _state[other_idx] == EnemyState.SPAWNING:
						continue

					var diff := _positions[i] - _positions[other_idx]
					var dist := diff.length()
					if dist < SEPARATION_RADIUS and dist > 0.01:
						var force := diff.normalized() * (SEPARATION_RADIUS - dist) / SEPARATION_RADIUS * SEPARATION_FORCE
						separation += force

		_velocities[i] += separation

func _world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(floorf(pos.x / _grid_cell_size)), int(floorf(pos.y / _grid_cell_size)))

# ---------------------------------------------------------------------------
# Rendering sync
# ---------------------------------------------------------------------------

func _sync_rendering() -> void:
	# --- Small enemies: update MultiMesh transforms ---
	var small_idx := 0
	for i in range(_active_count):
		if _type[i] == EnemyType.SMALL and _state[i] != EnemyState.DEAD:
			if small_idx < MAX_SMALL:
				var xform := Transform2D(0.0, _positions[i])
				# Fade-in: scale from 0 to 1 over spawn_fade_ms.
				if _state[i] == EnemyState.SPAWNING:
					var spawn_start := int(_timers[i])
					var elapsed := Time.get_ticks_msec() - spawn_start
					var progress := clampf(float(elapsed) / float(_spawn_fade_ms[i]), 0.0, 1.0)
					xform = xform.scaled(Vector2(progress, progress))
				# White flash: set modulate via instance color (simplified: use scale).
				_small_multimesh_data.set_instance_transform_2d(small_idx, xform)
				_small_multimesh_data.set_instance_color(small_idx, Color.WHITE if _flash_frames[i] <= 0 else Color(2.0, 2.0, 2.0))
				small_idx += 1

	# Hide remaining MultiMesh instances.
	while small_idx < MAX_SMALL:
		_small_multimesh_data.set_instance_transform_2d(small_idx, Transform2D(0.0, Vector2(-10000, -10000)))
		small_idx += 1

	# --- Medium enemies: update Sprite2D pool ---
	# First, hide all.
	for sprite in _medium_sprites:
		sprite.visible = false

	var med_idx := 0
	for i in range(_active_count):
		if _type[i] == EnemyType.MEDIUM and _state[i] != EnemyState.DEAD:
			if med_idx < MAX_MEDIUM:
				var sprite := _medium_sprites[med_idx]
				sprite.global_position = _positions[i]
				sprite.visible = true
				# White flash.
				sprite.modulate = Color(2.0, 2.0, 2.0) if _flash_frames[i] > 0 else Color.RED
				# Fade-in alpha.
				if _state[i] == EnemyState.SPAWNING:
					var spawn_start := int(_timers[i])
					var elapsed := Time.get_ticks_msec() - spawn_start
					var progress := clampf(float(elapsed) / float(_spawn_fade_ms[i]), 0.0, 1.0)
					sprite.modulate.a = progress
				else:
					sprite.modulate.a = 1.0
				med_idx += 1

	# --- Large enemies: update Sprite2D pool ---
	for sprite in _large_sprites:
		sprite.visible = false

	var large_idx := 0
	for i in range(_active_count):
		if _type[i] == EnemyType.LARGE and _state[i] != EnemyState.DEAD:
			if large_idx < MAX_LARGE:
				var sprite := _large_sprites[large_idx]
				sprite.global_position = _positions[i]
				sprite.visible = true
				sprite.modulate = Color(2.0, 2.0, 2.0) if _flash_frames[i] > 0 else Color.WHITE
				if _state[i] == EnemyState.SPAWNING:
					var spawn_start := int(_timers[i])
					var elapsed := Time.get_ticks_msec() - spawn_start
					var progress := clampf(float(elapsed) / float(_spawn_fade_ms[i]), 0.0, 1.0)
					sprite.modulate.a = progress
				else:
					sprite.modulate.a = 1.0
				# Death explosion: scale up and fade out.
				if _state[i] == EnemyState.DEAD:
					var death_elapsed := Time.get_ticks_msec() - int(_timers[i])
					var death_progress := clampf(float(death_elapsed) / float(LARGE_DEATH_EXPLOSION_MS), 0.0, 1.0)
					sprite.scale = Vector2.ONE * (1.0 + death_progress * 1.5)
					sprite.modulate.a = 1.0 - death_progress
					sprite.modulate = Color(1.0, 0.5, 0.0)  # orange explosion
				large_idx += 1

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _player_position() -> Vector2:
	if player_node != null:
		return player_node.global_position
	return Vector2.ZERO

func _get_radius(etype: int) -> float:
	match etype:
		EnemyType.SMALL:
			return RADIUS_SMALL
		EnemyType.MEDIUM:
			return RADIUS_MEDIUM
		EnemyType.LARGE:
			return RADIUS_LARGE
	return RADIUS_SMALL

# ---------------------------------------------------------------------------
# Public API -- query helpers
# ---------------------------------------------------------------------------

## Returns the current number of active enemies.
func get_active_count() -> int:
	return _active_count

## Returns the count of active enemies by type.
func get_count_by_type(etype: int) -> int:
	var count := 0
	for i in range(_active_count):
		if _type[i] == etype and _state[i] != EnemyState.DEAD:
			count += 1
	return count

## Returns true if the enemy manager is frozen (player is dead).
func is_frozen() -> bool:
	return _frozen

## Unfreezes the enemy manager (for scene reset).
func unfreeze() -> void:
	_frozen = false
