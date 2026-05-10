class_name SettingsUI extends CanvasLayer

var _save_manager: SaveManager = null

func _ready() -> void:
	hide()
	_save_manager = get_node_or_null("/root/SaveManager") as SaveManager

func show_settings() -> void:
	_clear()
	_build_sliders()
	show()

func _clear() -> void:
	for c in get_children():
		c.queue_free()

func _build_sliders() -> void:
	var labels := ["Master Volume", "BGM Volume", "SFX Volume"]
	var keys := ["master_volume", "bgm_volume", "sfx_volume"]
	for i in range(3):
		_add_slider(labels[i], keys[i], 100 + i * 60)

func _add_slider(label_text: String, key: String, y_pos: float) -> void:
	var label := Label.new()
	label.text = label_text
	label.position = Vector2(480 - 120, y_pos)
	label.size = Vector2(240, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)

	var slider := HSlider.new()
	slider.position = Vector2(480 - 100, y_pos + 30)
	slider.size = Vector2(200, 20)
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	if _save_manager:
		slider.value = _save_manager.get_setting(key, 1.0) * 100.0
	else:
		slider.value = 100.0
	slider.value_changed.connect(func(v: float):
		var vol := v / 100.0
		var bus_name := "Master"
		if key == "bgm_volume": bus_name = "BGM"
		elif key == "sfx_volume": bus_name = "SFX"
		var bus_idx := AudioServer.get_bus_index(bus_name)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(vol))
		if _save_manager:
			_save_manager.set_setting(key, vol)
	)
	add_child(slider)

	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.position = Vector2(480 - 40, y_pos + 120)
	close_btn.size = Vector2(80, 30)
	close_btn.pressed.connect(func(): hide())
	add_child(close_btn)
