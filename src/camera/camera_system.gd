class_name CameraSystem
extends Camera2D

# ---------------------------------------------------------------------------
# ShakeType enum and configuration (ADR-0009)
# ---------------------------------------------------------------------------

## The 5 camera shake types, triggered by different game events.
enum ShakeType {
	PLAYER_HIT,          ## 3px, 100ms, linear -- player takes damage
	PERFECT_DODGE,       ## 5px, 150ms, ease_out -- perfect dodge executed
	SKILL_BURST,         ## 12px, 300ms, ease_out -- skill 1 cast
	LARGE_ENEMY_APPEAR,  ## 8px, 200ms, ease_in_out -- large enemy spawns
	DEATH,               ## 20px, 500ms, ease_out -- player dies
}

## Shake configuration per ShakeType.
##
## intensity: maximum pixel offset in any direction.
## duration:  total shake duration in seconds (real time).
## decay:     easing curve for intensity falloff over the duration.
const SHAKE_CONFIG: Dictionary = {
	ShakeType.PLAYER_HIT:         {"intensity": 3.0,  "duration": 0.10, "decay": "linear"},
	ShakeType.PERFECT_DODGE:      {"intensity": 5.0,  "duration": 0.15, "decay": "ease_out"},
	ShakeType.SKILL_BURST:        {"intensity": 12.0, "duration": 0.30, "decay": "ease_out"},
	ShakeType.LARGE_ENEMY_APPEAR: {"intensity": 8.0,  "duration": 0.20, "decay": "ease_in_out"},
	ShakeType.DEATH:              {"intensity": 20.0, "duration": 0.50, "decay": "ease_out"},
}

# ---------------------------------------------------------------------------
# Exported configuration -- follow
# ---------------------------------------------------------------------------

## The node the camera follows (typically the player).
@export var follow_target: Node2D = null

## Lerp factor for smooth following. Lower = slower/smoother follow.
## 0.15 means the camera covers 15% of the remaining distance each frame.
@export var follow_speed: float = 0.15

## Maximum camera offset in pixels toward the aim direction.
@export var aim_offset_max: float = 80.0

# ---------------------------------------------------------------------------
# Exported configuration -- zoom
# ---------------------------------------------------------------------------

## Minimum zoom level (closest view). Vector2(1.0, 1.0) = native resolution.
@export var zoom_min: Vector2 = Vector2(1.0, 1.0)

## Maximum zoom level (farthest view). Vector2(3.0, 3.0) = 3x zoom out.
@export var zoom_max: Vector2 = Vector2(3.0, 3.0)

## Default zoom level on game start.
@export var zoom_default: Vector2 = Vector2(2.0, 2.0)

## Zoom step per scroll wheel tick.
@export var zoom_step: float = 0.1

## Duration of the zoom tween transition in seconds.
@export var zoom_transition_duration: float = 0.2

# ---------------------------------------------------------------------------
# Exported configuration -- InputSystem reference
# ---------------------------------------------------------------------------

## Optional reference to InputSystem for aim direction.
## When set, get_aim_direction() is used for the aim offset.
## When null, the system falls back to computing aim direction from
## the follow_target to the global mouse position.
@export var input_system: Node = null

# ---------------------------------------------------------------------------
# State -- follow
# ---------------------------------------------------------------------------

## Current aim offset, interpolated smoothly each frame.
var _current_aim_offset: Vector2 = Vector2.ZERO

# ---------------------------------------------------------------------------
# State -- zoom
# ---------------------------------------------------------------------------

## The active zoom tween, if any. Killed before starting a new zoom transition.
var _zoom_tween: Tween = null

# ---------------------------------------------------------------------------
# State -- shake
# ---------------------------------------------------------------------------

## The ShakeType currently being applied, or -1 if no shake is active.
## Used to compare intensities when a new shake fires.
var _active_shake_type: int = -1

## The active shake tween, if any.
var _shake_tween: Tween = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Initialize zoom to the default.
	zoom = zoom_default
	# Connect to EventBus signals for shake triggers.
	_connect_shake_signals()

## Smoothly follows the target and applies aim offset every idle frame
## for maximum visual smoothness at high refresh rates.
func _process(_delta: float) -> void:
	if follow_target == null:
		return

	_update_follow()
	_update_aim_offset()

# ---------------------------------------------------------------------------
# Follow logic
# ---------------------------------------------------------------------------

## Computes the desired camera position (target position + aim offset) and
## lerps the camera toward it. The result is clamped to scene bounds via
## the built-in Camera2D limit properties.
func _update_follow() -> void:
	var target_pos := follow_target.global_position + _current_aim_offset

	# Lerp toward target.
	global_position = global_position.lerp(target_pos, follow_speed)

	# Explicitly clamp to scene bounds. Camera2D enforces limits internally
	# when position is set, but we add an explicit clamp for safety and
	# to handle edge cases where the lerp might overshoot.
	if limit_left < limit_right:
		global_position.x = clampf(global_position.x, limit_left, limit_right)
	if limit_top < limit_bottom:
		global_position.y = clampf(global_position.y, limit_top, limit_bottom)

# ---------------------------------------------------------------------------
# Aim offset
# ---------------------------------------------------------------------------

## Computes the aim direction (from InputSystem or fallback) and lerps
## _current_aim_offset toward the desired offset. This provides a smooth
## ease-out effect as the player moves the mouse.
func _update_aim_offset() -> void:
	var aim_dir := _get_aim_direction()
	var target_offset := aim_dir * aim_offset_max

	# If the offset would push the camera past scene bounds, reduce it.
	target_offset = _clamp_offset_to_bounds(target_offset)

	# Smooth interpolation of the aim offset for ease-out feel.
	_current_aim_offset = _current_aim_offset.lerp(target_offset, 0.1)

## Returns the normalized aim direction.
##
## Uses InputSystem.get_aim_direction() if the reference is available and
## valid. Falls back to computing the direction from follow_target to the
## global mouse position.
func _get_aim_direction() -> Vector2:
	if input_system != null and is_instance_valid(input_system) and input_system.has_method("get_aim_direction"):
		return input_system.get_aim_direction()

	if follow_target != null:
		var mouse_world := follow_target.get_global_mouse_position()
		var dir := mouse_world - follow_target.global_position
		if dir.length_squared() > 0.001:
			return dir.normalized()

	return Vector2.ZERO

## Reduces the aim offset when it would push the camera outside scene
## bounds. This ensures the player is always visible even when aiming
## toward a boundary.
func _clamp_offset_to_bounds(offset: Vector2) -> Vector2:
	if follow_target == null:
		return offset

	var clamped := offset
	var target_global := follow_target.global_position

	# Check horizontal bounds.
	if limit_left < limit_right:
		if target_global.x + clamped.x < limit_left:
			clamped.x = limit_left - target_global.x
		elif target_global.x + clamped.x > limit_right:
			clamped.x = limit_right - target_global.x

	# Check vertical bounds.
	if limit_top < limit_bottom:
		if target_global.y + clamped.y < limit_top:
			clamped.y = limit_top - target_global.y
		elif target_global.y + clamped.y > limit_bottom:
			clamped.y = limit_bottom - target_global.y

	return clamped

# ---------------------------------------------------------------------------
# Zoom
# ---------------------------------------------------------------------------

## Processes mouse wheel input for zoom in / zoom out.
##
## Scroll up:   zoom out (increase zoom vector, see more).
## Scroll down: zoom in  (decrease zoom vector, see less).
##
## The zoom target is clamped between zoom_min and zoom_max, and the
## transition is animated via a Tween over zoom_transition_duration seconds
## with ease-in-out for a smooth feel.
func _process_zoom_input() -> void:
	# Mouse wheel up (zoom out): button_index 4 on some platforms,
	# BUTTON_WHEEL_UP on others.
	if Input.is_action_just_pressed("zoom_in") or Input.is_action_just_released("ui_accept"):
		# Fallback: direct mouse wheel check.
		pass

	# Use direct Input checks for scroll wheel, since we want continuous
	# zoom control regardless of Input Map configuration.
	var wheel_up := Input.is_action_just_pressed(&"zoom_in")
	var wheel_down := Input.is_action_just_pressed(&"zoom_out")

	if not wheel_up and not wheel_down:
		return

	var target_zoom := zoom
	if wheel_up:
		target_zoom += Vector2(zoom_step, zoom_step)
	elif wheel_down:
		target_zoom -= Vector2(zoom_step, zoom_step)

	target_zoom = target_zoom.clamp(zoom_min, zoom_max)
	_apply_zoom_transition(target_zoom)

## Smoothly transitions the camera zoom to [param target_zoom] over
## zoom_transition_duration seconds using a Tween with ease-in-out.
func _apply_zoom_transition(target_zoom: Vector2) -> void:
	# Kill any in-progress zoom tween.
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()

	_zoom_tween = create_tween()
	_zoom_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_zoom_tween.tween_property(self, "zoom", target_zoom, zoom_transition_duration)

# ---------------------------------------------------------------------------
# Camera shake (ADR-0009)
# ---------------------------------------------------------------------------

## Connects to EventBus signals that trigger camera shake.
##
## Uses get_node_or_null() for safe lookup (EventBus may not be registered
## in all environments) and has_signal() guards for partial EventBus
## implementations.
func _connect_shake_signals() -> void:
	var eb := get_node_or_null("/root/EventBus")
	if eb == null:
		return

	# player_hit -> PLAYER_HIT
	if eb.has_signal("player_hit"):
		eb.player_hit.connect(_on_shake_player_hit)

	# dodge_perfect -> PERFECT_DODGE
	if eb.has_signal("dodge_perfect"):
		eb.dodge_perfect.connect(_on_shake_perfect_dodge)

	# skill_1_cast -> SKILL_BURST
	if eb.has_signal("skill_1_cast"):
		eb.skill_1_cast.connect(_on_shake_skill_burst)

	# player_death -> DEATH
	if eb.has_signal("player_death"):
		eb.player_death.connect(_on_shake_player_death)

# ---------------------------------------------------------------------------
# Shake signal callbacks -- each maps an EventBus signal to a ShakeType
# ---------------------------------------------------------------------------

func _on_shake_player_hit(_damage: float, _source_pos: Vector2) -> void:
	_trigger_shake(ShakeType.PLAYER_HIT)

func _on_shake_perfect_dodge(_pos: Vector2, _charge_count: int) -> void:
	_trigger_shake(ShakeType.PERFECT_DODGE)

func _on_shake_skill_burst(_pos: Vector2) -> void:
	_trigger_shake(ShakeType.SKILL_BURST)

func _on_shake_player_death(_stats: Dictionary) -> void:
	_trigger_shake(ShakeType.DEATH)

# ---------------------------------------------------------------------------
# Shake execution
# ---------------------------------------------------------------------------

## Triggers a camera shake of the specified [param type].
##
## If a shake is already active with a higher or equal intensity, the new
## shake is ignored (strongest-wins policy, per ADR-0009). Otherwise, any
## running shake tween is killed and a new shake cycle begins.
##
## The shake generates random-direction offsets via tween_method(), which
## calls _apply_shake_offset(t) repeatedly over the shake duration. The
## intensity decays from full to zero as t goes from 0.0 to 1.0.
##
## All shake tweens use set_ignore_time_scale(true) so shake timing is
## unaffected by Engine.time_scale changes (ADR-0001).
func _trigger_shake(type: ShakeType) -> void:
	var cfg: Dictionary = SHAKE_CONFIG[type]
	var new_intensity: float = cfg["intensity"]

	# Strongest-wins policy: if the current shake has higher or equal
	# intensity, do not interrupt it.
	if _active_shake_type != -1:
		var current_cfg: Dictionary = SHAKE_CONFIG[_active_shake_type]
		if current_cfg["intensity"] >= new_intensity:
			return

	# Kill any running shake tween.
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
		_shake_tween = null

	_active_shake_type = type

	var duration: float = cfg["duration"]
	var decay: String = cfg["decay"]

	_shake_tween = create_tween()
	_shake_tween.set_ignore_time_scale(true)

	# Map decay type to Tween transition/ease.
	var trans_type := Tween.TRANS_LINEAR
	var ease_type := Tween.EASE_IN
	match decay:
		"ease_out":
			trans_type = Tween.TRANS_SINE
			ease_type = Tween.EASE_OUT
		"ease_in_out":
			trans_type = Tween.TRANS_SINE
			ease_type = Tween.EASE_IN_OUT
		"linear", _:
			trans_type = Tween.TRANS_LINEAR
			ease_type = Tween.EASE_IN

	# tween_method calls _apply_shake_offset(t) with t from 0.0 to 1.0
	# over the shake duration. At t=0: full intensity. At t=1: zero intensity.
	_shake_tween.tween_method(
		_apply_shake_offset.bind(new_intensity),
		0.0,
		1.0,
		duration
	).set_trans(trans_type).set_ease(ease_type)

	# When the shake completes, reset offset and state.
	_shake_tween.tween_callback(_on_shake_complete)

## Called repeatedly by the shake tween with [param t] from 0.0 to 1.0.
##
## Applies a random offset to the camera scaled by the remaining intensity
## at this point in the shake. [param full_intensity] is the starting
## intensity; the current effective intensity is full_intensity * (1.0 - t).
##
## [param t]: Normalized progress through the shake (0.0 = start, 1.0 = end).
## [param full_intensity]: The maximum pixel offset for this shake type.
func _apply_shake_offset(t: float, full_intensity: float) -> void:
	var current_intensity := full_intensity * (1.0 - t)
	offset = Vector2(
		randf_range(-current_intensity, current_intensity),
		randf_range(-current_intensity, current_intensity)
	)

## Called when the shake tween completes. Resets the camera offset to zero
## and clears the active shake state so weaker shakes can play again.
func _on_shake_complete() -> void:
	offset = Vector2.ZERO
	_active_shake_type = -1
	_shake_tween = null
