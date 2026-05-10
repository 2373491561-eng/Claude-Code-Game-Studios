# PROTOTYPE - NOT FOR PRODUCTION
# Date: 2026-05-07

extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 200.0
var _lifetime: float = 3.0


func _ready() -> void:
	body_entered.connect(_on_hit)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()


func _on_hit(body: Node2D) -> void:
	if body.has_method("is_invincible") and body.is_invincible():
		queue_free()
		return

	if body.has_method("notify_hit_imminent"):
		# Notify player ~100ms ahead for perfect dodge window
		var hit_time: float = (global_position - body.global_position).length() / speed
		if hit_time < 0.15:
			body.notify_hit_imminent(hit_time)

	if body.has_method("take_damage"):
		body.take_damage()
	queue_free()
