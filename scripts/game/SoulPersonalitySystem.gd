extends Node
## SoulPersonalitySystem - Soul personality system
## Follows GDD v2.0 Chapter 6: Soul Character System
## M2.6 Soul Character - Personality System
##
## Defines personality types and their effects on AI behavior,
## expressions, and dialogue. Each soul has a unique personality.

## Personality types
enum PersonalityType {
	BRAVE,      # 勇敢 - high aggression, low fear
	CAUTIOUS,   # 谨慎 - high defense, low aggression
	AGGRESSIVE, # 激进 - very high aggression, reckless
	CALM,       # 冷静 - balanced, high decision quality
	FRIENDLY,   # 友善 - high cooperation, helps allies
	LONELY,     # 孤傲 - low cooperation, independent
	CURIOUS,    # 好奇 - explores, uses items frequently
	STUBBORN,   # 固执 - low command compliance, high persistence
	CHEERFUL,   # 开朗 - high morale, positive expressions
	SERIOUS     # 严肃 - focused, serious expressions
}

## Personality definitions
var _personalities: Dictionary = {
	PersonalityType.BRAVE: {
		"name": "勇敢",
		"description": "面对危险毫不退缩，总是冲在最前线",
		"ai_modifiers": {
			"aggression": 1.3,
			"fear": 0.5,
			"cooperation": 0.9,
			"command_compliance": 1.0,
			"item_usage": 0.8,
			"trap_avoidance": 0.7
		},
		"expression_bias": {"happy": 0.3, "angry": 0.4, "determined": 0.5},
		"dialogue_style": "direct",
		"color": Color(1.0, 0.4, 0.2)
	},
	PersonalityType.CAUTIOUS: {
		"name": "谨慎",
		"description": "凡事三思而后行，善于防守和躲避",
		"ai_modifiers": {
			"aggression": 0.7,
			"fear": 1.5,
			"cooperation": 1.0,
			"command_compliance": 1.2,
			"item_usage": 1.0,
			"trap_avoidance": 1.5
		},
		"expression_bias": {"worried": 0.4, "thinking": 0.5, "calm": 0.3},
		"dialogue_style": "careful",
		"color": Color(0.3, 0.6, 1.0)
	},
	PersonalityType.AGGRESSIVE: {
		"name": "激进",
		"description": "战斗狂热者，不顾一切地进攻",
		"ai_modifiers": {
			"aggression": 1.6,
			"fear": 0.3,
			"cooperation": 0.6,
			"command_compliance": 0.7,
			"item_usage": 0.6,
			"trap_avoidance": 0.5
		},
		"expression_bias": {"angry": 0.6, "excited": 0.4, "determined": 0.4},
		"dialogue_style": "aggressive",
		"color": Color(1.0, 0.2, 0.2)
	},
	PersonalityType.CALM: {
		"name": "冷静",
		"description": "临危不乱，总能做出最优决策",
		"ai_modifiers": {
			"aggression": 1.0,
			"fear": 0.8,
			"cooperation": 1.1,
			"command_compliance": 1.1,
			"item_usage": 1.2,
			"trap_avoidance": 1.3,
			"decision_quality": 1.3
		},
		"expression_bias": {"calm": 0.6, "thinking": 0.4, "confident": 0.3},
		"dialogue_style": "calm",
		"color": Color(0.4, 0.8, 0.8)
	},
	PersonalityType.FRIENDLY: {
		"name": "友善",
		"description": "乐于帮助队友，善于协作",
		"ai_modifiers": {
			"aggression": 0.8,
			"fear": 0.9,
			"cooperation": 1.6,
			"command_compliance": 1.1,
			"item_usage": 1.0,
			"trap_avoidance": 1.0,
			"ally_help": 1.5
		},
		"expression_bias": {"happy": 0.6, "kind": 0.5, "excited": 0.3},
		"dialogue_style": "friendly",
		"color": Color(0.5, 1.0, 0.5)
	},
	PersonalityType.LONELY: {
		"name": "孤傲",
		"description": "独来独往，不依赖他人",
		"ai_modifiers": {
			"aggression": 1.1,
			"fear": 0.7,
			"cooperation": 0.4,
			"command_compliance": 0.8,
			"item_usage": 0.9,
			"trap_avoidance": 1.0,
			"independence": 1.5
		},
		"expression_bias": {"cold": 0.5, "proud": 0.4, "thinking": 0.3},
		"dialogue_style": "cold",
		"color": Color(0.6, 0.4, 0.8)
	},
	PersonalityType.CURIOUS: {
		"name": "好奇",
		"description": "对一切充满好奇，喜欢探索和尝试",
		"ai_modifiers": {
			"aggression": 0.9,
			"fear": 0.8,
			"cooperation": 0.9,
			"command_compliance": 0.9,
			"item_usage": 1.6,
			"trap_avoidance": 0.8,
			"exploration": 1.5
		},
		"expression_bias": {"curious": 0.6, "excited": 0.4, "happy": 0.3},
		"dialogue_style": "curious",
		"color": Color(1.0, 0.8, 0.3)
	},
	PersonalityType.STUBBORN: {
		"name": "固执",
		"description": "坚持自己的想法，不轻易改变",
		"ai_modifiers": {
			"aggression": 1.1,
			"fear": 0.6,
			"cooperation": 0.7,
			"command_compliance": 0.5,
			"item_usage": 0.7,
			"trap_avoidance": 0.9,
			"persistence": 1.5
		},
		"expression_bias": {"determined": 0.6, "angry": 0.3, "proud": 0.3},
		"dialogue_style": "stubborn",
		"color": Color(0.8, 0.5, 0.3)
	},
	PersonalityType.CHEERFUL: {
		"name": "开朗",
		"description": "总是充满活力，能鼓舞队友士气",
		"ai_modifiers": {
			"aggression": 1.0,
			"fear": 0.6,
			"cooperation": 1.3,
			"command_compliance": 1.0,
			"item_usage": 1.0,
			"trap_avoidance": 0.9,
			"morale_boost": 1.5
		},
		"expression_bias": {"happy": 0.7, "excited": 0.5, "kind": 0.3},
		"dialogue_style": "cheerful",
		"color": Color(1.0, 0.8, 0.4)
	},
	PersonalityType.SERIOUS: {
		"name": "严肃",
		"description": "认真对待每一场战斗，不苟言笑",
		"ai_modifiers": {
			"aggression": 1.1,
			"fear": 0.7,
			"cooperation": 1.0,
			"command_compliance": 1.2,
			"item_usage": 1.0,
			"trap_avoidance": 1.2,
			"focus": 1.4
		},
		"expression_bias": {"serious": 0.7, "thinking": 0.4, "determined": 0.3},
		"dialogue_style": "serious",
		"color": Color(0.5, 0.5, 0.6)
	}
}

## Default personality mapping by element
var _element_personality: Dictionary = {
	"fire": PersonalityType.AGGRESSIVE,
	"water": PersonalityType.CALM,
	"earth": PersonalityType.STUBBORN,
	"wind": PersonalityType.CURIOUS,
	"thunder": PersonalityType.BRAVE,
	"ice": PersonalityType.LONELY,
	"dark": PersonalityType.SERIOUS,
	"light": PersonalityType.FRIENDLY
}


func _ready() -> void:
	GameLog.info("SoulPersonalitySystem: Ready with %d personality types" % _personalities.size(), "Personality")


## Get personality definition
func get_personality(p_type: int) -> Dictionary:
	if not _personalities.has(p_type):
		GameLog.warning("SoulPersonalitySystem: Unknown personality type: %d" % p_type, "Personality")
		return _personalities[PersonalityType.CALM].duplicate()
	return _personalities[p_type].duplicate()


## Get personality name
func get_personality_name(p_type: int) -> String:
	var p = get_personality(p_type)
	return p.get("name", "未知")


## Get personality description
func get_personality_description(p_type: int) -> String:
	var p = get_personality(p_type)
	return p.get("description", "")


## Get AI modifiers for personality
func get_ai_modifiers(p_type: int) -> Dictionary:
	var p = get_personality(p_type)
	return p.get("ai_modifiers", {}).duplicate()


## Get expression bias for personality
func get_expression_bias(p_type: int) -> Dictionary:
	var p = get_personality(p_type)
	return p.get("expression_bias", {}).duplicate()


## Get personality color
func get_personality_color(p_type: int) -> Color:
	var p = get_personality(p_type)
	return p.get("color", Color.WHITE)


## Get default personality for element
func get_default_personality_for_element(p_element: String) -> int:
	return _element_personality.get(p_element, PersonalityType.CALM)


## Get all personality types
func get_all_personalities() -> Array:
	return _personalities.keys()


## Get personality count
func get_personality_count() -> int:
	return _personalities.size()


## Generate random personality
func generate_random_personality() -> int:
	var types = _personalities.keys()
	return types[randi() % types.size()]


## Apply personality to AI controller
func apply_personality_to_ai(p_ai_controller, p_type: int) -> void:
	if p_ai_controller == null:
		return

	var modifiers = get_ai_modifiers(p_type)

	# Apply aggression modifier
	if modifiers.has("aggression") and p_ai_controller.has_method("set_aggression"):
		p_ai_controller.set_aggression(modifiers["aggression"])

	# Apply command compliance modifier
	if modifiers.has("command_compliance") and p_ai_controller.has_method("set_command_compliance"):
		p_ai_controller.set_command_compliance(modifiers["command_compliance"])

	# Apply decision interval modifier (higher decision quality = shorter interval)
	if modifiers.has("decision_quality"):
		var quality = modifiers["decision_quality"]
		if p_ai_controller.has_method("set_decision_interval"):
			p_ai_controller.set_decision_interval(1.5 / quality)

	GameLog.info("SoulPersonalitySystem: Applied personality %s to AI" % get_personality_name(p_type), "Personality")


## Get personality-specific dialogue prefix
func get_dialogue_prefix(p_type: int) -> String:
	var p = get_personality(p_type)
	var style = p.get("dialogue_style", "normal")

	match style:
		"direct":
			return ""
		"careful":
			return "嗯……"
		"aggressive":
			return "哼！"
		"calm":
			return "……"
		"friendly":
			return "嘿嘿~"
		"cold":
			return "……"
		"curious":
			return "哇！"
		"stubborn":
			return "我说了算！"
		"cheerful":
			return "耶！"
		"serious":
			return "……"
	return ""
