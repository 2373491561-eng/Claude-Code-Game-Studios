# PROTOTYPE - NOT FOR PRODUCTION
# Question: Is the dodge system fun?
# Date: 2026-05-07

extends CharacterBody2D

const MOVE_SPEED: float = 300.0
const DODGE_SPEED: float = 100.0
const DODGE_DURATION: float = 0.3
const MAX_CHARGES: int = 3
const CHARGE_REGEN_TIME: float = 3.0
const PERFECT_WINDOW: float = 0.1
const INVINCIBILITY_TIME: float = 0.5

var _dodge_charges: int = MAX_CHARGES
var _charge_regen_timer: float = 0.0
var _is_dodging: bool = false
var _dodge_timer: float = 0.0
var _dodge_direction: Vector2 = Vector2.ZERO
var _last_move_dir: Vector2 = Vector2.UP
var _is_invincible: bool = false
var _invincible_timer: float = 0.0
var _is_perfect_dodge: bool = false
var _can_be_perfect_hit: bool = false
var _hit_imminent_timer: float = 0.0

@onready var _screen_overlay: ColorRect = $ScreenOverlay
@onready var _charge_label: Label = $ChargeLabel
@onready var _status_label: Label = $StatusLabel


func _ready() -> void:
	_update_charge_display()


func _physics_process(delta: float) -> void:
	if _is_dodging:
		_process_dodge(delta)
		return

	# Charge regeneration
	if _dodge_charges < MAX_CHARGES:
		_charge_regen_timer += delta
		if _charge_regen_timer >= CHARGE_REGEN_TIME:
			_dodge_charges += 1
			_charge_regen_timer = 0.0
			_update_charge_display()

	# Invincibility
	if _is_invincible:
		_invincible_timer -= delta
		if _invincible_timer <= 0.0:
			_is_invincible = false
		# Flash when about to expire
		modulate = Color.WHITE if _invincible_timer > 0.1 or fmod(_invincible_timer, 0.1) < 0.05 else Color(1, 1, 1, 0.3)

	# Movement
	var move_dir: Vector2 = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if move_dir.length() > 0:
		_last_move_dir = move_dir.normalized()
	velocity = move_dir.normalized() * MOVE_SPEED
	move_and_slide()

	# Perfect hit window timing
	if _can_be_perfect_hit:
		_hit_imminent_timer -= delta
		if _hit_imminent_timer <= 0.0:
			_can_be_perfect_hit = false

	# Dodge input
	if Input.is_action_just_pressed("dodge") and _dodge_charges > 0:
		_start_dodge()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("dodge") and not _is_dodging and _dodge_charges > 0:
		_start_dodge()


func _start_dodge() -> void:
	var is_perfect: bool = _can_be_perfect_hit

	_is_dodging = true
	_dodge_timer = DODGE_DURATION
	_dodge_direction = _last_move_dir
	_is_invincible = true
	_invincible_timer = DODGE_DURATION + INVINCIBILITY_TIME
	modulate = Color(1, 1, 1, 0.6)

	if is_perfect:
		_is_perfect_dodge = true
		Engine.time_scale = 0.2
		_screen_overlay.color = Color(0.2, 0.4, 0.9, 0.3)
		_status_label.text = "极限闪避！"
	else:
		_dodge_charges -= 1
		_update_charge_display()
		_status_label.text = "闪避"


func _process_dodge(delta: float) -> void:
	_dodge_timer -= delta
	if _dodge_timer <= 0.0:
		_end_dodge()
		return
	velocity = _dodge_direction * DODGE_SPEED
	move_and_slide()


func _end_dodge() -> void:
	_is_dodging = false
	modulate = Color.WHITE

	if _is_perfect_dodge:
		_is_perfect_dodge = false
		Engine.time_scale = 1.0
		_screen_overlay.color = Color(0, 0, 0, 0)
		_status_label.text = ""
		# In production: recover HP + grant shield + shorten skill CD + trigger skill_2

	_status_label.text = ""


func notify_hit_imminent(hit_time: float) -> void:
	# Called by enemy bullet when it's about to hit the player
	_can_be_perfect_hit = true
	_hit_imminent_timer = hit_time


func is_invincible() -> bool:
	return _is_invincible


func get_charge_count() -> int:
	return _dodge_charges


func _update_charge_display() -> void:
	_charge_label.text = "闪避充能: " + str(_dodge_charges) + "/" + str(MAX_CHARGES)
