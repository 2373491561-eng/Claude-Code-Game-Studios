extends Node2D

func _ready() -> void:
	_safe_set($InputSystem, "player_node", $Player)
	_safe_set($Player, "input_system", $InputSystem)
	_safe_set($Player/ShootingSystem, "input_system", $InputSystem)
	_safe_set($Player/ShootingSystem, "enemy_manager", $EnemyManager)
	_safe_set($Player/ShootingSystem, "skill_system", $Player/SkillSystem)
	_safe_set($Player/DodgeSystem, "input_system", $InputSystem)
	_safe_set($Player/DodgeSystem, "player_movement", $Player)
	_safe_set($Player/DodgeSystem, "enemy_manager", $EnemyManager)
	_safe_set($Player/SkillSystem, "input_system", $InputSystem)
	_safe_set($Player/SkillSystem, "dodge_system", $Player/DodgeSystem)
	_safe_set($Player/DamageHealthSystem, "dodge_system", $Player/DodgeSystem)
	_safe_set($Player/DamageHealthSystem, "skill_system", $Player/SkillSystem)
	_safe_set($Player/DamageHealthSystem, "input_system", $InputSystem)
	_safe_set($Player/DiegeticUI, "damage_health_system", $Player/DamageHealthSystem)
	_safe_set($Player/DiegeticUI, "dodge_system", $Player/DodgeSystem)
	_safe_set($Player/DiegeticUI, "skill_system", $Player/SkillSystem)
	_safe_set($HUD, "wave_manager", $WaveManager)
	print("All systems wired")

func _process(_delta: float) -> void:
	var dbg: Label = $DebugLabel
	var inp: Node = $InputSystem
	if not dbg or not inp:
		return
	var mx: Vector2 = inp.get_move_axis()
	var shoot: bool = inp.is_shoot_pressed()
	var aim: Vector2 = inp.get_aim_direction()
	dbg.text = "Move=%.1f,%.1f | Shoot=%s | Aim=%.1f,%.1f" % [mx.x, mx.y, shoot, aim.x, aim.y]

	# Simple shooting with visible bullet trail
	if shoot and not _was_shooting:
		_fire_bullet(aim)
	_was_shooting = shoot

var _was_shooting: bool = false

func _fire_bullet(aim: Vector2) -> void:
	var origin: Vector2 = $Player.global_position
	if aim.length() < 0.01:
		return
	var endpoint: Vector2 = origin + aim * 800.0

	# Check if ray hits test enemy
	var enemy: ColorRect = $TestEnemy
	var hit_enemy: bool = false
	if enemy:
		var epos: Vector2 = enemy.global_position
		var esize: float = 12.0
		var to_enemy: Vector2 = epos - origin
		var proj: float = to_enemy.dot(aim)
		if proj > 0 and proj < 800.0:
			var perp: Vector2 = to_enemy - aim * proj
			if perp.length() < esize:
				endpoint = origin + aim * proj
				hit_enemy = true
				enemy.color = Color(0.8, 0.2, 0.2, 1)  # Turn red on hit
				var tween: Tween = create_tween()
				tween.tween_property(enemy, "color", Color(0.3, 0.8, 0.3, 1), 0.3)  # Fade back to green

	# Draw bullet trail (red line, fades fast)
	var trail: ColorRect = ColorRect.new()
	trail.color = Color(1, 0.8, 0.2, 0.8)
	var dir: Vector2 = endpoint - origin
	var len: float = dir.length()
	var mid: Vector2 = (origin + endpoint) / 2.0
	trail.position = mid - Vector2(len/2.0, 1)
	trail.size = Vector2(len, 2) if len > 0 else Vector2(0, 2)
	trail.rotation = dir.angle()
	add_child(trail)
	var ft: Tween = create_tween()
	ft.tween_property(trail, "modulate:a", 0.0, 0.15)
	ft.tween_callback(trail.queue_free)

func _safe_set(node: Node, prop: String, value: Node) -> void:
	if node and prop in node:
		node.set(prop, value)
