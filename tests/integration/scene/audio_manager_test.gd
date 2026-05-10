extends GutTest

# Integration tests for AudioManager autoload (Story 003).
#
# Validates:
#   1. BGMState enum has 4 distinct values (NONE, MENU, COMBAT, DEATH)
#   2. Default _current_bgm is BGMState.NONE
#   3. crossfade_bgm() changes _current_bgm when coming from NONE
#   4. crossfade_bgm() is idempotent (same target = no-op)
#   5. crossfade_bgm() kills prior tween when target differs
#   6. AudioStreamPlayer child exists after _ready()
#   7. register_bgm_stream() stores stream in lookup
#   8. get_current_bgm() returns the correct state after crossfade
#   9. crossfade_bgm() with NONE->NONE is a no-op
#  10. Fast path when no stream registered (no crash)

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

var _am: AudioManager

func before_each() -> void:
	_am = AudioManager.new()
	add_child_autofree(_am)
	_am._ready()

func after_each() -> void:
	# Kill any in-progress tweens
	if _am != null and is_instance_valid(_am):
		if _am._active_tween != null and _am._active_tween.is_valid():
			_am._active_tween.kill()
		_am._active_tween = null

# ---------------------------------------------------------------------------
# AC 1: BGMState enum has 4 distinct values
# ---------------------------------------------------------------------------

func test_audio_manager_bgm_state_enum_has_four_values() -> void:
	var states := [
		AudioManager.BGMState.NONE,
		AudioManager.BGMState.MENU,
		AudioManager.BGMState.COMBAT,
		AudioManager.BGMState.DEATH,
	]
	for i in range(states.size()):
		for j in range(i + 1, states.size()):
			assert_ne(states[i], states[j],
				"BGMState values %d and %d should be distinct" % [states[i], states[j]])

# ---------------------------------------------------------------------------
# AC 2: Default _current_bgm is BGMState.NONE
# ---------------------------------------------------------------------------

func test_audio_manager_default_bgm_is_none() -> void:
	assert_eq(_am.get_current_bgm(), AudioManager.BGMState.NONE,
		"Default BGM should be NONE")
	assert_eq(_am._current_bgm, AudioManager.BGMState.NONE,
		"Internal _current_bgm should be NONE")

# ---------------------------------------------------------------------------
# AC 3: crossfade_bgm() changes _current_bgm (fast path from NONE)
# ---------------------------------------------------------------------------

func test_audio_manager_crossfade_from_none_sets_state_immediately() -> void:
	# From NONE, should take fast path -- no tween, immediate state change
	_am.crossfade_bgm(AudioManager.BGMState.MENU)
	assert_eq(_am.get_current_bgm(), AudioManager.BGMState.MENU,
		"crossfade from NONE to MENU should set state immediately")

func test_audio_manager_crossfade_from_none_to_multiple_targets() -> void:
	_am.crossfade_bgm(AudioManager.BGMState.COMBAT)
	assert_eq(_am.get_current_bgm(), AudioManager.BGMState.COMBAT)

	# Reset and try another
	var am2 := AudioManager.new()
	add_child_autofree(am2)
	am2._ready()
	am2.crossfade_bgm(AudioManager.BGMState.DEATH)
	assert_eq(am2.get_current_bgm(), AudioManager.BGMState.DEATH)

# ---------------------------------------------------------------------------
# AC 4: crossfade_bgm() is idempotent (same target = no-op)
# ---------------------------------------------------------------------------

func test_audio_manager_crossfade_idempotent_same_target() -> void:
	_am.crossfade_bgm(AudioManager.BGMState.MENU)
	assert_eq(_am.get_current_bgm(), AudioManager.BGMState.MENU)

	# Call again with same target -- should be a no-op
	var state_before := _am.get_current_bgm()
	_am.crossfade_bgm(AudioManager.BGMState.MENU)
	assert_eq(_am.get_current_bgm(), state_before,
		"Calling crossfade with same target should be a no-op")

# ---------------------------------------------------------------------------
# AC 4b: crossfade_bgm(NONE) from NONE is also a no-op
# ---------------------------------------------------------------------------

func test_audio_manager_crossfade_none_to_none_is_no_op() -> void:
	assert_eq(_am.get_current_bgm(), AudioManager.BGMState.NONE)
	_am.crossfade_bgm(AudioManager.BGMState.NONE)
	assert_eq(_am.get_current_bgm(), AudioManager.BGMState.NONE)
	# No tween should have been created
	assert_null(_am._active_tween,
		"No tween should be created for NONE->NONE transition")

# ---------------------------------------------------------------------------
# AC 5: crossfade_bgm() kills prior tween when target differs
# ---------------------------------------------------------------------------

func test_audio_manager_crossfade_kills_prior_tween_on_different_target() -> void:
	# Start a crossfade from MENU to COMBAT (this creates a tween since
	# _current_bgm is not NONE after the first call)
	_am.crossfade_bgm(AudioManager.BGMState.MENU)
	assert_eq(_am.get_current_bgm(), AudioManager.BGMState.MENU)

	# Now crossfade from MENU to COMBAT -- this should create a tween
	_am.crossfade_bgm(AudioManager.BGMState.COMBAT)
	# A tween should be active for the fade-out phase
	assert_not_null(_am._active_tween,
		"Crossfade between different non-NONE states should create a tween")

	# Call with a THIRD target while the tween is still running -- should
	# kill the old tween and start fresh
	var first_tween := _am._active_tween
	_am.crossfade_bgm(AudioManager.BGMState.DEATH)
	assert_ne(_am._active_tween, first_tween,
		"Calling crossfade with a different target should kill the old tween")
	# first_tween should now be invalid
	assert_false(is_instance_valid(first_tween),
		"Old tween should be killed when crossfade target changes")

# ---------------------------------------------------------------------------
# AC 6: AudioStreamPlayer child exists after _ready()
# ---------------------------------------------------------------------------

func test_audio_manager_has_audio_stream_player_child() -> void:
	assert_not_null(_am._bgm_player,
		"_bgm_player should be created in _ready()")
	assert_true(_am._bgm_player is AudioStreamPlayer,
		"_bgm_player should be an AudioStreamPlayer instance")
	# Confirm it is a child of AudioManager
	assert_true(_am._bgm_player in _am.get_children(),
		"AudioStreamPlayer should be a child of AudioManager")
	assert_eq(_am._bgm_player.bus, &"Master",
		"AudioStreamPlayer should be on the Master bus")

# ---------------------------------------------------------------------------
# AC 7: register_bgm_stream() stores stream in lookup
# ---------------------------------------------------------------------------

func test_audio_manager_register_bgm_stream_stores_reference() -> void:
	# Use a mock AudioStream — any AudioStream instance works
	var mock_stream := AudioStreamGenerator.new()
	_am.register_bgm_stream(AudioManager.BGMState.COMBAT, mock_stream)
	assert_true(_am._bgm_streams.has(AudioManager.BGMState.COMBAT),
		"Stream should be stored for COMBAT state")
	assert_eq(_am._bgm_streams[AudioManager.BGMState.COMBAT], mock_stream,
		"Registered stream should match the one passed in")

# ---------------------------------------------------------------------------
# AC 8: get_current_bgm() returns correct state after crossfade
# ---------------------------------------------------------------------------

func test_audio_manager_get_current_bgm_after_multiple_crossfades() -> void:
	_am.crossfade_bgm(AudioManager.BGMState.MENU)
	assert_eq(_am.get_current_bgm(), AudioManager.BGMState.MENU)

	_am.crossfade_bgm(AudioManager.BGMState.COMBAT)
	assert_eq(_am.get_current_bgm(), AudioManager.BGMState.COMBAT)

	_am.crossfade_bgm(AudioManager.BGMState.DEATH)
	assert_eq(_am.get_current_bgm(), AudioManager.BGMState.DEATH)

# ---------------------------------------------------------------------------
# AC 9: crossfade with no stream registered does not crash
# ---------------------------------------------------------------------------

func test_audio_manager_crossfade_without_registered_stream_no_crash() -> void:
	# No streams registered -- crossfade should still work (plays silence)
	_am.crossfade_bgm(AudioManager.BGMState.COMBAT)
	assert_eq(_am.get_current_bgm(), AudioManager.BGMState.COMBAT)
	# Should not crash -- the player just has a null stream

# ---------------------------------------------------------------------------
# AC 10: Volume is reset on fast path
# ---------------------------------------------------------------------------

func test_audio_manager_volume_reset_on_fast_path() -> void:
	_am._bgm_player.volume_db = -40.0  # Artificially lower the volume
	_am.crossfade_bgm(AudioManager.BGMState.MENU)
	assert_eq(_am._bgm_player.volume_db, AudioManager.NORMAL_DB,
		"Fast path should reset volume to NORMAL_DB")
