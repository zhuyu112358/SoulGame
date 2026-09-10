extends Node
## TrainingBattleSystem - Manages training battle statistics and history
## Follows GDD v2.0 Chapter 11: Battle Modes
## M2.11 Battle Modes - Training Battle Statistics
##
## Tracks training battle results: win/loss, win rate, streaks, per-difficulty stats.
## Persists to user://training_stats.cfg

## Training stats file path
const STATS_FILE := "user://training_stats.cfg"

## Statistics data
var _total_battles: int = 0
var _total_wins: int = 0
var _total_losses: int = 0
var _current_streak: int = 0
var _best_streak: int = 0
var _total_battle_time: float = 0.0

## Per-difficulty statistics
var _difficulty_stats: Dictionary = {
	"easy": {"battles": 0, "wins": 0, "losses": 0},
	"normal": {"battles": 0, "wins": 0, "losses": 0},
	"hard": {"battles": 0, "wins": 0, "losses": 0},
	"nightmare": {"battles": 0, "wins": 0, "losses": 0}
}

## Recent battle history (last 20)
var _battle_history: Array = []

## Maximum history entries
const MAX_HISTORY := 20


## Record a training battle result
func record_battle_result(p_won: bool, p_difficulty: String, p_battle_time: float, p_player_soul: Dictionary = {}, p_ai_soul: Dictionary = {}) -> void:
	_total_battles += 1
	_total_battle_time += p_battle_time

	if p_won:
		_total_wins += 1
		_current_streak += 1
		if _current_streak > _best_streak:
			_best_streak = _current_streak
	else:
		_total_losses += 1
		_current_streak = 0

	# Per-difficulty stats
	if _difficulty_stats.has(p_difficulty):
		_difficulty_stats[p_difficulty]["battles"] += 1
		if p_won:
			_difficulty_stats[p_difficulty]["wins"] += 1
		else:
			_difficulty_stats[p_difficulty]["losses"] += 1

	# Add to history
	var entry: Dictionary = {
		"timestamp": Time.get_datetime_string_from_system(),
		"won": p_won,
		"difficulty": p_difficulty,
		"battle_time": p_battle_time,
		"player_element": p_player_soul.get("element", "unknown"),
		"ai_element": p_ai_soul.get("element", "unknown")
	}
	_battle_history.push_front(entry)
	if _battle_history.size() > MAX_HISTORY:
		_battle_history.pop_back()

	GameLog.info("TrainingBattle: %s vs %s difficulty - %s (streak: %d)" % [
		p_player_soul.get("element", "?"), p_difficulty,
		"Victory" if p_won else "Defeat", _current_streak
	], "Training")

	_save_stats()


## Get overall statistics
func get_overall_stats() -> Dictionary:
	var win_rate: float = 0.0
	if _total_battles > 0:
		win_rate = float(_total_wins) / float(_total_battles) * 100.0

	return {
		"total_battles": _total_battles,
		"total_wins": _total_wins,
		"total_losses": _total_losses,
		"win_rate": win_rate,
		"current_streak": _current_streak,
		"best_streak": _best_streak,
		"total_battle_time": _total_battle_time,
		"avg_battle_time": _total_battle_time / _total_battles if _total_battles > 0 else 0.0
	}


## Get per-difficulty statistics
func get_difficulty_stats(p_difficulty: String = "") -> Dictionary:
	if p_difficulty == "":
		return _difficulty_stats.duplicate(true)
	return _difficulty_stats.get(p_difficulty, {}).duplicate()


## Get difficulty win rate
func get_difficulty_win_rate(p_difficulty: String) -> float:
	var stats = _difficulty_stats.get(p_difficulty, {})
	var battles: int = stats.get("battles", 0)
	if battles == 0:
		return 0.0
	return float(stats.get("wins", 0)) / float(battles) * 100.0


## Get battle history
func get_battle_history(p_count: int = 10) -> Array:
	var count = min(p_count, _battle_history.size())
	return _battle_history.slice(0, count)


## Get recent wins count
func get_recent_wins(p_count: int = 10) -> int:
	var count = min(p_count, _battle_history.size())
	var wins = 0
	for i in count:
		if _battle_history[i].get("won", false):
			wins += 1
	return wins


## Get rank based on win rate and battles
func get_rank() -> Dictionary:
	var stats = get_overall_stats()
	var win_rate = stats["win_rate"]
	var battles = stats["total_battles"]

	var rank_name = "新手"
	var rank_color = Color(0.6, 0.6, 0.6)
	var rank_icon = "ui_rank_rookie"

	if battles >= 50 and win_rate >= 70:
		rank_name = "传奇指挥官"
		rank_color = Color(1.0, 0.85, 0.3)
		rank_icon = "ui_rank_legend"
	elif battles >= 30 and win_rate >= 60:
		rank_name = "精英指挥官"
		rank_color = Color(0.8, 0.4, 0.9)
		rank_icon = "ui_rank_elite"
	elif battles >= 20 and win_rate >= 50:
		rank_name = "资深指挥官"
		rank_color = Color(0.4, 0.7, 1.0)
		rank_icon = "ui_rank_veteran"
	elif battles >= 10:
		rank_name = "熟练指挥官"
		rank_color = Color(0.4, 0.9, 0.5)
		rank_icon = "ui_rank_skilled"
	elif battles >= 5:
		rank_name = "初级指挥官"
		rank_color = Color(0.9, 0.7, 0.3)
		rank_icon = "ui_rank_beginner"

	return {
		"name": rank_name,
		"color": rank_color,
		"icon": rank_icon,
		"win_rate": win_rate,
		"battles": battles
	}


## Save statistics to file
func _save_stats() -> void:
	var config = ConfigFile.new()
	config.set_value("overall", "total_battles", _total_battles)
	config.set_value("overall", "total_wins", _total_wins)
	config.set_value("overall", "total_losses", _total_losses)
	config.set_value("overall", "current_streak", _current_streak)
	config.set_value("overall", "best_streak", _best_streak)
	config.set_value("overall", "total_battle_time", _total_battle_time)

	for diff in _difficulty_stats.keys():
		var stats = _difficulty_stats[diff]
		config.set_value("difficulty_" + diff, "battles", stats["battles"])
		config.set_value("difficulty_" + diff, "wins", stats["wins"])
		config.set_value("difficulty_" + diff, "losses", stats["losses"])

	config.set_value("history", "count", _battle_history.size())
	for i in _battle_history.size():
		var entry = _battle_history[i]
		config.set_value("history_" + str(i), "timestamp", entry["timestamp"])
		config.set_value("history_" + str(i), "won", entry["won"])
		config.set_value("history_" + str(i), "difficulty", entry["difficulty"])
		config.set_value("history_" + str(i), "battle_time", entry["battle_time"])
		config.set_value("history_" + str(i), "player_element", entry["player_element"])
		config.set_value("history_" + str(i), "ai_element", entry["ai_element"])

	var err = config.save(STATS_FILE)
	if err != OK:
		GameLog.warning("TrainingBattle: Failed to save stats: %d" % err, "Training")


## Load statistics from file
func load_stats() -> void:
	var config = ConfigFile.new()
	var err = config.load(STATS_FILE)
	if err != OK:
		GameLog.info("TrainingBattle: No saved stats found, starting fresh", "Training")
		return

	_total_battles = config.get_value("overall", "total_battles", 0)
	_total_wins = config.get_value("overall", "total_wins", 0)
	_total_losses = config.get_value("overall", "total_losses", 0)
	_current_streak = config.get_value("overall", "current_streak", 0)
	_best_streak = config.get_value("overall", "best_streak", 0)
	_total_battle_time = config.get_value("overall", "total_battle_time", 0.0)

	for diff in _difficulty_stats.keys():
		var section = "difficulty_" + diff
		if config.has_section(section):
			_difficulty_stats[diff]["battles"] = config.get_value(section, "battles", 0)
			_difficulty_stats[diff]["wins"] = config.get_value(section, "wins", 0)
			_difficulty_stats[diff]["losses"] = config.get_value(section, "losses", 0)

	var history_count = config.get_value("history", "count", 0)
	_battle_history.clear()
	for i in history_count:
		var section = "history_" + str(i)
		if config.has_section(section):
			_battle_history.append({
				"timestamp": config.get_value(section, "timestamp", ""),
				"won": config.get_value(section, "won", false),
				"difficulty": config.get_value(section, "difficulty", "normal"),
				"battle_time": config.get_value(section, "battle_time", 0.0),
				"player_element": config.get_value(section, "player_element", "unknown"),
				"ai_element": config.get_value(section, "ai_element", "unknown")
			})

	GameLog.info("TrainingBattle: Stats loaded - %d battles, %.1f%% win rate" % [
		_total_battles, get_overall_stats()["win_rate"]
	], "Training")


## Reset all statistics
func reset_stats() -> void:
	_total_battles = 0
	_total_wins = 0
	_total_losses = 0
	_current_streak = 0
	_best_streak = 0
	_total_battle_time = 0.0
	for diff in _difficulty_stats.keys():
		_difficulty_stats[diff] = {"battles": 0, "wins": 0, "losses": 0}
	_battle_history.clear()
	_save_stats()
	GameLog.info("TrainingBattle: All stats reset", "Training")


## Initialize on ready
func _ready() -> void:
	load_stats()
