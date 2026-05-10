extends GutTest

# ---------------------------------------------------------------------------
# Mock classes -- simulate full system interactions
# ---------------------------------------------------------------------------

class MockInputSystem extends RefCounted:
	var current_state: int = 0
	var state_log: Array[int] = []

	func set_state(new_state: int) -> void:
		current_state = new_state
		state_log.append(new_state)

	func get_state() -> int:
		return current_state


class MockDodgeSystem extends RefCounted:
	var _is_invincible: bool = false
	func is_invincible() -> bool:
		return _is_invincible


class MockSkillSystem extends RefCounted:
	var _skill2_open: bool = false
	var _consumed_count: int = 0

	func is_skill2_window_open() -> bool:
		return _skill2_open

	func consume_skill2() -> void:
		_consumed_count += 1
		_skill2_open = false


class MockSceneManager extends RefCounted:
	var switch_calls: Array[Dictionary] = []

	func switch_to(scene_id: int, data: Dictionary = {}) -> void:
		switch_calls.append({"scene_id": scene_id, "data": data})


class MockEventBus extends RefCounted:
	var player_hit_calls: Array[Dictionary] = []
	var player_death_calls: int = 0
	var enemy_killed_calls: Array[Dictionary] = []

	func has_signal(sig: String) -> bool:
		return true

	func connect(sig: String, callable: Callable) -> void:
		pass


# ---------------------------------------------------------------------------
# Full damage-health pipeline host
# ---------------------------------------------------------------------------

class PipelineHost extends Node:
	var _hp: int = 3
	var _shield: int = 0
	var _iframe_end_ms: int = 0
	var _shield_expiry_ms: int = 0
	var _is_dead: bool = false
	var _death_freeze_start_ms: int = 0
	var _death_transition_started: bool = false
	var _build_bonus: int = 0
	var dodge_system: RefCounted = null
	var skill_system: RefCounted = null
	var input_system: RefCounted = null
	var scene_manager: RefCounted = null
	var event_bus: RefCounted = null

	const MAX_HP: int = 3
	const IFRAME_MS: int = 500
	const SHIELD_DURATION_S: float = 3.0
	const BASE_DAMAGE: int = 1
	const DEATH_SCREEN_DELAY_MS: int = 500

	func get_hp() -> int:
		return _hp

	func is_alive() -> bool:
		return not _is_dead

	func is_dead() -> bool:
		return _is_dead

	func _is_in_iframes() -> bool:
		return Time.get_ticks_msec() < _iframe_end_ms

	func take_damage(incoming: int, source_pos: Vector2 = Vector2.ZERO) -> bool:
		if not is_alive():
			return false
		if dodge_system != null and dodge_system.is_invincible():
			return false
		if _is_in_iframes():
			return false

		var remaining := incoming
		if _shield > 0:
			var absorbed := mini(_shield, remaining)
			_shield -= absorbed
			remaining -= absorbed

		if remaining > 0:
			_hp -= remaining
			if _hp <= 0:
				_hp = 0
				_is_dead = true
				_death_freeze_start_ms = Time.get_ticks_msec()
				if input_system != null:
					input_system.set_state(4)  # STATE_DEAD
				if event_bus != null:
					event_bus.player_death_calls += 1
			else:
				_iframe_end_ms = Time.get_ticks_msec() + IFRAME_MS
			return true
		return false

	func _simulate_death_transition() -> void:
		if not _is_dead or _death_transition_started:
			return
		if Time.get_ticks_msec() - _death_freeze_start_ms >= DEATH_SCREEN_DELAY_MS:
			_death_transition_started = true
			if scene_manager != null:
				scene_manager.switch_to(2)  # DEATH_SCREEN

	func compute_player_damage() -> int:
		var base := BASE_DAMAGE + _build_bonus
		var mult := 1
		if skill_system != null and skill_system.is_skill2_window_open():
			mult = 2
			skill_system.consume_skill2()
		return base * mult


# ---------------------------------------------------------------------------
# Test fixture
# ---------------------------------------------------------------------------

var _host: PipelineHost = null
var _mock_dodge: MockDodgeSystem = null
var _mock_input: MockInputSystem = null
var _mock_skill: MockSkillSystem = null
var _mock_scene: MockSceneManager = null
var _mock_bus: MockEventBus = null

func before_each() -> void:
	_host = PipelineHost.new()
	_mock_dodge = MockDodgeSystem.new()
	_mock_input = MockInputSystem.new()
	_mock_skill = MockSkillSystem.new()
	_mock_scene = MockSceneManager.new()
	_mock_bus = MockEventBus.new()
	_host.dodge_system = _mock_dodge
	_host.input_system = _mock_input
	_host.skill_system = _mock_skill
	_host.scene_manager = _mock_scene
	_host.event_bus = _mock_bus
	add_child_autofree(_host)

func after_each() -> void:
	_host = null
	_mock_dodge = null
	_mock_input = null
	_mock_skill = null
	_mock_scene = null
	_mock_bus = null


# ---------------------------------------------------------------------------
# Death pipeline: fatal damage -> death -> freeze -> transition
# ---------------------------------------------------------------------------

func test_fatal_damage_triggers_death_flag() -> void:
	_host.take_damage(3)
	assert_true(_host.is_dead(), "Player should be dead after fatal damage")

func test_fatal_damage_sets_death_freeze_timestamp() -> void:
	var before := Time.get_ticks_msec()
	_host.take_damage(3)
	assert_ge(_host._death_freeze_start_ms, before, "Death timestamp should be recorded")

func test_fatal_damage_sets_input_state_to_dead() -> void:
	_host.take_damage(3)
	assert_eq(_mock_input.current_state, 4, "Input state should be set to STATE_DEAD (4)")

func test_fatal_damage_emits_player_death() -> void:
	assert_eq(_mock_bus.player_death_calls, 0, "No death calls before death")
	_host.take_damage(3)
	assert_gt(_mock_bus.player_death_calls, 0, "Player death should be emitted")

func test_death_blocks_subsequent_damage() -> void:
	_host.take_damage(3)  # Kill
	var hp_after_death := _host.get_hp()
	_host.take_damage(1)   # Should be ignored
	assert_eq(_host.get_hp(), hp_after_death, "Dead player should not take further damage")

func test_death_transition_after_delay() -> void:
	_host.take_damage(3)
	# Initially, transition should not have started.
	assert_false(_host._death_transition_started, "Transition should not start immediately")
	# Simulate delay elapsed.
	_host._death_freeze_start_ms = Time.get_ticks_msec() - _host.DEATH_SCREEN_DELAY_MS - 1
	_host._simulate_death_transition()
	assert_true(_host._death_transition_started, "Transition should start after delay")

func test_death_transition_switches_to_death_screen() -> void:
	_host.take_damage(3)
	_host._death_freeze_start_ms = Time.get_ticks_msec() - _host.DEATH_SCREEN_DELAY_MS - 1
	_host._simulate_death_transition()
	assert_gt(_mock_scene.switch_calls.size(), 0, "Scene manager switch should be called")
	assert_eq(_mock_scene.switch_calls[0].scene_id, 2, "Should switch to DEATH_SCREEN (2)")

func test_death_transition_only_triggered_once() -> void:
	_host.take_damage(3)
	_host._death_freeze_start_ms = Time.get_ticks_msec() - _host.DEATH_SCREEN_DELAY_MS - 1
	_host._simulate_death_transition()
	var call_count := _mock_scene.switch_calls.size()
	_host._simulate_death_transition()  # Try again.
	assert_eq(_mock_scene.switch_calls.size(), call_count, "Transition should only happen once")


# ---------------------------------------------------------------------------
# Enemy damage pipeline: player -> enemy damage computation
# ---------------------------------------------------------------------------

func test_player_damage_base_value() -> void:
	var dmg := _host.compute_player_damage()
	assert_eq(dmg, 1, "Base player damage should be 1")

func test_player_damage_skill2_window_doubles() -> void:
	_mock_skill._skill2_open = true
	var dmg := _host.compute_player_damage()
	assert_eq(dmg, 2, "Damage should double during skill_2 window")

func test_player_damage_skill2_consumes_window() -> void:
	_mock_skill._skill2_open = true
	_host.compute_player_damage()
	assert_false(_mock_skill._skill2_open, "skill_2 window should be consumed after use")
	assert_eq(_mock_skill._consumed_count, 1, "consume_skill2 should be called once")

func test_player_damage_build_bonus_adds() -> void:
	_host._build_bonus = 2
	var dmg := _host.compute_player_damage()
	assert_eq(dmg, 3, "Damage should be 1+2 = 3 with build bonus 2")

func test_player_damage_build_bonus_and_skill2() -> void:
	_host._build_bonus = 1
	_mock_skill._skill2_open = true
	var dmg := _host.compute_player_damage()
	assert_eq(dmg, 4, "Damage should be (1+1)*2 = 4")


# ---------------------------------------------------------------------------
# Full death sequence: damage accumulation over time
# ---------------------------------------------------------------------------

func test_death_after_three_hits_from_full() -> void:
	# Hit 1.
	assert_true(_host.take_damage(1), "First hit should land")
	assert_eq(_host.get_hp(), 2, "HP should be 2 after first hit")
	# Clear iframes.
	_host._iframe_end_ms = 0
	# Hit 2.
	assert_true(_host.take_damage(1), "Second hit should land")
	assert_eq(_host.get_hp(), 1, "HP should be 1 after second hit")
	# Clear iframes.
	_host._iframe_end_ms = 0
	# Hit 3 -- fatal.
	assert_true(_host.take_damage(1), "Third hit should land and kill")
	assert_eq(_host.get_hp(), 0, "HP should be 0")
	assert_true(_host.is_dead(), "Should be dead")

func test_iframes_prevent_rapid_death() -> void:
	# Hit 1 triggers iframes.
	_host.take_damage(1)
	assert_eq(_host.get_hp(), 2)
	# Hit 2 while iframes are still active -- should be ignored.
	var hit_during_iframes := _host.take_damage(1)
	assert_false(hit_during_iframes, "Hit during iframes should not land")
	assert_eq(_host.get_hp(), 2, "HP should still be 2")
	# Clear iframes.
	_host._iframe_end_ms = 0
	# Now hit 2 lands.
	_host.take_damage(1)
	assert_eq(_host.get_hp(), 1)

func test_shield_extends_survival() -> void:
	_host._hp = 1
	_host._shield = 1
	# Hit that would be fatal gets absorbed by shield.
	_host.take_damage(1)
	assert_eq(_host._shield, 0, "Shield absorbed the hit")
	assert_eq(_host.get_hp(), 1, "HP preserved by shield")

func test_mixed_damage_sources_pipeline() -> void:
	# Simulation: player takes various damage across a fight.
	_host._hp = 3

	# Hit by small enemy (1 dmg).
	_host.take_damage(1)
	assert_eq(_host.get_hp(), 2)
	_host._iframe_end_ms = 0

	# Dodge active -- hit ignored.
	_mock_dodge._is_invincible = true
	assert_false(_host.take_damage(1), "Hit ignored during dodge")
	assert_eq(_host.get_hp(), 2, "HP unchanged during dodge")
	_mock_dodge._is_invincible = false

	# Hit by large enemy melee (2 dmg) -- fatal.
	_host.take_damage(2)
	assert_eq(_host.get_hp(), 0, "Fatal damage")
	assert_true(_host.is_dead(), "Should be dead")
	assert_eq(_mock_input.current_state, 4, "Input should be DEAD")


# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

func test_damage_exactly_hp_value() -> void:
	_host._hp = 2
	_host.take_damage(2)
	assert_eq(_host.get_hp(), 0, "HP should be exactly 0")
	assert_true(_host.is_dead(), "Should be dead")

func test_damage_exceeds_hp() -> void:
	_host._hp = 2
	_host.take_damage(10)
	assert_eq(_host.get_hp(), 0, "HP should be clamped to 0")
	assert_true(_host.is_dead(), "Should be dead")

func test_input_state_transitions_on_death() -> void:
	# Start in NORMAL state (0).
	_mock_input.current_state = 0
	_host.take_damage(3)
	assert_eq(_mock_input.current_state, 4, "State should go directly to STATE_DEAD")
	assert_eq(_mock_input.state_log.size(), 1, "Should have exactly 1 state transition")
	assert_eq(_mock_input.state_log[0], 4, "Transition should be to STATE_DEAD")

func test_player_damage_skill2_not_consumed_when_not_open() -> void:
	_mock_skill._skill2_open = false
	_mock_skill._consumed_count = 0
	_host.compute_player_damage()
	assert_eq(_mock_skill._consumed_count, 0, "consume_skill2 should not be called when window not open")
