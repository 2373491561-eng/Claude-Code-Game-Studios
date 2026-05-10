## PlayerMovement -- WASD movement controller using CharacterBody2D.
##
## Reads move input from InputSystem every physics frame, normalizes diagonal
## input to prevent faster diagonal movement, and applies velocity via
## move_and_slide(). Movement is locked during DODGING, PAUSED, and DEAD states.
##
## Movement and shooting are independent -- this class only handles movement.
## Shooting is managed by ShootingSystem.
##
## Usage:
##   [codeblock]
##   # In game.tscn: add PlayerMovement as a child of the Player scene.
##   # Wire the InputSystem reference:
##   $Player/PlayerMovement.input_system = $InputSystem
##
##   # Other systems can query movement state:
##   var move_dir := player_movement.get_last_move_direction()
##   var speed := player_movement.velocity()
##   [/codeblock]
class_name PlayerMovement extends CharacterBody2D

# ---------------------------------------------------------------------------
# Exported configuration
# ---------------------------------------------------------------------------

## Reference to the InputSystem node (owned by game.tscn).
## Set by game.tscn after instancing the player.
@export var input_system: InputSystem = null

## Movement speed in pixels per second.
@export var move_speed: float = 300.0

# ---------------------------------------------------------------------------
# Per-frame cached state
# ---------------------------------------------------------------------------

## Cached velocity from the last physics frame.
## Exposed via velocity() so other systems can query current speed/direction.
var _velocity: Vector2 = Vector2.ZERO

## Cached last non-zero move direction.
## Updated whenever the move axis is non-zero. Persists across frames where
## the player releases all keys, so systems can still know which direction
## the player was last moving.
var _last_move_direction: Vector2 = Vector2.ZERO

# ---------------------------------------------------------------------------
# Node lifecycle
# ---------------------------------------------------------------------------

## Reads move input from InputSystem, normalizes diagonal input, computes
## velocity, and calls move_and_slide().
##
## Movement is locked (velocity forced to Vector2.ZERO) when the input state
## is not NORMAL and not SKILL_CASTING. This covers DODGING, PAUSED, and DEAD.
##
## Edge cases handled:
##   - Diagonal normalization: W+D produces 300 px/s, not ~424 px/s.
##   - Instant direction reverse: W to S changes velocity immediately with
##     no transition delay (CharacterBody2D has no inertia by default).
func _physics_process(_delta: float) -> void:
	# Guard: no InputSystem assigned yet (graceful degradation).
	if input_system == null:
		return

	# Movement lock: only NORMAL and SKILL_CASTING states allow movement.
	# DODGING, PAUSED, and DEAD force velocity to zero.
	var state: int = input_system.get_state()
	if state != InputSystem.STATE_NORMAL and state != InputSystem.STATE_SKILL_CASTING:
		velocity = Vector2.ZERO
		_velocity = Vector2.ZERO
		move_and_slide()
		return

	var move_axis: Vector2 = input_system.get_move_axis()

	# Diagonal normalization: clamp vector length to 1.0 so diagonal movement
	# (e.g., W+D) does not produce 424 px/s when move_speed is 300.
	if move_axis.length() > 1.0:
		move_axis = move_axis.normalized()

	# Cache last non-zero direction for external queries.
	if move_axis != Vector2.ZERO:
		_last_move_direction = move_axis

	velocity = move_axis * move_speed
	_velocity = velocity
	move_and_slide()

# ---------------------------------------------------------------------------
# Public getters
# ---------------------------------------------------------------------------

## Returns the last non-zero move direction.
##
## This is the most recent move axis input that was not Vector2.ZERO.
## Useful for systems that need to know which way the player is facing
## even when they have stopped moving (e.g., aim fallback direction).
##
## Returns Vector2.RIGHT if never moved (default facing right).
func get_last_move_direction() -> Vector2:
	if _last_move_direction == Vector2.ZERO:
		return Vector2.RIGHT
	return _last_move_direction

## Returns the velocity vector from the most recent physics frame.
##
## This is the post-normalization velocity that was applied via
## move_and_slide(). Magnitude is at most move_speed.
func velocity() -> Vector2:
	return _velocity
