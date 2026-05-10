extends Node

# ---------------------------------------------------------------------------
# Inner class -- per-run statistics and state
# ---------------------------------------------------------------------------

## Holds all stats for a single roguelike run.
class RunState:
	var wave: int = 0
	var kills: int = 0
	var build_choices: Array[String] = []
	var perfect_dodges: int = 0
	var total_damage_dealt: int = 0
	var start_time_ms: int = 0
	var end_time_ms: int = 0

# ---------------------------------------------------------------------------
# Public state
# ---------------------------------------------------------------------------

## The currently active run. null when not in a run.
var current_run: RunState = null

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Initializes a new RunState and records the start time via
## [method Time.get_ticks_msec] (real-time monotonic clock, per ADR-0001).
##
## Resets all stats to zero. Must be called before any run-active gameplay.
func start_new_run() -> void:
	current_run = RunState.new()
	current_run.start_time_ms = Time.get_ticks_msec()

## Finalizes the current run by recording the end time.
## Has no effect if called when [member current_run] is null.
func end_run() -> void:
	if current_run == null:
		return
	current_run.end_time_ms = Time.get_ticks_msec()

## Returns the run duration in seconds, precise to 0.1s.
##
## The duration is calculated as round((end_ms - start_ms) / 100.0) / 10.0
## which rounds to the nearest 100ms then converts to seconds with one
## decimal place of precision.
##
## Returns 0.0 if [method start_new_run] has not been called.
## If [method end_run] has not been called yet, uses the current time as end.
func get_run_duration_seconds() -> float:
	if current_run == null:
		return 0.0
	var end_ms: int = current_run.end_time_ms
	if end_ms == 0:
		end_ms = Time.get_ticks_msec()
	return round((end_ms - current_run.start_time_ms) / 100.0) / 10.0

## Increments the kill counter for the current run by 1.
## Has no effect if called when [member current_run] is null.
func record_kill() -> void:
	if current_run == null:
		return
	current_run.kills += 1
