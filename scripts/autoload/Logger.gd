extends Node
## Logger autoload singleton for Godot 4.7.2 compatibility

enum Level {
	DEBUG = 0,
	INFO = 1,
	WARNING = 2,
	ERROR = 3,
	NONE = 4
}

var _min_level: Level = Level.DEBUG
var _buffer: Array = []
var _counts: Dictionary = {"debug": 0, "info": 0, "warning": 0, "error": 0}

func debug(message: String, category: String = "General") -> void:
	_log(Level.DEBUG, message, category)

func info(message: String, category: String = "General") -> void:
	_log(Level.INFO, message, category)

func warning(message: String, category: String = "General") -> void:
	_log(Level.WARNING, message, category)

func error(message: String, category: String = "General") -> void:
	_log(Level.ERROR, message, category)

func _log(level: Level, message: String, category: String) -> void:
	if level < _min_level:
		return
	var level_name := _level_to_string(level)
	var timestamp := Time.get_datetime_string_from_system()
	var entry := {"timestamp": timestamp, "level": level_name, "category": category, "message": message}
	_buffer.append(entry)
	if _buffer.size() > 500:
		_buffer.pop_front()
	var count_key := level_name.to_lower()
	if _counts.has(count_key):
		_counts[count_key] += 1
	var msg := "[%s] [%s] [%s] %s" % [timestamp, level_name, category, message]
	match level:
		Level.WARNING: push_warning(msg)
		Level.ERROR: push_error(msg)
		_: print(msg)

func get_recent_entries(count: int = 50) -> Array:
	if count >= _buffer.size():
		return _buffer.duplicate()
	return _buffer.slice(_buffer.size() - count, _buffer.size())

func get_stats() -> Dictionary:
	return {
		"total_debug": _counts["debug"],
		"total_info": _counts["info"],
		"total_warning": _counts["warning"],
		"total_error": _counts["error"],
		"buffer_size": _buffer.size()
	}

func set_min_level(level: Level) -> void:
	_min_level = level

func get_min_level() -> Level:
	return _min_level

func _level_to_string(level: Level) -> String:
	match level:
		Level.DEBUG: return "DEBUG"
		Level.INFO: return "INFO"
		Level.WARNING: return "WARN"
		Level.ERROR: return "ERROR"
		_: return "UNKNOWN"
