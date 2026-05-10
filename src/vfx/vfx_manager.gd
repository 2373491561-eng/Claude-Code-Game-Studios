## VFXManager -- manages pre-allocated particle pools and screen effects.
##
## Implements: vfx-particles (Presentation layer)
## Governed by: ADR-0013 (VFX particle pool architecture), ADR-0005 (event bus signals)
##
## Provides 6 particle pools (bullet_trail, hit_spark, dodge_afterimage,
## skill_shockwave, skill_core, death_shatter) totaling 312 pre-allocated nodes.
## Pools use a simple Array[Node2D] acquire/release pattern with LRU eviction
## on pool exhaustion. Particles update speed_scale from Engine.time_scale.
##
## Screen effects (vignette, cold filter) are managed here as ColorRect nodes.
##
## Usage:
##   [codeblock]
##   # In game.tscn:
##   var vfx_mgr := VFXManager.new()
##   add_child(vfx_mgr)
##   [/codeblock]
class_name VFXManager
extends Node2D

# ---------------------------------------------------------------------------
# Constants -- pool sizes
# ---------------------------------------------------------------------------

const POOL_BULLET_TRAIL: int = 16
const POOL_HIT_SPARK: int = 128
const POOL_DODGE_AFTERIMAGE: int = 8
const POOL_SKILL_SHOCKWAVE: int = 64
const POOL_SKILL_CORE: int = 32
const POOL_DEATH_SHATTER: int = 64

## Total pooled particles: 312
const TOTAL_POOL_SIZE: int = POOL_BULLET_TRAIL + POOL_HIT_SPARK + POOL_DODGE_AFTERIMAGE + POOL_SKILL_SHOCKWAVE + POOL_SKILL_CORE + POOL_DEATH_SHATTER

## Maximum time a particle can remain active before being force-recycled.
## Prevents leaked particles from permanently draining the pool.
const MAX_PARTICLE_LIFETIME_MS: int = 10000

# ---------------------------------------------------------------------------
# Enum for pool types
# ---------------------------------------------------------------------------

enum PoolType {
	BULLET_TRAIL,
	HIT_SPARK,
	DODGE_AFTERIMAGE,
	SKILL_SHOCKWAVE,
	SKILL_CORE,
	DEATH_SHATTER,
}

# ---------------------------------------------------------------------------
# Particle pool structure
# ---------------------------------------------------------------------------

## A single particle pool: available + active arrays.
class ParticlePool:
	var available: Array[Node2D] = []
	var active: Array[Node2D] = []
	var spawn_timestamps: Array[int] = []
	var pool_type: int = PoolType.BULLET_TRAIL

	func _init(pool_type: int) -> void:
		self.pool_type = pool_type

	## Acquires a particle from the pool, or recycles the oldest active one.
	func acquire(returned_particle: Node2D, now: int) -> void:
		active.append(returned_particle)
		spawn_timestamps.append(now)
		returned_particle.visible = true
		returned_particle.process_mode = Node.PROCESS_MODE_INHERIT
		returned_particle.global_position = Vector2.ZERO

	## Releases a particle back to the pool.
	func release(particle: Node2D) -> void:
		var idx := active.find(particle)
		if idx >= 0:
			active.remove_at(idx)
			spawn_timestamps.remove_at(idx)
		particle.visible = false
		particle.process_mode = Node.PROCESS_MODE_DISABLED
		_reset_particle(particle)
		available.append(particle)

	## Resets a particle to its default state.
	func _reset_particle(p: Node2D) -> void:
		if p is GPUParticles2D:
			p.emitting = false
			p.amount = 0
		p.scale = Vector2.ONE
		p.modulate = Color.WHITE
		p.rotation = 0.0

	## Sweeps for expired particles (active longer than max lifetime).
	func sweep_expired(now: int, max_lifetime_ms: int) -> Array[Node2D]:
		var expired: Array[Node2D] = []
		for i in range(active.size() - 1, -1, -1):
			if now - spawn_timestamps[i] > max_lifetime_ms:
				var p := active[i]
				active.remove_at(i)
				spawn_timestamps.remove_at(i)
				p.visible = false
				p.process_mode = Node.PROCESS_MODE_DISABLED
				_reset_particle(p)
				available.append(p)
		return expired


# ---------------------------------------------------------------------------
# Pool container
# ---------------------------------------------------------------------------

## Dictionary mapping PoolType int to ParticlePool.
var _pools: Dictionary = {}

## Dictionary mapping PoolType int to original available sizes (for reset).
var _pool_available_sizes: Dictionary = {}

# ---------------------------------------------------------------------------
# Screen effect nodes
# ---------------------------------------------------------------------------

## Full-screen vignette overlay (dark edges).
var _vignette: ColorRect = null

## Full-screen cold filter (blue tint on perfect dodge).
var _cold_filter: ColorRect = null

## CanvasLayer parent for screen effects (renders above everything).
var _effect_canvas: CanvasLayer = null

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

## Timestamp of the last expired-particle sweep.
var _last_sweep_ms: int = 0

## Sweep interval in milliseconds.
const SWEEP_INTERVAL_MS: int = 5000

## Current viewport size (for screen effects).
var _viewport_size: Vector2 = Vector2.ZERO

# ---------------------------------------------------------------------------
# Node lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_init_pools()
	_create_screen_effects()
	_connect_signals()
	_last_sweep_ms = Time.get_ticks_msec()

func _process(_delta: float) -> void:
	# Update particle speed scales.
	for pool in _pools.values():
		for p in pool.active:
			if p is GPUParticles2D:
				p.speed_scale = Engine.time_scale

	# Periodic expired-particle sweep.
	var now := Time.get_ticks_msec()
	if now - _last_sweep_ms > SWEEP_INTERVAL_MS:
		_last_sweep_ms = now
		for pool in _pools.values():
			pool.sweep_expired(now, MAX_PARTICLE_LIFETIME_MS)

# ---------------------------------------------------------------------------
# Pool initialization
# ---------------------------------------------------------------------------

func _init_pools() -> void:
	_create_pool(PoolType.BULLET_TRAIL, POOL_BULLET_TRAIL, false)   # Sprite2D for trails
	_create_pool(PoolType.HIT_SPARK, POOL_HIT_SPARK, true)           # GPUParticles2D
	_create_pool(PoolType.DODGE_AFTERIMAGE, POOL_DODGE_AFTERIMAGE, false)  # Sprite2D
	_create_pool(PoolType.SKILL_SHOCKWAVE, POOL_SKILL_SHOCKWAVE, true)     # GPUParticles2D
	_create_pool(PoolType.SKILL_CORE, POOL_SKILL_CORE, true)               # GPUParticles2D
	_create_pool(PoolType.DEATH_SHATTER, POOL_DEATH_SHATTER, true)         # GPUParticles2D

## Creates a particle pool of the given type and size.
## [param use_gpu]: if true, creates GPUParticles2D; if false, creates Sprite2D.
func _create_pool(pool_type: int, size: int, use_gpu: bool) -> void:
	var pool := ParticlePool.new(pool_type)
	_pools[pool_type] = pool
	_pool_available_sizes[pool_type] = size

	for i in range(size):
		var node: Node2D
		if use_gpu:
			node = _create_gpu_particle(pool_type)
		else:
			node = _create_sprite_particle(pool_type)

		node.visible = false
		node.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(node)
		pool.available.append(node)

## Creates a GPUParticles2D node with minimal configuration for the given pool type.
func _create_gpu_particle(pool_type: int) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false

	match pool_type:
		PoolType.HIT_SPARK:
			p.amount = 12
			p.lifetime = 0.3
			p.modulate = Color(1.0, 0.8, 0.2)  # Orange sparks
			p.scale_amount_min = 0.5
			p.scale_amount_max = 1.5
		PoolType.SKILL_SHOCKWAVE:
			p.amount = 48
			p.lifetime = 0.5
			p.modulate = Color(0.2, 0.6, 1.0)  # Blue shockwave
			p.scale_amount_min = 0.8
			p.scale_amount_max = 2.0
		PoolType.SKILL_CORE:
			p.amount = 24
			p.lifetime = 0.4
			p.modulate = Color(1.0, 0.4, 0.1)  # Orange-red core
			p.scale_amount_min = 1.0
			p.scale_amount_max = 3.0
		PoolType.DEATH_SHATTER:
			p.amount = 16
			p.lifetime = 0.6
			p.modulate = Color(0.8, 0.3, 0.1)  # Red-orange shatter
			p.scale_amount_min = 0.3
			p.scale_amount_max = 1.2

	return p

## Creates a Sprite2D node for non-particle effects (trails, afterimages).
func _create_sprite_particle(pool_type: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = true
	s.visible = false

	match pool_type:
		PoolType.BULLET_TRAIL:
			s.modulate = Color(1.0, 0.9, 0.4, 0.7)  # Yellow-white trail
			s.scale = Vector2(0.15, 0.05)
		PoolType.DODGE_AFTERIMAGE:
			s.modulate = Color(0.3, 0.8, 1.0, 0.4)  # Cyan afterimage
			s.scale = Vector2(0.8, 0.8)

	return s

# ---------------------------------------------------------------------------
# Pool acquire / release
# ---------------------------------------------------------------------------

## Acquires a particle from the specified pool.
## Returns the particle node, or null if the pool type is invalid.
func acquire(pool_type: int) -> Node2D:
	var pool: ParticlePool = _pools.get(pool_type, null)
	if pool == null:
		return null

	var particle: Node2D

	if pool.available.size() > 0:
		# Pop from available.
		particle = pool.available.pop_back()
	else:
		# LRU eviction: recycle the oldest active particle.
		if pool.active.size() > 0:
			particle = pool.active.pop_front()
			pool.spawn_timestamps.pop_front()
			# Reset before reuse.
			if particle is GPUParticles2D:
				particle.emitting = false
				particle.amount = 0
			particle.scale = Vector2.ONE
			particle.modulate = Color.WHITE
			particle.rotation = 0.0
		else:
			return null

	pool.acquire(particle, Time.get_ticks_msec())
	return particle

## Releases a particle back to its pool based on pool type.
func release(pool_type: int, particle: Node2D) -> void:
	var pool: ParticlePool = _pools.get(pool_type, null)
	if pool == null:
		return
	pool.release(particle)

## Spawns a particle at [param pos] from the given pool.
## [param pool_type]: the pool to draw from.
## [param config]: optional Dictionary with keys like "color", "scale", "direction".
func spawn(pool_type: int, pos: Vector2, config: Dictionary = {}) -> void:
	var particle := acquire(pool_type)
	if particle == null:
		return

	particle.global_position = pos

	# Apply config overrides.
	if config.has("color") and config.color is Color:
		particle.modulate = config.color
	if config.has("scale") and config.scale is float:
		particle.scale = Vector2(config.scale, config.scale)
	if config.has("direction") and config.direction is Vector2:
		# Rotate particle to face direction.
		var dir: Vector2 = config.direction
		if dir.length_squared() > 0.001:
			particle.rotation = dir.angle()

	# Start emitting if it's a GPU particle.
	if particle is GPUParticles2D:
		var gpu := particle as GPUParticles2D
		gpu.emitting = true
		# Auto-release after lifetime.
		var lifetime := gpu.lifetime
		if lifetime > 0:
			get_tree().create_timer(lifetime).timeout.connect(
				func(): release(pool_type, particle)
			)

# ---------------------------------------------------------------------------
# Screen effects
# ---------------------------------------------------------------------------

func _create_screen_effects() -> void:
	_effect_canvas = CanvasLayer.new()
	_effect_canvas.layer = 64  # Below UI but above game world
	add_child(_effect_canvas)

	# Vignette: dark edges.
	_vignette = ColorRect.new()
	_vignette.color = Color(0.0, 0.0, 0.0, 0.2)  # Default subtle vignette
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effect_canvas.add_child(_vignette)

	# Cold filter: blue tint on perfect dodge.
	_cold_filter = ColorRect.new()
	_cold_filter.color = Color(0.0, 0.3, 0.8, 0.0)  # Start invisible
	_cold_filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cold_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effect_canvas.add_child(_cold_filter)

## Deepens the vignette (for wave transition).
## [param target_alpha]: target modulate.a value.
## [param duration]: transition duration in seconds.
func set_vignette_alpha(target_alpha: float, duration: float = 0.0) -> void:
	if _vignette == null:
		return

	if duration <= 0.0:
		_vignette.modulate.a = target_alpha
	else:
		var tween := create_tween()
		tween.set_ignore_time_scale(true)
		tween.tween_property(_vignette, "modulate:a", target_alpha, duration)

## Activates the cold filter (blue tint on perfect dodge).
## [param duration]: how long to keep the filter active in seconds.
func activate_cold_filter(duration: float = 0.3) -> void:
	if _cold_filter == null:
		return

	_cold_filter.modulate.a = 0.15
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(_cold_filter, "modulate:a", 0.0, duration)

# ---------------------------------------------------------------------------
# Signal connections
# ---------------------------------------------------------------------------

func _connect_signals() -> void:
	var eb := get_node_or_null("/root/EventBus")
	if eb == null:
		return

	if eb.has_signal("bullet_hit"):
		if not eb.bullet_hit.is_connected(_on_bullet_hit):
			eb.bullet_hit.connect(_on_bullet_hit)

	if eb.has_signal("dodge_normal"):
		if not eb.dodge_normal.is_connected(_on_dodge_normal):
			eb.dodge_normal.connect(_on_dodge_normal)

	if eb.has_signal("dodge_perfect"):
		if not eb.dodge_perfect.is_connected(_on_dodge_perfect):
			eb.dodge_perfect.connect(_on_dodge_perfect)

	if eb.has_signal("skill_1_cast"):
		if not eb.skill_1_cast.is_connected(_on_skill_1_cast):
			eb.skill_1_cast.connect(_on_skill_1_cast)

	if eb.has_signal("enemy_killed"):
		if not eb.enemy_killed.is_connected(_on_enemy_killed):
			eb.enemy_killed.connect(_on_enemy_killed)

# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_bullet_hit(hit_pos: Vector2, _is_skill2: bool) -> void:
	spawn(PoolType.HIT_SPARK, hit_pos)

func _on_dodge_normal(pos: Vector2, _direction: Vector2) -> void:
	spawn(PoolType.DODGE_AFTERIMAGE, pos)

func _on_dodge_perfect(pos: Vector2, _charge_count: int) -> void:
	spawn(PoolType.DODGE_AFTERIMAGE, pos)
	activate_cold_filter(0.5)

func _on_skill_1_cast(pos: Vector2) -> void:
	spawn(PoolType.SKILL_SHOCKWAVE, pos)
	spawn(PoolType.SKILL_CORE, pos)

func _on_enemy_killed(_type: int, position: Vector2, _index: int) -> void:
	spawn(PoolType.DEATH_SHATTER, position)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns the number of available particles in the given pool.
func get_available_count(pool_type: int) -> int:
	var pool: ParticlePool = _pools.get(pool_type, null)
	if pool == null:
		return 0
	return pool.available.size()

## Returns the number of active particles in the given pool.
func get_active_count(pool_type: int) -> int:
	var pool: ParticlePool = _pools.get(pool_type, null)
	if pool == null:
		return 0
	return pool.active.size()

## Returns the total number of particles across all pools.
func get_total_active_count() -> int:
	var count := 0
	for pool in _pools.values():
		count += pool.active.size()
	return count

## Resets all pools to their initial state (used on scene change).
func reset_all_pools() -> void:
	for pool_type in _pools.keys():
		var pool: ParticlePool = _pools[pool_type]
		# Release all active particles.
		while pool.active.size() > 0:
			var p := pool.active.pop_back()
			pool.spawn_timestamps.pop_back()
			p.visible = false
			p.process_mode = Node.PROCESS_MODE_DISABLED
			if p is GPUParticles2D:
				p.emitting = false
				p.amount = 0
			p.scale = Vector2.ONE
			p.modulate = Color.WHITE
			p.rotation = 0.0
			pool.available.append(p)
