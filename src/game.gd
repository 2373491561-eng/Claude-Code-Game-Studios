extends Node2D

# Player state
var _player_hp: int = 3
var _max_player_hp: int = 3
var _player_iframe_end: int = 0
var _last_move_dir: Vector2 = Vector2.RIGHT
var _move_speed: float = 300.0

# Shooting
var _was_shooting: bool = false
var _bullet_trails: Array = []
var _last_fire_ms: int = 0
var _fire_interval_ms: int = 125
var _bonus_damage: int = 0

# Dodge
var _is_dodging: bool = false
var _dodge_end_ms: int = 0

# Skill
var _skill_cooldown_ms: int = 0
var _skill_effects: Array = []

# Perfect dodge
var _perfect_overlay: ColorRect = null

# Enemies
var _enemies: Array = []
var _enemy_bullets: Array = []

# Wave
var _wave_number: int = 1
var _kill_count: int = 0
var _showing_upgrades: bool = false
var _upgrade_choices: Array = []
var _death_particles: Array = []

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

# ============================================================
# SPAWN
# ============================================================

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
		var ex: float
		var ey: float
		while true:
			ex = randi_range(100, 800)
			ey = randi_range(100, 400)
			if Vector2(ex - px, ey - py).length() > 200.0:
				break
		rect.position = Vector2(ex, ey)
		add_child(rect)
		_enemies.append({
			"rect": rect,
			"hp": 5 if is_medium else 3,
			"max_hp": 5 if is_medium else 3,
			"type": "medium" if is_medium else "small",
			"shoot_cd": 0.0
		})
	print("WAVE %d: %d enemies" % [_wave_number, _enemies.size()])

# ============================================================
# MAIN LOOP
# ============================================================

func _process(delta: float) -> void:
	if _showing_upgrades:
		return
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

	# Player movement
	if not _is_dodging:
		$Player.global_position += mx * _move_speed * delta

	# Enemy AI
	for e in _enemies:
		if e.hp <= 0:
			continue
		var epos: Vector2 = e.rect.position + e.rect.size / 2.0
		var to_player: Vector2 = $Player.global_position - epos
		var dist: float = to_player.length()
		# Small: chase
		if e.type == "small":
			if dist > 0.1:
				e.rect.position += to_player.normalized() * 120.0 * delta * Engine.time_scale
		# Medium: keep distance + shoot
		else:
			if dist < 120.0 and dist > 0.1:
				e.rect.position -= to_player.normalized() * 80.0 * delta * Engine.time_scale
			elif dist > 180.0 and dist > 0.1:
				e.rect.position += to_player.normalized() * 80.0 * delta * Engine.time_scale
			e.shoot_cd -= delta * Engine.time_scale
			if e.shoot_cd <= 0.0:
				e.shoot_cd = 2.0
				var bullet := ColorRect.new()
				bullet.color = Color(1, 0.5, 0, 1)
				bullet.size = Vector2(6, 6)
				bullet.position = epos - Vector2(3, 3)
				add_child(bullet)
				_enemy_bullets.append({"rect": bullet, "pos": epos, "vel": to_player.normalized() * 150.0})
		# Contact damage
		var hit_size: float = e.rect.size.x * 0.7
		if dist < hit_size and Time.get_ticks_msec() > _player_iframe_end:
			_hurt_player()

	# Enemy bullets
	for i in range(_enemy_bullets.size() - 1, -1, -1):
		var b: Dictionary = _enemy_bullets[i]
		b.pos += b.vel * delta * Engine.time_scale
		b.rect.position = b.pos - Vector2(3, 3)
		if b.pos.x < -50 or b.pos.x > 1010 or b.pos.y < -50 or b.pos.y > 590:
			b.rect.queue_free()
			_enemy_bullets.remove_at(i)
		elif b.pos.distance_to($Player.global_position) < 14.0 and Time.get_ticks_msec() > _player_iframe_end:
			b.rect.queue_free()
			_enemy_bullets.remove_at(i)
			_hurt_player()

	# Shooting
	if not _is_dodging:
		if shoot and not _was_shooting:
			_last_fire_ms = 0
		if shoot and Time.get_ticks_msec() - _last_fire_ms >= _fire_interval_ms:
			_last_fire_ms = Time.get_ticks_msec()
			_fire_bullet(aim)
	_was_shooting = shoot

	# Dodge
	if Input.is_action_just_pressed("dodge") and not _is_dodging and Time.get_ticks_msec() - _dodge_end_ms > 500:
		var nearest_dist: float = 99999.0
		for e in _enemies:
			if e.hp <= 0:
				continue
			var d: float = $Player.global_position.distance_to(e.rect.position + e.rect.size / 2.0)
			if d < nearest_dist:
				nearest_dist = d
	for dp in _death_particles:
		var a: float = clamp(dp.life / 0.4, 0.0, 1.0)
		draw_rect(Rect2(dp.pos.x - 3, dp.pos.y - 3, 6, 6), Color(dp.color.r, dp.color.g, dp.color.b, a))
	for e in _enemies:
		if e.hp <= 0: continue
		var ep: Vector2 = e.rect.position
		var es: Vector2 = e.rect.size
		var ratio: float = float(e.hp) / float(e.max_hp)
		draw_rect(Rect2(ep.x, ep.y - 8, es.x, 4), Color(0.2, 0.2, 0.2, 0.7))
		draw_rect(Rect2(ep.x, ep.y - 8, es.x * ratio, 4), Color.RED if ratio < 0.5 else Color.GREEN)
		for b in _enemy_bullets:
			var bd: float = $Player.global_position.distance_to(b.pos)
			if bd < nearest_dist:
				nearest_dist = bd
		_do_dodge(aim, nearest_dist < 50.0)

	# Skill
	if Input.is_action_just_pressed("skill_1") and Time.get_ticks_msec() - _skill_cooldown_ms > 3000:
		_skill_cooldown_ms = Time.get_ticks_msec()
		_do_skill()

	# Time scale recovery
	if Engine.time_scale < 1.0 and not _showing_upgrades:
		Engine.time_scale = clamp(Engine.time_scale + delta * 4.0, 0.2, 1.0)
		if Engine.time_scale >= 1.0:
			Engine.time_scale = 1.0
			if _perfect_overlay:
				_perfect_overlay.visible = false

	# Debug label
	var dbg: Label = $DebugLabel
	if dbg:
		var alive: int = 0
		for e in _enemies:
			if e.hp > 0:
				alive += 1
		var skill_ready: bool = Time.get_ticks_msec() - _skill_cooldown_ms > 3000
		dbg.text = "HP:%d/%d | Wave:%d | Enemies:%d | Kills:%d | Dodge:%s | Skill:%s" % [_player_hp, _max_player_hp, _wave_number, alive, _kill_count, _is_dodging, skill_ready]

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
	# Iframe blink
	if Time.get_ticks_msec() < _player_iframe_end:
		var blink: float = sin(Time.get_ticks_msec() * 0.02)
		$Player/PlayerSprite.modulate.a = 1.0 if blink > 0 else 0.3
	elif _player_hp > 0:
		$Player/PlayerSprite.modulate.a = 1.0
	# Death particles
	for i in range(_death_particles.size() - 1, -1, -1):
		var dp: Dictionary = _death_particles[i]
		dp.pos += dp.vel * delta
		dp.life -= delta
		if dp.life <= 0:
			_death_particles.remove_at(i)
	queue_redraw()

# ============================================================
# COMBAT
# ============================================================

func _fire_bullet(aim: Vector2) -> void:
	var origin: Vector2 = $Player.global_position
	if aim.length() < 0.01:
		return
	var endpoint: Vector2 = origin + aim * 800.0
	var closest: Dictionary = {}
	var closest_dist: float = 99999.0
	for e in _enemies:
		if e.hp <= 0:
			continue
		var ctr: Vector2 = e.rect.position + e.rect.size / 2.0
		var to_enemy: Vector2 = ctr - origin
		var proj: float = to_enemy.dot(aim)
		if proj > 0 and proj < closest_dist:
			var perp: float = (to_enemy - aim * proj).length()
			if perp < e.rect.size.x * 0.5:
				closest_dist = proj
				closest = e
	if not closest.is_empty() and closest_dist < 800.0:
		endpoint = origin + aim * closest_dist
		closest.hp -= (1 + _bonus_damage)
		closest.rect.color = Color(1, 0.2, 0.2, 1)
		if closest.hp <= 0:
			closest.rect.visible = false
			_spawn_particles(closest.rect.position + closest.rect.size / 2.0, closest.rect.color)
			_kill_count += 1
			_check_wave_clear()
		else:
			var t := create_tween()
			t.tween_property(closest.rect, "color", closest.rect.color, 0.0)
			t.tween_property(closest.rect, "color", Color(0.2, 1, 0.2, 1) if closest.type == "small" else Color(1, 0.8, 0.2, 1), 0.2)
	_bullet_trails.append({"origin": origin, "end": endpoint, "life": 0.15})

func _do_skill() -> void:
	var origin: Vector2 = $Player.global_position
	for e in _enemies:
		if e.hp <= 0:
			continue
		if origin.distance_to(e.rect.position + e.rect.size / 2.0) < 200.0:
			e.hp -= (1 + _bonus_damage)
			e.rect.color = Color(1, 0.2, 0.2, 1)
			if e.hp <= 0:
				e.rect.visible = false
				_spawn_particles(e.rect.position + e.rect.size / 2.0, e.rect.color)
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

func _hurt_player() -> void:
	_player_hp -= 1
	_player_iframe_end = Time.get_ticks_msec() + 1000
	$Player/PlayerSprite.color = Color(1, 1, 1, 1)
	var ht: Tween = create_tween()
	ht.tween_property($Player/PlayerSprite, "color", Color(1, 0.3, 0.3, 1), 0.3)
	if _player_hp <= 0:
		_player_iframe_end = Time.get_ticks_msec() + 3000
		_player_hp = _max_player_hp
		$Player.global_position = Vector2(480, 400)

# ============================================================
# WAVE / UPGRADES
# ============================================================

func _check_wave_clear() -> void:
	var alive: int = 0
	for e in _enemies:
		if e.hp > 0:
			alive += 1
	if alive <= 0 and not _showing_upgrades:
		_show_upgrades()

func _show_upgrades() -> void:
	_showing_upgrades = true
	_upgrade_choices.clear()
	var pool: Array = [
		{"name": "Fire Rate +25%", "id": "fire_rate", "icon": "🔥"},
		{"name": "Damage +1", "id": "damage", "icon": "💪"},
		{"name": "Max HP +1", "id": "max_hp", "icon": "❤️"},
		{"name": "Move Speed +20%", "id": "move_speed", "icon": "🏃"},
		{"name": "Dodge CD -200ms", "id": "dodge_cd", "icon": "🔄"},
		{"name": "Skill CD -1s", "id": "skill_cd", "icon": "⚡"},
	]
	pool.shuffle()
	var label := Label.new()
	label.text = "WAVE %d CLEARED! Choose upgrade (1/2/3):" % _wave_number
	label.position = Vector2(280, 350)
	label.add_theme_font_size_override("font_size", 14)
	add_child(label)
	_upgrade_choices.append(label)
	for i in range(3):
		var opt: Dictionary = pool[i]
		var btn := Button.new()
		btn.text = "%s  [%d] %s" % [opt.icon, i + 1, opt.name]
		btn.position = Vector2(300, 390 + i * 44)
		btn.size = Vector2(360, 36)
		btn.pressed.connect(func(id=opt.id): _pick_upgrade(id))
		add_child(btn)
		_upgrade_choices.append(btn)
	Engine.time_scale = 0.05

func _pick_upgrade(id: String) -> void:
	for c in _upgrade_choices:
		c.queue_free()
	_upgrade_choices.clear()
	_showing_upgrades = false
	Engine.time_scale = 1.0
	match id:
		"fire_rate":
			_fire_interval_ms = max(50, _fire_interval_ms - 30)
		"damage":
			_bonus_damage += 1
		"max_hp":
			_max_player_hp += 1
			_player_hp = min(_player_hp + 1, _max_player_hp)
		"move_speed":
			_move_speed += 60.0
		"dodge_cd":
			_dodge_end_ms = 0
		"skill_cd":
			_skill_cooldown_ms = 0
	_wave_number += 1
	_spawn_wave()

# ============================================================
# RENDER
# ============================================================


func _spawn_particles(pos: Vector2, col: Color) -> void:
	for i in range(8):
		var angle: float = TAU * float(i) / 8.0
		var speed: float = randf_range(60.0, 150.0)
		_death_particles.append({"pos": pos, "vel": Vector2(cos(angle), sin(angle)) * speed, "life": 0.4, "color": col})
func _draw() -> void:
	# Player HP bar
	var px: Vector2 = $Player.global_position
	var bar_w: float = 40.0
	var bar_h: float = 5.0
	var bar_x: float = px.x - bar_w / 2.0
	var bar_y: float = px.y - 30.0
	var hp_ratio: float = float(_player_hp) / float(_max_player_hp)
	var hp_color: Color = Color.GREEN if hp_ratio > 0.5 else (Color.YELLOW if hp_ratio > 0.25 else Color.RED)
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.2, 0.2, 0.2, 0.6))
	draw_rect(Rect2(bar_x, bar_y, bar_w * hp_ratio, bar_h), hp_color)
	for t in _bullet_trails:
		var a: float = clamp(t.life / 0.15, 0.0, 1.0)
		draw_line(t.origin, t.end, Color(1, 0.8, 0.2, a), 2)
	for s in _skill_effects:
		var a: float = clamp(s.life / 0.5, 0.0, 1.0)
		draw_arc(s.pos, s.radius, 0, TAU, 36, Color(0.2, 0.6, 1, a), 3)
	for dp in _death_particles:
		var a: float = clamp(dp.life / 0.4, 0.0, 1.0)
		draw_rect(Rect2(dp.pos.x - 3, dp.pos.y - 3, 6, 6), Color(dp.color.r, dp.color.g, dp.color.b, a))
	for e in _enemies:
		if e.hp <= 0: continue
		var ep: Vector2 = e.rect.position
		var es: Vector2 = e.rect.size
		var ratio: float = float(e.hp) / float(e.max_hp)
		draw_rect(Rect2(ep.x, ep.y - 8, es.x, 4), Color(0.2, 0.2, 0.2, 0.7))
		draw_rect(Rect2(ep.x, ep.y - 8, es.x * ratio, 4), Color.RED if ratio < 0.5 else Color.GREEN)
	for b in _enemy_bullets:
		draw_circle(b.pos, 3, Color(1, 0.5, 0, 1))

func _safe_set(node: Node, prop: String, value: Node) -> void:
	if node and prop in node:
		node.set(prop, value)
