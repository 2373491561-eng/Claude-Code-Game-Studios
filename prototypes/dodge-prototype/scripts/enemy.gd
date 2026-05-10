# PROTOTYPE - NOT FOR PRODUCTION
# Date: 2026-05-08

extends CharacterBody2D

const MOVE_SPEED: float = 100.0
const SHOOT_INTERVAL: float = 2.0
const BULLET_SPEED: float = 200.0
const KEEP_DIST: float = 200.0

var _shoot_timer: float = 1.0
var _player: Node2D = null
var _sprite: ColorRect


func _ready() -> void:
	var shape := CircleShape2D.new()
	shape.radius = 24.0
	$CollisionShape2D.shape = shape

	_sprite = ColorRect.new()
	_sprite.size = Vector2(48, 48)
	_sprite.position = Vector2(-24, -24)
	_sprite.color = Color(0.7, 0.2, 0.2, 1.0)
	add_child(_sprite)


func set_player(p: Node2D) -> void:
	_player = p


func _physics_process(delta: float) -> void:
	if _player == null:
		return

	var to_player: Vector2 = _player.global_position - global_position
	var dist: float = to_player.length()

	if dist < KEEP_DIST - 30:
		velocity = -to_player.normalized() * MOVE_SPEED
	elif dist > KEEP_DIST + 30:
		velocity = to_player.normalized() * MOVE_SPEED
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	_shoot_timer -= delta
	if _shoot_timer <= 0.0:
		_shoot()
		_shoot_timer = SHOOT_INTERVAL


func _shoot() -> void:
	if _player == null:
		return

	var bullet := Area2D.new()
	bullet.global_position = global_position

	var dir: Vector2 = (_player.global_position - global_position).normalized()

	var b_shape := CircleShape2D.new()
	b_shape.radius = 4.0
	var b_collision := CollisionShape2D.new()
	b_collision.shape = b_shape
	bullet.add_child(b_collision)

	var b_sprite := ColorRect.new()
	b_sprite.size = Vector2(8, 8)
	b_sprite.position = Vector2(-4, -4)
	b_sprite.color = Color(1.0, 0.4, 0.0, 1.0)
	bullet.add_child(b_sprite)

	bullet.set_meta("dir", dir)
	bullet.set_meta("speed", BULLET_SPEED)
	bullet.set_meta("life", 3.0)

	bullet.body_entered.connect(_on_bullet_hit.bind(bullet))

	get_parent().add_child(bullet)


func _on_bullet_hit(body: Node2D, bullet: Area2D) -> void:
	if body == self:
		return

	if body.has_method("is_invincible") and body.is_invincible():
		bullet.queue_free()
		return

	if body.has_method("take_damage"):
		body.take_damage()

	if is_instance_valid(bullet):
		bullet.queue_free()
