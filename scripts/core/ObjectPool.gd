extends Node
## ObjectPool - Generic object pooling system for efficient Node reuse
##
## Reduces instantiation overhead by pre-creating and reusing objects.
## Supports multiple pool types, dynamic growth, and statistics.
##
## Usage:
##   ObjectPool.register_pool("enemy", preload("res://enemy.tscn"), 10, 50)
##   var enemy = ObjectPool.acquire("enemy")
##   ObjectPool.release("enemy", enemy)
##   ObjectPool.preload_objects("enemy", 20)

## Pool definitions: { pool_name: { scene, active_count, pool, min_size, max_size, total_created } }
var _pools: Dictionary = {}

## Statistics
var _stats: Dictionary = {
	"total_acquired": 0,
	"total_released": 0,
	"pool_hits": 0,
	"pool_misses": 0,
	"peak_active": 0
}


func _ready() -> void:
	GameLog.info("ObjectPool initialized", "Pool")


## Register a new object pool
## pool_name: Unique identifier
## scene: PackedScene to instantiate
## min_size: Pre-created objects
## max_size: Maximum objects (0 = unlimited)
func register_pool(pool_name: String, scene: PackedScene, min_size: int = 5, max_size: int = 0) -> void:
	if _pools.has(pool_name):
		GameLog.warning("ObjectPool: Pool '%s' already registered, re-registering" % pool_name, "Pool")

	_pools[pool_name] = {
		"scene": scene,
		"active": [],
		"available": [],
		"min_size": min_size,
		"max_size": max_size,
		"total_created": 0
	}

	# Pre-create minimum objects
	for i in range(min_size):
		var obj := _create_instance(pool_name)
		_pools[pool_name]["available"].append(obj)

	GameLog.info("ObjectPool: Registered '%s' (min=%d, max=%d, preloaded=%d)" % [
		pool_name, min_size, max_size, min_size
	], "Pool")


## Acquire an object from the pool
## Returns null if pool is at max capacity
func acquire(pool_name: String) -> Node:
	if not _pools.has(pool_name):
		GameLog.error("ObjectPool: Unknown pool '%s'" % pool_name, "Pool")
		return null

	var pool = _pools[pool_name]

	# Try to reuse from available pool
	if not pool["available"].is_empty():
		var obj: Node = pool["available"].pop_back()
		pool["active"].append(obj)
		_stats["pool_hits"] += 1
		_stats["total_acquired"] += 1
		_update_peak(pool)
		obj.process_mode = Node.PROCESS_MODE_INHERIT
		obj.visible = true
		if obj.has_signal("acquired"):
			obj.emit_signal("acquired")
		return obj

	# Pool miss - create new instance if under max
	if pool["max_size"] > 0 and pool["total_created"] >= pool["max_size"]:
		GameLog.warning("ObjectPool: Pool '%s' at max capacity (%d)" % [pool_name, pool["max_size"]], "Pool")
		return null

	var obj := _create_instance(pool_name)
	pool["active"].append(obj)
	_stats["pool_misses"] += 1
	_stats["total_acquired"] += 1
	_update_peak(pool)
	return obj


## Release an object back to the pool
func release(pool_name: String, obj: Node) -> void:
	if not _pools.has(pool_name):
		GameLog.error("ObjectPool: Unknown pool '%s'" % pool_name, "Pool")
		obj.queue_free()
		return

	var pool = _pools[pool_name]

	# Remove from active list
	var active: Array = pool["active"]
	for i in range(active.size() - 1, -1, -1):
		if active[i] == obj:
			active.remove_at(i)
			break

	# Reset object state
	obj.process_mode = Node.PROCESS_MODE_DISABLED
	obj.visible = false
	if obj.has_method("reset"):
		obj.call("reset")
	if obj.has_signal("released"):
		obj.emit_signal("released")

	# Return to available pool
	pool["available"].append(obj)
	_stats["total_released"] += 1


## Preload additional objects into the pool
func preload_objects(pool_name: String, count: int) -> void:
	if not _pools.has(pool_name):
		return

	var pool = _pools[pool_name]
	for i in range(count):
		if pool["max_size"] > 0 and pool["total_created"] >= pool["max_size"]:
			break
		var obj := _create_instance(pool_name)
		pool["available"].append(obj)

	GameLog.debug("ObjectPool: Preloaded %d into '%s' (total=%d)" % [count, pool_name, pool["total_created"]], "Pool")


## Get pool size info
func get_pool_info(pool_name: String) -> Dictionary:
	if not _pools.has(pool_name):
		return {}
	var pool = _pools[pool_name]
	return {
		"name": pool_name,
		"active": pool["active"].size(),
		"available": pool["available"].size(),
		"total_created": pool["total_created"],
		"min_size": pool["min_size"],
		"max_size": pool["max_size"]
	}


## Get all pool info
func get_all_pool_info() -> Dictionary:
	var result := {}
	for name in _pools:
		result[name] = get_pool_info(name)
	return result


## Get statistics
func get_stats() -> Dictionary:
	return _stats.duplicate()


## Clear a pool (frees all objects)
func clear_pool(pool_name: String) -> void:
	if not _pools.has(pool_name):
		return

	var pool = _pools[pool_name]
	for obj in pool["available"]:
		obj.queue_free()
	for obj in pool["active"]:
		obj.queue_free()
	pool["available"].clear()
	pool["active"].clear()
	pool["total_created"] = 0
	GameLog.info("ObjectPool: Cleared pool '%s'" % pool_name, "Pool")


## Clear all pools
func clear_all() -> void:
	for name in _pools.keys():
		clear_pool(name)


## Unregister a pool
func unregister_pool(pool_name: String) -> void:
	clear_pool(pool_name)
	_pools.erase(pool_name)


func _create_instance(pool_name: String) -> Node:
	var pool = _pools[pool_name]
	var scene: PackedScene = pool["scene"]
	var obj: Node = scene.instantiate()
	obj.process_mode = Node.PROCESS_MODE_DISABLED
	obj.visible = false
	obj.name = "%s_%d" % [pool_name, pool["total_created"]]
	pool["total_created"] += 1
	add_child(obj)
	return obj


func _update_peak(pool: Dictionary) -> void:
	var active_count: int = pool["active"].size()
	if active_count > _stats["peak_active"]:
		_stats["peak_active"] = active_count
