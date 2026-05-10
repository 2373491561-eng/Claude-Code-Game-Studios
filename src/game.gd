extends Node2D

var _was_shooting: bool = false
var _bullet_trails: Array = []
var _last_fire_ms: int = 0
var _hit_count: int = 0
var _is_dodging: bool = false
var _dodge_end_ms: int = 0
var _last_move_dir: Vector2 = Vector2.RIGHT
var _skill_cooldown_ms: int = 0
var _skill_effects: Array = []
var _enemy_hp: int = 3
var _enemy_kills: int = 0

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
	if mx.length() > 1.0:
		mx = mx.normalized()
	var shoot: bool = inp.is_shoot_pressed()
	var aim: Vector2 = inp.get_aim_direction()

	if mx.length() > 0.1:
		_last_move_dir = mx.normalized()
	if not _is_dodging:
		$Player.global_position += mx * 300.0 * delta

	# Shooting
	if not _is_dodging:
		if shoot and not _was_shooting:
			_last_fire_ms = 0
		if shoot and Time.get_ticks_msec() - _last_fire_ms >= 125:
			_last_fire_ms = Time.get_ticks_msec()
			_fire_bullet(aim)
	_was_shooting = shoot

	# Dodge
	if Input.is_action_just_pressed("dodge") and not _is_dodging and Time.get_ticks_msec() - _dodge_end_ms > 500:
		_do_dodge(aim)

	# Skill — Space key, AoE shockwave
	if Input.is_action_just_pressed("skill_1") and Time.get_ticks_msec() - _skill_cooldown_ms > 3000:
		_skill_cooldown_ms = Time.get_ticks_msec()
		_do_skill()

	# Debug
	var dbg: Label = $DebugLabel
	if dbg:
		var skill_ready: bool = Time.get_ticks_msec() - _skill_cooldown_ms > 3000
		dbg.text = "HP=%d | Kills=%d | Dodge=%s | Skill=%s" % [_enemy_hp, _enemy_kills, _is_dodging, skill_ready]

	# Bullet trails
	for i in range(_bullet_trails.size() - 1, -1, -1):
		_bullet_trails[i].life -= delta
		if _bullet_trails[i].life <= 0:
			_bullet_trails.remove_at(i)
	# Skill effects
	for i in range(_skill_effects.size() - 1, -1, -1):
		_skill_effects[i].life -= delta
		_skill_effects[i].radius += 400.0 * delta
		if _skill_effects[i].life <= 0:
			_skill_effects.remove_at(i)
	queue_redraw()

func _do_dodge(aim: Vector2) -> void:
	_is_dodging = true
	var raw_mx: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction: Vector2
	if raw_mx.length() > 0.1:
		direction = raw_mx.normalized()
	elif _last_move_dir.length() > 0.01:
		direction = _last_move_dir
	else:
		direction = -aim if aim.length() > 0.01 else Vector2.RIGHT

	var start: Vector2 = $Player.global_position
	var target: Vector2 = start + direction * 100.0
	print("DODGE: raw=%s dir=%s start=%s target=%s" % [raw_mx, direction, start, target])

	$Player/PlayerSprite.color = Color(0.3, 0.5, 1, 1)

	var tween: Tween = create_tween()
	tween.tween_property($Player, "global_position", target, 0.15)
	tween.tween_callback(func():
		_is_dodging = false
		_dodge_end_ms = Time.get_ticks_msec()
		$Player/PlayerSprite.color = Color(1, 0.3, 0.3, 1)
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
				_hit_count += 1
				_enemy_hp -= 1
				enemy.color = Color(1, 0.2, 0.2, 1)
				if _enemy_hp <= 0:
					_enemy_kills += 1
					_respawn_enemy()
				else:
					var t := create_tween()
					t.tween_property(enemy, "color", Color(0.2, 1, 0.2, 1), 0.2)

	_bullet_trails.append({"origin": origin, "end": endpoint, "life": 0.15})

func _do_skill() -> void:
	var origin: Vector2 = $Player.global_position
	# Hit all enemies within 200px
	var enemy: ColorRect = $TestEnemy
	if enemy:
		var epos: Vector2 = enemy.position + Vector2(24, 24)
		if origin.distance_to(epos) < 200.0:
			_hit_count += 1
			_enemy_hp -= 1
			enemy.color = Color(1, 0.2, 0.2, 1)
			if _enemy_hp <= 0:
				_enemy_kills += 1
				_respawn_enemy()
	# Shockwave visual effect (expanding ring)
	_skill_effects.append({"pos": origin, "radius": 0.0, "life": 0.5})
	print("SKILL!")

func _draw() -> void:
	for t in _bullet_trails:
		var a: float = clamp(t.life / 0.15, 0.0, 1.0)
		draw_line(t.origin, t.end, Color(1, 0.8, 0.2, a), 2)
	for s in _skill_effects:
		var a: float = clamp(s.life / 0.5, 0.0, 1.0)
		draw_arc(s.pos, s.radius, 0, TAU, 36, Color(0.2, 0.6, 1, a), 3)

func _respawn_enemy() -> void:
	var enemy: ColorRect = $TestEnemy
	enemy.color = Color(0.2, 1, 0.2, 1)
	_enemy_hp = 3
	enemy.position = Vector2(randi_range(100, 800), randi_range(100, 400))

func _safe_set(node: Node, prop: String, value: Node) -> void:
	if node and prop in node:
		node.set(prop, value)
