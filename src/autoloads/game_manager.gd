extends Node
var current_run = null

class RunState:
	var wave: int = 0
	var kills: int = 0
	var build_choices: Array = []
	var perfect_dodges: int = 0
	var total_damage_dealt: int = 0
	var start_time_ms: int = 0
	var end_time_ms: int = 0

func start_new_run() -> void:
	current_run = RunState.new()
	current_run.start_time_ms = Time.get_ticks_msec()

func end_run() -> void:
	if current_run:
		current_run.end_time_ms = Time.get_ticks_msec()

func record_kill() -> void:
	if current_run:
		current_run.kills += 1

func get_run_duration_seconds() -> float:
	if current_run and current_run.start_time_ms > 0:
		return round((current_run.end_time_ms - current_run.start_time_ms) / 100.0) / 10.0
	return 0.0
