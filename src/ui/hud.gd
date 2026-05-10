class_name HUD
extends CanvasLayer

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Font size for HUD text.
const FONT_SIZE: int = 8

## Margin from screen edges in pixels.
const MARGIN: int = 8

## Normal opacity (50%).
const OPACITY_NORMAL: float = 0.5

## Info change opacity (85%).
const OPACITY_HIGHLIGHT: float = 0.85

## Skill burst opacity (20%).
const OPACITY_DIM: float = 0.2

## Duration of highlight/dim in seconds.
const OPACITY_TRANSITION_S: float = 0.5

# ---------------------------------------------------------------------------
# Exported references
# ---------------------------------------------------------------------------

@export var wave_manager: Node = null

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

var _wave_label: Label = null
var _kill_label: Label = null

var _last_wave: int = 0
var _last_kills: int = -1

var _target_opacity: float = OPACITY_NORMAL
var _current_opacity: float = OPACITY_NORMAL
var _opacity_tween: Tween = null

# ---------------------------------------------------------------------------
# Node lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	layer = 128  # Above everything

	# Create wave counter label (top-left).
	_wave_label = Label.new()
	_wave_label.position = Vector2(MARGIN, MARGIN)
	_wave_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_wave_label.add_theme_color_override("font_color", Color.WHITE)
	_wave_label.modulate.a = OPACITY_NORMAL
	add_child(_wave_label)

	# Create kill counter label (top-right -- will be positioned in _process).
	_kill_label = Label.new()
	_kill_label.position = Vector2(MARGIN, MARGIN)
	_kill_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_kill_label.add_theme_color_override("font_color", Color.WHITE)
	_kill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_kill_label.modulate.a = OPACITY_NORMAL
	add_child(_kill_label)

	# Connect to skill_1_cast for dimming.
	var eb := get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("skill_1_cast"):
		if not eb.skill_1_cast.is_connected(_on_skill_1_cast):
			eb.skill_1_cast.connect(_on_skill_1_cast)

func _process(_delta: float) -> void:
	_update_labels()
	_position_kill_label()

# ---------------------------------------------------------------------------
# Label updates
# ---------------------------------------------------------------------------

func _update_labels() -> void:
	# Wave counter.
	var current_wave := 0
	if wave_manager != null and wave_manager.has_method("get_current_wave"):
		current_wave = wave_manager.get_current_wave()

	if current_wave != _last_wave:
		_last_wave = current_wave
		_wave_label.text = "WAVE %d" % current_wave
		if current_wave > 0:
			_pulse_highlight()

	# Kill counter.
	var kills := 0
	if GameManager.current_run != null:
		kills = GameManager.current_run.kills

	if kills != _last_kills:
		_last_kills = kills
		_kill_label.text = "x %d" % kills
		_pulse_highlight()

# ---------------------------------------------------------------------------
# Positioning
# ---------------------------------------------------------------------------

func _position_kill_label() -> void:
	if _kill_label == null:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var size := viewport.get_visible_rect().size
	_kill_label.position = Vector2(size.x - MARGIN * 2, MARGIN)

# ---------------------------------------------------------------------------
# Opacity transitions
# ---------------------------------------------------------------------------

## Pulses both labels to highlight opacity, then back to normal.
func _pulse_highlight() -> void:
	_animate_opacity(OPACITY_HIGHLIGHT)
	if _opacity_tween and _opacity_tween.is_valid():
		_opacity_tween.kill()
	_opacity_tween = create_tween()
	_opacity_tween.set_ignore_time_scale(true)
	_opacity_tween.tween_callback(_restore_normal_opacity).set_delay(OPACITY_TRANSITION_S)

## Dims both labels (skill burst).
func _dim_labels() -> void:
	_animate_opacity(OPACITY_DIM)
	if _opacity_tween and _opacity_tween.is_valid():
		_opacity_tween.kill()
	_opacity_tween = create_tween()
	_opacity_tween.set_ignore_time_scale(true)
	_opacity_tween.tween_callback(_restore_normal_opacity).set_delay(OPACITY_TRANSITION_S)

func _restore_normal_opacity() -> void:
	_animate_opacity(OPACITY_NORMAL)

func _animate_opacity(target: float) -> void:
	_current_opacity = target
	if _wave_label:
		var t := create_tween()
		t.set_ignore_time_scale(true)
		t.tween_property(_wave_label, "modulate:a", target, 0.15)
	if _kill_label:
		var t := create_tween()
		t.set_ignore_time_scale(true)
		t.tween_property(_kill_label, "modulate:a", target, 0.15)

# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_skill_1_cast(_pos: Vector2) -> void:
	_dim_labels()
