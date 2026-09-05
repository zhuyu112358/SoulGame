extends Node
## ErrorHandler - Global error handling, crash reporting, recovery, and monitoring
##
## Captures unhandled exceptions, script errors, and warnings.
## Provides error history, crash dump generation, automatic recovery,
## error rate monitoring, and error storm suppression.
##
## Features:
## - 4 severity levels (critical/error/warning/info)
## - Error categorization with per-category tracking
## - Automatic crash dump generation on critical errors
## - Error rate monitoring (sliding window)
## - Error storm suppression (prevents log flooding)
## - Recovery strategy registry (auto-retry, fallback, degrade)
## - System state snapshot in crash dumps
##
## Usage:
##   ErrorHandler.track_error("Network", "Connection timeout", error_data)
##   ErrorHandler.register_recovery("Network", self, "_recover_network")
##   ErrorHandler.get_error_history()
##   ErrorHandler.generate_crash_dump()

## Error history: [{timestamp, category, message, data, severity, recovered}]
var _error_history: Array = []

## Maximum error history entries
var _max_history: int = 200

## Error counts by category
var _error_counts: Dictionary = {}

## Error counts by severity
var _severity_counts: Dictionary = {
	"critical": 0,
	"error": 0,
	"warning": 0,
	"info": 0
}

## Whether to automatically pause on critical errors
var _pause_on_critical: bool = false

## Crash dump directory
var _crash_dump_dir: String = "user://crashes"

## Total errors tracked
var _total_errors: int = 0

## Whether error tracking is active
var _active: bool = true

## --- Error Rate Monitoring ---

## Sliding window for error rate (timestamps of recent errors)
var _error_timestamps: Array = []

## Window size in seconds for rate calculation
var _rate_window_seconds: float = 60.0

## Warning threshold for errors per minute
var _rate_warning_threshold: float = 30.0

## Critical threshold for errors per minute
var _rate_critical_threshold: float = 100.0

## --- Error Storm Suppression ---

## Suppression state: { category: {count, first_time, suppressed} }
var _suppression_state: Dictionary = {}

## Max errors per category per minute before suppression
var _max_errors_per_category_per_minute: int = 50

## Whether suppression is enabled
var _suppression_enabled: bool = true

## --- Recovery Strategies ---

## Recovery handlers: { category: [{target, method, max_retries, retry_delay}] }
var _recovery_handlers: Dictionary = {}

## Recovery statistics: { category: {attempted, succeeded, failed} }
var _recovery_stats: Dictionary = {}

## Total recovery attempts
var _total_recoveries: int = 0


func _ready() -> void:
	_ensure_crash_dir()
	GameLog.info("ErrorHandler initialized (rate_window=%.0fs, suppression=%s)" % [_rate_window_seconds, _suppression_enabled], "Error")


## Track an error manually
## severity: "critical" | "error" | "warning" | "info"
func track_error(category: String, message: String, data: Dictionary = {}, severity: String = "error") -> void:
	if not _active:
		return

	# Check error storm suppression
	if _suppression_enabled and _is_suppressed(category):
		# Still count but don't log/emit
		_suppression_state[category]["suppressed"] += 1
		return

	var entry := {
		"timestamp": Time.get_datetime_string_from_system(),
		"tick_msec": Time.get_ticks_msec(),
		"category": category,
		"message": message,
		"data": data,
		"severity": severity,
		"recovered": false
	}

	_error_history.append(entry)
	if _error_history.size() > _max_history:
		_error_history.pop_front()

	_total_errors += 1
	_error_timestamps.append(Time.get_ticks_msec() / 1000.0)
	_cleanup_rate_window()

	if not _error_counts.has(category):
		_error_counts[category] = 0
	_error_counts[category] += 1

	if _severity_counts.has(severity):
		_severity_counts[severity] += 1

	# Update suppression tracking
	_update_suppression(category)

	# Log based on severity
	match severity:
		"critical":
			GameLog.error("CRITICAL [%s]: %s" % [category, message], "Error")
			_generate_crash_dump(entry)
			if _pause_on_critical:
				get_tree().paused = true
		"error":
			GameLog.error("[%s]: %s" % [category, message], "Error")
		"warning":
			GameLog.warning("[%s]: %s" % [category, message], "Error")
		"info":
			GameLog.info("[%s]: %s" % [category, message], "Error")

	EventBus.emit("error_tracked", entry)

	# Attempt automatic recovery
	_attempt_recovery(category, entry)


## Track an exception from a try/catch block
func track_exception(category: String, exception: Variant, data: Dictionary = {}) -> void:
	var message := str(exception)
	if typeof(exception) == TYPE_DICTIONARY and exception.has("message"):
		message = str(exception["message"])
	track_error(category, message, data, "error")


## --- Recovery Strategies ---

## Register a recovery handler for a category
## target: Object to call method on
## method: Method name, receives (error_entry: Dictionary) -> bool
## max_retries: Maximum recovery attempts
## retry_delay: Delay between retries in seconds
func register_recovery(category: String, target: Object, method: String, max_retries: int = 3, retry_delay: float = 1.0) -> void:
	if not _recovery_handlers.has(category):
		_recovery_handlers[category] = []

	_recovery_handlers[category].append({
		"target": target,
		"method": StringName(method),
		"max_retries": max_retries,
		"retry_delay": retry_delay
	})

	if not _recovery_stats.has(category):
		_recovery_stats[category] = {"attempted": 0, "succeeded": 0, "failed": 0}

	GameLog.info("ErrorHandler: Registered recovery for '%s' -> %s.%s (retries=%d)" % [category, target, method, max_retries], "Error")


## Unregister all recovery handlers for a category
func unregister_recovery(category: String) -> void:
	if _recovery_handlers.has(category):
		_recovery_handlers.erase(category)


## Attempt recovery for an error
func _attempt_recovery(category: String, error_entry: Dictionary) -> void:
	if not _recovery_handlers.has(category):
		return

	var handlers = _recovery_handlers[category]
	for handler in handlers:
		if is_instance_valid(handler["target"]):
			_total_recoveries += 1
			_recovery_stats[category]["attempted"] += 1
			var success := false
			var attempts_used := 0
			# Simple synchronous recovery (async retry could be added later)
			for attempt in range(handler["max_retries"]):
				attempts_used = attempt + 1
				if handler["target"].call(handler["method"], error_entry):
					success = true
					break
			if success:
				error_entry["recovered"] = true
				_recovery_stats[category]["succeeded"] += 1
				GameLog.info("ErrorHandler: Recovery succeeded for '%s' (attempt %d)" % [category, attempts_used], "Error")
				EventBus.emit("error_recovered", {"category": category, "error": error_entry})
			else:
				_recovery_stats[category]["failed"] += 1
				GameLog.warning("ErrorHandler: Recovery failed for '%s' after %d attempts" % [category, handler["max_retries"]], "Error")


## --- Error Rate Monitoring ---

## Get current error rate (errors per minute)
func get_error_rate() -> float:
	_cleanup_rate_window()
	if _error_timestamps.is_empty():
		return 0.0
	return float(_error_timestamps.size()) / (_rate_window_seconds / 60.0)


## Get error rate status: "normal" | "warning" | "critical"
func get_error_rate_status() -> String:
	var rate := get_error_rate()
	if rate >= _rate_critical_threshold:
		return "critical"
	elif rate >= _rate_warning_threshold:
		return "warning"
	return "normal"


## Clean up old timestamps from rate window
func _cleanup_rate_window() -> void:
	var cutoff := Time.get_ticks_msec() / 1000.0 - _rate_window_seconds
	while not _error_timestamps.is_empty() and _error_timestamps[0] < cutoff:
		_error_timestamps.pop_front()


## --- Error Storm Suppression ---

## Check if a category is currently suppressed
func _is_suppressed(category: String) -> bool:
	if not _suppression_state.has(category):
		return false
	var state = _suppression_state[category]
	var elapsed: float = (Time.get_ticks_msec() / 1000.0) - float(state["first_time"])
	if elapsed > 60.0:
		# Reset after 60 seconds
		_suppression_state.erase(category)
		return false
	return state["count"] > _max_errors_per_category_per_minute


## Update suppression tracking for a category
func _update_suppression(category: String) -> void:
	if not _suppression_state.has(category):
		_suppression_state[category] = {
			"count": 0,
			"first_time": Time.get_ticks_msec() / 1000.0,
			"suppressed": 0
		}
	_suppression_state[category]["count"] += 1


## Get suppression statistics
func get_suppression_stats() -> Dictionary:
	var result := {}
	for category in _suppression_state:
		result[category] = _suppression_state[category].duplicate()
	return result


## --- Error History ---

## Get error history (most recent first)
func get_error_history(count: int = 50) -> Array:
	var result := _error_history.duplicate()
	result.reverse()
	if count < result.size():
		result = result.slice(0, count)
	return result


## Get errors by category
func get_errors_by_category(category: String) -> Array:
	var result := []
	for entry in _error_history:
		if entry["category"] == category:
			result.append(entry)
	return result


## Get errors by severity
func get_errors_by_severity(severity: String) -> Array:
	var result := []
	for entry in _error_history:
		if entry["severity"] == severity:
			result.append(entry)
	return result


## Get unrecovered errors
func get_unrecovered_errors() -> Array:
	var result := []
	for entry in _error_history:
		if not entry["recovered"]:
			result.append(entry)
	return result


## --- Statistics ---

## Get error statistics
func get_stats() -> Dictionary:
	return {
		"total_errors": _total_errors,
		"by_category": _error_counts.duplicate(),
		"by_severity": _severity_counts.duplicate(),
		"history_size": _error_history.size(),
		"error_rate_per_min": get_error_rate(),
		"error_rate_status": get_error_rate_status(),
		"total_recoveries": _total_recoveries,
		"recovery_stats": _recovery_stats.duplicate(true),
		"suppressed_categories": _suppression_state.size(),
		"unrecovered_count": get_unrecovered_errors().size()
	}


## Check if there are any critical errors
func has_critical_errors() -> bool:
	return _severity_counts["critical"] > 0


## --- Crash Dump ---

## Generate a crash dump file
func _generate_crash_dump(error_entry: Dictionary) -> void:
	_ensure_crash_dir()

	var timestamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var dump_path := "%s/crash_%s.txt" % [_crash_dump_dir, timestamp]

	var dump := "=== SoulGame Crash Dump ===\n"
	dump += "Time: %s\n" % error_entry["timestamp"]
	dump += "Category: %s\n" % error_entry["category"]
	dump += "Severity: %s\n" % error_entry["severity"]
	dump += "Message: %s\n\n" % error_entry["message"]
	dump += "Error Data:\n%s\n\n" % JSON.stringify(error_entry["data"], "\t")
	dump += "=== System State ===\n"
	dump += "FPS: %d\n" % Engine.get_frames_per_second()
	dump += "Objects: %d\n" % get_tree().get_node_count()
	dump += "Scene: %s\n" % GameState.get_value("game", "current_scene", "unknown")
	dump += "Memory Static: %.1fMB\n" % (float(Performance.get_monitor(Performance.MEMORY_STATIC)) / (1024*1024))
	dump += "Memory Dynamic: %.1fMB\n" % (float(Performance.get_monitor(5)) / (1024*1024))
	dump += "Draw Calls: %d\n" % int(Performance.get_monitor(13))
	dump += "Error Rate: %.1f/min (%s)\n" % [get_error_rate(), get_error_rate_status()]
	dump += "\n=== Recent Errors ===\n"
	for entry in get_error_history(10):
		dump += "[%s] [%s] %s: %s%s\n" % [entry["timestamp"], entry["severity"], entry["category"], entry["message"], " [RECOVERED]" if entry["recovered"] else ""]

	var file := FileAccess.open(dump_path, FileAccess.WRITE)
	if file:
		file.store_string(dump)
		file.close()
		GameLog.info("ErrorHandler: Crash dump saved to %s" % dump_path, "Error")


## Generate a manual crash dump (for debugging)
func generate_manual_dump(reason: String = "manual") -> void:
	var entry := {
		"timestamp": Time.get_datetime_string_from_system(),
		"category": "Manual",
		"severity": "info",
		"message": "Manual dump: %s" % reason,
		"data": {},
		"recovered": false
	}
	_generate_crash_dump(entry)


## --- Configuration ---

## Clear all error history
func clear_history() -> void:
	_error_history.clear()
	_error_counts.clear()
	_severity_counts = {"critical": 0, "error": 0, "warning": 0, "info": 0}
	_total_errors = 0
	_error_timestamps.clear()
	_suppression_state.clear()
	GameLog.info("ErrorHandler: History cleared", "Error")


## Set whether to pause on critical errors
func set_pause_on_critical(enabled: bool) -> void:
	_pause_on_critical = enabled


## Enable/disable error tracking
func set_active(active: bool) -> void:
	_active = active


## Set error rate monitoring configuration
func set_rate_config(window_seconds: float, warning_threshold: float, critical_threshold: float) -> void:
	_rate_window_seconds = window_seconds
	_rate_warning_threshold = warning_threshold
	_rate_critical_threshold = critical_threshold


## Set error storm suppression configuration
func set_suppression_config(enabled: bool, max_per_minute: int) -> void:
	_suppression_enabled = enabled
	_max_errors_per_category_per_minute = max_per_minute


func _ensure_crash_dir() -> void:
	if not DirAccess.dir_exists_absolute(_crash_dump_dir):
		DirAccess.make_dir_recursive_absolute(_crash_dump_dir)
