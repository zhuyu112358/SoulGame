extends RefCounted
## EmberSoulDataBridge - Bridge between Ember SDK soul data and Battleplan SoulUnit
##
## Encapsulates Ember SoulData + Personality + EmotionState and provides
## a Battleplan-compatible interface (Dictionary-based personality/emotion).
##
## Architecture: Soul data is Ember's responsibility. This bridge adapts
## Ember's object model to Battleplan's expected Dictionary interface.
##
## Usage:
##   var bridge = EmberSoulDataBridge.new()
##   bridge.init_from_soul_data(soul_id, name, level, personality_dict)
##   bridge.personality["aggression"]  # -> reads from Ember Personality
##   bridge.emotion["anger"] = 0.5     # -> writes to Ember EmotionState

## Ember SDK instances
var _soul_data: Object = null
var _personality: Object = null
var _emotion_state: Object = null
var _ember_available: bool = false

## Battleplan-compatible personality Dictionary (synced with Ember Personality)
var personality: Dictionary = {}

## Battleplan-compatible emotion Dictionary (synced with Ember EmotionState)
var emotion: Dictionary = {}

## Soul identity
var soul_id: String = ""
var soul_name: String = ""
var level: int = 1
var element: String = "neutral"


func _init() -> void:
	_initialize_ember()


## Initialize Ember SDK instances
func _initialize_ember() -> void:
	if ClassDB.class_exists("SoulData"):
		_soul_data = ClassDB.instantiate("SoulData")
	if ClassDB.class_exists("Personality"):
		_personality = ClassDB.instantiate("Personality")
	if ClassDB.class_exists("EmotionState"):
		_emotion_state = ClassDB.instantiate("EmotionState")
	_ember_available = (_soul_data != null and _personality != null and _emotion_state != null)


## Initialize from soul data (called by SoulUnit.init_from_soul)
func init_from_soul_data(p_soul_id: String, p_name: String, p_level: int, p_element: String, p_personality: Dictionary) -> void:
	soul_id = p_soul_id
	soul_name = p_name
	level = p_level
	element = p_element

	# Set Ember SoulData
	if _ember_available:
		_soul_data.set_id(p_soul_id)
		_soul_data.set_name(p_name)
		_soul_data.set_level(p_level)
		# Set stats from level (basic scaling)
		var stats = _soul_data.get_stats()
		stats["health"] = 100.0 + p_level * 20.0
		stats["max_health"] = stats["health"]
		stats["attack"] = 10.0 + p_level * 3.0
		stats["defense"] = 5.0 + p_level * 1.0
		stats["speed"] = 5.0 + p_level * 0.5
		_soul_data.set_stats(stats)

		# Set Ember Personality from Battleplan dictionary
		_sync_personality_to_ember(p_personality)

	# Initialize Battleplan-compatible dictionaries
	personality = p_personality.duplicate()
	_init_emotion_dict()


## Initialize emotion dictionary with defaults
func _init_emotion_dict() -> void:
	emotion = {
		"anger": 0.0,
		"fear": 0.0,
		"excitement": 0.0,
		"sadness": 0.0,
		"joy": 0.0,
		"mood": "calm",
		"intensity": 0.0
	}


## Sync Battleplan personality dict to Ember Personality object
func _sync_personality_to_ember(p_personality: Dictionary) -> void:
	if not _ember_available:
		return
	# Map Battleplan personality traits to Ember Personality properties
	var trait_map = {
		"aggression": "aggression",
		"curiosity": "curiosity",
		"loyalty": "loyalty",
		"courage": "courage",
		"patience": "conscientiousness",
		"intelligence": "openness"
	}
	for bp_trait in trait_map.keys():
		if p_personality.has(bp_trait):
			var ember_prop = trait_map[bp_trait]
			var value = float(p_personality[bp_trait]) / 100.0  # Battleplan uses 0-100, Ember uses 0-1
			_personality.set(ember_prop, clamp(value, 0.0, 1.0))


## Sync Ember Personality to Battleplan dict
func _sync_personality_from_ember() -> void:
	if not _ember_available:
		return
	var trait_map = {
		"aggression": "aggression",
		"curiosity": "curiosity",
		"loyalty": "loyalty",
		"courage": "courage",
		"patience": "conscientiousness",
		"intelligence": "openness"
	}
	for bp_trait in trait_map.keys():
		var ember_prop = trait_map[bp_trait]
		var value = _personality.get(ember_prop)
		if value != null:
			personality[bp_trait] = int(value * 100.0)  # Ember 0-1 -> Battleplan 0-100


## Update emotion and sync to Ember
func update_emotion(p_event: String, p_value: float = 0.1) -> void:
	match p_event:
		"took_damage":
			emotion["fear"] = clamp(emotion["fear"] + p_value * 0.5, 0.0, 1.0)
			emotion["anger"] = clamp(emotion["anger"] + p_value * 0.3, 0.0, 1.0)
		"dealt_damage":
			emotion["excitement"] = clamp(emotion["excitement"] + p_value * 0.4, 0.0, 1.0)
			emotion["anger"] = clamp(emotion["anger"] - p_value * 0.1, 0.0, 1.0)
		"ally_died":
			emotion["fear"] = clamp(emotion["fear"] + p_value * 0.8, 0.0, 1.0)
			emotion["anger"] = clamp(emotion["anger"] + p_value * 0.6, 0.0, 1.0)
		"enemy_died":
			emotion["excitement"] = clamp(emotion["excitement"] + p_value * 0.6, 0.0, 1.0)
			emotion["fear"] = clamp(emotion["fear"] - p_value * 0.3, 0.0, 1.0)
		"low_hp":
			emotion["fear"] = clamp(emotion["fear"] + p_value * 0.3, 0.0, 1.0)

	# Decay
	emotion["anger"] = clamp(emotion["anger"] - 0.005, 0.0, 1.0)
	emotion["fear"] = clamp(emotion["fear"] - 0.005, 0.0, 1.0)
	emotion["excitement"] = clamp(emotion["excitement"] - 0.003, 0.0, 1.0)

	# Determine mood
	if emotion["anger"] > 0.5:
		emotion["mood"] = "anger"
	elif emotion["fear"] > 0.5:
		emotion["mood"] = "fear"
	elif emotion["excitement"] > 0.5:
		emotion["mood"] = "excited"
	else:
		emotion["mood"] = "calm"
	emotion["intensity"] = max(emotion["anger"], emotion["fear"], emotion["excitement"])

	# Sync to Ember EmotionState
	if _ember_available:
		_emotion_state.set("anger", emotion["anger"])
		_emotion_state.set("fear", emotion["fear"])
		_emotion_state.set("joy", emotion["excitement"])
		_emotion_state.set("sadness", emotion.get("sadness", 0.0))


## Get emotion-based damage modifier (anger +20% attack)
func get_damage_modifier() -> float:
	if emotion["mood"] == "anger":
		return 1.0 + emotion["intensity"] * 0.2
	return 1.0


## Get emotion-based defense modifier (fear +20% defense)
func get_defense_modifier() -> float:
	if emotion["mood"] == "fear":
		return 1.0 + emotion["intensity"] * 0.2
	return 1.0


## Get Ember SoulData object (for direct SDK access)
func get_soul_data() -> Object:
	return _soul_data


## Get Ember Personality object
func get_personality_obj() -> Object:
	return _personality


## Get Ember EmotionState object
func get_emotion_state() -> Object:
	return _emotion_state


## Check if Ember SDK is available
func is_ember_available() -> bool:
	return _ember_available


## Get soul info dictionary
func get_info() -> Dictionary:
	return {
		"id": soul_id,
		"name": soul_name,
		"level": level,
		"element": element,
		"personality": personality,
		"emotion": emotion,
		"ember_available": _ember_available
	}
