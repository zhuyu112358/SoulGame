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

## EmberSoulAIController preload (Ember SDK AI - architecture compliant)
const EmberAIController = preload("res://scripts/game/EmberSoulAIController.gd")

## ArenaEnvironment preload (weather + terrain effects)
const ArenaEnvironment = preload("res://scripts/game/ArenaEnvironment.gd")

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

## Soul AI Controller (coach-style RTS: autonomous decisions based on personality/emotion)
var _ai_controller: EmberAIController = null

## Player unit AI controller (for auto-battle mode)
var _player_ai_controller: EmberAIController = null

## Arena environment (weather + terrain effects)
var _environment: ArenaEnvironment = null

## A* pathfinding (temporary: ArboreusPathfinder has bug with large grids)
## [SDK需求] ArboreusPathfinder.find_path returns only 2 incorrect points on 40x19/cell=32 grids
## Works correctly on 10x10/cell=1 grids. Need Arboreus team to fix large grid support.
var _grid_map: RefCounted = null
var _pathfinder: RefCounted = null
var _grid_map_script: Script = null
var _pathfinder_script: Script = null

## ArboreusWorldBridge (Arboreus SDK world simulation - architecture compliant)
## Progressive integration: world simulation layer, SoulUnit remains presentation layer
const ArboreusWorldBridge = preload("res://scripts/game/ArboreusWorldBridge.gd")
var _arboreus_world: ArboreusWorldBridge = null
var _player_entity_id: int = -1
var _ai_entity_id: int = -1

## World state sync timer (sync ArboreusWorld status to GameState periodically)
var _world_state_sync_timer: float = 0.0
var _world_state_sync_interval: float = 1.0  # Sync every 1 second

## Combat stats sync timer (sync HP/attributes to ArboreusEntity components)
var _combat_stats_sync_timer: float = 0.0
var _combat_stats_sync_interval: float = 0.5  # Sync every 0.5 seconds

## Battle mode: "manual" (player controls skills) or "auto" (AI controls both)
## Default is "auto" for coach-style RTS: souls make autonomous decisions
var battle_mode: String = "auto"

## Battle speed multiplier (1.0 = normal, 2.0 = double speed)
var battle_speed: float = 1.0

## Last battle statistics (for result display)
var last_battle_stats: Dictionary = {}

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
func start_battle(p_player_soul: Dictionary, p_ai_soul: Dictionary, p_map_name: String = "default_arena") -> bool:
	if battle_state == BattleState.ACTIVE:
		GameLog.warning("RTSArenaManager: Battle already active", "Arena")
		return false

	GameLog.info("RTSArenaManager: Starting RTS battle between %s and %s on map %s" % [
		p_player_soul.get("name", "Player"), p_ai_soul.get("name", "AI"), p_map_name
	], "Arena")

	# Reset state
	battle_state = BattleState.ACTIVE
	battle_time = 0.0
	winner_id = ""
	battle_result = "pending"
	battle_log.clear()

	# Load arena map
	if ArenaMap and ArenaMap.has_method("load_map"):
		ArenaMap.load_map(p_map_name)
		battle_config["player_spawn"] = ArenaMap.player_spawn
		battle_config["ai_spawn"] = ArenaMap.ai_spawn

	# Initialize arena environment (weather + terrain effects)
	_environment = ArenaEnvironment.new()
	_environment.setup_for_map(p_map_name)
	battle_config["weather"] = _environment.get_weather_name()

	# Initialize pathfinding using Arboreus SDK Pathfinder (architecture compliant)
	# Grid: ArboreusGridMapBridge (for obstacle sync + SoulUnit grid queries)
	# Pathfinder: SDKPathfinder (ArboreusPathfinder adapter, replaces self-implemented A*)
	if _grid_map_script == null:
		_grid_map_script = load("res://scripts/game/ArboreusGridMapBridge.gd")
	if _pathfinder_script == null:
		_pathfinder_script = load("res://scripts/game/SDKPathfinder.gd")
	_grid_map = _grid_map_script.new(32.0, 40, 19, 0.0, 0.0, true)
	_pathfinder = _pathfinder_script.new(32.0, 40, 19, 0.0, 0.0, true)
	_sync_obstacles_to_grid()
	# Also sync obstacles to SDKPathfinder's internal ArboreusGridMap
	_sync_obstacles_to_sdk_pathfinder()
	GameLog.info("RTSArenaManager: Pathfinding initialized (SDKPathfinder=Arboreus SDK, ArboreusGridMapBridge, %dx%d, %d blocked cells)" % [
		_grid_map.width, _grid_map.height, _grid_map.get_blocked_count()
	], "Arena")

	# Initialize Arboreus World simulation (Arboreus SDK - architecture compliant)
	# Progressive integration: world sim layer, SoulUnit remains presentation layer
	_arboreus_world = ArboreusWorldBridge.new({
		"name": "rts_arena",
		"width": battle_config["arena_width"],
		"height": battle_config["arena_height"],
		"cell_size": 32
	})
	_arboreus_world.start()
	GameLog.info("RTSArenaManager: ArboreusWorld simulation started (available: %s)" % _arboreus_world.is_arboreus_available(), "Arena")

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
	player_unit.set_pathfinding(_pathfinder, _grid_map)
	player_unit.unit_died.connect(_on_unit_died)
	add_child(player_unit)
	emit_signal("unit_spawned", player_unit, true)

	# Create corresponding Arboreus entity (world simulation layer)
	if _arboreus_world and _arboreus_world.is_arboreus_available():
		_player_entity_id = _arboreus_world.create_entity(p_player_soul.get("name", "Player"), battle_config["player_spawn"])
		# Register entity to movement system with initial position (Arboreus SDK)
		_arboreus_world.register_entity_to_movement(_player_entity_id, player_unit.position)
		# Add transform component to entity (Arboreus SDK component system)
		_arboreus_world.entity_add_component(_player_entity_id, "transform", {"position": player_unit.position, "team": "player"})
		# Add combat stats component (battle attributes synced to ArboreusEntity)
		_arboreus_world.entity_add_component(_player_entity_id, "combat_stats", {
			"hp": player_unit.current_hp,
			"max_hp": player_unit.max_hp,
			"attack": player_unit.attack_damage,
			"attack_range": player_unit.attack_range,
			"move_speed": player_unit.move_speed,
			"level": player_unit.level,
			"element": player_unit.element
		})

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
	ai_unit.set_pathfinding(_pathfinder, _grid_map)
	ai_unit.unit_died.connect(_on_unit_died)
	add_child(ai_unit)
	emit_signal("unit_spawned", ai_unit, false)

	# Create corresponding Arboreus entity (world simulation layer)
	if _arboreus_world and _arboreus_world.is_arboreus_available():
		_ai_entity_id = _arboreus_world.create_entity(p_ai_soul.get("name", "AI Opponent"), battle_config["ai_spawn"])
		# Register entity to movement system with initial position (Arboreus SDK)
		_arboreus_world.register_entity_to_movement(_ai_entity_id, ai_unit.position)
		# Add transform component to entity (Arboreus SDK component system)
		_arboreus_world.entity_add_component(_ai_entity_id, "transform", {"position": ai_unit.position, "team": "ai"})
		# Add combat stats component (battle attributes synced to ArboreusEntity)
		_arboreus_world.entity_add_component(_ai_entity_id, "combat_stats", {
			"hp": ai_unit.current_hp,
			"max_hp": ai_unit.max_hp,
			"attack": ai_unit.attack_damage,
			"attack_range": ai_unit.attack_range,
			"move_speed": ai_unit.move_speed,
			"level": ai_unit.level,
			"element": ai_unit.element
		})

	# AI starts attacking player
	ai_unit.set_attack_target(player_unit)
	# Player also auto-attacks AI (auto-battle mode for M2 playable prototype)
	player_unit.set_attack_target(ai_unit)

	# Initialize AI controllers (coach-style RTS: autonomous decisions)
	_ai_controller = EmberAIController.new()
	_player_ai_controller = EmberAIController.new()

	# Set AI personality based on soul data (design doc: 个性即战术)
	_apply_soul_personality(ai_unit, p_ai_soul)
	_apply_soul_personality(player_unit, p_player_soul)

	_add_log("Battle started! %s vs %s" % [player_unit.soul_name, ai_unit.soul_name])
	_add_log("AI Personality: aggression=%d, courage=%d, loyalty=%d" % [
		ai_unit.personality["aggression"], ai_unit.personality["courage"], ai_unit.personality["loyalty"]
	])

	# Play battle start audio (design doc: audio feedback for battle events)
	AudioManager.play_sfx("ui_battle_start")
	AudioManager.play_bgm("battle")
	# Play soul emotion sound based on AI personality
	if ai_unit.personality["aggression"] > 70:
		AudioManager.play_sfx("soul_angry_roar", 0.5)
	elif ai_unit.personality["courage"] > 70:
		AudioManager.play_sfx("soul_brave_courage", 0.5)
	else:
		AudioManager.play_sfx("soul_determined_resolve", 0.5)

	emit_signal("battle_started", {
		"player": player_unit.get_info(),
		"ai": ai_unit.get_info(),
		"config": battle_config
	})

	return true


## Sync ArenaMap obstacles to A* grid
func _sync_obstacles_to_grid() -> void:
	if _grid_map == null or ArenaMap == null:
		return
	_grid_map.clear()
	# Get obstacles from ArenaMap
	if ArenaMap.has_method("get_obstacles"):
		var obstacles = ArenaMap.get_obstacles()
		for obs in obstacles:
			var pos: Vector2 = obs.get("position", Vector2.ZERO)
			var size: Vector2 = obs.get("size", Vector2(40, 40))
			# Add margin for unit collision radius
			var margin: float = 16.0
			_grid_map.block_region(
				pos.x - size.x / 2 - margin,
				pos.y - size.y / 2 - margin,
				pos.x + size.x / 2 + margin,
				pos.y + size.y / 2 + margin
			)
		GameLog.debug("RTSArenaManager: Synced %d obstacles to A* grid" % obstacles.size(), "Arena")
	else:
		GameLog.warning("RTSArenaManager: ArenaMap has no get_obstacles method", "Arena")


## Sync obstacles to SDKPathfinder's internal ArboreusGridMap (Arboreus SDK)
## Must be called after _sync_obstacles_to_grid, keeps both grids in sync
func _sync_obstacles_to_sdk_pathfinder() -> void:
	if _pathfinder == null or ArenaMap == null:
		return
	if not _pathfinder.has_method("block_region"):
		return
	_pathfinder.clear()
	if ArenaMap.has_method("get_obstacles"):
		var obstacles = ArenaMap.get_obstacles()
		for obs in obstacles:
			var pos: Vector2 = obs.get("position", Vector2.ZERO)
			var size: Vector2 = obs.get("size", Vector2(40, 40))
			var margin: float = 16.0
			_pathfinder.block_region(
				pos.x - size.x / 2 - margin,
				pos.y - size.y / 2 - margin,
				pos.x + size.x / 2 + margin,
				pos.y + size.y / 2 + margin
			)
		GameLog.debug("RTSArenaManager: Synced %d obstacles to SDKPathfinder" % obstacles.size(), "Arena")


## Apply soul personality to unit (design doc: 个性即战术)
func _apply_soul_personality(p_unit, p_soul_data: Dictionary) -> void:
	if p_soul_data.has("personality"):
		var personality_val = p_soul_data["personality"]
		# Support both Dictionary (full trait data) and String (preset name)
		if typeof(personality_val) == TYPE_DICTIONARY:
			var personality_data: Dictionary = personality_val
			for t_name in personality_data.keys():
				if p_unit.personality.has(t_name):
					p_unit.personality[t_name] = personality_data[t_name]
		elif typeof(personality_val) == TYPE_STRING:
			# String preset name -> apply corresponding trait values
			_apply_personality_preset(p_unit, personality_val)
	else:
		# Generate random personality for prototype
		p_unit.personality["aggression"] = randi_range(20, 80)
		p_unit.personality["courage"] = randi_range(20, 80)
		p_unit.personality["curiosity"] = randi_range(20, 80)
		p_unit.personality["patience"] = randi_range(20, 80)
		p_unit.personality["loyalty"] = randi_range(40, 90)
		p_unit.personality["intelligence"] = randi_range(30, 80)


## Apply personality preset by name (design doc: named personality archetypes)
func _apply_personality_preset(p_unit, p_preset: String) -> void:
	match p_preset.to_lower():
		"brave":
			p_unit.personality["aggression"] = 70
			p_unit.personality["courage"] = 85
			p_unit.personality["loyalty"] = 75
			p_unit.personality["patience"] = 40
			p_unit.personality["intelligence"] = 50
		"aggressive":
			p_unit.personality["aggression"] = 90
			p_unit.personality["courage"] = 75
			p_unit.personality["loyalty"] = 50
			p_unit.personality["patience"] = 20
			p_unit.personality["intelligence"] = 45
		"cautious":
			p_unit.personality["aggression"] = 30
			p_unit.personality["courage"] = 40
			p_unit.personality["loyalty"] = 80
			p_unit.personality["patience"] = 85
			p_unit.personality["intelligence"] = 70
		"wise":
			p_unit.personality["aggression"] = 40
			p_unit.personality["courage"] = 60
			p_unit.personality["loyalty"] = 70
			p_unit.personality["patience"] = 75
			p_unit.personality["intelligence"] = 90
		_:
			# Unknown preset -> random
			p_unit.personality["aggression"] = randi_range(20, 80)
			p_unit.personality["courage"] = randi_range(20, 80)
			p_unit.personality["loyalty"] = randi_range(40, 90)
			p_unit.personality["patience"] = randi_range(20, 80)
			p_unit.personality["intelligence"] = randi_range(30, 80)


## Process real-time battle updates
func _process(delta: float) -> void:
	if battle_state != BattleState.ACTIVE:
		return

	# Apply battle speed multiplier
	var scaled_delta = delta * battle_speed

	battle_time += scaled_delta
	emit_signal("battle_time_updated", battle_time)

	# Update Arboreus World simulation (Arboreus SDK - architecture compliant)
	if _arboreus_world and _arboreus_world.is_running():
		_arboreus_world.update(scaled_delta)

	# Sync ArboreusWorld state to GameState periodically (architecture compliant)
	_world_state_sync_timer += scaled_delta
	if _world_state_sync_timer >= _world_state_sync_interval:
		_world_state_sync_timer = 0.0
		_sync_world_state_to_game_state()

	# Sync SoulUnit positions to ArboreusMovementSystem every frame (Arboreus SDK)
	# Presentation layer (SoulUnit) -> engine layer (ArboreusMovementSystem)
	if _arboreus_world and _arboreus_world.is_running():
		if player_unit and _player_entity_id >= 0:
			_arboreus_world.set_entity_position(_player_entity_id, player_unit.position)
		if ai_unit and _ai_entity_id >= 0:
			_arboreus_world.set_entity_position(_ai_entity_id, ai_unit.position)

	# Sync combat stats (HP) to ArboreusEntity components periodically
	_combat_stats_sync_timer += scaled_delta
	if _combat_stats_sync_timer >= _combat_stats_sync_interval:
		_combat_stats_sync_timer = 0.0
		_sync_combat_stats_to_entities()

	# Update AI controllers
	if _ai_controller:
		_ai_controller.update(scaled_delta)
	if _player_ai_controller:
		_player_ai_controller.update(scaled_delta)

	# AI decision making (coach-style RTS: autonomous decisions)
	_ai_decision_timer += scaled_delta
	if _ai_decision_timer >= _ai_decision_interval:
		_ai_decision_timer = 0.0
		GameLog.debug("RTS: AI decision tick - player=%s ai=%s player_pos=(%.0f,%.0f) ai_pos=(%.0f,%.0f) dist=%.1f" % [
			player_unit.soul_name if player_unit else "null",
			ai_unit.soul_name if ai_unit else "null",
			player_unit.position.x if player_unit else -1,
			player_unit.position.y if player_unit else -1,
			ai_unit.position.x if ai_unit else -1,
			ai_unit.position.y if ai_unit else -1,
			player_unit.position.distance_to(ai_unit.position) if (player_unit and ai_unit) else -1
		], "Arena")
		_update_ai()

	# Auto-battle mode: player unit also controlled by AI
	if battle_mode == "auto" and _player_ai_controller:
		_update_player_ai()

	# Update emotions based on battle state
	_update_emotions()

	# Update arena environment (weather changes, terrain effects)
	if _environment:
		var env_events = _environment.update(scaled_delta)
		if env_events.get("weather_changed", false):
			_add_log("Weather changed to: %s" % _environment.get_weather_name())
			battle_config["weather"] = _environment.get_weather_name()
		if env_events.get("lightning", false):
			var lightning_pos = env_events.get("lightning_position", Vector2.ZERO)
			_add_log("Lightning strikes at (%d, %d)!" % [int(lightning_pos.x), int(lightning_pos.y)])
			_apply_lightning_damage(lightning_pos)

	# Apply terrain damage (lava etc.)
	_apply_terrain_damage(scaled_delta)

	# Check battle time limit
	if battle_time >= battle_config["max_battle_time"]:
		_finish_battle_by_time()


## Update AI behavior using EmberAIController (coach-style RTS)
func _update_ai() -> void:
	if ai_unit == null or ai_unit.state == SoulUnit.UnitState.DEAD:
		return
	if player_unit == null or player_unit.state == SoulUnit.UnitState.DEAD:
		return
	if _ai_controller == null:
		return

	# Make autonomous decision based on personality/emotion
	var decision = _ai_controller.make_decision(ai_unit, player_unit)
	_ai_controller.execute_decision(ai_unit, player_unit)

	# Log significant decisions
	if decision["decision"] == EmberAIController.Decision.USE_SKILL:
		_add_log("%s makes a tactical decision!" % ai_unit.soul_name)


## Update player AI (auto-battle mode)
func _update_player_ai() -> void:
	if player_unit == null or player_unit.state == SoulUnit.UnitState.DEAD:
		return
	if _player_ai_controller == null:
		return

	var decision = _player_ai_controller.make_decision(player_unit, ai_unit)
	_player_ai_controller.execute_decision(player_unit, ai_unit)


## Update emotional states based on battle events
func _update_emotions() -> void:
	if ai_unit == null or player_unit == null:
		return

	# Low HP triggers fear
	if float(ai_unit.current_hp) / float(ai_unit.max_hp) < 0.3:
		_ai_controller.update_emotion(ai_unit, "low_hp", 0.05)
	if float(player_unit.current_hp) / float(player_unit.max_hp) < 0.3:
		_player_ai_controller.update_emotion(player_unit, "low_hp", 0.05)


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

	# Cleanup Arboreus World simulation (Arboreus SDK - architecture compliant)
	if _arboreus_world and _arboreus_world.is_running():
		# Unregister entities from movement system (Arboreus SDK)
		if _player_entity_id >= 0:
			_arboreus_world.unregister_entity_from_movement(_player_entity_id)
		if _ai_entity_id >= 0:
			_arboreus_world.unregister_entity_from_movement(_ai_entity_id)
		# Remove entities from world
		if _player_entity_id >= 0:
			_arboreus_world.remove_entity(_player_entity_id)
			_player_entity_id = -1
		if _ai_entity_id >= 0:
			_arboreus_world.remove_entity(_ai_entity_id)
			_ai_entity_id = -1
		_arboreus_world.stop()
		GameLog.info("RTSArenaManager: ArboreusWorld simulation stopped", "Arena")

	# Clear world state in GameState
	GameState.set_world_state("arboreus_world_running", false)
	GameState.set_world_state("battle_active", false)

	var loser_id: String = ""
	if p_winner_id == player_unit.soul_id:
		loser_id = ai_unit.soul_id
	elif p_winner_id == ai_unit.soul_id:
		loser_id = player_unit.soul_id

	_add_log("Battle finished! Result: %s" % p_result.to_upper())

	# Play battle end audio (design doc: audio feedback for battle events)
	AudioManager.play_sfx("ui_battle_end")
	AudioManager.stop_bgm()
	if p_result == "victory":
		AudioManager.play_sfx("bat_victory")
		AudioManager.play_sfx("soul_confident", 0.6)
	else:
		AudioManager.play_sfx("bat_defeat")

	# Process battle result and growth feedback
	var battle_data: Dictionary = {
		"result": p_result,
		"player_soul_id": player_unit.soul_id,
		"opponent_soul_id": ai_unit.soul_id,
		"player_level": player_unit.level,
		"opponent_level": ai_unit.level,
		"player_hp_remaining": player_unit.current_hp,
		"player_max_hp": player_unit.max_hp,
		"ai_hp_remaining": ai_unit.current_hp,
		"ai_max_hp": ai_unit.max_hp,
		"duration": battle_time,
		"damage_dealt": player_unit.max_hp - ai_unit.current_hp,
		"damage_taken": player_unit.max_hp - player_unit.current_hp,
		"skills_used": []
	}
	BattleResultManager.process_battle_result(battle_data)

	# Save last battle stats for result display
	last_battle_stats = battle_data

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


## Player macro command (design doc: coach-style RTS, one command per 30s)
## Commands: "gather", "retreat", "attack", "defend"
## Soul may disobey based on loyalty/courage personality
func issue_player_command(p_command: String, p_target_position: Vector2 = Vector2.ZERO) -> Dictionary:
	if player_unit == null or battle_state != BattleState.ACTIVE:
		return {"success": false, "error": "No active battle"}

	if _player_ai_controller == null:
		return {"success": false, "error": "AI controller not initialized"}

	# Check if command is valid
	var valid_commands = ["gather", "attack", "defend", "retreat"]
	if not valid_commands.has(p_command):
		return {"success": false, "error": "Invalid command: %s" % p_command}

	# Check cooldown
	if _player_ai_controller.command_cooldown > 0:
		return {"success": false, "error": "Command on cooldown (30s)", "cooldown": _player_ai_controller.command_cooldown}

	var issued: bool = _player_ai_controller.issue_command(p_command, p_target_position)
	if not issued:
		return {"success": false, "error": "Command rejected", "cooldown": _player_ai_controller.command_cooldown}

	_add_log("Player issues command: %s" % p_command)
	return {
		"success": true,
		"command": p_command,
		"cooldown": EmberAIController.COMMAND_COOLDOWN
	}


## Get player command cooldown
func get_player_command_cooldown() -> float:
	if _player_ai_controller == null:
		return 0.0
	return _player_ai_controller.command_cooldown


## Set battle mode: "manual" (player controls skills) or "auto" (AI controls both)
func set_battle_mode(p_mode: String) -> void:
	battle_mode = p_mode
	_add_log("Battle mode: %s" % p_mode)
	GameLog.info("RTSArenaManager: Battle mode set to %s" % p_mode, "Arena")


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


## Set battle speed multiplier (1.0 = normal, 2.0 = double speed)
func set_battle_speed(p_speed: float) -> void:
	battle_speed = clamp(p_speed, 0.5, 3.0)
	_add_log("Battle speed set to %.1fx" % battle_speed)
	GameLog.info("RTSArenaManager: Battle speed set to %.1fx" % battle_speed, "Arena")


## Get current battle speed
func get_battle_speed() -> float:
	return battle_speed


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
	_environment = null
	GameLog.info("RTSArenaManager: Battle cleaned up", "Arena")


## Apply terrain damage to units (e.g., lava damage over time)
func _apply_terrain_damage(delta: float) -> void:
	if _environment == null:
		return

	# Player unit terrain damage
	if player_unit and player_unit.state != SoulUnit.UnitState.DEAD:
		var dmg = _environment.get_terrain_damage(player_unit.position)
		if dmg > 0:
			player_unit.take_damage(int(dmg * delta))
			if randf() < 0.02:  # Log occasionally
				_add_log("%s takes %.1f lava damage" % [player_unit.soul_name, dmg])

	# AI unit terrain damage
	if ai_unit and ai_unit.state != SoulUnit.UnitState.DEAD:
		var dmg = _environment.get_terrain_damage(ai_unit.position)
		if dmg > 0:
			ai_unit.take_damage(int(dmg * delta))


## Apply lightning damage at position (storm weather)
func _apply_lightning_damage(p_position: Vector2) -> void:
	var lightning_radius: float = 80.0
	var lightning_damage: float = 15.0

	# Check player unit
	if player_unit and player_unit.state != SoulUnit.UnitState.DEAD:
		if player_unit.position.distance_to(p_position) < lightning_radius:
			player_unit.take_damage(lightning_damage)
			_add_log("%s struck by lightning! (-%d HP)" % [player_unit.soul_name, int(lightning_damage)])

	# Check AI unit
	if ai_unit and ai_unit.state != SoulUnit.UnitState.DEAD:
		if ai_unit.position.distance_to(p_position) < lightning_radius:
			ai_unit.take_damage(lightning_damage)
			_add_log("%s struck by lightning! (-%d HP)" % [ai_unit.soul_name, int(lightning_damage)])


## Get current environment info (for UI display)
func get_environment_info() -> Dictionary:
	if _environment:
		return _environment.get_environment_info()
	return {"weather": "Clear", "weather_type": 0}


## Reset battle state for rematch (clears units and state)
func reset_battle() -> void:
	cleanup_battle()
	_ai_controller = null
	_player_ai_controller = null
	winner_id = ""
	battle_result = ""
	_ai_decision_timer = 0.0
	GameLog.info("RTSArenaManager: Battle reset for rematch", "Arena")


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
		"log_count": battle_log.size(),
		"weather": _environment.get_weather_name() if _environment != null else "Clear"
	}


## Get recent battle log
func get_recent_log(p_count: int = 10) -> Array:
	if battle_log.size() <= p_count:
		return battle_log.duplicate()
	return battle_log.slice(battle_log.size() - p_count, battle_log.size())


## Sync ArboreusWorld state to GameState (architecture compliant)
## Arboreus SDK owns world simulation; GameState is Battleplan's state store (application layer)
func _sync_world_state_to_game_state() -> void:
	if not _arboreus_world or not _arboreus_world.is_arboreus_available():
		return

	var world_status = _arboreus_world.get_status()
	if world_status == null or not (world_status is Dictionary):
		return

	# Sync world simulation state to GameState "world" namespace
	GameState.set_world_state("arboreus_world_running", world_status.get("is_running", false))
	GameState.set_world_state("arboreus_world_time", world_status.get("time", 0.0))
	GameState.set_world_state("arboreus_entity_count", world_status.get("entity_count", 0))
	GameState.set_world_state("arboreus_spatial_entity_count", world_status.get("spatial_entity_count", 0))
	GameState.set_world_state("arboreus_day_count", world_status.get("day_count", 0))
	GameState.set_world_state("arboreus_time_of_day", world_status.get("time_of_day", "unknown"))
	GameState.set_world_state("arboreus_queued_events", world_status.get("queued_events", 0))

	# Sync battle-specific state
	GameState.set_world_state("battle_active", battle_state == BattleState.ACTIVE)
	GameState.set_world_state("battle_time", battle_time)
	GameState.set_world_state("battle_speed", battle_speed)
	GameState.set_world_state("battle_mode", battle_mode)

	# Sync unit positions (presentation layer, from SoulUnit)
	if player_unit:
		GameState.set_world_state("player_position", player_unit.position)
		GameState.set_world_state("player_hp", player_unit.current_hp)
	if ai_unit:
		GameState.set_world_state("ai_position", ai_unit.position)
		GameState.set_world_state("ai_hp", ai_unit.current_hp)


## Sync combat stats (HP etc.) from SoulUnit to ArboreusEntity components
## Presentation layer (SoulUnit) -> engine layer (ArboreusEntity combat_stats component)
func _sync_combat_stats_to_entities() -> void:
	if not _arboreus_world or not _arboreus_world.is_arboreus_available():
		return
	if not _arboreus_world.is_running():
		return

	# Sync player entity combat stats
	if player_unit and _player_entity_id >= 0:
		_arboreus_world.entity_add_component(_player_entity_id, "combat_stats", {
			"hp": player_unit.current_hp,
			"max_hp": player_unit.max_hp,
			"attack": player_unit.attack_damage,
			"attack_range": player_unit.attack_range,
			"move_speed": player_unit.move_speed,
			"level": player_unit.level,
			"element": player_unit.element
		})

	# Sync AI entity combat stats
	if ai_unit and _ai_entity_id >= 0:
		_arboreus_world.entity_add_component(_ai_entity_id, "combat_stats", {
			"hp": ai_unit.current_hp,
			"max_hp": ai_unit.max_hp,
			"attack": ai_unit.attack_damage,
			"attack_range": ai_unit.attack_range,
			"move_speed": ai_unit.move_speed,
			"level": ai_unit.level,
			"element": ai_unit.element
		})
