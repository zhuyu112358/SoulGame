extends Node
## ConfigManager - Configuration file loading and management
##
## Loads and manages game, soul, and world configuration files.
## Supports hot-reload, default values, and type-safe access.
##
## Usage:
##   ConfigManager.load_config("game")
##   var fps = ConfigManager.get_value("game", "display", "target_fps", 60)
##   ConfigManager.set_value("game", "audio", "master_volume", 0.8)
##   ConfigManager.save_config("game")

## Loaded config stores: { config_name: ConfigFile }
var _configs: Dictionary = {}

## Default values for configs
var _defaults: Dictionary = {}

## Config file paths
var _config_paths: Dictionary = {
	"game": "res://config/game.cfg",
	"soul": "res://config/soul.cfg",
	"world": "res://config/world.cfg",
	"sdk": "res://config/sdk_versions.cfg",
	"user": "user://config/user.cfg"
}

## Whether config has been modified since last save
var _dirty: Dictionary = {}


func _ready() -> void:
	_load_defaults()
	# Load all built-in configs
	for config_name in _config_paths:
		if config_name != "user":
			load_config(config_name)
	# Load user config (may not exist yet)
	load_config("user")


## Load a configuration file
func load_config(config_name: String) -> bool:
	var path := _get_config_path(config_name)
	if path.is_empty():
		Logger.error("Unknown config: %s" % config_name, "Config")
		return false

	var config := ConfigFile.new()
	var error_code := config.load(path)

	if error_code != OK:
		Logger.warning("Could not load config '%s' (will use defaults): %s" % [config_name, path], "Config")
		# Create empty config with defaults
		_configs[config_name] = config
		_dirty[config_name] = true
		return false

	_configs[config_name] = config
	_dirty[config_name] = false
	Logger.info("Loaded config: %s" % config_name, "Config")
	return true


## Save a configuration file
func save_config(config_name: String) -> bool:
	if not _configs.has(config_name):
		Logger.error("Config not loaded: %s" % config_name, "Config")
		return false

	var path := _get_config_path(config_name)
	if path.is_empty():
		return false

	# Ensure directory exists for user:// paths
	if path.begins_with("user://"):
		var dir_path := path.get_base_dir()
		if not DirAccess.dir_exists_absolute(dir_path):
			DirAccess.make_dir_recursive_absolute(dir_path)

	var config: ConfigFile = _configs[config_name]
	var error_code := config.save(path)

	if error_code != OK:
		Logger.error("Failed to save config '%s': error %d" % [config_name, error_code], "Config")
		return false

	_dirty[config_name] = false
	Logger.info("Saved config: %s" % config_name, "Config")
	return true


## Get a config value with optional default
func get_value(config_name: String, section: String, key: String, default_value = null):
	if not _configs.has(config_name):
		return _get_default(config_name, section, key, default_value)

	var config: ConfigFile = _configs[config_name]
	if config.has_section_key(section, key):
		return config.get_value(section, key)

	return _get_default(config_name, section, key, default_value)


## Set a config value
func set_value(config_name: String, section: String, key: String, value) -> void:
	if not _configs.has(config_name):
		var config := ConfigFile.new()
		_configs[config_name] = config

	var config: ConfigFile = _configs[config_name]
	config.set_value(section, key, value)
	_dirty[config_name] = true


## Check if a config has a section/key
func has_key(config_name: String, section: String, key: String) -> bool:
	if not _configs.has(config_name):
		return false
	var config: ConfigFile = _configs[config_name]
	return config.has_section_key(section, key)


## Get all sections in a config
func get_sections(config_name: String) -> Array:
	if not _configs.has(config_name):
		return []
	var config: ConfigFile = _configs[config_name]
	return config.get_sections()


## Get all keys in a section
func get_section_keys(config_name: String, section: String) -> Array:
	if not _configs.has(config_name):
		return []
	var config: ConfigFile = _configs[config_name]
	return config.get_section_keys(section)


## Reload a config from disk (discards unsaved changes)
func reload_config(config_name: String) -> bool:
	return load_config(config_name)


## Check if any config is dirty
func is_dirty(config_name: String = "") -> bool:
	if config_name.is_empty():
		for name in _dirty:
			if _dirty[name]:
				return true
		return false
	return _dirty.get(config_name, false)


## Save all dirty configs
func save_all() -> void:
	for config_name in _dirty:
		if _dirty[config_name]:
			save_config(config_name)


func _get_config_path(config_name: String) -> String:
	if _config_paths.has(config_name):
		return _config_paths[config_name]
	return ""


func _get_default(config_name: String, section: String, key: String, fallback):
	if _defaults.has(config_name):
		var config_defaults = _defaults[config_name]
		if config_defaults.has(section):
			var section_defaults = config_defaults[section]
			if section_defaults.has(key):
				return section_defaults[key]
	return fallback


func _load_defaults() -> void:
	_defaults = {
		"game": {
			"display": {
				"target_fps": 60,
				"vsync": true,
				"fullscreen": false
			},
			"audio": {
				"master_volume": 1.0,
				"sfx_volume": 0.8,
				"music_volume": 0.6
			},
			"debug": {
				"show_fps": false,
				"show_debug_overlay": true,
				"log_level": "DEBUG"
			}
		},
		"sdk": {
			"soularena": {
				"base_url": "http://localhost:3000",
				"version": "4.2.0",
				"timeout_ms": 5000,
				"max_retries": 3
			},
			"seed": {
				"base_url": "http://localhost:3001",
				"version": "dist",
				"timeout_ms": 5000,
				"max_retries": 3
			}
		},
		"network": {
			"reconnect": {
				"max_attempts": 5,
				"base_delay_ms": 1000,
				"max_delay_ms": 10000
			}
		}
	}


## Get configuration statistics
func get_stats() -> Dictionary:
	var loaded_count := 0
	var dirty_count := 0
	for config_name in _configs:
		if _configs[config_name] != null:
			loaded_count += 1
	for config_name in _dirty:
		if _dirty[config_name]:
			dirty_count += 1
	return {
		"configs_registered": _config_paths.size(),
		"configs_loaded": loaded_count,
		"dirty_configs": dirty_count,
		"defaults_defined": _defaults.size()
	}
