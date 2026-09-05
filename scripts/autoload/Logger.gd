extends Node
## Logger - Centralized logging system with levels and categories
##
## Supports multiple log levels, categorized logging, file output,
## and integration with debug overlay.
##
## Usage:
##   Logger.info("Player joined", "Game")
##   Logger.warning("Low memory", "System")
##   Logger.error("Connection failed", "Network")
##   Logger.debug("Tick: %d" % tick, "AI")

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

## Whether to write logs to file
var _log_to_file: bool = true

## Log file path
var _log_file_path: String = "user://logs/game.log"

## Maximum log entries kept in memory for debug overlay
var _max_memory_entries: int = 200

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
		_log_file = FileAccess.open(_log_file_path, FileAccess.WRITE)
		if _log_file:
			_log_file.seek_end()
			_log_file.store_line("\n=== Session started: %s ===" % Time.get_datetime_string_from_system())

	_initialized = true
	info("Logger initialized", "Logger")


## Set minimum log level
func set_min_level(level: Level) -> void:
	_min_level = level


## Get minimum log level
func get_min_level() -> Level:
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
	if level < _min_level:
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

	# Emit event for debug overlay
	EventBus.emit("log_entry", entry)


## Get recent log entries for debug display
func get_recent_entries(count: int = 50) -> Array:
	if count >= _log_buffer.size():
		return _log_buffer.duplicate()
	return _log_buffer.slice(_log_buffer.size() - count, _log_buffer.size())


## Get log statistics
func get_stats() -> Dictionary:
	return _counts.duplicate()


## Clear memory buffer
func clear_buffer() -> void:
	_log_buffer.clear()


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
