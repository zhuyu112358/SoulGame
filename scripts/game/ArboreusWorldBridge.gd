class_name ArboreusWorldBridge
extends RefCounted
## ArboreusWorldBridge - Adapter for Arboreus SDK World
##
## Encapsulates ArboreusWorld from the Arboreus SDK and provides
## a Battleplan-compatible interface for RTS arena management.
##
## Architecture compliant: world simulation uses Arboreus SDK.
## Battleplan only uses it through this bridge (application layer).
##
## Status: SKELETON - API being explored, full integration in next round.

## Arboreus SDK World instance
var _world: Object = null
var _arboreus_available: bool = false

## World configuration
var _config: Dictionary = {}
var _is_running: bool = false

## Entity tracking (Battleplan-side, for quick lookup)
var _entities: Dictionary = {}  # entity_id -> ArboreusEntity
var _next_entity_id: int = 1


func _init(p_config: Dictionary = {}) -> void:
	_config = p_config
	_initialize_world()


## Initialize Arboreus SDK World
func _initialize_world() -> void:
	if ClassDB.class_exists("ArboreusWorld"):
		var world_factory = ClassDB.instantiate("ArboreusWorld")
		if world_factory != null:
			# create(config: Dictionary) -> ArboreusWorld
			var default_config = {
				"name": "rts_arena",
				"width": 1280,
				"height": 600,
				"cell_size": 32
			}
			var merged_config = default_config.duplicate()
			merged_config.merge(_config)
			_world = world_factory.create(merged_config)
			if _world != null:
				_arboreus_available = true
				print("[ArboreusWorldBridge] ArboreusWorld SDK initialized: %s" % merged_config)
			else:
				_arboreus_available = false
				print("[ArboreusWorldBridge] WARNING: create() returned null")
		else:
			_arboreus_available = false
			print("[ArboreusWorldBridge] WARNING: Failed to instantiate ArboreusWorld factory")
	else:
		_arboreus_available = false
		print("[ArboreusWorldBridge] WARNING: ArboreusWorld class not found")


## Start the world simulation
func start() -> void:
	if _arboreus_available and _world != null:
		_world.start()
		_is_running = true
		print("[ArboreusWorldBridge] World started")


## Stop the world simulation
func stop() -> void:
	if _arboreus_available and _world != null:
		_world.stop()
		_is_running = false
		print("[ArboreusWorldBridge] World stopped")


## Update the world simulation
## delta: time delta in seconds
func update(delta: float) -> void:
	if _arboreus_available and _world != null and _is_running:
		_world.update(delta)


## Create a new entity in the world
## Returns entity ID (int) for Battleplan-side tracking
## Note: ArboreusWorld.create_entity() takes 0 arguments
func create_entity(p_name: String = "entity", p_position: Vector2 = Vector2.ZERO) -> int:
	if not _arboreus_available or _world == null:
		return -1

	var entity = _world.create_entity()
	if entity != null:
		var entity_id = _next_entity_id
		_next_entity_id += 1
		_entities[entity_id] = entity
		# Set entity name if method exists
		if entity.has_method("set_name"):
			entity.set_name(p_name)
		print("[ArboreusWorldBridge] Entity created: id=%d, name=%s" % [entity_id, p_name])
		return entity_id
	else:
		print("[ArboreusWorldBridge] WARNING: create_entity() returned null")
		return -1


## Remove an entity from the world
## Note: ArboreusWorld.remove_entity() returns void
func remove_entity(p_entity_id: int) -> bool:
	if not _arboreus_available or _world == null:
		return false
	if not _entities.has(p_entity_id):
		return false

	var entity = _entities[p_entity_id]
	_world.remove_entity(entity)  # returns void
	_entities.erase(p_entity_id)
	print("[ArboreusWorldBridge] Entity removed: id=%d" % p_entity_id)
	return true


## Get entity by ID
func get_entity(p_entity_id: int) -> Object:
	if _entities.has(p_entity_id):
		return _entities[p_entity_id]
	return null


## Get all entities
func get_all_entities() -> Array:
	return _entities.values()


## Get entity count
func get_entity_count() -> int:
	if _arboreus_available and _world != null:
		return _world.get_entity_count()
	return _entities.size()


## Set entity name
func set_entity_name(p_entity_id: int, p_name: String) -> bool:
	var entity = get_entity(p_entity_id)
	if entity != null and entity.has_method("set_name"):
		entity.set_name(p_name)
		return true
	return false


## Get entity name
func get_entity_name(p_entity_id: int) -> String:
	var entity = get_entity(p_entity_id)
	if entity != null and entity.has_method("get_name"):
		return entity.get_name()
	return ""


## Check if entity has component
func entity_has_component(p_entity_id: int, p_component: String) -> bool:
	var entity = get_entity(p_entity_id)
	if entity != null and entity.has_method("has_component"):
		return entity.has_component(p_component)
	return false


## Remove component from entity
func entity_remove_component(p_entity_id: int, p_component: String) -> bool:
	var entity = get_entity(p_entity_id)
	if entity != null and entity.has_method("remove_component"):
		entity.remove_component(p_component)
		return true
	return false


## Check if entity has tag
func entity_has_tag(p_entity_id: int, p_tag: String) -> bool:
	var entity = get_entity(p_entity_id)
	if entity != null and entity.has_method("has_tag"):
		return entity.has_tag(p_tag)
	return false


## Remove tag from entity
func entity_remove_tag(p_entity_id: int, p_tag: String) -> bool:
	var entity = get_entity(p_entity_id)
	if entity != null and entity.has_method("remove_tag"):
		entity.remove_tag(p_tag)
		return true
	return false


## Get world status
func get_status() -> Dictionary:
	if _arboreus_available and _world != null:
		var status = _world.get_status()
		if status is Dictionary:
			return status
	return {
		"running": _is_running,
		"entities": _entities.size(),
		"arboreus_available": _arboreus_available
	}


## Get subsystem references
func get_grid_map() -> Object:
	if _arboreus_available and _world != null and _world.has_method("get_grid_map"):
		return _world.get_grid_map()
	return null


func get_pathfinder() -> Object:
	if _arboreus_available and _world != null and _world.has_method("get_pathfinder"):
		return _world.get_pathfinder()
	return null


func get_physics_system() -> Object:
	if _arboreus_available and _world != null and _world.has_method("get_physics_system"):
		return _world.get_physics_system()
	return null


func get_movement_system() -> Object:
	if _arboreus_available and _world != null and _world.has_method("get_movement_system"):
		return _world.get_movement_system()
	return null


func get_event_bus() -> Object:
	if _arboreus_available and _world != null and _world.has_method("get_event_bus"):
		return _world.get_event_bus()
	return null


func get_world_clock() -> Object:
	if _arboreus_available and _world != null and _world.has_method("get_world_clock"):
		return _world.get_world_clock()
	return null


## --- Accessors ---

func is_arboreus_available() -> bool:
	return _arboreus_available


func get_world() -> Object:
	return _world


func is_running() -> bool:
	return _is_running
