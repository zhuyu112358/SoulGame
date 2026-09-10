extends Node
## TacticalCommandSystem - Manages 6 tactical commands that influence AI behavior
## Follows GDD v2.0 Chapter 2.1.1: Tactical Command System (Core)
## M2.2 Core Battle System

# Signal emitted when tactical command changes
signal command_changed(command_id: String, command_name: String)

# Current active command (default: free)
var _current_command: String = "free"

# Tactical command definitions (GDD v2.0: 6 commands)
const COMMANDS: Dictionary = {
	"aggressive": {
		"name": "进攻",
		"name_en": "AGGRESSIVE",
		"description": "主动寻找敌人，优先攻击，冒进倾向高",
		"color": Color(0.9, 0.3, 0.3),
		"icon": "⚔"
	},
	"defensive": {
		"name": "防守",
		"name_en": "DEFENSIVE",
		"description": "保持距离，优先躲避，防守反击",
		"color": Color(0.3, 0.5, 0.9),
		"icon": "🛡"
	},
	"focus": {
		"name": "集火",
		"name_en": "FOCUS",
		"description": "优先攻击玩家标记的目标",
		"color": Color(0.9, 0.5, 0.2),
		"icon": "🎯"
	},
	"retreat": {
		"name": "撤退",
		"name_en": "RETREAT",
		"description": "向后撤退，脱离战斗",
		"color": Color(0.7, 0.7, 0.3),
		"icon": "↩"
	},
	"follow": {
		"name": "跟随",
		"name_en": "FOLLOW",
		"description": "跟随指定友方单位，保护核心",
		"color": Color(0.3, 0.8, 0.5),
		"icon": "👥"
	},
	"free": {
		"name": "自由",
		"name_en": "FREE",
		"description": "完全自主决策，不干预",
		"color": Color(0.7, 0.7, 0.7),
		"icon": "✦"
	}
}

# AI behavior weight modifiers for each command
# These weights modify EmberSoulAIController decision making
const WEIGHT_MODIFIERS: Dictionary = {
	"aggressive": {
		"attack_priority": 1.5,      # More likely to attack
		"chase_range": 1.3,          # Chase farther
		"evade_priority": 0.5,       # Less likely to evade
		"keep_distance": 0.7,        # Get closer
		"skill_aggressiveness": 1.4, # Use skills more aggressively
		"risk_tolerance": 1.5        # Take more risks
	},
	"defensive": {
		"attack_priority": 0.7,      # Less likely to attack first
		"chase_range": 0.6,          # Don't chase far
		"evade_priority": 1.6,       # More likely to evade
		"keep_distance": 1.4,        # Keep more distance
		"skill_aggressiveness": 0.7, # Use skills defensively
		"risk_tolerance": 0.5        # Avoid risks
	},
	"focus": {
		"attack_priority": 1.8,      # Very high priority to attack marked target
		"chase_range": 1.5,          # Chase marked target far
		"evade_priority": 0.6,       # Less evasion while focusing
		"keep_distance": 0.8,        # Get close to target
		"skill_aggressiveness": 1.5, # Use skills on marked target
		"risk_tolerance": 1.3        # Moderate risk
	},
	"retreat": {
		"attack_priority": 0.2,      # Almost never attack
		"chase_range": 0.0,          # Never chase
		"evade_priority": 2.0,       # Maximum evasion
		"keep_distance": 2.0,        # Maximum distance
		"skill_aggressiveness": 0.3, # Only use escape skills
		"risk_tolerance": 0.2        # Avoid all risks
	},
	"follow": {
		"attack_priority": 0.8,      # Attack threats to followed unit
		"chase_range": 0.5,          # Don't chase far from followed unit
		"evade_priority": 1.2,       # Protect followed unit
		"keep_distance": 1.0,        # Stay near followed unit
		"skill_aggressiveness": 0.9, # Use skills to protect
		"risk_tolerance": 0.8        # Moderate caution
	},
	"free": {
		"attack_priority": 1.0,      # Normal
		"chase_range": 1.0,          # Normal
		"evade_priority": 1.0,       # Normal
		"keep_distance": 1.0,        # Normal
		"skill_aggressiveness": 1.0, # Normal
		"risk_tolerance": 1.0        # Normal
	}
}

func _ready() -> void:
	GameLog.info("TacticalCommandSystem initialized", "TacticalCommand")

## Set current tactical command
func set_command(command_id: String) -> void:
	if not COMMANDS.has(command_id):
		GameLog.error("Unknown tactical command: %s" % command_id, "TacticalCommand")
		return
	if _current_command == command_id:
		return
	_current_command = command_id
	var cmd: Dictionary = COMMANDS[command_id]
	GameLog.info("Tactical command changed to: %s (%s)" % [cmd["name"], cmd["name_en"]], "TacticalCommand")
	command_changed.emit(command_id, cmd["name"])

## Get current command ID
func get_current_command() -> String:
	return _current_command

## Get current command data
func get_current_command_data() -> Dictionary:
	return COMMANDS.get(_current_command, COMMANDS["free"])

## Get weight modifiers for current command
func get_weight_modifiers() -> Dictionary:
	return WEIGHT_MODIFIERS.get(_current_command, WEIGHT_MODIFIERS["free"])

## Get specific weight modifier
func get_weight(modifier_name: String, default_value: float = 1.0) -> float:
	var modifiers: Dictionary = get_weight_modifiers()
	return modifiers.get(modifier_name, default_value)

## Get all commands for UI
func get_all_commands() -> Dictionary:
	return COMMANDS

## Check if command is valid
func is_valid_command(command_id: String) -> bool:
	return COMMANDS.has(command_id)
