extends Node

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Background music states corresponding to each scene / game phase.
enum BGMState { NONE, MENU, COMBAT, DEATH }

## Volume in dB when "silent" during a crossfade.
const SILENT_DB: float = -80.0

## Default playback volume in dB.
const NORMAL_DB: float = 0.0

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## The currently active (or transitioning-to) BGM state.
var _current_bgm: BGMState = BGMState.NONE

## The AudioStreamPlayer child used for playback.
var _bgm_player: AudioStreamPlayer = null

## Reference to the currently active crossfade tween, if any.
var _active_tween: Tween = null

## Maps BGMState values to AudioStream resources.
var _bgm_streams: Dictionary = {}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = &"Master"
	add_child(_bgm_player)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Crossfades the background music to [param target] over [param duration]
## seconds.
##
## If [param target] equals the currently playing BGM, this is a no-op
## (idempotent).
##
## The crossfade sequence is: fade current track to silence over duration/2,
## switch to the target stream, fade in to normal volume over duration/2.
## Total transition time equals [param duration].
##
## If no BGM is currently playing ([member BGMState.NONE] or no stream
## registered), the target begins immediately at full volume.
##
## The tween uses [method Tween.set_ignore_time_scale] per ADR-0001 so the
## crossfade proceeds in real time regardless of [member Engine.time_scale].
func crossfade_bgm(target: BGMState, duration: float = 0.5) -> void:
	if _current_bgm == target:
		return

	# Kill any in-progress crossfade
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null

	var half_duration := duration / 2.0

	# Fast path: no current BGM -- start the target immediately
	if _current_bgm == BGMState.NONE or _bgm_player == null:
		_set_bgm_stream(target)
		if _bgm_player != null:
			_bgm_player.volume_db = NORMAL_DB
			_bgm_player.play()
		_current_bgm = target
		return

	# Crossfade sequence: fade out -> switch -> fade in
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	_active_tween = tween

	tween.tween_property(_bgm_player, "volume_db", SILENT_DB, half_duration)
	tween.tween_callback(_switch_bgm.bind(target))
	tween.tween_property(_bgm_player, "volume_db", NORMAL_DB, half_duration)
	tween.tween_callback(_on_crossfade_complete)

## Returns the currently active BGM state.
func get_current_bgm() -> BGMState:
	return _current_bgm

## Registers an [AudioStream] for a given [BGMState].
##
## Call this from game.tscn or a resource loader to associate audio files
## with BGM states. Unregistered states will play silence when crossfaded to.
func register_bgm_stream(state: BGMState, stream: AudioStream) -> void:
	_bgm_streams[state] = stream

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

## Assigns the AudioStream for [param target] to the player.
## If no stream is registered, sets stream to null (produces silence).
func _set_bgm_stream(target: BGMState) -> void:
	if _bgm_player == null:
		return
	if _bgm_streams.has(target):
		_bgm_player.stream = _bgm_streams[target]
	else:
		_bgm_player.stream = null

## Tween callback: switches the stream to the target BGM and updates state.
func _switch_bgm(target: BGMState) -> void:
	_set_bgm_stream(target)
	_current_bgm = target
	if _bgm_player != null and _bgm_player.stream != null and not _bgm_player.playing:
		_bgm_player.play()

## Tween callback: clears the active tween reference after crossfade completes.
func _on_crossfade_complete() -> void:
	_active_tween = null
