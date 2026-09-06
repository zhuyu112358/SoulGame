extends Node
## RTSArenaManager - Manages real-time strategy arena battles
##
## Handles RTS battle flow: unit spawning, real-time combat, AI control,
## victory/defeat detection, and battle result reporting.
##
## Unlike ArenaManager (turn-based), this manager processes battles in
## real-time using _process(delta). Units move and attack continuously.
##
## This is game-specific logic, not SDK kernel code.

## SoulUnit preload
const SoulUnit = preload("res://scripts/game/SoulUnit.gd")

## Battle state constants
enum BattleState {
	IDLE,
	ACTIVE,
	PAUSED,
	FINISHED
}

## Current battle state
var battle_state: int = BattleState.IDLE

## Player unit
var player_unit: SoulUnit = null

## AI opponent unit
var ai_unit: SoulUnit = null

## Battle configuration
var battle_config: Dictionary = {
	"arena_width": 1280,
	"arena_height": 600,
	"player_spawn": Vector2(200, 300),
	"ai_spawn": Vector2(1080, 300),
	"max_battle_time": 120.0,
	"battle_type": "normal"
}

## Battle timing
var battle_time: float = 0.0
var winner_id: String = ""
var battle_result: String = "pending"

## AI decision timer
var _ai_decision_timer: float = 0.0
var _ai_decision_interval: float = 1.5  # AI makes decision every 1.5 seconds

## Battle log
var battle_log: Array = []

## Signal for battle events
signal battle_started(battle_info)
signal battle_finished(result, winner_id, loser_id)
signal battle_time_updated(time)
signal unit_spawned(unit, is_player)
signal log_added(message)


func _ready() -> void:
	GameLog.info("RTSArenaManager: Initialized", "Arena")


## Start a new RTS battle
func start_battle(p_player_soul: Dictionary, p_ai_soul: Dictionary) -> bool:
	if battle_state == BattleState.ACTIVE:
		GameLog.warning("RTSArenaManager: Battle already active", "Arena")
		return false

	GameLog.info("RTSArenaManager: Starting RTS battle between %s and %s" % [p_player_soul.get("name", "Player"), p_ai_soul.get("name", "AI")], "Arena")

	# Reset state
	battle_state = BattleState.ACTIVE
	battle_time = 0.0
	winner_id = ""
	battle_result = "pending"
	battle_log.clear()

	# Spawn player unit
	player_unit = SoulUnit.new()
	player_unit.init_from_soul(
		p_player_soul.get("id", "player"),
		p_player_soul.get("name", "Player"),
		p_player_soul.get("element", "neutral"),
		p_player_soul.get("level", 1),
		true
	)
	player_unit.position = battle_config["player_spawn"]
	player_unit.unit_died.connect(_on_unit_died)
	add_child(player_unit)
	emit_signal("unit_spawned", player_unit, true)

	# Spawn AI unit
	ai_unit = SoulUnit.new()
	ai_unit.init_from_soul(
		p_ai_soul.get("id", "ai"),
		p_ai_soul.get("name", "AI Opponent"),
		p_ai_soul.get("element", "neutral"),
		p_ai_soul.get("level", 1),
		false
	)
	ai_unit.position = battle_config["ai_spawn"]
	ai_unit.unit_died.connect(_on_unit_died)
	add_child(ai_unit)
	emit_signal("unit_spawned", ai_unit, false)

	# AI starts attacking player
	ai_unit.set_attack_target(player_unit)

	_add_log("Battle started! %s vs %s" % [player_unit.soul_name, ai_unit.soul_name])

	emit_signal("battle_started", {
		"player": player_unit.get_info(),
		"ai": ai_unit.get_info(),
		"config": battle_config
	})

	return true


## Process real-time battle updates
func _process(delta: float) -> void:
	if battle_state != BattleState.ACTIVE:
		return

	battle_time += delta
	emit_signal("battle_time_updated", battle_time)

	# AI decision making
	_ai_decision_timer += delta
	if _ai_decision_timer >= _ai_decision_interval:
		_ai_decision_timer = 0.0
		_update_ai()

	# Check battle time limit
	if battle_time >= battle_config["max_battle_time"]:
		_finish_battle_by_time()


## Update AI behavior
func _update_ai() -> void:
	if ai_unit == null or ai_unit.state == SoulUnit.UnitState.DEAD:
		return

	if player_unit == null or player_unit.state == SoulUnit.UnitState.DEAD:
		return

	var distance: float = ai_unit.position.distance_to(player_unit.position)

	# Simple AI: use skills when available, otherwise basic attack
	var skills: Array = ["heavy_strike", "quick_strike", "heal", "defend"]
	for skill_name in skills:
		if ai_unit.skill_cooldowns.get(skill_name, 999) <= 0:
			if skill_name == "heal" and ai_unit.current_hp < ai_unit.max_hp * 0.4:
				ai_unit.use_skill(skill_name, ai_unit)
				_add_log("%s uses %s!" % [ai_unit.soul_name, skill_name])
				return
			elif skill_name == "defend" and ai_unit.current_hp < ai_unit.max_hp * 0.6:
				ai_unit.use_skill(skill_name)
				_add_log("%s uses %s!" % [ai_unit.soul_name, skill_name])
				return
			elif skill_name in ["heavy_strike", "quick_strike"] and distance <= ai_unit.attack_range:
				ai_unit.use_skill(skill_name, player_unit)
				_add_log("%s uses %s on %s!" % [ai_unit.soul_name, skill_name, player_unit.soul_name])
				return

	# Default: attack player
	if distance <= ai_unit.attack_range:
		ai_unit.set_attack_target(player_unit)
	else:
		ai_unit.move_to(player_unit.position)


## Handle unit death
func _on_unit_died(p_unit: SoulUnit) -> void:
	GameLog.info("RTSArenaManager: %s has been defeated!" % p_unit.soul_name, "Arena")
	_add_log("%s has been defeated!" % p_unit.soul_name)

	if p_unit == player_unit:
		_finish_battle(ai_unit.soul_id, "defeat")
	elif p_unit == ai_unit:
		_finish_battle(player_unit.soul_id, "victory")


## Finish battle by time limit (higher HP wins)
func _finish_battle_by_time() -> void:
	GameLog.info("RTSArenaManager: Battle time limit reached", "Arena")
	_add_log("Time limit reached!")

	if player_unit.current_hp > ai_unit.current_hp:
		_finish_battle(player_unit.soul_id, "victory")
	elif ai_unit.current_hp > player_unit.current_hp:
		_finish_battle(ai_unit.soul_id, "defeat")
	else:
		_finish_battle("", "draw")


## Finish battle
func _finish_battle(p_winner_id: String, p_result: String) -> void:
	battle_state = BattleState.FINISHED
	winner_id = p_winner_id
	battle_result = p_result

	var loser_id: String = ""
	if p_winner_id == player_unit.soul_id:
		loser_id = ai_unit.soul_id
	elif p_winner_id == ai_unit.soul_id:
		loser_id = player_unit.soul_id

	_add_log("Battle finished! Result: %s" % p_result.to_upper())

	emit_signal("battle_finished", p_result, p_winner_id, loser_id)

	GameLog.info("RTSArenaManager: Battle finished - %s (winner: %s)" % [p_result, p_winner_id], "Arena")


## Player command: move to position
func player_move_to(p_position: Vector2) -> void:
	if player_unit == null or player_unit.state == SoulUnit.UnitState.DEAD:
		return
	if battle_state != BattleState.ACTIVE:
		return
	player_unit.move_to(p_position)


## Player command: attack target
func player_attack_target(p_target: SoulUnit) -> void:
	if player_unit == null or player_unit.state == SoulUnit.UnitState.DEAD:
		return
	if battle_state != BattleState.ACTIVE:
		return
	player_unit.set_attack_target(p_target)


## Player command: use skill
func player_use_skill(p_skill_name: String, p_target: SoulUnit = null) -> bool:
	if player_unit == null or player_unit.state == SoulUnit.UnitState.DEAD:
		return false
	if battle_state != BattleState.ACTIVE:
		return false

	var target: SoulUnit = p_target
	if target == null:
		target = ai_unit

	var success: bool = player_unit.use_skill(p_skill_name, target)
	if success:
		_add_log("%s uses %s!" % [player_unit.soul_name, p_skill_name])
	return success


## Pause battle
func pause_battle() -> void:
	if battle_state == BattleState.ACTIVE:
		battle_state = BattleState.PAUSED
		_add_log("Battle paused")
		GameLog.info("RTSArenaManager: Battle paused", "Arena")


## Resume battle
func resume_battle() -> void:
	if battle_state == BattleState.PAUSED:
		battle_state = BattleState.ACTIVE
		_add_log("Battle resumed")
		GameLog.info("RTSArenaManager: Battle resumed", "Arena")


## Forfeit battle
func forfeit_battle() -> void:
	if battle_state == BattleState.ACTIVE:
		_finish_battle(ai_unit.soul_id, "defeat")
		_add_log("Player forfeited the battle")


## Clean up battle
func cleanup_battle() -> void:
	if player_unit != null and is_instance_valid(player_unit):
		player_unit.queue_free()
		player_unit = null
	if ai_unit != null and is_instance_valid(ai_unit):
		ai_unit.queue_free()
		ai_unit = null
	battle_state = BattleState.IDLE
	battle_time = 0.0
	GameLog.info("RTSArenaManager: Battle cleaned up", "Arena")


## Add log entry
func _add_log(p_message: String) -> void:
	battle_log.append({
		"time": battle_time,
		"message": p_message
	})
	emit_signal("log_added", p_message)


## Get battle info
func get_battle_info() -> Dictionary:
	return {
		"state": battle_state,
		"time": battle_time,
		"result": battle_result,
		"winner_id": winner_id,
		"player": player_unit.get_info() if player_unit != null else {},
		"ai": ai_unit.get_info() if ai_unit != null else {},
		"log_count": battle_log.size()
	}


## Get recent battle log
func get_recent_log(p_count: int = 10) -> Array:
	if battle_log.size() <= p_count:
		return battle_log.duplicate()
	return battle_log.slice(battle_log.size() - p_count, battle_log.size())
