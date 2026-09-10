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

## Current save format version
const SAVE_VERSION: int = 2

## Minimum supported save version (older will be migrated)
const MIN_SUPPORTED_VERSION: int = 1

## Auto-save interval in seconds (0 = disabled)
var _auto_save_interval: float = 0.0

## Auto-save timer
var _auto_save_timer: float = 0.0

## Whether auto-save is enabled
var _auto_save_enabled: bool = false

## Cached settings
var _settings: ConfigFile = null

## Save metadata cache: { slot: {timestamp, name, playtime, version} }
var _save_metadata: Dictionary = {}

## Migration statistics
var _migration_stats: Dictionary = {
	"total_migrated": 0,
	"failed_migrations": 0,
	"last_migration": ""
}


func _ready() -> void:
	_ensure_directories()
	_load_settings()
	_load_save_metadata()
	GameLog.info("SaveSystem initialized", "Save")


func _process(delta: float) -> void:
	if _auto_save_enabled and _auto_save_interval > 0:
		_auto_save_timer += delta
		if _auto_save_timer >= _auto_save_interval:
			_auto_save_timer = 0.0
			auto_save()


## Save game data to a slot
func save_game(slot: int, data: Dictionary, slot_name: String = "") -> bool:
	if slot < 0 or slot >= _max_slots:
		GameLog.error("SaveSystem: Invalid slot %d" % slot, "Save")
		return false

	var save_path := _get_save_path(slot)
	var save_file := ConfigFile.new()

	# Store metadata
	save_file.set_value("meta", "timestamp", Time.get_datetime_string_from_system())
	save_file.set_value("meta", "slot_name", slot_name if not slot_name.is_empty() else "Save %d" % slot)
	save_file.set_value("meta", "version", SAVE_VERSION)
	save_file.set_value("meta", "engine_version", Engine.get_version_info()["string"])

	# Store game data (flatten dictionary to sections)
	_serialize_dict(save_file, "data", data)

	var error_code := save_file.save(save_path)
	if error_code != OK:
		GameLog.error("SaveSystem: Failed to save slot %d: error %d" % [slot, error_code], "Save")
		return false

	# Update metadata cache
	_save_metadata[slot] = {
		"timestamp": Time.get_datetime_string_from_system(),
		"name": slot_name if not slot_name.is_empty() else "Save %d" % slot,
		"size": FileAccess.get_file_as_bytes(save_path).size()
	}

	EventBus.emit("game_saved", {"slot": slot, "name": _save_metadata[slot]["name"]})
	GameLog.info("SaveSystem: Saved game to slot %d" % slot, "Save")

	# Sync to Steam cloud if available
	_sync_save_to_cloud(slot)

	return true


## Sync save file to Steam cloud
func _sync_save_to_cloud(slot: int) -> void:
	if not _is_steam_manager_available():
		return
	if not SteamManager.is_cloud_enabled():
		return
	var save_path := _get_save_path(slot)
	if not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file:
		var data := file.get_buffer(file.get_length())
		file.close()
		var cloud_filename := "save_slot_%d.cfg" % slot
		SteamManager.save_to_cloud(cloud_filename, data)
		GameLog.info("SaveSystem: Synced slot %d to Steam cloud" % slot, "Save")


## Check if Steam Manager is available
func _is_steam_manager_available() -> bool:
	return get_node_or_null("/root/SteamManager") != null


## Load save file from Steam cloud
func _load_save_from_cloud(slot: int) -> PackedByteArray:
	if not _is_steam_manager_available():
		return PackedByteArray()
	if not SteamManager.is_cloud_enabled():
		return PackedByteArray()
	var cloud_filename := "save_slot_%d.cfg" % slot
	if not SteamManager.cloud_file_exists(cloud_filename):
		return PackedByteArray()
	var data := SteamManager.load_from_cloud(cloud_filename)
	# Save to local for future use
	if data.size() > 0:
		var save_path := _get_save_path(slot)
		var file := FileAccess.open(save_path, FileAccess.WRITE)
		if file:
			file.store_buffer(data)
			file.close()
			GameLog.info("SaveSystem: Restored slot %d from Steam cloud to local" % slot, "Save")
	return data


## Parse save data from PackedByteArray to Dictionary
func _parse_save_data(data: PackedByteArray) -> Dictionary:
	var save_file := ConfigFile.new()
	# Write to temp file and load (ConfigFile doesn't support loading from buffer directly)
	var temp_path := "user://temp_cloud_save.cfg"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file:
		file.store_buffer(data)
		file.close()
	var error_code := save_file.load(temp_path)
	DirAccess.remove_absolute(temp_path)
	if error_code != OK:
		GameLog.error("SaveSystem: Failed to parse cloud save data", "Save")
		return {}
	return _deserialize_dict(save_file, "data")


## Load game data from a slot
## Automatically migrates old save formats to current version
## Falls back to Steam cloud if local save not found
func load_game(slot: int) -> Dictionary:
	if slot < 0 or slot >= _max_slots:
		GameLog.error("SaveSystem: Invalid slot %d" % slot, "Save")
		return {}

	var save_path := _get_save_path(slot)
	if not FileAccess.file_exists(save_path):
		# Try loading from Steam cloud
		var cloud_data := _load_save_from_cloud(slot)
		if cloud_data.size() > 0:
			GameLog.info("SaveSystem: Loaded slot %d from Steam cloud" % slot, "Save")
			return _parse_save_data(cloud_data)
		GameLog.warning("SaveSystem: No save in slot %d" % slot, "Save")
		return {}

	var save_file := ConfigFile.new()
	var error_code := save_file.load(save_path)
	if error_code != OK:
		GameLog.error("SaveSystem: Failed to load slot %d: error %d" % [slot, error_code], "Save")
		return {}

	# Check version and migrate if needed
	var save_version := int(save_file.get_value("meta", "version", "1"))
	if save_version < SAVE_VERSION:
		GameLog.info("SaveSystem: Migrating save slot %d from v%d to v%d" % [slot, save_version, SAVE_VERSION], "Save")
		var migrated := _migrate_save(save_file, save_version)
		if migrated:
			save_file.save(save_path)
			_migration_stats["total_migrated"] += 1
			_migration_stats["last_migration"] = "slot %d: v%d -> v%d" % [slot, save_version, SAVE_VERSION]
		else:
			_migration_stats["failed_migrations"] += 1
			GameLog.error("SaveSystem: Migration failed for slot %d" % slot, "Save")

	var data := _deserialize_dict(save_file, "data")
	EventBus.emit("game_loaded", {"slot": slot, "version": SAVE_VERSION})
	GameLog.info("SaveSystem: Loaded game from slot %d (v%d)" % [slot, SAVE_VERSION], "Save")
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
		GameLog.error("SaveSystem: Failed to delete slot %d" % slot, "Save")
		return false

	_save_metadata.erase(slot)
	EventBus.emit("save_deleted", {"slot": slot})
	GameLog.info("SaveSystem: Deleted save slot %d" % slot, "Save")
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
	var data := GameState.get_ns("game")
	data["souls"] = GameState.get_ns("soul")
	data["world"] = GameState.get_ns("world")
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
					"size": FileAccess.get_file_as_bytes(save_path).size(),
					"version": int(config.get_value("meta", "version", "1"))
				}


## --- Save Migration ---

## Migrate a save file from an older version to current
## Returns true if migration was successful
func _migrate_save(config: ConfigFile, from_version: int) -> bool:
	var current := from_version

	# Migration chain: each step upgrades one version
	while current < SAVE_VERSION:
		match current:
			1:
				if not _migrate_v1_to_v2(config):
					return false
			_:
				GameLog.warning("SaveSystem: No migration path for v%d" % current, "Save")
				return false
		current += 1

	config.set_value("meta", "version", SAVE_VERSION)
	return true


## Migration from v1 to v2
## v2 adds: playtime tracking, schema version, normalized data sections
func _migrate_v1_to_v2(config: ConfigFile) -> bool:
	# Add playtime if missing
	if not config.has_section_key("meta", "playtime"):
		config.set_value("meta", "playtime", 0.0)

	# Add schema version
	if not config.has_section_key("meta", "schema_version"):
		config.set_value("meta", "schema_version", "2.0")

	# Ensure data section exists
	if not config.has_section("data"):
		config.set_value("data", "migrated", true)

	GameLog.info("SaveSystem: Migrated v1 -> v2", "Save")
	return true


## Get migration statistics
func get_migration_stats() -> Dictionary:
	return _migration_stats.duplicate()


## Get save format version
func get_save_version() -> int:
	return SAVE_VERSION


## Check if a save needs migration
func needs_migration(slot: int) -> bool:
	var save_path := _get_save_path(slot)
	if not FileAccess.file_exists(save_path):
		return false
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return false
	var version := int(config.get_value("meta", "version", "1"))
	return version < SAVE_VERSION
