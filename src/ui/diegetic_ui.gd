## DiegeticUI -- in-world player status indicators rendered around the player.
##
## Implements: diegetic-ui (Presentation layer)
## Story type: Visual/Feel (no automated tests)
##
## Three diegetic indicators orbit the player:
##   1. Health halo: segmented circle showing current HP / max HP.
##      On damage: segments shatter outward. On heal: segments fade in.
##   2. Skill charge orb: circle at offset (0, -30). Color/glow indicates
##      OrbState (EMPTY, CHARGING, ALMOST_READY, READY).
##   3. Dodge dots: 3 dots on 28px orbit ring. Available=cyan pulse,
##      cooling=gray. Consumed: white flash+shrink.
##
## Reads systems directly via @export refs. Rendered via _draw() with arcs
## and circles. z_index control for render order.
##
## Usage:
##   [codeblock]
##   # In game.tscn, as a child of the Player node:
##   var diegetic := DiegeticUI.new()
##   diegetic.damage_health_system = $Player/DamageHealthSystem
##   diegetic.skill_system = $Player/SkillSystem
##   diegetic.dodge_system = $Player/DodgeSystem
##   player.add_child(diegetic)
##   [/codeblock]
class_name DiegeticUI
extends Node2D

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Health halo radius in pixels.
const HALO_RADIUS: float = 20.0

## Skill charge orb offset from player center.
const ORB_OFFSET: Vector2 = Vector2(0, -30)

## Skill charge orb radius.
const ORB_RADIUS: float = 7.0

## Dodge dots orbit ring radius.
const DODGE_ORBIT_RADIUS: float = 28.0

## Dodge dot radius.
const DODGE_DOT_RADIUS: float = 3.0

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------

const COLOR_HEALTH_SEGMENT: Color = Color(0.2, 1.0, 0.3, 0.9)    # Green
const COLOR_HEALTH_MISSING: Color = Color(0.3, 0.1, 0.1, 0.4)    # Dark red
const COLOR_ORB_EMPTY: Color = Color(0.3, 0.4, 0.5, 0.6)         # Gray-blue
const COLOR_ORB_CHARGING: Color = Color(0.0, 0.8, 1.0, 0.8)      # Cyan
const COLOR_ORB_ALMOST_READY: Color = Color(0.0, 0.5, 1.0, 1.0)  # Electric blue
const COLOR_ORB_READY_PRIMARY: Color = Color(1.0, 0.4, 0.1, 1.0) # Orange-red
const COLOR_ORB_READY_SECONDARY: Color = Color(0.0, 0.5, 1.0, 1.0) # Electric blue
const COLOR_DOT_AVAILABLE: Color = Color(0.0, 0.8, 1.0, 0.9)     # Cyan
const COLOR_DOT_COOLING: Color = Color(0.4, 0.4, 0.4, 0.5)       # Gray

# ---------------------------------------------------------------------------
# Exported references
# ---------------------------------------------------------------------------

@export var damage_health_system: Node = null
@export var skill_system: Node = null
@export var dodge_system: Node = null

# ---------------------------------------------------------------------------
# Internal state -- health halo
# ---------------------------------------------------------------------------

var _displayed_hp: int = 3
var _max_hp: int = 3
var _shatter_particles: Array[Dictionary] = []  # [{angle, offset, alpha, vel}]

# ---------------------------------------------------------------------------
# Internal state -- charge orb
# ---------------------------------------------------------------------------

var _orb_pulse_accum: float = 0.0

# ---------------------------------------------------------------------------
# Internal state -- dodge dots
# ---------------------------------------------------------------------------

var _dot_consumed_flash: Array[float] = [0.0, 0.0, 0.0]  # Remaining flash time per dot
var _previous_charge_count: int = 3

# ---------------------------------------------------------------------------
# Node lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	z_index = 5  # Render above player sprite but below UI

	# Read initial HP from system if available.
	if damage_health_system != null and damage_health_system.has_method("get_hp"):
		_displayed_hp = damage_health_system.get_hp()
		_max_hp = _read_max_hp()

	# Read initial dodge charges.
	if dodge_system != null and dodge_system.has_method("get_charge_count"):
		_previous_charge_count = dodge_system.get_charge_count()

func _process(delta: float) -> void:
	_update_state()
	_update_animations(delta)
	queue_redraw()

func _draw() -> void:
	_draw_health_halo()
	_draw_skill_orb()
	_draw_dodge_dots()

# ---------------------------------------------------------------------------
# State updates
# ---------------------------------------------------------------------------

func _update_state() -> void:
	# Read HP from system.
	if damage_health_system != null and damage_health_system.has_method("get_hp"):
		var current_hp := damage_health_system.get_hp()
		_max_hp = _read_max_hp()

		if current_hp < _displayed_hp:
			# Damage taken -- trigger shatter on lost segments.
			for i in range(current_hp, _displayed_hp):
				_trigger_shatter(i)
			_displayed_hp = current_hp
		elif current_hp > _displayed_hp:
			# Healed -- fade-in new segment.
			_displayed_hp = current_hp

	# Detect dodge charge consumption via DodgeSystem.
	if dodge_system != null and dodge_system.has_method("get_charge_count"):
		var current_charges := dodge_system.get_charge_count()
		if current_charges < _previous_charge_count:
			var dots_consumed := _previous_charge_count - current_charges
			for d in range(dots_consumed):
				var dot_idx := _previous_charge_count - 1 - d
				if dot_idx >= 0 and dot_idx < 3:
					_dot_consumed_flash[dot_idx] = 0.3  # 300ms flash
		_previous_charge_count = current_charges

func _read_max_hp() -> int:
	if damage_health_system == null:
		return 3
	# Try to read MAX_HP constant or getter.
	if damage_health_system.has_method("get_max_hp"):
		return damage_health_system.get_max_hp()
	if damage_health_system.get("MAX_HP") != null:
		return int(damage_health_system.MAX_HP)
	return 3

# ---------------------------------------------------------------------------
# Animation updates
# ---------------------------------------------------------------------------

func _update_animations(delta: float) -> void:
	# Update shatter particles.
	for i in range(_shatter_particles.size() - 1, -1, -1):
		var p := _shatter_particles[i]
		p.alpha -= delta * 2.0
		p.offset += p.vel * delta
		if p.alpha <= 0.0:
			_shatter_particles.remove_at(i)

	# Update dodge dot flash timers.
	for i in range(3):
		if _dot_consumed_flash[i] > 0.0:
			_dot_consumed_flash[i] -= delta

	# Orb pulse accumulator.
	_orb_pulse_accum += delta

# ---------------------------------------------------------------------------
# Health halo drawing
# ---------------------------------------------------------------------------

func _draw_health_halo() -> void:
	var segment_angle := TAU / float(_max_hp)
	var segment_span := segment_angle * 0.8  # 80% of full angle for gap

	for i in range(_max_hp):
		var start_angle := float(i) * segment_angle - segment_span / 2.0 - TAU / 4.0
		var end_angle := start_angle + segment_span

		var color := COLOR_HEALTH_SEGMENT if i < _displayed_hp else COLOR_HEALTH_MISSING

		draw_arc(Vector2.ZERO, HALO_RADIUS, start_angle, end_angle, 8, color, 2.0, true)

	# Draw shatter particles.
	for p in _shatter_particles:
		var pos := Vector2(cos(p.angle), sin(p.angle)) * (HALO_RADIUS + p.offset)
		var shatter_color := COLOR_HEALTH_SEGMENT
		shatter_color.a = p.alpha
		draw_circle(pos, 2.0, shatter_color)

func _trigger_shatter(segment_index: int) -> void:
	var segment_angle := TAU / float(_max_hp)
	var angle := float(segment_index) * segment_angle - TAU / 4.0
	var outward := Vector2(cos(angle), sin(angle))

	# Spawn 3 shatter fragments.
	for _i in range(3):
		var spread := randf_range(-0.3, 0.3)
		var particle := {
			angle = angle + spread,
			offset = 0.0,
			alpha = 1.0,
			vel = outward * randf_range(30.0, 60.0) + Vector2(randf_range(-20, 20), randf_range(-20, 20)),
		}
		_shatter_particles.append(particle)

# ---------------------------------------------------------------------------
# Skill charge orb drawing
# ---------------------------------------------------------------------------

func _draw_skill_orb() -> void:
	var orb_state: int = 0  # EMPTY default
	if skill_system != null and skill_system.has_method("get_orb_state"):
		orb_state = skill_system.get_orb_state()

	var color: Color
	var pulse_rate: float

	match orb_state:
		0:  # EMPTY
			color = COLOR_ORB_EMPTY
			pulse_rate = 0.0
		1:  # CHARGING
			color = COLOR_ORB_CHARGING
			pulse_rate = 1.0
		2:  # ALMOST_READY
			color = COLOR_ORB_ALMOST_READY
			pulse_rate = 3.0
		3:  # READY
			# Alternate between orange-red and electric blue at 5 Hz.
			var phase := sin(_orb_pulse_accum * TAU * 5.0)
			if phase > 0:
				color = COLOR_ORB_READY_PRIMARY
			else:
				color = COLOR_ORB_READY_SECONDARY
			pulse_rate = 5.0

	# Apply pulse to radius.
	var radius := ORB_RADIUS
	if pulse_rate > 0.0:
		var pulse := 1.0 + 0.3 * sin(_orb_pulse_accum * TAU * pulse_rate)
		radius *= pulse

	# Draw glow (larger, semi-transparent).
	var glow_color := color
	glow_color.a *= 0.3
	draw_circle(ORB_OFFSET, radius * 1.8, glow_color)

	# Draw orb.
	draw_circle(ORB_OFFSET, radius, color)

	# Draw border.
	draw_arc(ORB_OFFSET, radius, 0, TAU, 12, color, 1.0, false)

# ---------------------------------------------------------------------------
# Dodge dots drawing
# ---------------------------------------------------------------------------

func _draw_dodge_dots() -> void:
	var charge_count := 3
	if dodge_system != null and dodge_system.has_method("get_charge_count"):
		charge_count = dodge_system.get_charge_count()

	for i in range(3):
		var angle := float(i) * TAU / 3.0 - TAU / 4.0  # Start from top
		var pos := Vector2(cos(angle), sin(angle)) * DODGE_ORBIT_RADIUS
		var radius := DODGE_DOT_RADIUS
		var color: Color

		if _dot_consumed_flash[i] > 0.0:
			# White flash + shrink.
			color = Color(1.0, 1.0, 1.0, _dot_consumed_flash[i] / 0.3)
			radius *= 0.5
		elif i < charge_count:
			# Available: cyan pulse.
			var pulse := 1.0 + 0.2 * sin(_orb_pulse_accum * TAU * 2.0 + float(i))
			color = COLOR_DOT_AVAILABLE
			color.a *= pulse
		else:
			# Cooling: gray.
			color = COLOR_DOT_COOLING

		draw_circle(pos, radius, color)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns the current displayed HP (may lag behind actual HP during animations).
func get_displayed_hp() -> int:
	return _displayed_hp
