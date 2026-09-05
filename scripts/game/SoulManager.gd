extends Node
## SoulManager - Manages soul lifecycle: create, view, train, deploy
##
## Handles soul creation, growth data management, training tasks,
## and deployment to game worlds. This is the M1 foundation for
## soul management functionality.
##
## Soul Creation (M1 simple mode):
## - Player inputs a description sentence
## - AI generates soul personality based on description
## - Soul "awakens" with initial stats
## - Player names the soul

## Currently active soul
var active_soul: SoulGrowthData = null

## List of all souls (summaries)
var soul_list: Array = []

## Soul creation state
var creation_state: Dictionary = {
	"in_progress": false,
	"description": "",
	"generated_personality": {},
	"name": ""
}

## Training tasks available
var training_tasks: Array = [
	{"id": "cognitive_basic", "name": "Cognitive Basic Training", "dimension": "cognitive", "exp": 15, "duration": 30},
	{"id": "emotional_basic", "name": "Emotional Connection Practice", "dimension": "emotional", "exp": 12, "duration": 25},
	{"id": "skill_basic", "name": "Basic Skill Practice", "dimension": "skill", "exp": 20, "duration": 40},
	{"id": "memory_review", "name": "Memory Review", "dimension": "cognitive", "exp": 8, "duration": 15},
	{"id": "social_practice", "name": "Social Practice", "dimension": "emotional", "exp": 10, "duration": 20}
]

## Active training task
var active_training: Dictionary = {}

## Training timer
var _training_timer: float = 0.0


func _ready() -> void:
	GameLog.info("SoulManager: Initialized", "SoulManager")
	_load_soul_list()


func _process(delta: float) -> void:
	# Process active training
	if active_training.size() > 0:
		_training_timer += delta
		var duration = active_training.get("duration", 30)
		if _training_timer >= duration:
			_complete_training()


## --- Soul Creation ---

## Start soul creation with a description
func start_creation(description: String) -> void:
	creation_state["in_progress"] = true
	creation_state["description"] = description

	# Generate personality based on description keywords
	creation_state["generated_personality"] = _generate_personality_from_description(description)

	GameLog.info("SoulManager: Creation started - '%s'" % description, "SoulManager")
	EventBus.emit("soul_creation_started", {"description": description})



## Generate personality traits from description keywords
func _generate_personality_from_description(description: String) -> Dictionary:
	var personality: Dictionary = {
		"openness": 50,
		"conscientiousness": 50,
		"extraversion": 50,
		"agreeableness": 50,
		"neuroticism": 50,
		"curiosity": 50,
		"bravery": 50,
		"warmth": 50
	}
	var desc_lower: String = description.to_lower()
	# Keyword-based personality adjustment
	var keyword_map: Dictionary = {
		"brave": {"bravery": 20, "extraversion": 10},
		"coward": {"bravery": -20, "neuroticism": 10},
		"outgoing": {"extraversion": 20, "warmth": 10},
		"shy": {"extraversion": -15, "conscientiousness": 10},
		"curious": {"openness": 15, "curiosity": 15},
		"explorer": {"curiosity": 25, "openness": 10},
		"kind": {"warmth": 20, "agreeableness": 15},
		"cold": {"warmth": -20, "agreeableness": -10},
		"disciplined": {"conscientiousness": 20},
		"creative": {"openness": 10, "extraversion": 10, "conscientiousness": -10},
		"friendly": {"agreeableness": 20, "warmth": 15},
		"anxious": {"openness": 10, "neuroticism": 5},
		"confident": {"bravery": 15, "neuroticism": -10},
		"sensitive": {"neuroticism": 15, "warmth": 10},
		"calm": {"extraversion": 10, "neuroticism": -15},
		"organized": {"conscientiousness": 15, "bravery": -5}
	}
	var kw_keys: Array = keyword_map.keys()
	for kw in kw_keys:
		if desc_lower.find(kw) >= 0:
			var tdict: Dictionary = keyword_map[kw]
			var tkeys: Array = tdict.keys()
			for t in tkeys:
				personality[t] = clamp(personality[t] + tdict[t], 5, 95)
	return personality


## Complete soul creation with a name
func complete_creation(name: String) -> SoulGrowthData:
	if not creation_state["in_progress"]:
		GameLog.error("SoulManager: No creation in progress", "SoulManager")
		return null

	var soul := SoulGrowthData.new()
	soul.soul_id = "soul_%s_%d" % [name.to_lower(), Time.get_unix_time_from_system()]
	soul.soul_name = name
	soul.personality = creation_state["generated_personality"].duplicate()

	# Set initial cognitive/emotional values based on personality
	soul.cognitive["sub_dimensions"]["learning"]["value"] = 10 + int(soul.personality["curiosity"] * 0.2)
	soul.cognitive["sub_dimensions"]["creativity"]["value"] = 10 + int(soul.personality["openness"] * 0.2)
	soul.emotional["sub_dimensions"]["empathy"]["value"] = 10 + int(soul.personality["agreeableness"] * 0.2)
	soul.emotional["sub_dimensions"]["emotion_expression"]["value"] = 10 + int(soul.personality["extraversion"] * 0.2)

	# Initial memories
	soul.add_memory("I was born! Player named me %s." % name, "birth", 5)
	soul.add_memory("My creator described me as: %s" % creation_state["description"], "origin", 4)

	# Reset creation state
	creation_state["in_progress"] = false
	creation_state["description"] = ""
	creation_state["generated_personality"] = {}
	creation_state["name"] = ""

	# Add to soul list
	soul_list.append({"id": soul.soul_id, "name": soul.soul_name, "level": soul.level})

	# Set as active
	active_soul = soul

	# Save
	_save_soul(soul)

	GameLog.info("SoulManager: Soul created - %s (%s)" % [name, soul.soul_id], "SoulManager")
	EventBus.emit("soul_created", {"id": soul.soul_id, "name": name, "personality": soul.personality})

	return soul


## --- Soul Management ---

## Set active soul by ID
func set_active_soul(soul_id: String) -> bool:
	for soul_summary in soul_list:
		if soul_summary["id"] == soul_id:
			active_soul = _load_soul(soul_id)
			if active_soul:
				GameLog.info("SoulManager: Active soul set to %s" % active_soul.soul_name, "SoulManager")
				EventBus.emit("soul_selected", {"id": soul_id, "name": active_soul.soul_name})
				return true
	GameLog.warning("SoulManager: Soul not found: %s" % soul_id, "SoulManager")
	return false


## Get soul details
func get_soul_details(soul_id: String) -> Dictionary:
	var soul = _load_soul(soul_id)
	if soul:
		return soul.get_summary()
	return {}


## Delete a soul
func delete_soul(soul_id: String) -> bool:
	for i in range(soul_list.size()):
		if soul_list[i]["id"] == soul_id:
			soul_list.remove_at(i)
			_save_soul_list()
			if active_soul and active_soul.soul_id == soul_id:
				active_soul = null
			GameLog.info("SoulManager: Soul deleted: %s" % soul_id, "SoulManager")
			EventBus.emit("soul_deleted", {"id": soul_id})
			return true
	return false


## --- Training System ---

## Start a training task
func start_training(task_id: String) -> bool:
	if active_soul == null:
		GameLog.warning("SoulManager: No active soul for training", "SoulManager")
		return false

	for task in training_tasks:
		if task["id"] == task_id:
			active_training = task.duplicate()
			_training_timer = 0.0
			GameLog.info("SoulManager: Training started - %s" % task["name"], "SoulManager")
			EventBus.emit("soul_training_started", {"task": task, "soul_id": active_soul.soul_id})
			return true

	GameLog.warning("SoulManager: Unknown training task: %s" % task_id, "SoulManager")
	return false


## Complete active training
func _complete_training() -> void:
	if active_soul == null or active_training.size() == 0:
		return

	var task = active_training
	var dimension = task["dimension"]
	var exp = task["exp"]

	var result = active_soul.add_dimension_experience(dimension, exp)
	active_soul.add_memory("Completed training: %s (+%d %s exp)" % [task["name"], exp, dimension], "training", 2)

	GameLog.info("SoulManager: Training complete - %s (+%d %s)" % [task["name"], exp, dimension], "SoulManager")
	EventBus.emit("soul_training_complete", {
		"task": task,
		"soul_id": active_soul.soul_id,
		"exp_gained": exp,
		"leveled_up": result["leveled_up"]
	})

	active_training = {}
	_training_timer = 0.0


## Get training progress (0.0 to 1.0)
func get_training_progress() -> float:
	if active_training.size() == 0:
		return 0.0
	var duration = active_training.get("duration", 30)
	return clamp(_training_timer / duration, 0.0, 1.0)


## --- Deployment ---

## Deploy soul to a world
func deploy_soul(soul_id: String, world_id: String, world_name: String) -> bool:
	var soul = _load_soul(soul_id)
	if soul == null:
		GameLog.warning("SoulManager: Cannot deploy, soul not found: %s" % soul_id, "SoulManager")
		return false

	# Call SoulArena API to enter world
	var body := {
		"worldId": world_id,
		"worldName": world_name,
		"communicationMedium": "direct_api"
	}
	SoulArenaClient.enter_world(soul_id, world_id, "", self, "_on_deploy_result")

	GameLog.info("SoulManager: Deploying %s to %s" % [soul.soul_name, world_name], "SoulManager")
	return true


## Callback for deployment result
func _on_deploy_result(status_code: int, response: Dictionary) -> void:
	if status_code == 200:
		GameLog.info("SoulManager: Soul deployed successfully", "SoulManager")
		EventBus.emit("soul_deployed", {"status": "success", "response": response})
	else:
		GameLog.error("SoulManager: Deployment failed: %d" % status_code, "SoulManager")
		ErrorHandler.track_error("SoulManager", "Soul deployment failed", {"status": status_code}, "error")


## --- Persistence ---

## Save soul data
func _save_soul(soul: SoulGrowthData) -> void:
	var key = "soul_%s" % soul.soul_id
	SaveSystem.set_value(key, soul.to_dict())
	_save_soul_list()


## Load soul data
func _load_soul(soul_id: String) -> SoulGrowthData:
	var key = "soul_%s" % soul_id
	var data = SaveSystem.get_value(key, {})
	if data.size() == 0:
		return null
	var soul = SoulGrowthData.new()
	soul.from_dict(data)
	return soul


## Save soul list
func _save_soul_list() -> void:
	SaveSystem.set_value("soul_list", soul_list)


## Load soul list
func _load_soul_list() -> void:
	soul_list = SaveSystem.get_value("soul_list", [])
	GameLog.info("SoulManager: Loaded %d souls" % soul_list.size(), "SoulManager")


## Get all souls summary
func get_all_souls() -> Array:
	return soul_list.duplicate()


## Get stats
func get_stats() -> Dictionary:
	return {
		"total_souls": soul_list.size(),
		"active_soul": active_soul.soul_name if active_soul else "none",
		"training_active": active_training.size() > 0,
		"training_progress": get_training_progress(),
		"creation_in_progress": creation_state["in_progress"]
	}
