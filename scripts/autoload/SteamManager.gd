## SteamManager - Steamworks SDK integration wrapper
##
## Provides a unified interface for Steam features with local fallback
## when Steamworks SDK is not available. Use conditional compilation
## with STEAMWORKS_ENABLED define to enable actual Steam integration.
##
## Features:
## - Steam initialization/shutdown
## - Achievement unlock/progress
## - Cloud save/load
## - Stats tracking
## - Friend list (basic)
## - Overlay activation
extends Node

signal steam_initialized(success: bool)
signal achievement_unlocked(achievement_id: String)
signal achievement_progress(achievement_id: String, current: int, max: int)
signal cloud_save_completed(success: bool, file: String)
signal cloud_load_completed(success: bool, file: String)
signal overlay_activated()
signal friend_joined_game(friend_id: String)

## Steam initialization state
var _initialized: bool = false
var _steam_running: bool = false
var _app_id: int = 0

## Local achievement cache (fallback when Steam not available)
var _local_achievements: Dictionary = {}
var _local_achievement_progress: Dictionary = {}

## Local stats cache (fallback)
var _local_stats: Dictionary = {}

## Cloud save state
var _cloud_enabled: bool = false
var _local_save_path: String = "user://steam_cloud/"

## Friend data (fallback)
var _local_friends: Array = []

## Steam user info
var _steam_id: String = ""
var _steam_name: String = ""
var _steam_level: int = 0

## Configuration
var _auto_init: bool = true
var _use_cloud: bool = true


func _ready() -> void:
	if _auto_init:
		initialize()


## Initialize Steamworks
func initialize() -> bool:
	# Try Steamworks SDK if available
	#if STEAMWORKS_ENABLED:
	#	return _init_steamworks()

	# Local fallback
	_steam_running = false
	_initialized = true
	_steam_id = "local_player_%d" % Time.get_unix_time_from_system()
	_steam_name = "Local Player"
	_load_local_data()
	steam_initialized.emit(true)
	return true


## Check if Steam is initialized and running
func is_initialized() -> bool:
	return _initialized


## Check if actual Steam client is running
func is_steam_running() -> bool:
	return _steam_running


## Get Steam ID
func get_steam_id() -> String:
	return _steam_id


## Get Steam display name
func get_steam_name() -> String:
	return _steam_name


## Get Steam level
func get_steam_level() -> int:
	return _steam_level


# ==================== Achievements ====================

## Unlock an achievement
func unlock_achievement(p_achievement_id: String) -> bool:
	if p_achievement_id.is_empty():
		return false

	#if STEAMWORKS_ENABLED and _steam_running:
	#	return _steam_unlock_achievement(p_achievement_id)

	# Local fallback
	if not _local_achievements.has(p_achievement_id):
		_local_achievements[p_achievement_id] = true
		_save_local_data()
		achievement_unlocked.emit(p_achievement_id)
		return true
	return false


## Check if achievement is unlocked
func is_achievement_unlocked(p_achievement_id: String) -> bool:
	#if STEAMWORKS_ENABLED and _steam_running:
	#	return _steam_is_achievement_unlocked(p_achievement_id)

	return _local_achievements.get(p_achievement_id, false)


## Set achievement progress (for progress-based achievements)
func set_achievement_progress(p_achievement_id: String, p_current: int, p_max: int) -> bool:
	if p_achievement_id.is_empty() or p_max <= 0:
		return false

	#if STEAMWORKS_ENABLED and _steam_running:
	#	return _steam_set_achievement_progress(p_achievement_id, p_current, p_max)

	# Local fallback
	_local_achievement_progress[p_achievement_id] = {
		"current": p_current,
		"max": p_max
	}
	achievement_progress.emit(p_achievement_id, p_current, p_max)

	# Auto-unlock if progress complete
	if p_current >= p_max:
		return unlock_achievement(p_achievement_id)

	_save_local_data()
	return true


## Get achievement progress
func get_achievement_progress(p_achievement_id: String) -> Dictionary:
	#if STEAMWORKS_ENABLED and _steam_running:
	#	return _steam_get_achievement_progress(p_achievement_id)

	return _local_achievement_progress.get(p_achievement_id, {"current": 0, "max": 0})


## Clear achievement (for testing)
func clear_achievement(p_achievement_id: String) -> bool:
	#if STEAMWORKS_ENABLED and _steam_running:
	#	return _steam_clear_achievement(p_achievement_id)

	if _local_achievements.has(p_achievement_id):
		_local_achievements.erase(p_achievement_id)
		_local_achievement_progress.erase(p_achievement_id)
		_save_local_data()
		return true
	return false


## Get all unlocked achievements
func get_unlocked_achievements() -> Array:
	#if STEAMWORKS_ENABLED and _steam_running:
	#	return _steam_get_unlocked_achievements()

	return _local_achievements.keys()


# ==================== Stats ====================

## Set a stat value
func set_stat(p_stat_name: String, p_value: int) -> bool:
	if p_stat_name.is_empty():
		return false

	#if STEAMWORKS_ENABLED and _steam_running:
	#	return _steam_set_stat(p_stat_name, p_value)

	_local_stats[p_stat_name] = p_value
	_save_local_data()
	return true


## Get a stat value
func get_stat(p_stat_name: String, p_default: int = 0) -> int:
	#if STEAMWORKS_ENABLED and _steam_running:
	#	return _steam_get_stat(p_stat_name, p_default)

	return _local_stats.get(p_stat_name, p_default)


## Increment a stat value
func increment_stat(p_stat_name: String, p_amount: int = 1) -> int:
	var current = get_stat(p_stat_name)
	var new_value = current + p_amount
	set_stat(p_stat_name, new_value)
	return new_value


## Store stats to Steam (must call after setting stats)
func store_stats() -> bool:
	#if STEAMWORKS_ENABLED and _steam_running:
	#	return _steam_store_stats()

	_save_local_data()
	return true


# ==================== Cloud Save ====================

## Enable/disable cloud saves
func set_cloud_enabled(p_enabled: bool) -> void:
	_cloud_enabled = p_enabled
	_use_cloud = p_enabled


## Check if cloud is enabled
func is_cloud_enabled() -> bool:
	return _cloud_enabled


## Save file to cloud
func save_to_cloud(p_filename: String, p_data: PackedByteArray) -> bool:
	if p_filename.is_empty():
		return false

	#if STEAMWORKS_ENABLED and _steam_running and _cloud_enabled:
	#	return _steam_cloud_save(p_filename, p_data)

	# Local fallback
	var dir = DirAccess.open(_local_save_path)
	if dir == null:
		dir.make_dir_recursive(_local_save_path)
	var file_path = _local_save_path + p_filename
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_buffer(p_data)
		file.close()
		cloud_save_completed.emit(true, p_filename)
		return true
	cloud_save_completed.emit(false, p_filename)
	return false


## Load file from cloud
func load_from_cloud(p_filename: String) -> PackedByteArray:
	if p_filename.is_empty():
		return PackedByteArray()

	#if STEAMWORKS_ENABLED and _steam_running and _cloud_enabled:
	#	return _steam_cloud_load(p_filename)

	# Local fallback
	var file_path = _local_save_path + p_filename
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var data = file.get_buffer(file.get_length())
			file.close()
			cloud_load_completed.emit(true, p_filename)
			return data
	cloud_load_completed.emit(false, p_filename)
	return PackedByteArray()


## Check if cloud file exists
func cloud_file_exists(p_filename: String) -> bool:
	#if STEAMWORKS_ENABLED and _steam_running and _cloud_enabled:
	#	return _steam_cloud_file_exists(p_filename)

	return FileAccess.file_exists(_local_save_path + p_filename)


## Delete cloud file
func delete_cloud_file(p_filename: String) -> bool:
	#if STEAMWORKS_ENABLED and _steam_running and _cloud_enabled:
	#	return _steam_cloud_delete(p_filename)

	var file_path = _local_save_path + p_filename
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
		return true
	return false


# ==================== Friends ====================

## Get friend count
func get_friend_count() -> int:
	#if STEAMWORKS_ENABLED and _steam_running:
	#	return _steam_get_friend_count()

	return _local_friends.size()


## Get friend list
func get_friend_list() -> Array:
	#if STEAMWORKS_ENABLED and _steam_running:
	#	return _steam_get_friend_list()

	return _local_friends.duplicate()


## Get friend name
func get_friend_name(p_friend_id: String) -> String:
	#if STEAMWORKS_ENABLED and _steam_running:
	#	return _steam_get_friend_name(p_friend_id)

	for friend in _local_friends:
		if friend.get("id", "") == p_friend_id:
			return friend.get("name", "Unknown")
	return "Unknown"


## Get friend persona state (0=offline, 1=online, 2=busy, 3=away, 4=snooze)
func get_friend_persona_state(p_friend_id: String) -> int:
	#if STEAMWORKS_ENABLED and _steam_running:
	#	return _steam_get_friend_persona_state(p_friend_id)

	for friend in _local_friends:
		if friend.get("id", "") == p_friend_id:
			return friend.get("state", 0)
	return 0


## Invite friend to game
func invite_friend_to_game(p_friend_id: String, p_connect_string: String = "") -> bool:
	#if STEAMWORKS_ENABLED and _steam_running:
	#	return _steam_invite_friend(p_friend_id, p_connect_string)

	return false


# ==================== Overlay ====================

## Activate Steam overlay to a specific page
func activate_overlay(p_page: String = "Friends") -> void:
	#if STEAMWORKS_ENABLED and _steam_running:
	#	_steam_activate_overlay(p_page)
	#	return

	overlay_activated.emit()


## Activate overlay to user profile
func activate_overlay_to_user(p_user_id: String, p_page: String = "steamid") -> void:
	#if STEAMWORKS_ENABLED and _steam_running:
	#	_steam_activate_overlay_to_user(p_user_id, p_page)
	#	return

	overlay_activated.emit()


## Activate overlay to store page
func activate_overlay_to_store(p_app_id: int = 0) -> void:
	#if STEAMWORKS_ENABLED and _steam_running:
	#	_steam_activate_overlay_to_store(p_app_id)
	#	return

	overlay_activated.emit()


## Check if overlay is enabled
func is_overlay_enabled() -> bool:
	#if STEAMWORKS_ENABLED and _steam_running:
	#	return _steam_is_overlay_enabled()

	return false


# ==================== App Info ====================

## Get app ID
func get_app_id() -> int:
	return _app_id


## Set app ID (for testing)
func set_app_id(p_app_id: int) -> void:
	_app_id = p_app_id


## Check if app is installed
func is_app_installed(p_app_id: int) -> bool:
	#if STEAMWORKS_ENABLED and _steam_running:
	#	return _steam_is_app_installed(p_app_id)

	return p_app_id == _app_id


## Get app install directory
func get_app_install_dir(p_app_id: int = 0) -> String:
	#if STEAMWORKS_ENABLED and _steam_running:
	#	return _steam_get_app_install_dir(p_app_id)

	return OS.get_executable_path().get_base_dir()


# ==================== DLC ====================

## Check if DLC is installed
func is_dlc_installed(p_app_id: int) -> bool:
	#if STEAMWORKS_ENABLED and _steam_running:
	#	return _steam_is_dlc_installed(p_app_id)

	return false


## Install DLC
func install_dlc(p_app_id: int) -> void:
	#if STEAMWORKS_ENABLED and _steam_running:
	#	_steam_install_dlc(p_app_id)
	pass


# ==================== Local Data Persistence ====================

## Save local data to file
func _save_local_data() -> void:
	var data = {
		"achievements": _local_achievements,
		"achievement_progress": _local_achievement_progress,
		"stats": _local_stats,
		"friends": _local_friends
	}
	var file = FileAccess.open("user://steam_manager_data.cfg", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()


## Load local data from file
func _load_local_data() -> void:
	var file_path = "user://steam_manager_data.cfg"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var json = JSON.new()
			var result = json.parse(file.get_as_text())
			file.close()
			if result == OK:
				var data = json.data
				if data is Dictionary:
					_local_achievements = data.get("achievements", {})
					_local_achievement_progress = data.get("achievement_progress", {})
					_local_stats = data.get("stats", {})
					_local_friends = data.get("friends", [])


# ==================== Process ====================

func _process(delta: float) -> void:
	#if STEAMWORKS_ENABLED and _steam_running:
	#	_steam_run_callbacks()
	pass


func _exit_tree() -> void:
	#if STEAMWORKS_ENABLED and _steam_running:
	#	_steam_shutdown()
	_save_local_data()


## Get manager info/status
func get_info() -> Dictionary:
	return {
		"initialized": _initialized,
		"steam_running": _steam_running,
		"steam_id": _steam_id,
		"steam_name": _steam_name,
		"steam_level": _steam_level,
		"app_id": _app_id,
		"cloud_enabled": _cloud_enabled,
		"unlocked_achievements": _local_achievements.size(),
		"tracked_stats": _local_stats.size(),
		"friend_count": _local_friends.size(),
		"overlay_enabled": is_overlay_enabled()
	}
