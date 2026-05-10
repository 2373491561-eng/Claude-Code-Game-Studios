extends Node2D

var _was_shooting: bool = false
var _bullet_trails: Array = []
var _last_fire_ms: int = 0
var _hit_count: int = 0
var _is_dodging: bool = false
var _last_move_dir: Vector2 = Vector2.RIGHT

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
	var inp: Node = $InputSystem
	if not inp:
		return

	var mx: Vector2 = inp.get_move_axis()
	var shoot: bool = inp.is_shoot_pressed()
	var aim: Vector2 = inp.get_aim_direction()

	# Debug display
	var dbg: Label = $DebugLabel
	if dbg:
		var dodge_text: String = " DODGING!" if _is_dodging else ""
		dbg.text = "WASD | Click=Shoot | Shift=Dodge | HIT=%d%s" % [_hit_count, dodge_text]

	# Cache last move direction
	if mx.length() > 0.1:
		_last_move_dir = mx.normalized()

	# Shooting
	if shoot and not _was_shooting:
		_last_fire_ms = 0
	if shoot and Time.get_ticks_msec() - _last_fire_ms >= 125:
		_last_fire_ms = Time.get_ticks_msec()
		_fire_bullet(aim)
	_was_shooting = shoot

	# Dodge — triggered by Shift or Right-click
	if Input.is_action_just_pressed("dodge") and not _is_dodging:
		_do_dodge(mx, aim)

	# Bullet trail fade
	for i in range(_bullet_trails.size() - 1, -1, -1):
		_bullet_trails[i].life -= delta
		if _bullet_trails[i].life <= 0:
			_bullet_trails.remove_at(i)
	queue_redraw()

func _do_dodge(mx: Vector2, aim: Vector2) -> void:
	_is_dodging = true
	var direction: Vector2
	if mx.length() > 0.1:
		direction = mx.normalized()
	elif _last_move_dir.length() > 0.1:
		direction = _last_move_dir
	else:
		direction = -aim if aim.length() > 0.01 else Vector2.RIGHT

	var player: Node2D = $Player
	var start: Vector2 = player.global_position
	var target: Vector2 = start + direction * 100.0

	# Visual: turn blue during dodge
	var sprite: ColorRect = $Player/PlayerSprite
	sprite.color = Color(0.3, 0.5, 1, 1)

	# Tween animation
	var tween: Tween = create_tween()
	tween.tween_property(player, "global_position", target, 0.3).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func():
		_is_dodging = false
		sprite.color = Color(1, 0.3, 0.3, 1)
	)

func _fire_bullet(aim: Vector2) -> void:
	var origin: Vector2 = $Player.global_position
	if aim.length() < 0.01:
		return
	var endpoint: Vector2 = origin + aim * 800.0

	var enemy: ColorRect = $TestEnemy
	if enemy:
		var epos: Vector2 = enemy.position + Vector2(24, 24)
		var to_enemy: Vector2 = epos - origin
		var proj: float = to_enemy.dot(aim)
		if proj > 0 and proj < 800.0:
			var perp: float = (to_enemy - aim * proj).length()
			if perp < 24.0:
				endpoint = origin + aim * proj
				enemy.color = Color(1, 0.2, 0.2, 1) if enemy.color.g > 0.5 else Color(0.2, 1, 0.2, 1)
				_hit_count += 1

	_bullet_trails.append({"origin": origin, "end": endpoint, "life": 0.15})

func _draw() -> void:
	for t in _bullet_trails:
		var a: float = clamp(t.life / 0.15, 0.0, 1.0)
		draw_line(t.origin, t.end, Color(1, 0.8, 0.2, a), 2)

func _safe_set(node: Node, prop: String, value: Node) -> void:
	if node and prop in node:
		node.set(prop, value)
