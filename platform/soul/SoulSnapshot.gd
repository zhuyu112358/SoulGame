extends RefCounted
## SoulSnapshot - Standardized soul data format for cross-world migration
##
## This is the platform-level soul data format that allows a soul to be
## transported between different games/worlds on the Sojourn platform.
## A soul created in one game can be loaded into another game via this format.
##
## Key principles:
## - Game-agnostic: contains no game-specific data
## - Versioned: format version allows backward compatibility
## - Serializable: can be saved to JSON, sent over network
## - Secure: signature field for anti-tampering verification
##
## This is PLATFORM code, not game code. RTS battle logic should NOT be here.

## Snapshot format version
const SNAPSHOT_VERSION: String = "1.0.0"

## Soul unique identifier (platform-wide, UUID format)
var soul_id: String = ""

## Soul display name
var soul_name: String = ""

## Soul element type (fire, water, earth, wind, light, dark)
var element: String = ""

## Soul creation timestamp (unix)
var created_at: int = 0

## Soul last modified timestamp (unix)
var modified_at: int = 0

## Soul origin (which game/world created this soul)
var origin_game: String = ""
var origin_world: String = ""

## Soul current location (which game/world currently has this soul)
var current_game: String = ""
var current_world: String = ""

## Core cognitive stats (0-100 scale)
var cognition: Dictionary = {
	"perception": 0,
	"memory": 0,
	"reasoning": 0,
	"decision": 0,
	"learning": 0,
	"creativity": 0
}

## Core emotional stats (0-100 scale)
var emotion: Dictionary = {
	"empathy": 0,
	"expression": 0,
	"attachment": 0,
	"emotional_range": 0,
	"emotional_depth": 0
}

## Soul level and experience
var level: int = 1
var experience: int = 0
var experience_to_next: int = 100

## Soul skills (skill_id -> level)
var skills: Dictionary = {}

## Soul personality traits (trait_id -> value 0-100)
var personality: Dictionary = {}

## Soul memories (platform-level, game-agnostic)
## Each memory: {id, type, content, emotion, importance, timestamp}
var memories: Array = []

## Soul achievements (achievement_id -> unlocked timestamp)
var achievements: Dictionary = {}

## Soul appearance (cosmetic only, resource IDs)
var appearance: Dictionary = {
	"skin_id": "",
	"color_palette": {},
	"accessories": []
}

## Soul relationships (other_soul_id -> relationship_data)
var relationships: Dictionary = {}

## Soul inventory (item_id -> quantity, cosmetic only)
var inventory: Dictionary = {}

## Migration history (list of {game, world, timestamp, action})
var migration_history: Array = []

## Snapshot signature (for anti-tampering, reserved)
var signature: String = ""

## Snapshot metadata
var metadata: Dictionary = {
	"format_version": SNAPSHOT_VERSION,
	"platform_version": "",
	"engine_versions": {}
}


## Create empty snapshot
func _init() -> void:
	created_at = Time.get_unix_time_from_system()
	modified_at = created_at


## Load snapshot data from dictionary
func load_from_dict(p_data: Dictionary) -> void:
	soul_id = p_data.get("id", p_data.get("soul_id", ""))
	soul_name = p_data.get("name", p_data.get("soul_name", ""))
	element = p_data.get("element", "")
	level = p_data.get("level", 1)
	experience = p_data.get("experience", 0)
	experience_to_next = p_data.get("experience_to_next", 100)
	cognition = p_data.get("cognition", cognition.duplicate())
	emotion = p_data.get("emotion", emotion.duplicate())
	skills = p_data.get("skills", {})
	personality = p_data.get("personality", {})
	origin_game = p_data.get("origin_game", "")
	origin_world = p_data.get("origin_world", "")
	current_game = p_data.get("current_game", "")
	current_world = p_data.get("current_world", "")
	appearance = p_data.get("appearance", appearance.duplicate())
	memories = p_data.get("memories", [])
	achievements = p_data.get("achievements", {})
	relationships = p_data.get("relationships", {})
	inventory = p_data.get("inventory", {})
	migration_history = p_data.get("migration_history", [])
	signature = p_data.get("signature", "")
	metadata = p_data.get("metadata", metadata.duplicate())
	created_at = p_data.get("created_at", created_at)
	modified_at = p_data.get("modified_at", modified_at)


## Convert snapshot to dictionary for serialization
func to_dict() -> Dictionary:
	return {
		"soul_id": soul_id,
		"soul_name": soul_name,
		"element": element,
		"level": level,
		"experience": experience,
		"experience_to_next": experience_to_next,
		"cognition": cognition.duplicate(),
		"emotion": emotion.duplicate(),
		"skills": skills.duplicate(),
		"personality": personality.duplicate(),
		"origin_game": origin_game,
		"origin_world": origin_world,
		"current_game": current_game,
		"current_world": current_world,
		"appearance": appearance.duplicate(),
		"memories": memories.duplicate(),
		"achievements": achievements.duplicate(),
		"relationships": relationships.duplicate(),
		"inventory": inventory.duplicate(),
		"migration_history": migration_history.duplicate(),
		"signature": signature,
		"metadata": metadata.duplicate(),
		"created_at": created_at,
		"modified_at": modified_at
	}


## Serialize to JSON string
func to_json() -> String:
	return JSON.stringify(to_dict(), "\t")


## Load from JSON string
func load_from_json(p_json: String) -> bool:
	var parsed = JSON.parse_string(p_json)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		return false
	load_from_dict(parsed)
	return true


## Record a migration event
func record_migration(p_game: String, p_world: String, p_action: String) -> void:
	migration_history.append({
		"game": p_game,
		"world": p_world,
		"action": p_action,
		"timestamp": Time.get_unix_time_from_system()
	})
	current_game = p_game
	current_world = p_world
	modified_at = Time.get_unix_time_from_system()


## Validate snapshot integrity
func validate() -> Dictionary:
	var errors: Array = []
	var warnings: Array = []

	if soul_id == "":
		errors.append("Missing soul_id")
	if soul_name == "":
		warnings.append("Missing soul_name")
	if element == "":
		warnings.append("Missing element")
	if level < 1:
		errors.append("Invalid level: %d" % level)
	if experience < 0:
		errors.append("Negative experience")

	# Check cognition stats range
	for stat in cognition.keys():
		var val = cognition[stat]
		if val < 0 or val > 100:
			errors.append("Cognition stat %s out of range: %d" % [stat, val])

	# Check emotion stats range
	for stat in emotion.keys():
		var val = emotion[stat]
		if val < 0 or val > 100:
			errors.append("Emotion stat %s out of range: %d" % [stat, val])

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"version": SNAPSHOT_VERSION
	}


## Get soul power level (composite score)
func get_power_level() -> int:
	var cog_sum: int = 0
	for val in cognition.values():
		cog_sum += val
	var emo_sum: int = 0
	for val in emotion.values():
		emo_sum += val
	var skill_count: int = skills.size()
	return level * 100 + cog_sum + emo_sum + skill_count * 10


## Get summary for display
func get_summary() -> Dictionary:
	return {
		"id": soul_id,
		"name": soul_name,
		"element": element,
		"level": level,
		"power": get_power_level(),
		"skills": skills.size(),
		"memories": memories.size(),
		"origin": "%s/%s" % [origin_game, origin_world],
		"current": "%s/%s" % [current_game, current_world],
		"migrations": migration_history.size()
	}
