class_name UpgradeCardUI extends CanvasLayer

var _cards: Array[Control] = []
var _upgrade_options: Array = []
var _selected: bool = false
var _select_time_ms: int = 0

@export var build_system: Node = null

func _ready() -> void:
	hide()
	if not EventBus.has_signal("wave_clear"):
		return
	EventBus.wave_clear.connect(_on_wave_clear)

func _on_wave_clear(_wave_num: int) -> void:
	if build_system and build_system.has_method("draw_upgrades"):
		_upgrade_options = build_system.draw_upgrades()
	_display_cards()

func _display_cards() -> void:
	_selected = false
	for c in _cards:
		c.queue_free()
	_cards.clear()
	for i in range(_upgrade_options.size()):
		var card := _make_card(_upgrade_options[i], i)
		add_child(card)
		_cards.append(card)
		var tween := create_tween()
		card.position.y += 600
		tween.tween_property(card, "position:y", card.position.y - 600, 0.3).set_delay(i * 0.15)
	show()

func _make_card(upgrade: Dictionary, index: int) -> Control:
	var card := Control.new()
	card.custom_minimum_size = Vector2(180, 240)
	var x_pos := 480 - (90 + 10) + index * 190
	card.position = Vector2(x_pos - 90, 540 - 240 - 20)
	if index == 1: card.position.y -= 8
	var bg := ColorRect.new()
	bg.size = Vector2(180, 240)
	bg.color = Color(0.1, 0.15, 0.25, 0.85)
	card.add_child(bg)
	var icon := TextureRect.new()
	icon.position = Vector2(58, 16)
	icon.size = Vector2(64, 64)
	icon.texture = PlaceholderTexture2D.new()
	icon.texture.size = Vector2(64, 64)
	card.add_child(icon)
	var name_label := Label.new()
	name_label.position = Vector2(8, 88)
	name_label.size = Vector2(164, 24)
	name_label.text = upgrade.get("name", "Upgrade")
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(name_label)
	var desc_label := Label.new()
	desc_label.position = Vector2(8, 116)
	desc_label.size = Vector2(164, 40)
	desc_label.text = upgrade.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 8)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	card.add_child(desc_label)
	card.gui_input.connect(_on_card_input.bind(index))
	return card

func _on_card_input(event: InputEvent, index: int) -> void:
	if _selected: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var now := Time.get_ticks_msec()
		if now - _select_time_ms < 500: return
		_select_time_ms = now
		_select_card(index)

func _input(event: InputEvent) -> void:
	if _selected: return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: _select_card(0)
			KEY_2: _select_card(1)
			KEY_3: _select_card(2)

func _select_card(index: int) -> void:
	if index >= _upgrade_options.size(): return
	_selected = true
	var card := _cards[index]
	var tween := create_tween()
	tween.tween_property(card, "scale", Vector2(1.2, 1.2), 0.15)
	tween.tween_property(card, "modulate", Color.WHITE, 0.1)
	tween.tween_property(card, "position", Vector2(480 - 90, 270 - 120), 0.3)
	tween.tween_callback(func():
		if build_system and build_system.has_method("select_upgrade"):
			build_system.select_upgrade(_upgrade_options[index].get("id", ""))
		for i in range(_cards.size()):
			if i != index:
				var ft := create_tween()
				ft.tween_property(_cards[i], "modulate:a", 0.0, 0.2)
		await get_tree().create_timer(0.3).timeout
		hide()
	)
