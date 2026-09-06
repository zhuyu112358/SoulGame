extends Node
## BattleResultManager - Handles battle results and soul growth feedback
##
## Processes battle outcomes, calculates experience rewards, updates soul
## growth data, and maintains battle history/statistics.
##
## This is game-specific logic for M2 RTS arena, not SDK kernel code.

## Battle history record structure
## {battle_id, timestamp, player_soul_id, opponent_soul_id, result,
##  player_hp_remaining, opponent_hp_remaining, duration, experience_gained,
##  skills_used, damage_dealt, damage_taken}

## Battle history (all past battles)
var battle_history: Array = []

## Battle statistics
var stats: Dictionary = {
	"total_battles": 0,
	"victories": 0,
	"defeats": 0,
	"draws": 0,
	"win_rate": 0.0,
	"total_experience_gained": 0,
	"total_damage_dealt": 0,
	"total_damage_taken": 0,
	"current_streak": 0,
	"best_streak": 0
}

## Experience reward configuration
var exp_config: Dictionary = {
	"victory_base": 50,
	"defeat_base": 15,
	"draw_base": 25,
	"level_difference_bonus": 5,  # per level difference when winning
	"hp_remaining_bonus": 0.2,    # bonus multiplier based on HP remaining
	"quick_battle_bonus": 10,     # bonus for winning under 30 seconds
	"comeback_bonus": 20          # bonus for winning with <30% HP
}

## Signal for battle result processed
signal battle_result_processed(result_data)
signal soul_growth_updated(soul_id, experience_gained, leveled_up)
signal stats_updated(new_stats)


func _ready() -> void:
	GameLog.info("BattleResultManager: Initialized", "Arena")
	_load_history()


## Process a battle result and apply growth feedback
func process_battle_result(p_battle_data: Dictionary) -> Dictionary:
	GameLog.info("BattleResultManager: Processing battle result - %s" % p_battle_data.get("result", "unknown"), "Arena")

	# Play battle result open sound
	AudioManager.play_ui("battle_result_open")

	var result: String = p_battle_data.get("result", "draw")
	var player_soul_id: String = p_battle_data.get("player_soul_id", "")
	var opponent_soul_id: String = p_battle_data.get("opponent_soul_id", "")
	var player_level: int = p_battle_data.get("player_level", 1)
	var opponent_level: int = p_battle_data.get("opponent_level", 1)
	var player_hp_remaining: int = p_battle_data.get("player_hp_remaining", 0)
	var player_max_hp: int = p_battle_data.get("player_max_hp", 100)
	var duration: float = p_battle_data.get("duration", 0.0)
	var damage_dealt: int = p_battle_data.get("damage_dealt", 0)
	var damage_taken: int = p_battle_data.get("damage_taken", 0)
	var skills_used: Array = p_battle_data.get("skills_used", [])

	# Calculate experience gained
	var experience_gained: int = _calculate_experience(
		result, player_level, opponent_level,
		player_hp_remaining, player_max_hp, duration
	)

	# Create battle record
	var battle_record: Dictionary = {
		"battle_id": "battle_%d" % Time.get_unix_time_from_system(),
		"timestamp": Time.get_datetime_string_from_system(),
		"player_soul_id": player_soul_id,
		"opponent_soul_id": opponent_soul_id,
		"result": result,
		"player_level": player_level,
		"opponent_level": opponent_level,
		"player_hp_remaining": player_hp_remaining,
		"player_max_hp": player_max_hp,
		"duration": duration,
		"experience_gained": experience_gained,
		"skills_used": skills_used,
		"damage_dealt": damage_dealt,
		"damage_taken": damage_taken
	}

	# Add to history
	battle_history.append(battle_record)

	# Update statistics
	_update_stats(result, experience_gained, damage_dealt, damage_taken)

	# Update soul growth data
	var leveled_up: bool = false
	if player_soul_id != "":
		leveled_up = _update_soul_growth(player_soul_id, experience_gained, result)

	# Save history
	_save_history()

	var result_data: Dictionary = {
		"battle_record": battle_record,
		"experience_gained": experience_gained,
		"leveled_up": leveled_up,
		"stats": stats.duplicate()
	}

	emit_signal("battle_result_processed", result_data)
	GameLog.info("BattleResultManager: Battle processed - %s, EXP: +%d, Level up: %s" % [
		result, experience_gained, str(leveled_up)
	], "Arena")

	# Play victory sound on win
	if result == "win":
		AudioManager.play_ui("battle_victory")

	return result_data


## Calculate experience gained based on battle factors
func _calculate_experience(p_result: String, p_player_level: int, p_opponent_level: int,
		p_hp_remaining: int, p_max_hp: int, p_duration: float) -> int:
	var base_exp: int = 0

	match p_result:
		"victory":
			base_exp = exp_config["victory_base"]
			# Level difference bonus (bonus for defeating higher level opponent)
			var level_diff: int = p_opponent_level - p_player_level
			if level_diff > 0:
				base_exp += level_diff * exp_config["level_difference_bonus"]
			# HP remaining bonus
			var hp_ratio: float = float(p_hp_remaining) / float(p_max_hp)
			base_exp += int(base_exp * hp_ratio * exp_config["hp_remaining_bonus"])
			# Quick battle bonus
			if p_duration < 30.0:
				base_exp += exp_config["quick_battle_bonus"]
			# Comeback bonus (won with low HP)
			if hp_ratio < 0.3:
				base_exp += exp_config["comeback_bonus"]
		"defeat":
			base_exp = exp_config["defeat_base"]
			# Bonus for taking down higher level opponent's HP
			var level_diff: int = p_opponent_level - p_player_level
			if level_diff > 0:
				base_exp += level_diff * 2
		"draw":
			base_exp = exp_config["draw_base"]

	return max(1, base_exp)


## Update soul growth data
func _update_soul_growth(p_soul_id: String, p_experience: int, p_result: String) -> bool:
	# Find soul in SoulManager
	var soul = null
	if SoulManager.has_method("get_soul"):
		soul = SoulManager.get_soul(p_soul_id)

	if soul == null:
		GameLog.warning("BattleResultManager: Soul %s not found for growth update" % p_soul_id, "Arena")
		return false

	var leveled_up: bool = false

	# Add experience
	if soul.has_method("add_experience"):
		leveled_up = soul.add_experience(p_experience)
	elif "growth_data" in soul and soul.growth_data != null:
		if soul.growth_data.has_method("add_experience"):
			leveled_up = soul.growth_data.add_experience(p_experience)

	# Apply battle-specific growth bonuses
	_apply_battle_growth(soul, p_result)

	emit_signal("soul_growth_updated", p_soul_id, p_experience, leveled_up)

	return leveled_up


## Apply battle-specific growth to soul attributes
func _apply_battle_growth(p_soul, p_result: String) -> void:
	# This is a simplified growth system - actual implementation would
	# use SoulArena SDK cognitive ability mapping
	if p_soul == null:
		return

	var growth_data = null
	if p_soul.has_method("get_growth_data"):
		growth_data = p_soul.get_growth_data()
	elif "growth_data" in p_soul:
		growth_data = p_soul.growth_data

	if growth_data == null:
		return

	# Victory boosts confidence/decision, defeat boosts resilience
	match p_result:
		"victory":
			_growth_skill(growth_data, "decision", 1)
			_growth_skill(growth_data, "confidence", 1)
		"defeat":
			_growth_skill(growth_data, "resilience", 1)
			_growth_skill(growth_data, "endurance", 1)
		"draw":
			_growth_skill(growth_data, "balance", 1)


## Helper to grow a skill by amount
func _growth_skill(p_growth_data, p_skill_name: String, p_amount: int) -> void:
	if p_growth_data == null:
		return
	if p_growth_data.skills.has(p_skill_name):
		var current_level = p_growth_data.skills[p_skill_name].get("level", 1)
		p_growth_data.skills[p_skill_name]["level"] = current_level + p_amount
		GameLog.debug("BattleResultManager: Skill %s leveled to %d" % [p_skill_name, current_level + p_amount], "Arena")


## Update battle statistics
func _update_stats(p_result: String, p_experience: int, p_damage_dealt: int, p_damage_taken: int) -> void:
	stats["total_battles"] += 1
	stats["total_experience_gained"] += p_experience
	stats["total_damage_dealt"] += p_damage_dealt
	stats["total_damage_taken"] += p_damage_taken

	match p_result:
		"victory":
			stats["victories"] += 1
			stats["current_streak"] += 1
			if stats["current_streak"] > stats["best_streak"]:
				stats["best_streak"] = stats["current_streak"]
		"defeat":
			stats["defeats"] += 1
			stats["current_streak"] = 0
		"draw":
			stats["draws"] += 1
			stats["current_streak"] = 0

	# Calculate win rate
	if stats["total_battles"] > 0:
		stats["win_rate"] = float(stats["victories"]) / float(stats["total_battles"]) * 100.0

	emit_signal("stats_updated", stats.duplicate())


## Get battle history
func get_history(p_limit: int = 20) -> Array:
	if battle_history.size() <= p_limit:
		return battle_history.duplicate()
	return battle_history.slice(battle_history.size() - p_limit, battle_history.size())


## Get statistics
func get_stats() -> Dictionary:
	return stats.duplicate()


## Get win/loss record for a specific soul
func get_soul_record(p_soul_id: String) -> Dictionary:
	var record: Dictionary = {
		"battles": 0,
		"victories": 0,
		"defeats": 0,
		"draws": 0,
		"win_rate": 0.0,
		"total_experience": 0
	}

	for battle in battle_history:
		if battle.get("player_soul_id", "") == p_soul_id:
			record["battles"] += 1
			record["total_experience"] += battle.get("experience_gained", 0)
			match battle.get("result", ""):
				"victory": record["victories"] += 1
				"defeat": record["defeats"] += 1
				"draw": record["draws"] += 1

	if record["battles"] > 0:
		record["win_rate"] = float(record["victories"]) / float(record["battles"]) * 100.0

	return record


## Save battle history to disk
func _save_history() -> void:
	var save_data: Dictionary = {
		"battle_history": battle_history,
		"stats": stats
	}
	SaveSystem.set_setting("arena", "battle_history", JSON.stringify(save_data))
	GameLog.debug("BattleResultManager: History saved (%d battles)" % battle_history.size(), "Arena")


## Load battle history from disk
func _load_history() -> void:
	var saved_json = SaveSystem.get_setting("arena", "battle_history", "")
	if saved_json != "" and typeof(saved_json) == TYPE_STRING:
		var parsed = JSON.parse_string(saved_json)
		if parsed != null and typeof(parsed) == TYPE_DICTIONARY:
			if parsed.has("battle_history"):
				battle_history = parsed["battle_history"]
			if parsed.has("stats"):
				stats = parsed["stats"]
	GameLog.info("BattleResultManager: History loaded (%d battles)" % battle_history.size(), "Arena")


## Clear all battle history
func clear_history() -> void:
	battle_history.clear()
	stats = {
		"total_battles": 0,
		"victories": 0,
		"defeats": 0,
		"draws": 0,
		"win_rate": 0.0,
		"total_experience_gained": 0,
		"total_damage_dealt": 0,
		"total_damage_taken": 0,
		"current_streak": 0,
		"best_streak": 0
	}
	_save_history()
	GameLog.info("BattleResultManager: History cleared", "Arena")
