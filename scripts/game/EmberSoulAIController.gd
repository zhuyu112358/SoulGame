extends RefCounted
## EmberSoulAIController - AI decision system using Ember SDK
##
## Replaces the self-implemented SoulAIController with Ember SDK:
## - PerceptionSystem: battlefield perception (enemy position, threats, opportunities)
## - CognitiveEngine: decision making (perceive -> decide -> act pipeline)
##
## Architecture compliance: AI decision is Ember's responsibility.
## Player command system and emotion-based stat modifiers are gameplay-layer logic.
##
## Design reference: 06_对战系统深度设计.md
## - 个性即战术: personality affects decision via Ember Personality
## - 情绪影响: anger +20% attack, fear +20% defense (gameplay modifier)
## - 玩家有限指令: macro commands every 30s, souls may disobey

## Decision types (compatible with SoulAIController.Decision enum)
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

## Ember SDK instances
var _cognitive: Object = null
var _perception: Object = null
var _ember_initialized: bool = false

## Last Ember decision info for debugging
var last_ember_decision: Dictionary = {}
var last_perception_result: Dictionary = {}

## Player command system (gameplay layer, preserved)
var player_command: String = ""
var player_command_target: Vector2 = Vector2.ZERO
var command_cooldown: float = 0.0
const COMMAND_COOLDOWN: float = 30.0

## Command obedience chance (based on loyalty)
var last_command_obeyed: bool = true

## Battle memory (gameplay layer)
var battle_memory: Dictionary = {
	"times_hit_by_heavy": 0,
	"times_hit_by_quick": 0,
	"times_killed": 0,
	"favorite_skill": "quick_strike",
	"enemy_skill_danger": {}
}


func _init() -> void:
	_initialize_ember_sdk()


## Initialize Ember SDK instances
func _initialize_ember_sdk() -> void:
	if ClassDB.class_exists("CognitiveEngine"):
		_cognitive = ClassDB.instantiate("CognitiveEngine")
		GameLog.info("EmberSoulAIController: CognitiveEngine initialized", "Arena")
	else:
		GameLog.warning("EmberSoulAIController: CognitiveEngine class not found!", "Arena")

	if ClassDB.class_exists("PerceptionSystem"):
		_perception = ClassDB.instantiate("PerceptionSystem")
		GameLog.info("EmberSoulAIController: PerceptionSystem initialized", "Arena")
	else:
		GameLog.warning("EmberSoulAIController: PerceptionSystem class not found!", "Arena")

	_ember_initialized = (_cognitive != null and _perception != null)
	var status_text = "available" if _ember_initialized else "NOT available"
	GameLog.info("EmberSoulAIController: Ember SDK %s" % status_text, "Arena")


## Make a decision using Ember CognitiveEngine
func make_decision(p_self, p_enemy) -> Dictionary:
	if decision_cooldown > 0:
		decision_cooldown -= 0.1
		return {"decision": current_decision, "target": decision_target}

	decision_cooldown = decision_interval

	# Player command takes priority if soul is loyal
	if player_command != "" and command_cooldown <= 0:
		if _should_follow_command(p_self):
			var cmd_result = _execute_player_command(p_self, p_enemy)
			if cmd_result != null:
				current_decision = cmd_result["decision"]
				decision_target = cmd_result.get("target", null)
				return cmd_result

	# Use Ember SDK for autonomous decision
	if _ember_initialized:
		var ember_decision = _ember_decide(p_self, p_enemy)
		current_decision = ember_decision["decision"]
		decision_target = ember_decision.get("target", null)
		return ember_decision
	else:
		# Fallback: simple heuristic if Ember SDK not available
		return _fallback_decide(p_self, p_enemy)


## Ember perception-decision pipeline
func _ember_decide(p_self, p_enemy) -> Dictionary:
	# Step 1: Perceive battlefield
	var stimuli = _build_stimuli(p_self, p_enemy)
	var perception_result = _perception.perceive(stimuli)
	last_perception_result = perception_result

	# Step 2: Build decision context
	var context = _build_context(p_self, p_enemy, perception_result)

	# Step 3: Decide using CognitiveEngine
	var decision = _cognitive.decide(context)
	last_ember_decision = decision

	GameLog.debug("Ember AI: %s decide type=%s confidence=%.2f reasoning='%s'" % [
		p_self.soul_name, decision.get("type", "unknown"),
		decision.get("confidence", 0.0), decision.get("reasoning", "")
	], "Arena")

	# Step 4: Convert Ember decision to Battleplan decision
	return _convert_ember_decision(decision, p_self, p_enemy)


## Build perception stimuli from battlefield state
func _build_stimuli(p_self, p_enemy) -> Array:
	var stimuli = []

	# Enemy as visual stimulus
	if p_enemy != null and is_instance_valid(p_enemy):
		var dist = p_self.position.distance_to(p_enemy.position)
		stimuli.append({
			"type": "enemy",
			"position": p_enemy.position,
			"distance": dist,
			"threat_level": _calculate_threat_level(p_self, p_enemy),
			"hp_ratio": float(p_enemy.current_hp) / float(p_enemy.max_hp)
		})

	# Self state as internal stimulus
	stimuli.append({
		"type": "self",
		"hp_ratio": float(p_self.current_hp) / float(p_self.max_hp),
		"energy_ratio": float(p_self.current_energy) / float(p_self.max_energy),
		"position": p_self.position
	})

	return stimuli


## Build decision context from perception result
func _build_context(p_self, p_enemy, p_perception: Dictionary) -> Dictionary:
	var hp_ratio = float(p_self.current_hp) / float(p_self.max_hp)
	var energy_ratio = float(p_self.current_energy) / float(p_self.max_energy)
	var distance = 0.0
	if p_enemy != null:
		distance = p_self.position.distance_to(p_enemy.position)

	var threats = p_perception.get("threats", [])
	var opportunities = p_perception.get("opportunities", [])

	return {
		"battle_state": "active",
		"health_percent": hp_ratio,
		"energy_percent": energy_ratio,
		"enemy_distance": distance,
		"enemy_in_range": distance <= p_self.attack_range,
		"threat_count": threats.size(),
		"opportunity_count": opportunities.size(),
		"personality": p_self.personality,
		"emotion": p_self.emotion
	}


## Convert Ember decision type to Battleplan Decision enum
func _convert_ember_decision(p_decision: Dictionary, p_self, p_enemy) -> Dictionary:
	var decision_type = p_decision.get("type", "idle")
	var distance = 0.0
	var in_range = false
	if p_enemy != null and is_instance_valid(p_enemy):
		distance = p_self.position.distance_to(p_enemy.position)
		in_range = distance <= p_self.attack_range

	match decision_type:
		"attack":
			return {"decision": Decision.ATTACK, "target": p_enemy}
		"move", "move_to":
			# If enemy in attack range, attack instead of moving
			if p_enemy != null and in_range:
				return {"decision": Decision.ATTACK, "target": p_enemy}
			if p_enemy != null:
				return {"decision": Decision.MOVE_TO_TARGET, "target": p_enemy.position}
			return {"decision": Decision.EXPLORE, "target": null}
		"defend", "defensive":
			return {"decision": Decision.DEFEND, "target": null}
		"retreat", "flee":
			return {"decision": Decision.RETREAT, "target": null}
		"skill", "cast", "use_skill":
			return {"decision": Decision.USE_SKILL, "target": p_enemy}
		"explore", "wander":
			return {"decision": Decision.EXPLORE, "target": null}
		_:
			# Unknown decision type - use distance-based fallback
			if p_enemy != null:
				if in_range:
					return {"decision": Decision.ATTACK, "target": p_enemy}
				return {"decision": Decision.MOVE_TO_TARGET, "target": p_enemy.position}
			return {"decision": Decision.IDLE, "target": null}


## Calculate threat level of enemy
func _calculate_threat_level(p_self, p_enemy) -> float:
	if p_enemy == null:
		return 0.0
	var hp_ratio = float(p_enemy.current_hp) / float(p_enemy.max_hp)
	var atk_ratio = float(p_enemy.attack_damage) / float(p_self.max_hp)
	return clamp(hp_ratio * 0.5 + atk_ratio * 0.5, 0.0, 1.0)


## Fallback decision when Ember SDK not available
func _fallback_decide(p_self, p_enemy) -> Dictionary:
	var distance = 0.0
	if p_enemy != null:
		distance = p_self.position.distance_to(p_enemy.position)
	var hp_ratio = float(p_self.current_hp) / float(p_self.max_hp)

	if hp_ratio < 0.2:
		return {"decision": Decision.RETREAT, "target": null}
	if distance <= p_self.attack_range:
		return {"decision": Decision.ATTACK, "target": p_enemy}
	return {"decision": Decision.MOVE_TO_TARGET, "target": p_enemy.position if p_enemy != null else null}


## Execute the current decision on the unit
func execute_decision(p_self, p_enemy) -> void:
	var dist: float = -1.0
	if p_enemy != null:
		dist = p_self.position.distance_to(p_enemy.position)
	GameLog.debug("Ember AI: %s decision=%s dist=%.1f" % [
		p_self.soul_name, _decision_name(current_decision), dist
	], "Arena")

	# Get tactical command weights from RTSArenaManager (GDD v2.0 Chapter 2.1.1)
	var tactical_cmd: String = RTSArenaManager.current_tactical_command
	var attack_weight: float = RTSArenaManager.get_tactical_weight("attack_priority", 1.0)
	var chase_weight: float = RTSArenaManager.get_tactical_weight("chase_range", 1.0)
	var evade_weight: float = RTSArenaManager.get_tactical_weight("evade_priority", 1.0)
	var keep_dist_weight: float = RTSArenaManager.get_tactical_weight("keep_distance", 1.0)

	# RETREAT command: always retreat regardless of other factors
	if tactical_cmd == "retreat" and p_enemy != null:
		var retreat_dir: Vector2 = (p_self.position - p_enemy.position).normalized()
		p_self.move_to(p_self.position + retreat_dir * 200.0)
		return

	# Calculate effective attack range based on chase weight
	var effective_range: float = p_self.attack_range * chase_weight

	# Priority override: if enemy is in effective attack range, attack immediately
	# This prevents units from wandering while in range due to stale decision (1.5s decision interval)
	if p_enemy != null and is_instance_valid(p_enemy) and dist <= effective_range:
		# DEFENSIVE command: keep distance, only attack if very close
		if tactical_cmd == "defensive" and dist < p_self.attack_range * 0.7:
			p_self.set_attack_target(p_enemy)
		elif tactical_cmd != "defensive":
			p_self.set_attack_target(p_enemy)
		return

	# DEFENSIVE command: keep distance from enemy
	if tactical_cmd == "defensive" and p_enemy != null and dist < p_self.attack_range * keep_dist_weight:
		var away_dir: Vector2 = (p_self.position - p_enemy.position).normalized()
		p_self.move_to(p_self.position + away_dir * 100.0, false)
		return

	match current_decision:
		Decision.ATTACK:
			if p_enemy != null and dist <= effective_range:
				p_self.set_attack_target(p_enemy)
			else:
				p_self.move_to(p_enemy.position, false)  # Keep attack_target while closing in
		Decision.USE_SKILL:
			_use_best_skill(p_self, p_enemy)
		Decision.DEFEND:
			if p_self.skill_cooldowns.get("defend", 999) <= 0:
				p_self.use_skill("defend")
		Decision.RETREAT:
			if p_enemy != null:
				var retreat_dir: Vector2 = (p_self.position - p_enemy.position).normalized()
				p_self.move_to(p_self.position + retreat_dir * 200.0)
		Decision.EXPLORE:
			var random_dir: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			p_self.move_to(p_self.position + random_dir * 150.0)
		Decision.MOVE_TO_TARGET:
			if decision_target != null:
				p_self.move_to(decision_target, false)  # Keep attack_target while moving


## Use the best available skill based on state
func _use_best_skill(p_self, p_enemy) -> void:
	var hp_ratio: float = float(p_self.current_hp) / float(p_self.max_hp)
	var aggression: float = float(p_self.personality.get("aggression", 50)) / 100.0

	if hp_ratio < 0.4 and p_self.skill_cooldowns.get("heal", 999) <= 0:
		p_self.use_skill("heal", p_self)
		return
	if hp_ratio < 0.6 and p_self.skill_cooldowns.get("defend", 999) <= 0:
		p_self.use_skill("defend")
		return
	if p_enemy != null and p_self.position.distance_to(p_enemy.position) <= p_self.attack_range:
		if aggression > 0.6 and p_self.skill_cooldowns.get("heavy_strike", 999) <= 0:
			p_self.use_skill("heavy_strike", p_enemy)
		elif p_self.skill_cooldowns.get("quick_strike", 999) <= 0:
			p_self.use_skill("quick_strike", p_enemy)


## Check if soul should follow player command
func _should_follow_command(p_self) -> bool:
	var loyalty: float = float(p_self.personality.get("loyalty", 50)) / 100.0
	var courage: float = float(p_self.personality.get("courage", 50)) / 100.0
	var obey_chance: float = 0.5 + loyalty * 0.4
	if player_command == "retreat":
		obey_chance += (1.0 - courage) * 0.2
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


## Issue a player command
func issue_command(p_command: String, p_target: Vector2 = Vector2.ZERO) -> bool:
	if command_cooldown > 0:
		return false
	var valid_commands = ["gather", "attack", "defend", "retreat"]
	if not valid_commands.has(p_command):
		return false
	player_command = p_command
	player_command_target = p_target
	command_cooldown = COMMAND_COOLDOWN
	return true


## Update emotional state based on battle events
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

	p_self.emotion["anger"] = clamp(p_self.emotion["anger"] - 0.005, 0.0, 1.0)
	p_self.emotion["fear"] = clamp(p_self.emotion["fear"] - 0.005, 0.0, 1.0)
	p_self.emotion["excitement"] = clamp(p_self.emotion["excitement"] - 0.003, 0.0, 1.0)

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
			player_command = ""


## Get AI state info for debugging/UI
func get_state_info() -> Dictionary:
	return {
		"decision": current_decision,
		"player_command": player_command,
		"command_cooldown": command_cooldown,
		"last_command_obeyed": last_command_obeyed,
		"decision_cooldown": decision_cooldown,
		"ember_available": _ember_initialized,
		"last_ember_decision": last_ember_decision
	}


## Helper: get decision name for logging
func _decision_name(p_decision: int) -> String:
	match p_decision:
		Decision.IDLE: return "IDLE"
		Decision.MOVE_TO_TARGET: return "MOVE_TO_TARGET"
		Decision.ATTACK: return "ATTACK"
		Decision.USE_SKILL: return "USE_SKILL"
		Decision.DEFEND: return "DEFEND"
		Decision.RETREAT: return "RETREAT"
		Decision.EXPLORE: return "EXPLORE"
		Decision.FOLLOW_COMMAND: return "FOLLOW_COMMAND"
	return "UNKNOWN(%d)" % p_decision
