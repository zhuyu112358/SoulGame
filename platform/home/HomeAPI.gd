extends Node
## HomeAPI - Platform-level soul home interface
##
## The soul home is a PLATFORM feature, not a game feature. This API provides
## access to the soul home from any game on the Sojourn platform.
##
## Games should NOT implement their own soul home. They should call this API
## to access home functionality (visit home, interact with soul, etc.).
##
## This is PLATFORM code. The RTS game can call this to let players visit
## their soul's home between battles.

## Home state cache
var _home_state: Dictionary = {}

## Whether home is currently loaded
var _home_loaded: bool = false

## Active soul in home
var _home_soul_id: String = ""

## Home interaction cooldown
var _interaction_cooldown: float = 0.0


func _ready() -> void:
	GameLog.info("HomeAPI: Initialized", "Platform")


## Load soul home for a soul
func load_home(p_soul_id: String) -> Dictionary:
	if _home_loaded and _home_soul_id == p_soul_id:
		return {"success": true, "already_loaded": true}

	_home_soul_id = p_soul_id
	_home_loaded = true
	_home_state = {
		"soul_id": p_soul_id,
		"room_theme": "default",
		"decorations": [],
		"ambiance": "calm",
		"last_visit": Time.get_unix_time_from_system()
	}

	GameLog.info("HomeAPI: Loaded home for soul '%s'" % p_soul_id, "Platform")
	return {"success": true, "home": _home_state.duplicate()}


## Unload home
func unload_home() -> void:
	_home_loaded = false
	_home_soul_id = ""
	_home_state = {}
	GameLog.info("HomeAPI: Home unloaded", "Platform")


## Interact with soul in home
## Interaction types: "chat", "pet", "feed", "play", "train", "gift"
func interact(p_interaction_type: String, p_params: Dictionary = {}) -> Dictionary:
	if not _home_loaded:
		return {"success": false, "error": "Home not loaded"}

	if _interaction_cooldown > 0:
		return {"success": false, "error": "Interaction on cooldown", "cooldown": _interaction_cooldown}

	var result: Dictionary = {
		"success": true,
		"type": p_interaction_type,
		"soul_id": _home_soul_id,
		"timestamp": Time.get_unix_time_from_system()
	}

	# Apply interaction effects (platform-level, game-agnostic)
	match p_interaction_type:
		"chat":
			result["mood_change"] = 5
			result["attachment_change"] = 2
			result["response"] = _generate_chat_response()
		"pet":
			result["mood_change"] = 8
			result["attachment_change"] = 3
		"feed":
			result["energy_change"] = 15
			result["mood_change"] = 3
		"play":
			result["mood_change"] = 10
			result["energy_change"] = -5
			result["experience_change"] = 5
		"train":
			result["experience_change"] = 15
			result["energy_change"] = -10
			result["cognition_change"] = {"learning": 2}
		"gift":
			result["mood_change"] = 12
			result["attachment_change"] = 5
		_:
			result["success"] = false
			result["error"] = "Unknown interaction type: %s" % p_interaction_type

	_interaction_cooldown = 1.0  # 1 second cooldown
	return result


## Generate a chat response (mock)
func _generate_chat_response() -> String:
	var responses: Array = [
		"Hello! I'm happy to see you.",
		"I've been thinking about our adventures.",
		"Want to train together today?",
		"I feel stronger when you're around.",
		"Let's go on a new journey!"
	]
	return responses[randi() % responses.size()]


## Get home state
func get_home_state() -> Dictionary:
	return _home_state.duplicate()


## Get soul's mood in home
func get_soul_mood() -> String:
	if not _home_loaded:
		return "unknown"
	var moods: Array = ["happy", "calm", "excited", "sleepy", "curious"]
	return moods[randi() % moods.size()]


## Update home decorations
func set_decoration(p_slot: String, p_item_id: String) -> bool:
	if not _home_loaded:
		return false
	_home_state["decorations"].append({"slot": p_slot, "item": p_item_id})
	return true


## Change home theme
func set_room_theme(p_theme: String) -> bool:
	if not _home_loaded:
		return false
	_home_state["room_theme"] = p_theme
	return true


## Process cooldowns
func _process(delta: float) -> void:
	if _interaction_cooldown > 0:
		_interaction_cooldown = max(0.0, _interaction_cooldown - delta)


## Get API info
func get_info() -> Dictionary:
	return {
		"home_loaded": _home_loaded,
		"active_soul": _home_soul_id,
		"interaction_cooldown": _interaction_cooldown,
		"api_version": "1.0.0"
	}
