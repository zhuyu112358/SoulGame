extends Node
## LatencyProfiler - Network latency and round-trip time measurement
##
## Measures HTTP request latency, WebSocket ping/pong latency,
## and state sync delay. Provides baseline data for technical validation.
##
## Usage:
##   LatencyProfiler.measure_http("http://localhost:3000/api/souls", self, "_on_result")
##   LatencyProfiler.start_ws_probe("ws://localhost:3000/ws")
##   var stats = LatencyProfiler.get_stats()

## HTTP latency samples: { url: [times] }
var _http_samples: Dictionary = {}

## WebSocket latency samples
var _ws_samples: Array = []

## State sync delay samples (tick received vs tick sent)
var _sync_delay_samples: Array = []

## Maximum samples per metric
var _max_samples: int = 100

## Overall statistics
var _stats: Dictionary = {
	"http_requests": 0,
	"http_avg_ms": 0.0,
	"http_p95_ms": 0.0,
	"http_min_ms": 0.0,
	"http_max_ms": 0.0,
	"ws_pings": 0,
	"ws_avg_ms": 0.0,
	"sync_events": 0,
	"sync_avg_ms": 0.0
}

## Active HTTP measurements: { request_id: {url, start_time, callback} }
var _active_measurements: Dictionary = {}
var _request_counter: int = 0


func _ready() -> void:
	GameLog.info("LatencyProfiler initialized", "Latency")


## Measure HTTP request latency
## Returns request_id for tracking
func measure_http(url: String, callback_target: Object = null, callback_method: String = "") -> int:
	var request_id := _request_counter
	_request_counter += 1

	_active_measurements[request_id] = {
		"url": url,
		"start_time": Time.get_ticks_msec(),
		"callback_target": callback_target,
		"callback_method": callback_method
	}

	NetworkClient.http_get(url, self, "_on_http_response")
	return request_id


## Record a WebSocket latency sample (called by StateSyncClient or manually)
func record_ws_latency(latency_ms: float) -> void:
	_ws_samples.append(latency_ms)
	if _ws_samples.size() > _max_samples:
		_ws_samples.pop_front()
	_stats["ws_pings"] += 1
	_stats["ws_avg_ms"] = _ws_samples.reduce(func(a, b): return a + b, 0.0) / _ws_samples.size()
	PerformanceMonitor.record_metric("ws_latency", latency_ms)


## Record a state sync delay sample
func record_sync_delay(delay_ms: float) -> void:
	_sync_delay_samples.append(delay_ms)
	if _sync_delay_samples.size() > _max_samples:
		_sync_delay_samples.pop_front()
	_stats["sync_events"] += 1
	_stats["sync_avg_ms"] = _sync_delay_samples.reduce(func(a, b): return a + b, 0.0) / _sync_delay_samples.size()
	PerformanceMonitor.record_metric("sync_delay_ms", delay_ms)


## Run a batch HTTP latency test
## count: number of requests to send
## interval_ms: delay between requests
func run_http_batch(url: String, count: int, interval_ms: float = 100.0, callback_target: Object = null, callback_method: String = "") -> void:
	GameLog.info("LatencyProfiler: Starting batch test - %d requests to %s" % [count, url], "Latency")
	_batch_results = []
	_batch_target = callback_target
	_batch_method = callback_method
	_batch_total = count
	_batch_completed = 0

	for i in range(count):
		await get_tree().create_timer(interval_ms / 1000.0).timeout
		measure_http(url, self, "_on_batch_response")


## Get current statistics
func get_stats() -> Dictionary:
	return _stats.duplicate()


## Get detailed HTTP stats for a URL
func get_http_stats(url: String) -> Dictionary:
	if not _http_samples.has(url) or _http_samples[url].is_empty():
		return {}

	var samples: Array = _http_samples[url]
	var sorted := samples.duplicate()
	sorted.sort()

	return {
		"url": url,
		"count": samples.size(),
		"min_ms": sorted[0],
		"max_ms": sorted[sorted.size() - 1],
		"avg_ms": samples.reduce(func(a, b): return a + b, 0.0) / samples.size(),
		"p50_ms": sorted[int(sorted.size() * 0.5)],
		"p95_ms": sorted[int(sorted.size() * 0.95)],
		"p99_ms": sorted[int(sorted.size() * 0.99)]
	}


## Get all HTTP stats
func get_all_http_stats() -> Dictionary:
	var result := {}
	for url in _http_samples:
		result[url] = get_http_stats(url)
	return result


## Reset all measurements
func reset() -> void:
	_http_samples.clear()
	_ws_samples.clear()
	_sync_delay_samples.clear()
	_active_measurements.clear()
	_stats = {
		"http_requests": 0,
		"http_avg_ms": 0.0,
		"http_p95_ms": 0.0,
		"http_min_ms": 0.0,
		"http_max_ms": 0.0,
		"ws_pings": 0,
		"ws_avg_ms": 0.0,
		"sync_events": 0,
		"sync_avg_ms": 0.0
	}
	GameLog.info("LatencyProfiler reset", "Latency")


## --- Internal ---

var _batch_results: Array = []
var _batch_target: Object = null
var _batch_method: String = ""
var _batch_total: int = 0
var _batch_completed: int = 0


func _on_http_response(status: int, data: Dictionary) -> void:
	# Find the most recent active measurement (simplified: FIFO)
	if _active_measurements.is_empty():
		return

	var request_id = _active_measurements.keys()[0]
	var measurement = _active_measurements[request_id]
	var latency := float(Time.get_ticks_msec() - measurement["start_time"])
	_active_measurements.erase(request_id)

	# Record sample
	var url: String = measurement["url"]
	if not _http_samples.has(url):
		_http_samples[url] = []
	_http_samples[url].append(latency)
	if _http_samples[url].size() > _max_samples:
		_http_samples[url].pop_front()

	# Update overall stats
	_stats["http_requests"] += 1
	var all_samples: Array = []
	for u in _http_samples:
		all_samples.append_array(_http_samples[u])
	if not all_samples.is_empty():
		_stats["http_avg_ms"] = all_samples.reduce(func(a, b): return a + b, 0.0) / all_samples.size()
		var sorted := all_samples.duplicate()
		sorted.sort()
		_stats["http_min_ms"] = sorted[0]
		_stats["http_max_ms"] = sorted[sorted.size() - 1]
		_stats["http_p95_ms"] = sorted[int(sorted.size() * 0.95)]

	PerformanceMonitor.record_metric("http_latency_ms", latency)

	# Callback
	var callback_target: Object = measurement["callback_target"]
	var callback_method: String = measurement["callback_method"]
	if callback_target and is_instance_valid(callback_target) and not callback_method.is_empty():
		callback_target.call(callback_method, {"latency_ms": latency, "status": status, "url": url})


func _on_batch_response(result: Dictionary) -> void:
	_batch_results.append(result)
	_batch_completed += 1

	if _batch_completed >= _batch_total:
		var latencies := []
		for r in _batch_results:
			latencies.append(r["latency_ms"])
		var sorted := latencies.duplicate()
		sorted.sort()
		var summary := {
			"total": _batch_total,
			"avg_ms": latencies.reduce(func(a, b): return a + b, 0.0) / latencies.size(),
			"min_ms": sorted[0],
			"max_ms": sorted[sorted.size() - 1],
			"p95_ms": sorted[int(sorted.size() * 0.95)],
			"results": _batch_results
		}
		GameLog.info("LatencyProfiler: Batch complete - avg: %.1fms, p95: %.1fms" % [summary["avg_ms"], summary["p95_ms"]], "Latency")

		if _batch_target and is_instance_valid(_batch_target) and not _batch_method.is_empty():
			_batch_target.call(_batch_method, summary)
