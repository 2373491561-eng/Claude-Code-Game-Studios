extends Node
enum SceneID { MAIN_MENU, GAME, DEATH_SCREEN }
var _current_scene: int = SceneID.MAIN_MENU
var _last_switch_ms: int = 0

func get_current_scene() -> int:
	return _current_scene

func switch_to(scene_id: int, _data: Dictionary = {}) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_switch_ms < 500:
		return
	_last_switch_ms = now
	var path: String = ""
	match scene_id:
		SceneID.MAIN_MENU: path = "res://src/scenes/main_menu.tscn"
		SceneID.GAME: path = "res://src/scenes/game.tscn"
		SceneID.DEATH_SCREEN: path = "res://src/scenes/death_screen.tscn"
	if path.is_empty():
		return
	_current_scene = scene_id
	if scene_id == SceneID.GAME:
		GameManager.start_new_run()
	get_tree().change_scene_to_file(path)
