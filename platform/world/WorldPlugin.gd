extends RefCounted
## WorldPlugin - Base class for third-party world plugins
##
## This is the extension point for third-party developers to create new worlds
## for the Sojourn platform. Each world plugin defines a self-contained world
## with its own rules, environments, and interactions.
##
## Third-party developers extend this class and implement the required methods.
## The platform loads plugins dynamically via WorldLoader.
##
## This is PLATFORM code. Game-specific world logic should extend this.

## Plugin unique identifier (reverse domain format recommended)
var plugin_id: String = ""

## Plugin display name
var plugin_name: String = ""

## Plugin version
var plugin_version: String = "1.0.0"

## Plugin author
var author: String = ""

## Plugin description
var description: String = ""

## World type: "exploration" | "battle" | "social" | "creative" | "custom"
var world_type: String = "exploration"

## Supported platform API version
var api_version: String = "1.0.0"

## Whether plugin is currently loaded
var _loaded: bool = false

## Whether plugin is currently active
var _active: bool = false

## Plugin configuration
var config: Dictionary = {}

## World state (runtime)
var world_state: Dictionary = {}


## Initialize plugin (called when plugin is loaded)
## Override in subclass to set up plugin-specific data
func _init_plugin() -> void:
	pass


## Load world resources (called before entering world)
## Returns true if load succeeded
func load_world() -> bool:
	if _loaded:
		return true
	_loaded = _on_load()
	return _loaded


## Unload world resources (called after leaving world)
func unload_world() -> void:
	if not _loaded:
		return
	_on_unload()
	_loaded = false
	_active = false


## Enter world (player/soul enters this world)
func enter_world(p_soul_snapshot) -> Dictionary:
	if not _loaded:
		return {"success": false, "error": "World not loaded"}
	_active = true
	return _on_enter(p_soul_snapshot)


## Exit world (player/soul leaves this world)
func exit_world(p_soul_snapshot) -> Dictionary:
	if not _active:
		return {"success": false, "error": "World not active"}
	var result = _on_exit(p_soul_snapshot)
	_active = false
	return result


## Update world (called every frame/tick)
func update_world(p_delta: float) -> void:
	if not _active:
		return
	_on_update(p_delta)


## Get world info for display
func get_world_info() -> Dictionary:
	return {
		"id": plugin_id,
		"name": plugin_name,
		"version": plugin_version,
		"author": author,
		"description": description,
		"type": world_type,
		"loaded": _loaded,
		"active": _active,
		"state": world_state.duplicate()
	}


## Check if plugin supports a feature
func supports_feature(p_feature: String) -> bool:
	var features = get_supported_features()
	return features.has(p_feature)


## Get list of supported features (override in subclass)
func get_supported_features() -> Array:
	return []


## === Virtual methods to override in subclass ===

## Called when world is loaded (override)
func _on_load() -> bool:
	return true


## Called when world is unloaded (override)
func _on_unload() -> void:
	pass


## Called when soul enters world (override)
## Returns {success: bool, data: Dictionary}
func _on_enter(p_soul_snapshot) -> Dictionary:
	return {"success": true, "data": {}}


## Called when soul exits world (override)
## Returns {success: bool, data: Dictionary}
func _on_exit(p_soul_snapshot) -> Dictionary:
	return {"success": true, "data": {}}


## Called every update (override)
func _on_update(p_delta: float) -> void:
	pass


## Serialize plugin state
func serialize_state() -> Dictionary:
	return {
		"plugin_id": plugin_id,
		"plugin_version": plugin_version,
		"world_state": world_state.duplicate(),
		"config": config.duplicate()
	}


## Deserialize plugin state
func deserialize_state(p_data: Dictionary) -> void:
	world_state = p_data.get("world_state", {})
	config = p_data.get("config", {})
