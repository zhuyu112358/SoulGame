extends Node
## SaveSystem - Local storage, configuration persistence, and save game management
##
## Manages save slots, auto-save, and data serialization.
## Uses ConfigFile for structured data and FileAccess for binary blobs.
##
## Usage:
##   SaveSystem.save_game(0, {"player": {...}, "world": {...}})
##   var data = SaveSystem.load_game(0)
##   SaveSystem.set_setting("audio", "volume", 0.8)
##   var vol = SaveSystem.get_setting("audio", "volume", 1.0)

## Save file directory
var _save_dir: String = "user://saves"

## Settings file path
var _settings_path: String = "user://settings.cfg"

## Maximum save slots
var _max_slots: int = 10

## Auto-save interval in seconds (0 = disabled)
var _auto_save_interval: float = 0.0

## Auto-save timer
var _auto_save_timer: float = 0.0

## Whether auto-save is enabled
var _auto_save_enabled: bool = false

## Cached settings
var _settings: ConfigFile = null

## Save metadata cache: { slot: {timestamp, name, playtime} }
var _save_metadata: Dictionary = {}


func _ready() -> void:
	_ensure_directories()
	_load_settings()
	_load_save_metadata()
	Logger.info("SaveSystem initialized", "Save")


func _process(delta: float) -> void:
	if _auto_save_enabled and _auto_save_interval > 0:
		_auto_save_timer += delta
		if _auto_save_timer >= _auto_save_interval:
			_auto_save_timer = 0.0
			auto_save()


## Save game data to a slot
func save_game(slot: int, data: Dictionary, slot_name: String = "") -> bool:
	if slot < 0 or slot >= _max_slots:
		Logger.error("SaveSystem: Invalid slot %d" % slot, "Save")
		return false

	var save_path := _get_save_path(slot)
	var save_file := ConfigFile.new()

	# Store metadata
	save_file.set_value("meta", "timestamp", Time.get_datetime_string_from_system())
	save_file.set_value("meta", "slot_name", slot_name if not slot_name.is_empty() else "Save %d" % slot)
	save_file.set_value("meta", "version", "1")

	# Store game data (flatten dictionary to sections)
	_serialize_dict(save_file, "data", data)

	var error_code := save_file.save(save_path)
	if error_code != OK:
		Logger.error("SaveSystem: Failed to save slot %d: error %d" % [slot, error_code], "Save")
		return false

	# Update metadata cache
	_save_metadata[slot] = {
		"timestamp": Time.get_datetime_string_from_system(),
		"name": slot_name if not slot_name.is_empty() else "Save %d" % slot,
		"size": FileAccess.get_file_as_bytes(save_path).size()
	}

	EventBus.emit("game_saved", {"slot": slot, "name": _save_metadata[slot]["name"]})
	Logger.info("SaveSystem: Saved game to slot %d" % slot, "Save")
	return true


## Load game data from a slot
func load_game(slot: int) -> Dictionary:
	if slot < 0 or slot >= _max_slots:
		Logger.error("SaveSystem: Invalid slot %d" % slot, "Save")
		return {}

	var save_path := _get_save_path(slot)
	if not FileAccess.file_exists(save_path):
		Logger.warning("SaveSystem: No save in slot %d" % slot, "Save")
		return {}

	var save_file := ConfigFile.new()
	var error_code := save_file.load(save_path)
	if error_code != OK:
		Logger.error("SaveSystem: Failed to load slot %d: error %d" % [slot, error_code], "Save")
		return {}

	var data := _deserialize_dict(save_file, "data")
	EventBus.emit("game_loaded", {"slot": slot})
	Logger.info("SaveSystem: Loaded game from slot %d" % slot, "Save")
	return data


## Check if a save slot has data
func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_get_save_path(slot))


## Delete a save slot
func delete_save(slot: int) -> bool:
	var save_path := _get_save_path(slot)
	if not FileAccess.file_exists(save_path):
		return false

	var error_code := DirAccess.remove_absolute(save_path)
	if error_code != OK:
		Logger.error("SaveSystem: Failed to delete slot %d" % slot, "Save")
		return false

	_save_metadata.erase(slot)
	EventBus.emit("save_deleted", {"slot": slot})
	Logger.info("SaveSystem: Deleted save slot %d" % slot, "Save")
	return true


## Get save metadata for all slots
func get_all_saves() -> Dictionary:
	return _save_metadata.duplicate(true)


## Get metadata for a specific slot
func get_save_info(slot: int) -> Dictionary:
	if _save_metadata.has(slot):
		return _save_metadata[slot].duplicate()
	return {}


## Auto-save to slot 0
func auto_save() -> void:
	var data := GameState.get_namespace("game")
	data["souls"] = GameState.get_namespace("soul")
	data["world"] = GameState.get_namespace("world")
	save_game(0, data, "Auto-save")


## --- Settings management ---

## Get a setting value
func get_setting(section: String, key: String, default_value = null):
	if _settings and _settings.has_section_key(section, key):
		return _settings.get_value(section, key)
	return default_value


## Set a setting value
func set_setting(section: String, key: String, value) -> void:
	if _settings == null:
		_settings = ConfigFile.new()
	_settings.set_value(section, key, value)
	_save_settings()


## Save settings to disk
func _save_settings() -> void:
	if _settings:
		_settings.save(_settings_path)


## Load settings from disk
func _load_settings() -> void:
	_settings = ConfigFile.new()
	if FileAccess.file_exists(_settings_path):
		_settings.load(_settings_path)


## --- Export/Import ---

## Export a save slot to a shareable string
func export_save(slot: int) -> String:
	var save_path := _get_save_path(slot)
	if not FileAccess.file_exists(save_path):
		return ""
	var file := FileAccess.open(save_path, FileAccess.READ)
	var content := file.get_as_text()
	file.close()
	return Marshalls.raw_to_base64(content.to_utf8_buffer())


## Import a save from exported string
func import_save(slot: int, data: String) -> bool:
	var decoded := Marshalls.base64_to_raw(data)
	if decoded.is_empty():
		return false
	var save_path := _get_save_path(slot)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_buffer(decoded)
	file.close()
	_load_save_metadata()
	return true


## --- Internal helpers ---

func _get_save_path(slot: int) -> String:
	return "%s/save_%02d.cfg" % [_save_dir, slot]


func _ensure_directories() -> void:
	if not DirAccess.dir_exists_absolute(_save_dir):
		DirAccess.make_dir_recursive_absolute(_save_dir)


func _serialize_dict(config: ConfigFile, section_prefix: String, data: Dictionary) -> void:
	for key in data:
		var value = data[key]
		var section_key := "%s/%s" % [section_prefix, key]
		if typeof(value) == TYPE_DICTIONARY:
			_serialize_dict(config, section_key, value)
		else:
			config.set_value(section_prefix, key, value)


func _deserialize_dict(config: ConfigFile, section_prefix: String) -> Dictionary:
	var result := {}
	var sections := config.get_sections()
	for section in sections:
		if section == section_prefix:
			for key in config.get_section_keys(section):
				result[key] = config.get_value(section, key)
		elif section.begins_with(section_prefix + "/"):
			var sub_key := section.substr(section_prefix.length() + 1)
			if not sub_key.contains("/"):
				result[sub_key] = _deserialize_dict(config, section)
	return result


func _load_save_metadata() -> void:
	_save_metadata.clear()
	for slot in range(_max_slots):
		var save_path := _get_save_path(slot)
		if FileAccess.file_exists(save_path):
			var config := ConfigFile.new()
			if config.load(save_path) == OK:
				_save_metadata[slot] = {
					"timestamp": config.get_value("meta", "timestamp", "unknown"),
					"name": config.get_value("meta", "slot_name", "Save %d" % slot),
					"size": FileAccess.get_file_as_bytes(save_path).size()
				}
