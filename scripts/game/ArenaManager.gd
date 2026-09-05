extends Node
## ArenaManager - Manages arena battles between souls
##
## Handles battle flow: initialization, turn order, action processing,
## damage calculation, status effects, and win/loss determination.
##
## Uses BattleState for data storage. This is game-specific logic,
## not SDK kernel code.

## BattleState preload
const BattleState = preload("res://scripts/game/BattleState.gd")

## Current battle state
var current_battle = null

## Battle history (past battles)
var battle_history: Array = []

## Element advantage mapping (attacker -> defender -> multiplier)
var element_advantages: Dictionary = {
	"fire": {"wood": 1.5, "ice": 1.5, "wind": 0.75},
	"water": {"fire": 1.5, "earth": 0.75, "electric": 1.5},
	"earth": {"water": 1.5, "electric": 0.75, "fire": 0.75},
	"wind": {"earth": 1.5, "fire": 1.5, "water": 0.75},
	"light": {"dark": 1.5, "water": 0.75},
	"dark": {"light": 0.75, "earth": 1.5},
	"neutral": {}
}


func _ready() -> void:
	GameLog.info("ArenaManager: Initialized", "Arena")


## Start a new battle between two souls
func start_battle(p_soul1_id: String, p_soul1_name: String, p_soul1_element: String, p_soul1_level: int, p_soul2_id: String, p_soul2_name: String, p_soul2_element: String, p_soul2_level: int) -> BattleState:
	GameLog.info("ArenaManager: Starting battle between %s and %s" % [p_soul1_name, p_soul2_name], "Arena")

	current_battle = BattleState.new()
	current_battle.battle_id = "battle_%d" % Time.get_unix_time_from_system()
	current_battle.status = "active"
	current_battle.started_at = Time.get_datetime_string_from_system()

	# Calculate HP based on level (100 + level * 20)
	var hp1 = 100 + p_soul1_level * 20
	var hp2 = 100 + p_soul2_level * 20
	var energy1 = 50 + p_soul1_level * 5
	var energy2 = 50 + p_soul2_level * 5

	current_battle.add_participant(p_soul1_id, p_soul1_name, p_soul1_element, p_soul1_level, hp1, energy1)
	current_battle.add_participant(p_soul2_id, p_soul2_name, p_soul2_element, p_soul2_level, hp2, energy2)

	# Determine turn order by speed (simplified: higher level goes first, random if equal)
	if p_soul1_level >= p_soul2_level:
		current_battle.turn_order = [p_soul1_id, p_soul2_id]
	else:
		current_battle.turn_order = [p_soul2_id, p_soul1_id]

	current_battle.round = 1
	current_battle.turn = 1
	current_battle.current_actor_index = 0

	current_battle.add_log(1, "system", "battle_start", "", 0, "", "Battle started between %s and %s" % [p_soul1_name, p_soul2_name])

	EventBus.emit("arena_battle_started", {"battle_id": current_battle.battle_id, "participants": [p_soul1_name, p_soul2_name]})

	return current_battle


## Process an attack action
func process_attack(p_attacker_id: String, p_defender_id: String, p_skill_name: String = "basic_attack") -> Dictionary:
	if current_battle == null or current_battle.status != "active":
		return {"success": false, "message": "No active battle"}

	var attacker = current_battle.get_participant(p_attacker_id)
	var defender = current_battle.get_participant(p_defender_id)

	if attacker.is_empty() or defender.is_empty():
		return {"success": false, "message": "Invalid participant"}

	if not attacker["is_alive"]:
		return {"success": false, "message": "Attacker is defeated"}

	# Calculate base damage based on level and skill
	var base_damage = 10 + attacker["level"] * 3
	var energy_cost = 5

	# Skill-specific modifiers
	match p_skill_name:
		"heavy_strike":
			base_damage *= 1.5
			energy_cost = 15
		"quick_strike":
			base_damage *= 0.7
			energy_cost = 3
		"heal":
			# Heal self instead of attacking
			var heal_amount = 15 + attacker["level"] * 2
			attacker["current_hp"] = min(attacker["max_hp"], attacker["current_hp"] + heal_amount)
			attacker["current_energy"] -= energy_cost
			current_battle.add_log(current_battle.turn, p_attacker_id, "heal", p_attacker_id, 0, "heal", "%s healed for %d HP" % [attacker["name"], heal_amount])
			_advance_turn()
			return {"success": true, "action": "heal", "amount": heal_amount}
		"defend":
			attacker["defense_bonus"] = 0.5
			attacker["current_energy"] -= 2
			current_battle.add_log(current_battle.turn, p_attacker_id, "defend", p_attacker_id, 0, "defense_up", "%s is defending" % attacker["name"])
			_advance_turn()
			return {"success": true, "action": "defend"}

	# Check energy
	if attacker["current_energy"] < energy_cost:
		return {"success": false, "message": "Not enough energy"}

	# Apply element advantage
	var element_mult = _get_element_multiplier(attacker["element"], defender["element"])

	# Apply attack/defense bonuses
	var attack_bonus = 1.0 + attacker.get("attack_bonus", 0)
	var defense_bonus = 1.0 - defender.get("defense_bonus", 0)

	# Calculate final damage
	var final_damage = int(base_damage * element_mult * attack_bonus * defense_bonus)
	final_damage = max(1, final_damage)  # Minimum 1 damage

	# Apply damage
	defender["current_hp"] -= final_damage
	attacker["current_energy"] -= energy_cost

	# Reset defense bonus after being attacked
	defender["defense_bonus"] = 0

	# Check for defeat
	if defender["current_hp"] <= 0:
		defender["current_hp"] = 0
		defender["is_alive"] = false
		current_battle.add_log(current_battle.turn, p_attacker_id, p_skill_name, p_defender_id, final_damage, "defeat", "%s defeated %s!" % [attacker["name"], defender["name"]])
		_finish_battle(p_attacker_id)
	else:
		var effect_msg = ""
		if element_mult > 1.0:
			effect_msg = "Super effective!"
		elif element_mult < 1.0:
			effect_msg = "Not very effective..."
		current_battle.add_log(current_battle.turn, p_attacker_id, p_skill_name, p_defender_id, final_damage, effect_msg, "%s used %s on %s for %d damage %s" % [attacker["name"], p_skill_name, defender["name"], final_damage, effect_msg])

	_advance_turn()

	return {
		"success": true,
		"action": "attack",
		"damage": final_damage,
		"element_multiplier": element_mult,
		"defender_hp": defender["current_hp"],
		"defender_defeated": not defender["is_alive"]
	}


## Get element advantage multiplier
func _get_element_multiplier(p_attacker_element: String, p_defender_element: String) -> float:
	if element_advantages.has(p_attacker_element):
		var advantages = element_advantages[p_attacker_element]
		if advantages.has(p_defender_element):
			return advantages[p_defender_element]
	return 1.0


## Advance to next turn
func _advance_turn() -> void:
	current_battle.turn += 1
	current_battle.current_actor_index += 1

	# Check if round is complete
	if current_battle.current_actor_index >= current_battle.turn_order.size():
		current_battle.current_actor_index = 0
		current_battle.round += 1

		# Regenerate energy at start of each round
		for p in current_battle.participants:
			if p["is_alive"]:
				p["current_energy"] = min(p["max_energy"], p["current_energy"] + 10)

	# Skip defeated participants
	while current_battle.current_actor_index < current_battle.turn_order.size():
		var actor = current_battle.get_participant(current_battle.turn_order[current_battle.current_actor_index])
		if not actor.is_empty() and actor["is_alive"]:
			break
		current_battle.current_actor_index += 1

	# Check max turns
	if current_battle.turn > current_battle.config["max_turns"]:
		_finish_battle_draw()


## Finish battle with a winner
func _finish_battle(p_winner_id: String) -> void:
	current_battle.status = "finished"
	current_battle.winner_id = p_winner_id
	current_battle.result = "victory"
	current_battle.ended_at = Time.get_datetime_string_from_system()

	var winner = current_battle.get_participant(p_winner_id)
	current_battle.add_log(current_battle.turn, "system", "battle_end", "", 0, "", "%s wins the battle!" % winner.get("name", "Unknown"))

	# Add to history
	battle_history.append(current_battle.to_dict())

	EventBus.emit("arena_battle_finished", {
		"battle_id": current_battle.battle_id,
		"winner": winner.get("name", ""),
		"result": "victory",
		"turns": current_battle.turn
	})

	GameLog.info("ArenaManager: Battle finished - %s wins in %d turns" % [winner.get("name", "Unknown"), current_battle.turn], "Arena")


## Finish battle as a draw
func _finish_battle_draw() -> void:
	current_battle.status = "finished"
	current_battle.result = "draw"
	current_battle.ended_at = Time.get_datetime_string_from_system()
	current_battle.add_log(current_battle.turn, "system", "battle_end", "", 0, "", "Battle ended in a draw (max turns reached)")

	battle_history.append(current_battle.to_dict())

	EventBus.emit("arena_battle_finished", {
		"battle_id": current_battle.battle_id,
		"winner": "",
		"result": "draw",
		"turns": current_battle.turn
	})


## Get current battle state
func get_current_battle() -> BattleState:
	return current_battle


## Get battle log as formatted text
func get_battle_log_text(p_last_n: int = 10) -> String:
	if current_battle == null:
		return "No active battle"

	var logs = current_battle.battle_log
	var start = max(0, logs.size() - p_last_n)
	var text = ""
	for i in range(start, logs.size()):
		var entry = logs[i]
		text += "[T%d] %s\n" % [entry["turn"], entry["message"]]
	return text


## Get battle stats
func get_stats() -> Dictionary:
	return {
		"battles_played": battle_history.size(),
		"has_active_battle": current_battle != null and current_battle.status == "active",
		"current_turn": current_battle.turn if current_battle else 0,
		"current_round": current_battle.round if current_battle else 0
	}


## Forfeit current battle
func forfeit_battle(p_forfeiter_id: String) -> void:
	if current_battle == null or current_battle.status != "active":
		return

	var forfeiter = current_battle.get_participant(p_forfeiter_id)
	if forfeiter.is_empty():
		return

	forfeiter["is_alive"] = false
	forfeiter["current_hp"] = 0

	# Find the other participant as winner
	for p in current_battle.participants:
		if p["id"] != p_forfeiter_id and p["is_alive"]:
			_finish_battle(p["id"])
			return

	_finish_battle_draw()
