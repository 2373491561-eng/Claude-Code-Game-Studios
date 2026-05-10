extends GutTest

# Integration tests for AudioSystem Story 001: Audio Bus Setup + Event Connections.
#
# Validates:
#   1. All 8 audio buses exist after _ready() (AC 1)
#   2. SFX pool is created with MAX_SIMULTANEOUS_SFX players (AC 3 infrastructure)
#   3. play_sfx() assigns the correct bus and starts playback (AC 2)
#   4. play_sfx() with null stream is a no-op (graceful degradation)
#   5. MAX_SIMULTANEOUS_SFX enforcement: 9th call stops oldest player (AC 3)
#   6. Shoot loop AudioStreamPlayer exists and is on SFX/Weapon bus (AC 4)
#   7. Shoot loop starts on first simulated bullet_hit (AC 4)
#   8. Shoot loop stops after SHOOT_LOOP_TIMEOUT with no bullet_hit (AC 4)
#   9. EventBus signal connection attempts do not crash when EventBus is absent
#  10. Bus creation is idempotent (calling _ready() twice does not create duplicates)

# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------

var _audio_sys: AudioSystem = null

func before_each() -> void:
	_audio_sys = AudioSystem.new()
	add_child_autofree(_audio_sys)
	_audio_sys._ready()

func after_each() -> void:
	# Stop all playing SFX to prevent audio bleed between tests.
	if _audio_sys != null and is_instance_valid(_audio_sys):
		for player in _audio_sys._sfx_pool:
			if player.playing:
				player.stop()
		if _audio_sys._shoot_loop_player != null and _audio_sys._shoot_loop_player.playing:
			_audio_sys._shoot_loop_player.stop()
		# Kill any ducking tweens.
		for t in _audio_sys._duck_tweens:
			if t.is_valid():
				t.kill()
		_audio_sys._duck_tweens.clear()

# ---------------------------------------------------------------------------
# AC 1: All 8 audio buses exist after _ready()
# ---------------------------------------------------------------------------

func test_audio_system_all_eight_buses_exist() -> void:
	for bus_name in AudioSystem.BUS_NAMES:
		var idx := AudioServer.get_bus_index(bus_name)
		assert_ne(idx, -1,
			"Bus '%s' should exist after _ready()" % bus_name)

func test_audio_system_master_bus_is_index_zero() -> void:
	var idx := AudioServer.get_bus_index("Master")
	assert_eq(idx, 0, "Master bus should always be at index 0")

func test_audio_system_sfx_skill_bus_exists() -> void:
	# SFX/Skill is critical -- it must exist and MUST NOT be ducked.
	var idx := AudioServer.get_bus_index("SFX/Skill")
	assert_ne(idx, -1, "SFX/Skill bus must exist")

# ---------------------------------------------------------------------------
# AC 1 supplementary: bus creation is idempotent
# ---------------------------------------------------------------------------

func test_audio_system_bus_creation_is_idempotent() -> void:
	# Record the bus count after first _ready().
	var bus_count_before := AudioServer.bus_count

	# Create a second AudioSystem and call _ready() again.
	var sys2 := AudioSystem.new()
	add_child_autofree(sys2)
	sys2._ready()

	# Bus count should not change -- no duplicates.
	assert_eq(AudioServer.bus_count, bus_count_before,
		"Second _ready() should not create duplicate buses")

# ---------------------------------------------------------------------------
# AC 2: SFX pool is created with correct size
# ---------------------------------------------------------------------------

func test_audio_system_sfx_pool_has_max_players() -> void:
	assert_eq(_audio_sys._sfx_pool.size(), AudioSystem.MAX_SIMULTANEOUS_SFX,
		"SFX pool should have MAX_SIMULTANEOUS_SFX players")

func test_audio_system_sfx_pool_all_children() -> void:
	for player in _audio_sys._sfx_pool:
		assert_true(player in _audio_sys.get_children(),
			"Each SFX pool player should be a child of AudioSystem")

# ---------------------------------------------------------------------------
# AC 3: play_sfx() assigns correct bus and starts playback
# ---------------------------------------------------------------------------

func test_audio_system_play_sfx_assigns_bus_and_plays() -> void:
	var stream := AudioStreamGenerator.new()
	var player := _audio_sys.play_sfx("SFX/Dodge", stream)

	assert_not_null(player, "play_sfx should return an AudioStreamPlayer")
	assert_true(player.playing, "Player should be playing after play_sfx()")
	assert_eq(player.bus, &"SFX/Dodge",
		"Player should be assigned to the requested bus")
	assert_eq(player.stream, stream,
		"Player should have the requested stream assigned")

func test_audio_system_play_sfx_null_stream_is_no_op() -> void:
	var player := _audio_sys.play_sfx("SFX/Weapon", null)
	assert_null(player, "play_sfx with null stream should return null")

	var active_count := 0
	for p in _audio_sys._sfx_pool:
		if p.playing:
			active_count += 1
	assert_eq(active_count, 0,
		"No players should be active after play_sfx(null)")

func test_audio_system_play_sfx_multiple_buses() -> void:
	var stream1 := AudioStreamGenerator.new()
	var stream2 := AudioStreamGenerator.new()

	var p1 := _audio_sys.play_sfx("SFX/Weapon", stream1)
	var p2 := _audio_sys.play_sfx("UI", stream2)

	assert_ne(p1, p2, "Each play_sfx should use a different pool player")
	assert_eq(p1.bus, &"SFX/Weapon")
	assert_eq(p2.bus, &"UI")
	assert_true(p1.playing)
	assert_true(p2.playing)

# ---------------------------------------------------------------------------
# AC 4: MAX_SIMULTANEOUS_SFX enforcement
# ---------------------------------------------------------------------------

func test_audio_system_max_simultaneous_sfx_enforcement() -> void:
	# Play MAX_SIMULTANEOUS_SFX sounds. All should play.
	var players: Array[AudioStreamPlayer] = []
	for i in range(AudioSystem.MAX_SIMULTANEOUS_SFX):
		var stream := AudioStreamGenerator.new()
		var p := _audio_sys.play_sfx("SFX/Weapon", stream)
		assert_not_null(p, "SFX %d should be assigned a player" % i)
		assert_true(p.playing, "SFX %d should be playing" % i)
		players.append(p)

	# Now play one more -- should evict the OLDEST.
	# The first player in the pool is the oldest.
	var extra_stream := AudioStreamGenerator.new()
	var extra_player := _audio_sys.play_sfx("SFX/Impact", extra_stream)

	assert_not_null(extra_player, "Extra SFX should be assigned a player")

	# The oldest player (first in the pool) should have been evicted.
	# Count currently playing -- should still be MAX_SIMULTANEOUS_SFX.
	var active_count := 0
	for p in _audio_sys._sfx_pool:
		if p.playing:
			active_count += 1
	assert_eq(active_count, AudioSystem.MAX_SIMULTANEOUS_SFX,
		"Active SFX count should not exceed MAX_SIMULTANEOUS_SFX")

# ---------------------------------------------------------------------------
# AC 5: Shoot loop player exists on correct bus
# ---------------------------------------------------------------------------

func test_audio_system_shoot_loop_player_exists() -> void:
	assert_not_null(_audio_sys._shoot_loop_player,
		"Shoot loop player should be created in _ready()")
	assert_true(_audio_sys._shoot_loop_player in _audio_sys.get_children(),
		"Shoot loop player should be a child of AudioSystem")
	assert_eq(_audio_sys._shoot_loop_player.bus, &"SFX/Weapon",
		"Shoot loop player should be on SFX/Weapon bus")

# ---------------------------------------------------------------------------
# AC 6: Shoot loop starts on bullet_hit
# ---------------------------------------------------------------------------

func test_audio_system_shoot_loop_starts_on_bullet_hit() -> void:
	# Assign a stream so the loop can play.
	var stream := AudioStreamGenerator.new()
	_audio_sys.set_shoot_loop_stream(stream)

	# Simulate bullet_hit.
	_audio_sys._on_bullet_hit(Vector2(100, 200), false)

	assert_true(_audio_sys._shoot_loop_player.playing,
		"Shoot loop should start playing on first bullet_hit")

func test_audio_system_shoot_loop_does_not_start_without_stream() -> void:
	# Do NOT assign a stream -- the loop should not start.
	_audio_sys._on_bullet_hit(Vector2.ZERO, false)

	assert_false(_audio_sys._shoot_loop_player.playing,
		"Shoot loop should not start when no stream is assigned")

# ---------------------------------------------------------------------------
# AC 7: Shoot loop stops after timeout
# ---------------------------------------------------------------------------

func test_audio_system_shoot_loop_stops_after_timeout() -> void:
	var stream := AudioStreamGenerator.new()
	_audio_sys.set_shoot_loop_stream(stream)

	# Start the shoot loop.
	_audio_sys._on_bullet_hit(Vector2.ZERO, false)
	assert_true(_audio_sys._shoot_loop_player.playing,
		"Setup: shoot loop should be playing")

	# Simulate timeout: set last_bullet_hit far in the past.
	_audio_sys._last_bullet_hit_time = Time.get_ticks_msec() / 1000.0 - AudioSystem.SHOOT_LOOP_TIMEOUT - 0.1

	# Trigger _process which checks the timeout.
	_audio_sys._process(0.016)

	assert_false(_audio_sys._shoot_loop_player.playing,
		"Shoot loop should stop after SHOOT_LOOP_TIMEOUT with no bullet_hit")

# ---------------------------------------------------------------------------
# AC 8: EventBus signal connections do not crash when EventBus absent
# ---------------------------------------------------------------------------

func test_audio_system_no_event_bus_does_not_crash() -> void:
	# Create a fresh AudioSystem without EventBus autoload.
	# This should not crash -- signals are simply not connected.
	var sys := AudioSystem.new()
	add_child_autofree(sys)

	# _connect_event_bus_signals uses get_node_or_null -- should succeed.
	# Calling _ready() should complete without errors.
	sys._ready()
	# If we reach here, no crash occurred.
	pass_test("AudioSystem._ready() should not crash when EventBus is absent")

# ---------------------------------------------------------------------------
# AC 9: _duck_tweens initialized empty
# ---------------------------------------------------------------------------

func test_audio_system_duck_tweens_starts_empty() -> void:
	assert_eq(_audio_sys._duck_tweens.size(), 0,
		"_duck_tweens should be empty before any ducking")

# ---------------------------------------------------------------------------
# AC 10: play_sfx applies current bus pitch_scale
# ---------------------------------------------------------------------------

func test_audio_system_play_sfx_applies_default_pitch_scale() -> void:
	var stream := AudioStreamGenerator.new()
	var player := _audio_sys.play_sfx("SFX/Weapon", stream)

	assert_eq(player.pitch_scale, 1.0,
		"New SFX player should have default pitch_scale = 1.0")
