# PROTOTYPE - NOT FOR PRODUCTION
# Question: Can the player dodge enemy attacks and feel the perfect dodge timing?
# Date: 2026-05-07

extends CharacterBody2D

const MOVE_SPEED: float = 120.0
const SHOOT_INTERVAL: float = 2.0
const BULLET_SPEED: float = 200.0
const KEEP_DISTANCE: float = 200.0

var _shoot_timer: float = 0.0
var _player_ref: Node2D = null

@onready var _bullet_scene: PackedScene = preload("res://scripts/bullet.tscn")
@onready var _shoot_pos: Marker2D = $ShootPos


func _ready() -> void:
	_shoot_timer = randf_range(0.5, 1.5)


func _physics_process(delta: float) -> void:
	if _player_ref == null:
		return

	var to_player: Vector2 = _player_ref.global_position - global_position
	var dist: float = to_player.length()

	# Keep distance
	if dist < KEEP_DISTANCE - 20:
		velocity = -to_player.normalized() * MOVE_SPEED
	elif dist > KEEP_DISTANCE + 20:
		velocity = to_player.normalized() * MOVE_SPEED
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	# Shoot
	_shoot_timer -= delta
	if _shoot_timer <= 0.0:
		_shoot()
		_shoot_timer = SHOOT_INTERVAL


func _shoot() -> void:
	if _player_ref == null:
		return
	var bullet: Area2D = _bullet_scene.instantiate()
	bullet.global_position = global_position
	bullet.direction = (_player_ref.global_position - global_position).normalized()
	bullet.speed = BULLET_SPEED
	get_parent().add_child(bullet)


func set_player(p: Node2D) -> void:
	_player_ref = p
