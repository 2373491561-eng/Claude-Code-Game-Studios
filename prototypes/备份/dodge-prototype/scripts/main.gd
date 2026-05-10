# PROTOTYPE - NOT FOR PRODUCTION
# Date: 2026-05-07

extends Node2D

@onready var _player = $Player
@onready var _enemy = $Enemy


func _ready() -> void:
	_enemy.set_player(_player)

	var instructions: Label = Label.new()
	instructions.text = "WASD=移动 | Shift/右键=闪避 | 靠近敌人子弹触发极限闪避"
	instructions.position = Vector2(10, 10)
	instructions.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	add_child(instructions)
