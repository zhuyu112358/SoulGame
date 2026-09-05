extends Node
## TimeManager - Game time management, tick scheduling, timers, and time events
##
## Manages game time scaling, fixed timestep ticks, scheduled callbacks,
## named timers, time-of-day tracking, and frame rate statistics.
## This is infrastructure - no game logic.
##
## Features:
## - Time scaling (slow motion, fast forward, pause)
## - Fixed timestep ticks (configurable rate)
## - One-time and repeating scheduled callbacks
## - Named timers with pause/resume
## - Tick-based scheduling
## - Time-of-day with day phases
## - Frame rate and frame time statistics
##
## Usage:
##   TimeManager.set_time_scale(0.5)  # slow motion
##   TimeManager.schedule_once(5.0, self, "_on_timer")
##   var id = TimeManager.schedule_repeating(1.0, self, "_on_tick")
##   TimeManager.start_named_timer("ability_cd", 10.0)
##   TimeManager.cancel(id)

## Current game time (scaled)
var _game_time: float = 0.0

## Real time since start (unscaled)
var _real_time: float = 0.0

## Time scale (1.0 = normal, 0.5 = slow, 2.0 = fast, 0 = paused)
var _time_scale: float = 1.0

## Fixed timestep for game ticks (seconds)
var _fixed_timestep: float = 0.05  # 20 ticks per second

## Accumulator for fixed timestep
var _accumulator: float = 0.0

## Current tick count
var _tick_count: int = 0

## Scheduled callbacks: { id: {time, interval, repeating, target, method, args, active, created_at} }
var _scheduled: Dictionary = {}

## Next schedule ID
var _next_schedule_id: int = 1

## Named timers: { name: {remaining, duration, paused, auto_remove} }
var _named_timers: Dictionary = {}

## Tick-based schedules: { tick: [{target, method, args}] }
var _tick_schedules: Dictionary = {}

## Time of day (0.0 - 24.0)
var _time_of_day: float = 12.0

## Day length in real seconds (for time-of-day progression)
var _day_length_seconds: float = 1200.0  # 20 minutes per day

## Whether time-of-day progresses automatically
var _auto_progression: bool = false

## Pause state
var _paused: bool = false

## --- Frame Statistics ---

## Frame time history for FPS calculation
var _frame_times: Array = []

## Max frame times to track
var _max_frame_samples: int = 120

## Frame time stats
var _frame_stats: Dictionary = {
	"min_ms": 9999.0,
	"max_ms": 0.0,
	"avg_ms": 0.0,
	"total_frames": 0
}

## Statistics
var _stats: Dictionary = {
	"total_ticks": 0,
	"scheduled_total": 0,
	"scheduled_active": 0,
	"max_frame_time": 0.0,
	"named_timers": 0,
	"tick_schedules": 0,
	"timer_expirations": 0
}


func _ready() -> void:
	GameLog.info("TimeManager initialized (tick_rate=%.0f Hz)" % (1.0 / _fixed_timestep), "Time")


func _process(delta: float) -> void:
	# Track frame stats (always, even when paused)
	_track_frame(delta)

	if _paused:
		return

	_real_time += delta
	var scaled_delta := delta * _time_scale
	_game_time += scaled_delta

	# Fixed timestep accumulation
	_accumulator += scaled_delta
	while _accumulator >= _fixed_timestep:
		_accumulator -= _fixed_timestep
		_fixed_tick(_fixed_timestep)

	# Time of day progression
	if _auto_progression:
		_time_of_day += (scaled_delta / _day_length_seconds) * 24.0
		if _time_of_day >= 24.0:
			_time_of_day -= 24.0

	# Process scheduled callbacks
	_process_scheduled(scaled_delta)

	# Process named timers
	_process_named_timers(scaled_delta)


## Fixed timestep update (called at fixed rate)
func _fixed_tick(delta: float) -> void:
	_tick_count += 1
	_stats["total_ticks"] += 1
	GameState.increment_tick()
	EventBus.emit("fixed_tick", {"tick": _tick_count, "delta": delta})

	# Process tick-based schedules
	if _tick_schedules.has(_tick_count):
		for schedule in _tick_schedules[_tick_count]:
			if schedule["target"] and is_instance_valid(schedule["target"]):
				schedule["target"].call(schedule["method"], schedule["args"])
		_tick_schedules.erase(_tick_count)
		_stats["tick_schedules"] = _tick_schedules.size()


## Process scheduled callbacks
func _process_scheduled(delta: float) -> void:
	var to_remove := []

	for id in _scheduled:
		var item = _scheduled[id]
		if not item["active"]:
			to_remove.append(id)
			continue

		item["time"] -= delta
		if item["time"] <= 0.0:
			# Execute callback
			if item["target"] and is_instance_valid(item["target"]):
				item["target"].call(item["method"], item["args"])

			if item["repeating"]:
				item["time"] = item["interval"]
			else:
				item["active"] = false
				to_remove.append(id)

	for id in to_remove:
		_scheduled.erase(id)

	_stats["scheduled_active"] = _scheduled.size()


## Process named timers
func _process_named_timers(delta: float) -> void:
	var to_remove := []

	for name in _named_timers:
		var timer = _named_timers[name]
		if timer["paused"]:
			continue

		timer["remaining"] -= delta
		if timer["remaining"] <= 0.0:
			_stats["timer_expirations"] += 1
			EventBus.emit("timer_expired", {"name": name, "duration": timer["duration"]})
			if timer["auto_remove"]:
				to_remove.append(name)
			else:
				timer["remaining"] = 0.0

	for name in to_remove:
		_named_timers.erase(name)

	_stats["named_timers"] = _named_timers.size()


## --- Scheduling ---

## Schedule a one-time callback
## Returns schedule ID for cancellation
func schedule_once(delay: float, target: Object, method: String, args: Dictionary = {}) -> int:
	return _add_schedule(delay, false, target, method, args)


## Schedule a repeating callback
## Returns schedule ID for cancellation
func schedule_repeating(interval: float, target: Object, method: String, args: Dictionary = {}) -> int:
	return _add_schedule(interval, true, target, method, args)


## Schedule a callback after N ticks
func schedule_after_ticks(ticks: int, target: Object, method: String, args: Dictionary = {}) -> void:
	var target_tick := _tick_count + max(ticks, 1)
	if not _tick_schedules.has(target_tick):
		_tick_schedules[target_tick] = []
	_tick_schedules[target_tick].append({
		"target": target,
		"method": StringName(method),
		"args": args
	})
	_stats["tick_schedules"] = _tick_schedules.size()


## Cancel a scheduled callback
func cancel(schedule_id: int) -> void:
	if _scheduled.has(schedule_id):
		_scheduled[schedule_id]["active"] = false
		GameLog.debug("TimeManager: Cancelled schedule %d" % schedule_id, "Time")


## Cancel all scheduled callbacks
func cancel_all() -> void:
	for id in _scheduled:
		_scheduled[id]["active"] = false
	GameLog.info("TimeManager: Cancelled all schedules", "Time")


## Check if a schedule is active
func is_scheduled(schedule_id: int) -> bool:
	return _scheduled.has(schedule_id) and _scheduled[schedule_id]["active"]


## Get remaining time for a schedule
func get_schedule_remaining(schedule_id: int) -> float:
	if _scheduled.has(schedule_id) and _scheduled[schedule_id]["active"]:
		return _scheduled[schedule_id]["time"]
	return 0.0


## --- Named Timers ---

## Start a named timer
func start_named_timer(name: String, duration: float, auto_remove: bool = true) -> void:
	_named_timers[name] = {
		"remaining": duration,
		"duration": duration,
		"paused": false,
		"auto_remove": auto_remove
	}
	_stats["named_timers"] = _named_timers.size()
	GameLog.debug("TimeManager: Started timer '%s' (%.2fs)" % [name, duration], "Time")


## Get remaining time for a named timer
func get_timer_remaining(name: String) -> float:
	if _named_timers.has(name):
		return max(_named_timers[name]["remaining"], 0.0)
	return 0.0


## Check if a named timer is active (remaining > 0)
func is_timer_active(name: String) -> bool:
	return _named_timers.has(name) and _named_timers[name]["remaining"] > 0.0


## Pause a named timer
func pause_timer(name: String) -> void:
	if _named_timers.has(name):
		_named_timers[name]["paused"] = true


## Resume a named timer
func resume_timer(name: String) -> void:
	if _named_timers.has(name):
		_named_timers[name]["paused"] = false


## Cancel a named timer
func cancel_timer(name: String) -> void:
	if _named_timers.has(name):
		_named_timers.erase(name)
		_stats["named_timers"] = _named_timers.size()


## Get all active named timers
func get_active_timers() -> Dictionary:
	var result := {}
	for name in _named_timers:
		if _named_timers[name]["remaining"] > 0.0:
			result[name] = _named_timers[name].duplicate()
	return result


## --- Time Scale ---

## Set time scale (1.0 = normal, 0 = paused)
func set_time_scale(scale: float) -> void:
	_time_scale = clamp(scale, 0.0, 10.0)
	GameState.set_world_state("time_scale", _time_scale)
	GameLog.info("TimeManager: Time scale set to %.2f" % _time_scale, "Time")
	EventBus.emit("time_scale_changed", {"scale": _time_scale})


## Get current time scale
func get_time_scale() -> float:
	return _time_scale


## Get game time (scaled)
func get_game_time() -> float:
	return _game_time


## Get real time (unscaled)
func get_real_time() -> float:
	return _real_time


## Get current tick count
func get_tick_count() -> int:
	return _tick_count


## Get fixed timestep
func get_fixed_timestep() -> float:
	return _fixed_timestep


## Set fixed timestep (tick rate)
func set_tick_rate(ticks_per_second: int) -> void:
	_fixed_timestep = 1.0 / float(max(ticks_per_second, 1))
	GameLog.info("TimeManager: Tick rate set to %d Hz" % ticks_per_second, "Time")


## --- Pause ---

## Pause game time
func pause() -> void:
	_paused = true
	GameState.set_value("game", "paused", true)
	EventBus.emit("game_paused", {})
	GameLog.info("TimeManager: Paused", "Time")


## Resume game time
func resume() -> void:
	_paused = false
	GameState.set_value("game", "paused", false)
	EventBus.emit("game_resumed", {})
	GameLog.info("TimeManager: Resumed", "Time")


## Check if paused
func is_paused() -> bool:
	return _paused


## --- Time of Day ---

## Set time of day (0-24)
func set_time_of_day(hour: float) -> void:
	_time_of_day = clamp(hour, 0.0, 24.0)


## Get time of day (0-24)
func get_time_of_day() -> float:
	return _time_of_day


## Get time of day as string (HH:MM)
func get_time_of_day_string() -> String:
	var hours := int(_time_of_day)
	var minutes := int((_time_of_day - hours) * 60)
	return "%02d:%02d" % [hours, minutes]


## Enable/disable auto time progression
func set_auto_progression(enabled: bool) -> void:
	_auto_progression = enabled


## Set day length in seconds
func set_day_length(seconds: float) -> void:
	_day_length_seconds = max(seconds, 1.0)


## Get day phase: "night", "morning", "day", "evening"
func get_day_phase() -> String:
	if _time_of_day < 6.0 or _time_of_day >= 20.0:
		return "night"
	elif _time_of_day < 10.0:
		return "morning"
	elif _time_of_day < 17.0:
		return "day"
	else:
		return "evening"


## --- Frame Statistics ---

## Track frame time
func _track_frame(delta: float) -> void:
	var ms := delta * 1000.0
	_frame_times.append(ms)
	if _frame_times.size() > _max_frame_samples:
		_frame_times.pop_front()

	_frame_stats["total_frames"] += 1
	if ms < _frame_stats["min_ms"]:
		_frame_stats["min_ms"] = ms
	if ms > _frame_stats["max_ms"]:
		_frame_stats["max_ms"] = ms
	if _frame_times.size() > 0:
		_frame_stats["avg_ms"] = _frame_times.reduce(func(a, b): return a + b, 0.0) / _frame_times.size()


## Get current FPS (based on recent frame times)
func get_fps() -> float:
	if _frame_times.is_empty() or _frame_stats["avg_ms"] <= 0.0:
		return 0.0
	return 1000.0 / _frame_stats["avg_ms"]


## Get frame statistics
func get_frame_stats() -> Dictionary:
	return {
		"fps": get_fps(),
		"min_ms": _frame_stats["min_ms"] if _frame_stats["min_ms"] < 9999.0 else 0.0,
		"max_ms": _frame_stats["max_ms"],
		"avg_ms": _frame_stats["avg_ms"],
		"total_frames": _frame_stats["total_frames"],
		"samples": _frame_times.size()
	}


## Get 1% low FPS (frame time at 99th percentile)
func get_1pct_low_fps() -> float:
	if _frame_times.size() < 10:
		return get_fps()
	var sorted := _frame_times.duplicate()
	sorted.sort()
	var idx := int(sorted.size() * 0.99)
	var p99_ms := sorted[min(idx, sorted.size() - 1)]
	return 1000.0 / p99_ms if p99_ms > 0.0 else 0.0


## --- Statistics ---

func get_stats() -> Dictionary:
	var stats := _stats.duplicate()
	stats["game_time"] = _game_time
	stats["real_time"] = _real_time
	stats["time_scale"] = _time_scale
	stats["tick_count"] = _tick_count
	stats["paused"] = _paused
	stats["fps"] = get_fps()
	stats["frame_avg_ms"] = _frame_stats["avg_ms"]
	stats["frame_max_ms"] = _frame_stats["max_ms"]
	stats["1pct_low_fps"] = get_1pct_low_fps()
	return stats


## Reset time state
func reset() -> void:
	_game_time = 0.0
	_real_time = 0.0
	_tick_count = 0
	_accumulator = 0.0
	_time_scale = 1.0
	_paused = false
	_named_timers.clear()
	_tick_schedules.clear()
	_frame_times.clear()
	_frame_stats = {"min_ms": 9999.0, "max_ms": 0.0, "avg_ms": 0.0, "total_frames": 0}
	cancel_all()
	GameLog.info("TimeManager: Reset", "Time")


func _add_schedule(delay: float, repeating: bool, target: Object, method: String, args: Dictionary) -> int:
	var id := _next_schedule_id
	_next_schedule_id += 1

	_scheduled[id] = {
		"time": delay,
		"interval": delay,
		"repeating": repeating,
		"target": target,
		"method": StringName(method),
		"args": args,
		"active": true,
		"created_at": _game_time
	}

	_stats["scheduled_total"] += 1
	_stats["scheduled_active"] = _scheduled.size()

	GameLog.debug("TimeManager: Scheduled %s (id=%d, delay=%.2fs, repeating=%s)" % [
		method, id, delay, repeating
	], "Time")

	return id
