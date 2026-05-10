# PROTOTYPE - NOT FOR PRODUCTION
# Date: 2026-05-08

extends Node2D


func _ready() -> void:
	var player := $Player
	var enemy := $Enemy
	enemy.set_player(player)

	# Bullet processor
	var bullet_timer := Timer.new()
	bullet_timer.wait_time = 1.0 / 60.0
	bullet_timer.timeout.connect(_process_bullets)
	add_child(bullet_timer)
	bullet_timer.start()

	# Top-left instructions
	var label1 := Label.new()
	label1.text = "WASD = 移动"
	label1.position = Vector2(10, 10)
	label1.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	add_child(label1)

	var label2 := Label.new()
	label2.text = "Shift / 右键 = 闪避"
	label2.position = Vector2(10, 28)
	label2.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	add_child(label2)

	var label3 := Label.new()
	label3.text = "子弹靠近身边(16px内)时闪避 = 极限闪避 (蓝+时间变慢+不耗充能)"
	label3.position = Vector2(10, 46)
	label3.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	add_child(label3)

	var label4 := Label.new()
	label4.text = "颜色: 绿=正常 | 蓝(1秒)=极限闪避 | 橙(1秒)=被击中 | 白闪=无敌帧"
	label4.position = Vector2(10, 64)
	label4.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	add_child(label4)


func _process_bullets() -> void:
	for child in get_children():
		if child is Area2D and child.has_meta("dir"):
			var dir: Vector2 = child.get_meta("dir")
			var speed: float = child.get_meta("speed")
			var life: float = child.get_meta("life")
			life -= 1.0 / 60.0
			if life <= 0.0:
				child.queue_free()
				continue
			child.set_meta("life", life)
			child.position += dir * speed * (1.0 / 60.0)
