## SkillSystem -- manages skill_1 cooldown, AoE damage, cancel refund, skill_2
## window, and charge orb visual state.
##
## Implements: design/gdd/skill-system.md (all stories)
## Governed by: ADR-0010 (skill_2 pierce), ADR-0005 (event bus signals)
##
## Skill 1 is a time-cooldown circular AoE burst (200px radius) triggered by
## Space. Its cooldown speed is accelerated by dodge charge count. Dodges
## reduce the cooldown directly: -3s for normal, -8s for perfect (charge>=1).
## Skill 1 can be canceled during its 200ms startup window by dodging,
## refunding 75% of the remaining cooldown.
##
## Skill 2 is auto-attach: after a perfect dodge (charge>=1), a 500ms window
## opens. The next attack during this window automatically gets damage x2
## and pierce 1. No extra key press required.
##
## Usage:
##   [codeblock]
##   # In game.tscn, after instancing dodge and input systems:
##   var skill_sys := SkillSystem.new()
##   skill_sys.dodge_system = $Player/DodgeSystem
##   skill_sys.input_system = $InputSystem
##   skill_sys.enemy_manager = $EnemyManager  # optional, for AoE damage
##   player.add_child(skill_sys)
##   [/codeblock]
class_name SkillSystem
extends Node2D

# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

## OrbState describes the visual state of the charge orb for Diegetic UI.
enum OrbState {
	EMPTY,        ## cooldown_ratio > 0.8 -- grey-blue, static, no glow
	CHARGING,     ## 0.3 < cooldown_ratio <= 0.8 -- cool cyan, dim glow, 1 Hz pulse
	ALMOST_READY, ## 0.0 < cooldown_ratio <= 0.3 -- electric blue, bright glow, 3 Hz pulse
	READY,        ## cooldown_ratio == 0.0 -- electric blue + orange-red alternate, 5 Hz pulse
}

# ---------------------------------------------------------------------------
# Constants -- all gameplay values are data-driven (tuning knobs from GDD)
# ---------------------------------------------------------------------------

## Base cooldown of skill_1 in seconds (real time).
const BASE_CD: float = 15.0

## Maximum ratio of base cooldown that can be reduced per cycle.
## BASE_CD * CD_CAP_RATIO = max reduction (15 * 0.6 = 9s).
const CD_CAP_RATIO: float = 0.6

## Radius of the skill_1 circular AoE in pixels.
const AOE_RADIUS: float = 200.0

## Cancel window duration in milliseconds (real time).
## During the first CANCEL_WINDOW_MS of a skill_1 cast, pressing dodge
## cancels the skill and refunds 75% of the remaining cooldown.
const CANCEL_WINDOW_MS: int = 200

## Total skill_1 cast duration in milliseconds (real time).
## 200ms startup (cancelable) + 300ms active (non-cancelable).
const SKILL_CAST_DURATION_MS: int = 500

## Cooldown refund ratio when skill_1 is canceled during startup.
const CANCEL_REFUND_RATIO: float = 0.75

## Base damage dealt by skill_1 AoE.
const BASE_DAMAGE: int = 1

## Cooldown acceleration multiplier per dodge charge above 1.
## cd_speed = 1.0 + max(charge_count - 1, 0) * CD_CHARGE_ACCEL
const CD_CHARGE_ACCEL: float = 0.5

## Cooldown reduction in seconds from a normal dodge (charge>=1).
const CD_REDUCTION_NORMAL: float = 3.0

## Cooldown reduction in seconds from a perfect dodge (charge>=1).
const CD_REDUCTION_PERFECT: float = 8.0

## Cooldown reduction from a perfect dodge with charge=0.
const CD_REDUCTION_PERFECT_NO_CHARGE: float = 0.0

## skill_2 window duration in milliseconds (real time).
const SKILL2_WINDOW_MS: int = 500

## OrbState threshold: cooldown ratio above this is EMPTY.
const ORB_EMPTY_THRESHOLD: float = 0.8

## OrbState threshold: cooldown ratio above this is CHARGING (below EMPTY).
const ORB_CHARGING_THRESHOLD: float = 0.3

# ---------------------------------------------------------------------------
# Exported references
# ---------------------------------------------------------------------------

## Reference to the DodgeSystem node. Used to read charge_count for CD
## acceleration, consume dodge results for CD reduction, and detect
## perfect dodge for skill_2 window opening.
@export var dodge_system: DodgeSystem = null

## Reference to the InputSystem node (owned by game.tscn).
@export var input_system: InputSystem = null

## Reference to the EnemyManager node. Optional -- used for AoE damage
## application via intersect_shape().
@export var enemy_manager: Node = null

# ---------------------------------------------------------------------------
# Internal state -- cooldown
# ---------------------------------------------------------------------------

## Remaining cooldown in seconds. When <= 0, skill_1 is ready.
var _cooldown_remaining: float = 0.0

## Timestamp (Time.get_ticks_msec()) of the last cooldown tick.
var _last_tick_ms: int = 0

## Total cooldown reduction applied this cycle (capped at BASE_CD * CD_CAP_RATIO).
var _total_reduction_this_cycle: float = 0.0

# ---------------------------------------------------------------------------
# Internal state -- skill_1 cast
# ---------------------------------------------------------------------------

## True while skill_1 is casting (0-500ms).
var _is_casting: bool = false

## Timestamp when the current skill_1 cast began.
var _cast_start_ms: int = 0

# ---------------------------------------------------------------------------
# Internal state -- skill_2 window
# ---------------------------------------------------------------------------

## Timestamp when the skill_2 window was opened (or 0 if not open).
var _skill2_window_open_ms: int = 0

# ---------------------------------------------------------------------------
# Cached physics query objects (created in _ready())
# ---------------------------------------------------------------------------

## Cached CircleShape2D for the AoE intersect_shape query (radius AOE_RADIUS).
var _aoe_shape: CircleShape2D = null

## Cached PhysicsShapeQueryParameters2D for the AoE query.
## The shape transform is updated each cast to the player's position.
var _aoe_query: PhysicsShapeQueryParameters2D = null

## Cached reference to the physics world's direct space state.
var _space_state: PhysicsDirectSpaceState2D = null

# ---------------------------------------------------------------------------
# Public API -- skill_1
# ---------------------------------------------------------------------------

## Returns true if skill_1 is ready to cast (cooldown <= 0 and not already
## casting).
func is_skill1_ready() -> bool:
	return _cooldown_remaining <= 0.0 and not _is_casting

## Returns the remaining cooldown in seconds.
func get_cooldown_remaining() -> float:
	return _cooldown_remaining

## Returns the cooldown ratio (cooldown_remaining / BASE_CD) clamped to [0, 1].
func get_cooldown_ratio() -> float:
	return clampf(_cooldown_remaining / BASE_CD, 0.0, 1.0)

# ---------------------------------------------------------------------------
# Public API -- skill_2
# ---------------------------------------------------------------------------

## Returns true while the skill_2 window is open (perfect dodge within the
## last 500ms, charge >= 1 required at time of perfect dodge).
func is_skill2_window_open() -> bool:
	if _skill2_window_open_ms == 0:
		return false
	return Time.get_ticks_msec() - _skill2_window_open_ms < SKILL2_WINDOW_MS

## Consumes the skill_2 window. After this call, is_skill2_window_open()
## returns false until the next perfect dodge (charge>=1).
func consume_skill2() -> void:
	_skill2_window_open_ms = 0

# ---------------------------------------------------------------------------
# Public API -- orb visual state
# ---------------------------------------------------------------------------

## Returns the current OrbState based on the cooldown ratio.
##
## Mapping:
##   ratio > 0.8  -> EMPTY
##   0.3 < ratio <= 0.8 -> CHARGING
##   0.0 < ratio <= 0.3 -> ALMOST_READY
##   ratio == 0.0 -> READY
func get_orb_state() -> int:
	var ratio := get_cooldown_ratio()
	if ratio <= 0.0:
		return OrbState.READY
	if ratio <= ORB_CHARGING_THRESHOLD:
		return OrbState.ALMOST_READY
	if ratio <= ORB_EMPTY_THRESHOLD:
		return OrbState.CHARGING
	return OrbState.EMPTY

# ---------------------------------------------------------------------------
# Node lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Cache the physics shape for AoE queries.
	_aoe_shape = CircleShape2D.new()
	_aoe_shape.radius = AOE_RADIUS

	# Cache physics space reference (requires being in the tree).
	if is_inside_tree():
		_space_state = get_world_2d().direct_space_state

	# Initialize cooldown timer.
	_last_tick_ms = Time.get_ticks_msec()

func _physics_process(_delta: float) -> void:
	# Guard: no InputSystem assigned yet.
	if input_system == null:
		return

	# Cache space state if not already done.
	if _space_state == null and is_inside_tree():
		_space_state = get_world_2d().direct_space_state

	# ----------------------------------------------------------------
	# Step 0: Poll dodge system for CD reduction events
	# ----------------------------------------------------------------
	if dodge_system != null:
		_process_dodge_cd_reduction()

	# ----------------------------------------------------------------
	# Step 1: Cooldown update (real time via Time.get_ticks_msec)
	# ----------------------------------------------------------------
	_update_cooldown()

	# ----------------------------------------------------------------
	# Step 2: Check skill_2 window (perfect dodge -> open window)
	# ----------------------------------------------------------------
	_update_skill2_window()

	# ----------------------------------------------------------------
	# Step 3: If currently casting, manage cancel window and cast end
	# ----------------------------------------------------------------
	if _is_casting:
		_process_cast_lifecycle()
		return

	# ----------------------------------------------------------------
	# Step 4: Check for skill_1 trigger
	# ----------------------------------------------------------------
	if not is_skill1_ready():
		# Cooldown active -- pressing skill_1 does nothing.
		# (The input_system already blocks skill_1 in SKILL_CASTING state.)
		if input_system.is_skill1_just_pressed():
			# Cooldown-not-ready feedback: handled by Diegetic UI (red flash).
			pass
		return

	# Skill is ready and player pressed the key.
	if input_system.is_skill1_just_pressed():
		_execute_skill1()

# ---------------------------------------------------------------------------
# Cooldown update (real time, charge-accelerated)
# ---------------------------------------------------------------------------

## Updates the cooldown timer using real-time elapsed milliseconds.
##
## Cooldown speed is accelerated by dodge charge count:
##   cd_speed = 1.0 + max(charge_count - 1, 0) * CD_CHARGE_ACCEL
##
## Uses Time.get_ticks_msec() (not delta) so cooldown is unaffected by
## Engine.time_scale. This means during a perfect dodge's time scale
## slowdown, skill cooldown continues ticking at normal speed.
func _update_cooldown() -> void:
	if _cooldown_remaining <= 0.0:
		_cooldown_remaining = 0.0

	var now := Time.get_ticks_msec()
	var elapsed := now - _last_tick_ms

	# Detect large time jumps (e.g., game paused for debugging).
	if elapsed > 5000:
		_last_tick_ms = now
		return

	if elapsed <= 0:
		return

	# Compute CD speed multiplier from dodge charge count.
	var charge_count := 0
	if dodge_system != null:
		charge_count = dodge_system.get_charge_count()

	var cd_speed := 1.0 + maxi(charge_count - 1, 0) * CD_CHARGE_ACCEL

	# Advance cooldown.
	_cooldown_remaining -= (elapsed / 1000.0) * cd_speed
	if _cooldown_remaining < 0.0:
		_cooldown_remaining = 0.0

	_last_tick_ms = now

# ---------------------------------------------------------------------------
# Dodge CD reduction processing
# ---------------------------------------------------------------------------

## Polls the DodgeSystem for dodge results and applies CD reductions.
##
## Called once per physics frame. Reads consume_last_dodge_result() from
## DodgeSystem and applies the appropriate CD reduction based on dodge type
## and charge count at time of dodge trigger.
##
## CD reduction is capped at BASE_CD * CD_CAP_RATIO per cycle.
func _process_dodge_cd_reduction() -> void:
	var result: Dictionary = dodge_system.consume_last_dodge_result()
	var dodge_type: int = result.get("type", DodgeSystem.DODGE_RESULT_NONE)
	var charge_at_trigger: int = result.get("charge", 0)

	if dodge_type == DodgeSystem.DODGE_RESULT_NONE:
		return

	# Only reduce CD if cooldown is not already zero.
	if _cooldown_remaining <= 0.0:
		return

	var reduction := 0.0

	if dodge_type == DodgeSystem.DODGE_RESULT_NORMAL:
		# Normal dodge: -3s (always charge>=1 since normal dodge requires it).
		reduction = CD_REDUCTION_NORMAL

	elif dodge_type == DodgeSystem.DODGE_RESULT_PERFECT:
		if charge_at_trigger >= 1:
			# Perfect dodge with charge >= 1: -8s.
			reduction = CD_REDUCTION_PERFECT
		else:
			# Perfect dodge with charge=0: no reduction.
			reduction = CD_REDUCTION_PERFECT_NO_CHARGE

	# Apply CD reduction cap.
	var cap := BASE_CD * CD_CAP_RATIO
	var available_cap := cap - _total_reduction_this_cycle
	if available_cap <= 0.0:
		# Cap reached -- no further reduction this cycle.
		return

	reduction = minf(reduction, available_cap)

	# Apply the reduction.
	_cooldown_remaining -= reduction
	if _cooldown_remaining < 0.0:
		_cooldown_remaining = 0.0

	_total_reduction_this_cycle += reduction

# ---------------------------------------------------------------------------
# Skill_2 window management
# ---------------------------------------------------------------------------

## Checks if the DodgeSystem has opened a new skill_2 window.
##
## A skill_2 window opens when the DodgeSystem detects a perfect dodge
## with charge >= 1. The window is open for SKILL2_WINDOW_MS (500ms).
##
## If a new perfect dodge occurs while the window is already open,
## the window is refreshed (restarted at 500ms).
##
## The DodgeSystem's _is_perfect_dodge_active flag becomes true on the
## frame a perfect dodge executes. We detect the rising edge to open
## or refresh the window.
func _update_skill2_window() -> void:
	if dodge_system == null:
		return

	# Check if a perfect dodge just triggered.
	# We track the previous frame's perfect dodge state to detect rising edge.
	if dodge_system.is_perfect_dodge_active():
		# Get the charge count at the time of the perfect dodge.
		# The _last_dodge_charge_at_trigger is already set by DodgeSystem.
		# We can infer from the public API -- if charge >= 1, open window.
		var charge_count := dodge_system.get_charge_count()
		# Actually, get_charge_count() returns the CURRENT charge.
		# Since perfect dodge doesn't consume charge, this is accurate.
		if charge_count >= 1:
			# Open or refresh the skill_2 window.
			_skill2_window_open_ms = Time.get_ticks_msec()
	else:
		# If window has expired, close it.
		if _skill2_window_open_ms != 0:
			if Time.get_ticks_msec() - _skill2_window_open_ms >= SKILL2_WINDOW_MS:
				_skill2_window_open_ms = 0

# ---------------------------------------------------------------------------
# Skill_1 execution
# ---------------------------------------------------------------------------

## Executes skill_1: AoE damage burst, resets cooldown, begins cast lifecycle.
##
## Sets input state to SKILL_CASTING so the input system blocks new skill_1
## presses and allows dodge cancel. The cast lasts SKILL_CAST_DURATION_MS
## (500ms total): first CANCEL_WINDOW_MS (200ms) is cancelable by dodge,
## the remaining 300ms is non-cancelable.
func _execute_skill1() -> void:
	# Apply AoE damage to all enemies in range.
	_apply_aoe_damage()

	# Emit skill_1_cast signal.
	_emit_skill_1_cast()

	# Reset cooldown and reduction tracking.
	_cooldown_remaining = BASE_CD
	_total_reduction_this_cycle = 0.0

	# Begin cast lifecycle.
	_is_casting = true
	_cast_start_ms = Time.get_ticks_msec()

	# Set input state to SKILL_CASTING.
	if input_system != null:
		input_system.set_state(InputSystem.STATE_SKILL_CASTING)

# ---------------------------------------------------------------------------
# Skill_1 AoE damage application
# ---------------------------------------------------------------------------

## Applies BASE_DAMAGE to all enemies within AOE_RADIUS of the player.
##
## Uses PhysicsDirectSpaceState2D.intersect_shape() with a cached
## CircleShape2D. If EnemyManager exists and has apply_damage(idx, dmg),
## damage is routed through it per ADR-0004.
##
## If EnemyManager is not available, any intersecting bodies are skipped
## (no-op -- the skill still plays its visual/audio effects via EventBus).
func _apply_aoe_damage() -> void:
	if _space_state == null or _aoe_shape == null:
		return

	# Build the query each cast (transform depends on player position).
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _aoe_shape
	query.transform = Transform2D(0.0, player_movement_global_position())
	query.collision_mask = _get_enemy_collision_layer()

	var results: Array[Dictionary] = _space_state.intersect_shape(query)

	# Collect unique enemy indices from the results.
	# Since enemies in ADR-0004 are NOT physics bodies, we check for
	# EnemyManager compatibility and route damage through it.
	if enemy_manager == null:
		return

	if enemy_manager.has_method("apply_damage_to_all_in_shape"):
		enemy_manager.apply_damage_to_all_in_shape(query, BASE_DAMAGE)
		return

	# Fallback: if EnemyManager exposes individual apply_damage, iterate.
	for hit in results:
		var collider = hit.get("collider")
		if collider and enemy_manager.has_method("apply_damage_to_body"):
			enemy_manager.apply_damage_to_body(collider, BASE_DAMAGE)

# ---------------------------------------------------------------------------
# Skill_1 cast lifecycle
# ---------------------------------------------------------------------------

## Manages the skill_1 cast lifecycle: cancel window, dodge cancel detection,
## and cast completion.
##
## Called each physics frame while _is_casting is true.
##
## Same-frame dodge + skill_1: cancel takes priority. The dodge system runs
## before the skill system in _physics_process, so if the input system's
## dodge just pressed is true, we process the cancel here before doing
## anything else with the cast.
func _process_cast_lifecycle() -> void:
	var elapsed_ms := Time.get_ticks_msec() - _cast_start_ms

	# Check for dodge cancel (same-frame priority per AC7).
	if input_system != null:
		if input_system.is_dodge_just_pressed() or input_system.consume_dodge_buffer():
			if elapsed_ms < CANCEL_WINDOW_MS:
				# Dodge cancels skill_1 during startup window.
				_cancel_skill1()
				return

	# Check if cast duration has expired.
	if elapsed_ms >= SKILL_CAST_DURATION_MS:
		_end_cast()
		return

# ---------------------------------------------------------------------------
# Skill_1 cancel (dodge during startup window)
# ---------------------------------------------------------------------------

## Cancels the current skill_1 cast and refunds CANCEL_REFUND_RATIO (75%)
## of the remaining cooldown, rounded to 0.1s.
##
## The cast is interrupted, particles fade out, and cooldown restarts
## from the refunded value. The input state is reset to NORMAL.
##
## Cancel refund does NOT count toward the CD reduction cap (it is a
## recovery, not an additional reduction).
func _cancel_skill1() -> void:
	# Calculate refund based on cooldown remaining BEFORE cancel.
	# cooldown_remaining is the value since the cast reset it to BASE_CD.
	# But some time has passed since the cast started, so the actual
	# remaining is less. We use the original BASE_CD minus elapsed time.
	var elapsed_sec := (Time.get_ticks_msec() - _cast_start_ms) / 1000.0
	var current_remaining := maxf(BASE_CD - elapsed_sec, 0.0)

	# Refund 75% of the current remaining, rounded to 0.1s.
	var refund := roundf(current_remaining * CANCEL_REFUND_RATIO * 10.0) / 10.0
	_cooldown_remaining = maxf(current_remaining - refund, 0.0)

	# End the cast.
	_is_casting = false

	if input_system != null:
		input_system.set_state(InputSystem.STATE_NORMAL)

# ---------------------------------------------------------------------------
# Skill_1 cast end (normal completion)
# ---------------------------------------------------------------------------

## Ends the skill_1 cast normally and restores NORMAL input state.
func _end_cast() -> void:
	_is_casting = false

	if input_system != null:
		input_system.set_state(InputSystem.STATE_NORMAL)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Returns the player's current global position.
##
## If dodge_system.player_movement is available, uses that. Otherwise
## falls back to the parent node's position.
func player_movement_global_position() -> Vector2:
	if dodge_system != null and dodge_system.player_movement != null:
		return dodge_system.player_movement.global_position
	return global_position

## Returns the collision layer bit for enemy detection.
##
## If dodge_system is available, uses its enemy_collision_layer_bit.
## Otherwise defaults to layer 3 (bit 2 = value 4).
func _get_enemy_collision_layer() -> int:
	if dodge_system != null:
		return dodge_system.enemy_collision_layer_bit
	return 4

# ---------------------------------------------------------------------------
# EventBus signal emission helpers
# ---------------------------------------------------------------------------

## Emits skill_1_cast on the EventBus Autoload if available.
##
## Signal: skill_1_cast(pos: Vector2)
## Consumed by: VFX (shockwave particle burst), Audio (burst sound +
## BGM ducking), Camera (intense shake).
func _emit_skill_1_cast() -> void:
	var eb := get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("skill_1_cast"):
		eb.skill_1_cast.emit(player_movement_global_position())
