extends Node
## TimeManager - Game time management, tick scheduling, and timers
##
## Manages game time scaling, fixed timestep ticks, scheduled callbacks,
## and basic time-of-day tracking. This is infrastructure - no game logic.
##
## Usage:
##   TimeManager.set_time_scale(0.5)  # slow motion
##   TimeManager.schedule_once(5.0, self, "_on_timer")
##   var id = TimeManager.schedule_repeating(1.0, self, "_on_tick")
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

## Scheduled callbacks: { id: {time, interval, repeating, target, method, args, active} }
var _scheduled: Dictionary = {}

## Next schedule ID
var _next_schedule_id: int = 1

## Time of day (0.0 - 24.0)
var _time_of_day: float = 12.0

## Day length in real seconds (for time-of-day progression)
var _day_length_seconds: float = 1200.0  # 20 minutes per day

## Whether time-of-day progresses automatically
var _auto_progression: bool = false

## Pause state
var _paused: bool = false

## Statistics
var _stats: Dictionary = {
	"total_ticks": 0,
	"scheduled_total": 0,
	"scheduled_active": 0,
	"max_frame_time": 0.0
}


func _ready() -> void:
	Logger.info("TimeManager initialized (tick_rate=%.0f Hz)" % (1.0 / _fixed_timestep), "Time")


func _process(delta: float) -> void:
	if _paused:
		return

	_real_time += delta
	var scaled_delta := delta * _time_scale
	_game_time += scaled_delta

	# Track max frame time
	if delta > _stats["max_frame_time"]:
		_stats["max_frame_time"] = delta

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


## Fixed timestep update (called at fixed rate)
func _fixed_tick(delta: float) -> void:
	_tick_count += 1
	_stats["total_ticks"] += 1
	GameState.increment_tick()
	EventBus.emit("fixed_tick", {"tick": _tick_count, "delta": delta})


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


## Schedule a one-time callback
## Returns schedule ID for cancellation
func schedule_once(delay: float, target: Object, method: String, args: Dictionary = {}) -> int:
	return _add_schedule(delay, false, target, method, args)


## Schedule a repeating callback
## Returns schedule ID for cancellation
func schedule_repeating(interval: float, target: Object, method: String, args: Dictionary = {}) -> int:
	return _add_schedule(interval, true, target, method, args)


## Cancel a scheduled callback
func cancel(schedule_id: int) -> void:
	if _scheduled.has(schedule_id):
		_scheduled[schedule_id]["active"] = false
		Logger.debug("TimeManager: Cancelled schedule %d" % schedule_id, "Time")


## Cancel all scheduled callbacks
func cancel_all() -> void:
	for id in _scheduled:
		_scheduled[id]["active"] = false
	Logger.info("TimeManager: Cancelled all schedules", "Time")


## Check if a schedule is active
func is_scheduled(schedule_id: int) -> bool:
	return _scheduled.has(schedule_id) and _scheduled[schedule_id]["active"]


## --- Time Scale ---

## Set time scale (1.0 = normal, 0 = paused)
func set_time_scale(scale: float) -> void:
	_time_scale = clamp(scale, 0.0, 10.0)
	GameState.set_world_state("time_scale", _time_scale)
	Logger.info("TimeManager: Time scale set to %.2f" % _time_scale, "Time")
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
	Logger.info("TimeManager: Tick rate set to %d Hz" % ticks_per_second, "Time")


## --- Pause ---

## Pause game time
func pause() -> void:
	_paused = true
	GameState.set("game", "paused", true)
	EventBus.emit("game_paused", {})
	Logger.info("TimeManager: Paused", "Time")


## Resume game time
func resume() -> void:
	_paused = false
	GameState.set("game", "paused", false)
	EventBus.emit("game_resumed", {})
	Logger.info("TimeManager: Resumed", "Time")


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


## --- Statistics ---

func get_stats() -> Dictionary:
	return _stats.duplicate()


## Reset time state
func reset() -> void:
	_game_time = 0.0
	_real_time = 0.0
	_tick_count = 0
	_accumulator = 0.0
	_time_scale = 1.0
	_paused = false
	cancel_all()
	Logger.info("TimeManager: Reset", "Time")


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
		"active": true
	}

	_stats["scheduled_total"] += 1
	_stats["scheduled_active"] = _scheduled.size()

	Logger.debug("TimeManager: Scheduled %s (id=%d, delay=%.2fs, repeating=%s)" % [
		method, id, delay, repeating
	], "Time")

	return id
