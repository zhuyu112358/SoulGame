extends Node
## SoulArenaClient - SoulArena SDK API client wrapper
##
## Encapsulates all SoulArena API calls with unified error handling,
## timeout, and retry. Aligns with interface_spec.md v1.0.
##
## SoulArena API base: http://localhost:3000
##
## Usage:
##   SoulArenaClient.get_souls(self, "_on_souls")
##   SoulArenaClient.enter_world("soul_001", "world_01", callback)
##   SoulArenaClient.perceive("soul_001", perception_data, callback)
##   SoulArenaClient.exit_world("soul_001")

## API base URL
var _base_url: String = "http://localhost:3000"

## SDK version
var _sdk_version: String = "4.2.0"

## Whether client is connected
var _connected: bool = false

## Last error
var _last_error: String = ""

## Request statistics
var _stats: Dictionary = {
	"total_calls": 0,
	"successful": 0,
	"failed": 0,
	"active_souls": 0
}


func _ready() -> void:
	_load_config()
	GameLog.info("SoulArenaClient initialized (v%s, base=%s)" % [_sdk_version, _base_url], "SoulArena")


## Load configuration from ConfigManager
func _load_config() -> void:
	_base_url = ConfigManager.get_value("sdk", "soularena", "base_url", _base_url)
	_sdk_version = ConfigManager.get_value("sdk", "soularena", "version", _sdk_version)


## --- Soul Management ---

## Get list of all souls
## GET /api/souls
func get_souls(callback_target: Object = null, callback_method: String = "") -> void:
	_stats["total_calls"] += 1
	NetworkClient.http_get("%s/api/souls" % _base_url, callback_target, callback_method)


## Get soul details
## GET /api/souls/:id
func get_soul(soul_id: String, callback_target: Object = null, callback_method: String = "") -> void:
	_stats["total_calls"] += 1
	NetworkClient.http_get("%s/api/souls/%s" % [_base_url, soul_id], callback_target, callback_method)


## --- World Lifecycle ---

## Enter a soul into a world
## POST /api/souls/:id/enter-world
func enter_world(soul_id: String, world_id: String, callback_url: String = "", callback_target: Object = null, callback_method: String = "") -> void:
	_stats["total_calls"] += 1
	var body := {
		"worldId": world_id,
		"worldName": world_id,
		"callbackUrl": callback_url,
		"communicationMedium": "direct_api",
		"perceptionConfig": {},
		"worldRules": {}
	}
	NetworkClient.http_post("%s/api/souls/%s/enter-world" % [_base_url, soul_id], body, self, "_on_enter_world")
	# Store callback for chaining
	_pending_callbacks["enter_world"] = {"target": callback_target, "method": callback_method, "soul_id": soul_id}


## Get world connection state for a soul
## GET /api/souls/:id/world-state
func get_world_state(soul_id: String, callback_target: Object = null, callback_method: String = "") -> void:
	_stats["total_calls"] += 1
	NetworkClient.http_get("%s/api/souls/%s/world-state" % [_base_url, soul_id], callback_target, callback_method)


## Exit a soul from a world
## POST /api/souls/:id/exit-world
func exit_world(soul_id: String, reason: String = "unknown", callback_target: Object = null, callback_method: String = "") -> void:
	_stats["total_calls"] += 1
	var body := {"reason": reason}
	NetworkClient.http_post("%s/api/souls/%s/exit-world" % [_base_url, soul_id], body, callback_target, callback_method)


## --- Perception / Action Loop ---

## Send perception data to a soul
## POST /api/souls/:id/perceive
##
## perception format (simplified mode recommended):
## {
##   "tick": 0,
##   "situation": "You are in a dark forest...",  # simplified mode
##   "perception": { "visual": {...}, "auditory": {...}, ... },
##   "events": [...],
##   "worldState": {}
## }
func perceive(soul_id: String, perception: Dictionary, callback_target: Object = null, callback_method: String = "") -> void:
	_stats["total_calls"] += 1
	NetworkClient.http_post("%s/api/souls/%s/perceive" % [_base_url, soul_id], perception, callback_target, callback_method)


## Send action result back to soul
## POST /api/souls/:id/action-result
##
## action_type: "speak" | "expression" | "move" | "interact" | etc.
## result: arbitrary result data
func action_result(soul_id: String, action_id: String, action_type: String, result: Dictionary, success: bool = true, callback_target: Object = null, callback_method: String = "") -> void:
	_stats["total_calls"] += 1
	var body := {
		"actionId": action_id,
		"type": action_type,
		"success": success,
		"result": result,
		"tick": GameState.get_value("session", "tick_count", 0)
	}
	NetworkClient.http_post("%s/api/souls/%s/action-result" % [_base_url, soul_id], body, callback_target, callback_method)


## --- Connection Testing ---

## Check if SoulArena API is reachable
func check_connection() -> bool:
	return NetworkClient.check_connectivity("%s/api/souls" % _base_url)


## Ping the API (simple connectivity test)
func ping(callback_target: Object = null, callback_method: String = "") -> void:
	NetworkClient.http_get("%s/api/souls" % _base_url, self, "_on_ping_response")
	_pending_callbacks["ping"] = {"target": callback_target, "method": callback_method}


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
	GameLog.info("SoulArenaClient: Base URL set to %s" % url, "SoulArena")


## --- Internal callbacks ---

var _pending_callbacks: Dictionary = {}


func _on_enter_world(status: int, data: Dictionary) -> void:
	if status >= 200 and status < 300:
		_stats["successful"] += 1
		_stats["active_souls"] += 1
		_connected = true
		GameLog.info("SoulArenaClient: Soul entered world successfully", "SoulArena")
	else:
		_stats["failed"] += 1
		_last_error = str(data)
		GameLog.error("SoulArenaClient: Enter world failed: %s" % str(data), "SoulArena")

	if _pending_callbacks.has("enter_world"):
		var cb = _pending_callbacks["enter_world"]
		if cb["target"] and is_instance_valid(cb["target"]) and not cb["method"].is_empty():
			cb["target"].call(cb["method"], status, data)
		_pending_callbacks.erase("enter_world")


func _on_ping_response(status: int, data: Dictionary) -> void:
	_connected = (status >= 200 and status < 300)
	if _pending_callbacks.has("ping"):
		var cb = _pending_callbacks["ping"]
		if cb["target"] and is_instance_valid(cb["target"]) and not cb["method"].is_empty():
			cb["target"].call(cb["method"], status, data)
		_pending_callbacks.erase("ping")
