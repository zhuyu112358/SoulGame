extends Node
## MatchmakingSystem - Random battle matchmaking system
## Follows GDD v2.0 Chapter 11: Battle Modes
## M2.11 Battle Modes - Random Matchmaking
##
## Simulates online matchmaking for single-player game.
## Randomly selects AI difficulty and opponent soul, then starts battle.

## AIDifficultySystem preload
const AIDifficultySystem = preload("res://scripts/game/AIDifficultySystem.gd")

## Matchmaking states
enum MatchState {
	IDLE,           # Not matchmaking
	SEARCHING,      # Searching for opponent
	MATCH_FOUND,    # Opponent found
	CANCELLED,      # Matchmaking cancelled
	FAILED          # Matchmaking failed
}

## Current matchmaking state
var _state: int = MatchState.IDLE

## Matchmaking timer
var _match_timer: float = 0.0

## Minimum match time (seconds)
var _min_match_time: float = 3.0

## Maximum match time (seconds)
var _max_match_time: float = 8.0

## Target match time (randomized)
var _target_match_time: float = 5.0

## Selected opponent data
var _opponent_data: Dictionary = {}

## Matchmaking UI reference
var _matchmaking_ui = null

## Signals
signal matchmaking_started()
signal matchmaking_progress(progress: float, elapsed: float)
signal opponent_found(opponent_data: Dictionary)
signal matchmaking_cancelled()
signal matchmaking_failed(reason: String)


func _ready() -> void:
	GameLog.info("MatchmakingSystem: Ready", "Matchmaking")


## Start matchmaking
func start_matchmaking() -> void:
	if _state == MatchState.SEARCHING:
		GameLog.warning("MatchmakingSystem: Already searching", "Matchmaking")
		return

	_state = MatchState.SEARCHING
	_match_timer = 0.0
	_target_match_time = randf_range(_min_match_time, _max_match_time)
	_opponent_data = {}

	matchmaking_started.emit()
	GameLog.info("MatchmakingSystem: Started, target time: %.1fs" % _target_match_time, "Matchmaking")


## Cancel matchmaking
func cancel_matchmaking() -> void:
	if _state != MatchState.SEARCHING:
		return

	_state = MatchState.CANCELLED
	matchmaking_cancelled.emit()
	GameLog.info("MatchmakingSystem: Cancelled", "Matchmaking")


## Process matchmaking timer
func _process(delta: float) -> void:
	if _state != MatchState.SEARCHING:
		return

	_match_timer += delta

	# Emit progress
	var progress = clampf(_match_timer / _target_match_time, 0.0, 1.0)
	matchmaking_progress.emit(progress, _match_timer)

	# Check if match found
	if _match_timer >= _target_match_time:
		_find_opponent()


## Find a random opponent
func _find_opponent() -> void:
	_state = MatchState.MATCH_FOUND

	# Random difficulty selection (weighted: normal most common)
	var difficulties = ["easy", "normal", "normal", "hard", "nightmare"]
	var difficulty = difficulties[randi() % difficulties.size()]

	# Random opponent element
	var elements = ["fire", "water", "earth", "wind", "thunder", "ice", "dark", "light"]
	var element = elements[randi() % elements.size()]

	# Random opponent level (based on player progress)
	var player_level = 1
	if GameState and GameState.has("player"):
		player_level = GameState.get_value("player", "level", 1)
	var opponent_level = clampi(player_level + randi_range(-1, 2), 1, 20)

	# Random opponent name
	var names = ["灵界战士", "暗影猎手", "元素大师", "竞技场老手", "新手指挥官", "灵魂守护者", "风暴使者", "寒冰法师"]
	var name = names[randi() % names.size()]

	_opponent_data = {
		"name": name,
		"element": element,
		"level": opponent_level,
		"difficulty": difficulty,
		"is_ai": true,
		"match_time": _match_timer
	}

	opponent_found.emit(_opponent_data)
	GameLog.info("MatchmakingSystem: Opponent found - %s (%s, Lv.%d, %s)" % [
		name, element, opponent_level, difficulty
	], "Matchmaking")


## Get current state
func get_state() -> int:
	return _state


## Get state name
func get_state_name() -> String:
	match _state:
		MatchState.IDLE:
			return "空闲"
		MatchState.SEARCHING:
			return "搜索中"
		MatchState.MATCH_FOUND:
			return "已找到对手"
		MatchState.CANCELLED:
			return "已取消"
		MatchState.FAILED:
			return "失败"
	return "未知"


## Get opponent data
func get_opponent_data() -> Dictionary:
	return _opponent_data.duplicate()


## Get match progress (0.0 - 1.0)
func get_progress() -> float:
	if _state != MatchState.SEARCHING:
		return 0.0
	return clampf(_match_timer / _target_match_time, 0.0, 1.0)


## Get elapsed time
func get_elapsed_time() -> float:
	return _match_timer


## Start battle with matched opponent
func start_battle_with_opponent() -> void:
	if _state != MatchState.MATCH_FOUND:
		GameLog.warning("MatchmakingSystem: No opponent found", "Matchmaking")
		return

	# Store opponent data for battle config
	if GameState:
		GameState.set_value("battle", "ai_soul", {
			"id": "matched_opponent",
			"name": _opponent_data["name"],
			"element": _opponent_data["element"],
			"level": _opponent_data["level"],
			"is_player": false,
			"difficulty": _opponent_data["difficulty"]
		})
		GameState.set_value("battle", "difficulty", _opponent_data["difficulty"])
		GameState.set_value("battle", "match_type", "random")

	GameLog.info("MatchmakingSystem: Starting battle with opponent", "Matchmaking")


## Reset matchmaking
func reset() -> void:
	_state = MatchState.IDLE
	_match_timer = 0.0
	_opponent_data = {}
