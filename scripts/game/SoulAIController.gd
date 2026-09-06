extends RefCounted
## SoulAIController - AI decision system for soul units in RTS battle
##
## Implements the "coach-style RTS" design: souls make autonomous decisions
## based on personality, emotion, memory, and current battlefield state.
## Player issues macro commands (gather/retreat/attack), souls may choose
## to follow or ignore based on personality (loyalty trait).
##
## Design reference: 06_对战系统深度设计.md
## - 个性即战术: personality directly affects battle behavior
## - 情绪影响: anger +20% attack, fear +20% defense
## - 玩家有限指令: macro commands every 30s, souls may disobey
##
## This is game-specific AI logic, not SDK kernel code.

## Decision types
enum Decision {
	IDLE,
	MOVE_TO_TARGET,
	ATTACK,
	USE_SKILL,
	DEFEND,
	RETREAT,
	EXPLORE,
	FOLLOW_COMMAND
}

## Current decision
var current_decision: int = Decision.IDLE

## Decision target (position or unit)
var decision_target: Variant = null

## Decision cooldown (seconds between decisions)
var decision_cooldown: float = 0.0
var decision_interval: float = 1.5

## Player command system
var player_command: String = ""  # "gather"/"retreat"/"attack"/"defend"/""
var player_command_target: Vector2 = Vector2.ZERO
var command_cooldown: float = 0.0
const COMMAND_COOLDOWN: float = 30.0  # Design doc: one command per 30s

## Command obedience chance (based on loyalty)
var last_command_obeyed: bool = true

## Battle memory (simplified for M2 prototype)
## Design doc: memory affects behavior - soul hit by skill X will avoid it
var battle_memory: Dictionary = {
	"times_hit_by_heavy": 0,
	"times_hit_by_quick": 0,
	"times_killed": 0,
	"favorite_skill": "quick_strike",
	"enemy_skill_danger": {}
}


## Make a decision based on personality, emotion, and battlefield state
func make_decision(p_self, p_enemy) -> Dictionary:
	if decision_cooldown > 0:
		decision_cooldown -= 0.1  # approximate delta
		return {"decision": current_decision, "target": decision_target}

	decision_cooldown = decision_interval

	# If player command active and soul is loyal, consider following
	if player_command != "" and command_cooldown <= 0:
		if _should_follow_command(p_self):
			var cmd_result = _execute_player_command(p_self, p_enemy)
			if cmd_result != null:
				current_decision = cmd_result["decision"]
				decision_target = cmd_result.get("target", null)
				return cmd_result

	# Autonomous decision based on personality and state
	var distance: float = 0.0
	if p_enemy != null:
		distance = p_self.position.distance_to(p_enemy.position)

	var hp_ratio: float = float(p_self.current_hp) / float(p_self.max_hp)
	var energy_ratio: float = float(p_self.current_energy) / float(p_self.max_energy)

	# Decision scoring based on personality
	var scores: Dictionary = _calculate_decision_scores(p_self, p_enemy, distance, hp_ratio, energy_ratio)

	# Pick highest scoring decision
	var best_decision: int = Decision.IDLE
	var best_score: float = -999.0
	for d in scores.keys():
		if scores[d] > best_score:
			best_score = scores[d]
			best_decision = d

	current_decision = best_decision
	decision_target = p_enemy if best_decision in [Decision.ATTACK, Decision.USE_SKILL] else null

	return {"decision": best_decision, "target": decision_target}


## Calculate decision scores based on personality and state
func _calculate_decision_scores(p_self, p_enemy, p_distance: float, p_hp_ratio: float, p_energy_ratio: float) -> Dictionary:
	var scores: Dictionary = {
		Decision.ATTACK: 0.0,
		Decision.USE_SKILL: 0.0,
		Decision.DEFEND: 0.0,
		Decision.RETREAT: 0.0,
		Decision.EXPLORE: 0.0,
		Decision.IDLE: 0.0
	}

	var aggression: float = float(p_self.personality.get("aggression", 50)) / 100.0
	var courage: float = float(p_self.personality.get("courage", 50)) / 100.0
	var patience: float = float(p_self.personality.get("patience", 50)) / 100.0
	var intelligence: float = float(p_self.personality.get("intelligence", 50)) / 100.0

	# Emotion modifiers
	var anger: float = p_self.emotion.get("anger", 0.0)
	var fear: float = p_self.emotion.get("fear", 0.0)

	# Attack score: high aggression + high courage + enemy in range
	scores[Decision.ATTACK] = aggression * 50 + courage * 30 + anger * 20
	if p_distance <= p_self.attack_range:
		scores[Decision.ATTACK] += 30
	if p_hp_ratio < 0.3:
		scores[Decision.ATTACK] -= 40  # Low HP = less likely to attack

	# Skill score: high intelligence + enough energy
	scores[Decision.USE_SKILL] = intelligence * 40 + p_energy_ratio * 30
	if p_distance <= p_self.attack_range:
		scores[Decision.USE_SKILL] += 20

	# Defend score: low HP + high patience + fear
	scores[Decision.DEFEND] = (1.0 - p_hp_ratio) * 60 + patience * 20 + fear * 30
	if p_hp_ratio < 0.4:
		scores[Decision.DEFEND] += 30

	# Retreat score: very low HP + low courage + high fear
	scores[Decision.RETREAT] = (1.0 - p_hp_ratio) * 80 + (1.0 - courage) * 30 + fear * 40
	if p_hp_ratio < 0.2:
		scores[Decision.RETREAT] += 50

	# Explore score: high curiosity
	var curiosity: float = float(p_self.personality.get("curiosity", 50)) / 100.0
	scores[Decision.EXPLORE] = curiosity * 40
	if p_distance > p_self.attack_range * 2:
		scores[Decision.EXPLORE] += 20

	# Idle score: baseline
	scores[Decision.IDLE] = 10.0

	return scores


## Execute the current decision on the unit
func execute_decision(p_self, p_enemy) -> void:
	match current_decision:
		Decision.ATTACK:
			if p_enemy != null and p_self.position.distance_to(p_enemy.position) <= p_self.attack_range:
				p_self.set_attack_target(p_enemy)
			else:
				p_self.move_to(p_enemy.position)
		Decision.USE_SKILL:
			_use_best_skill(p_self, p_enemy)
		Decision.DEFEND:
			if p_self.skill_cooldowns.get("defend", 999) <= 0:
				p_self.use_skill("defend")
		Decision.RETREAT:
			var retreat_dir: Vector2 = (p_self.position - p_enemy.position).normalized()
			p_self.move_to(p_self.position + retreat_dir * 200.0)
		Decision.EXPLORE:
			var random_dir: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			p_self.move_to(p_self.position + random_dir * 150.0)
		Decision.MOVE_TO_TARGET:
			if decision_target != null:
				p_self.move_to(decision_target)


## Use the best available skill based on state
func _use_best_skill(p_self, p_enemy) -> void:
	var hp_ratio: float = float(p_self.current_hp) / float(p_self.max_hp)
	var aggression: float = float(p_self.personality.get("aggression", 50)) / 100.0

	# Healing priority for low HP
	if hp_ratio < 0.4 and p_self.skill_cooldowns.get("heal", 999) <= 0:
		p_self.use_skill("heal", p_self)
		return

	# Defend for medium HP
	if hp_ratio < 0.6 and p_self.skill_cooldowns.get("defend", 999) <= 0:
		p_self.use_skill("defend")
		return

	# Attack skills based on aggression
	if p_enemy != null and p_self.position.distance_to(p_enemy.position) <= p_self.attack_range:
		if aggression > 0.6 and p_self.skill_cooldowns.get("heavy_strike", 999) <= 0:
			p_self.use_skill("heavy_strike", p_enemy)
		elif p_self.skill_cooldowns.get("quick_strike", 999) <= 0:
			p_self.use_skill("quick_strike", p_enemy)


## Check if soul should follow player command
## Design doc: soul may disobey based on loyalty/courage
func _should_follow_command(p_self) -> bool:
	var loyalty: float = float(p_self.personality.get("loyalty", 50)) / 100.0
	var courage: float = float(p_self.personality.get("courage", 50)) / 100.0

	# Base obedience from loyalty
	var obey_chance: float = 0.5 + loyalty * 0.4

	# Retreat commands are more likely to be obeyed by low courage souls
	if player_command == "retreat":
		obey_chance += (1.0 - courage) * 0.2
	# Attack commands are less likely to be obeyed by low courage souls
	elif player_command == "attack":
		obey_chance -= (1.0 - courage) * 0.3

	last_command_obeyed = randf() < obey_chance
	return last_command_obeyed


## Execute player command
func _execute_player_command(p_self, p_enemy):
	match player_command:
		"gather":
			return {"decision": Decision.MOVE_TO_TARGET, "target": player_command_target}
		"retreat":
			return {"decision": Decision.RETREAT, "target": null}
		"attack":
			return {"decision": Decision.ATTACK, "target": p_enemy}
		"defend":
			return {"decision": Decision.DEFEND, "target": null}
	return null


## Issue a player command (design doc: one per 30s)
func issue_command(p_command: String, p_target: Vector2 = Vector2.ZERO) -> bool:
	if command_cooldown > 0:
		return false
	player_command = p_command
	player_command_target = p_target
	command_cooldown = COMMAND_COOLDOWN
	return true


## Update emotional state based on battle events
## Design doc: emotion affects skill effectiveness
func update_emotion(p_self, p_event: String, p_value: float = 0.1) -> void:
	match p_event:
		"took_damage":
			p_self.emotion["fear"] = clamp(p_self.emotion["fear"] + p_value * 0.5, 0.0, 1.0)
			p_self.emotion["anger"] = clamp(p_self.emotion["anger"] + p_value * 0.3, 0.0, 1.0)
		"dealt_damage":
			p_self.emotion["excitement"] = clamp(p_self.emotion["excitement"] + p_value * 0.4, 0.0, 1.0)
			p_self.emotion["anger"] = clamp(p_self.emotion["anger"] - p_value * 0.1, 0.0, 1.0)
		"ally_died":
			p_self.emotion["fear"] = clamp(p_self.emotion["fear"] + p_value * 0.8, 0.0, 1.0)
			p_self.emotion["anger"] = clamp(p_self.emotion["anger"] + p_value * 0.6, 0.0, 1.0)
		"enemy_died":
			p_self.emotion["excitement"] = clamp(p_self.emotion["excitement"] + p_value * 0.6, 0.0, 1.0)
			p_self.emotion["fear"] = clamp(p_self.emotion["fear"] - p_value * 0.3, 0.0, 1.0)
		"low_hp":
			p_self.emotion["fear"] = clamp(p_self.emotion["fear"] + p_value * 0.3, 0.0, 1.0)

	# Decay emotions over time
	p_self.emotion["anger"] = clamp(p_self.emotion["anger"] - 0.005, 0.0, 1.0)
	p_self.emotion["fear"] = clamp(p_self.emotion["fear"] - 0.005, 0.0, 1.0)
	p_self.emotion["excitement"] = clamp(p_self.emotion["excitement"] - 0.003, 0.0, 1.0)

	# Determine dominant mood
	if p_self.emotion["anger"] > 0.5:
		p_self.emotion["mood"] = "anger"
	elif p_self.emotion["fear"] > 0.5:
		p_self.emotion["mood"] = "fear"
	elif p_self.emotion["excitement"] > 0.5:
		p_self.emotion["mood"] = "excited"
	else:
		p_self.emotion["mood"] = "calm"

	p_self.emotion["intensity"] = max(p_self.emotion["anger"], p_self.emotion["fear"], p_self.emotion["excitement"])


## Get emotion-based damage modifier
## Design doc: anger +20% attack, fear +20% defense
func get_damage_modifier(p_self) -> float:
	if p_self.emotion["mood"] == "anger":
		return 1.0 + p_self.emotion["intensity"] * 0.2
	return 1.0


## Get emotion-based defense modifier
func get_defense_modifier(p_self) -> float:
	if p_self.emotion["mood"] == "fear":
		return 1.0 + p_self.emotion["intensity"] * 0.2
	return 1.0


## Update cooldowns
func update(delta: float) -> void:
	if decision_cooldown > 0:
		decision_cooldown -= delta
	if command_cooldown > 0:
		command_cooldown -= delta
		if command_cooldown <= 0:
			player_command = ""  # Command expires


## Get AI state info for debugging/UI
func get_state_info() -> Dictionary:
	return {
		"decision": current_decision,
		"player_command": player_command,
		"command_cooldown": command_cooldown,
		"last_command_obeyed": last_command_obeyed,
		"decision_cooldown": decision_cooldown
	}
