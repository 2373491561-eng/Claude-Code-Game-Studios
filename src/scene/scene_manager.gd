## SceneManager -- Autoload that handles scene transitions with fade effects.
##
## Manages the 3-scene flow: MAIN_MENU -> GAME -> DEATH_SCREEN -> MAIN_MENU.
## Includes a 500ms debounce to prevent rapid-fire scene switches (per ADR-0006)
## and black fade-in/fade-out transitions for visual polish.
##
## On switch to GAME: calls [method GameManager.start_new_run].
## On switch to DEATH_SCREEN: stores GameManager.current_run stats for the
## death screen to display via [method get_pending_death_data].
##
## SceneManager must be an Autoload because [method SceneTree.change_scene_to_file]
## removes all non-autoload nodes from the tree.
##
## Usage:
##   [codeblock]
##   SceneManager.switch_to(SceneManager.SceneID.GAME)
##   SceneManager.switch_to(SceneManager.SceneID.DEATH_SCREEN)
##   var current := SceneManager.get_current_scene()
##   [/codeblock]
class_name SceneManager
extends Node

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Identifies one of the three game scenes.
enum SceneID { MAIN_MENU, GAME, DEATH_SCREEN }

## Maps each SceneID to its .tscn file path.
const SCENE_PATHS: Dictionary = {
	SceneID.MAIN_MENU: "res://src/scenes/main_menu.tscn",
	SceneID.GAME: "res://src/scenes/game.tscn",
	SceneID.DEATH_SCREEN: "res://src/scenes/death_screen.tscn",
}

## Minimum time between scene switches, in milliseconds (per ADR-0006).
const DEBOUNCE_MS: int = 500

## Duration of each half of the fade transition, in seconds.
const FADE_DURATION: float = 0.15

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

## The scene currently displayed (or being transitioned to).
var _current_scene: SceneID = SceneID.MAIN_MENU

## Timestamp of the last accepted switch_to() call, in milliseconds.
## Used for debounce; compared against [method Time.get_ticks_msec].
var _last_switch_ms: int = 0

## The SceneID being transitioned to. Set before the fade-out begins.
var _pending_scene_id: SceneID

## Optional data passed by the caller for the destination scene.
var _pending_data: Dictionary = {}

## Full-screen black overlay used for fade transitions.
var _overlay: ColorRect = null

## CanvasLayer parent for the overlay so it renders above everything.
var _canvas_layer: CanvasLayer = null

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Switches to [param scene_id] after a fade-out / fade-in transition.
##
## [param data] is an optional dictionary passed to the destination scene.
## On switch to GAME: calls GameManager.start_new_run() during the transition.
## On switch to DEATH_SCREEN: snapshots GameManager.current_run stats so the
##   death screen can read them via [method get_pending_death_data].
##
## Calls within [constant DEBOUNCE_MS] milliseconds of the last accepted switch
## are silently ignored.
func switch_to(scene_id: SceneID, data: Dictionary = {}) -> void:
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_switch_ms < DEBOUNCE_MS:
		return
	_last_switch_ms = now_ms

	_pending_scene_id = scene_id
	_pending_data = data
	_fade_out()

## Returns the currently active scene.
func get_current_scene() -> SceneID:
	return _current_scene

## Returns the data snapshot captured when switching to DEATH_SCREEN.
## This includes a copy of GameManager.current_run fields at the time of switch.
## Returns an empty Dictionary if no death data is pending.
func get_pending_death_data() -> Dictionary:
	return _pending_data.duplicate()

# ---------------------------------------------------------------------------
# Fade transitions
# ---------------------------------------------------------------------------

## Creates the black overlay and animates it from transparent to opaque.
func _fade_out() -> void:
	_create_overlay()
	_overlay.modulate.a = 0.0

	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(_overlay, "modulate:a", 1.0, FADE_DURATION)
	tween.tween_callback(_do_scene_change)

## After the scene has loaded, fades the overlay from opaque to transparent.
func _fade_in() -> void:
	# Re-create the overlay because change_scene_to_file may have freed
	# the previous one (the new scene tree replaces all non-autoload nodes).
	_create_overlay()
	_overlay.modulate.a = 1.0

	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(_overlay, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(_destroy_overlay)

## Called when the fade-out tween completes. Performs the actual scene change
## and then triggers fade-in.
func _do_scene_change() -> void:
	var path: String = SCENE_PATHS.get(_pending_scene_id, "")
	if path.is_empty() or not FileAccess.file_exists(path):
		push_error("SceneManager: Scene file missing for SceneID %d (path: %s)" % [_pending_scene_id, path])
		_pending_scene_id = SceneID.MAIN_MENU
		path = SCENE_PATHS[SceneID.MAIN_MENU]
		if not FileAccess.file_exists(path):
			push_error("SceneManager: Fatal -- main_menu.tscn also missing: " + path)
			return

	# Pre-switch side effects
	if _pending_scene_id == SceneID.GAME:
		GameManager.start_new_run()

	# Snapshot run stats for death screen
	if _pending_scene_id == SceneID.DEATH_SCREEN and GameManager.current_run != null:
		_pending_data["run_duration"] = GameManager.get_run_duration_seconds()
		_pending_data["kills"] = GameManager.current_run.kills
		_pending_data["wave"] = GameManager.current_run.wave
		_pending_data["perfect_dodges"] = GameManager.current_run.perfect_dodges
		_pending_data["total_damage_dealt"] = GameManager.current_run.total_damage_dealt

	# Destroy overlay before scene change so it does not interfere
	_destroy_overlay()

	# Change scene
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneManager: change_scene_to_file failed with error %d for path: %s" % [err, path])
		if _pending_scene_id != SceneID.MAIN_MENU:
			get_tree().change_scene_to_file(SCENE_PATHS[SceneID.MAIN_MENU])
			_current_scene = SceneID.MAIN_MENU
		_fade_in()
		return

	_current_scene = _pending_scene_id

	# Fade back in
	_fade_in()

# ---------------------------------------------------------------------------
# Overlay management
# ---------------------------------------------------------------------------

## Creates a full-screen black ColorRect on a CanvasLayer as children of
## this autoload node. The CanvasLayer ensures the overlay renders above
## all other content.
func _create_overlay() -> void:
	_destroy_overlay()
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 128
	add_child(_canvas_layer)
	_overlay = ColorRect.new()
	_overlay.color = Color.BLACK
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas_layer.add_child(_overlay)

## Safely removes the overlay and its CanvasLayer parent.
func _destroy_overlay() -> void:
	if _canvas_layer != null and is_instance_valid(_canvas_layer):
		_canvas_layer.queue_free()
	_canvas_layer = null
	_overlay = null
