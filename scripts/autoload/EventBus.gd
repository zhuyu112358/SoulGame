extends Node
## EventBus - Global publish/subscribe event system
##
## Provides a centralized event bus for decoupled communication between
## game systems. Any system can emit events and any other system can
## subscribe without direct references.
##
## Usage:
##   EventBus.subscribe("soul_spawned", self, "_on_soul_spawned")
##   EventBus.emit("soul_spawned", {"id": "soul_001", "name": "Test"})
##   EventBus.unsubscribe("soul_spawned", self, "_on_soul_spawned")

## Dictionary mapping event names to arrays of subscribers
## Each subscriber is { "target": Object, "method": StringName }
var _subscribers: Dictionary = {}

## Statistics for debugging
var _emitted_count: int = 0
var _delivered_count: int = 0


## Subscribe to an event
## event_name: Name of the event to listen for
## target: Object that will receive the callback
## method: Method name to call on target when event fires
func subscribe(event_name: String, target: Object, method: String) -> void:
	if not _subscribers.has(event_name):
		_subscribers[event_name] = []

	# Avoid duplicate subscriptions
	for sub in _subscribers[event_name]:
		if sub.target == target and sub.method == StringName(method):
			push_warning("EventBus: Duplicate subscription for event '%s' on %s.%s" % [event_name, target, method])
			return

	_subscribers[event_name].append({
		"target": target,
		"method": StringName(method)
	})
	Logger.debug("EventBus: Subscribed to '%s' -> %s.%s" % [event_name, target, method], "EventBus")


## Unsubscribe from an event
func unsubscribe(event_name: String, target: Object, method: String) -> void:
	if not _subscribers.has(event_name):
		return

	var subscribers = _subscribers[event_name]
	for i in range(subscribers.size() - 1, -1, -1):
		var sub = subscribers[i]
		if sub.target == target and sub.method == StringName(method):
			subscribers.remove_at(i)
			Logger.debug("EventBus: Unsubscribed from '%s' -> %s.%s" % [event_name, target, method], "EventBus")

	if subscribers.is_empty():
		_subscribers.erase(event_name)


## Emit an event with optional data payload
## All subscribers will be called synchronously in subscription order
func emit(event_name: String, data: Dictionary = {}) -> void:
	_emitted_count += 1

	if not _subscribers.has(event_name):
		return

	var subscribers = _subscribers[event_name].duplicate()
	for sub in subscribers:
		if is_instance_valid(sub.target):
			_delivered_count += 1
			sub.target.call(sub.method, data)
		else:
			# Clean up invalid subscribers
			Logger.warning("EventBus: Invalid subscriber for '%s', removing" % event_name, "EventBus")
			_remove_invalid_subscriber(event_name, sub.target)


## Check if an event has any subscribers
func has_subscribers(event_name: String) -> bool:
	return _subscribers.has(event_name) and not _subscribers[event_name].is_empty()


## Get all registered event names
func get_event_names() -> Array:
	return _subscribers.keys()


## Get subscriber count for an event
func get_subscriber_count(event_name: String) -> int:
	if _subscribers.has(event_name):
		return _subscribers[event_name].size()
	return 0


## Get statistics for debug overlay
func get_stats() -> Dictionary:
	return {
		"emitted": _emitted_count,
		"delivered": _delivered_count,
		"active_events": _subscribers.size(),
		"total_subscribers": _get_total_subscribers()
	}


## Remove all subscriptions for a target object (call on free)
func unsubscribe_all(target: Object) -> void:
	for event_name in _subscribers.keys():
		var subscribers = _subscribers[event_name]
		for i in range(subscribers.size() - 1, -1, -1):
			if subscribers[i].target == target:
				subscribers.remove_at(i)
		if subscribers.is_empty():
			_subscribers.erase(event_name)


func _remove_invalid_subscriber(event_name: String, target: Object) -> void:
	if not _subscribers.has(event_name):
		return
	var subscribers = _subscribers[event_name]
	for i in range(subscribers.size() - 1, -1, -1):
		if subscribers[i].target == target or not is_instance_valid(subscribers[i].target):
			subscribers.remove_at(i)
	if subscribers.is_empty():
		_subscribers.erase(event_name)


func _get_total_subscribers() -> int:
	var total: int = 0
	for event_name in _subscribers:
		total += _subscribers[event_name].size()
	return total
