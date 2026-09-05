extends Node
## EventBus - Global publish/subscribe event system
##
## Provides a centralized event bus for decoupled communication between
## game systems. Any system can emit events and any other system can
## subscribe without direct references.
##
## Features:
## - Synchronous event delivery in subscription order
## - Event history tracking for debugging
## - Per-event-type statistics
## - Event filtering (temporarily suppress events)
## - Automatic cleanup of invalid subscribers
##
## Usage:
##   EventBus.subscribe("soul_spawned", self, "_on_soul_spawned")
##   EventBus.emit("soul_spawned", {"id": "soul_001", "name": "Test"})
##   EventBus.unsubscribe("soul_spawned", self, "_on_soul_spawned")
##   var history = EventBus.get_history(20)
##   EventBus.suppress_event("debug_spam")

## Dictionary mapping event names to arrays of subscribers
## Each subscriber is { "target": Object, "method": StringName }
var _subscribers: Dictionary = {}

## Event history: circular buffer of recent events
## Each entry: { "name": String, "data": Dictionary, "time": float, "delivered": int }
var _event_history: Array = []

## Maximum number of events to keep in history
var _max_history_size: int = 500

## Per-event-type emission counts
var _event_counts: Dictionary = {}

## Suppressed events (temporarily not delivered)
var _suppressed_events: Dictionary = {}

## Statistics for debugging
var _emitted_count: int = 0
var _delivered_count: int = 0
var _suppressed_count: int = 0


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
	print("[EventBus] Subscribed to '%s' -> %s.%s" % [event_name, target, method])


## Unsubscribe from an event
func unsubscribe(event_name: String, target: Object, method: String) -> void:
	if not _subscribers.has(event_name):
		return

	var subscribers = _subscribers[event_name]
	for i in range(subscribers.size() - 1, -1, -1):
		var sub = subscribers[i]
		if sub.target == target and sub.method == StringName(method):
			subscribers.remove_at(i)
			print("[EventBus] Unsubscribed from '%s' -> %s.%s" % [event_name, target, method])

	if subscribers.is_empty():
		_subscribers.erase(event_name)


## Emit an event with optional data payload
## All subscribers will be called synchronously in subscription order
func emit(event_name: String, data: Dictionary = {}) -> void:
	_emitted_count += 1
	_event_counts[event_name] = _event_counts.get(event_name, 0) + 1

	# Check if event is suppressed
	if _suppressed_events.has(event_name):
		_suppressed_count += 1
		_record_history(event_name, data, 0, true)
		return

	if not _subscribers.has(event_name):
		_record_history(event_name, data, 0, false)
		return

	var delivered := 0
	var subscribers = _subscribers[event_name].duplicate()
	for sub in subscribers:
		if is_instance_valid(sub.target):
			_delivered_count += 1
			delivered += 1
			sub.target.call(sub.method, data)
		else:
			# Clean up invalid subscribers
			push_warning("[EventBus] Invalid subscriber for '%s', removing" % event_name)
			_remove_invalid_subscriber(event_name, sub.target)

	_record_history(event_name, data, delivered, false)


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


## --- Event History ---

## Get recent event history
## count: number of events to return (most recent first)
func get_history(count: int = 20) -> Array:
	if count <= 0 or _event_history.is_empty():
		return []
	var end := _event_history.size()
	var start: int = max(end - count, 0)
	# Return in reverse order (most recent first)
	var result := []
	for i in range(end - 1, start - 1, -1):
		result.append(_event_history[i])
	return result


## Get history filtered by event name
func get_history_by_event(event_name: String, count: int = 20) -> Array:
	var result := []
	var found := 0
	for i in range(_event_history.size() - 1, -1, -1):
		if _event_history[i]["name"] == event_name:
			result.append(_event_history[i])
			found += 1
			if found >= count:
				break
	return result


## Clear event history
func clear_history() -> void:
	_event_history.clear()
	print("[EventBus] History cleared")


## Set maximum history size
func set_max_history_size(size: int) -> void:
	_max_history_size = max(size, 0)
	# Trim if needed
	while _event_history.size() > _max_history_size:
		_event_history.pop_front()


## --- Event Filtering ---

## Temporarily suppress an event (it will be recorded but not delivered)
func suppress_event(event_name: String) -> void:
	_suppressed_events[event_name] = true
	print("[EventBus] Suppressing event '%s'" % event_name)


## Unsuppress an event
func unsuppress_event(event_name: String) -> void:
	if _suppressed_events.has(event_name):
		_suppressed_events.erase(event_name)
		print("[EventBus] Unsuppressing event '%s'" % event_name)


## Check if an event is suppressed
func is_suppressed(event_name: String) -> bool:
	return _suppressed_events.has(event_name)


## Get all suppressed events
func get_suppressed_events() -> Array:
	return _suppressed_events.keys()


## Clear all suppressed events
func clear_suppressed() -> void:
	_suppressed_events.clear()


## --- Statistics ---

## Get statistics for debug overlay
func get_stats() -> Dictionary:
	var top_events := _get_top_events(5)
	return {
		"emitted": _emitted_count,
		"delivered": _delivered_count,
		"suppressed": _suppressed_count,
		"active_events": _subscribers.size(),
		"total_subscribers": _get_total_subscribers(),
		"history_size": _event_history.size(),
		"max_history_size": _max_history_size,
		"suppressed_event_count": _suppressed_events.size(),
		"unique_event_types": _event_counts.size(),
		"top_events": top_events
	}


## Get per-event-type statistics
func get_event_stats(event_name: String) -> Dictionary:
	return {
		"name": event_name,
		"emitted": _event_counts.get(event_name, 0),
		"subscribers": get_subscriber_count(event_name),
		"suppressed": is_suppressed(event_name)
	}


## Get all event type statistics
func get_all_event_stats() -> Array:
	var result := []
	for event_name in _event_counts:
		result.append(get_event_stats(event_name))
	# Sort by emission count descending
	result.sort_custom(func(a, b): return a["emitted"] > b["emitted"])
	return result


## Remove all subscriptions for a target object (call on free)
func unsubscribe_all(target: Object) -> void:
	for event_name in _subscribers.keys():
		var subscribers = _subscribers[event_name]
		for i in range(subscribers.size() - 1, -1, -1):
			if subscribers[i].target == target:
				subscribers.remove_at(i)
		if subscribers.is_empty():
			_subscribers.erase(event_name)


## --- Internal ---

func _record_history(event_name: String, data: Dictionary, delivered: int, suppressed: bool) -> void:
	if _max_history_size <= 0:
		return

	_event_history.append({
		"name": event_name,
		"data": data.duplicate(true),
		"time": Time.get_ticks_msec() / 1000.0,
		"delivered": delivered,
		"suppressed": suppressed
	})

	# Trim old entries
	while _event_history.size() > _max_history_size:
		_event_history.pop_front()


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


func _get_top_events(count: int) -> Array:
	var events := []
	for event_name in _event_counts:
		events.append({"name": event_name, "count": _event_counts[event_name]})
	events.sort_custom(func(a, b): return a["count"] > b["count"])
	if events.size() > count:
		events = events.slice(0, count)
	return events
