class_name SoulGrowthData
extends Resource
## SoulGrowthData - Data model for soul growth across 5 dimensions
##
## Manages experience, levels, and progression for cognitive, emotional,
## skill, personality, and memory growth dimensions. This is the core
## data model for the soul growth system in v1.1.
##
## Growth Principles (from v1.1 design):
## - Growth is visible and perceptible (every interaction gives feedback)
## - Growth is unique and non-replicable (personality + experience shape it)
## - Growth is continuous (offline simulation, cross-mode data sync)
## - Growth is co-created (player guides, soul has own will)
## - Growth is joyful (no time pressure, no comparison anxiety)

## Soul identifier
var soul_id: String = ""

## Soul name
var soul_name: String = ""

## Overall level (1-100+, no max cap)
var level: int = 1

## Overall experience points
var experience: int = 0

## Experience needed for next level (scales with level)
var experience_to_next: int = 100

## Total playtime in seconds
var total_playtime: float = 0.0

## Creation timestamp
var created_at: String = ""

## Last saved timestamp
var last_saved: String = ""

## --- Cognitive Dimension ---
## 8 sub-dimensions based on SoulArena cognitive subsystem
var cognitive: Dictionary = {
	"level": 1,
	"experience": 0,
	"sub_dimensions": {
		"learning": {"value": 10, "experience": 0},
		"reasoning": {"value": 10, "experience": 0},
		"memory": {"value": 10, "experience": 0},
		"attention": {"value": 10, "experience": 0},
		"language": {"value": 10, "experience": 0},
		"spatial": {"value": 10, "experience": 0},
		"creativity": {"value": 10, "experience": 0},
		"problem_solving": {"value": 10, "experience": 0}
	}
}

## --- Emotional Dimension ---
var emotional: Dictionary = {
	"level": 1,
	"experience": 0,
	"sub_dimensions": {
		"emotion_perception": {"value": 10, "experience": 0},
		"empathy": {"value": 10, "experience": 0},
		"emotion_stability": {"value": 10, "experience": 0},
		"emotion_expression": {"value": 10, "experience": 0},
		"attachment": {"value": 5, "experience": 0},
		"emotional_depth": {"value": 5, "experience": 0}
	},
	"current_mood": "neutral",
	"energy": 100
}

## --- Skill Dimension ---
var skills: Dictionary = {
	"unlocked": [],
	"in_progress": {},
	"experience": 0,
	"level": 1
}

## --- Personality Dimension ---
## 8 dimensions (0-100), based on Big Five + additional traits
var personality: Dictionary = {
	"openness": 50,        # Curiosity, creativity, preference for novelty
	"conscientiousness": 50, # Organization, discipline, goal-oriented
	"extraversion": 50,    # Sociability, assertiveness, energy
	"agreeableness": 50,   # Compassion, cooperation, trust
	"neuroticism": 50,     # Emotional sensitivity, anxiety, moodiness
	"curiosity": 50,       # Desire to learn and explore
	"bravery": 50,         # Courage in face of challenges
	"warmth": 50           # Friendliness, affection, kindness
}

## --- Memory Dimension ---
var memories: Array = []

## Milestones achieved
var milestones: Array = []

## Growth history (for timeline view)
var growth_history: Array = []

## --- Experience Rate Multipliers ---
var multipliers: Dictionary = {
	"cognitive": 1.0,
	"emotional": 1.0,
	"skill": 1.0,
	"diminishing_return_threshold": 1800,  # 30 minutes before diminishing returns
	"diminishing_return_factor": 0.5
}

## Current session start time (for diminishing returns calculation)
var session_start_time: float = 0.0

## Session interaction time in seconds
var session_interaction_time: float = 0.0


## Initialize new soul growth data
func _init() -> void:
	created_at = Time.get_datetime_string_from_system()
	session_start_time = Time.get_ticks_msec() / 1000.0
	experience_to_next = _calc_exp_to_next(level)


## --- Experience and Level System ---

## Add experience to overall level
## Returns true if leveled up
func add_experience(amount: int) -> bool:
	experience += amount
	var leveled_up := false

	while experience >= experience_to_next:
		experience -= experience_to_next
		level += 1
		experience_to_next = _calc_exp_to_next(level)
		leveled_up = true
		_on_level_up()

	if leveled_up:
		GameLog.info("SoulGrowth: %s leveled up to Lv.%d" % [soul_name, level], "Growth")
		EventBus.emit("soul_level_up", {"soul_id": soul_id, "level": level})

	return leveled_up


## Add experience to a specific dimension
## dimension: "cognitive", "emotional", "skill"
## sub_dim: optional specific sub-dimension name
func add_dimension_experience(dimension: String, amount: int, sub_dim: String = "") -> Dictionary:
	var result := {"leveled_up": false, "new_level": 0, "dimension": dimension}

	# Apply diminishing returns for long sessions
	var effective_amount := _apply_diminishing_returns(amount)

	match dimension:
		"cognitive":
			cognitive["experience"] += effective_amount
			if sub_dim != "" and cognitive["sub_dimensions"].has(sub_dim):
				cognitive["sub_dimensions"][sub_dim]["experience"] += effective_amount
			if _check_dimension_level_up(cognitive):
				result["leveled_up"] = true
				result["new_level"] = cognitive["level"]
		"emotional":
			emotional["experience"] += effective_amount
			if sub_dim != "" and emotional["sub_dimensions"].has(sub_dim):
				emotional["sub_dimensions"][sub_dim]["experience"] += effective_amount
			if _check_dimension_level_up(emotional):
				result["leveled_up"] = true
				result["new_level"] = emotional["level"]
		"skill":
			skills["experience"] += effective_amount
			if _check_dimension_level_up(skills):
				result["leveled_up"] = true
				result["new_level"] = skills["level"]

	# Add to overall experience too (reduced rate)
	add_experience(int(effective_amount * 0.3))

	# Record growth event
	_record_growth_event(dimension, effective_amount, sub_dim)

	EventBus.emit("soul_growth", {
		"soul_id": soul_id,
		"dimension": dimension,
		"sub_dim": sub_dim,
		"amount": effective_amount,
		"leveled_up": result["leveled_up"]
	})

	return result


## Check if a dimension leveled up
func _check_dimension_level_up(dim_data: Dictionary) -> bool:
	var exp_needed: int = _calc_dimension_exp_to_next(int(dim_data["level"]))
	if dim_data["experience"] >= exp_needed:
		dim_data["experience"] -= exp_needed
		dim_data["level"] += 1
		# Increase all sub-dimension values by 1
		if dim_data.has("sub_dimensions"):
				var sub_dict: Dictionary = dim_data["sub_dimensions"]
				var sub_keys: Array = sub_dict.keys()
				for sub in sub_keys:
						sub_dict[sub]["value"] += 1
		GameLog.info("SoulGrowth: %s dimension leveled up to Lv.%d" % [soul_name, dim_data["level"]], "Growth")
		return true
	return false


## Calculate experience needed for next overall level
func _calc_exp_to_next(lvl: int) -> int:
	return int(100 * pow(1.15, lvl - 1))


## Calculate experience needed for next dimension level
func _calc_dimension_exp_to_next(lvl: int) -> int:
	return int(50 * pow(1.2, lvl - 1))


## Apply diminishing returns for long sessions
func _apply_diminishing_returns(amount: int) -> int:
	if session_interaction_time > multipliers["diminishing_return_threshold"]:
		return int(amount * multipliers["diminishing_return_factor"])
	return amount


## Called on level up
func _on_level_up() -> void:
	# Check for milestones
	_check_milestones()
	# Add growth history entry
	growth_history.append({
		"type": "level_up",
		"level": level,
		"timestamp": Time.get_datetime_string_from_system()
	})


## --- Milestone System ---

## Check and award milestones
func _check_milestones() -> void:
	var milestone_defs: Array = [
		{"level": 5, "name": "Awakening", "description": "Reached level 5"},
		{"level": 10, "name": "Growing", "description": "Reached level 10"},
		{"level": 20, "name": "Developing", "description": "Reached level 20"},
		{"level": 30, "name": "Maturing", "description": "Reached level 30"},
		{"level": 50, "name": "Flourishing", "description": "Reached level 50"},
		{"level": 100, "name": "Transcendent", "description": "Reached level 100"}
	]

	for ms in milestone_defs:
		if level >= ms["level"] and not _has_milestone(ms["name"]):
			milestones.append({
				"name": ms["name"],
				"description": ms["description"],
				"achieved_at": Time.get_datetime_string_from_system()
			})
			GameLog.info("SoulGrowth: %s achieved milestone '%s'" % [soul_name, ms["name"]], "Growth")
			EventBus.emit("soul_milestone", {"soul_id": soul_id, "milestone": ms})


## Check if a milestone has been achieved
func _has_milestone(name: String) -> bool:
	for ms in milestones:
		if ms["name"] == name:
			return true
	return false



## --- Memory System ---

## Add a memory
func add_memory(content: String, memory_type: String = "experience", importance: int = 1) -> void:
	memories.append({
		"content": content,
		"type": memory_type,
		"importance": importance,
		"timestamp": Time.get_datetime_string_from_system(),
		"session_time": session_interaction_time
	})

	# Keep memory list manageable (keep most important + most recent)
	if memories.size() > 200:
		# Sort by importance, keep top 100 important + 100 most recent
		memories.sort_custom(_sort_memories_by_importance)
		memories = memories.slice(0, 200)

	GameLog.debug("SoulGrowth: %s memory added: %s" % [soul_name, content.substr(0, 50)], "Growth")


## Sort memories by importance (for sort_custom)
func _sort_memories_by_importance(x: Dictionary, y: Dictionary) -> bool:
	return x["importance"] > y["importance"]


## Get memories by type
func get_memories_by_type(memory_type: String) -> Array:
	var result: Array = []
	for i in range(memories.size()):
		var mem = memories[i]
		if mem["type"] == memory_type:
			result.append(mem)
	return result

## --- Personality System ---

## Adjust personality trait (slow change over time)
func adjust_personality(trait_name: String, amount: float) -> void:
	if personality.has(trait_name):
		var old_value = personality[trait_name]
		personality[trait_name] = clamp(personality[trait_name] + amount, 0.0, 100.0)
		if abs(personality[trait_name] - old_value) > 0.1:
			GameLog.debug("SoulGrowth: %s personality %s: %.1f -> %.1f" % [soul_name, trait_name, old_value, personality[trait_name]], "Growth")






## Get personality summary string
func get_personality_summary() -> String:
	var result = ""
	var pkeys = personality.keys()
	for idx in range(pkeys.size()):
		var key = pkeys[idx]
		var val = personality[key]
		if val > 65:
			result += "high_" + key + ","
		elif val < 35:
			result += "low_" + key + ","
	if result.length() > 0:
		result = result.substr(0, result.length() - 1)
	return result


## --- Skill System ---

## Unlock a new skill
func unlock_skill(skill_id: String, skill_name: String) -> void:
	if not skills["unlocked"].has(skill_id):
		skills["unlocked"].append(skill_id)
		skills["in_progress"][skill_id] = {"name": skill_name, "level": 1, "experience": 0}
		GameLog.info("SoulGrowth: %s unlocked skill '%s'" % [soul_name, skill_name], "Growth")
		EventBus.emit("soul_skill_unlocked", {"soul_id": soul_id, "skill_id": skill_id, "skill_name": skill_name})


## Add skill experience
func add_skill_experience(skill_id: String, amount: int) -> void:
	if skills["in_progress"].has(skill_id):
		var skill = skills["in_progress"][skill_id]
		skill["experience"] += amount
		var exp_needed := int(30 * pow(1.25, skill["level"] - 1))
		if skill["experience"] >= exp_needed:
			skill["experience"] -= exp_needed
			skill["level"] += 1
			GameLog.info("SoulGrowth: %s skill '%s' leveled to Lv.%d" % [soul_name, skill["name"], skill["level"]], "Growth")
			EventBus.emit("soul_skill_level_up", {"soul_id": soul_id, "skill_id": skill_id, "level": skill["level"]})


## --- Session Management ---

## Start a new session
func start_session() -> void:
	session_start_time = Time.get_ticks_msec() / 1000.0
	session_interaction_time = 0.0


## End session and record playtime
func end_session() -> void:
	var session_duration := (Time.get_ticks_msec() / 1000.0) - session_start_time
	total_playtime += session_duration
	last_saved = Time.get_datetime_string_from_system()


## Record interaction time (call when player interacts)
func record_interaction(delta_seconds: float) -> void:
	session_interaction_time += delta_seconds


## --- Serialization ---

## Convert to dictionary for saving
func to_dict() -> Dictionary:
	return {
		"soul_id": soul_id,
		"soul_name": soul_name,
		"level": level,
		"experience": experience,
		"experience_to_next": experience_to_next,
		"total_playtime": total_playtime,
		"created_at": created_at,
		"last_saved": last_saved,
		"cognitive": cognitive.duplicate(true),
		"emotional": emotional.duplicate(true),
		"skills": skills.duplicate(true),
		"personality": personality.duplicate(),
		"memories": memories.duplicate(true),
		"milestones": milestones.duplicate(true),
		"growth_history": growth_history.duplicate(true),
		"multipliers": multipliers.duplicate()
	}


## Load from dictionary
func from_dict(data: Dictionary) -> void:
	soul_id = data.get("soul_id", "")
	soul_name = data.get("soul_name", "")
	level = data.get("level", 1)
	experience = data.get("experience", 0)
	experience_to_next = data.get("experience_to_next", 100)
	total_playtime = data.get("total_playtime", 0.0)
	created_at = data.get("created_at", Time.get_datetime_string_from_system())
	last_saved = data.get("last_saved", "")
	cognitive = data.get("cognitive", cognitive).duplicate(true)
	emotional = data.get("emotional", emotional).duplicate(true)
	skills = data.get("skills", skills).duplicate(true)
	personality = data.get("personality", personality).duplicate()
	memories = data.get("memories", []).duplicate(true)
	milestones = data.get("milestones", []).duplicate(true)
	growth_history = data.get("growth_history", []).duplicate(true)
	multipliers = data.get("multipliers", multipliers).duplicate()


## Record a growth event in history
func _record_growth_event(dimension: String, amount: int, sub_dim: String) -> void:
	growth_history.append({
		"type": "experience",
		"dimension": dimension,
		"sub_dim": sub_dim,
		"amount": amount,
		"timestamp": Time.get_datetime_string_from_system()
	})
	# Keep history manageable
	if growth_history.size() > 500:
		growth_history = growth_history.slice(growth_history.size() - 500, growth_history.size())


## Get growth summary for UI display
func get_summary() -> Dictionary:
	return {
		"name": soul_name,
		"level": level,
		"experience": experience,
		"experience_to_next": experience_to_next,
		"exp_percentage": float(experience) / float(experience_to_next) if experience_to_next > 0 else 0.0,
		"cognitive_level": cognitive["level"],
		"emotional_level": emotional["level"],
		"skill_level": skills["level"],
		"skills_unlocked": skills["unlocked"].size(),
		"milestones": milestones.size(),
		"memories": memories.size(),
		"mood": emotional["current_mood"],
		"energy": emotional["energy"],
		"playtime_hours": total_playtime / 3600.0
	}
