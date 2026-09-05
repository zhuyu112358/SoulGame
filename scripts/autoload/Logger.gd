extends Node
## Logger - Centralized logging system with levels, categories, file output, and rotation
##
## Supports multiple log levels, categorized logging, file output with rotation,
## category filtering, and integration with debug overlay.
##
## Features:
## - 4 log levels (DEBUG/INFO/WARNING/ERROR)
## - Categorized logging with per-category level overrides
## - File output with size-based rotation
## - In-memory buffer for debug display
## - Console output with Godot warning/error integration
## - Event emission for real-time log display
##
## Usage:
##   Logger.info("Player joined", "Game")
##   Logger.warning("Low memory", "System")
##   Logger.error("Connection failed", "Network")
##   Logger.debug("Tick: %d" % tick, "AI")
##   Logger.set_category_level("Network", Logger.Level.INFO)

## Log levels
enum Level {
	DEBUG = 0,
	INFO = 1,
	WARNING = 2,
	ERROR = 3,
	NONE = 4
}

## Current minimum level to display
var _min_level: Level = Level.DEBUG

## Per-category level overrides: { category: Level }
var _category_levels: Dictionary = {}

## Whether to write logs to file
var _log_to_file: bool = true

## Log file path
var _log_file_path: String = "user://logs/game.log"

## Maximum log file size in bytes before rotation (default 5MB)
var _max_file_size: int = 5 * 1024 * 1024

## Number of rotated log files to keep
var _max_rotated_files: int = 5

## Maximum log entries kept in memory for debug overlay
var _max_memory_entries: int = 500

## In-memory log buffer for debug display
var _log_buffer: Array = []

## File handle for log writing
var _log_file: FileAccess = null

## Whether logging system is initialized
var _initialized: bool = false

## Statistics
var _counts: Dictionary = {
	"debug": 0,
	"info": 0,
	"warning": 0,
	"error": 0
}

## Per-category statistics: { category: {debug, info, warning, error} }
var _category_counts: Dictionary = {}

## Total bytes written to log file
var _bytes_written: int = 0

## Log rotation count
var _rotation_count: int = 0


func _ready() -> void:
	_initialize()


## Initialize logging system
func _initialize() -> void:
	if _initialized:
		return

	# Ensure log directory exists
	var dir := DirAccess.open("user://logs")
	if dir == null:
		DirAccess.make_dir_recursive_absolute("user://logs")

	# Open log file
	if _log_to_file:
		_open_log_file()

	_initialized = true
	info("Logger initialized (file=%s, max_size=%dMB, rotations=%d)" % [_log_to_file, _max_file_size / (1024 * 1024), _max_rotated_files], "Logger")


## Open or create the log file
func _open_log_file() -> void:
	_log_file = FileAccess.open(_log_file_path, FileAccess.WRITE)
	if _log_file:
		_log_file.seek_end()
		var header := "\n=== Session started: %s ===\n" % Time.get_datetime_string_from_system()
		_log_file.store_line(header)
		_log_file.flush()
		_bytes_written += header.length()


## Set minimum log level
func set_min_level(level: Level) -> void:
	_min_level = level
	info("Log level set to %s" % _level_to_string(level), "Logger")


## Get minimum log level
func get_min_level() -> Level:
	return _min_level


## Set per-category log level override
func set_category_level(category: String, level: Level) -> void:
	_category_levels[category] = level
	info("Category '%s' level set to %s" % [category, _level_to_string(level)], "Logger")


## Clear per-category level override
func clear_category_level(category: String) -> void:
	if _category_levels.has(category):
		_category_levels.erase(category)


## Get effective log level for a category
func get_effective_level(category: String) -> Level:
	if _category_levels.has(category):
		return _category_levels[category]
	return _min_level


## Log at DEBUG level
func debug(message: String, category: String = "General") -> void:
	_log(Level.DEBUG, message, category)


## Log at INFO level
func info(message: String, category: String = "General") -> void:
	_log(Level.INFO, message, category)


## Log at WARNING level
func warning(message: String, category: String = "General") -> void:
	_log(Level.WARNING, message, category)


## Log at ERROR level
func error(message: String, category: String = "General") -> void:
	_log(Level.ERROR, message, category)


## Core logging function
func _log(level: Level, message: String, category: String) -> void:
	# Check global level
	if level < _min_level:
		return

	# Check category-level override
	var effective_level := get_effective_level(category)
	if level < effective_level:
		return

	var level_name := _level_to_string(level)
	var timestamp := Time.get_datetime_string_from_system()
	var entry := {
		"timestamp": timestamp,
		"level": level_name,
		"category": category,
		"message": message
	}

	# Update counts
	var count_key := level_name.to_lower()
	if _counts.has(count_key):
		_counts[count_key] += 1

	# Update per-category counts
	if not _category_counts.has(category):
		_category_counts[category] = {"debug": 0, "info": 0, "warning": 0, "error": 0}
	_category_counts[category][count_key] += 1

	# Add to memory buffer
	_log_buffer.append(entry)
	if _log_buffer.size() > _max_memory_entries:
		_log_buffer.pop_front()

	# Print to console with color
	var colored_message := "[%s] [%s] [%s] %s" % [timestamp, level_name, category, message]
	match level:
		Level.DEBUG:
			print(colored_message)
		Level.INFO:
			print(colored_message)
		Level.WARNING:
			push_warning(colored_message)
		Level.ERROR:
			push_error(colored_message)

	# Write to file
	if _log_to_file and _log_file:
		_log_file.store_line(colored_message)
		_log_file.flush()
		_bytes_written += colored_message.length() + 1
		_check_rotation()

	# Emit event for debug overlay
	EventBus.emit("log_entry", entry)


## Check if log file needs rotation
func _check_rotation() -> void:
	if _bytes_written < _max_file_size:
		return

	_rotate_logs()


## Rotate log files
## game.log -> game.log.1 -> game.log.2 -> ... -> game.log.N (deleted)
func _rotate_logs() -> void:
	if _log_file:
		_log_file.close()
		_log_file = null

	# Shift existing rotated files
	for i in range(_max_rotated_files - 1, 0, -1):
		var old_path := "%s.%d" % [_log_file_path, i]
		var new_path := "%s.%d" % [_log_file_path, i + 1]
		if FileAccess.file_exists(old_path):
			DirAccess.rename_absolute(old_path, new_path)

	# Rotate current log
	if FileAccess.file_exists(_log_file_path):
		var rotated_path := "%s.1" % _log_file_path
		DirAccess.rename_absolute(_log_file_path, rotated_path)

	# Delete oldest if exceeds max
	var oldest_path := "%s.%d" % [_log_file_path, _max_rotated_files + 1]
	if FileAccess.file_exists(oldest_path):
		DirAccess.remove_absolute(oldest_path)

	_rotation_count += 1
	_bytes_written = 0

	# Open new log file
	_open_log_file()

	info("Log rotated (rotation #%d)" % _rotation_count, "Logger")


## Get recent log entries for debug display
func get_recent_entries(count: int = 50) -> Array:
	if count >= _log_buffer.size():
		return _log_buffer.duplicate()
	return _log_buffer.slice(_log_buffer.size() - count, _log_buffer.size())


## Get recent log entries filtered by category
func get_recent_by_category(category: String, count: int = 50) -> Array:
	var result := []
	for i in range(_log_buffer.size() - 1, -1, -1):
		if _log_buffer[i]["category"] == category:
			result.append(_log_buffer[i])
			if result.size() >= count:
				break
	return result


## Get recent log entries filtered by level
func get_recent_by_level(level: Level, count: int = 50) -> Array:
	var level_name := _level_to_string(level)
	var result := []
	for i in range(_log_buffer.size() - 1, -1, -1):
		if _log_buffer[i]["level"] == level_name:
			result.append(_log_buffer[i])
			if result.size() >= count:
				break
	return result


## Get log statistics
func get_stats() -> Dictionary:
	return {
		"total_debug": _counts["debug"],
		"total_info": _counts["info"],
		"total_warning": _counts["warning"],
		"total_error": _counts["error"],
		"total_logged": _counts["debug"] + _counts["info"] + _counts["warning"] + _counts["error"],
		"buffer_size": _log_buffer.size(),
		"max_buffer_size": _max_memory_entries,
		"bytes_written": _bytes_written,
		"rotations": _rotation_count,
		"categories_tracked": _category_counts.size(),
		"category_overrides": _category_levels.size(),
		"file_output": _log_to_file,
		"current_level": _level_to_string(_min_level)
	}


## Get per-category statistics
func get_category_stats(category: String) -> Dictionary:
	if _category_counts.has(category):
		return _category_counts[category].duplicate()
	return {"debug": 0, "info": 0, "warning": 0, "error": 0}


## Get all category statistics
func get_all_category_stats() -> Dictionary:
	return _category_counts.duplicate(true)


## Clear memory buffer
func clear_buffer() -> void:
	_log_buffer.clear()


## Clear all statistics
func clear_stats() -> void:
	_counts = {"debug": 0, "info": 0, "warning": 0, "error": 0}
	_category_counts.clear()
	_bytes_written = 0
	_rotation_count = 0


## Set log file configuration
func set_file_config(enabled: bool, max_size_mb: float = 5.0, max_rotations: int = 5) -> void:
	_log_to_file = enabled
	_max_file_size = int(max_size_mb * 1024 * 1024)
	_max_rotated_files = max_rotations
	info("Log file config updated: enabled=%s, max_size=%.1fMB, rotations=%d" % [enabled, max_size_mb, max_rotations], "Logger")


func _level_to_string(level: Level) -> String:
	match level:
		Level.DEBUG: return "DEBUG"
		Level.INFO: return "INFO"
		Level.WARNING: return "WARN"
		Level.ERROR: return "ERROR"
		_: return "UNKNOWN"


func _exit_tree() -> void:
	if _log_file:
		_log_file.store_line("=== Session ended: %s ===" % Time.get_datetime_string_from_system())
		_log_file.close()
