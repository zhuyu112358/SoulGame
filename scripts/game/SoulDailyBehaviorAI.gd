extends Node
## SoulDailyBehaviorAI - AI for soul daily behavior in Soul Home
## Follows GDD v2.0 Chapter 8: Soul Home (Soul Daily Behavior AI)
## M2.8 Soul Home - Daily Behavior AI
##
## The soul autonomously chooses behaviors based on its needs, current room,
## and personality. Behaviors affect soul stats (energy, mood, experience, etc.)

## Behavior states
enum BehaviorState {
	IDLE,
	SLEEPING,
	EATING,
	READING,
	TRAINING,
	PLAYING,
	MEDITATING,
	WALKING,
	INTERACTING
}

## Behavior definitions
const BEHAVIORS := {
	BehaviorState.IDLE: {
		"name": "发呆",
		"description": "灵魂在休息",
		"duration": 3.0,
		"energy_cost": 0.0,
		"mood_change": 0.0,
		"exp_reward": 0,
		"allowed_rooms": ["main", "bedroom", "living", "kitchen", "study", "training", "garden", "bathroom"]
	},
	BehaviorState.SLEEPING: {
		"name": "睡觉",
		"description": "灵魂在睡觉恢复能量",
		"duration": 10.0,
		"energy_cost": -20.0,  # negative = restores energy
		"mood_change": 5.0,
		"exp_reward": 5,
		"allowed_rooms": ["bedroom"]
	},
	BehaviorState.EATING: {
		"name": "进食",
		"description": "灵魂在享用食物",
		"duration": 5.0,
		"energy_cost": -10.0,
		"mood_change": 3.0,
		"exp_reward": 3,
		"allowed_rooms": ["kitchen", "living"]
	},
	BehaviorState.READING: {
		"name": "阅读",
		"description": "灵魂在阅读学习",
		"duration": 8.0,
		"energy_cost": 5.0,
		"mood_change": 2.0,
		"exp_reward": 10,
		"allowed_rooms": ["study", "living", "main"]
	},
	BehaviorState.TRAINING: {
		"name": "训练",
		"description": "灵魂在自我训练",
		"duration": 8.0,
		"energy_cost": 10.0,
		"mood_change": -1.0,
		"exp_reward": 15,
		"allowed_rooms": ["training", "garden"]
	},
	BehaviorState.PLAYING: {
		"name": "玩耍",
		"description": "灵魂在开心地玩耍",
		"duration": 6.0,
		"energy_cost": 5.0,
		"mood_change": 8.0,
		"exp_reward": 5,
		"allowed_rooms": ["living", "garden", "main"]
	},
	BehaviorState.MEDITATING: {
		"name": "冥想",
		"description": "灵魂在冥想提升认知",
		"duration": 10.0,
		"energy_cost": 3.0,
		"mood_change": 4.0,
		"exp_reward": 12,
		"allowed_rooms": ["study", "garden", "bathroom"]
	},
	BehaviorState.WALKING: {
		"name": "漫步",
		"description": "灵魂在四处走动",
		"duration": 4.0,
		"energy_cost": 2.0,
		"mood_change": 1.0,
		"exp_reward": 2,
		"allowed_rooms": ["main", "bedroom", "living", "kitchen", "study", "training", "garden", "bathroom"]
	},
	BehaviorState.INTERACTING: {
		"name": "互动",
		"description": "灵魂在与环境互动",
		"duration": 5.0,
		"energy_cost": 3.0,
		"mood_change": 3.0,
		"exp_reward": 5,
		"allowed_rooms": ["main", "bedroom", "living", "kitchen", "study", "training", "garden", "bathroom"]
	}
}

## Current behavior state
var _current_behavior: int = BehaviorState.IDLE

## Behavior timer
var _behavior_timer: float = 0.0

## Soul needs (0-100, higher = more urgent)
var _needs: Dictionary = {
	"energy": 50.0,  # lower = more tired
	"hunger": 30.0,  # higher = more hungry
	"mood": 70.0,    # lower = more sad
	"social": 40.0,  # higher = more wants social
	"knowledge": 50.0,  # higher = more wants to learn
	"fitness": 50.0  # higher = more wants to exercise
}

## Current room
var _current_room: String = "main"

## Whether AI is active
var _ai_active: bool = true

## Behavior change cooldown
var _behavior_cooldown: float = 0.0

## Total behaviors performed
var _total_behaviors: int = 0

## Signal emitted when behavior changes
signal behavior_changed(old_behavior, new_behavior)

## Signal emitted when behavior completes
signal behavior_completed(behavior, rewards)

## Signal emitted when needs change
signal needs_changed(needs)


func _process(delta: float) -> void:
	if not _ai_active:
		return
	# Update behavior timer
	if _behavior_timer > 0:
		_behavior_timer -= delta
		if _behavior_timer <= 0:
			_complete_behavior()
	# Update behavior cooldown
	if _behavior_cooldown > 0:
		_behavior_cooldown -= delta
	# Update needs over time
	_update_needs(delta)
	# Maybe choose new behavior
	if _behavior_cooldown <= 0 and _current_behavior == BehaviorState.IDLE:
		_choose_behavior()


## Set current room
func set_room(room: String) -> void:
	_current_room = room
	# If current behavior not allowed in new room, switch to idle
	var behavior = BEHAVIORS.get(_current_behavior, null)
	if behavior and room not in behavior["allowed_rooms"]:
		_set_behavior(BehaviorState.IDLE)


## Get current behavior
func get_current_behavior() -> int:
	return _current_behavior


## Get current behavior name
func get_current_behavior_name() -> String:
	var behavior = BEHAVIORS.get(_current_behavior, null)
	if behavior:
		return behavior["name"]
	return "未知"


## Get needs
func get_needs() -> Dictionary:
	return _needs.duplicate()


## Set AI active
func set_ai_active(active: bool) -> void:
	_ai_active = active


## Is AI active
func is_ai_active() -> bool:
	return _ai_active


## Force a specific behavior
func force_behavior(behavior: int) -> bool:
	if not BEHAVIORS.has(behavior):
		return false
	var behavior_def = BEHAVIORS[behavior]
	if _current_room not in behavior_def["allowed_rooms"]:
		return false
	_set_behavior(behavior)
	return true


## Choose next behavior based on needs and room
func _choose_behavior() -> void:
	# Get allowed behaviors for current room
	var allowed_behaviors = []
	for behavior_id in BEHAVIORS.keys():
		var behavior = BEHAVIORS[behavior_id]
		if _current_room in behavior["allowed_rooms"] and behavior_id != BehaviorState.IDLE:
			allowed_behaviors.append(behavior_id)
	if allowed_behaviors.is_empty():
		_set_behavior(BehaviorState.IDLE)
		return
	# Score each behavior based on needs
	var scored_behaviors = []
	for behavior_id in allowed_behaviors:
		var score = _score_behavior(behavior_id)
		scored_behaviors.append({"id": behavior_id, "score": score})
	# Sort by score (descending)
	scored_behaviors.sort_custom(func(a, b): return a["score"] > b["score"])
	# Choose from top 3 with some randomness
	var top_count = min(3, scored_behaviors.size())
	var chosen_index = randi() % top_count
	var chosen = scored_behaviors[chosen_index]["id"]
	_set_behavior(chosen)


## Score a behavior based on current needs
func _score_behavior(behavior: int) -> float:
	var score = 1.0  # base score
	var behavior_def = BEHAVIORS[behavior]
	# Energy: if low energy, prefer resting behaviors
	if _needs["energy"] < 30.0:
		if behavior_def["energy_cost"] < 0:  # restores energy
			score += (30.0 - _needs["energy"]) * 0.5
		elif behavior_def["energy_cost"] > 10:  # high energy cost
			score -= 5.0
	# Hunger: if hungry, prefer eating
	if _needs["hunger"] > 60.0:
		if behavior == BehaviorState.EATING:
			score += _needs["hunger"] * 0.3
	# Mood: if sad, prefer playing
	if _needs["mood"] < 40.0:
		if behavior_def["mood_change"] > 3:
			score += (40.0 - _needs["mood"]) * 0.4
	# Knowledge: if wants to learn, prefer reading/meditating
	if _needs["knowledge"] > 60.0:
		if behavior in [BehaviorState.READING, BehaviorState.MEDITATING]:
			score += _needs["knowledge"] * 0.2
	# Fitness: if wants to exercise, prefer training
	if _needs["fitness"] > 60.0:
		if behavior == BehaviorState.TRAINING:
			score += _needs["fitness"] * 0.2
	# Add some randomness
	score += randf_range(0, 5)
	return score


## Set current behavior
func _set_behavior(behavior: int) -> void:
	var old_behavior = _current_behavior
	_current_behavior = behavior
	var behavior_def = BEHAVIORS.get(behavior, null)
	if behavior_def:
		_behavior_timer = behavior_def["duration"]
	_behavior_cooldown = 1.0  # prevent immediate re-choose
	behavior_changed.emit(old_behavior, behavior)


## Complete current behavior
func _complete_behavior() -> void:
	var behavior = _current_behavior
	var behavior_def = BEHAVIORS.get(behavior, null)
	if behavior_def == null:
		_set_behavior(BehaviorState.IDLE)
		return
	# Apply behavior effects
	var rewards = {
		"exp": behavior_def["exp_reward"],
		"energy_change": -behavior_def["energy_cost"],
		"mood_change": behavior_def["mood_change"]
	}
	# Update needs
	_needs["energy"] = clamp(_needs["energy"] - behavior_def["energy_cost"], 0, 100)
	_needs["mood"] = clamp(_needs["mood"] + behavior_def["mood_change"], 0, 100)
	# Hunger increases over time (handled in _update_needs)
	_total_behaviors += 1
	behavior_completed.emit(behavior, rewards)
	needs_changed.emit(_needs.duplicate())
	# Return to idle
	_set_behavior(BehaviorState.IDLE)


## Update needs over time
func _update_needs(delta: float) -> void:
	# Energy decreases slowly
	_needs["energy"] = clamp(_needs["energy"] - delta * 0.1, 0, 100)
	# Hunger increases slowly
	_needs["hunger"] = clamp(_needs["hunger"] + delta * 0.15, 0, 100)
	# Mood decreases slowly if not doing fun things
	if _current_behavior not in [BehaviorState.PLAYING, BehaviorState.INTERACTING]:
		_needs["mood"] = clamp(_needs["mood"] - delta * 0.05, 0, 100)
	# Social need increases
	_needs["social"] = clamp(_needs["social"] + delta * 0.1, 0, 100)
	# Knowledge need increases
	_needs["knowledge"] = clamp(_needs["knowledge"] + delta * 0.08, 0, 100)
	# Fitness need increases
	_needs["fitness"] = clamp(_needs["fitness"] + delta * 0.08, 0, 100)


## Get total behaviors performed
func get_total_behaviors() -> int:
	return _total_behaviors


## Reset AI (for testing)
func reset() -> void:
	_current_behavior = BehaviorState.IDLE
	_behavior_timer = 0.0
	_needs = {
		"energy": 50.0,
		"hunger": 30.0,
		"mood": 70.0,
		"social": 40.0,
		"knowledge": 50.0,
		"fitness": 50.0
	}
	_current_room = "main"
	_ai_active = true
	_behavior_cooldown = 0.0
	_total_behaviors = 0
