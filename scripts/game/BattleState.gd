extends Resource
## BattleState - Data model for an arena battle
##
## Tracks all state during a soul battle: participants, turn order,
## health, energy, actions, and battle outcome.
##
## This is pure data, no game logic. ArenaManager handles battle flow.

## Battle ID
var battle_id: String = ""

## Battle status: "idle", "active", "paused", "finished"
var status: String = "idle"

## Current turn number
var turn: int = 0

## Current round (each round has all participants acting once)
var round: int = 0

## Participants: Array of Dictionaries with soul data
## Each: {id, name, element, level, max_hp, current_hp, max_energy, current_energy, skills, is_alive}
var participants: Array = []

## Turn order: Array of soul IDs in action order
var turn_order: Array = []

## Index of current actor in turn_order
var current_actor_index: int = 0

## Battle log: Array of action records
## Each: {turn, actor_id, action_type, target_id, damage, effect, message}
var battle_log: Array = []

## Winner soul ID (empty if battle not finished)
var winner_id: String = ""

## Battle result: "pending", "victory", "defeat", "draw"
var result: String = "pending"

## Battle start time
var started_at: String = ""

## Battle end time
var ended_at: String = ""

## Battle configuration
var config: Dictionary = {
	"max_turns": 50,
	"max_rounds": 25,
	"turn_time_limit": 30,
	"auto_battle": false,
	"battle_type": "normal"  # normal, tournament, training
}


## Reset battle state for a new battle
func reset() -> void:
	battle_id = ""
	status = "idle"
	turn = 0
	round = 0
	participants.clear()
	turn_order.clear()
	current_actor_index = 0
	battle_log.clear()
	winner_id = ""
	result = "pending"
	started_at = ""
	ended_at = ""


## Add a participant to the battle
func add_participant(p_soul_id: String, p_soul_name: String, p_element: String, p_level: int, p_max_hp: int, p_max_energy: int) -> void:
	var participant = {
		"id": p_soul_id,
		"name": p_soul_name,
		"element": p_element,
		"level": p_level,
		"max_hp": p_max_hp,
		"current_hp": p_max_hp,
		"max_energy": p_max_energy,
		"current_energy": p_max_energy,
		"skills": [],
		"is_alive": true,
		"defense_bonus": 0,
		"attack_bonus": 0,
		"status_effects": []
	}
	participants.append(participant)


## Get participant by ID
func get_participant(p_soul_id: String) -> Dictionary:
	for p in participants:
		if p["id"] == p_soul_id:
			return p
	return {}


## Get current actor
func get_current_actor() -> Dictionary:
	if current_actor_index < turn_order.size():
		return get_participant(turn_order[current_actor_index])
	return {}


## Check if battle is finished
func is_finished() -> bool:
	return status == "finished"


## Get alive participants count
func get_alive_count() -> int:
	var count = 0
	for p in participants:
		if p["is_alive"]:
			count += 1
	return count


## Add a log entry
func add_log(p_turn: int, p_actor_id: String, p_action_type: String, p_target_id: String, p_damage: int, p_effect: String, p_message: String) -> void:
	var entry = {
		"turn": p_turn,
		"actor_id": p_actor_id,
		"action_type": p_action_type,
		"target_id": p_target_id,
		"damage": p_damage,
		"effect": p_effect,
		"message": p_message,
		"timestamp": Time.get_datetime_string_from_system()
	}
	battle_log.append(entry)


## Serialize to dictionary
func to_dict() -> Dictionary:
	return {
		"battle_id": battle_id,
		"status": status,
		"turn": turn,
		"round": round,
		"participants": participants.duplicate(true),
		"turn_order": turn_order.duplicate(),
		"current_actor_index": current_actor_index,
		"battle_log": battle_log.duplicate(true),
		"winner_id": winner_id,
		"result": result,
		"started_at": started_at,
		"ended_at": ended_at,
		"config": config.duplicate()
	}


## Load from dictionary
func from_dict(p_data: Dictionary) -> void:
	battle_id = p_data.get("battle_id", "")
	status = p_data.get("status", "idle")
	turn = p_data.get("turn", 0)
	round = p_data.get("round", 0)
	participants = p_data.get("participants", []).duplicate(true)
	turn_order = p_data.get("turn_order", []).duplicate()
	current_actor_index = p_data.get("current_actor_index", 0)
	battle_log = p_data.get("battle_log", []).duplicate(true)
	winner_id = p_data.get("winner_id", "")
	result = p_data.get("result", "pending")
	started_at = p_data.get("started_at", "")
	ended_at = p_data.get("ended_at", "")
	config = p_data.get("config", config).duplicate()


## Get battle summary
func get_summary() -> String:
	if status == "idle":
		return "Battle not started"
	if status == "active":
		return "Battle in progress - Turn %d, Round %d" % [turn, round]
	if status == "finished":
		if result == "victory":
			var winner = get_participant(winner_id)
			return "Battle finished - %s wins!" % winner.get("name", "Unknown")
		if result == "draw":
			return "Battle finished - Draw"
		return "Battle finished"
	return "Battle status: %s" % status
