extends Node
## GameState - Global state management for game, soul, and world states
##
## Provides a centralized state store with change notifications.
## States are organized into namespaces (game, soul, world, ui).
##
## Usage:
##   GameState.set_value("game", "current_scene", "main_menu")
##   var scene = GameState.get("game", "current_scene")
##   GameState.subscribe("game", "current_scene", self, "_on_scene_changed")
##   GameState.get_soul_state("soul_001", "emotion")

## State stores by namespace
var _states: Dictionary = {
	"game": {},
	"soul": {},
	"world": {},
	"ui": {},
	"session": {}
}

## State change subscribers: { "namespace.key": [{target, method}] }
var _subscribers: Dictionary = {}

## State history for undo/debug (limited)
var _history: Array = []
var _max_history: int = 100

## Whether to record history
var _record_history: bool = true


func _ready() -> void:
	_initialize_defaults()
	Logger.info("GameState initialized", "State")


## Set a state value and notify subscribers
func set_value(namespace: String, key: String, value: Variant) -> void:
	if not _states.has(namespace):
		_states[namespace] = {}

	var old_value = null
	if _states[namespace].has(key):
		old_value = _states[namespace][key]

	_states[namespace][key] = value

	# Record history
	if _record_history:
		_history.append({
			"timestamp": Time.get_ticks_msec(),
			"namespace": namespace,
			"key": key,
			"old": old_value,
			"new": value
		})
		if _history.size() > _max_history:
			_history.pop_front()

	# Notify subscribers
	var subscriber_key := "%s.%s" % [namespace, key]
	if _subscribers.has(subscriber_key):
		var data := {
			"namespace": namespace,
			"key": key,
			"old": old_value,
			"new": value
		}
		for sub in _subscribers[subscriber_key]:
			if is_instance_valid(sub.target):
				sub.target.call(sub.method, data)

	# Also emit global event
	EventBus.emit("state_changed", {
		"namespace": namespace,
		"key": key,
		"value": value
	})


## Get a state value
func get(namespace: String, key: String, default_value = null):
	if _states.has(namespace) and _states[namespace].has(key):
		return _states[namespace][key]
	return default_value


## Check if a state key exists
func has(namespace: String, key: String) -> bool:
	return _states.has(namespace) and _states[namespace].has(key)


## Subscribe to state changes for a specific key
func subscribe(namespace: String, key: String, target: Object, method: String) -> void:
	var subscriber_key := "%s.%s" % [namespace, key]
	if not _subscribers.has(subscriber_key):
		_subscribers[subscriber_key] = []

	for sub in _subscribers[subscriber_key]:
		if sub.target == target and sub.method == StringName(method):
			return

	_subscribers[subscriber_key].append({
		"target": target,
		"method": StringName(method)
	})


## Unsubscribe from state changes
func unsubscribe(namespace: String, key: String, target: Object, method: String) -> void:
	var subscriber_key := "%s.%s" % [namespace, key]
	if not _subscribers.has(subscriber_key):
		return

	var subscribers = _subscribers[subscriber_key]
	for i in range(subscribers.size() - 1, -1, -1):
		if subscribers[i].target == target and subscribers[i].method == StringName(method):
			subscribers.remove_at(i)


## Get all state in a namespace
func get_namespace(namespace: String) -> Dictionary:
	if _states.has(namespace):
		return _states[namespace].duplicate(true)
	return {}


## Set entire namespace (bulk update)
func set_namespace(namespace: String, data: Dictionary) -> void:
	for key in data:
		set(namespace, key, data[key])


## --- Soul-specific state management ---

## Set a soul-specific state
func set_soul_state(soul_id: String, key: String, value) -> void:
	if not _states["soul"].has(soul_id):
		_states["soul"][soul_id] = {}
	_states["soul"][soul_id][key] = value
	EventBus.emit("soul_state_changed", {"soul_id": soul_id, "key": key, "value": value})


## Get a soul-specific state
func get_soul_state(soul_id: String, key: String, default_value = null):
	if _states["soul"].has(soul_id) and _states["soul"][soul_id].has(key):
		return _states["soul"][soul_id][key]
	return default_value


## Get all soul IDs currently tracked
func get_soul_ids() -> Array:
	return _states["soul"].keys()


## Remove a soul's state
func remove_soul(soul_id: String) -> void:
	if _states["soul"].has(soul_id):
		_states["soul"].erase(soul_id)
		EventBus.emit("soul_removed", {"soul_id": soul_id})


## --- World-specific state management ---

## Set world state
func set_world_state(key: String, value) -> void:
	set("world", key, value)


## Get world state
func get_world_state(key: String, default_value = null):
	return get("world", key, default_value)


## --- Session management ---

## Start a new session
func start_session(session_id: String) -> void:
	set("session", "id", session_id)
	set("session", "start_time", Time.get_datetime_string_from_system())
	set("session", "tick_count", 0)
	Logger.info("Session started: %s" % session_id, "State")


## End current session
func end_session() -> void:
	var session_id = get("session", "id", "unknown")
	set("session", "end_time", Time.get_datetime_string_from_system())
	Logger.info("Session ended: %s" % session_id, "State")


## Increment session tick
func increment_tick() -> int:
	var tick: int = get("session", "tick_count", 0)
	tick += 1
	set("session", "tick_count", tick)
	return tick


## Get state history (for debug)
func get_history(count: int = 20) -> Array:
	if count >= _history.size():
		return _history.duplicate()
	return _history.slice(_history.size() - count, _history.size())


## Get state summary for debug overlay
func get_summary() -> Dictionary:
	return {
		"namespaces": _states.keys(),
		"soul_count": _states["soul"].size(),
		"history_size": _history.size(),
		"current_scene": get("game", "current_scene", "none"),
		"session_id": get("session", "id", "none"),
		"tick": get("session", "tick_count", 0)
	}


## Get state statistics (standard interface)
func get_stats() -> Dictionary:
	var namespace_counts := {}
	for ns in _states:
		namespace_counts[ns] = _states[ns].size()
	return {
		"namespaces": _states.size(),
		"namespace_counts": namespace_counts,
		"soul_count": _states["soul"].size(),
		"history_size": _history.size(),
		"total_keys": _count_total_keys(),
		"session_active": get("session", "id", "") != ""
	}


## Count total keys across all namespaces
func _count_total_keys() -> int:
	var count := 0
	for ns in _states:
		count += _states[ns].size()
	return count


## Reset all states (use with caution)
func reset() -> void:
	_states = {
		"game": {},
		"soul": {},
		"world": {},
		"ui": {},
		"session": {}
	}
	_history.clear()
	_initialize_defaults()
	Logger.warning("GameState reset", "State")


func _initialize_defaults() -> void:
	_states["game"]["version"] = "0.1.0"
	_states["game"]["current_scene"] = "bootstrap"
	_states["game"]["paused"] = false
	_states["world"]["tick_rate"] = 20
	_states["world"]["time_scale"] = 1.0
