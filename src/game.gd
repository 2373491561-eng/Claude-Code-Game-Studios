extends Node2D

var _was_shooting: bool = false
var _bullet_trails: Array = []
var _last_fire_ms: int = 0

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

func _process(delta: float) -> void:
	var dbg: Label = $DebugLabel
	var inp: Node = $InputSystem
	if dbg and inp:
		var mx: Vector2 = inp.get_move_axis()
		var shoot: bool = inp.is_shoot_pressed()
		var aim: Vector2 = inp.get_aim_direction()
		dbg.text = "Move=%.1f,%.1f | Shoot=%s | Aim=%.1f,%.1f" % [mx.x, mx.y, shoot, aim.x, aim.y]
		if shoot and not _was_shooting:
			_last_fire_ms = 0  # Reset cooldown on new press
		if shoot and Time.get_ticks_msec() - _last_fire_ms >= 125:
			_last_fire_ms = Time.get_ticks_msec()
			_fire_bullet(aim)
		_was_shooting = shoot

	for i in range(_bullet_trails.size() - 1, -1, -1):
		_bullet_trails[i].life -= delta
		if _bullet_trails[i].life <= 0:
			_bullet_trails.remove_at(i)
	queue_redraw()

func _fire_bullet(aim: Vector2) -> void:
	var origin: Vector2 = $Player.global_position
	if aim.length() < 0.01:
		return
	var endpoint: Vector2 = origin + aim * 800.0

	var enemy: ColorRect = $TestEnemy
	if enemy:
		var epos: Vector2 = enemy.global_position + enemy.size / 2.0
		var esize: float = enemy.size.x / 2.0
		var to_enemy: Vector2 = epos - origin
		var proj: float = to_enemy.dot(aim)
		if proj > 0 and proj < 800.0:
			var perp: Vector2 = to_enemy - aim * proj
			if perp.length() < esize:
				endpoint = origin + aim * proj
				enemy.color = Color(0.8, 0.2, 0.2, 1)
				var tween: Tween = create_tween()
				tween.tween_property(enemy, "color", Color(0.3, 0.8, 0.3, 1), 0.3)

	_bullet_trails.append({"origin": origin, "end": endpoint, "life": 0.15})

func _draw() -> void:
	for t in _bullet_trails:
		var a: float = clamp(t.life / 0.15, 0.0, 1.0)
		draw_line(t.origin, t.end, Color(1, 0.8, 0.2, a), 2)

func _safe_set(node: Node, prop: String, value: Node) -> void:
	if node and prop in node:
		node.set(prop, value)
