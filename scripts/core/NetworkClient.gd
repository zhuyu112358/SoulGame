extends Node
## NetworkClient - Unified HTTP and WebSocket client with queue, priority, and circuit breaker
##
## Provides a consistent interface for all network communication.
## Handles connection pooling, request queue with priority, retry logic,
## timeout, circuit breaker, and error normalization.
##
## Features:
## - HTTP GET/POST/PUT/DELETE with callback
## - Request queue with priority (high/normal/low)
## - Circuit breaker per host (prevents cascading failures)
## - Automatic retry with exponential backoff
## - WebSocket client with auto-reconnect
## - Detailed request statistics and latency tracking
## - Request cancellation
##
## Usage:
##   NetworkClient.get("http://localhost:3000/api/souls", self, "_on_souls_loaded")
##   NetworkClient.post("http://localhost:3000/api/soul/1/perceive", body, self, "_on_perceive")
##   NetworkClient.connect_ws("ws://localhost:3000/ws")
##   NetworkClient.set_priority("http://localhost:3000/api", NetworkClient.PRIORITY_HIGH)

## Request priorities
enum Priority {
	HIGH = 0,
	NORMAL = 1,
	LOW = 2
}

## Circuit breaker states
enum BreakerState {
	CLOSED = 0,     # Normal operation
	OPEN = 1,       # Failing fast, no requests
	HALF_OPEN = 2   # Testing if service recovered
}

## HTTP request pool
var _http_requests: Array = []

## Maximum concurrent HTTP requests
var _max_concurrent_requests: int = 8

## Request queue: [{url, method, body, headers, target, method_name, priority, retry_count, created_at}]
var _request_queue: Array = []

## Active WebSocket connections
var _ws_connections: Dictionary = {}

## Default timeout in milliseconds
var _default_timeout: int = 5000

## Default retry count
var _default_retries: int = 3

## Retry backoff base in ms
var _retry_base_delay: float = 500.0

## --- Circuit Breaker ---

## Circuit breaker state per host: { host: {state, failure_count, success_count, last_failure_time, reset_timeout} }
var _circuit_breakers: Dictionary = {}

## Failure threshold before opening circuit
var _breaker_failure_threshold: int = 5

## Time in seconds before attempting to close circuit
var _breaker_reset_timeout: float = 30.0

## Half-open max requests before fully closing
var _breaker_half_open_max: int = 3

## Request statistics
var _stats: Dictionary = {
	"total_requests": 0,
	"successful": 0,
	"failed": 0,
	"retries": 0,
	"avg_response_ms": 0.0,
	"ws_connections": 0,
	"queued": 0,
	"cancelled": 0,
	"breaker_rejected": 0
}

## Response time tracking
var _response_times: Array = []

## Per-host statistics: { host: {requests, successes, failures, avg_ms} }
var _host_stats: Dictionary = {}

## Active request count
var _active_requests: int = 0


func _ready() -> void:
	Logger.info("NetworkClient initialized (max_concurrent=%d, breaker_threshold=%d)" % [_max_concurrent_requests, _breaker_failure_threshold], "Network")


## --- HTTP Methods ---

## HTTP GET
func get(url: String, callback_target: Object = null, callback_method: String = "", headers: Dictionary = {}, priority: int = Priority.NORMAL) -> void:
	_queue_request(url, HTTPClient.METHOD_GET, {}, headers, callback_target, callback_method, priority)


## HTTP POST
func post(url: String, body: Dictionary, callback_target: Object = null, callback_method: String = "", headers: Dictionary = {}, priority: int = Priority.NORMAL) -> void:
	_queue_request(url, HTTPClient.METHOD_POST, body, headers, callback_target, callback_method, priority)


## HTTP PUT
func put(url: String, body: Dictionary, callback_target: Object = null, callback_method: String = "", headers: Dictionary = {}, priority: int = Priority.NORMAL) -> void:
	_queue_request(url, HTTPClient.METHOD_PUT, body, headers, callback_target, callback_method, priority)


## HTTP DELETE
func delete(url: String, callback_target: Object = null, callback_method: String = "", headers: Dictionary = {}, priority: int = Priority.NORMAL) -> void:
	_queue_request(url, HTTPClient.METHOD_DELETE, {}, headers, callback_target, callback_method, priority)


## --- Request Queue ---

## Add request to queue with priority
func _queue_request(url: String, method: int, body: Dictionary, headers: Dictionary, callback_target: Object, callback_method: String, priority: int) -> void:
	var request := {
		"url": url,
		"method": method,
		"body": body,
		"headers": headers,
		"target": callback_target,
		"method_name": callback_method,
		"priority": priority,
		"retry_count": 0,
		"created_at": Time.get_ticks_msec()
	}

	# Insert sorted by priority (lower number = higher priority)
	var inserted := false
	for i in range(_request_queue.size()):
		if _request_queue[i]["priority"] > priority:
			_request_queue.insert(i, request)
			inserted = true
			break
	if not inserted:
		_request_queue.append(request)

	_stats["queued"] += 1
	_process_queue()


## Process the request queue
func _process_queue() -> void:
	while _active_requests < _max_concurrent_requests and not _request_queue.is_empty():
		var request = _request_queue.pop_front()
		_send_queued_request(request)


## Send a queued request
func _send_queued_request(request: Dictionary) -> void:
	var url: String = request["url"]
	var host := _extract_host(url)

	# Check circuit breaker
	if _is_circuit_open(host):
		_stats["breaker_rejected"] += 1
		_stats["failed"] += 1
		Logger.warning("NetworkClient: Circuit open for %s, rejecting request" % host, "Network")
		if request["target"] and is_instance_valid(request["target"]) and not request["method_name"].is_empty():
			request["target"].call(request["method_name"], 0, {"error": "Circuit breaker open", "host": host})
		_process_queue()
		return

	_active_requests += 1
	_stats["total_requests"] += 1

	var http_request := HTTPRequest.new()
	http_request.timeout = _default_timeout / 1000.0
	add_child(http_request)

	# Build headers
	var header_array := ["Content-Type: application/json", "Accept: application/json"]
	for key in request["headers"]:
		header_array.append("%s: %s" % [key, request["headers"][key]])

	# Build body
	var body_string := ""
	if request["method"] != HTTPClient.METHOD_GET and not request["body"].is_empty():
		body_string = JSON.stringify(request["body"])

	var start_time := Time.get_ticks_msec()

	# Connect response handler
	http_request.request_completed.connect(
		_on_request_completed.bind(request, start_time, http_request)
	)

	var error_code := http_request.request(url, header_array, true, request["method"], body_string)
	if error_code != OK:
		Logger.error("NetworkClient: Failed to start request to %s: error %d" % [url, error_code], "Network")
		_handle_request_failure(request, error_code, "")
		http_request.queue_free()
		_active_requests -= 1
		_process_queue()


## Request completion handler
func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, request: Dictionary, start_time: int, http_request: HTTPRequest) -> void:
	_active_requests -= 1
	var elapsed := Time.get_ticks_msec() - start_time
	var url: String = request["url"]
	var host := _extract_host(url)

	_response_times.append(elapsed)
	if _response_times.size() > 200:
		_response_times.pop_front()
	_stats["avg_response_ms"] = _response_times.reduce(func(a, b): return a + b, 0.0) / _response_times.size()

	# Update host stats
	_update_host_stats(host, elapsed, result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300)

	http_request.queue_free()

	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		_stats["successful"] += 1
		_record_success(host)
		var response_data := _parse_response(body)
		Logger.debug("NetworkClient: %s %s -> %d (%dms)" % [_method_string(request["method"]), url, response_code, elapsed], "Network")

		if request["target"] and is_instance_valid(request["target"]) and not request["method_name"].is_empty():
			request["target"].call(request["method_name"], response_code, response_data)
	else:
		_stats["failed"] += 1
		_record_failure(host)
		var error_body := body.get_string_from_utf8()
		Logger.warning("NetworkClient: %s %s -> %d (result=%d, %dms) %s" % [_method_string(request["method"]), url, response_code, result, elapsed, error_body], "Network")

		# Retry on server errors or network failures
		if request["retry_count"] < _default_retries and (response_code >= 500 or result != HTTPRequest.RESULT_SUCCESS):
			_stats["retries"] += 1
			var delay := _retry_base_delay * pow(2.0, request["retry_count"]) / 1000.0
			Logger.info("NetworkClient: Retrying %s (attempt %d/%d) in %.1fs" % [url, request["retry_count"] + 1, _default_retries, delay], "Network")
			request["retry_count"] += 1
			await get_tree().create_timer(delay).timeout
			_request_queue.insert(0, request)  # Re-queue at front for retry
		else:
			if request["target"] and is_instance_valid(request["target"]) and not request["method_name"].is_empty():
				request["target"].call(request["method_name"], response_code, {"error": "Request failed", "status": response_code, "body": error_body})

	EventBus.emit("network_response", {"url": url, "code": response_code, "elapsed_ms": elapsed})
	_process_queue()


## Handle immediate request failure
func _handle_request_failure(request: Dictionary, error_code: int, error_msg: String) -> void:
	var url: String = request["url"]
	var host := _extract_host(url)
	_record_failure(host)

	if request["retry_count"] < _default_retries:
		_stats["retries"] += 1
		var delay := _retry_base_delay * pow(2.0, request["retry_count"]) / 1000.0
		request["retry_count"] += 1
		await get_tree().create_timer(delay).timeout
		_request_queue.insert(0, request)
	else:
		_stats["failed"] += 1
		if request["target"] and is_instance_valid(request["target"]) and not request["method_name"].is_empty():
			request["target"].call(request["method_name"], 0, {"error": error_msg, "code": error_code})


## --- Circuit Breaker ---

## Extract host from URL
func _extract_host(url: String) -> String:
	var parts := url.split("://")
	if parts.size() > 1:
		var host_part := parts[1].split("/")[0]
		return host_part
	return url


## Check if circuit is open for a host
func _is_circuit_open(host: String) -> bool:
	if not _circuit_breakers.has(host):
		return false

	var breaker = _circuit_breakers[host]
	var now := Time.get_ticks_msec() / 1000.0

	match breaker["state"]:
		BreakerState.OPEN:
			# Check if reset timeout has elapsed
			if now - breaker["last_failure_time"] > _breaker_reset_timeout:
				breaker["state"] = BreakerState.HALF_OPEN
				breaker["half_open_count"] = 0
				Logger.info("NetworkClient: Circuit half-open for %s" % host, "Network")
				return false
			return true
		BreakerState.HALF_OPEN:
			# Allow limited requests
			if breaker["half_open_count"] >= _breaker_half_open_max:
				return true
			breaker["half_open_count"] += 1
			return false
		_:
			return false


## Record a successful request for circuit breaker
func _record_success(host: String) -> void:
	if not _circuit_breakers.has(host):
		return

	var breaker = _circuit_breakers[host]
	breaker["success_count"] += 1

	if breaker["state"] == BreakerState.HALF_OPEN:
		# Close circuit after enough successes in half-open
		if breaker["success_count"] >= _breaker_half_open_max:
			breaker["state"] = BreakerState.CLOSED
			breaker["failure_count"] = 0
			breaker["success_count"] = 0
			Logger.info("NetworkClient: Circuit closed for %s" % host, "Network")


## Record a failed request for circuit breaker
func _record_failure(host: String) -> void:
	if not _circuit_breakers.has(host):
		_circuit_breakers[host] = {
			"state": BreakerState.CLOSED,
			"failure_count": 0,
			"success_count": 0,
			"last_failure_time": 0.0,
			"half_open_count": 0
		}

	var breaker = _circuit_breakers[host]
	breaker["failure_count"] += 1
	breaker["last_failure_time"] = Time.get_ticks_msec() / 1000.0

	if breaker["state"] == BreakerState.HALF_OPEN:
		# Any failure in half-open re-opens circuit
		breaker["state"] = BreakerState.OPEN
		breaker["half_open_count"] = 0
		Logger.warning("NetworkClient: Circuit re-opened for %s" % host, "Network")
	elif breaker["failure_count"] >= _breaker_failure_threshold and breaker["state"] == BreakerState.CLOSED:
		breaker["state"] = BreakerState.OPEN
		Logger.warning("NetworkClient: Circuit opened for %s after %d failures" % [host, breaker["failure_count"]], "Network")
		EventBus.emit("circuit_opened", {"host": host, "failures": breaker["failure_count"]})


## Get circuit breaker state for a host
func get_circuit_state(host: String) -> String:
	if not _circuit_breakers.has(host):
		return "closed"
	var breaker = _circuit_breakers[host]
	match breaker["state"]:
		BreakerState.CLOSED: return "closed"
		BreakerState.OPEN: return "open"
		BreakerState.HALF_OPEN: return "half_open"
	return "unknown"


## Get all circuit breaker states
func get_all_circuit_states() -> Dictionary:
	var result := {}
	for host in _circuit_breakers:
		var breaker = _circuit_breakers[host]
		result[host] = {
			"state": get_circuit_state(host),
			"failures": breaker["failure_count"],
			"successes": breaker["success_count"],
			"last_failure": breaker["last_failure_time"]
		}
	return result


## Reset circuit breaker for a host
func reset_circuit(host: String) -> void:
	if _circuit_breakers.has(host):
		_circuit_breakers.erase(host)
		Logger.info("NetworkClient: Circuit reset for %s" % host, "Network")


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
		"connected": false,
		"reconnect_attempts": 0
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
					conn["reconnect_attempts"] = 0
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


## --- Statistics ---

## Get network statistics
func get_stats() -> Dictionary:
	var stats := _stats.duplicate()
	stats["active_requests"] = _active_requests
	stats["queue_size"] = _request_queue.size()
	stats["circuit_breakers"] = _circuit_breakers.size()
	stats["hosts_tracked"] = _host_stats.size()
	if _stats["total_requests"] > 0:
		stats["success_rate"] = float(_stats["successful"]) / float(_stats["total_requests"])
	else:
		stats["success_rate"] = 0.0
	return stats


## Get per-host statistics
func get_host_stats(host: String) -> Dictionary:
	if _host_stats.has(host):
		return _host_stats[host].duplicate()
	return {"requests": 0, "successes": 0, "failures": 0, "avg_ms": 0.0}


## Get all host statistics
func get_all_host_stats() -> Dictionary:
	return _host_stats.duplicate(true)


## Update per-host statistics
func _update_host_stats(host: String, elapsed_ms: int, success: bool) -> void:
	if not _host_stats.has(host):
		_host_stats[host] = {"requests": 0, "successes": 0, "failures": 0, "total_ms": 0.0, "avg_ms": 0.0}

	var stats = _host_stats[host]
	stats["requests"] += 1
	stats["total_ms"] += elapsed_ms
	stats["avg_ms"] = stats["total_ms"] / stats["requests"]
	if success:
		stats["successes"] += 1
	else:
		stats["failures"] += 1


## Check if a URL is reachable (quick test)
func check_connectivity(url: String) -> bool:
	var http_request := HTTPRequest.new()
	http_request.timeout = 2.0
	add_child(http_request)
	var error_code := http_request.request(url, [], true, HTTPClient.METHOD_HEAD, "")
	return error_code == OK


## Get queue size
func get_queue_size() -> int:
	return _request_queue.size()


## Clear request queue
func clear_queue() -> void:
	_request_queue.clear()
	Logger.info("NetworkClient: Request queue cleared", "Network")


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
