extends Node
## IntelligenceUpgradeSystem - Manages Ember-linked cognitive intelligence upgrades
## Follows GDD v2.0 Chapter 5: Three Upgrade Systems (Intelligence Upgrade - Ember Core)
## M2.7 Three Upgrade Systems (Intelligence Upgrade - Core Differentiator)
##
## This is the CORE DIFFERENTIATOR of Battleplan: souls are not just stat blocks,
## they are cognitive agents that learn, remember, and grow smarter over time.
## Intelligence upgrades are deeply linked to the Ember CognitiveEngine SDK.

## 8 cognitive dimensions (linked to Ember CognitiveEngine)
const COGNITIVE_DIMENSIONS := {
	"learning": {
		"name": "学习能力",
		"description": "从战斗经验中学习的速度，影响经验获取和技能掌握",
		"ember_attr": "learning_rate",
		"base_value": 0.1,
		"per_level": 0.02,
		"max_level": 10,
		"stage_threshold": [0, 2, 4, 6, 8, 10]
	},
	"reasoning": {
		"name": "推理能力",
		"description": "逻辑推理和战术分析能力，影响决策质量",
		"eember_attr": "reasoning_depth",
		"base_value": 0.1,
		"per_level": 0.02,
		"max_level": 10,
		"stage_threshold": [0, 2, 4, 6, 8, 10]
	},
	"memory": {
		"name": "记忆能力",
		"description": "记忆对手战术和战斗模式的能力，影响对战适应性",
		"eember_attr": "memory_capacity",
		"base_value": 0.1,
		"per_level": 0.02,
		"max_level": 10,
		"stage_threshold": [0, 2, 4, 6, 8, 10]
	},
	"attention": {
		"name": "注意力",
		"description": "战场态势感知和多目标跟踪能力，影响反应速度",
		"eember_attr": "attention_focus",
		"base_value": 0.1,
		"per_level": 0.02,
		"max_level": 10,
		"stage_threshold": [0, 2, 4, 6, 8, 10]
	},
	"language": {
		"name": "语言理解",
		"description": "理解玩家指令和战术沟通的能力，影响指令遵从度",
		"eember_attr": "language_comprehension",
		"base_value": 0.1,
		"per_level": 0.02,
		"max_level": 10,
		"stage_threshold": [0, 2, 4, 6, 8, 10]
	},
	"spatial": {
		"name": "空间认知",
		"description": "空间感知和路径规划能力，影响寻路和走位",
		"eember_attr": "spatial_awareness",
		"base_value": 0.1,
		"per_level": 0.02,
		"max_level": 10,
		"stage_threshold": [0, 2, 4, 6, 8, 10]
	},
	"creativity": {
		"name": "创造力",
		"description": "创新战术和意外策略的能力，影响决策多样性",
		"eember_attr": "creativity_index",
		"base_value": 0.1,
		"per_level": 0.02,
		"max_level": 10,
		"stage_threshold": [0, 2, 4, 6, 8, 10]
	},
	"problem_solving": {
		"name": "问题解决",
		"description": "应对复杂战场情况和危机处理能力，影响逆境表现",
		"eember_attr": "problem_solving_skill",
		"base_value": 0.1,
		"per_level": 0.02,
		"max_level": 10,
		"stage_threshold": [0, 2, 4, 6, 8, 10]
	}
}

## 6 cognitive stages
const COGNITIVE_STAGES := [
	{"name": "启蒙", "description": "刚刚觉醒的灵魂，认知能力有限", "min_total": 0},
	{"name": "成长", "description": "开始学习和成长，展现基本认知", "min_total": 8},
	{"name": "熟练", "description": "认知能力熟练，能应对常见战斗", "min_total": 24},
	{"name": "精通", "description": "认知能力精通，战术思维成熟", "min_total": 48},
	{"name": "大师", "description": "认知大师级，能创造独特战术", "min_total": 64},
	{"name": "超越", "description": "超越常规认知，拥有超凡智慧", "min_total": 80}
]

## Cognitive dimension levels (persistent)
var _cognitive_levels: Dictionary = {
	"learning": 0,
	"reasoning": 0,
	"memory": 0,
	"attention": 0,
	"language": 0,
	"spatial": 0,
	"creativity": 0,
	"problem_solving": 0
}

## Cognitive experience (earned from battles, used for auto-upgrade)
var _cognitive_experience: int = 0

## Available intelligence points (earned from cognitive level ups)
var _intelligence_points: int = 0

## Overall cognitive level
var _cognitive_level: int = 1

## Cognitive experience
var _cognitive_exp: int = 0

## Experience needed for next cognitive level
var _cognitive_exp_to_next: int = 150

## Save file path
const SAVE_PATH := "user://intelligence_upgrades.save"

## Signal emitted when cognitive dimension upgrades
signal cognitive_upgraded(dimension, new_level)

## Signal emitted when cognitive stage changes
signal stage_changed(new_stage, new_stage_name)

## Signal emitted when cognitive level up
signal cognitive_leveled_up(new_level)


func _ready() -> void:
	_load_data()


## Get cognitive dimension level
func get_cognitive_level(dimension: String) -> int:
	return _cognitive_levels.get(dimension, 0)


## Get cognitive dimension value (0.0 - 1.0+)
func get_cognitive_value(dimension: String) -> float:
	var dim = COGNITIVE_DIMENSIONS.get(dimension, null)
	if dim == null:
		return 0.0
	var level = _cognitive_levels.get(dimension, 0)
	return dim["base_value"] + dim["per_level"] * level


## Get total cognitive levels (sum of all dimensions)
func get_total_cognitive_level() -> int:
	var total = 0
	for dimension in _cognitive_levels.keys():
		total += _cognitive_levels[dimension]
	return total


## Get current cognitive stage (0-5)
func get_cognitive_stage() -> int:
	var total = get_total_cognitive_level()
	var stage = 0
	for i in range(COGNITIVE_STAGES.size()):
		if total >= COGNITIVE_STAGES[i]["min_total"]:
			stage = i
	return stage


## Get cognitive stage name
func get_cognitive_stage_name() -> String:
	return COGNITIVE_STAGES[get_cognitive_stage()]["name"]


## Apply cognitive upgrade to a dimension (costs 1 intelligence point)
func apply_cognitive_upgrade(dimension: String) -> bool:
	if _intelligence_points <= 0:
		return false
	var dim = COGNITIVE_DIMENSIONS.get(dimension, null)
	if dim == null:
		return false
	var current_level = _cognitive_levels.get(dimension, 0)
	if current_level >= dim["max_level"]:
		return false
	var old_stage = get_cognitive_stage()
	_cognitive_levels[dimension] = current_level + 1
	_intelligence_points -= 1
	var new_stage = get_cognitive_stage()
	cognitive_upgraded.emit(dimension, current_level + 1)
	if new_stage > old_stage:
		stage_changed.emit(new_stage, COGNITIVE_STAGES[new_stage]["name"])
	_save_data()
	return true


## Add cognitive experience and check for level up
func add_cognitive_experience(amount: int) -> void:
	_cognitive_exp += amount
	_cognitive_experience += amount
	# Check for cognitive level up
	while _cognitive_exp >= _cognitive_exp_to_next:
		_cognitive_exp -= _cognitive_exp_to_next
		_cognitive_level += 1
		_intelligence_points += 1  # Gain 1 intelligence point per level
		_cognitive_exp_to_next = _calc_cognitive_exp_to_next(_cognitive_level)
		cognitive_leveled_up.emit(_cognitive_level)
	_save_data()


## Calculate cognitive experience needed for next level
func _calc_cognitive_exp_to_next(level: int) -> int:
	return int(150 * pow(1.2, level - 1))


## Get cognitive level
func get_cognitive_level_overall() -> int:
	return _cognitive_level


## Get cognitive experience
func get_cognitive_experience() -> int:
	return _cognitive_exp


## Get experience to next cognitive level
func get_cognitive_exp_to_next() -> int:
	return _cognitive_exp_to_next


## Get available intelligence points
func get_intelligence_points() -> int:
	return _intelligence_points


## Get all cognitive levels
func get_all_cognitive_levels() -> Dictionary:
	return _cognitive_levels.duplicate()


## Get dimension definition
func get_dimension(dimension: String) -> Dictionary:
	return COGNITIVE_DIMENSIONS.get(dimension, {})


## Get all dimension IDs
func get_all_dimension_ids() -> Array:
	return COGNITIVE_DIMENSIONS.keys()


## Get AI decision modifiers based on cognitive levels
## These modifiers affect EmberSoulAIController behavior
func get_ai_modifiers() -> Dictionary:
	var modifiers = {
		"decision_interval": 1.5,  # Base 1.5 seconds
		"decision_confidence_threshold": 0.5,
		"learning_rate": 0.1,
		"command_compliance": 0.7,
		"reaction_speed": 1.0,
		"adaptability": 0.3,
		"creativity": 0.2,
		"crisis_handling": 0.3
	}
	# Learning: faster experience gain, faster skill mastery
	var learning_val = get_cognitive_value("learning")
	modifiers["learning_rate"] = 0.1 + learning_val * 2.0
	# Reasoning: better decision quality, higher confidence threshold
	var reasoning_val = get_cognitive_value("reasoning")
	modifiers["decision_confidence_threshold"] = 0.5 + reasoning_val * 1.5
	modifiers["decision_interval"] = max(0.5, 1.5 - reasoning_val * 3.0)
	# Memory: better adaptability to opponent patterns
	var memory_val = get_cognitive_value("memory")
	modifiers["adaptability"] = 0.3 + memory_val * 2.0
	# Attention: faster reaction speed
	var attention_val = get_cognitive_value("attention")
	modifiers["reaction_speed"] = 1.0 + attention_val * 2.0
	# Language: better command compliance
	var language_val = get_cognitive_value("language")
	modifiers["command_compliance"] = 0.7 + language_val * 1.0
	# Spatial: better pathfinding and positioning (handled in movement)
	# Creativity: more diverse decisions
	var creativity_val = get_cognitive_value("creativity")
	modifiers["creativity"] = 0.2 + creativity_val * 2.0
	# Problem solving: better crisis handling
	var problem_solving_val = get_cognitive_value("problem_solving")
	modifiers["crisis_handling"] = 0.3 + problem_solving_val * 2.0
	return modifiers


## Apply cognitive upgrades to Ember AI controller
func apply_to_ai_controller(ai_controller) -> void:
	if ai_controller == null:
		return
	var modifiers = get_ai_modifiers()
	# Apply decision interval (faster decisions with higher reasoning)
	if ai_controller.has_method("set_decision_interval"):
		ai_controller.set_decision_interval(modifiers["decision_interval"])
	# Apply command compliance (better with higher language)
	if "command_compliance" in ai_controller:
		ai_controller.command_compliance = modifiers["command_compliance"]
	# Store cognitive modifiers for AI to use
	if "cognitive_modifiers" in ai_controller:
		ai_controller.cognitive_modifiers = modifiers


## Reset all intelligence upgrades (for testing)
func reset_all() -> void:
	_cognitive_levels = {
		"learning": 0,
		"reasoning": 0,
		"memory": 0,
		"attention": 0,
		"language": 0,
		"spatial": 0,
		"creativity": 0,
		"problem_solving": 0
	}
	_cognitive_experience = 0
	_intelligence_points = 0
	_cognitive_level = 1
	_cognitive_exp = 0
	_cognitive_exp_to_next = 150
	_save_data()


## Save intelligence data to file
func _save_data() -> void:
	var save_data = {
		"cognitive_levels": _cognitive_levels,
		"cognitive_experience": _cognitive_experience,
		"intelligence_points": _intelligence_points,
		"cognitive_level": _cognitive_level,
		"cognitive_exp": _cognitive_exp,
		"cognitive_exp_to_next": _cognitive_exp_to_next
	}
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(save_data))
		f.close()


## Load intelligence data from file
func _load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f:
		var json_string = f.get_as_text()
		f.close()
		var parsed = JSON.parse_string(json_string)
		if parsed != null and typeof(parsed) == TYPE_DICTIONARY:
			if parsed.has("cognitive_levels"):
				for key in _cognitive_levels.keys():
					if parsed["cognitive_levels"].has(key):
						_cognitive_levels[key] = parsed["cognitive_levels"][key]
			if parsed.has("cognitive_experience"):
				_cognitive_experience = parsed["cognitive_experience"]
			if parsed.has("intelligence_points"):
				_intelligence_points = parsed["intelligence_points"]
			if parsed.has("cognitive_level"):
				_cognitive_level = parsed["cognitive_level"]
			if parsed.has("cognitive_exp"):
				_cognitive_exp = parsed["cognitive_exp"]
			if parsed.has("cognitive_exp_to_next"):
				_cognitive_exp_to_next = parsed["cognitive_exp_to_next"]
