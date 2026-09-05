extends Node
## SeedClient - Seed world engine API client wrapper
##
## Encapsulates all Seed world engine API calls.
## Seed provides world simulation, entity management, and SoulBridgeAdapter.
##
## Seed API base: http://localhost:3001
##
## Usage:
##   SeedClient.create_world("forest_01", config, callback)
##   SeedClient.spawn_soul("world_01", "soul_001", position, callback)
##   SeedClient.get_world_state("world_01", callback)
##   SeedClient.tick_world("world_01", callback)

## API base URL
var _base_url: String = "http://localhost:3001"

## SDK version
var _sdk_version: String = "dist"

## Whether client is connected
var _connected: bool = false

## Active worlds
var _active_worlds: Array = []

## Request statistics
var _stats: Dictionary = {
	"total_calls": 0,
	"successful": 0,
	"failed": 0,
	"active_worlds": 0,
	"total_ticks": 0
}


func _ready() -> void:
	_load_config()
	GameLog.info("SeedClient initialized (v%s, base=%s)" % [_sdk_version, _base_url], "Seed")


## Load configuration from ConfigManager
func _load_config() -> void:
	_base_url = ConfigManager.get_value("sdk", "seed", "base_url", _base_url)
	_sdk_version = ConfigManager.get_value("sdk", "seed", "version", _sdk_version)


## --- World Management ---

## Create a new world
## POST /api/worlds
func create_world(world_id: String, config: Dictionary = {}, callback_target: Object = null, callback_method: String = "") -> void:
	_stats["total_calls"] += 1
	var body := {
		"id": world_id,
		"name": config.get("name", world_id),
		"config": config
	}
	NetworkClient.http_post("%s/api/worlds" % _base_url, body, self, "_on_world_created")
	_pending_callbacks["create_world"] = {"target": callback_target, "method": callback_method, "world_id": world_id}


## Get world state
## GET /api/worlds/:id
func get_world_state(world_id: String, callback_target: Object = null, callback_method: String = "") -> void:
	_stats["total_calls"] += 1
	NetworkClient.http_get("%s/api/worlds/%s" % [_base_url, world_id], callback_target, callback_method)


## List all worlds
## GET /api/worlds
func list_worlds(callback_target: Object = null, callback_method: String = "") -> void:
	_stats["total_calls"] += 1
	NetworkClient.http_get("%s/api/worlds" % _base_url, callback_target, callback_method)


## Delete a world
## DELETE /api/worlds/:id
func delete_world(world_id: String, callback_target: Object = null, callback_method: String = "") -> void:
	_stats["total_calls"] += 1
	NetworkClient.http_delete("%s/api/worlds/%s" % [_base_url, world_id], callback_target, callback_method)
	_active_worlds.erase(world_id)
	_stats["active_worlds"] = _active_worlds.size()


## --- World Tick ---

## Advance world by one tick
## POST /api/worlds/:id/tick
func tick_world(world_id: String, callback_target: Object = null, callback_method: String = "") -> void:
	_stats["total_calls"] += 1
	_stats["total_ticks"] += 1
	NetworkClient.http_post("%s/api/worlds/%s/tick" % [_base_url, world_id], {}, callback_target, callback_method)


## Run multiple ticks
## POST /api/worlds/:id/tick-multiple
func tick_world_multiple(world_id: String, count: int, callback_target: Object = null, callback_method: String = "") -> void:
	_stats["total_calls"] += 1
	_stats["total_ticks"] += count
	var body := {"count": count}
	NetworkClient.http_post("%s/api/worlds/%s/tick-multiple" % [_base_url, world_id], body, callback_target, callback_method)


## --- Soul Management in World ---

## Spawn a soul in the world
## POST /api/worlds/:id/souls
func spawn_soul(world_id: String, soul_id: String, position: Dictionary = {}, callback_target: Object = null, callback_method: String = "") -> void:
	_stats["total_calls"] += 1
	var body := {
		"soulId": soul_id,
		"position": position
	}
	NetworkClient.http_post("%s/api/worlds/%s/souls" % [_base_url, world_id], body, callback_target, callback_method)


## Remove a soul from world
## DELETE /api/worlds/:id/souls/:soulId
func remove_soul(world_id: String, soul_id: String, callback_target: Object = null, callback_method: String = "") -> void:
	_stats["total_calls"] += 1
	NetworkClient.http_delete("%s/api/worlds/%s/souls/%s" % [_base_url, world_id, soul_id], callback_target, callback_method)


## Get soul state in world
## GET /api/worlds/:id/souls/:soulId
func get_soul_in_world(world_id: String, soul_id: String, callback_target: Object = null, callback_method: String = "") -> void:
	_stats["total_calls"] += 1
	NetworkClient.http_get("%s/api/worlds/%s/souls/%s" % [_base_url, world_id, soul_id], callback_target, callback_method)


## --- Entity Management ---

## Spawn an entity in world
## POST /api/worlds/:id/entities
func spawn_entity(world_id: String, entity_type: String, position: Dictionary, config: Dictionary = {}, callback_target: Object = null, callback_method: String = "") -> void:
	_stats["total_calls"] += 1
	var body := {
		"type": entity_type,
		"position": position,
		"config": config
	}
	NetworkClient.http_post("%s/api/worlds/%s/entities" % [_base_url, world_id], body, callback_target, callback_method)


## List entities in world
## GET /api/worlds/:id/entities
func list_entities(world_id: String, callback_target: Object = null, callback_method: String = "") -> void:
	_stats["total_calls"] += 1
	NetworkClient.http_get("%s/api/worlds/%s/entities" % [_base_url, world_id], callback_target, callback_method)


## --- Bridge / Adapter ---

## Get SoulBridgeAdapter status
## GET /api/bridge/status
func get_bridge_status(callback_target: Object = null, callback_method: String = "") -> void:
	_stats["total_calls"] += 1
	NetworkClient.http_get("%s/api/bridge/status" % _base_url, callback_target, callback_method)


## Start bridge for a soul
## POST /api/bridge/start
func start_bridge(soul_id: String, world_id: String, callback_target: Object = null, callback_method: String = "") -> void:
	_stats["total_calls"] += 1
	var body := {
		"soulId": soul_id,
		"worldId": world_id
	}
	NetworkClient.http_post("%s/api/bridge/start" % _base_url, body, callback_target, callback_method)


## Stop bridge for a soul
## POST /api/bridge/stop
func stop_bridge(soul_id: String, callback_target: Object = null, callback_method: String = "") -> void:
	_stats["total_calls"] += 1
	var body := {"soulId": soul_id}
	NetworkClient.http_post("%s/api/bridge/stop" % _base_url, body, callback_target, callback_method)


## --- Connection Testing ---

## Check if Seed API is reachable
func check_connection() -> bool:
	return NetworkClient.check_connectivity("%s/api/worlds" % _base_url)


## Get client statistics
func get_stats() -> Dictionary:
	return _stats.duplicate()


## Get SDK version
func get_version() -> String:
	return _sdk_version


## Get base URL
func get_base_url() -> String:
	return _base_url


## Set base URL (for testing)
func set_base_url(url: String) -> void:
	_base_url = url


## --- Internal callbacks ---

var _pending_callbacks: Dictionary = {}


func _on_world_created(status: int, data: Dictionary) -> void:
	if status >= 200 and status < 300:
		_stats["successful"] += 1
		if _pending_callbacks.has("create_world"):
			var world_id = _pending_callbacks["create_world"]["world_id"]
			if not _active_worlds.has(world_id):
				_active_worlds.append(world_id)
			_stats["active_worlds"] = _active_worlds.size()
		_connected = true
		GameLog.info("SeedClient: World created successfully", "Seed")
	else:
		_stats["failed"] += 1
		GameLog.error("SeedClient: Create world failed: %s" % str(data), "Seed")

	if _pending_callbacks.has("create_world"):
		var cb = _pending_callbacks["create_world"]
		if cb["target"] and is_instance_valid(cb["target"]) and not cb["method"].is_empty():
			cb["target"].call(cb["method"], status, data)
		_pending_callbacks.erase("create_world")
