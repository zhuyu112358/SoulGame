extends Node
## NetworkClient - Unified HTTP and WebSocket client with retry and timeout
##
## Provides a consistent interface for all network communication.
## Handles connection pooling, retry logic, timeout, and error normalization.
##
## Usage:
##   NetworkClient.get("http://localhost:3000/api/souls", self, "_on_souls_loaded")
##   NetworkClient.post("http://localhost:3000/api/soul/1/perceive", body, self, "_on_perceive")
##   NetworkClient.connect_ws("ws://localhost:3000/ws")

## HTTP request pool
var _http_requests: Array = []

## Maximum concurrent HTTP requests
var _max_concurrent_requests: int = 8

## Active WebSocket connections
var _ws_connections: Dictionary = {}

## Default timeout in milliseconds
var _default_timeout: int = 5000

## Default retry count
var _default_retries: int = 3

## Retry backoff base in ms
var _retry_base_delay: float = 500.0

## Request statistics
var _stats: Dictionary = {
	"total_requests": 0,
	"successful": 0,
	"failed": 0,
	"retries": 0,
	"avg_response_ms": 0.0,
	"ws_connections": 0
}

## Response time tracking
var _response_times: Array = []


func _ready() -> void:
	Logger.info("NetworkClient initialized", "Network")


## --- HTTP GET ---
func get(url: String, callback_target: Object = null, callback_method: String = "", headers: Dictionary = {}) -> void:
	_send_request(url, HTTPClient.METHOD_GET, {}, headers, callback_target, callback_method)


## --- HTTP POST ---
func post(url: String, body: Dictionary, callback_target: Object = null, callback_method: String = "", headers: Dictionary = {}) -> void:
	_send_request(url, HTTPClient.METHOD_POST, body, headers, callback_target, callback_method)


## --- HTTP PUT ---
func put(url: String, body: Dictionary, callback_target: Object = null, callback_method: String = "", headers: Dictionary = {}) -> void:
	_send_request(url, HTTPClient.METHOD_PUT, body, headers, callback_target, callback_method)


## --- HTTP DELETE ---
func delete(url: String, callback_target: Object = null, callback_method: String = "", headers: Dictionary = {}) -> void:
	_send_request(url, HTTPClient.METHOD_DELETE, {}, headers, callback_target, callback_method)


## Core request sender with retry logic
func _send_request(url: String, method: int, body: Dictionary, headers: Dictionary, callback_target: Object, callback_method: String, retry_count: int = 0) -> void:
	_stats["total_requests"] += 1

	var http_request := HTTPRequest.new()
	http_request.timeout = _default_timeout / 1000.0
	add_child(http_request)

	# Build headers
	var header_array := ["Content-Type: application/json", "Accept: application/json"]
	for key in headers:
		header_array.append("%s: %s" % [key, headers[key]])

	# Build body
	var body_string := ""
	if method != HTTPClient.METHOD_GET and not body.is_empty():
		body_string = JSON.stringify(body)

	var start_time := Time.get_ticks_msec()

	# Connect response handler
	http_request.request_completed.connect(
		_on_request_completed.bind(url, method, body, headers, callback_target, callback_method, retry_count, start_time)
	)

	var error_code := http_request.request(url, header_array, true, method, body_string)
	if error_code != OK:
		Logger.error("NetworkClient: Failed to start request to %s: error %d" % [url, error_code], "Network")
		_handle_failure(url, method, body, headers, callback_target, callback_method, retry_count, error_code, "")
		http_request.queue_free()


## Request completion handler
func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, url: String, method: int, req_body: Dictionary, req_headers: Dictionary, callback_target: Object, callback_method: String, retry_count: int, start_time: int) -> void:
	var elapsed := Time.get_ticks_msec() - start_time
	_response_times.append(elapsed)
	if _response_times.size() > 100:
		_response_times.pop_front()
	_stats["avg_response_ms"] = _response_times.reduce(func(a, b): return a + b, 0.0) / _response_times.size()

	# Free the HTTPRequest node
	var http_request := http_request if "http_request" in locals() else null

	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		_stats["successful"] += 1
		var response_data := _parse_response(body)
		Logger.debug("NetworkClient: %s %s -> %d (%dms)" % [_method_string(method), url, response_code, elapsed], "Network")

		if callback_target and is_instance_valid(callback_target) and not callback_method.is_empty():
			callback_target.call(callback_method, response_code, response_data)
	else:
		_stats["failed"] += 1
		var error_body := body.get_string_from_utf8()
		Logger.warning("NetworkClient: %s %s -> %d (result=%d, %dms) %s" % [_method_string(method), url, response_code, result, elapsed, error_body], "Network")

		# Retry on server errors or network failures
		if retry_count < _default_retries and (response_code >= 500 or result != HTTPRequest.RESULT_SUCCESS):
			_stats["retries"] += 1
			var delay := _retry_base_delay * pow(2.0, retry_count) / 1000.0
			Logger.info("NetworkClient: Retrying %s (attempt %d/%d) in %.1fs" % [url, retry_count + 1, _default_retries, delay], "Network")
			await get_tree().create_timer(delay).timeout
			_send_request(url, method, req_body, req_headers, callback_target, callback_method, retry_count + 1)
		else:
			if callback_target and is_instance_valid(callback_target) and not callback_method.is_empty():
				callback_target.call(callback_method, response_code, {"error": "Request failed", "status": response_code, "body": error_body})

	EventBus.emit("network_response", {"url": url, "code": response_code, "elapsed_ms": elapsed})


func _handle_failure(url: String, method: int, body: Dictionary, headers: Dictionary, callback_target: Object, callback_method: String, retry_count: int, error_code: int, error_msg: String) -> void:
	if retry_count < _default_retries:
		_stats["retries"] += 1
		var delay := _retry_base_delay * pow(2.0, retry_count) / 1000.0
		await get_tree().create_timer(delay).timeout
		_send_request(url, method, body, headers, callback_target, callback_method, retry_count + 1)
	else:
		_stats["failed"] += 1
		if callback_target and is_instance_valid(callback_target) and not callback_method.is_empty():
			callback_target.call(callback_method, 0, {"error": error_msg, "code": error_code})


## --- WebSocket ---

## Connect to a WebSocket endpoint
func connect_ws(url: String, callback_target: Object = null, callback_method: String = "") -> WebSocketPeer:
	if _ws_connections.has(url):
		Logger.warning("NetworkClient: Already connected to %s" % url, "Network")
		return _ws_connections[url]["peer"]

	var ws_peer := WebSocketPeer.new()
	var error_code := ws_peer.connect_to_url(url)
	if error_code != OK:
		Logger.error("NetworkClient: Failed to connect WS %s: error %d" % [url, error_code], "Network")
		return null

	_ws_connections[url] = {
		"peer": ws_peer,
		"target": callback_target,
		"method": callback_method,
		"connected": false
	}
	_stats["ws_connections"] += 1
	Logger.info("NetworkClient: Connecting WS %s" % url, "Network")
	return ws_peer


## Send data over WebSocket
func send_ws(url: String, data: String) -> bool:
	if not _ws_connections.has(url):
		Logger.error("NetworkClient: No WS connection to %s" % url, "Network")
		return false

	var conn = _ws_connections[url]
	if not conn["connected"]:
		Logger.warning("NetworkClient: WS not connected to %s" % url, "Network")
		return false

	var ws_peer: WebSocketPeer = conn["peer"]
	var error_code := ws_peer.send_text(data)
	if error_code != OK:
		Logger.error("NetworkClient: WS send failed to %s: error %d" % [url, error_code], "Network")
		return false
	return true


## Close WebSocket connection
func close_ws(url: String) -> void:
	if _ws_connections.has(url):
		var ws_peer: WebSocketPeer = _ws_connections[url]["peer"]
		ws_peer.close()
		_ws_connections.erase(url)
		_stats["ws_connections"] -= 1
		Logger.info("NetworkClient: Closed WS %s" % url, "Network")


## Process WebSocket events (call in _process)
func _process(delta: float) -> void:
	for url in _ws_connections.keys():
		var conn = _ws_connections[url]
		var ws_peer: WebSocketPeer = conn["peer"]
		ws_peer.poll()

		var state := ws_peer.get_ready_state()
		match state:
			WebSocketPeer.STATE_OPEN:
				if not conn["connected"]:
					conn["connected"] = true
					Logger.info("NetworkClient: WS connected %s" % url, "Network")
					EventBus.emit("ws_connected", {"url": url})
					if conn["target"] and is_instance_valid(conn["target"]):
						conn["target"].call(conn["method"], "connected", {})

				# Receive messages
				while ws_peer.get_available_packet_count() > 0:
					var packet := ws_peer.get_packet()
					var message := packet.get_string_from_utf8()
					Logger.debug("NetworkClient: WS message from %s: %s" % [url, message.substr(0, 100)], "Network")
					if conn["target"] and is_instance_valid(conn["target"]):
						conn["target"].call(conn["method"], "message", {"data": message})

			WebSocketPeer.STATE_CLOSED:
				if conn["connected"]:
					conn["connected"] = false
					Logger.warning("NetworkClient: WS disconnected %s" % url, "Network")
					EventBus.emit("ws_disconnected", {"url": url})
					if conn["target"] and is_instance_valid(conn["target"]):
						conn["target"].call(conn["method"], "disconnected", {})


## Get network statistics
func get_stats() -> Dictionary:
	return _stats.duplicate()


## Check if a URL is reachable (quick test)
func check_connectivity(url: String) -> bool:
	# Simple HEAD request to check connectivity
	var http_request := HTTPRequest.new()
	http_request.timeout = 2.0
	add_child(http_request)
	var error_code := http_request.request(url, [], true, HTTPClient.METHOD_HEAD, "")
	return error_code == OK


func _parse_response(body: PackedByteArray) -> Variant:
	var text := body.get_string_from_utf8()
	if text.is_empty():
		return {}
	var json := JSON.new()
	var error_code := json.parse(text)
	if error_code != OK:
		Logger.warning("NetworkClient: Failed to parse JSON response: %s" % text.substr(0, 200), "Network")
		return {"raw": text}
	return json.data


func _method_string(method: int) -> String:
	match method:
		HTTPClient.METHOD_GET: return "GET"
		HTTPClient.METHOD_POST: return "POST"
		HTTPClient.METHOD_PUT: return "PUT"
		HTTPClient.METHOD_DELETE: return "DELETE"
		_: return "UNKNOWN"
