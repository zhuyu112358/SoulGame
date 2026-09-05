extends Node
## PerformanceMonitor - Real-time performance metrics collection and reporting
##
## Collects FPS, memory, draw calls, process time, and custom metrics.
## Exposes stats for DebugOverlay and logging. Supports performance baseline
## testing for technical validation (not game logic).
##
## Usage:
##   PerformanceMonitor.start_baseline("multi_soul_render")
##   # ... run test ...
##   var results = PerformanceMonitor.end_baseline("multi_soul_render")
##   PerformanceMonitor.record_metric("custom_timing", 16.5)

## Whether monitoring is active
var _active: bool = true

## Frame statistics
var _frame_times: Array = []
var _max_frame_history: int = 300

## FPS tracking
var _fps_samples: Array = []
var _fps_min: float = 9999.0
var _fps_max: float = 0.0

## Memory tracking (in MB)
var _memory_static: float = 0.0
var _memory_dynamic: float = 0.0
var _memory_peak: float = 0.0

## Draw call tracking
var _draw_calls: int = 0
var _draw_calls_peak: int = 0

## Process time tracking (ms)
var _process_time_ms: float = 0.0
var _process_time_peak: float = 0.0

## Custom metrics: { name: { values: [], min, max, avg, count } }
var _custom_metrics: Dictionary = {}

## Active baseline tests: { name: { start_time, frames, frame_times, ... } }
var _active_baselines: Dictionary = {}

## Completed baseline results: { name: { ... } }
var _baseline_results: Dictionary = {}

## Update interval for heavy metrics (seconds)
var _heavy_update_interval: float = 1.0
var _heavy_update_timer: float = 0.0

## Statistics for overall session
var _session_stats: Dictionary = {
	"total_frames": 0,
	"total_time": 0.0,
	"fps_avg": 0.0,
	"fps_1pct_low": 0.0,
	"memory_peak_mb": 0.0
}


func _ready() -> void:
	Logger.info("PerformanceMonitor initialized", "Perf")


func _process(delta: float) -> void:
	if not _active:
		return

	# Frame time tracking
	var frame_time_ms := delta * 1000.0
	_frame_times.append(frame_time_ms)
	if _frame_times.size() > _max_frame_history:
		_frame_times.pop_front()

	# FPS tracking
	var fps := Engine.get_frames_per_second()
	_fps_samples.append(fps)
	if _fps_samples.size() > _max_frame_history:
		_fps_samples.pop_front()
	if fps < _fps_min:
		_fps_min = fps
	if fps > _fps_max:
		_fps_max = fps

	# Session stats
	_session_stats["total_frames"] += 1
	_session_stats["total_time"] += delta

	# Heavy metrics (updated less frequently)
	_heavy_update_timer += delta
	if _heavy_update_timer >= _heavy_update_interval:
		_heavy_update_timer = 0.0
		_update_heavy_metrics()

	# Update active baselines
	for name in _active_baselines:
		var baseline = _active_baselines[name]
		baseline["frames"] += 1
		baseline["frame_times"].append(frame_time_ms)
		baseline["fps_samples"].append(fps)
		if frame_time_ms > baseline["frame_time_peak"]:
			baseline["frame_time_peak"] = frame_time_ms
		if fps < baseline["fps_min"]:
			baseline["fps_min"] = fps


## Start a performance baseline test
func start_baseline(test_name: String) -> void:
	if _active_baselines.has(test_name):
		Logger.warning("PerformanceMonitor: Baseline '%s' already running, restarting" % test_name, "Perf")

	_active_baselines[test_name] = {
		"start_time": Time.get_ticks_msec(),
		"start_frame": _session_stats["total_frames"],
		"frames": 0,
		"frame_times": [],
		"fps_samples": [],
		"fps_min": 9999.0,
		"frame_time_peak": 0.0,
		"draw_calls_start": _draw_calls,
		"memory_start": _memory_static + _memory_dynamic
	}
	Logger.info("PerformanceMonitor: Baseline started: %s" % test_name, "Perf")


## End a performance baseline test and return results
func end_baseline(test_name: String) -> Dictionary:
	if not _active_baselines.has(test_name):
		Logger.error("PerformanceMonitor: Baseline '%s' not found" % test_name, "Perf")
		return {}

	var baseline = _active_baselines[test_name]
	var elapsed_ms := Time.get_ticks_msec() - baseline["start_time"]

	# Calculate statistics
	var frame_times: Array = baseline["frame_times"]
	var fps_samples: Array = baseline["fps_samples"]

	var avg_frame_time := 0.0
	if not frame_times.is_empty():
		avg_frame_time = frame_times.reduce(func(a, b): return a + b, 0.0) / frame_times.size()

	var avg_fps := 0.0
	if not fps_samples.is_empty():
		avg_fps = fps_samples.reduce(func(a, b): return a + b, 0.0) / fps_samples.size()

	# 1% low FPS (bottom 1% of frame times converted)
	var sorted_frames := frame_times.duplicate()
	sorted_frames.sort()
	var p99_index := int(sorted_frames.size() * 0.99)
	var frame_time_p99 := sorted_frames[min(p99_index, sorted_frames.size() - 1)] if not sorted_frames.is_empty() else 0.0
	var fps_1pct_low := 1000.0 / max(frame_time_p99, 0.01)

	var results := {
		"test_name": test_name,
		"elapsed_ms": elapsed_ms,
		"frames": baseline["frames"],
		"avg_fps": avg_fps,
		"fps_min": baseline["fps_min"],
		"fps_1pct_low": fps_1pct_low,
		"avg_frame_time_ms": avg_frame_time,
		"frame_time_peak_ms": baseline["frame_time_peak"],
		"frame_time_p99_ms": frame_time_p99,
		"draw_calls": _draw_calls - baseline["draw_calls_start"],
		"memory_delta_mb": (_memory_static + _memory_dynamic) - baseline["memory_start"],
		"timestamp": Time.get_datetime_string_from_system()
	}

	_baseline_results[test_name] = results
	_active_baselines.erase(test_name)

	Logger.info("PerformanceMonitor: Baseline '%s' complete - avg FPS: %.1f, 1%% low: %.1f, peak frame: %.2fms" % [
		test_name, avg_fps, fps_1pct_low, baseline["frame_time_peak"]
	], "Perf")

	EventBus.emit("baseline_complete", results)
	return results


## Get a completed baseline result
func get_baseline_result(test_name: String) -> Dictionary:
	if _baseline_results.has(test_name):
		return _baseline_results[test_name].duplicate()
	return {}


## Get all baseline results
func get_all_baselines() -> Dictionary:
	return _baseline_results.duplicate(true)


## Record a custom metric value
func record_metric(metric_name: String, value: float) -> void:
	if not _custom_metrics.has(metric_name):
		_custom_metrics[metric_name] = {
			"values": [],
			"min": value,
			"max": value,
			"sum": 0.0,
			"count": 0
		}

	var metric = _custom_metrics[metric_name]
	metric["values"].append(value)
	if metric["values"].size() > 1000:
		metric["values"].pop_front()
	metric["sum"] += value
	metric["count"] += 1
	if value < metric["min"]:
		metric["min"] = value
	if value > metric["max"]:
		metric["max"] = value


## Get custom metric statistics
func get_metric_stats(metric_name: String) -> Dictionary:
	if not _custom_metrics.has(metric_name):
		return {}
	var metric = _custom_metrics[metric_name]
	return {
		"name": metric_name,
		"count": metric["count"],
		"min": metric["min"],
		"max": metric["max"],
		"avg": metric["sum"] / max(metric["count"], 1),
		"recent": metric["values"][metric["values"].size() - 1] if not metric["values"].is_empty() else 0.0
	}


## Get current performance snapshot (for DebugOverlay)
func get_snapshot() -> Dictionary:
	var avg_fps := 0.0
	if not _fps_samples.is_empty():
		avg_fps = _fps_samples.reduce(func(a, b): return a + b, 0.0) / _fps_samples.size()

	var avg_frame := 0.0
	if not _frame_times.is_empty():
		avg_frame = _frame_times.reduce(func(a, b): return a + b, 0.0) / _frame_times.size()

	return {
		"fps_current": Engine.get_frames_per_second(),
		"fps_avg": avg_fps,
		"fps_min": _fps_min,
		"fps_max": _fps_max,
		"frame_time_avg_ms": avg_frame,
		"frame_time_peak_ms": _frame_times.max() if not _frame_times.is_empty() else 0.0,
		"memory_static_mb": _memory_static,
		"memory_dynamic_mb": _memory_dynamic,
		"memory_peak_mb": _memory_peak,
		"draw_calls": _draw_calls,
		"draw_calls_peak": _draw_calls_peak,
		"active_baselines": _active_baselines.size(),
		"completed_baselines": _baseline_results.size(),
		"object_count": get_tree().get_node_count(),
		"total_frames": _session_stats["total_frames"]
	}


## Reset all statistics
func reset() -> void:
	_frame_times.clear()
	_fps_samples.clear()
	_fps_min = 9999.0
	_fps_max = 0.0
	_custom_metrics.clear()
	_active_baselines.clear()
	_baseline_results.clear()
	_session_stats = {
		"total_frames": 0,
		"total_time": 0.0,
		"fps_avg": 0.0,
		"fps_1pct_low": 0.0,
		"memory_peak_mb": 0.0
	}
	Logger.info("PerformanceMonitor reset", "Perf")


## Get performance statistics (standard interface)
func get_stats() -> Dictionary:
	var snapshot := get_snapshot()
	snapshot["session_stats"] = _session_stats.duplicate()
	snapshot["custom_metrics_count"] = _custom_metrics.size()
	snapshot["process_time_ms"] = _process_time_ms
	snapshot["process_time_peak_ms"] = _process_time_peak_ms
	return snapshot


func _update_heavy_metrics() -> void:
	# Memory stats (Godot 4 Performance API)
	_memory_static = float(Performance.get_monitor(Performance.MEMORY_STATIC)) / (1024.0 * 1024.0)
	_memory_dynamic = float(Performance.get_monitor(Performance.MEMORY_DYNAMIC)) / (1024.0 * 1024.0)
	var total_memory := _memory_static + _memory_dynamic
	if total_memory > _memory_peak:
		_memory_peak = total_memory

	# Draw calls
	_draw_calls = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if _draw_calls > _draw_calls_peak:
		_draw_calls_peak = _draw_calls

	# Process time
	_process_time_ms = float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
	if _process_time_ms > _process_time_peak:
		_process_time_peak = _process_time_ms
