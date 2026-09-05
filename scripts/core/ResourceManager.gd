extends Node
## ResourceManager - Asynchronous resource loading, caching, and unloading
##
## Manages game resources (textures, scenes, audio, fonts) with reference
## counting, async loading, and memory management. Prevents duplicate loads
## and provides progress tracking for bulk loading.
##
## Usage:
##   ResourceManager.load_async("res://assets/textures/player.png", self, "_on_loaded")
##   var tex = ResourceManager.get("res://assets/textures/player.png")
##   ResourceManager.unload("res://assets/textures/player.png")
##   ResourceManager.load_group(["a.png", "b.png"], self, "_on_group", 0.5)

## Cached resources: { path: { resource, ref_count, type, size_kb } }
var _cache: Dictionary = {}

## Active async loads: { path: [{target, method}] }
var _pending_loads: Dictionary = {}

## Loading groups: { group_id: { paths, loaded, total, callback_target, callback_method } }
var _loading_groups: Dictionary = {}
var _group_counter: int = 0

## Maximum cache size in KB (0 = unlimited)
var _max_cache_kb: int = 0

## Statistics
var _stats: Dictionary = {
	"total_loads": 0,
	"cache_hits": 0,
	"cache_misses": 0,
	"total_unloaded": 0,
	"current_cache_size_kb": 0,
	"peak_cache_size_kb": 0
}


func _ready() -> void:
	GameLog.info("ResourceManager initialized", "Resource")


## Load a resource synchronously (with cache)
func load(path: String) -> Resource:
	if _cache.has(path):
		_stats["cache_hits"] += 1
		var entry = _cache[path]
		entry["ref_count"] += 1
		return entry["resource"]

	_stats["cache_misses"] += 1
	var resource: Resource = ResourceLoader.load(path)
	if resource == null:
		GameLog.error("ResourceManager: Failed to load: %s" % path, "Resource")
		return null

	_cache_resource(path, resource)
	_stats["total_loads"] += 1
	return resource


## Load a resource asynchronously
## callback(target, method) receives (path, resource)
func load_async(path: String, callback_target: Object = null, callback_method: String = "") -> void:
	# Check cache first
	if _cache.has(path):
		_stats["cache_hits"] += 1
		var entry = _cache[path]
		entry["ref_count"] += 1
		if callback_target and is_instance_valid(callback_target) and not callback_method.is_empty():
			callback_target.call(callback_method, path, entry["resource"])
		return

	# Check if already loading
	if _pending_loads.has(path):
		if callback_target and is_instance_valid(callback_target) and not callback_method.is_empty():
			_pending_loads[path].append({"target": callback_target, "method": callback_method})
		return

	# Start new async load
	_pending_loads[path] = []
	if callback_target and is_instance_valid(callback_target) and not callback_method.is_empty():
		_pending_loads[path].append({"target": callback_target, "method": callback_method})

	_stats["cache_misses"] += 1

	# Use ResourceLoader.load_threaded_request
	var error_code := ResourceLoader.load_threaded_request(path, false, ResourceLoader.CACHE_MODE_REUSE)
	if error_code != OK:
		GameLog.error("ResourceManager: Async load failed for %s: error %d" % [path, error_code], "Resource")
		_notify_load_complete(path, null)
		return

	# Poll for completion
	_await_async_load(path)


## Get a cached resource (does not increment ref count)
func get(path: String) -> Resource:
	if _cache.has(path):
		return _cache[path]["resource"]
	return null


## Check if resource is cached
func is_cached(path: String) -> bool:
	return _cache.has(path)


## Check if resource is currently loading
func is_loading(path: String) -> bool:
	return _pending_loads.has(path)


## Unload a resource (decrements ref count, frees at 0)
func unload(path: String) -> void:
	if not _cache.has(path):
		return

	var entry = _cache[path]
	entry["ref_count"] -= 1

	if entry["ref_count"] <= 0:
		_stats["current_cache_size_kb"] -= entry["size_kb"]
		_stats["total_unloaded"] += 1
		_cache.erase(path)
		GameLog.debug("ResourceManager: Unloaded: %s (%.1f KB)" % [path, entry["size_kb"]], "Resource")
	else:
		GameLog.debug("ResourceManager: Released ref: %s (refs=%d)" % [path, entry["ref_count"]], "Resource")


## Force unload regardless of ref count
func force_unload(path: String) -> void:
	if _cache.has(path):
		var entry = _cache[path]
		_stats["current_cache_size_kb"] -= entry["size_kb"]
		_stats["total_unloaded"] += 1
		_cache.erase(path)
		GameLog.info("ResourceManager: Force unloaded: %s" % path, "Resource")


## Load a group of resources with progress callback
## progress_callback receives (group_id, loaded, total, path, resource)
## Returns group_id
func load_group(paths: Array, callback_target: Object = null, callback_method: String = "", priority: float = 1.0) -> int:
	var group_id := _group_counter
	_group_counter += 1

	_loading_groups[group_id] = {
		"paths": paths.duplicate(),
		"loaded": 0,
		"total": paths.size(),
		"callback_target": callback_target,
		"callback_method": callback_method
	}

	GameLog.info("ResourceManager: Loading group %d (%d resources)" % [group_id, paths.size()], "Resource")

	for path in paths:
		load_async(path, self, "_on_group_resource_loaded")
		# Store group_id for callback routing
		_last_group_id = group_id

	return group_id


## Get loading group progress
func get_group_progress(group_id: int) -> Dictionary:
	if not _loading_groups.has(group_id):
		return {}
	var group = _loading_groups[group_id]
	return {
		"group_id": group_id,
		"loaded": group["loaded"],
		"total": group["total"],
		"progress": float(group["loaded"]) / max(group["total"], 1),
		"complete": group["loaded"] >= group["total"]
	}


## Get cache statistics
func get_cache_stats() -> Dictionary:
	var result := _stats.duplicate()
	result["cached_resources"] = _cache.size()
	result["pending_loads"] = _pending_loads.size()
	result["active_groups"] = _loading_groups.size()
	return result


## Get detailed cache info
func get_cache_info() -> Dictionary:
	var result := {}
	for path in _cache:
		var entry = _cache[path]
		result[path] = {
			"type": entry["type"],
			"ref_count": entry["ref_count"],
			"size_kb": entry["size_kb"]
		}
	return result


## Clear all cached resources
func clear_cache() -> void:
	var count := _cache.size()
	_cache.clear()
	_stats["current_cache_size_kb"] = 0
	GameLog.info("ResourceManager: Cleared cache (%d resources)" % count, "Resource")


## Get resource manager statistics
func get_stats() -> Dictionary:
	var stats := _stats.duplicate()
	stats["cached_resources"] = _cache.size()
	stats["pending_loads"] = _pending_loads.size()
	stats["loading_groups"] = _loading_groups.size()
	stats["max_cache_kb"] = _max_cache_kb
	if _stats["cache_hits"] + _stats["cache_misses"] > 0:
		stats["cache_hit_rate"] = float(_stats["cache_hits"]) / float(_stats["cache_hits"] + _stats["cache_misses"])
	else:
		stats["cache_hit_rate"] = 0.0
	return stats


## Preload a list of resources synchronously
func preload(paths: Array) -> void:
	for path in paths:
		load(path)
	GameLog.info("ResourceManager: Preloaded %d resources" % paths.size(), "Resource")


## --- Internal ---

var _last_group_id: int = -1


func _cache_resource(path: String, resource: Resource) -> void:
	var size_kb := _estimate_resource_size(resource)
	_cache[path] = {
		"resource": resource,
		"ref_count": 1,
		"type": resource.get_class(),
		"size_kb": size_kb
	}
	_stats["current_cache_size_kb"] += size_kb
	if _stats["current_cache_size_kb"] > _stats["peak_cache_size_kb"]:
		_stats["peak_cache_size_kb"] = _stats["current_cache_size_kb"]


func _await_async_load(path: String) -> void:
	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame

	var status := ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var resource: Resource = ResourceLoader.load_threaded_get(path)
		if resource:
			_cache_resource(path, resource)
			_stats["total_loads"] += 1
		_notify_load_complete(path, resource)
	else:
		GameLog.error("ResourceManager: Async load failed for %s (status=%d)" % [path, status], "Resource")
		_notify_load_complete(path, null)


func _notify_load_complete(path: String, resource: Resource) -> void:
	if _pending_loads.has(path):
		var callbacks = _pending_loads[path]
		_pending_loads.erase(path)
		for cb in callbacks:
			if cb["target"] and is_instance_valid(cb["target"]) and not cb["method"].is_empty():
				cb["target"].call(cb["method"], path, resource)


func _on_group_resource_loaded(path: String, resource: Resource) -> void:
	# Find the group that requested this resource
	for group_id in _loading_groups:
		var group = _loading_groups[group_id]
		if group["paths"].has(path):
			group["loaded"] += 1
			var progress := float(group["loaded"]) / max(group["total"], 1)

			if group["callback_target"] and is_instance_valid(group["callback_target"]) and not group["callback_method"].is_empty():
				group["callback_target"].call(group["callback_method"], {
					"group_id": group_id,
					"path": path,
					"resource": resource,
					"loaded": group["loaded"],
					"total": group["total"],
					"progress": progress
				})

			if group["loaded"] >= group["total"]:
				GameLog.info("ResourceManager: Group %d complete (%d resources)" % [group_id, group["total"]], "Resource")
				_loading_groups.erase(group_id)
			break


func _estimate_resource_size(resource: Resource) -> float:
	# Rough size estimation based on resource type
	match resource.get_class():
		"Texture2D", "ImageTexture":
			var img: Image = null
			if resource is ImageTexture:
				img = (resource as ImageTexture).get_image()
			if img:
				return float(img.get_data().size()) / 1024.0
			return 100.0  # default estimate
		"PackedScene":
			return 50.0
		"AudioStream":
			return 200.0
		"FontFile":
			return 500.0
		_:
			return 10.0
