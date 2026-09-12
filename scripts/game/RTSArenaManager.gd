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

## AIDifficultySystem preload (AI difficulty levels)
const AIDifficultySystem = preload("res://scripts/game/AIDifficultySystem.gd")

## Battle state constants
enum BattleState {
	IDLE,
	ACTIVE,
	PAUSED,
	FINISHED
}

## Current battle state
var battle_state: int = BattleState.IDLE

## Player unit (compatibility: refers to first unit in player_units)
var player_unit: SoulUnit = null

## AI opponent unit (compatibility: refers to first unit in ai_units)
var ai_unit: SoulUnit = null

## GAP-001: Team battle support (4v4)
## Array of player team units (up to 4)
var player_units: Array = []
## Array of AI team units (up to 4)
var ai_units: Array = []
## Team size (GDD v2.0: 4 souls per team)
const TEAM_SIZE: int = 4
## Arboreus entity IDs for team units
var _player_entity_ids: Array = []
var _ai_entity_ids: Array = []
## AI controllers for each AI unit
var _ai_controllers: Array = []
## Player AI controllers for each player unit (auto-battle mode)
var _player_ai_controllers: Array = []

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

## Tactical command system (GDD v2.0 Chapter 2.1.1)
## Current tactical command influences AI behavior weights
var current_tactical_command: String = "free"
var tactical_weights: Dictionary = {
	"attack_priority": 1.0,
	"chase_range": 1.0,
	"evade_priority": 1.0,
	"keep_distance": 1.0,
	"skill_aggressiveness": 1.0,
	"risk_tolerance": 1.0
}

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
func start_battle(p_player_soul: Dictionary, p_ai_soul: Dictionary, p_map_name: String = "default_arena", p_ai_difficulty: int = 1) -> bool:
	if battle_state == BattleState.ACTIVE:
		GameLog.warning("RTSArenaManager: Battle already active", "Arena")
		return false

	GameLog.info("RTSArenaManager: Starting RTS battle between %s and %s on map %s (AI difficulty: %d)" % [
		p_player_soul.get("name", "Player"), p_ai_soul.get("name", "AI"), p_map_name, p_ai_difficulty
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

	# Apply AI difficulty modifiers (M2.11 Battle Modes)
	_apply_ai_difficulty(ai_unit, p_ai_difficulty)

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


## GAP-001: Start a 4v4 team battle
## p_player_team: Array of soul dictionaries (up to 4)
## p_ai_team: Array of soul dictionaries (up to 4)
## p_map_name: Arena map name
## p_ai_difficulty: AI difficulty level (1-4)
func start_team_battle(p_player_team: Array, p_ai_team: Array, p_map_name: String = "default_arena", p_ai_difficulty: int = 1) -> bool:
	if battle_state == BattleState.ACTIVE:
		GameLog.warning("RTSArenaManager: Battle already active", "Arena")
		return false

	# Validate team sizes
	if p_player_team.is_empty() or p_ai_team.is_empty():
		GameLog.warning("RTSArenaManager: Team cannot be empty", "Arena")
		return false

	var player_count: int = min(p_player_team.size(), TEAM_SIZE)
	var ai_count: int = min(p_ai_team.size(), TEAM_SIZE)

	GameLog.info("RTSArenaManager: Starting %dv%d team battle on map %s (AI difficulty: %d)" % [player_count, ai_count, p_map_name, p_ai_difficulty], "Arena")

	# Reset state
	battle_state = BattleState.ACTIVE
	battle_time = 0.0
	winner_id = ""
	battle_result = "pending"
	battle_log.clear()
	player_units.clear()
	ai_units.clear()
	_player_entity_ids.clear()
	_ai_entity_ids.clear()
	_ai_controllers.clear()
	_player_ai_controllers.clear()

	# Load arena map
	if ArenaMap and ArenaMap.has_method("load_map"):
		ArenaMap.load_map(p_map_name)
		battle_config["player_spawn"] = ArenaMap.player_spawn
		battle_config["ai_spawn"] = ArenaMap.ai_spawn

	# Initialize arena environment
	_environment = ArenaEnvironment.new()
	_environment.setup_for_map(p_map_name)
	battle_config["weather"] = _environment.get_weather_name()

	# Initialize pathfinding
	if _grid_map_script == null:
		_grid_map_script = load("res://scripts/game/ArboreusGridMapBridge.gd")
	if _pathfinder_script == null:
		_pathfinder_script = load("res://scripts/game/SDKPathfinder.gd")
	_grid_map = _grid_map_script.new(32.0, 40, 19, 0.0, 0.0, true)
	_pathfinder = _pathfinder_script.new(32.0, 40, 19, 0.0, 0.0, true)
	_sync_obstacles_to_grid()
	_sync_obstacles_to_sdk_pathfinder()

	# Initialize Arboreus World simulation
	_arboreus_world = ArboreusWorldBridge.new({
		"name": "rts_arena",
		"width": battle_config["arena_width"],
		"height": battle_config["arena_height"],
		"cell_size": 32
	})
	_arboreus_world.start()

	# Spawn player team units (vertical formation)
	var player_base_pos: Vector2 = battle_config["player_spawn"]
	for i in range(player_count):
		var soul_data: Dictionary = p_player_team[i]
		var unit: SoulUnit = SoulUnit.new()
		unit.init_from_soul(
			soul_data.get("id", "player_%d" % i),
			soul_data.get("name", "Player %d" % (i + 1)),
			soul_data.get("element", "neutral"),
			soul_data.get("level", 1),
			true
		)
		# Vertical formation: units spaced 80px apart
		var offset_y: float = (i - (player_count - 1) / 2.0) * 80.0
		unit.position = player_base_pos + Vector2(0, offset_y)
		unit.set_pathfinding(_pathfinder, _grid_map)
		unit.unit_died.connect(_on_team_unit_died)
		add_child(unit)
		player_units.append(unit)
		emit_signal("unit_spawned", unit, true)

		# Create Arboreus entity
		if _arboreus_world and _arboreus_world.is_arboreus_available():
			var entity_id: int = _arboreus_world.create_entity(unit.soul_name, unit.position)
			_arboreus_world.register_entity_to_movement(entity_id, unit.position)
			_arboreus_world.entity_add_component(entity_id, "transform", {"position": unit.position, "team": "player"})
			_arboreus_world.entity_add_component(entity_id, "combat_stats", {
				"hp": unit.current_hp, "max_hp": unit.max_hp, "attack": unit.attack_damage,
				"attack_range": unit.attack_range, "move_speed": unit.move_speed,
				"level": unit.level, "element": unit.element
			})
			_player_entity_ids.append(entity_id)

		# Apply soul personality
		_apply_soul_personality(unit, soul_data)

		# Create player AI controller (auto-battle mode)
		var player_ai: EmberAIController = EmberAIController.new()
		_player_ai_controllers.append(player_ai)

	# Set compatibility reference to first player unit
	if not player_units.is_empty():
		player_unit = player_units[0]

	# Spawn AI team units (vertical formation)
	var ai_base_pos: Vector2 = battle_config["ai_spawn"]
	for i in range(ai_count):
		var soul_data: Dictionary = p_ai_team[i]
		var unit: SoulUnit = SoulUnit.new()
		unit.init_from_soul(
			soul_data.get("id", "ai_%d" % i),
			soul_data.get("name", "AI %d" % (i + 1)),
			soul_data.get("element", "neutral"),
			soul_data.get("level", 1),
			false
		)
		var offset_y: float = (i - (ai_count - 1) / 2.0) * 80.0
		unit.position = ai_base_pos + Vector2(0, offset_y)
		unit.set_pathfinding(_pathfinder, _grid_map)
		unit.unit_died.connect(_on_team_unit_died)
		add_child(unit)
		ai_units.append(unit)
		emit_signal("unit_spawned", unit, false)

		# Apply AI difficulty
		_apply_ai_difficulty(unit, p_ai_difficulty)

		# Create Arboreus entity
		if _arboreus_world and _arboreus_world.is_arboreus_available():
			var entity_id: int = _arboreus_world.create_entity(unit.soul_name, unit.position)
			_arboreus_world.register_entity_to_movement(entity_id, unit.position)
			_arboreus_world.entity_add_component(entity_id, "transform", {"position": unit.position, "team": "ai"})
			_arboreus_world.entity_add_component(entity_id, "combat_stats", {
				"hp": unit.current_hp, "max_hp": unit.max_hp, "attack": unit.attack_damage,
				"attack_range": unit.attack_range, "move_speed": unit.move_speed,
				"level": unit.level, "element": unit.element
			})
			_ai_entity_ids.append(entity_id)

		# Apply soul personality
		_apply_soul_personality(unit, soul_data)

		# Create AI controller
		var ai_controller: EmberAIController = EmberAIController.new()
		_ai_controllers.append(ai_controller)

	# Set compatibility reference to first AI unit
	if not ai_units.is_empty():
		ai_unit = ai_units[0]

	# Set initial attack targets (each unit targets nearest enemy)
	_setup_team_attack_targets()

	# Initialize compatibility AI controllers (for existing code)
	if not _ai_controllers.is_empty():
		_ai_controller = _ai_controllers[0]
	if not _player_ai_controllers.is_empty():
		_player_ai_controller = _player_ai_controllers[0]

	_add_log("Team battle started! %dv%d" % [player_count, ai_count])
	var player_names: Array = []
	for u in player_units:
		player_names.append(u.soul_name)
	_add_log("Player team: " + ", ".join(player_names))
	var ai_names: Array = []
	for u in ai_units:
		ai_names.append(u.soul_name)
	_add_log("AI team: " + ", ".join(ai_names))

	# Play battle start audio
	AudioManager.play_sfx("ui_battle_start")
	AudioManager.play_bgm("battle")

	# Build team info arrays
	var player_team_info: Array = []
	for u in player_units:
		player_team_info.append(u.get_info())
	var ai_team_info: Array = []
	for u in ai_units:
		ai_team_info.append(u.get_info())

	emit_signal("battle_started", {
		"player_team": player_team_info,
		"ai_team": ai_team_info,
		"config": battle_config,
		"team_battle": true
	})

	return true


## Setup attack targets for team battle (each unit targets nearest enemy)
func _setup_team_attack_targets() -> void:
	for p_unit in player_units:
		if p_unit and p_unit.state != SoulUnit.UnitState.DEAD:
			var nearest: SoulUnit = _find_nearest_enemy(p_unit, ai_units)
			if nearest:
				p_unit.set_attack_target(nearest)
	for a_unit in ai_units:
		if a_unit and a_unit.state != SoulUnit.UnitState.DEAD:
			var nearest: SoulUnit = _find_nearest_enemy(a_unit, player_units)
			if nearest:
				a_unit.set_attack_target(nearest)


## Find nearest alive enemy unit
func _find_nearest_enemy(p_unit: SoulUnit, p_enemies: Array) -> SoulUnit:
	var nearest: SoulUnit = null
	var min_dist: float = INF
	for enemy in p_enemies:
		if enemy and enemy.state != SoulUnit.UnitState.DEAD:
			var dist: float = p_unit.position.distance_to(enemy.position)
			if dist < min_dist:
				min_dist = dist
				nearest = enemy
	return nearest


## Get count of alive units in team
func get_alive_count(p_team: Array) -> int:
	var count: int = 0
	for unit in p_team:
		if unit and unit.state != SoulUnit.UnitState.DEAD:
			count += 1
	return count


## Get total HP of team
func get_team_total_hp(p_team: Array) -> int:
	var total: int = 0
	for unit in p_team:
		if unit and unit.state != SoulUnit.UnitState.DEAD:
			total += unit.current_hp
	return total


## Handle team unit death
func _on_team_unit_died(p_unit: SoulUnit) -> void:
	GameLog.info("RTSArenaManager: %s has been defeated!" % p_unit.soul_name, "Arena")
	_add_log("%s has been defeated!" % p_unit.soul_name)

	# Check if player team wiped
	var player_alive: int = get_alive_count(player_units)
	var ai_alive: int = get_alive_count(ai_units)

	if player_alive == 0:
		_finish_battle(ai_units[0].soul_id if not ai_units.is_empty() else "ai", "defeat")
	elif ai_alive == 0:
		_finish_battle(player_units[0].soul_id if not player_units.is_empty() else "player", "victory")
	else:
		# Re-target remaining units
		_setup_team_attack_targets()


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


## Apply AI difficulty modifiers to AI unit (M2.11 Battle Modes)
func _apply_ai_difficulty(p_unit, p_difficulty: int) -> void:
	var difficulty_system = AIDifficultySystem.new()
	var modifiers = difficulty_system.get_stat_modifiers(p_difficulty)

	# Apply stat modifiers
	if modifiers.has("hp_multiplier"):
		p_unit.max_hp = int(p_unit.max_hp * modifiers["hp_multiplier"])
		p_unit.current_hp = p_unit.max_hp
	if modifiers.has("attack_multiplier"):
		p_unit.attack_damage = int(p_unit.attack_damage * modifiers["attack_multiplier"])
	if modifiers.has("speed_multiplier"):
		p_unit.move_speed = int(p_unit.move_speed * modifiers["speed_multiplier"])
	if modifiers.has("crit_rate_multiplier"):
		p_unit.crit_rate = clampf(p_unit.crit_rate * modifiers["crit_rate_multiplier"], 0.0, 1.0)
	if modifiers.has("crit_damage_multiplier"):
		p_unit.crit_multiplier = p_unit.crit_multiplier * modifiers["crit_damage_multiplier"]

	GameLog.info("RTSArenaManager: AI difficulty applied - %s (HP:%d ATK:%d SPD:%d)" % [
		difficulty_system.get_difficulty_name(p_difficulty),
		p_unit.max_hp, p_unit.attack_damage, p_unit.move_speed
	], "Arena")
	difficulty_system.queue_free()


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

	# GAP-001: Update all team AI controllers
	for ctrl in _ai_controllers:
		if ctrl:
			ctrl.update(scaled_delta)
	for ctrl in _player_ai_controllers:
		if ctrl:
			ctrl.update(scaled_delta)

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
		# GAP-001: Update all team AI decisions
		_update_team_ai()

	# Auto-battle mode: player unit also controlled by AI
	if battle_mode == "auto" and _player_ai_controller:
		_update_player_ai()
	# GAP-001: Update all team player AI decisions
	if battle_mode == "auto":
		_update_team_player_ai()

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

	# Auto-re-engage: if player unit is idle (after player move command) and AI is in range, resume attack
	if player_unit and ai_unit and player_unit.state == 0 and player_unit.attack_target == null:
		var dist = player_unit.position.distance_to(ai_unit.position)
		if dist <= player_unit.attack_range:
			player_unit.set_attack_target(ai_unit)

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


## GAP-001: Update all AI team units decisions
func _update_team_ai() -> void:
	if ai_units.is_empty() or player_units.is_empty():
		return
	for i in range(ai_units.size()):
		var ai_u: SoulUnit = ai_units[i]
		if ai_u == null or ai_u.state == SoulUnit.UnitState.DEAD:
			continue
		if i >= _ai_controllers.size() or _ai_controllers[i] == null:
			continue
		# Find nearest alive player unit as target
		var target: SoulUnit = _find_nearest_enemy(ai_u, player_units)
		if target == null:
			continue
		var decision = _ai_controllers[i].make_decision(ai_u, target)
		_ai_controllers[i].execute_decision(ai_u, target)


## GAP-001: Update all player team units AI decisions (auto-battle mode)
func _update_team_player_ai() -> void:
	if player_units.is_empty() or ai_units.is_empty():
		return
	for i in range(player_units.size()):
		var p_unit: SoulUnit = player_units[i]
		if p_unit == null or p_unit.state == SoulUnit.UnitState.DEAD:
			continue
		if i >= _player_ai_controllers.size() or _player_ai_controllers[i] == null:
			continue
		var target: SoulUnit = _find_nearest_enemy(p_unit, ai_units)
		if target == null:
			continue
		var decision = _player_ai_controllers[i].make_decision(p_unit, target)
		_player_ai_controllers[i].execute_decision(p_unit, target)


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

	# GAP-001: Compare team total HP for team battles
	var player_total_hp: int = get_team_total_hp(player_units)
	var ai_total_hp: int = get_team_total_hp(ai_units)

	# Fallback to single unit comparison if teams are empty
	if player_units.is_empty() and player_unit:
		player_total_hp = player_unit.current_hp
	if ai_units.is_empty() and ai_unit:
		ai_total_hp = ai_unit.current_hp

	if player_total_hp > ai_total_hp:
		_finish_battle(player_units[0].soul_id if not player_units.is_empty() else (player_unit.soul_id if player_unit else "player"), "victory")
	elif ai_total_hp > player_total_hp:
		_finish_battle(ai_units[0].soul_id if not ai_units.is_empty() else (ai_unit.soul_id if ai_unit else "ai"), "defeat")
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
	# GAP-001: Calculate team stats for 4v4 battles
	var player_team_damage: int = 0
	var ai_team_damage: int = 0
	var player_alive_count: int = 0
	var ai_alive_count: int = 0
	var player_team_stats: Array = []
	var ai_team_stats: Array = []

	for u in player_units:
		var unit_damage = u.max_hp - u.current_hp if u.current_hp < u.max_hp else 0
		player_team_damage += unit_damage
		if u.state != SoulUnit.UnitState.DEAD:
			player_alive_count += 1
		player_team_stats.append({
			"name": u.soul_name,
			"element": u.element,
			"hp_remaining": u.current_hp,
			"max_hp": u.max_hp,
			"alive": u.state != SoulUnit.UnitState.DEAD,
			"damage_dealt": unit_damage
		})

	for u in ai_units:
		var unit_damage = u.max_hp - u.current_hp if u.current_hp < u.max_hp else 0
		ai_team_damage += unit_damage
		if u.state != SoulUnit.UnitState.DEAD:
			ai_alive_count += 1
		ai_team_stats.append({
			"name": u.soul_name,
			"element": u.element,
			"hp_remaining": u.current_hp,
			"max_hp": u.max_hp,
			"alive": u.state != SoulUnit.UnitState.DEAD,
			"damage_dealt": unit_damage
		})

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
		"skills_used": [],
		# GAP-001: Team battle stats
		"is_team_battle": player_units.size() > 1 or ai_units.size() > 1,
		"player_team_size": player_units.size(),
		"ai_team_size": ai_units.size(),
		"player_team_damage": player_team_damage,
		"ai_team_damage": ai_team_damage,
		"player_alive_count": player_alive_count,
		"ai_alive_count": ai_alive_count,
		"player_team_stats": player_team_stats,
		"ai_team_stats": ai_team_stats
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


## Player command: move specific team unit to position (4v4 team battle)
func move_player_unit_to(p_index: int, p_position: Vector2) -> void:
	if p_index < 0 or p_index >= player_units.size():
		return
	var unit = player_units[p_index]
	if unit == null or unit.state == SoulUnit.UnitState.DEAD:
		return
	if battle_state != BattleState.ACTIVE:
		return
	unit.move_to(p_position)


## Player command: attack target
func player_attack_target(p_target: SoulUnit) -> void:
	if player_unit == null or player_unit.state == SoulUnit.UnitState.DEAD:
		return
	if battle_state != BattleState.ACTIVE:
		return
	player_unit.set_attack_target(p_target)


## Player command: set specific team unit attack target (4v4 team battle)
func set_player_unit_attack_target(p_index: int, p_target: SoulUnit) -> void:
	if p_index < 0 or p_index >= player_units.size():
		return
	var unit = player_units[p_index]
	if unit == null or unit.state == SoulUnit.UnitState.DEAD:
		return
	if battle_state != BattleState.ACTIVE:
		return
	unit.set_attack_target(p_target)


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


## Player command: use skill on specific team unit (4v4 team battle)
func player_unit_use_skill(p_index: int, p_skill_name: String, p_target: SoulUnit = null) -> bool:
	if p_index < 0 or p_index >= player_units.size():
		return false
	var unit = player_units[p_index]
	if unit == null or unit.state == SoulUnit.UnitState.DEAD:
		return false
	if battle_state != BattleState.ACTIVE:
		return false

	var target: SoulUnit = p_target
	if target == null:
		# Find nearest alive enemy
		target = _find_nearest_enemy(unit, ai_units)

	var success: bool = unit.use_skill(p_skill_name, target)
	if success:
		_add_log("%s uses %s!" % [unit.soul_name, p_skill_name])
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


## Set tactical command and update AI weights (GDD v2.0 Chapter 2.1.1)
func set_tactical_command(command_id: String, weights: Dictionary) -> void:
	current_tactical_command = command_id
	tactical_weights = weights
	GameLog.info("Tactical command set: %s" % command_id, "ArenaManager")


## Get current tactical weight modifier
func get_tactical_weight(modifier_name: String, default_value: float = 1.0) -> float:
	return tactical_weights.get(modifier_name, default_value)


## Clean up battle
func cleanup_battle() -> void:
	# Clean up player units
	for unit in player_units:
		if unit != null and is_instance_valid(unit):
			unit.queue_free()
	player_units.clear()
	# Clean up AI units
	for unit in ai_units:
		if unit != null and is_instance_valid(unit):
			unit.queue_free()
	ai_units.clear()
	# Clear compatibility references
	player_unit = null
	ai_unit = null
	# Clear entity IDs
	_player_entity_ids.clear()
	_ai_entity_ids.clear()
	# Clear AI controllers
	_ai_controllers.clear()
	_player_ai_controllers.clear()
	_ai_controller = null
	_player_ai_controller = null
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
	var info: Dictionary = {
		"state": battle_state,
		"time": battle_time,
		"result": battle_result,
		"winner_id": winner_id,
		"player": player_unit.get_info() if player_unit != null else {},
		"ai": ai_unit.get_info() if ai_unit != null else {},
		"log_count": battle_log.size(),
		"weather": _environment.get_weather_name() if _environment != null else "Clear"
	}
	# GAP-001: Add team info
	if not player_units.is_empty():
		var p_team: Array = []
		for u in player_units:
			p_team.append(u.get_info())
		info["player_team"] = p_team
		info["player_alive"] = get_alive_count(player_units)
	if not ai_units.is_empty():
		var a_team: Array = []
		for u in ai_units:
			a_team.append(u.get_info())
		info["ai_team"] = a_team
		info["ai_alive"] = get_alive_count(ai_units)
		info["team_battle"] = true
	return info


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
