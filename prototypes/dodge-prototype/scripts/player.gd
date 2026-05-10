# PROTOTYPE - NOT FOR PRODUCTION
# Question: Is the dodge system fun?
# Date: 2026-05-08

extends CharacterBody2D

const MOVE_SPEED: float = 300.0
const DODGE_DISTANCE: float = 100.0
const DODGE_DURATION: float = 0.3
const MAX_CHARGES: int = 3
const CHARGE_REGEN_TIME: float = 3.0
const PERFECT_DISTANCE: float = 40.0
const FLASH_DURATION: float = 1.0

var _dodge_charges: int = MAX_CHARGES
var _charge_regen_timer: float = 0.0
var _is_dodging: bool = false
var _dodge_timer: float = 0.0
var _dodge_dir: Vector2 = Vector2.ZERO
var _last_move_dir: Vector2 = Vector2(0, -1)
var _is_invincible: bool = false
var _is_perfect: bool = false

var _overlay: ColorRect
var _charge_label: Label
var _status_label: Label
var _sprite: ColorRect
var _flash_timer: float = 0.0


func _ready() -> void:
	var shape := CircleShape2D.new()
	shape.radius = 16.0
	$CollisionShape2D.shape = shape

	_sprite = ColorRect.new()
	_sprite.size = Vector2(32, 32)
	_sprite.position = Vector2(-16, -16)
	_sprite.color = Color(0.2, 0.6, 0.2, 1.0)
	add_child(_sprite)

	_overlay = ColorRect.new()
	_overlay.size = Vector2(960, 540)
	_overlay.position = Vector2(-480, -270)
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	_charge_label = Label.new()
	_charge_label.position = Vector2(-60, -50)
	_charge_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.9, 1))
	add_child(_charge_label)

	_status_label = Label.new()
	_status_label.position = Vector2(-60, -35)
	_status_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2, 1))
	add_child(_status_label)

	_update_charge_display()


func _physics_process(delta: float) -> void:
	if _is_dodging:
		_process_dodge(delta)
		return

	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_sprite.color = Color(0.2, 0.6, 0.2, 1.0)
			_status_label.text = ""

	if _dodge_charges < MAX_CHARGES:
		_charge_regen_timer += delta
		if _charge_regen_timer >= CHARGE_REGEN_TIME:
			_dodge_charges += 1
			_charge_regen_timer = 0.0
			_update_charge_display()

	var move_dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if move_dir.length() > 0.0:
		_last_move_dir = move_dir.normalized()
	velocity = move_dir.normalized() * MOVE_SPEED
	move_and_slide()

	if Input.is_action_just_pressed("dodge"):
		if _dodge_charges > 0:
			_start_dodge()
		else:
			_status_label.text = "充能不足!"


func _check_perfect_dodge() -> bool:
	var bullets: Array = _find_bullets()
	for bullet in bullets:
		var dist: float = bullet.global_position.distance_to(global_position)
		if dist <= PERFECT_DISTANCE:
			return true
	return false


func _find_bullets() -> Array:
	var bullets: Array = []
	var parent := get_parent()
	if parent == null:
		return bullets
	for child in parent.get_children():
		if child is Area2D and child.has_meta("dir"):
			bullets.append(child)
	return bullets


func _start_dodge() -> void:
	_is_perfect = _check_perfect_dodge()

	_is_dodging = true
	_dodge_timer = DODGE_DURATION
	_dodge_dir = _last_move_dir
	_is_invincible = true

	if _is_perfect:
		Engine.time_scale = 0.2
		_overlay.color = Color(0.2, 0.4, 0.9, 0.3)
		_status_label.text = "极限闪避!"
		_sprite.color = Color(0.2, 0.4, 0.9, 1.0)
	else:
		_dodge_charges -= 1
		_update_charge_display()
		_status_label.text = "闪避"


func _process_dodge(delta: float) -> void:
	_dodge_timer -= delta
	if _dodge_timer <= 0.0:
		_end_dodge()
		return
	velocity = _dodge_dir * (DODGE_DISTANCE / DODGE_DURATION)
	move_and_slide()


func _end_dodge() -> void:
	_is_dodging = false
	_is_invincible = false
	if _is_perfect:
		_is_perfect = false
		Engine.time_scale = 1.0
		_overlay.color = Color(0, 0, 0, 0)
		_flash_timer = FLASH_DURATION
	else:
		_status_label.text = ""
		_sprite.color = Color(0.2, 0.6, 0.2, 1.0)


func take_damage() -> void:
	if _is_invincible:
		return
	_sprite.color = Color(1.0, 0.5, 0.0, 1.0)
	_status_label.text = "被击中!"
	_flash_timer = FLASH_DURATION


func is_invincible() -> bool:
	return _is_invincible


func get_charge_count() -> int:
	return _dodge_charges


func _update_charge_display() -> void:
	_charge_label.text = "充能: " + str(_dodge_charges) + "/" + str(MAX_CHARGES)
