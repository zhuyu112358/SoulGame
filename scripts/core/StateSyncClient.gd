extends Node
## StateSyncClient - WebSocket-based state synchronization foundation
##
## Provides real-time state sync between game client and backend.
## Handles connection lifecycle, message routing, state interpolation
## basis, and reconnect logic. This is infrastructure only - no game logic.
##
## Message protocol (JSON):
##   { "type": "state_update", "tick": 123, "data": {...} }
##   { "type": "ping", "timestamp": 1234567890 }
##   { "type": "pong", "timestamp": 1234567890, "server_time": 1234567891 }
##
## Usage:
##   StateSyncClient.connect_to_server("ws://localhost:3000/ws")
##   StateSyncClient.send_state("soul_position", {"x": 1, "y": 2})
##   StateSyncClient.subscribe("soul_position", self, "_on_soul_pos")

## WebSocket peer
var _ws: WebSocketPeer = null

## Connection state
enum ConnectionState {
	DISCONNECTED,
	CONNECTING,
	CONNECTED,
	RECONNECTING
}

var _connection_state: ConnectionState = ConnectionState.DISCONNECTED

## Server URL
var _server_url: String = ""

## Reconnect settings
var _auto_reconnect: bool = true
var _max_reconnect_attempts: int = 5
var _reconnect_attempts: int = 0
var _reconnect_base_delay: float = 1.0
var _reconnect_delay: float = 0.0
var _reconnect_timer: float = 0.0

## Message subscribers: { message_type: [{target, method}] }
var _subscribers: Dictionary = {}

## Pending state updates for interpolation: { state_key: [{tick, data, timestamp}] }
var _state_buffer: Dictionary = {}

## Maximum buffer size per state key
var _max_buffer_size: int = 10

## Last received server tick
var _last_server_tick: int = 0

## Local tick counter
var _local_tick: int = 0

## Statistics
var _stats: Dictionary = {
	"messages_sent": 0,
	"messages_received": 0,
	"bytes_sent": 0,
	"bytes_received": 0,
	"reconnect_count": 0,
	"dropped_messages": 0,
	"last_message_time": 0
}

## Ping/pong for latency measurement
var _pending_pings: Dictionary = {}
var _latency_samples: Array = []
var _current_latency_ms: float = 0.0


func _ready() -> void:
	GameLog.info("StateSyncClient initialized", "Sync")


func _process(delta: float) -> void:
	if _ws == null:
		return

	_ws.poll()
	var state := _ws.get_ready_state()

	match state:
		WebSocketPeer.STATE_OPEN:
			if _connection_state != ConnectionState.CONNECTED:
				_on_connected()
			_process_messages()
			_auto_ping(delta)

		WebSocketPeer.STATE_CONNECTING:
			_connection_state = ConnectionState.CONNECTING

		WebSocketPeer.STATE_CLOSING, WebSocketPeer.STATE_CLOSED:
			if _connection_state == ConnectionState.CONNECTED:
				_on_disconnected()
			if _auto_reconnect and _reconnect_attempts < _max_reconnect_attempts:
				_process_reconnect(delta)


## Connect to WebSocket server
func connect_to_server(url: String) -> void:
	_server_url = url
	_reconnect_attempts = 0
	_connect()


func _connect() -> void:
	if _ws:
		_ws.close()
		_ws = null

	_ws = WebSocketPeer.new()
	var error_code := _ws.connect_to_url(_server_url)
	if error_code != OK:
		GameLog.error("StateSyncClient: Failed to connect to %s: error %d" % [_server_url, error_code], "Sync")
		return

	_connection_state = ConnectionState.CONNECTING
	GameLog.info("StateSyncClient: Connecting to %s" % _server_url, "Sync")


## Disconnect from server
func disconnect_from_server() -> void:
	_auto_reconnect = false
	if _ws:
		_ws.close()
	_connection_state = ConnectionState.DISCONNECTED
	GameLog.info("StateSyncClient: Disconnected", "Sync")


## Send a state update to server
func send_state(state_type: String, data: Dictionary) -> void:
	if _connection_state != ConnectionState.CONNECTED:
		_stats["dropped_messages"] += 1
		GameLog.warning("StateSyncClient: Cannot send, not connected", "Sync")
		return

	var message := {
		"type": state_type,
		"tick": _local_tick,
		"timestamp": Time.get_ticks_msec(),
		"data": data
	}
	_send_message(message)


## Send a raw message
func send_message(message_type: String, data: Dictionary = {}) -> void:
	if _connection_state != ConnectionState.CONNECTED:
		return

	var message := {
		"type": message_type,
		"timestamp": Time.get_ticks_msec(),
		"data": data
	}
	_send_message(message)


## Subscribe to a message type
func subscribe(message_type: String, target: Object, method: String) -> void:
	if not _subscribers.has(message_type):
		_subscribers[message_type] = []

	for sub in _subscribers[message_type]:
		if sub.target == target and sub.method == StringName(method):
			return

	_subscribers[message_type].append({
		"target": target,
		"method": StringName(method)
	})


## Unsubscribe from a message type
func unsubscribe(message_type: String, target: Object, method: String) -> void:
	if not _subscribers.has(message_type):
		return

	var subscribers = _subscribers[message_type]
	for i in range(subscribers.size() - 1, -1, -1):
		if subscribers[i].target == target and subscribers[i].method == StringName(method):
			subscribers.remove_at(i)


## Get current latency in ms
func get_latency_ms() -> float:
	return _current_latency_ms


## Get connection state
func get_connection_state() -> String:
	match _connection_state:
		ConnectionState.DISCONNECTED: return "disconnected"
		ConnectionState.CONNECTING: return "connecting"
		ConnectionState.CONNECTED: return "connected"
		ConnectionState.RECONNECTING: return "reconnecting"
	return "unknown"


## Get statistics
func get_stats() -> Dictionary:
	return _stats.duplicate()


## Get buffered state for interpolation
func get_buffered_state(state_key: String) -> Array:
	if _state_buffer.has(state_key):
		return _state_buffer[state_key].duplicate()
	return []


## Get latest state value
func get_latest_state(state_key: String) -> Dictionary:
	if _state_buffer.has(state_key) and not _state_buffer[state_key].is_empty():
		return _state_buffer[state_key][_state_buffer[state_key].size() - 1]
	return {}


## --- Internal ---

func _send_message(message: Dictionary) -> void:
	var json_string := JSON.stringify(message)
	var error_code := _ws.send_text(json_string)
	if error_code == OK:
		_stats["messages_sent"] += 1
		_stats["bytes_sent"] += json_string.length()
	else:
		_stats["dropped_messages"] += 1
		GameLog.error("StateSyncClient: Send failed: error %d" % error_code, "Sync")


func _process_messages() -> void:
	while _ws.get_available_packet_count() > 0:
		var packet := _ws.get_packet()
		var text := packet.get_string_from_utf8()
		_stats["messages_received"] += 1
		_stats["bytes_received"] += text.length()
		_stats["last_message_time"] = Time.get_ticks_msec()

		var json := JSON.new()
		if json.parse(text) != OK:
			GameLog.warning("StateSyncClient: Invalid JSON received: %s" % text.substr(0, 100), "Sync")
			continue

		var message: Dictionary = json.data
		_handle_message(message)


func _handle_message(message: Dictionary) -> void:
	var message_type: String = message.get("type", "unknown")

	match message_type:
		"pong":
			_handle_pong(message)
		"state_update":
			_handle_state_update(message)
		_:
			# Route to subscribers
			if _subscribers.has(message_type):
				for sub in _subscribers[message_type]:
					if is_instance_valid(sub.target):
						sub.target.call(sub.method, message)

	# Also emit global event
	EventBus.emit("sync_message", message)


func _handle_state_update(message: Dictionary) -> void:
	var data: Dictionary = message.get("data", {})
	var tick: int = message.get("tick", 0)
	var state_key: String = message.get("state_key", message.get("type", "unknown"))

	if tick > _last_server_tick:
		_last_server_tick = tick

	# Buffer for interpolation
	if not _state_buffer.has(state_key):
		_state_buffer[state_key] = []
	_state_buffer[state_key].append({
		"tick": tick,
		"data": data,
		"timestamp": Time.get_ticks_msec()
	})
	if _state_buffer[state_key].size() > _max_buffer_size:
		_state_buffer[state_key].pop_front()

	# Route to subscribers
	if _subscribers.has("state_update"):
		for sub in _subscribers["state_update"]:
			if is_instance_valid(sub.target):
				sub.target.call(sub.method, message)


func _handle_pong(message: Dictionary) -> void:
	var ping_id: int = message.get("ping_id", -1)
	if _pending_pings.has(ping_id):
		var send_time: int = _pending_pings[ping_id]
		var latency := float(Time.get_ticks_msec() - send_time)
		_latency_samples.append(latency)
		if _latency_samples.size() > 20:
			_latency_samples.pop_front()
		_current_latency_ms = _latency_samples.reduce(func(a, b): return a + b, 0.0) / _latency_samples.size()
		_pending_pings.erase(ping_id)
		PerformanceMonitor.record_metric("ws_latency_ms", _current_latency_ms)


var _ping_timer: float = 0.0
var _ping_interval: float = 5.0
var _ping_counter: int = 0


func _auto_ping(delta: float) -> void:
	_ping_timer += delta
	if _ping_timer >= _ping_interval:
		_ping_timer = 0.0
		var ping_id := _ping_counter
		_ping_counter += 1
		_pending_pings[ping_id] = Time.get_ticks_msec()
		_send_message({"type": "ping", "ping_id": ping_id, "timestamp": Time.get_ticks_msec()})


func _on_connected() -> void:
	_connection_state = ConnectionState.CONNECTED
	_reconnect_attempts = 0
	_reconnect_delay = 0.0
	GameLog.info("StateSyncClient: Connected to %s" % _server_url, "Sync")
	EventBus.emit("sync_connected", {"url": _server_url})


func _on_disconnected() -> void:
	_connection_state = ConnectionState.DISCONNECTED
	GameLog.warning("StateSyncClient: Disconnected from %s" % _server_url, "Sync")
	EventBus.emit("sync_disconnected", {"url": _server_url})


func _process_reconnect(delta: float) -> void:
	if _connection_state != ConnectionState.RECONNECTING:
		_connection_state = ConnectionState.RECONNECTING
		_reconnect_attempts += 1
		_stats["reconnect_count"] += 1
		_reconnect_delay = _reconnect_base_delay * pow(2.0, _reconnect_attempts - 1)
		_reconnect_timer = 0.0
		GameLog.info("StateSyncClient: Reconnect attempt %d/%d in %.1fs" % [
			_reconnect_attempts, _max_reconnect_attempts, _reconnect_delay
		], "Sync")

	_reconnect_timer += delta
	if _reconnect_timer >= _reconnect_delay:
		_connect()
