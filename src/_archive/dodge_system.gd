class_name DodgeSystem
extends Node2D

# ---------------------------------------------------------------------------
# Constants -- all gameplay values are data-driven (tuning knobs from GDD)
# ---------------------------------------------------------------------------

## Maximum number of dodge charges.
const MAX_CHARGE: float = 3.0

## Time in seconds to regenerate one full charge.
const CHARGE_REGEN_TIME: float = 3.0

## Distance in pixels the player travels during a dodge.
const DODGE_DISTANCE: float = 100.0

## Duration of a dodge in milliseconds (real time via Time.get_ticks_msec()).
## Invincibility frames persist for the full duration even if displacement
## is cut short by a wall collision.
const DODGE_DURATION_MS: int = 300

## Maximum distance in pixels for perfect dodge detection.
## Any enemy attack within this radius at the moment dodge is pressed
## triggers a perfect dodge instead of a normal dodge.
const PERFECT_DISTANCE: float = 40.0

## Time scale value during perfect dodge slowdown.
const TIME_SCALE_SLOW: float = 0.2

## Duration of time scale recovery in milliseconds (real time).
## After a perfect dodge, Engine.time_scale recovers from 0.2 to 1.0
## over this duration using an ease-out-expo curve.
const TS_RECOVERY_DURATION_MS: int = 200

## Dodge result types consumed by SkillSystem.
const DODGE_RESULT_NONE: int = 0
const DODGE_RESULT_NORMAL: int = 1
const DODGE_RESULT_PERFECT: int = 2

## Post-dodge overlap resolution: maximum spiral search radius in pixels.
const POST_DODGE_SEARCH_RADIUS: float = 200.0

## Post-dodge overlap resolution: step size for spiral search in pixels.
const POST_DODGE_SEARCH_STEP: float = 50.0

## Post-dodge overlap resolution: number of directions to check per radius.
const POST_DODGE_DIRECTIONS: int = 8

## Minimum time scale safeguard to prevent soft-locks.
const MIN_TIME_SCALE: float = 0.01

# ---------------------------------------------------------------------------
# Exported references
# ---------------------------------------------------------------------------

## Reference to the InputSystem node (owned by game.tscn).
## Set by game.tscn after instancing the player.
@export var input_system: InputSystem = null

## Reference to the PlayerMovement node (CharacterBody2D).
## Dodge displacement is applied through this node.
@export var player_movement: PlayerMovement = null

## Reference to the EnemyManager node. Optional -- used for perfect dodge
## detection. If not assigned, perfect dodge will never trigger.
@export var enemy_manager: Node = null

## Collision layer bit used by enemies. During dodge, this layer is
## temporarily removed from the player's collision_mask so the player
## can pass through enemies.
@export var enemy_collision_layer_bit: int = 4  # layer 3 = bit 2 = value 4

## Collision layer bit used by walls/obstacles. Used for displacement
## collision tests.
@export var wall_collision_layer_bit: int = 1  # layer 1 = bit 0 = value 1

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

## Current charge count as a float. floor(_charge) is the number of
## available dodges shown to the player.
var _charge: float = MAX_CHARGE

## True while a dodge displacement animation is active (300ms).
var _is_dodging: bool = false

## Timestamp (Time.get_ticks_msec()) when the current dodge began.
var _dodge_start_ms: int = 0

## The normalized direction of the current dodge displacement.
var _dodge_direction: Vector2 = Vector2.RIGHT

## The world position of the player when the current dodge began.
var _dodge_start_pos: Vector2 = Vector2.ZERO

## True while the player has invincibility from a dodge (300ms).
## Invincibility is NOT affected by displacement being cut short.
var _is_invincible: bool = false

## True when a perfect dodge is active (displacement phase + recovery phase).
## Used to prevent stacked perfect dodge triggers.
var _is_perfect_dodge_active: bool = false

## Timestamp when time scale recovery began (or 0 if not active).
var _ts_recovery_start_ms: int = 0

## True while the time scale recovery curve is running.
var _ts_recovery_active: bool = false

## Stores the result of the most recent dodge for SkillSystem consumption.
var _last_dodge_result: int = DODGE_RESULT_NONE

## Stores the charge_count (floor(_charge)) at the moment of the last dodge.
var _last_dodge_charge_at_trigger: int = 0

## Cached original collision_mask of the player, restored after dodge.
var _original_collision_mask: int = 0

## Cached reference to the physics world's direct space state.
## Lazy-initialized since it requires the node to be in the tree.
var _space_state: PhysicsDirectSpaceState2D = null

# ---------------------------------------------------------------------------
# Public getters
# ---------------------------------------------------------------------------

## Returns true while the player is invincible from a dodge.
##
## Invincibility lasts the full DODGE_DURATION_MS (300ms) even if the
## displacement is cut short by a wall collision. Damage systems must
## check this before applying damage.
func is_invincible() -> bool:
	return _is_invincible

## Returns the number of available dodge charges as an integer.
##
## Uses floor() so charge=0.6 returns 0 (no dodge available).
## Used by SkillSystem for CD acceleration and by Diegetic UI for
## charge indicator display.
func get_charge_count() -> int:
	return floori(_charge)

## Returns true while a dodge displacement is active.
##
## This covers both normal and perfect dodge displacement phases.
## The time scale recovery phase (after perfect dodge displacement ends)
## is NOT included -- during recovery, is_dodging() returns false.
func is_dodging() -> bool:
	return _is_dodging

## Returns true if the current dodge was a perfect dodge.
##
## Use this to check whether the currently active dodge (if any) or
## the just-completed dodge was triggered by a perfect dodge.
func is_perfect_dodge_active() -> bool:
	return _is_perfect_dodge_active

## Returns true if time scale is currently being recovered from a
## perfect dodge.
func is_time_scale_recovering() -> bool:
	return _ts_recovery_active

## Consumes and returns the result of the most recent dodge trigger.
##
## Returns a Dictionary with keys:
##   - "type": int (DODGE_RESULT_NORMAL or DODGE_RESULT_PERFECT)
##   - "charge": int (charge_count at time of dodge trigger)
##
## After this call, the stored result is cleared. This is designed
## to be consumed by SkillSystem each physics frame.
func consume_last_dodge_result() -> Dictionary:
	var result := {
		"type": _last_dodge_result,
		"charge": _last_dodge_charge_at_trigger,
	}
	_last_dodge_result = DODGE_RESULT_NONE
	_last_dodge_charge_at_trigger = 0
	return result

# ---------------------------------------------------------------------------
# Node lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Cache the original collision mask for restoration after dodge.
	if player_movement != null:
		_original_collision_mask = player_movement.collision_mask

func _physics_process(_delta: float) -> void:
	# Guard: no InputSystem assigned yet.
	if input_system == null:
		return

	# Guard: no PlayerMovement assigned yet.
	if player_movement == null:
		return

	# Cache space state for collision queries.
	if _space_state == null and is_inside_tree():
		_space_state = get_world_2d().direct_space_state

	# ----------------------------------------------------------------
	# Step 1: Charge regeneration (paused during dodge)
	# Uses get_physics_process_delta_time() for frame-rate independence
	# and immunity to Engine.time_scale.
	# ----------------------------------------------------------------
	if not _is_dodging:
		_charge += get_physics_process_delta_time() / CHARGE_REGEN_TIME
		_charge = clampf(_charge, 0.0, MAX_CHARGE)

	# ----------------------------------------------------------------
	# Step 2: Time scale recovery (perfect dodge aftermath)
	# ----------------------------------------------------------------
	if _ts_recovery_active:
		_update_time_scale_recovery()

	# ----------------------------------------------------------------
	# Step 3: Dodge displacement (if actively dodging)
	# ----------------------------------------------------------------
	if _is_dodging:
		_apply_dodge_displacement()
		return

	# ----------------------------------------------------------------
	# Step 4: Check for dodge trigger (only when not already dodging)
	# ----------------------------------------------------------------
	var dodge_pressed: bool = input_system.is_dodge_just_pressed() or input_system.consume_dodge_buffer()

	if not dodge_pressed:
		return

	# Must have at least 1 charge (floor check) to execute a dodge.
	if floori(_charge) < 1:
		return

	# Determine if this is a perfect dodge.
	var is_perfect := _check_perfect_dodge(player_movement.global_position)

	# Perfect dodge during an existing perfect dodge (recovery phase) is
	# ignored to prevent time scale stacking.
	if is_perfect and _is_perfect_dodge_active:
		return

	# Execute the dodge.
	_execute_dodge(is_perfect)

# ---------------------------------------------------------------------------
# Dodge execution
# ---------------------------------------------------------------------------

## Executes a dodge (normal or perfect).
##
## [param is_perfect]: true if a perfect dodge was detected.
##
## Normal dodge: consumes 1 charge, displaces player, grants 300ms
## invincibility. Perfect dodge: does NOT consume charge, additionally
## triggers time scale slowdown and recovery.
func _execute_dodge(is_perfect: bool) -> void:
	# --- Determine dodge direction ---
	var move_axis := input_system.get_move_axis()
	if move_axis != Vector2.ZERO:
		_dodge_direction = move_axis.normalized()
	else:
		_dodge_direction = player_movement.get_last_move_direction()
		# If never moved (sentinel zero vector), dodge away from aim direction.
		if _dodge_direction == Vector2.ZERO:
			var aim_dir := input_system.get_aim_direction()
			if aim_dir != Vector2.ZERO:
				_dodge_direction = -aim_dir
			else:
				_dodge_direction = Vector2.RIGHT

	# --- Charge handling ---
	var charge_at_trigger := floori(_charge)

	if is_perfect:
		# Perfect dodge does NOT consume charge.
		_last_dodge_result = DODGE_RESULT_PERFECT
		_last_dodge_charge_at_trigger = charge_at_trigger
	else:
		# Normal dodge consumes 1 charge.
		_charge -= 1.0
		_last_dodge_result = DODGE_RESULT_NORMAL
		_last_dodge_charge_at_trigger = charge_at_trigger

	# --- Begin dodge ---
	_is_dodging = true
	_is_invincible = true
	_dodge_start_ms = Time.get_ticks_msec()
	_dodge_start_pos = player_movement.global_position

	# Remove enemy collision layer so the player can pass through enemies.
	if player_movement != null:
		player_movement.collision_mask &= ~enemy_collision_layer_bit

	# Set input state to DODGING to lock movement, shooting, and new dodges.
	input_system.set_state(InputSystem.STATE_DODGING)

	# --- Perfect dodge specifics ---
	if is_perfect:
		_is_perfect_dodge_active = true
		_ts_recovery_active = false  # will start when displacement ends

		# Time scale slowdown only if charge >= 1.
		if charge_at_trigger >= 1:
			Engine.time_scale = maxf(TIME_SCALE_SLOW, MIN_TIME_SCALE)
			_ts_recovery_start_ms = 0  # set when displacement ends

		# Emit perfect dodge event.
		_emit_dodge_perfect()

	else:
		# Emit normal dodge event.
		_emit_dodge_normal()

# ---------------------------------------------------------------------------
# Dodge displacement (per-physics-frame step)
# ---------------------------------------------------------------------------

## Applies one physics frame worth of dodge displacement.
##
## Uses get_physics_process_delta_time() for the step calculation so that
## displacement speed is unaffected by Engine.time_scale. Wall collisions
## cut displacement short, but invincibility stays for the full 300ms.
##
## The displacement is applied directly to the player_movement node's
## global_position. A ray query is used to detect wall collisions along
## the displacement path.
func _apply_dodge_displacement() -> void:
	var elapsed_ms := Time.get_ticks_msec() - _dodge_start_ms
	var progress := clampf(elapsed_ms / float(DODGE_DURATION_MS), 0.0, 1.0)

	var target_pos: Vector2 = _dodge_start_pos + _dodge_direction * DODGE_DISTANCE * progress
	var current_pos: Vector2 = player_movement.global_position
	var step: Vector2 = target_pos - current_pos

	if step.length_squared() < 0.01:
		# Negligible step -- all displacement is done (or blocked).
		# Check if dodge duration has expired.
		if elapsed_ms >= DODGE_DURATION_MS:
			_end_dodge()
		return

	# Test for wall collision along the step.
	if _space_state != null:
		var query := PhysicsRayQueryParameters2D.create(current_pos, target_pos)
		query.collision_mask = wall_collision_layer_bit
		# Exclude the player's own body from the ray query.
		query.exclude = [player_movement.get_rid()]
		var result := _space_state.intersect_ray(query)

		if not result.is_empty():
			# Wall hit -- stop at collision point with a small offset.
			var hit_point: Vector2 = result.position
			var safe_pos := hit_point - _dodge_direction * 2.0
			player_movement.global_position = safe_pos
			# Displacement is blocked but dodge continues (invincibility stays).
			# We leave _is_dodging=true and wait for the timer to expire.
			if elapsed_ms >= DODGE_DURATION_MS:
				_end_dodge()
			return

	# No wall collision -- apply the full step.
	player_movement.global_position = target_pos

	# Check if dodge duration has expired.
	if elapsed_ms >= DODGE_DURATION_MS:
		_end_dodge()

# ---------------------------------------------------------------------------
# Dodge end and post-dodge resolution
# ---------------------------------------------------------------------------

## Ends the current dodge: restores collision, clears flags, resolves
## post-dodge overlap, and sets input state back to NORMAL.
func _end_dodge() -> void:
	_is_dodging = false
	_is_invincible = false

	# Restore the original collision mask.
	if player_movement != null:
		player_movement.collision_mask = _original_collision_mask

	# Resolve post-dodge overlap (spiral search for non-overlapping position).
	if get_charge_count() < 1:
		pass  # SkillSystem will read charge drop
	_post_dodge_overlap_resolution()

	# Start time scale recovery if this was a perfect dodge with charge >= 1.
	if _is_perfect_dodge_active and _last_dodge_charge_at_trigger >= 1:
		_ts_recovery_start_ms = Time.get_ticks_msec()
		_ts_recovery_active = true
	# Perfect dodge is no longer in displacement phase.
	if _is_perfect_dodge_active and _last_dodge_charge_at_trigger < 1:
		# charge=0 perfect dodge -- no time scale, no recovery.
		_is_perfect_dodge_active = false

	# Restore input state to NORMAL.
	if input_system != null:
		input_system.set_state(InputSystem.STATE_NORMAL)

# ---------------------------------------------------------------------------
# Post-dodge overlap resolution
# ---------------------------------------------------------------------------

## After a dodge ends, the player may be inside an enemy's collision volume
## (since enemies were pass-through during dodge). This method searches
## outward from the player's position in a spiral pattern to find a
## non-overlapping position.
##
## Spiral search: 8 directions, steps of POST_DODGE_SEARCH_STEP (50px),
## up to POST_DODGE_SEARCH_RADIUS (200px). If no clear position is found
## within the search radius, the player takes 1 damage and is force-pushed
## to the last checked position.
func _post_dodge_overlap_resolution() -> void:
	if player_movement == null:
		return

	var start_pos: Vector2 = player_movement.global_position
	var best_pos := start_pos
	var found_clear := false

	# Spiral search: for each radius step, check 8 directions.
	var max_rings := ceili(POST_DODGE_SEARCH_RADIUS / POST_DODGE_SEARCH_STEP)

	for ring in range(1, max_rings + 1):
		var radius := float(ring) * POST_DODGE_SEARCH_STEP
		var angle_step := TAU / float(POST_DODGE_DIRECTIONS)

		for dir_idx in range(POST_DODGE_DIRECTIONS):
			var angle := float(dir_idx) * angle_step
			var offset := Vector2(cos(angle), sin(angle)) * radius
			var test_pos: Vector2 = start_pos + offset

			# Quick bounds check: ensure we don't go outside reasonable world bounds.
			# We check if the position is valid by testing a tiny move.
			if _space_state != null:
				var query := PhysicsRayQueryParameters2D.create(start_pos, test_pos)
				query.collision_mask = wall_collision_layer_bit
				query.exclude = [player_movement.get_rid()]
				var result := _space_state.intersect_ray(query)
				if result.is_empty():
					# No wall between start and test_pos -- candidate.
					best_pos = test_pos
					found_clear = true
					break

		if found_clear:
			break

	if found_clear:
		player_movement.global_position = best_pos
	else:
		# Fallback: take 1 damage and force-push to best found position.
		# The DamageHealthSystem will handle the damage event.
		player_movement.global_position = best_pos
		# Emit a damage event if EventBus is available.
		var eb := get_node_or_null("/root/EventBus")
		if eb and eb.has_signal("player_hit"):
			eb.player_hit.emit(1, best_pos)

# ---------------------------------------------------------------------------
# Perfect dodge detection
# ---------------------------------------------------------------------------

## Checks whether any enemy attack is within PERFECT_DISTANCE of the player.
##
## Queries EnemyManager.get_all_attack_positions() using distance_squared_to()
## for efficient O(N) distance comparison. Uses method_exists guard since
## EnemyManager may not be implemented yet.
##
## Returns true if at least one attack position is within 40px of the player.
## If multiple attacks are in range, still returns true (no stacking).
##
## [param player_pos]: the player's current world position.
func _check_perfect_dodge(player_pos: Vector2) -> bool:
	# Guard: EnemyManager may not exist or may not have the method yet.
	if enemy_manager == null:
		return false

	if not enemy_manager.has_method("get_all_attack_positions"):
		return false

	var attacks: Array = enemy_manager.get_all_attack_positions()
	if attacks.is_empty():
		return false

	var nearest_dist_sq := PERFECT_DISTANCE * PERFECT_DISTANCE
	var found := false

	for pos in attacks:
		if pos is Vector2:
			var dist_sq := player_pos.distance_squared_to(pos as Vector2)
			if dist_sq < nearest_dist_sq:
				nearest_dist_sq = dist_sq
				found = true

	return found

# ---------------------------------------------------------------------------
# Time scale recovery
# ---------------------------------------------------------------------------

## Updates Engine.time_scale using the ease-out-expo recovery curve.
##
## f(t) = clamp(1.0 - 0.8 * exp(-6 * t), 0.2, 1.0)
## t from 0->1 over TS_RECOVERY_DURATION_MS (200ms).
## HARD CLAMP at t >= 1.0 to ensure time_scale returns to exactly 1.0.
func _update_time_scale_recovery() -> void:
	var elapsed_ms := Time.get_ticks_msec() - _ts_recovery_start_ms
	var t := clampf(elapsed_ms / float(TS_RECOVERY_DURATION_MS), 0.0, 1.0)

	var ts: float
	if t >= 1.0:
		# Hard clamp: ensure time_scale returns to exactly 1.0.
		ts = 1.0
		_ts_recovery_active = false
		_is_perfect_dodge_active = false
	else:
		# f(t) = clamp(1.0 - 0.8 * exp(-6*t), 0.2, 1.0)
		ts = clampf(1.0 - 0.8 * exp(-6.0 * t), TIME_SCALE_SLOW, 1.0)

	Engine.time_scale = maxf(ts, MIN_TIME_SCALE)

# ---------------------------------------------------------------------------
# EventBus signal emission helpers
# ---------------------------------------------------------------------------

## Emits dodge_normal on the EventBus Autoload if available.
##
## Signal: dodge_normal(pos: Vector2, direction: Vector2)
## Consumed by: VFX (dust puff, landing ripple), Audio (whoosh), Camera.
func _emit_dodge_normal() -> void:
	var eb := get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("dodge_normal"):
		eb.dodge_normal.emit(player_movement.global_position, _dodge_direction)

## Emits dodge_perfect on the EventBus Autoload if available.
##
## Signal: dodge_perfect(pos: Vector2, charge_count: int)
## Consumed by: VFX (cold filter, edge sharpening, afterimage),
## Audio (time freeze sound, pitch shift), Camera (shake),
## SkillSystem (skill_2 window, CD reduction).
func _emit_dodge_perfect() -> void:
	var eb := get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("dodge_perfect"):
		eb.dodge_perfect.emit(player_movement.global_position, _last_dodge_charge_at_trigger)
