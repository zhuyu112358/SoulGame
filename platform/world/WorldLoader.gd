extends Node
## WorldLoader - Manages loading and lifecycle of world plugins
##
## This is the platform's world management system. It discovers, loads, and
## manages WorldPlugin instances. Third-party worlds are loaded dynamically.
##
## This is PLATFORM code. The RTS game uses this to load the arena world,
## but the loader itself is game-agnostic and can load any world plugin.

# Preload WorldPlugin base class
const WorldPlugin = preload("res://platform/world/WorldPlugin.gd")

## Registered plugin classes (plugin_id -> script path)
var _registered_plugins: Dictionary = {}

## Loaded plugin instances (plugin_id -> WorldPlugin)
var _loaded_plugins: Dictionary = {}

## Currently active world plugin
var _active_world = null

## Current world plugin ID
var _current_world_id: String = ""

## Plugin search paths
var _plugin_paths: Array = ["res://platform/world/plugins/", "res://worlds/"]


func _ready() -> void:
	GameLog.info("WorldLoader: Initialized", "Platform")
	_register_builtin_worlds()


## Register built-in world plugins
func _register_builtin_worlds() -> void:
	# Built-in worlds can be registered here
	# Third-party worlds are discovered from plugin paths
	GameLog.info("WorldLoader: Built-in worlds registered", "Platform")


## Register a world plugin class
func register_plugin(p_plugin_id: String, p_script_path: String) -> void:
	_registered_plugins[p_plugin_id] = p_script_path
	GameLog.info("WorldLoader: Registered plugin '%s'" % p_plugin_id, "Platform")


## Unregister a world plugin
func unregister_plugin(p_plugin_id: String) -> void:
	if _registered_plugins.has(p_plugin_id):
		_registered_plugins.erase(p_plugin_id)
		GameLog.info("WorldLoader: Unregistered plugin '%s'" % p_plugin_id, "Platform")


## Discover plugins from search paths
func discover_plugins() -> Array:
	var discovered: Array = []
	for path in _plugin_paths:
		if not DirAccess.dir_exists_absolute(path):
			continue
		var dir = DirAccess.open(path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".gd"):
				var plugin_id = file_name.get_basename()
				if not _registered_plugins.has(plugin_id):
					_registered_plugins[plugin_id] = path + file_name
					discovered.append(plugin_id)
			file_name = dir.get_next()
		dir.list_dir_end()
	GameLog.info("WorldLoader: Discovered %d new plugins" % discovered.size(), "Platform")
	return discovered


## Load a world plugin by ID
## Returns the loaded WorldPlugin instance, or null on failure
func load_world(p_plugin_id: String):
	if _loaded_plugins.has(p_plugin_id):
		return _loaded_plugins[p_plugin_id]

	if not _registered_plugins.has(p_plugin_id):
		GameLog.error("WorldLoader: Plugin '%s' not registered" % p_plugin_id, "Platform")
		return null

	var script_path = _registered_plugins[p_plugin_id]
	var plugin_script = load(script_path)
	if plugin_script == null:
		GameLog.error("WorldLoader: Failed to load script %s" % script_path, "Platform")
		return null

	var plugin = plugin_script.new()
	if plugin == null:
		GameLog.error("WorldLoader: Failed to instantiate plugin '%s'" % p_plugin_id, "Platform")
		return null

	# Initialize plugin
	plugin._init_plugin()

	# Load world resources
	if not plugin.load_world():
		GameLog.error("WorldLoader: Plugin '%s' failed to load world" % p_plugin_id, "Platform")
		return null

	_loaded_plugins[p_plugin_id] = plugin
	GameLog.info("WorldLoader: Loaded world '%s'" % p_plugin_id, "Platform")
	return plugin


## Unload a world plugin
func unload_world(p_plugin_id: String) -> void:
	if not _loaded_plugins.has(p_plugin_id):
		return

	if _current_world_id == p_plugin_id:
		exit_current_world(null)

	var plugin = _loaded_plugins[p_plugin_id]
	plugin.unload_world()
	_loaded_plugins.erase(p_plugin_id)
	GameLog.info("WorldLoader: Unloaded world '%s'" % p_plugin_id, "Platform")


## Enter a world (soul enters the world)
func enter_world(p_plugin_id: String, p_soul_snapshot) -> Dictionary:
	var plugin = load_world(p_plugin_id)
	if plugin == null:
		return {"success": false, "error": "Failed to load world"}

	# Exit current world if any
	if _active_world and _current_world_id != p_plugin_id:
		exit_current_world(p_soul_snapshot)

	var result = plugin.enter_world(p_soul_snapshot)
	if result.get("success", false):
		_active_world = plugin
		_current_world_id = p_plugin_id
		GameLog.info("WorldLoader: Entered world '%s'" % p_plugin_id, "Platform")
	return result


## Exit current world
func exit_current_world(p_soul_snapshot) -> Dictionary:
	if _active_world == null:
		return {"success": true, "data": {}}

	var result = _active_world.exit_world(p_soul_snapshot)
	GameLog.info("WorldLoader: Exited world '%s'" % _current_world_id, "Platform")
	_active_world = null
	_current_world_id = ""
	return result


## Update active world
func _process(delta: float) -> void:
	if _active_world:
		_active_world.update_world(delta)


## Get current active world
func get_current_world():
	return _active_world


## Get current world ID
func get_current_world_id() -> String:
	return _current_world_id


## Get all registered plugin IDs
func get_registered_worlds() -> Array:
	return _registered_plugins.keys()


## Get all loaded plugin IDs
func get_loaded_worlds() -> Array:
	return _loaded_plugins.keys()


## Get world info
func get_world_info(p_plugin_id: String) -> Dictionary:
	if _loaded_plugins.has(p_plugin_id):
		return _loaded_plugins[p_plugin_id].get_world_info()
	if _registered_plugins.has(p_plugin_id):
		return {
			"id": p_plugin_id,
			"loaded": false,
			"script": _registered_plugins[p_plugin_id]
		}
	return {"id": p_plugin_id, "error": "Not registered"}


## Get loader stats
func get_stats() -> Dictionary:
	return {
		"registered": _registered_plugins.size(),
		"loaded": _loaded_plugins.size(),
		"current_world": _current_world_id,
		"active": _active_world != null
	}
