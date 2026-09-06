extends Node
## PlatformSDK - Platform-level SDK abstraction for soul operations
##
## This is the unified interface for games on the Sojourn platform to interact
## with soul data. Games should NOT directly access Ember/Arboreus engines.
## Instead, they call PlatformSDK methods, which handle engine communication,
## caching, and cross-world migration.
##
## Key principles:
## - Game-agnostic: works for any game on the platform
## - Engine-agnostic: can switch underlying engines without game code changes
## - Caching: soul data cached locally, synced with platform
## - Migration: souls can move between games via SoulSnapshot
##
## This is PLATFORM code. RTS game calls this to get soul data for battle.

# Preload SoulSnapshot script (class_name not used to avoid cross-dir resolution issues)
const SoulSnapshotClass = preload("res://platform/soul/SoulSnapshot.gd")

## Soul cache (soul_id -> SoulSnapshot instance)
var _soul_cache: Dictionary = {}

## Active soul ID
var _active_soul_id: String = ""

## Platform API base URL
var _api_base_url: String = "http://localhost:3000/api"

## Whether using mock mode (M2 prototype)
var _mock_mode: bool = true

## HTTP client for API calls
var _http_client: HTTPClient = HTTPClient.new()

## Pending API requests
var _pending_requests: Array = []


func _ready() -> void:
	GameLog.info("PlatformSDK: Initialized (mock_mode=%s)" % str(_mock_mode), "Platform")


## Set mock mode (M2 prototype uses mock, production uses real API)
func set_mock_mode(p_enabled: bool) -> void:
	_mock_mode = p_enabled
	GameLog.info("PlatformSDK: Mock mode set to %s" % str(p_enabled), "Platform")


## Create a new soul on the platform
## Returns SoulSnapshot on success, null on failure
func create_soul(p_name: String, p_element: String, p_personality: Dictionary = {}):
	if _mock_mode:
		return _mock_create_soul(p_name, p_element, p_personality)

	# Real API call (future)
	var result = _api_call("POST", "/souls", {
		"name": p_name,
		"element": p_element,
		"personality": p_personality
	})
	if result.get("success", false):
		var snapshot = SoulSnapshotClass.new()
		snapshot.load_from_dict(result["data"])
		_soul_cache[snapshot.soul_id] = snapshot
		return snapshot
	return null


## Get a soul by ID (from cache or API)
func get_soul(p_soul_id: String):
	# Check cache first
	if _soul_cache.has(p_soul_id):
		return _soul_cache[p_soul_id]

	if _mock_mode:
		return _mock_get_soul(p_soul_id)

	# Real API call (future)
	var result = _api_call("GET", "/souls/%s" % p_soul_id, {})
	if result.get("success", false):
		var snapshot = SoulSnapshotClass.new()
		snapshot.load_from_dict(result["data"])
		_soul_cache[p_soul_id] = snapshot
		return snapshot
	return null


## Save soul data to platform
func save_soul(p_snapshot) -> bool:
	if p_snapshot == null:
		return false

	p_snapshot.modified_at = Time.get_unix_time_from_system()
	_soul_cache[p_snapshot.soul_id] = p_snapshot

	if _mock_mode:
		return true  # Mock: just cache

	# Real API call (future)
	var result = _api_call("PUT", "/souls/%s" % p_snapshot.soul_id, p_snapshot.to_dict())
	return result.get("success", false)


## Delete a soul from platform
func delete_soul(p_soul_id: String) -> bool:
	_soul_cache.erase(p_soul_id)
	if _active_soul_id == p_soul_id:
		_active_soul_id = ""

	if _mock_mode:
		return true

	var result = _api_call("DELETE", "/souls/%s" % p_soul_id, {})
	return result.get("success", false)


## Set active soul (current soul being used)
func set_active_soul(p_soul_id: String) -> bool:
	if not _soul_cache.has(p_soul_id):
		var soul = get_soul(p_soul_id)
		if soul == null:
			return false
	_active_soul_id = p_soul_id
	GameLog.info("PlatformSDK: Active soul set to '%s'" % p_soul_id, "Platform")
	return true


## Get active soul
func get_active_soul():
	if _active_soul_id == "":
		return null
	return get_soul(_active_soul_id)


## Get all souls (list of summaries)
func list_souls() -> Array:
	if _mock_mode:
		var summaries: Array = []
		for soul_id in _soul_cache.keys():
			summaries.append(_soul_cache[soul_id].get_summary())
		return summaries

	var result = _api_call("GET", "/souls", {})
	return result.get("data", [])


## Migrate soul to another game/world
## Returns updated SoulSnapshot
func migrate_soul(p_soul_id: String, p_target_game: String, p_target_world: String):
	var soul = get_soul(p_soul_id)
	if soul == null:
		return null

	soul.record_migration(p_target_game, p_target_world, "migrate")
	save_soul(soul)

	GameLog.info("PlatformSDK: Soul '%s' migrated to %s/%s" % [
		p_soul_id, p_target_game, p_target_world
	], "Platform")
	return soul


## Update soul stats (cognition/emotion/skills)
## This is the main interface for games to modify soul growth
func update_soul_stats(p_soul_id: String, p_updates: Dictionary):
	var soul = get_soul(p_soul_id)
	if soul == null:
		return null

	# Apply cognition updates
	if p_updates.has("cognition"):
		for stat in p_updates["cognition"].keys():
			if soul.cognition.has(stat):
				soul.cognition[stat] = clampi(
					soul.cognition[stat] + p_updates["cognition"][stat], 0, 100
				)

	# Apply emotion updates
	if p_updates.has("emotion"):
		for stat in p_updates["emotion"].keys():
			if soul.emotion.has(stat):
				soul.emotion[stat] = clampi(
					soul.emotion[stat] + p_updates["emotion"][stat], 0, 100
				)

	# Apply experience
	if p_updates.has("experience"):
		soul.experience += p_updates["experience"]
		_check_level_up(soul)

	save_soul(soul)
	return soul


## Add skill to soul
func add_skill(p_soul_id: String, p_skill_id: String, p_level: int = 1) -> bool:
	var soul = get_soul(p_soul_id)
	if soul == null:
		return false
	soul.skills[p_skill_id] = p_level
	save_soul(soul)
	return true


## Add memory to soul
func add_memory(p_soul_id: String, p_memory: Dictionary) -> bool:
	var soul = get_soul(p_soul_id)
	if soul == null:
		return false
	p_memory["id"] = "mem_%d" % Time.get_unix_time_from_system()
	p_memory["timestamp"] = Time.get_unix_time_from_system()
	soul.memories.append(p_memory)
	save_soul(soul)
	return true


## Check and handle level up
func _check_level_up(p_soul) -> void:
	while p_soul.experience >= p_soul.experience_to_next:
		p_soul.experience -= p_soul.experience_to_next
		p_soul.level += 1
		p_soul.experience_to_next = int(p_soul.experience_to_next * 1.5)
		GameLog.info("PlatformSDK: Soul '%s' leveled up to %d" % [
			p_soul.soul_name, p_soul.level
		], "Platform")


## === Mock implementations (M2 prototype) ===

func _mock_create_soul(p_name: String, p_element: String, p_personality: Dictionary):
	var soul = SoulSnapshotClass.new()
	soul.soul_id = "soul_%d" % Time.get_unix_time_from_system()
	soul.soul_name = p_name
	soul.element = p_element
	soul.personality = p_personality.duplicate()
	soul.origin_game = "rts_arena"
	soul.origin_world = "default"
	soul.current_game = "rts_arena"
	soul.current_world = "default"
	# Initialize base stats
	soul.cognition = {"perception": 10, "memory": 10, "reasoning": 10, "decision": 10, "learning": 10, "creativity": 10}
	soul.emotion = {"empathy": 10, "expression": 10, "attachment": 10, "emotional_range": 10, "emotional_depth": 10}
	_soul_cache[soul.soul_id] = soul
	GameLog.info("PlatformSDK: Mock created soul '%s'" % p_name, "Platform")
	return soul


func _mock_get_soul(p_soul_id: String):
	# In mock mode, create a default soul if not found
	if not _soul_cache.has(p_soul_id):
		var soul = _mock_create_soul(p_soul_id, "fire", {})
		soul.soul_id = p_soul_id
		_soul_cache[p_soul_id] = soul
	return _soul_cache[p_soul_id]


## === API call (future implementation) ===

func _api_call(p_method: String, p_endpoint: String, p_data: Dictionary) -> Dictionary:
	# Real API implementation goes here
	# M2 prototype uses mock mode, so this is not called
	return {"success": false, "error": "API not implemented in mock mode"}


## Get SDK info
func get_info() -> Dictionary:
	return {
		"mock_mode": _mock_mode,
		"api_base_url": _api_base_url,
		"cached_souls": _soul_cache.size(),
		"active_soul": _active_soul_id,
		"sdk_version": "1.0.0"
	}
