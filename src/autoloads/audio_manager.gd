extends Node
enum BGMState { NONE, MENU, COMBAT, DEATH }
var _current_bgm: int = BGMState.NONE

func crossfade_bgm(_target: int, _duration: float = 0.5) -> void:
	_current_bgm = _target

func get_current_bgm() -> int:
	return _current_bgm
