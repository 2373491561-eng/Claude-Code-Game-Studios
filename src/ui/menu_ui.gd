class_name MenuUI extends CanvasLayer

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.08, 0.2, 1)
	bg.size = Vector2(960, 540)
	add_child(bg)

	var title := Label.new()
	title.text = "RIFT REACTION"
	title.position = Vector2(350, 180)
	title.add_theme_font_size_override("font_size", 28)
	add_child(title)

	var btn := Button.new()
	btn.text = "START GAME"
	btn.position = Vector2(400, 280)
	btn.size = Vector2(160, 40)
	btn.pressed.connect(func():
		SceneManager.switch_to(SceneManager.SceneID.GAME, {})
	)
	add_child(btn)
