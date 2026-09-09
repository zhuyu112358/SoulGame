extends Node
## Logger autoload singleton - simplified for Godot 4.7.2 compatibility

var _buffer: Array = []
var _counts: Dictionary = {"debug": 0, "info": 0, "warning": 0, "error": 0}

func _ready() -> void:
	print("Logger autoload ready")

func info(message: String, category: String = "General") -> void:
	_log("INFO", message, category)

func debug(message: String, category: String = "General") -> void:
	_log("DEBUG", message, category)

func warning(message: String, category: String = "General") -> void:
	_log("WARN", message, category)

func error(message: String, category: String = "General") -> void:
	_log("ERROR", message, category)

func _log(level: String, message: String, category: String) -> void:
	var timestamp: String = Time.get_datetime_string_from_system()
	var entry: Dictionary = {"timestamp": timestamp, "level": level, "category": category, "message": message}
	_buffer.append(entry)
	if _buffer.size() > 500:
		_buffer.pop_front()
	var count_key: String = level.to_lower()
	if count_key == "warn":
		count_key = "warning"
	if _counts.has(count_key):
		_counts[count_key] += 1
	print("[%s] [%s] [%s] %s" % [timestamp, level, category, message])

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

func set_min_level(level: int) -> void:
	pass

func get_min_level() -> int:
	return 0
