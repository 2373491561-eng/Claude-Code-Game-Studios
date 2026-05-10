extends Node
class_name InputSystem

# ---------------------------------------------------------------------------
# Constants — Input Map action names
# ---------------------------------------------------------------------------

## Move axis actions (4 directional, consumed by Input.get_vector).
const MOVE_LEFT: String = "move_left"
const MOVE_RIGHT: String = "move_right"
const MOVE_UP: String = "move_up"
const MOVE_DOWN: String = "move_down"

## Game action names.
const SHOOT: String = "shoot"
const DODGE: String = "dodge"
const SKILL_1: String = "skill_1"
const PAUSE: String = "pause"

## Deadzone applied to move axis.
## Values below this magnitude are treated as zero input.
const MOVE_DEADZONE: float = 0.2

## Dodge debounce window in milliseconds.
## Presses within this window of a previous dodge execution are discarded
## to prevent accidental double-triggers from input hardware bounce.
const DEBOUNCE_MS: int = 50

## Dodge input buffer window in milliseconds.
## If dodge is pressed while unavailable (on cooldown), the press is held
## in a buffer. If dodge becomes available within this window, it fires
## automatically. If the window expires, the buffer is silently discarded.
const BUFFER_MS: int = 100

# ---------------------------------------------------------------------------
# Input state machine constants (Story 003)
# ---------------------------------------------------------------------------

## All inputs available — default gameplay state.
const STATE_NORMAL: int = 0

## Only aim + skill_1 inputs are polled. Move and shoot are skipped.
## Set by DodgeSystem when a dodge begins.
const STATE_DODGING: int = 1

## Aim + dodge (for cancel) + shoot + move are polled. Skill_1 is blocked
## (already casting). Set by SkillSystem when a skill cast begins.
const STATE_SKILL_CASTING: int = 2

## Only the pause action is polled (to resume). Set by pause toggle or
## focus loss.
const STATE_PAUSED: int = 3

## No inputs are polled. Set when the player dies.
const STATE_DEAD: int = 4

# ---------------------------------------------------------------------------
# Exported references
# ---------------------------------------------------------------------------

## The player node, used to convert mouse screen coordinates to a world-space
## aim direction. Set by game.tscn after instancing the player.
@export var player_node: Node2D = null

# ---------------------------------------------------------------------------
# Per-physics-frame cached state
# ---------------------------------------------------------------------------

var _move_axis: Vector2 = Vector2.ZERO
var _aim_direction: Vector2 = Vector2.ZERO
var _shoot_pressed: bool = false
var _dodge_just_pressed: bool = false
var _skill1_just_pressed: bool = false
var _pause_just_pressed: bool = false

# ---------------------------------------------------------------------------
# Input state machine (Story 003)
# ---------------------------------------------------------------------------

## Current input state. Controls which actions are polled each physics frame.
var _state: int = STATE_NORMAL

## State saved before entering PAUSED, restored on resume.
var _previous_state: int = STATE_NORMAL

## True when a DODGING->NORMAL transition detects that the shoot key is still
## held. The ShootingSystem can call consume_shoot_resume() to read and clear
## this flag, then immediately resume firing without requiring a new press.
var _shoot_resume_pending: bool = false

# ---------------------------------------------------------------------------
# Dodge debounce / buffer state (ADR-0002: lightweight _input markers)
# ---------------------------------------------------------------------------

## Timestamp (Time.get_ticks_msec()) from the most recent dodge action press
## captured in _input(). Used for debounce comparison against _last_dodge_ms.
var _dodge_raw_time_ms: int = 0

## True when a dodge action press has been captured in _input() and is waiting
## to be processed by _process_dodge() in the next physics tick.
var _dodge_queued: bool = false

## True when a dodge press arrived while _dodge_available was false and the
## input has been stored in the buffer.
var _dodge_buffered: bool = false

## Timestamp when the current buffered dodge was stored.
## Used to enforce the BUFFER_MS expiration window.
var _dodge_buffered_time_ms: int = 0

## Timestamp of the most recent dodge execution (used for debounce window).
var _last_dodge_ms: int = 0

## Whether dodge is currently available to execute.
## External systems (DodgeSystem) control this via set_dodge_availability().
var _dodge_available: bool = true

## Remaining cooldown time reported by the dodge system.
## Informational — not used in internal logic, exposed for HUD/UI queries.
var _dodge_remaining_ms: int = 0

# ---------------------------------------------------------------------------
# Static: Input Map registration
# ---------------------------------------------------------------------------

## Ensures all required Input Map actions are registered.
##
## Safe to call multiple times — existing actions are detected and skipped.
## Call once at startup (from _ready() or from GameManager initialization).
##
## Creates 8 actions:
##   move_left (A), move_right (D), move_up (W), move_down (S),
##   shoot (Mouse Left), dodge (Shift + Mouse Right),
##   skill_1 (Space), pause (Escape)
static func register_input_map() -> void:
	_ensure_key_action(MOVE_LEFT, KEY_A)
	_ensure_key_action(MOVE_RIGHT, KEY_D)
	_ensure_key_action(MOVE_UP, KEY_W)
	_ensure_key_action(MOVE_DOWN, KEY_S)

	_ensure_mouse_action(SHOOT, MOUSE_BUTTON_LEFT)

	# Dodge is dual-channel: Shift (keyboard) OR Right Click (mouse).
	_ensure_key_action(DODGE, KEY_SHIFT)
	_ensure_mouse_action(DODGE, MOUSE_BUTTON_RIGHT)

	_ensure_key_action(SKILL_1, KEY_SPACE)
	_ensure_key_action(PAUSE, KEY_ESCAPE)

## Creates a keyboard-driven Input Map action if it does not already exist.
static func _ensure_key_action(action_name: String, keycode: Key) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
	var event := InputEventKey.new()
	event.keycode = keycode
	InputMap.action_add_event(action_name, event)

## Creates a mouse-button-driven Input Map action if it does not already exist.
static func _ensure_mouse_action(action_name: String, button: MouseButton) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action_name, event)

# ---------------------------------------------------------------------------
# Node lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	register_input_map()
	# InputSystem must continue running _physics_process() even when the
	# scene tree is paused, so it can detect the Esc press to unpause.
	# Without PROCESS_MODE_ALWAYS, get_tree().paused = true would stop
	# _physics_process() and the player would be stuck in pause forever.
	process_mode = PROCESS_MODE_ALWAYS

## _input() is reserved for lightweight state marking per ADR-0002.
##
## Stores the raw timestamp and sets a queued flag for dodge presses.
## No game actions are executed here — execution is deferred to
## _process_dodge() inside _physics_process().
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(DODGE) and not event.is_echo():
		_dodge_raw_time_ms = Time.get_ticks_msec()
		_dodge_queued = true

## Polls all game input actions once per physics tick.
##
## This is the single source of truth for game input each frame. Systems read
## the cached values via getters in their own _physics_process() methods,
## guaranteeing the ADR-0002 priority order (dodge -> skill_1 -> shoot -> move).
##
## State-gated polling per Story 003:
##   NORMAL         — all inputs available
##   DODGING        — only aim + skill_1 polled (move/shoot/dodge skipped)
##   SKILL_CASTING  — aim + dodge + shoot + move polled (skill_1 blocked)
##   PAUSED         — only pause action checked (via _process_pause),
##                     all other cached values zeroed
##   DEAD           — no inputs polled, all cached values zeroed
##
## Pause detection runs first (Story 004) — it is not gated by state so that
## the player can always unpause. In PAUSED or DEAD state the method returns
## early after pause processing.
func _physics_process(_delta: float) -> void:
	# Reset per-frame dodge just-pressed state before processing.
	# _process_dodge() will set this to true if dodge fires this frame.
	_dodge_just_pressed = false

	# ----------------------------------------------------------------
	# Step 0: Pause detection (highest priority — always runs)
	# Must process before all other input to guarantee Esc always works.
	# ----------------------------------------------------------------
	_process_pause()

	# ----------------------------------------------------------------
	# PAUSED state: only pause action works. Zero all cached values.
	# ----------------------------------------------------------------
	if _state == STATE_PAUSED:
		_move_axis = Vector2.ZERO
		_aim_direction = Vector2.ZERO
		_shoot_pressed = false
		_skill1_just_pressed = false
		return

	# ----------------------------------------------------------------
	# DEAD state: no input at all. Player is dead and cannot act.
	# ----------------------------------------------------------------
	if _state == STATE_DEAD:
		_move_axis = Vector2.ZERO
		_aim_direction = Vector2.ZERO
		_shoot_pressed = false
		_skill1_just_pressed = false
		return

	# ----------------------------------------------------------------
	# Step 1: Dodge (per ADR-0002 priority: dodge before skill_1)
	# Blocked in DODGING — cannot start a new dodge while dodging.
	# Allowed in SKILL_CASTING — so dodge cancel can fire.
	# ----------------------------------------------------------------
	if _state != STATE_DODGING:
		_process_dodge()

	# ----------------------------------------------------------------
	# Step 2: Skill_1 (per ADR-0002 priority: skill_1 before shoot)
	# Blocked in SKILL_CASTING — cannot cast while already casting.
	# Allowed in NORMAL and DODGING (skill_1 is free during dodge per AC4).
	# ----------------------------------------------------------------
	if _state != STATE_SKILL_CASTING:
		_skill1_just_pressed = Input.is_action_just_pressed(SKILL_1)
	else:
		_skill1_just_pressed = false

	# ----------------------------------------------------------------
	# Step 3: Shoot (per ADR-0002 priority: shoot after skill_1)
	# Blocked in DODGING state (AC3: dodge locks shooting).
	# Allowed in NORMAL and SKILL_CASTING.
	# ----------------------------------------------------------------
	if _state == STATE_DODGING:
		_shoot_pressed = false
	else:
		_shoot_pressed = Input.is_action_pressed(SHOOT)

	# ----------------------------------------------------------------
	# Step 4: Move (per ADR-0002 priority: move is lowest)
	# Blocked in DODGING state (AC3: dodge locks movement).
	# Allowed in NORMAL and SKILL_CASTING.
	# ----------------------------------------------------------------
	if _state == STATE_DODGING:
		_move_axis = Vector2.ZERO
	else:
		_move_axis = Input.get_vector(
			MOVE_LEFT, MOVE_RIGHT, MOVE_UP, MOVE_DOWN, MOVE_DEADZONE
		)

	# Aim direction is polled last and available in all active states
	# (NORMAL, DODGING, SKILL_CASTING).
	_aim_direction = _compute_aim_direction()

# ---------------------------------------------------------------------------
# Pause detection (Story 004)
# ---------------------------------------------------------------------------

## Detects pause toggles and focus-loss auto-pause.
##
## Called at the top of _physics_process() before any state-gated polling.
## Esc toggles pause on/off. When pausing, the current state is saved to
## _previous_state. When resuming, it is restored.
##
## Pause ON:  get_tree().paused = true, emit EventBus.game_paused
## Pause OFF: get_tree().paused = false, emit EventBus.game_resumed
##
## EventBus is an Autoload registered in project.godot. If not yet
## registered, signal emission is silently skipped (graceful degradation).
func _process_pause() -> void:
	if not Input.is_action_just_pressed(PAUSE):
		return

	if _state == STATE_PAUSED:
		# Unpause: restore previous state and emit game_resumed.
		_state = _previous_state
		get_tree().paused = false
		_pause_just_pressed = true
		_emit_game_resumed()
	else:
		# Pause: save current state, switch to PAUSED, emit game_paused.
		_previous_state = _state
		_pause_just_pressed = true
		_state = STATE_PAUSED
		get_tree().paused = true
		_emit_game_paused()

## Auto-pauses the game when the window loses focus (Alt+Tab).
##
## The player must manually press Esc to resume — focus return does NOT
## auto-unpause. If the game is already PAUSED or DEAD, focus loss is
## ignored (no state change).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if _state != STATE_PAUSED and _state != STATE_DEAD:
			_previous_state = _state
			_state = STATE_PAUSED
			get_tree().paused = true
			_emit_game_paused()

# ---------------------------------------------------------------------------
# EventBus signal emission helpers (Story 004)
# ---------------------------------------------------------------------------

## Emits game_paused on the EventBus Autoload if available.
##
## Uses path-based lookup to find the EventBus node at /root/EventBus.
## This is robust against EventBus not yet being registered as an Autoload
## during early integration or testing.
func _emit_game_paused() -> void:
	var eb := get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("game_paused"):
		eb.game_paused.emit()

## Emits game_resumed on the EventBus Autoload if available.
func _emit_game_resumed() -> void:
	var eb := get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("game_resumed"):
		eb.game_resumed.emit()

# ---------------------------------------------------------------------------
# Dodge debounce / buffer pipeline (ADR-0002)
# ---------------------------------------------------------------------------

## Processes a queued dodge press through the debounce -> buffer -> execute
## pipeline.
##
## 1. Debounce (DEBOUNCE_MS): if this press arrived within 50ms of the last
##    dodge execution, it is discarded as hardware bounce.
## 2. Buffer (BUFFER_MS): if dodge is currently unavailable, store the press
##    in a buffer. If dodge becomes available within 100ms, the buffered
##    dodge fires automatically.
## 3. Execute: if dodge is available and debounce passes, mark
##    _dodge_just_pressed = true for downstream systems to consume.
##
## If no dodge is queued but a buffered dodge exists, this method checks
## whether the buffer should fire (availability restored within window) or
## expire (window elapsed).
func _process_dodge() -> void:
	# --- No new press queued: check buffered-dodge lifecycle ---
	if not _dodge_queued:
		if _dodge_buffered:
			if _dodge_available:
				# Availability restored — fire if within buffer window.
				if Time.get_ticks_msec() - _dodge_buffered_time_ms <= BUFFER_MS:
					_dodge_just_pressed = true
					_last_dodge_ms = Time.get_ticks_msec()
				# Whether fired or expired, consume the buffer.
				_dodge_buffered = false
			elif Time.get_ticks_msec() - _dodge_buffered_time_ms > BUFFER_MS:
				# Still unavailable and buffer window elapsed — discard.
				_dodge_buffered = false
		return

	# --- New press queued: run debounce -> buffer -> execute pipeline ---
	_dodge_queued = false

	# Step 1 — Debounce
	if _dodge_raw_time_ms - _last_dodge_ms < DEBOUNCE_MS:
		return

	# Step 2 — Buffer (dodge unavailable)
	if not _dodge_available:
		_dodge_buffered = true
		_dodge_buffered_time_ms = _dodge_raw_time_ms
		return

	# Step 3 — Execute
	_dodge_just_pressed = true
	_last_dodge_ms = _dodge_raw_time_ms

# ---------------------------------------------------------------------------
# Public getters
# ---------------------------------------------------------------------------

## Returns the move axis from WASD input.
##
## Returns Vector2 where:
##   x: -1.0 (A/left) .. 1.0 (D/right)
##   y: -1.0 (W/up) .. 1.0 (S/down)
##   magnitude clamped by MOVE_DEADZONE.
##
## Returns Vector2.ZERO in DODGING, PAUSED, or DEAD states.
func get_move_axis() -> Vector2:
	return _move_axis

## Returns the normalized direction from the player to the mouse cursor
## in world space.
##
## Returns Vector2.ZERO when:
##   - player_node is not assigned
##   - viewport is unavailable
##   - mouse is at (or extremely close to) the player position
##   - state is PAUSED or DEAD
func get_aim_direction() -> Vector2:
	return _aim_direction

## Returns true while the shoot action (Mouse Left) is held down.
##
## Returns false in DODGING, PAUSED, or DEAD states (shoot is locked).
func is_shoot_pressed() -> bool:
	return _shoot_pressed

## Returns true on the physics frame the dodge action executes.
##
## This reflects the output of the debounce -> buffer -> execute pipeline
## (ADR-0002). Raw Input Map presses are filtered through a 50ms debounce
## window and an optional 100ms input buffer.
##
## Dual-channel: fires for Shift (keyboard) OR Mouse Right Click.
##
## Returns false in DODGING, PAUSED, or DEAD states (dodge is locked).
func is_dodge_just_pressed() -> bool:
	return _dodge_just_pressed

## Returns true on the physics frame the skill_1 action (Space) is first
## pressed.
##
## Returns false in SKILL_CASTING, PAUSED, or DEAD states.
func is_skill1_just_pressed() -> bool:
	return _skill1_just_pressed

## Returns true on the physics frame the pause action (Escape) is first
## pressed.
func is_pause_just_pressed() -> bool:
	return _pause_just_pressed

# ---------------------------------------------------------------------------
# Input state machine API (Story 003)
# ---------------------------------------------------------------------------

## Sets the current input state.
##
## External systems call this to indicate the player's current action state:
##   - DodgeSystem: STATE_DODGING on dodge start, STATE_NORMAL on dodge end
##   - SkillSystem: STATE_SKILL_CASTING on cast start, STATE_NORMAL on end
##   - DamageHealthSystem: STATE_DEAD on player death
##   - InputSystem itself: STATE_PAUSED on pause toggle
##
## Flash-resume: when transitioning from DODGING to NORMAL, if the shoot
## key is still physically held (checked via Input.is_action_pressed),
## _shoot_resume_pending is set to true. ShootingSystem can then call
## consume_shoot_resume() to resume firing without a new button press.
##
## [param new_state]: one of STATE_NORMAL, STATE_DODGING, STATE_SKILL_CASTING,
##                    STATE_PAUSED, STATE_DEAD.
func set_state(new_state: int) -> void:
	var old_state := _state
	_state = new_state

	# Flash-resume: when transitioning from DODGING to NORMAL, check if
	# the player is still holding the shoot button. The raw Input check
	# is used here because _shoot_pressed is always forced to false in
	# DODGING state (the cached value cannot be trusted during dodge).
	#
	# If the shoot key was released during the dodge, no flag is set and
	# the player must press shoot again to resume firing.
	if old_state == STATE_DODGING and new_state == STATE_NORMAL:
		if Input.is_action_pressed(SHOOT):
			_shoot_resume_pending = true

## Returns the current input state.
##
## Returns one of STATE_NORMAL (0), STATE_DODGING (1), STATE_SKILL_CASTING (2),
## STATE_PAUSED (3), or STATE_DEAD (4).
func get_state() -> int:
	return _state

# ---------------------------------------------------------------------------
# Shoot resume — flash-resume after dodge (Story 003)
# ---------------------------------------------------------------------------

## Returns true if a shoot-resume is pending (flash-resume after dodge).
##
## When a dodge ends and the player is still holding the shoot key, a
## "shoot resume pending" flag is set. ShootingSystem can read this to
## immediately resume firing without requiring the player to release
## and re-press the shoot button.
func is_shoot_resume_pending() -> bool:
	return _shoot_resume_pending

## Consumes and returns the shoot-resume pending flag.
##
## Call this once to check and clear the flag. Returns true if a
## shoot-resume was pending. After this call, the flag is reset to false
## and subsequent calls return false until the next dodge ends with
## shoot held.
##
## Returns: true if a shoot-resume was pending before this call.
func consume_shoot_resume() -> bool:
	var was_pending := _shoot_resume_pending
	_shoot_resume_pending = false
	return was_pending

# ---------------------------------------------------------------------------
# Pause / focus API (Story 004)
# ---------------------------------------------------------------------------

## Returns true if the game is currently paused.
##
## This is true when the input state is STATE_PAUSED. It covers both
## manual Esc pause and automatic focus-loss pause.
func is_game_paused() -> bool:
	return _state == STATE_PAUSED

# ---------------------------------------------------------------------------
# Dodge buffer / availability public API
# ---------------------------------------------------------------------------

## Returns true if a dodge press is currently buffered (pressed while
## unavailable, waiting for availability to be restored).
func is_dodge_buffered() -> bool:
	return _dodge_buffered

## Consumes and returns the current dodge buffer state.
##
## After this call, the buffer is cleared. Use this when a system wants
## to manually consume the buffered dodge (e.g., to cancel it rather than
## let it auto-fire).
##
## Returns: true if a dodge was buffered before this call.
func consume_dodge_buffer() -> bool:
	var was_buffered := _dodge_buffered
	_dodge_buffered = false
	return was_buffered

## Sets dodge availability controlled by the DodgeSystem.
##
## [param available]: true when dodge can execute, false during cooldown.
## [param remaining_ms]: cooldown time remaining (informational, for UI).
func set_dodge_availability(available: bool, remaining_ms: int = 0) -> void:
	_dodge_available = available
	_dodge_remaining_ms = remaining_ms

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Converts the mouse screen position to a world-space direction vector
## relative to the player.
func _compute_aim_direction() -> Vector2:
	if player_node == null:
		return Vector2.ZERO

	var mouse_world := player_node.get_global_mouse_position()
	var direction := mouse_world - player_node.global_position

	# Zero-vector guard: avoid normalizing a zero-length vector.
	if direction.length_squared() < 0.0001:
		return Vector2.ZERO

	return direction.normalized()
