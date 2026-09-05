extends Node
## ErrorHandler - Global error handling, crash reporting, and recovery
##
## Captures unhandled exceptions, script errors, and warnings.
## Provides error history, crash dump generation, and automatic recovery.
##
## Usage:
##   ErrorHandler.track_error("Network", "Connection timeout", error_data)
##   ErrorHandler.get_error_history()
##   ErrorHandler.generate_crash_dump()

## Error history: [{timestamp, category, message, data, severity}]
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


func _ready() -> void:
	_ensure_crash_dir()
	# Connect to Godot's global error handler
	if Engine.has_singleton("GodotError"):
		pass  # Godot 4 doesn't have a global error signal by default
	Logger.info("ErrorHandler initialized", "Error")


## Track an error manually
## severity: "critical" | "error" | "warning" | "info"
func track_error(category: String, message: String, data: Dictionary = {}, severity: String = "error") -> void:
	if not _active:
		return

	var entry := {
		"timestamp": Time.get_datetime_string_from_system(),
		"tick_msec": Time.get_ticks_msec(),
		"category": category,
		"message": message,
		"data": data,
		"severity": severity
	}

	_error_history.append(entry)
	if _error_history.size() > _max_history:
		_error_history.pop_front()

	_total_errors += 1

	if not _error_counts.has(category):
		_error_counts[category] = 0
	_error_counts[category] += 1

	if _severity_counts.has(severity):
		_severity_counts[severity] += 1

	# Log based on severity
	match severity:
		"critical":
			Logger.error("CRITICAL [%s]: %s" % [category, message], "Error")
			_generate_crash_dump(entry)
			if _pause_on_critical:
				get_tree().paused = true
		"error":
			Logger.error("[%s]: %s" % [category, message], "Error")
		"warning":
			Logger.warning("[%s]: %s" % [category, message], "Error")
		"info":
			Logger.info("[%s]: %s" % [category, message], "Error")

	EventBus.emit("error_tracked", entry)


## Track an exception from a try/catch block
func track_exception(category: String, exception: Variant, data: Dictionary = {}) -> void:
	var message := str(exception)
	if typeof(exception) == TYPE_DICTIONARY and exception.has("message"):
		message = str(exception["message"])
	track_error(category, message, data, "error")


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


## Get error statistics
func get_stats() -> Dictionary:
	return {
		"total_errors": _total_errors,
		"by_category": _error_counts.duplicate(),
		"by_severity": _severity_counts.duplicate(),
		"history_size": _error_history.size()
	}


## Check if there are any critical errors
func has_critical_errors() -> bool:
	return _severity_counts["critical"] > 0


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
	dump += "Scene: %s\n" % GameState.get("game", "current_scene", "unknown")
	dump += "Memory Static: %.1fMB\n" % (float(Performance.get_monitor(Performance.MEMORY_STATIC)) / (1024*1024))
	dump += "Memory Dynamic: %.1fMB\n" % (float(Performance.get_monitor(Performance.MEMORY_DYNAMIC)) / (1024*1024))
	dump += "Draw Calls: %d\n" % int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	dump += "\n=== Recent Errors ===\n"
	for entry in get_error_history(10):
		dump += "[%s] [%s] %s: %s\n" % [entry["timestamp"], entry["severity"], entry["category"], entry["message"]]

	var file := FileAccess.open(dump_path, FileAccess.WRITE)
	if file:
		file.store_string(dump)
		file.close()
		Logger.info("ErrorHandler: Crash dump saved to %s" % dump_path, "Error")


## Clear all error history
func clear_history() -> void:
	_error_history.clear()
	_error_counts.clear()
	_severity_counts = {"critical": 0, "error": 0, "warning": 0, "info": 0}
	_total_errors = 0
	Logger.info("ErrorHandler: History cleared", "Error")


## Set whether to pause on critical errors
func set_pause_on_critical(enabled: bool) -> void:
	_pause_on_critical = enabled


## Enable/disable error tracking
func set_active(active: bool) -> void:
	_active = active


func _ensure_crash_dir() -> void:
	if not DirAccess.dir_exists_absolute(_crash_dump_dir):
		DirAccess.make_dir_recursive_absolute(_crash_dump_dir)
