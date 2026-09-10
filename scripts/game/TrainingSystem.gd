extends Node
## TrainingSystem - Manages soul training in the Soul Home training room
## Follows GDD v2.0 Chapter 8: Soul Home (Training Ground)
## M2.8 Soul Home - Training System

## Training types
const TRAINING_TYPES := {
	"attack": {
		"name": "攻击训练",
		"description": "提升攻击力和暴击率",
		"icon_index": 0,
		"duration": 30.0,  # seconds
		"stat_boost": {"attack": 1, "crit": 0.005},
		"exp_reward": 20,
		"cooldown": 60.0
	},
	"defense": {
		"name": "防御训练",
		"description": "提升防御力和生命值",
		"icon_index": 1,
		"duration": 30.0,
		"stat_boost": {"defense": 0.01, "health": 5},
		"exp_reward": 20,
		"cooldown": 60.0
	},
	"speed": {
		"name": "速度训练",
		"description": "提升移动速度和反应速度",
		"icon_index": 2,
		"duration": 25.0,
		"stat_boost": {"speed": 2, "reaction": 0.02},
		"exp_reward": 15,
		"cooldown": 45.0
	},
	"skill": {
		"name": "技能训练",
		"description": "提升技能伤害和能量回复",
		"icon_index": 3,
		"duration": 35.0,
		"stat_boost": {"skill": 0.02, "energy": 3},
		"exp_reward": 25,
		"cooldown": 70.0
	},
	"stamina": {
		"name": "体能训练",
		"description": "提升生命值和能量上限",
		"icon_index": 4,
		"duration": 40.0,
		"stat_boost": {"health": 10, "energy": 5},
		"exp_reward": 30,
		"cooldown": 90.0
	},
	"meditation": {
		"name": "冥想训练",
		"description": "提升认知能力和专注度",
		"icon_index": 5,
		"duration": 45.0,
		"stat_boost": {"focus": 0.03, "cognitive": 1},
		"exp_reward": 35,
		"cooldown": 120.0
	}
}

## Current training state
var _current_training: String = ""
var _training_progress: float = 0.0
var _training_active: bool = false
var _training_cooldowns: Dictionary = {}

## Total training sessions completed
var _total_sessions: int = 0

## Training statistics
var _training_stats: Dictionary = {
	"attack": 0,
	"defense": 0,
	"speed": 0,
	"skill": 0,
	"stamina": 0,
	"meditation": 0
}

## Save file path
const SAVE_PATH := "user://soul_training.save"

## Signal emitted when training starts
signal training_started(training_type)

## Signal emitted when training completes
signal training_completed(training_type, rewards)

## Signal emitted when training progress updates
signal training_progress(progress, duration)


func _process(delta: float) -> void:
	if _training_active and not _current_training.is_empty():
		var training = TRAINING_TYPES.get(_current_training, null)
		if training:
			_training_progress += delta
			training_progress.emit(_training_progress, training["duration"])
			if _training_progress >= training["duration"]:
				_complete_training()


## Start a training session
func start_training(training_type: String) -> bool:
	if _training_active:
		return false
	if not TRAINING_TYPES.has(training_type):
		return false
	# Check cooldown
	if _training_cooldowns.has(training_type):
		if _training_cooldowns[training_type] > 0:
			return false
	_current_training = training_type
	_training_progress = 0.0
	_training_active = true
	training_started.emit(training_type)
	return true


## Complete current training
func _complete_training() -> void:
	var training_type = _current_training
	var training = TRAINING_TYPES.get(training_type, null)
	if training == null:
		_training_active = false
		_current_training = ""
		return
	# Apply rewards
	var rewards = {
		"exp": training["exp_reward"],
		"stat_boost": training["stat_boost"].duplicate()
	}
	# Update stats
	_training_stats[training_type] += 1
	_total_sessions += 1
	# Set cooldown
	_training_cooldowns[training_type] = training["cooldown"]
	# Reset training state
	_training_active = false
	_current_training = ""
	_training_progress = 0.0
	training_completed.emit(training_type, rewards)
	_save_data()


## Cancel current training
func cancel_training() -> void:
	if _training_active:
		_training_active = false
		_current_training = ""
		_training_progress = 0.0


## Get current training type
func get_current_training() -> String:
	return _current_training


## Get training progress (0.0 - 1.0)
func get_training_progress() -> float:
	if not _training_active or _current_training.is_empty():
		return 0.0
	var training = TRAINING_TYPES.get(_current_training, null)
	if training == null:
		return 0.0
	return min(1.0, _training_progress / training["duration"])


## Get training time remaining
func get_time_remaining() -> float:
	if not _training_active or _current_training.is_empty():
		return 0.0
	var training = TRAINING_TYPES.get(_current_training, null)
	if training == null:
		return 0.0
	return max(0.0, training["duration"] - _training_progress)


## Is training active
func is_training_active() -> bool:
	return _training_active


## Get training cooldown for a type
func get_cooldown(training_type: String) -> float:
	return _training_cooldowns.get(training_type, 0.0)


## Is training type available (not on cooldown and not active)
func is_available(training_type: String) -> bool:
	if _training_active:
		return false
	if not TRAINING_TYPES.has(training_type):
		return false
	return _training_cooldowns.get(training_type, 0.0) <= 0.0


## Get all training types
func get_all_training_types() -> Dictionary:
	return TRAINING_TYPES.duplicate()


## Get training type info
func get_training_type(training_type: String) -> Dictionary:
	return TRAINING_TYPES.get(training_type, {})


## Get total sessions
func get_total_sessions() -> int:
	return _total_sessions


## Get training stats for a type
func get_training_stat(training_type: String) -> int:
	return _training_stats.get(training_type, 0)


## Get all training stats
func get_all_training_stats() -> Dictionary:
	return _training_stats.duplicate()


## Get total stat bonuses from all training
func get_total_stat_bonuses() -> Dictionary:
	var bonuses = {
		"attack": 0,
		"defense": 0.0,
		"speed": 0,
		"skill": 0.0,
		"health": 0,
		"energy": 0,
		"crit": 0.0,
		"focus": 0.0,
		"cognitive": 0,
		"reaction": 0.0
	}
	for training_type in _training_stats.keys():
		var count = _training_stats[training_type]
		var training = TRAINING_TYPES.get(training_type, null)
		if training == null:
			continue
		for stat in training["stat_boost"].keys():
			if bonuses.has(stat):
				bonuses[stat] += training["stat_boost"][stat] * count
	return bonuses


## Update cooldowns (call from _process in controller)
func update_cooldowns(delta: float) -> void:
	for training_type in _training_cooldowns.keys():
		if _training_cooldowns[training_type] > 0:
			_training_cooldowns[training_type] -= delta
			if _training_cooldowns[training_type] < 0:
				_training_cooldowns[training_type] = 0.0


## Reset all training (for testing)
func reset_all() -> void:
	_current_training = ""
	_training_progress = 0.0
	_training_active = false
	_training_cooldowns = {}
	_total_sessions = 0
	_training_stats = {
		"attack": 0,
		"defense": 0,
		"speed": 0,
		"skill": 0,
		"stamina": 0,
		"meditation": 0
	}
	_save_data()


## Save training data to file
func _save_data() -> void:
	var save_data = {
		"total_sessions": _total_sessions,
		"training_stats": _training_stats,
		"training_cooldowns": _training_cooldowns
	}
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(save_data))
		f.close()


## Load training data from file
func _load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f:
		var json_string = f.get_as_text()
		f.close()
		var parsed = JSON.parse_string(json_string)
		if parsed != null and typeof(parsed) == TYPE_DICTIONARY:
			if parsed.has("total_sessions"):
				_total_sessions = parsed["total_sessions"]
			if parsed.has("training_stats"):
				for key in _training_stats.keys():
					if parsed["training_stats"].has(key):
						_training_stats[key] = parsed["training_stats"][key]
			if parsed.has("training_cooldowns"):
				_training_cooldowns = parsed["training_cooldowns"]


func _ready() -> void:
	_load_data()
