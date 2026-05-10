class_name MenuUI extends CanvasLayer

@export var scene_manager: Node = null

func _ready() -> void:
	if EventBus.has_signal("game_paused"):
		EventBus.game_paused.connect(_on_paused)
	if EventBus.has_signal("game_resumed"):
		EventBus.game_resumed.connect(_on_resumed)
	if EventBus.has_signal("player_death"):
		EventBus.player_death.connect(_on_player_death)
	var current_scene := ""
	if scene_manager and scene_manager.has_method("get_current_scene"):
		current_scene = scene_manager.get_current_scene()
	if current_scene == "main_menu":
		_show_main_menu()
	elif current_scene == "death_screen":
		_show_death_screen()

func _show_main_menu() -> void:
	hide()
	var title := Label.new()
	title.text = "RIFT REACTION"
	title.position = Vector2(480 - 150, 200)
	title.size = Vector2(300, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	add_child(title)
	var btn := Button.new()
	btn.text = "START GAME"
	btn.position = Vector2(480 - 80, 280)
	btn.size = Vector2(160, 36)
	btn.pressed.connect(func():
		if scene_manager and scene_manager.has_method("switch_to"):
			scene_manager.switch_to(1, {}) # SceneID.GAME
	)
	add_child(btn)
	show()

func _show_death_screen() -> void:
	hide()
	var stats := _get_stats()
	var y_pos := 150.0
	for key in ["wave", "kills", "builds"]:
		var label := Label.new()
		label.text = str(key.to_upper(), ": ", stats.get(key, 0))
		label.position = Vector2(480 - 100, y_pos)
		label.size = Vector2(200, 30)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)
		var tween := create_tween()
		label.modulate.a = 0
		tween.tween_property(label, "modulate:a", 1.0, 0.3)
		y_pos += 40
	var btn := Button.new()
	btn.text = "RETURN TO MENU"
	btn.position = Vector2(480 - 80, y_pos + 20)
	btn.size = Vector2(160, 36)
	btn.pressed.connect(func():
		if scene_manager and scene_manager.has_method("switch_to"):
			scene_manager.switch_to(0, {}) # SceneID.MAIN_MENU
	)
	add_child(btn)
	show()

func _get_stats() -> Dictionary:
	if GameManager.current_run:
		return {
			"wave": GameManager.current_run.wave,
			"kills": GameManager.current_run.kills,
			"builds": GameManager.current_run.build_choices.size(),
		}
	return {"wave": 0, "kills": 0, "builds": 0}

func _on_paused() -> void:
	var overlay := ColorRect.new()
	overlay.name = "PauseOverlay"
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.size = Vector2(960, 540)
	add_child(overlay)
	var cont := Button.new()
	cont.text = "CONTINUE"
	cont.position = Vector2(480 - 80, 240)
	cont.size = Vector2(160, 36)
	cont.pressed.connect(func():
		overlay.queue_free()
		get_tree().paused = false
		EventBus.game_resumed.emit()
	)
	add_child(cont)
	var quit := Button.new()
	quit.text = "QUIT"
	quit.position = Vector2(480 - 80, 290)
	quit.size = Vector2(160, 36)
	quit.pressed.connect(func():
		overlay.queue_free()
		get_tree().paused = false
		if scene_manager and scene_manager.has_method("switch_to"):
			scene_manager.switch_to(0, {})
	)
	add_child(quit)

func _on_resumed() -> void:
	get_tree().paused = false

func _on_player_death(_stats) -> void:
	pass
