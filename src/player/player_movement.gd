## PlayerMovement -- WASD movement controller using CharacterBody2D.
extends CharacterBody2D

@export var input_system: Node = null
@export var move_speed: float = 300.0

var _cached_velocity: Vector2 = Vector2.ZERO
var _last_move_direction: Vector2 = Vector2.RIGHT

func _physics_process(_delta: float) -> void:
	if input_system == null:
		return
	var state: int = input_system.get_state()
	if state != input_system.STATE_NORMAL and state != input_system.STATE_SKILL_CASTING:
		velocity = Vector2.ZERO
		_cached_velocity = Vector2.ZERO
		move_and_slide()
		return
	var move_axis: Vector2 = input_system.get_move_axis()
	if move_axis.length() > 1.0:
		move_axis = move_axis.normalized()
	if move_axis.length() > 0.01:
		_last_move_direction = move_axis
	velocity = move_axis * move_speed
	_cached_velocity = velocity
	move_and_slide()

func get_last_move_direction() -> Vector2:
	return _last_move_direction

func get_move_velocity() -> Vector2:
	return _cached_velocity
