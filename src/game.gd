extends Node2D

var _was_shooting: bool = false
var _bullet_trails: Array = []
var _last_fire_ms: int = 0
var _is_dodging: bool = false
var _dodge_end_ms: int = 0
var _last_move_dir: Vector2 = Vector2.RIGHT
var _skill_cooldown_ms: int = 0
var _skill_effects: Array = []
var _player_hp: int = 3
var _player_iframe_end: int = 0
var _perfect_overlay: ColorRect = null
var _enemies: Array = []
var _enemy_bullets: Array = []
var _wave_number: int = 1
var _kill_count: int = 0

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
	_spawn_wave()
	print("Game ready! Wave %d" % _wave_number)

func _spawn_wave() -> void:
	for e in _enemies:
		if is_instance_valid(e.rect):
			e.rect.queue_free()
	_enemies.clear()
	var px: float = $Player.global_position.x
	var py: float = $Player.global_position.y
	for i in range(_wave_number + 2):
		var is_medium: bool = (i == _wave_number + 1) and _wave_number >= 2
		var rect := ColorRect.new()
		if is_medium:
			rect.color = Color(1, 0.8, 0.2, 1)
			rect.size = Vector2(40, 40)
		else:
			rect.color = Color(0.2, 1, 0.2, 1)
			rect.size = Vector2(24, 24)
		var ex: float; var ey: float
		while true:
			ex = randi_range(100, 800); ey = randi_range(100, 400)
			if Vector2(ex - px, ey - py).length() > 200.0: break
		rect.position = Vector2(ex, ey)
		add_child(rect)
		_enemies.append({"rect": rect, "hp": 5 if is_medium else 3, "max_hp": 5 if is_medium else 3, "type": "medium" if is_medium else "small", "shoot_cd": 0})
	print("WAVE %d: %d enemies" % [_wave_number, _enemies.size()])
func _process(delta: float) -> void:
	var inp: Node = $InputSystem
	if not inp:
		return
	var mx: Vector2 = inp.get_move_axis()
	if mx.length() > 1.0: mx = mx.normalized()
	var shoot: bool = inp.is_shoot_pressed()
	var aim: Vector2 = inp.get_aim_direction()
	if mx.length() > 0.1: _last_move_dir = mx.normalized()

	# Player movement
	if not _is_dodging:
		$Player.global_position += mx * 300.0 * delta

	# Enemy AI
	for e in _enemies:
		if e.hp <= 0: continue
		var epos: Vector2 = e.rect.position + e.rect.size / 2.0
		var to_player: Vector2 = $Player.global_position - epos
		var dist: float = to_player.length()
		if e.type == "small":
			if dist > 0.1:
				e.rect.position += to_player.normalized() * 120.0 * delta * Engine.time_scale
		else:
			# Medium: keep distance 150px
			if dist < 120.0 and dist > 0.1:
				e.rect.position -= to_player.normalized() * 80.0 * delta * Engine.time_scale
			elif dist > 180.0 and dist > 0.1:
				e.rect.position += to_player.normalized() * 80.0 * delta * Engine.time_scale
			# Shoot
			e.shoot_cd -= delta * Engine.time_scale
			if e.shoot_cd <= 0:
				e.shoot_cd = 2.0
				var bullet := ColorRect.new()
				bullet.color = Color(1, 0.5, 0, 1)
				bullet.size = Vector2(6, 6)
				bullet.position = epos - Vector2(3, 3)
				add_child(bullet)
				_enemy_bullets.append({"rect": bullet, "pos": epos, "vel": to_player.normalized() * 150.0})
		# Contact damage for both types
		if dist < e.rect.size.x * 0.7 and Time.get_ticks_msec() > _player_iframe_end:
			_player_hp -= 1
			_player_iframe_end = Time.get_ticks_msec() + 1000
			$Player/PlayerSprite.color = Color(1, 1, 1, 1)
			var ht: Tween = create_tween()
			ht.tween_property($Player/PlayerSprite, "color", Color(1, 0.3, 0.3, 1), 0.3)
			if _player_hp <= 0:
				_player_iframe_end = Time.get_ticks_msec() + 3000
				_player_hp = 3
				$Player.global_position = Vector2(480, 400)

	# Move enemy bullets
	for i in range(_enemy_bullets.size() - 1, -1, -1):
		var b: Dictionary = _enemy_bullets[i]
		b.pos += b.vel * delta * Engine.time_scale
		b.rect.position = b.pos - Vector2(3, 3)
		if b.pos.x < 0 or b.pos.x > 960 or b.pos.y < 0 or b.pos.y > 540:
			b.rect.queue_free(); _enemy_bullets.remove_at(i); continue
		var dist_to_player: float = b.pos.distance_to($Player.global_position)
		if dist_to_player < 16.0 and Time.get_ticks_msec() > _player_iframe_end:
			_player_hp -= 1
			_player_iframe_end = Time.get_ticks_msec() + 1000
			$Player/PlayerSprite.color = Color(1, 1, 1, 1)
			var ht: Tween = create_tween()
			ht.tween_property($Player/PlayerSprite, "color", Color(1, 0.3, 0.3, 1), 0.3)
			b.rect.queue_free(); _enemy_bullets.remove_at(i)
			if _player_hp <= 0:
				_player_iframe_end = Time.get_ticks_msec() + 3000
				_player_hp = 3
				$Player.global_position = Vector2(480, 400)
	# Shooting
	if not _is_dodging:
		if shoot and not _was_shooting: _last_fire_ms = 0
		if shoot and Time.get_ticks_msec() - _last_fire_ms >= 125:
			_last_fire_ms = Time.get_ticks_msec()
			_fire_bullet(aim)
	_was_shooting = shoot

	# Dodge
	if Input.is_action_just_pressed("dodge") and not _is_dodging and Time.get_ticks_msec() - _dodge_end_ms > 500:
		var nearest_dist: float = 99999.0
		for e in _enemies:
			if e.hp <= 0: continue
			var d: float = $Player.global_position.distance_to(e.rect.position + Vector2(12, 12))
			if d < nearest_dist: nearest_dist = d
		for b in _enemy_bullets:
			var bd: float = $Player.global_position.distance_to(b.pos)
			if bd < nearest_dist: nearest_dist = bd
		_do_dodge(aim, nearest_dist < 50.0)

	# Skill
	if Input.is_action_just_pressed("skill_1") and Time.get_ticks_msec() - _skill_cooldown_ms > 3000:
		_skill_cooldown_ms = Time.get_ticks_msec()
		_do_skill()

	# Time scale recovery
	if Engine.time_scale < 1.0:
		Engine.time_scale = clamp(Engine.time_scale + delta * 4.0, 0.2, 1.0)
		if Engine.time_scale >= 1.0:
			Engine.time_scale = 1.0
			if _perfect_overlay: _perfect_overlay.visible = false

	# Debug
	var dbg: Label = $DebugLabel
	if dbg:
		var alive: int = 0
		for e in _enemies:
			if e.hp > 0: alive += 1
		var skill_ready: bool = Time.get_ticks_msec() - _skill_cooldown_ms > 3000
		dbg.text = "HP:%d | Wave:%d | Enemies:%d | Kills:%d | Dodge:%s | Skill:%s" % [_player_hp, _wave_number, alive, _kill_count, _is_dodging, skill_ready]

	# Bullet trails
	for i in range(_bullet_trails.size() - 1, -1, -1):
		_bullet_trails[i].life -= delta
		if _bullet_trails[i].life <= 0: _bullet_trails.remove_at(i)
	# Skill effects
	for i in range(_skill_effects.size() - 1, -1, -1):
		_skill_effects[i].life -= delta
		_skill_effects[i].radius += 400.0 * delta
		if _skill_effects[i].life <= 0: _skill_effects.remove_at(i)
	queue_redraw()

func _fire_bullet(aim: Vector2) -> void:
	var origin: Vector2 = $Player.global_position
	if aim.length() < 0.01: return
	var endpoint: Vector2 = origin + aim * 800.0
	var closest: Dictionary = {}
	var closest_dist: float = 99999.0
	for e in _enemies:
		if e.hp <= 0: continue
		var ctr: Vector2 = e.rect.position + Vector2(12, 12)
		var to_enemy: Vector2 = ctr - origin
		var proj: float = to_enemy.dot(aim)
		if proj > 0 and proj < closest_dist:
			var perp: float = (to_enemy - aim * proj).length()
			if perp < 20.0:
				closest_dist = proj
				closest = e
	if not closest.is_empty() and closest_dist < 800.0:
		endpoint = origin + aim * closest_dist
		closest.hp -= 1
		closest.rect.color = Color(1, 0.2, 0.2, 1)
		if closest.hp <= 0:
			closest.rect.visible = false
			_kill_count += 1
			_check_wave_clear()
		else:
			var t := create_tween()
			t.tween_property(closest.rect, "color", Color(0.2, 1, 0.2, 1), 0.2)
	_bullet_trails.append({"origin": origin, "end": endpoint, "life": 0.15})

func _do_skill() -> void:
	var origin: Vector2 = $Player.global_position
	for e in _enemies:
		if e.hp <= 0: continue
		if origin.distance_to(e.rect.position + Vector2(12, 12)) < 200.0:
			e.hp -= 1
			e.rect.color = Color(1, 0.2, 0.2, 1)
			if e.hp <= 0:
				e.rect.visible = false
				_kill_count += 1
				_check_wave_clear()
	_skill_effects.append({"pos": origin, "radius": 0.0, "life": 0.5})

func _do_dodge(aim: Vector2, is_perfect: bool = false) -> void:
	_is_dodging = true
	_player_iframe_end = Time.get_ticks_msec() + 500
	var raw_mx: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction: Vector2
	if raw_mx.length() > 0.1:
		direction = raw_mx.normalized()
	elif _last_move_dir.length() > 0.01:
		direction = _last_move_dir
	else:
		direction = -aim if aim.length() > 0.01 else Vector2.RIGHT
	var target: Vector2 = $Player.global_position + direction * 100.0
	if is_perfect:
		$Player/PlayerSprite.color = Color(0.2, 0.8, 1, 1)
		Engine.time_scale = 0.2
		_skill_cooldown_ms = 0
		if not _perfect_overlay:
			_perfect_overlay = ColorRect.new()
			_perfect_overlay.color = Color(0, 0.3, 0.6, 0.3)
			_perfect_overlay.size = Vector2(960, 540)
			_perfect_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_perfect_overlay)
		_perfect_overlay.visible = true
	else:
		$Player/PlayerSprite.color = Color(0.3, 0.5, 1, 1)
	var tween: Tween = create_tween()
	tween.tween_property($Player, "global_position", target, 0.15)
	tween.tween_callback(func():
		_is_dodging = false
		_dodge_end_ms = Time.get_ticks_msec()
		$Player/PlayerSprite.color = Color(1, 0.3, 0.3, 1)
	)

func _check_wave_clear() -> void:
	var alive: int = 0
	for e in _enemies:
		if e.hp > 0: alive += 1
	if alive <= 0:
		_wave_number += 1
		_spawn_wave()

func _draw() -> void:
	for t in _bullet_trails:
		var a: float = clamp(t.life / 0.15, 0.0, 1.0)
		draw_line(t.origin, t.end, Color(1, 0.8, 0.2, a), 2)
	for b in _enemy_bullets:
		draw_circle(b.pos, 3, Color(0, 0.5, 1, 1))

	for s in _skill_effects:
		var a: float = clamp(s.life / 0.5, 0.0, 1.0)
		draw_arc(s.pos, s.radius, 0, TAU, 36, Color(0.2, 0.6, 1, a), 3)

func _safe_set(node: Node, prop: String, value: Node) -> void:
	if node and prop in node:
		node.set(prop, value)
