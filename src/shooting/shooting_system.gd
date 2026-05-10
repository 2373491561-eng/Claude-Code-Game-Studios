class_name ShootingSystem extends Node2D

# ---------------------------------------------------------------------------
# Signals (connected by Presentation systems for VFX/audio)
# ---------------------------------------------------------------------------

## Emitted when a bullet is fired, regardless of hit or miss.
## [param origin] World-space starting position of the bullet.
## [param end_point] World-space end position (hit point or max range).
signal bullet_fired(origin: Vector2, end_point: Vector2)

## Emitted when a bullet travels its full range without hitting anything.
## [param origin] World-space starting position.
## [param end_point] World-space end point (origin + direction * weapon_range).
signal bullet_trail(origin: Vector2, end_point: Vector2)

# ---------------------------------------------------------------------------
# Exported configuration
# ---------------------------------------------------------------------------

## Reference to the InputSystem node (owned by game.tscn).
@export var input_system: InputSystem = null

## Reference to the EnemyManager node (owned by game.tscn).
## May be null during early integration -- hit detection is skipped gracefully.
@export var enemy_manager: Node = null

## Reference to the SkillSystem node (owned by game.tscn).
## May be null during early integration -- skill_2 features are skipped.
@export var skill_system: Node = null

## Reference to the Player node, used as the bullet origin point.
@export var player_node: Node2D = null

## Base damage per bullet before skill_2 multiplier.
@export var base_damage: int = 10

## Shots per second. Interval between shots is int(1000.0 / fire_rate) ms.
## At 8.0 rps: interval = 125 ms.
@export var fire_rate: float = 8.0

## Maximum distance a bullet travels before it is considered a miss.
@export var weapon_range: float = 800.0

# ---------------------------------------------------------------------------
# Per-frame state
# ---------------------------------------------------------------------------

## Timestamp (Time.get_ticks_msec()) of the most recent bullet fired.
## Used to enforce the fire rate interval.
var _last_fire_time_ms: int = 0

## Whether the shoot key was held on the previous physics frame.
## Used to detect release-then-repress for immediate fire reset.
var _was_shoot_held: bool = false

## Number of remaining pierce targets for the current skill_2 bullet.
## Set to 1 when skill_2 window is open and a bullet is fired.
## Decremented after the first pierce pass.
var _pierce_remaining: int = 0

## True when skill_2 was active for the current bullet being processed.
## Used to know whether to call consume_skill2() after processing.
var _skill2_active_this_shot: bool = false

# ---------------------------------------------------------------------------
# Node lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Initialize the fire timer to current time so the player doesn't
	# fire a bullet immediately on the first frame after scene load.
	_last_fire_time_ms = Time.get_ticks_msec()

## Polls shoot input and fires bullets on the configured interval.
##
## Fire is skipped when:
##   - input_system is not assigned
##   - aim_direction is Vector2.ZERO
##   - input state is DODGING, PAUSED, or DEAD
##   - fire rate interval has not elapsed
##
## Fire timer is reset when:
##   - consume_shoot_resume() returns true (flash-resume after dodge)
##   - the player releases and re-presses shoot within the interval
func _physics_process(_delta: float) -> void:
	if input_system == null:
		return

	# Don't fire if the player isn't aiming at anything.
	var aim_dir: Vector2 = input_system.get_aim_direction()
	if aim_dir == Vector2.ZERO:
		return

	var state: int = input_system.get_state()

	# Dodge-locked: shooting is blocked during dodge.
	if state == InputSystem.STATE_DODGING:
		return

	# No shooting while paused or dead.
	if state == InputSystem.STATE_PAUSED or state == InputSystem.STATE_DEAD:
		return

	# Flash-resume: if a dodge just ended and the player was still holding
	# shoot, reset the fire timer so the next bullet fires immediately.
	if input_system.consume_shoot_resume():
		_last_fire_time_ms = Time.get_ticks_msec()

	var is_pressed: bool = input_system.is_shoot_pressed()

	# Release-then-repress detection: if the player released shoot and then
	# pressed it again, reset the fire timer so they don't have to wait for
	# the previous interval to expire.
	if is_pressed and not _was_shoot_held:
		_last_fire_time_ms = Time.get_ticks_msec()

	_was_shoot_held = is_pressed

	if not is_pressed:
		return

	# Fire rate interval check.
	var interval_ms: int = int(1000.0 / fire_rate)
	var now: int = Time.get_ticks_msec()
	if now - _last_fire_time_ms < interval_ms:
		return

	_last_fire_time_ms = now
	_fire_bullet()

# ---------------------------------------------------------------------------
# Bullet firing pipeline
# ---------------------------------------------------------------------------

## Fires a single hitscan bullet.
##
## Pipeline:
##   1. Determine bullet origin (player position) and direction (aim).
##   2. Check skill_2 window -- if open, double damage and enable pierce.
##   3. First ray: check_bullet_hit() via enemy_manager.
##      - Miss: emit bullet_fired + bullet_trail to max range.
##      - Hit: apply damage, emit bullet_fired + EventBus.bullet_hit.
##   4. Pierce (skill_2 only): if _pierce_remaining > 0, fire second ray
##      from hit position + 2px offset toward remaining range.
##   5. Consume skill_2 if it was active.
func _fire_bullet() -> void:
	# Determine bullet origin.
	var origin: Vector2 = player_node.global_position if player_node else global_position
	var direction: Vector2 = input_system.get_aim_direction()
	if direction == Vector2.ZERO:
		return

	var max_dist: float = weapon_range
	var dmg_multiplier: float = 1.0
	var is_skill2: bool = false

	# --- Skill_2 window check ---
	if _has_skill2_methods() and skill_system.is_skill2_window_open():
		dmg_multiplier = 2.0
		is_skill2 = true
		_pierce_remaining = 1
		_skill2_active_this_shot = true

	# --- First ray ---
	var hit: Dictionary = _check_bullet_hit(origin, direction, max_dist)

	if hit.get("index", -1) == -1:
		# Miss: trail to max range.
		var end_point: Vector2 = origin + direction * max_dist
		bullet_fired.emit(origin, end_point)
		bullet_trail.emit(origin, end_point)
		_finish_skill2()
		return

	# Hit first target.
	var dmg: int = int(base_damage * dmg_multiplier)
	_apply_damage(hit["index"], dmg)
	_emit_bullet_hit(hit["position"], is_skill2)
	bullet_fired.emit(origin, hit["position"])

	# --- Pierce: second ray (skill_2 only) ---
	if _pierce_remaining > 0:
		_pierce_remaining -= 1
		var consumed_dist: float = (hit["position"] - origin).length()
		var remaining_dist: float = max_dist - consumed_dist

		if remaining_dist > 0.0:
			# Offset origin by 2px along direction to avoid re-hitting
			# the same target, per ADR-0010.
			var pierce_origin: Vector2 = hit["position"] + direction * 2.0
			var hit2: Dictionary = _check_bullet_hit(pierce_origin, direction, remaining_dist)

			if hit2.get("index", -1) != -1:
				# Second target also receives doubled damage.
				_apply_damage(hit2["index"], dmg)
				_emit_bullet_hit(hit2["position"], is_skill2)
				bullet_fired.emit(origin, hit2["position"])

	_finish_skill2()

# ---------------------------------------------------------------------------
# Skill_2 lifecycle
# ---------------------------------------------------------------------------

## Consumes skill_2 if it was active during this shot.
##
## Called at the end of _fire_bullet() regardless of hit/miss/pierce outcome.
## After this call, _pierce_remaining and _skill2_active_this_shot are reset
## so the next shot uses normal damage unless skill_2 is re-opened.
func _finish_skill2() -> void:
	if _skill2_active_this_shot:
		_skill2_active_this_shot = false
		_pierce_remaining = 0
		if _has_skill2_methods():
			skill_system.consume_skill2()

# ---------------------------------------------------------------------------
# EnemyManager integration (graceful degradation)
# ---------------------------------------------------------------------------

## Calls enemy_manager.check_bullet_hit() if available.
##
## Returns {"index": int, "position": Vector2} on success, or
## {"index": -1, "position": Vector2.ZERO} if enemy_manager is unavailable
## or lacks the method (graceful degradation).
func _check_bullet_hit(origin: Vector2, direction: Vector2, max_dist: float) -> Dictionary:
	if enemy_manager != null and enemy_manager.has_method("check_bullet_hit"):
		return enemy_manager.check_bullet_hit(origin, direction, max_dist)
	return {"index": -1, "position": Vector2.ZERO}

## Calls enemy_manager.apply_damage() if available.
func _apply_damage(index: int, damage: int) -> void:
	if enemy_manager != null and enemy_manager.has_method("apply_damage"):
		enemy_manager.apply_damage(index, damage)

# ---------------------------------------------------------------------------
# EventBus integration
# ---------------------------------------------------------------------------

## Emits bullet_hit on the EventBus Autoload if available.
##
## Uses path-based lookup to find /root/EventBus, matching the pattern
## used by InputSystem. This is robust against EventBus not yet being
## registered as an Autoload during testing.
func _emit_bullet_hit(hit_pos: Vector2, is_skill2: bool) -> void:
	var eb := get_node_or_null("/root/EventBus")
	if eb != null and eb.has_signal("bullet_hit"):
		eb.bullet_hit.emit(hit_pos, is_skill2)

# ---------------------------------------------------------------------------
# SkillSystem duck-typing helpers
# ---------------------------------------------------------------------------

## Returns true if skill_system is assigned and has the required methods
## for skill_2 integration (is_skill2_window_open, consume_skill2).
func _has_skill2_methods() -> bool:
	return (
		skill_system != null
		and skill_system.has_method("is_skill2_window_open")
		and skill_system.has_method("consume_skill2")
	)
