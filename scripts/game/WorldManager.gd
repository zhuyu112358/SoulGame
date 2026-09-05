extends Node
## WorldManager - Manages game worlds: create, configure, run
##
## Handles world creation, configuration, simulation control,
## and world state management. M1 provides basic world management
## with template-based creation.

## List of all worlds
var world_list: Array = []

## Currently active/running world
var active_world: Dictionary = {}

## World templates
var world_templates: Array = [
	{
		"id": "training_arena",
		"name": "璁粌绔炴妧鍦?,
		"description": "鍩虹璁粌鍦哄湴锛岄€傚悎鎶€鑳界粌涔?,
		"size": "medium",
		"resource_points": 3,
		"growth_rules": {"skill_rate": 1.2, "cognitive_rate": 1.0},
		"difficulty": 1
	},
	{
		"id": "exploration_forest",
		"name": "鎺㈢储妫灄",
		"description": "鍏呮弧鏈煡鐨勬．鏋楋紝閫傚悎鎺㈢储鍜岃鐭ユ垚闀?,
		"size": "large",
		"resource_points": 5,
		"growth_rules": {"cognitive_rate": 1.3, "emotional_rate": 1.1},
		"difficulty": 2
	},
	{
		"id": "social_plaza",
		"name": "绀句氦骞垮満",
		"description": "鐏甸瓊鑱氶泦鐨勫箍鍦猴紝閫傚悎绀句氦鍜屾儏鎰熸垚闀?,
		"size": "medium",
		"resource_points": 4,
		"growth_rules": {"emotional_rate": 1.4, "skill_rate": 0.9},
		"difficulty": 1
	},
	{
		"id": "challenge_maze",
		"name": "鎸戞垬杩峰",
		"description": "澶嶆潅鐨勮糠瀹紝鑰冮獙闂瑙ｅ喅鍜岀┖闂磋鐭?,
		"size": "large",
		"resource_points": 6,
		"growth_rules": {"cognitive_rate": 1.5, "skill_rate": 1.2},
		"difficulty": 3
	}
]

## World creation state
var creation_state: Dictionary = {
	"in_progress": false,
	"template_id": "",
	"custom_config": {}
}

## World simulation state
var simulation_state: Dictionary = {
	"running": false,
	"tick_count": 0,
	"start_time": 0.0,
	"elapsed_time": 0.0
}


func _ready() -> void:
	GameLog.info("WorldManager: Initialized", "WorldManager")
	_load_world_list()


func _process(delta: float) -> void:
	if simulation_state["running"]:
		simulation_state["elapsed_time"] += delta
		# Tick every 1 second (game time, not real time)
		if simulation_state["elapsed_time"] - simulation_state["last_tick_time"] >= 1.0:
			simulation_state["last_tick_time"] = simulation_state["elapsed_time"]
			simulation_state["tick_count"] += 1
			_on_world_tick()


## --- World Creation ---

## Start world creation from template
func start_creation(template_id: String) -> bool:
	for template in world_templates:
		if template["id"] == template_id:
			creation_state["in_progress"] = true
			creation_state["template_id"] = template_id
			creation_state["custom_config"] = template.duplicate(true)
			GameLog.info("WorldManager: Creation started from template: %s" % template["name"], "WorldManager")
			return true
	GameLog.warning("WorldManager: Unknown template: %s" % template_id, "WorldManager")
	return false


## Configure world parameters
func configure_world(config_key: String, value) -> bool:
	if not creation_state["in_progress"]:
		GameLog.warning("WorldManager: No creation in progress", "WorldManager")
		return false
	creation_state["custom_config"][config_key] = value
	return true


## Complete world creation
func complete_creation(world_name: String) -> Dictionary:
	if not creation_state["in_progress"]:
		GameLog.error("WorldManager: No creation in progress", "WorldManager")
		return {}

	var world := {
		"id": "world_%s_%d" % [world_name.to_lower().replace(" ", "_"), Time.get_unix_time_from_system()],
		"name": world_name,
		"template": creation_state["template_id"],
		"config": creation_state["custom_config"].duplicate(true),
		"created_at": Time.get_datetime_string_from_system(),
		"status": "created",
		"souls_deployed": [],
		"stats": {
			"total_ticks": 0,
			"total_runtime": 0.0,
			"events": 0
		}
	}

	world_list.append({"id": world["id"], "name": world["name"], "status": world["status"]})

	# Reset creation state
	creation_state["in_progress"] = false
	creation_state["template_id"] = ""
	creation_state["custom_config"] = {}

	# Save
	_save_world(world)
	_save_world_list()

	GameLog.info("WorldManager: World created - %s (%s)" % [world_name, world["id"]], "WorldManager")
	EventBus.emit("world_created", {"id": world["id"], "name": world_name, "template": world["template"]})

	return world


## --- World Management ---

## Get world details
func get_world_details(world_id: String) -> Dictionary:
	return _load_world(world_id)


## Delete a world
func delete_world(world_id: String) -> bool:
	for i in range(world_list.size()):
		if world_list[i]["id"] == world_id:
			world_list.remove_at(i)
			_save_world_list()
			if active_world.get("id", "") == world_id:
				stop_simulation()
				active_world = {}
			GameLog.info("WorldManager: World deleted: %s" % world_id, "WorldManager")
			EventBus.emit("world_deleted", {"id": world_id})
			return true
	return false


## Get all worlds
func get_all_worlds() -> Array:
	return world_list.duplicate()


## Get available templates
func get_templates() -> Array:
	return world_templates.duplicate(true)


## --- Simulation Control ---

## Start world simulation
func start_simulation(world_id: String) -> bool:
	var world = _load_world(world_id)
	if world.size() == 0:
		GameLog.warning("WorldManager: Cannot start, world not found: %s" % world_id, "WorldManager")
		return false

	active_world = world
	simulation_state["running"] = true
	simulation_state["tick_count"] = 0
	simulation_state["start_time"] = Time.get_ticks_msec() / 1000.0
	simulation_state["elapsed_time"] = 0.0
	simulation_state["last_tick_time"] = 0.0

	active_world["status"] = "running"
	_save_world(active_world)

	GameLog.info("WorldManager: Simulation started - %s" % world["name"], "WorldManager")
	EventBus.emit("world_simulation_started", {"id": world_id, "name": world["name"]})
	return true


## Stop world simulation
func stop_simulation() -> void:
	if not simulation_state["running"]:
		return

	simulation_state["running"] = false

	if active_world.size() > 0:
		active_world["status"] = "stopped"
		active_world["stats"]["total_ticks"] += simulation_state["tick_count"]
		active_world["stats"]["total_runtime"] += simulation_state["elapsed_time"]
		_save_world(active_world)
		GameLog.info("WorldManager: Simulation stopped - %s (ticks: %d)" % [active_world["name"], simulation_state["tick_count"]], "WorldManager")
		EventBus.emit("world_simulation_stopped", {"id": active_world["id"], "ticks": simulation_state["tick_count"]})


## World tick handler
func _on_world_tick() -> void:
	# Process world events, soul growth, etc.
	if active_world.size() > 0:
		EventBus.emit("world_tick", {
			"world_id": active_world["id"],
			"tick": simulation_state["tick_count"],
			"elapsed": simulation_state["elapsed_time"]
		})


## --- Soul Deployment to World ---

## Deploy soul to active world
func deploy_soul_to_world(soul_id: String, world_id: String) -> bool:
	var world = _load_world(world_id)
	if world.size() == 0:
		GameLog.warning("WorldManager: World not found: %s" % world_id, "WorldManager")
		return false

	if not world["souls_deployed"].has(soul_id):
		world["souls_deployed"].append(soul_id)
		_save_world(world)
		GameLog.info("WorldManager: Soul %s deployed to world %s" % [soul_id, world_id], "WorldManager")
		EventBus.emit("world_soul_deployed", {"soul_id": soul_id, "world_id": world_id})
		return true
	return false


## Remove soul from world
func remove_soul_from_world(soul_id: String, world_id: String) -> bool:
	var world = _load_world(world_id)
	if world.size() == 0:
		return false

	if world["souls_deployed"].has(soul_id):
		world["souls_deployed"].erase(soul_id)
		_save_world(world)
		GameLog.info("WorldManager: Soul %s removed from world %s" % [soul_id, world_id], "WorldManager")
		return true
	return false


## --- Persistence ---

func _save_world(world: Dictionary) -> void:
	var key = "world_%s" % world["id"]
	SaveSystem.set_value(key, world)


func _load_world(world_id: String) -> Dictionary:
	var key = "world_%s" % world_id
	return SaveSystem.get_value(key, {})


func _save_world_list() -> void:
	SaveSystem.set_value("world_list", world_list)


func _load_world_list() -> void:
	world_list = SaveSystem.get_value("world_list", [])
	GameLog.info("WorldManager: Loaded %d worlds" % world_list.size(), "WorldManager")


## Get stats
func get_stats() -> Dictionary:
	return {
		"total_worlds": world_list.size(),
		"active_world": active_world.get("name", "none"),
		"simulation_running": simulation_state["running"],
		"simulation_ticks": simulation_state["tick_count"],
		"simulation_elapsed": simulation_state["elapsed_time"],
		"templates_available": world_templates.size()
	}
