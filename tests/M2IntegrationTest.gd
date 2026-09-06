extends Node2D
## M2IntegrationTest - Integration tests for M2 RTS arena features
##
## Tests BattleResultManager, ArenaMap, SoulUnit, and RTSArenaManager.
## Run via: m2_test_runner.gd (SceneTree wrapper)

# Preload scripts without class_name
const SoulUnit = preload("res://scripts/game/SoulUnit.gd")

## Test counters
var _tests_run: int = 0
var _tests_passed: int = 0
var _tests_failed: int = 0
var _failed_tests: Array = []


func _ready() -> void:
	print("\n=== M2 Integration Tests ===")
	print("Testing RTS arena battle system...\n")

	# Run all test suites
	_test_battle_result_manager()
	_test_arena_map()
	_test_soul_unit()
	_test_rts_arena_manager()
	_test_soul_ai_controller()
	_test_arena_environment()
	_test_arena_manager_environment()
	_test_battle_result_growth()
	_test_soul_unit_combat()

	# Print summary
	print("\n=== M2 TEST SUMMARY ===")
	print("Passed: %d" % _tests_passed)
	print("Failed: %d" % _tests_failed)
	print("Total: %d" % _tests_run)

	if _tests_failed > 0:
		print("\nFAILED TESTS:")
		for test_name in _failed_tests:
			print("  - %s" % test_name)

	# Exit with appropriate code
	get_tree().quit(_tests_failed)


## Assert helper
func _assert(condition: bool, test_name: String) -> void:
	_tests_run += 1
	if condition:
		_tests_passed += 1
		print("[PASS] %s" % test_name)
	else:
		_tests_failed += 1
		_failed_tests.append(test_name)
		print("[FAIL] %s" % test_name)


## ============================================
## BattleResultManager Tests
## ============================================
func _test_battle_result_manager() -> void:
	print("\n--- BattleResultManager Tests ---")

	# Test 1: Manager exists and is initialized
	_assert(BattleResultManager != null, "BattleResultManager initialized")

	# Test 2: Process victory result
	var result = BattleResultManager.process_battle_result({
		"result": "victory",
		"player_soul_id": "test_soul_1",
		"opponent_soul_id": "test_ai_1",
		"player_level": 5,
		"opponent_level": 5,
		"player_hp_remaining": 80,
		"player_max_hp": 100,
		"duration": 45.0,
		"damage_dealt": 120,
		"damage_taken": 20,
		"skills_used": ["heavy_strike", "basic_attack"]
	})
	_assert(result.has("experience_gained"), "Battle result returns experience_gained")
	_assert(result["experience_gained"] > 0, "Victory gives positive experience")

	# Test 3: Process defeat result
	var defeat_result = BattleResultManager.process_battle_result({
		"result": "defeat",
		"player_soul_id": "test_soul_1",
		"opponent_soul_id": "test_ai_2",
		"player_level": 3,
		"opponent_level": 7,
		"player_hp_remaining": 0,
		"player_max_hp": 100,
		"duration": 60.0,
		"damage_dealt": 50,
		"damage_taken": 100,
		"skills_used": []
	})
	_assert(defeat_result["experience_gained"] > 0, "Defeat gives some experience")

	# Test 4: Statistics updated
	var stats = BattleResultManager.get_stats()
	_assert(stats["total_battles"] >= 2, "Total battles updated")
	_assert(stats["victories"] >= 1, "Victories count updated")
	_assert(stats["defeats"] >= 1, "Defeats count updated")
	_assert(stats["total_experience_gained"] > 0, "Total experience accumulated")

	# Test 5: Battle history recorded
	var history = BattleResultManager.get_history(10)
	_assert(history.size() >= 2, "Battle history recorded")

	# Test 6: Per-soul record
	var soul_record = BattleResultManager.get_soul_record("test_soul_1")
	_assert(soul_record["battles"] >= 2, "Per-soul battle count correct")
	_assert(soul_record["total_experience"] > 0, "Per-soul experience correct")

	# Test 7: Draw result
	var draw_result = BattleResultManager.process_battle_result({
		"result": "draw",
		"player_soul_id": "test_soul_2",
		"opponent_soul_id": "test_ai_3",
		"player_level": 4,
		"opponent_level": 4,
		"player_hp_remaining": 50,
		"player_max_hp": 100,
		"duration": 120.0,
		"damage_dealt": 80,
		"damage_taken": 80,
		"skills_used": []
	})
	_assert(draw_result["experience_gained"] > 0, "Draw gives experience")
	_assert(BattleResultManager.get_stats()["draws"] >= 1, "Draws count updated")


## ============================================
## ArenaMap Tests
## ============================================
func _test_arena_map() -> void:
	print("\n--- ArenaMap Tests ---")

	# Test 1: ArenaMap exists
	_assert(ArenaMap != null, "ArenaMap initialized")

	# Test 2: Load default map
	ArenaMap.load_map("default_arena")
	_assert(ArenaMap.map_name == "default_arena", "Default map loaded")
	_assert(ArenaMap.obstacles.size() > 0, "Default map has obstacles")
	_assert(ArenaMap.player_spawn != Vector2.ZERO, "Player spawn set")
	_assert(ArenaMap.ai_spawn != Vector2.ZERO, "AI spawn set")

	# Test 3: Load forest map
	ArenaMap.load_map("forest_arena")
	_assert(ArenaMap.map_name == "forest_arena", "Forest map loaded")

	# Test 4: Load crystal map
	ArenaMap.load_map("crystal_arena")
	_assert(ArenaMap.map_name == "crystal_arena", "Crystal map loaded")

	# Test 5: Available maps list
	var maps = ArenaMap.get_available_maps()
	_assert(maps.size() == 3, "Three available maps")
	_assert(maps.has("default_arena"), "Default map in list")
	_assert(maps.has("forest_arena"), "Forest map in list")
	_assert(maps.has("crystal_arena"), "Crystal map in list")

	# Test 6: Position validation - valid position
	ArenaMap.load_map("default_arena")
	var valid_pos = ArenaMap.is_position_valid(Vector2(640, 300), 32.0)
	_assert(valid_pos == false, "Center position blocked by crystal")

	# Test 7: Position validation - open position
	var open_pos = ArenaMap.is_position_valid(Vector2(400, 300), 32.0)
	_assert(open_pos == true, "Open position valid")

	# Test 8: Terrain speed modifier
	var speed_mod = ArenaMap.get_terrain_speed_modifier(Vector2(100, 100))
	_assert(speed_mod > 0, "Terrain speed modifier positive")
	_assert(speed_mod <= 1.0, "Terrain speed modifier <= 1.0")

	# Test 9: Map info
	var map_info = ArenaMap.get_map_info()
	_assert(map_info.has("name"), "Map info has name")
	_assert(map_info.has("obstacle_count"), "Map info has obstacle count")
	_assert(map_info["width"] == 1280, "Map width correct")
	_assert(map_info["height"] == 600, "Map height correct")

	# Test 10: Reset map
	ArenaMap.reset_map()
	var all_intact = true
	for obstacle in ArenaMap.obstacles:
		if obstacle["destroyed"]:
			all_intact = false
	_assert(all_intact, "Map reset restores all obstacles")


## ============================================
## SoulUnit Tests
## ============================================
func _test_soul_unit() -> void:
	print("\n--- SoulUnit Tests ---")

	# Test 1: Create and initialize unit
	var unit = SoulUnit.new()
	unit.init_from_soul("test_unit", "Test Soul", "fire", 5, true)
	_assert(unit.soul_name == "Test Soul", "Unit name correct")
	_assert(unit.element == "fire", "Unit element correct")
	_assert(unit.level == 5, "Unit level correct")
	_assert(unit.is_player_controlled == true, "Unit player flag correct")

	# Test 2: Stats scaled by level
	_assert(unit.max_hp == 100 + 5 * 20, "HP scaled by level (200)")
	_assert(unit.attack_damage == 10 + 5 * 3, "Attack scaled by level (25)")
	_assert(unit.current_hp == unit.max_hp, "Full HP at init")
	_assert(unit.current_energy == unit.max_energy, "Full energy at init")

	# Test 3: Unit state
	_assert(unit.state == SoulUnit.UnitState.IDLE, "Unit starts idle")

	# Test 4: Move command
	unit.move_to(Vector2(100, 100))
	_assert(unit.state == SoulUnit.UnitState.MOVING, "Unit state changes to moving")
	_assert(unit.target_position == Vector2(100, 100), "Target position set")

	# Test 5: Take damage
	var unit2 = SoulUnit.new()
	unit2.init_from_soul("target", "Target", "water", 3, false)
	var initial_hp = unit2.current_hp
	unit2.take_damage(20, unit)
	_assert(unit2.current_hp == initial_hp - 20, "Damage applied correctly")
	_assert(unit2.state != SoulUnit.UnitState.DEAD, "Unit alive after damage")

	# Test 6: Unit death
	unit2.take_damage(1000, unit)
	_assert(unit2.current_hp == 0, "HP zeroed on death")
	_assert(unit2.state == SoulUnit.UnitState.DEAD, "Unit state changes to dead")

	# Test 7: Skill cooldowns initialized
	_assert(unit.skill_cooldowns.has("basic_attack"), "Basic attack cooldown exists")
	_assert(unit.skill_cooldowns.has("heavy_strike"), "Heavy strike cooldown exists")
	_assert(unit.skill_cooldowns.has("heal"), "Heal cooldown exists")
	_assert(unit.skill_cooldowns["heavy_strike"] == 0.0, "Cooldowns start at 0")

	# Test 8: Use skill - heal
	var heal_unit = SoulUnit.new()
	heal_unit.init_from_soul("healer", "Healer", "light", 5, true)
	heal_unit.current_hp = 50
	var hp_before = heal_unit.current_hp
	heal_unit.use_skill("heal")
	_assert(heal_unit.current_hp > hp_before, "Heal increases HP")
	_assert(heal_unit.skill_cooldowns["heal"] > 0, "Heal goes on cooldown")

	# Test 9: Get info
	var info = unit.get_info()
	_assert(info.has("id"), "Unit info has id")
	_assert(info.has("hp"), "Unit info has hp")
	_assert(info.has("state"), "Unit info has state")
	_assert(info["is_alive"] == true, "Unit info reports alive")

	# Test 10: Stop action
	unit.stop()
	_assert(unit.state == SoulUnit.UnitState.IDLE, "Stop returns to idle")
	_assert(unit.attack_target == null, "Stop clears attack target")

	# Cleanup
	unit.queue_free()
	unit2.queue_free()
	heal_unit.queue_free()


## ============================================
## RTSArenaManager Tests
## ============================================
func _test_rts_arena_manager() -> void:
	print("\n--- RTSArenaManager Tests ---")

	# Test 1: Manager exists
	_assert(RTSArenaManager != null, "RTSArenaManager initialized")

	# Test 2: Start battle
	var player_soul = {"id": "test_p", "name": "Player", "element": "fire", "level": 5}
	var ai_soul = {"id": "test_a", "name": "AI", "element": "water", "level": 5}
	var started = RTSArenaManager.start_battle(player_soul, ai_soul, "default_arena")
	_assert(started == true, "Battle started successfully")
	_assert(RTSArenaManager.battle_state == RTSArenaManager.BattleState.ACTIVE, "Battle state active")

	# Test 3: Units spawned
	_assert(RTSArenaManager.player_unit != null, "Player unit spawned")
	_assert(RTSArenaManager.ai_unit != null, "AI unit spawned")
	_assert(RTSArenaManager.player_unit.soul_name == "Player", "Player unit name correct")
	_assert(RTSArenaManager.ai_unit.soul_name == "AI", "AI unit name correct")

	# Test 4: Battle time starts at 0
	_assert(RTSArenaManager.battle_time == 0.0, "Battle time starts at 0")

	# Test 5: Player move command
	RTSArenaManager.player_move_to(Vector2(500, 300))
	_assert(RTSArenaManager.player_unit.state == SoulUnit.UnitState.MOVING, "Player unit moving")

	# Test 6: Player attack command
	RTSArenaManager.player_attack_target(RTSArenaManager.ai_unit)
	_assert(RTSArenaManager.player_unit.attack_target == RTSArenaManager.ai_unit, "Player attack target set")

	# Test 7: Player use skill
	var skill_result = RTSArenaManager.player_use_skill("defend")
	_assert(skill_result == true, "Player can use defend skill")

	# Test 8: Battle info
	var info = RTSArenaManager.get_battle_info()
	_assert(info.has("state"), "Battle info has state")
	_assert(info.has("player"), "Battle info has player")
	_assert(info.has("ai"), "Battle info has ai")
	_assert(info["player"]["name"] == "Player", "Battle info player name correct")

	# Test 9: Battle log
	var log = RTSArenaManager.get_recent_log(10)
	_assert(log.size() >= 0, "Battle log accessible")

	# Test 10: Forfeit battle
	RTSArenaManager.forfeit_battle()
	_assert(RTSArenaManager.battle_state == RTSArenaManager.BattleState.FINISHED, "Battle finished after forfeit")
	_assert(RTSArenaManager.battle_result == "defeat", "Forfeit results in defeat")

	# Test 11: Cleanup
	RTSArenaManager.cleanup_battle()
	_assert(RTSArenaManager.battle_state == RTSArenaManager.BattleState.IDLE, "Battle cleaned up")
	_assert(RTSArenaManager.player_unit == null, "Player unit removed")
	_assert(RTSArenaManager.ai_unit == null, "AI unit removed")

	# Test 12: Reset battle for rematch
	var p2 = {"id": "test_p2", "name": "Player2", "element": "earth", "level": 3}
	var a2 = {"id": "test_a2", "name": "AI2", "element": "wind", "level": 3}
	RTSArenaManager.start_battle(p2, a2, "forest_arena")
	_assert(RTSArenaManager.battle_state == RTSArenaManager.BattleState.ACTIVE, "Second battle started")
	RTSArenaManager.reset_battle()
	_assert(RTSArenaManager.battle_state == RTSArenaManager.BattleState.IDLE, "Battle reset to idle")
	_assert(RTSArenaManager.player_unit == null, "Player unit removed after reset")
	_assert(RTSArenaManager.ai_unit == null, "AI unit removed after reset")
	_assert(RTSArenaManager.winner_id == "", "Winner cleared after reset")
	_assert(RTSArenaManager.battle_result == "", "Result cleared after reset")

	# Test 13: Player macro command (coach-style RTS)
	var p3 = {"id": "test_p3", "name": "Coach", "element": "fire", "level": 5}
	var a3 = {"id": "test_a3", "name": "Opponent", "element": "water", "level": 5}
	RTSArenaManager.start_battle(p3, a3, "default_arena")
	var cmd_result = RTSArenaManager.issue_player_command("attack")
	_assert(cmd_result.get("success", false) == true, "Player command attack accepted")
	_assert(cmd_result.has("command"), "Command result has command field")
	_assert(cmd_result.get("command") == "attack", "Command is attack")

	# Test 14: Command cooldown
	var cmd2 = RTSArenaManager.issue_player_command("defend")
	_assert(cmd2.get("success", false) == false, "Second command rejected during cooldown")
	_assert(cmd2.has("error"), "Rejected command has error field")

	# Test 15: Command cooldown getter
	var cooldown = RTSArenaManager.get_player_command_cooldown()
	_assert(cooldown > 0.0, "Command cooldown active after command")
	_assert(cooldown <= 30.0, "Cooldown within 30 second limit")

	# Test 16: All valid commands
	var valid_commands = ["gather", "attack", "defend", "retreat"]
	for cmd_name in valid_commands:
		# Reset cooldown by starting new battle
		RTSArenaManager.reset_battle()
		RTSArenaManager.start_battle(p3, a3, "default_arena")
		var r = RTSArenaManager.issue_player_command(cmd_name)
		_assert(r.get("success", false) == true, "Command '%s' accepted" % cmd_name)
	RTSArenaManager.reset_battle()

	# Test 17: Invalid command
	RTSArenaManager.start_battle(p3, a3, "default_arena")
	var invalid = RTSArenaManager.issue_player_command("invalid_cmd")
	_assert(invalid.get("success", false) == false, "Invalid command rejected")
	RTSArenaManager.reset_battle()


## ============================================
## SoulAIController Tests
## ============================================
func _test_soul_ai_controller() -> void:
	print("\n--- SoulAIController Tests ---")

	# Preload AI controller
	const SoulAIController = preload("res://scripts/game/SoulAIController.gd")

	# Test 1: Create AI controller
	var ai = SoulAIController.new()
	_assert(ai != null, "SoulAIController created")

	# Test 2: Default state
	var state = ai.get_state_info()
	_assert(state.has("decision"), "State has decision")
	_assert(state.has("player_command"), "State has player_command")
	_assert(state.has("command_cooldown"), "State has command_cooldown")
	_assert(state["player_command"] == "", "No player command initially")
	_assert(state["command_cooldown"] == 0.0, "No command cooldown initially")

	# Test 3: Issue command
	var issued = ai.issue_command("attack")
	_assert(issued == true, "Command attack issued")
	_assert(ai.player_command == "attack", "Player command set to attack")
	_assert(ai.command_cooldown > 0.0, "Command cooldown active after issue")

	# Test 4: Command cooldown blocks second command
	var issued2 = ai.issue_command("defend")
	_assert(issued2 == false, "Second command blocked during cooldown")

	# Test 5: All valid commands
	var valid_commands = ["gather", "attack", "defend", "retreat"]
	for cmd_name in valid_commands:
		var ai2 = SoulAIController.new()
		var r = ai2.issue_command(cmd_name)
		_assert(r == true, "Command '%s' is valid" % cmd_name)

	# Test 6: Invalid command
	var ai3 = SoulAIController.new()
	var invalid = ai3.issue_command("invalid_cmd")
	_assert(invalid == false, "Invalid command rejected")

	# Test 7: Battle memory
	_assert(ai.battle_memory.has("times_hit_by_heavy"), "Memory has times_hit_by_heavy")
	_assert(ai.battle_memory.has("favorite_skill"), "Memory has favorite_skill")
	_assert(ai.battle_memory["times_hit_by_heavy"] == 0, "Memory starts at 0")

	# Test 8: Update battle memory
	ai.battle_memory["times_hit_by_heavy"] = 3
	ai.battle_memory["favorite_skill"] = "heavy_strike"
	_assert(ai.battle_memory["times_hit_by_heavy"] == 3, "Memory updated")
	_assert(ai.battle_memory["favorite_skill"] == "heavy_strike", "Favorite skill updated")

	# Test 9: Decision cooldown
	_assert(ai.decision_cooldown == 0.0, "Decision cooldown starts at 0")
	_assert(ai.decision_interval == 1.5, "Decision interval is 1.5s")

	# Test 10: Make decision with SoulUnit
	var self_unit = SoulUnit.new()
	self_unit.init_from_soul("test_self", "TestSelf", "fire", 5, false)
	self_unit.personality = {"aggression": 80, "courage": 70, "curiosity": 50, "patience": 50, "loyalty": 90, "intelligence": 60}
	self_unit.emotion = {"mood": "neutral", "intensity": 0.0}

	var enemy_unit = SoulUnit.new()
	enemy_unit.init_from_soul("test_enemy", "TestEnemy", "water", 5, true)

	var ai4 = SoulAIController.new()
	var decision = ai4.make_decision(self_unit, enemy_unit)
	_assert(decision.has("decision"), "Decision has decision field")
	_assert(decision.has("target"), "Decision has target field")
	_assert(typeof(decision["decision"]) == TYPE_INT, "Decision is integer enum")
	_assert(decision["decision"] >= 0 and decision["decision"] <= 7, "Decision value in valid range (0-7): %d" % decision["decision"])

	# Test 11: Damage modifier with anger
	self_unit.emotion = {"mood": "anger", "intensity": 1.0}
	var dmg_mod = ai4.get_damage_modifier(self_unit)
	_assert(dmg_mod >= 1.0, "Anger increases damage modifier (%.2f)" % dmg_mod)
	_assert(dmg_mod <= 1.3, "Damage modifier within reasonable range")

	# Test 12: Defense modifier with fear
	self_unit.emotion = {"mood": "fear", "intensity": 1.0}
	var def_mod = ai4.get_defense_modifier(self_unit)
	_assert(def_mod >= 1.0, "Fear increases defense modifier (%.2f)" % def_mod)

	# Cleanup
	self_unit.queue_free()
	enemy_unit.queue_free()


## ============================================
## ArenaEnvironment Tests
## ============================================
func _test_arena_environment() -> void:
	print("\n--- ArenaEnvironment Tests ---")

	# Preload environment
	const ArenaEnvironment = preload("res://scripts/game/ArenaEnvironment.gd")

	# Test 1: Create environment
	var env = ArenaEnvironment.new()
	_assert(env != null, "ArenaEnvironment created")

	# Test 2: Default weather is CLEAR
	_assert(env.current_weather == ArenaEnvironment.WeatherType.CLEAR, "Default weather is CLEAR")

	# Test 3: Setup for default_arena map
	env.setup_for_map("default_arena")
	_assert(env.current_weather == ArenaEnvironment.WeatherType.CLEAR, "default_arena weather is CLEAR")

	# Test 4: Setup for forest_arena map
	env.setup_for_map("forest_arena")
	_assert(env.current_weather == ArenaEnvironment.WeatherType.RAIN, "forest_arena weather is RAIN")

	# Test 5: Setup for crystal_arena map
	env.setup_for_map("crystal_arena")
	_assert(env.current_weather == ArenaEnvironment.WeatherType.SNOW, "crystal_arena weather is SNOW")

	# Test 6: Unknown map defaults to CLEAR
	env.setup_for_map("unknown_map")
	_assert(env.current_weather == ArenaEnvironment.WeatherType.CLEAR, "Unknown map defaults to CLEAR")

	# Test 7: Weather movement modifiers
	env.current_weather = ArenaEnvironment.WeatherType.CLEAR
	_assert(env.get_weather_movement_modifier() == 1.0, "CLEAR movement mod is 1.0")
	env.current_weather = ArenaEnvironment.WeatherType.RAIN
	_assert(env.get_weather_movement_modifier() == 0.9, "RAIN movement mod is 0.9")
	env.current_weather = ArenaEnvironment.WeatherType.FOG
	_assert(env.get_weather_movement_modifier() == 1.0, "FOG movement mod is 1.0")
	env.current_weather = ArenaEnvironment.WeatherType.SNOW
	_assert(env.get_weather_movement_modifier() == 0.85, "SNOW movement mod is 0.85")
	env.current_weather = ArenaEnvironment.WeatherType.STORM
	_assert(env.get_weather_movement_modifier() == 0.8, "STORM movement mod is 0.8")

	# Test 8: Weather accuracy modifiers
	env.current_weather = ArenaEnvironment.WeatherType.CLEAR
	_assert(env.get_weather_accuracy_modifier() == 1.0, "CLEAR accuracy mod is 1.0")
	env.current_weather = ArenaEnvironment.WeatherType.RAIN
	_assert(env.get_weather_accuracy_modifier() == 0.95, "RAIN accuracy mod is 0.95")
	env.current_weather = ArenaEnvironment.WeatherType.FOG
	_assert(env.get_weather_accuracy_modifier() == 0.9, "FOG accuracy mod is 0.9")
	env.current_weather = ArenaEnvironment.WeatherType.STORM
	_assert(env.get_weather_accuracy_modifier() == 0.85, "STORM accuracy mod is 0.85")

	# Test 9: Weather visibility modifiers
	env.current_weather = ArenaEnvironment.WeatherType.CLEAR
	_assert(env.get_visibility_modifier() == 1.0, "CLEAR visibility mod is 1.0")
	env.current_weather = ArenaEnvironment.WeatherType.FOG
	_assert(env.get_visibility_modifier() == 0.7, "FOG visibility mod is 0.7")
	env.current_weather = ArenaEnvironment.WeatherType.STORM
	_assert(env.get_visibility_modifier() == 0.6, "STORM visibility mod is 0.6")

	# Test 10: Weather defense modifiers
	env.current_weather = ArenaEnvironment.WeatherType.SNOW
	_assert(env.get_weather_defense_modifier() == 1.1, "SNOW defense mod is 1.1")
	env.current_weather = ArenaEnvironment.WeatherType.CLEAR
	_assert(env.get_weather_defense_modifier() == 1.0, "CLEAR defense mod is 1.0")

	# Test 11: Weather name
	env.current_weather = ArenaEnvironment.WeatherType.CLEAR
	_assert(env.get_weather_name() == "Clear", "CLEAR weather name is 'Clear'")
	env.current_weather = ArenaEnvironment.WeatherType.STORM
	_assert(env.get_weather_name() == "Storm", "STORM weather name is 'Storm'")

	# Test 12: Environment info
	env.current_weather = ArenaEnvironment.WeatherType.RAIN
	var info = env.get_environment_info()
	_assert(info.has("weather"), "Environment info has weather")
	_assert(info["weather"] == "Rain", "Environment info weather name correct")
	_assert(info.has("movement_mod"), "Environment info has movement_mod")
	_assert(info.has("accuracy_mod"), "Environment info has accuracy_mod")
	_assert(info.has("visibility_mod"), "Environment info has visibility_mod")
	_assert(info.has("defense_mod"), "Environment info has defense_mod")

	# Test 13: Force set weather
	env.set_weather(ArenaEnvironment.WeatherType.STORM)
	_assert(env.current_weather == ArenaEnvironment.WeatherType.STORM, "set_weather changes to STORM")
	_assert(env.weather_timer == 0.0, "set_weather resets timer")

	# Test 14: Invalid weather set ignored
	var before = env.current_weather
	env.set_weather(999)
	_assert(env.current_weather == before, "Invalid weather type ignored")

	# Test 15: Terrain damage (lava)
	var lava_damage = env.get_terrain_damage(Vector2(640, 300))
	_assert(lava_damage >= 0.0, "Terrain damage is non-negative")

	# Test 16: Total movement modifier combines weather + terrain
	env.current_weather = ArenaEnvironment.WeatherType.RAIN
	var total_mod = env.get_total_movement_modifier(Vector2(100, 100))
	_assert(total_mod > 0.0, "Total movement modifier positive")
	_assert(total_mod <= 1.0, "Total movement modifier <= 1.0")

	# Test 17: Update returns events dictionary
	env.setup_for_map("default_arena")
	var events = env.update(0.1)
	_assert(events.has("weather_changed"), "Update returns weather_changed")
	_assert(events.has("lightning"), "Update returns lightning")
	_assert(events.has("lightning_position"), "Update returns lightning_position")

	# Test 18: Weather timer increments
	env.setup_for_map("default_arena")
	env.update(10.0)
	_assert(env.weather_timer == 10.0, "Weather timer increments by delta")


## ============================================
## RTSArenaManager Environment Integration Tests
## ============================================
func _test_arena_manager_environment() -> void:
	print("\n--- RTSArenaManager Environment Integration Tests ---")

	# Test soul data
	var p_soul = {"id": "test_p", "name": "Player", "element": "fire", "level": 5}
	var a_soul = {"id": "test_a", "name": "AI", "element": "water", "level": 5}

	# Test 1: Start battle initializes environment
	RTSArenaManager.start_battle(p_soul, a_soul, "default_arena")
	var env_info = RTSArenaManager.get_environment_info()
	_assert(env_info.has("weather"), "Environment info has weather after battle start")
	_assert(env_info["weather"] == "Clear", "default_arena weather is Clear")

	# Test 2: Environment info contains all modifier fields
	_assert(env_info.has("movement_mod"), "Environment info has movement_mod")
	_assert(env_info.has("accuracy_mod"), "Environment info has accuracy_mod")
	_assert(env_info.has("visibility_mod"), "Environment info has visibility_mod")
	_assert(env_info.has("defense_mod"), "Environment info has defense_mod")
	_assert(env_info["movement_mod"] == 1.0, "Clear movement_mod is 1.0")
	_assert(env_info["accuracy_mod"] == 1.0, "Clear accuracy_mod is 1.0")

	# Test 3: Battle config stores weather
	var battle_info = RTSArenaManager.get_battle_info()
	_assert(battle_info.has("weather"), "Battle info has weather")
	_assert(battle_info["weather"] == "Clear", "Battle config weather is Clear")

	# Test 4: Cleanup clears environment (returns default)
	RTSArenaManager.cleanup_battle()
	var env_after = RTSArenaManager.get_environment_info()
	_assert(env_after.get("weather", "") == "Clear", "Environment returns default Clear after cleanup")

	# Test 5: Forest map starts with rain
	RTSArenaManager.start_battle(p_soul, a_soul, "forest_arena")
	var forest_env = RTSArenaManager.get_environment_info()
	_assert(forest_env["weather"] == "Rain", "forest_arena weather is Rain")
	_assert(forest_env["movement_mod"] == 0.9, "Rain movement_mod is 0.9")
	_assert(forest_env["accuracy_mod"] == 0.95, "Rain accuracy_mod is 0.95")
	RTSArenaManager.cleanup_battle()

	# Test 6: Crystal map starts with snow
	RTSArenaManager.start_battle(p_soul, a_soul, "crystal_arena")
	var crystal_env = RTSArenaManager.get_environment_info()
	_assert(crystal_env["weather"] == "Snow", "crystal_arena weather is Snow")
	_assert(crystal_env["defense_mod"] == 1.1, "Snow defense_mod is 1.1")
	RTSArenaManager.cleanup_battle()

	# Test 7: Reset battle reinitializes environment (returns default)
	RTSArenaManager.start_battle(p_soul, a_soul, "default_arena")
	RTSArenaManager.reset_battle()
	var reset_env = RTSArenaManager.get_environment_info()
	_assert(reset_env.get("weather", "") == "Clear", "Environment returns default Clear after reset")

	# Test 8: Process updates environment (no crash)
	RTSArenaManager.start_battle(p_soul, a_soul, "default_arena")
	RTSArenaManager._process(0.1)
	var proc_env = RTSArenaManager.get_environment_info()
	_assert(proc_env.has("weather"), "Environment valid after process")
	RTSArenaManager.cleanup_battle()

	# Test 9: Multiple battle starts/cleanups (no leak)
	for i in range(3):
		RTSArenaManager.start_battle(p_soul, a_soul, "default_arena")
		_assert(RTSArenaManager.get_environment_info()["weather"] == "Clear", "Battle %d environment valid" % i)
		RTSArenaManager.cleanup_battle()

	# Test 10: Environment info format for UI
	RTSArenaManager.start_battle(p_soul, a_soul, "default_arena")
	var ui_info = RTSArenaManager.get_environment_info()
	_assert(typeof(ui_info["weather"]) == TYPE_STRING, "Weather is string for UI")
	_assert(typeof(ui_info["movement_mod"]) == TYPE_FLOAT, "movement_mod is float for UI")
	_assert(typeof(ui_info["accuracy_mod"]) == TYPE_FLOAT, "accuracy_mod is float for UI")
	RTSArenaManager.cleanup_battle()


## ============================================
## Battle Result Growth Feedback Tests
## ============================================
func _test_battle_result_growth() -> void:
	print("\n--- Battle Result Growth Feedback Tests ---")

	# Clear history first for clean test
	BattleResultManager.clear_history()

	# Test 1: Victory gives more experience than defeat
	var victory_data = {
		"result": "victory",
		"player_soul_id": "growth_test_1",
		"opponent_soul_id": "ai_test_1",
		"player_level": 5,
		"opponent_level": 5,
		"player_hp_remaining": 80,
		"player_max_hp": 100,
		"duration": 60.0,
		"damage_dealt": 120,
		"damage_taken": 20,
		"skills_used": ["fireball", "shield"]
	}
	var victory_result = BattleResultManager.process_battle_result(victory_data)
	_assert(victory_result.has("experience_gained"), "Victory result has experience_gained")
	var victory_exp = victory_result["experience_gained"]
	_assert(victory_exp > 0, "Victory gives positive experience: %d" % victory_exp)

	var defeat_data = victory_data.duplicate()
	defeat_data["result"] = "defeat"
	defeat_data["player_soul_id"] = "growth_test_2"
	var defeat_result = BattleResultManager.process_battle_result(defeat_data)
	var defeat_exp = defeat_result["experience_gained"]
	_assert(defeat_exp >= 0, "Defeat gives non-negative experience: %d" % defeat_exp)
	_assert(victory_exp > defeat_exp, "Victory gives more EXP than defeat (%d > %d)" % [victory_exp, defeat_exp])

	# Test 2: Higher level opponent gives more experience
	var low_opponent = victory_data.duplicate()
	low_opponent["opponent_level"] = 1
	low_opponent["player_soul_id"] = "growth_test_3"
	var low_result = BattleResultManager.process_battle_result(low_opponent)

	var high_opponent = victory_data.duplicate()
	high_opponent["opponent_level"] = 10
	high_opponent["player_soul_id"] = "growth_test_4"
	var high_result = BattleResultManager.process_battle_result(high_opponent)
	_assert(high_result["experience_gained"] >= low_result["experience_gained"],
		"Higher level opponent gives >= EXP (%d >= %d)" % [high_result["experience_gained"], low_result["experience_gained"]])

	# Test 3: Battle history records battles
	var history = BattleResultManager.get_history()
	_assert(history.size() >= 4, "Battle history has at least 4 records: %d" % history.size())
	var latest = history[history.size() - 1]
	_assert(latest.has("battle_id"), "History record has battle_id")
	_assert(latest.has("result"), "History record has result")
	_assert(latest.has("experience_gained"), "History record has experience_gained")
	_assert(latest.has("timestamp"), "History record has timestamp")

	# Test 4: get_history with limit
	var limited = BattleResultManager.get_history(2)
	_assert(limited.size() <= 2, "get_history(2) returns at most 2 records: %d" % limited.size())

	# Test 5: Statistics tracking
	var stats = BattleResultManager.get_stats()
	_assert(stats.has("total_battles"), "Stats has total_battles")
	_assert(stats.has("victories"), "Stats has victories")
	_assert(stats.has("defeats"), "Stats has defeats")
	_assert(stats.has("total_experience_gained"), "Stats has total_experience_gained")
	_assert(stats["total_battles"] >= 4, "Total battles >= 4: %d" % stats["total_battles"])
	_assert(stats["total_experience_gained"] > 0, "Total experience > 0: %d" % stats["total_experience_gained"])

	# Test 6: Soul record tracking
	var soul_record = BattleResultManager.get_soul_record("growth_test_1")
	_assert(soul_record.has("battles"), "Soul record has battles")
	_assert(soul_record.has("victories"), "Soul record has victories")
	_assert(soul_record["battles"] >= 1, "Soul growth_test_1 has >= 1 battle")

	# Test 7: Nonexistent soul returns empty record
	var empty_record = BattleResultManager.get_soul_record("nonexistent_soul")
	_assert(empty_record.get("battles", 0) == 0, "Nonexistent soul has 0 battles")

	# Test 8: Draw result gives experience
	var draw_data = victory_data.duplicate()
	draw_data["result"] = "draw"
	draw_data["player_soul_id"] = "growth_test_5"
	var draw_result = BattleResultManager.process_battle_result(draw_data)
	_assert(draw_result["experience_gained"] >= 0, "Draw gives non-negative experience")

	# Test 9: Battle record includes skills used
	var skill_history = BattleResultManager.get_history()
	var with_skills = skill_history[skill_history.size() - 1]
	_assert(with_skills.has("skills_used"), "Battle record has skills_used")
	_assert(with_skills["skills_used"].size() == 2, "Battle record has 2 skills used")

	# Test 10: Clear history works
	BattleResultManager.clear_history()
	var cleared = BattleResultManager.get_history()
	_assert(cleared.size() == 0, "History cleared: %d records" % cleared.size())
	var cleared_stats = BattleResultManager.get_stats()
	_assert(cleared_stats["total_battles"] == 0, "Stats reset after clear: %d" % cleared_stats["total_battles"])


## ============================================
## SoulUnit Combat Tests
## ============================================
func _test_soul_unit_combat() -> void:
	print("\n--- SoulUnit Combat Tests ---")

	# Create test units
	var unit1 = SoulUnit.new()
	unit1.init_from_soul("test_u1", "FireSoul", "fire", 5, true)
	var unit2 = SoulUnit.new()
	unit2.init_from_soul("test_u2", "WaterSoul", "water", 5, false)

	# Test 1: init_from_soul sets properties correctly
	_assert(unit1.soul_id == "test_u1", "Unit1 soul_id correct")
	_assert(unit1.soul_name == "FireSoul", "Unit1 soul_name correct")
	_assert(unit1.element == "fire", "Unit1 element correct")
	_assert(unit1.level == 5, "Unit1 level correct")
	_assert(unit1.is_player_controlled == true, "Unit1 is player controlled")
	_assert(unit2.is_player_controlled == false, "Unit2 is AI controlled")

	# Test 2: Initial HP and energy
	_assert(unit1.current_hp == unit1.max_hp, "Unit1 HP full at init: %d/%d" % [unit1.current_hp, unit1.max_hp])
	_assert(unit1.current_energy == unit1.max_energy, "Unit1 energy full at init: %d/%d" % [unit1.current_energy, unit1.max_energy])

	# Test 3: take_damage reduces HP
	var hp_before = unit1.current_hp
	unit1.take_damage(20)
	_assert(unit1.current_hp == hp_before - 20, "take_damage reduces HP by 20: %d -> %d" % [hp_before, unit1.current_hp])

	# Test 4: take_damage with attacker
	var hp_before2 = unit2.current_hp
	unit2.take_damage(15, unit1)
	_assert(unit2.current_hp == hp_before2 - 15, "take_damage with attacker reduces HP")

	# Test 5: HP cannot go below 0
	unit1.take_damage(1000)
	_assert(unit1.current_hp == 0, "HP clamped to 0: %d" % unit1.current_hp)
	_assert(unit1.state == SoulUnit.UnitState.DEAD, "Unit enters DEAD state at 0 HP")

	# Test 6: Dead unit cannot take more damage
	unit1.take_damage(50)
	_assert(unit1.current_hp == 0, "Dead unit HP stays 0")

	# Test 7: get_info returns correct data
	var info = unit2.get_info()
	_assert(info.has("id"), "get_info has id")
	_assert(info.has("name"), "get_info has name")
	_assert(info.has("element"), "get_info has element")
	_assert(info.has("hp"), "get_info has hp")
	_assert(info.has("max_hp"), "get_info has max_hp")
	_assert(info["id"] == "test_u2", "get_info id correct")
	_assert(info["name"] == "WaterSoul", "get_info name correct")

	# Test 8: move_to sets target position
	unit2.move_to(Vector2(500, 300))
	_assert(unit2.target_position == Vector2(500, 300), "move_to sets target position")
	_assert(unit2.state == SoulUnit.UnitState.MOVING, "Unit enters MOVING state")

	# Test 9: stop stops movement
	unit2.stop()
	_assert(unit2.state == SoulUnit.UnitState.IDLE, "stop returns to IDLE state")

	# Test 10: Element multiplier - fire vs water (no advantage defined = 1.0)
	var mult_fire_vs_water = unit2._get_element_multiplier("fire", "water")
	_assert(mult_fire_vs_water == 1.0, "Fire vs Water multiplier is 1.0 (no advantage): %.2f" % mult_fire_vs_water)

	# Test 11: Element multiplier - water vs fire (water strong vs fire)
	var mult_water_vs_fire = unit2._get_element_multiplier("water", "fire")
	_assert(mult_water_vs_fire == 1.5, "Water vs Fire multiplier is 1.5: %.2f" % mult_water_vs_fire)

	# Test 12: Element multiplier - neutral (no advantage)
	var mult_neutral = unit2._get_element_multiplier("neutral", "fire")
	_assert(mult_neutral == 1.0, "Neutral multiplier is 1.0: %.2f" % mult_neutral)

	# Test 13: Element multiplier - same element
	var mult_same = unit2._get_element_multiplier("fire", "fire")
	_assert(mult_same == 1.0, "Same element multiplier is 1.0: %.2f" % mult_same)

	# Test 14: use_skill requires energy
	unit2.current_energy = 0
	var skill_result = unit2.use_skill("heavy_strike", unit1)
	_assert(skill_result == false, "use_skill fails with 0 energy")

	# Test 15: use_skill with enough energy
	unit2.current_energy = unit2.max_energy
	var skill_result2 = unit2.use_skill("heavy_strike", unit1)
	_assert(skill_result2 == true, "use_skill succeeds with enough energy")

	# Test 16: use_skill on dead unit fails
	var dead_skill = unit1.use_skill("heavy_strike", unit2)
	_assert(dead_skill == false, "Dead unit cannot use skill")

	# Test 17: use_skill invalid skill name
	var invalid_skill = unit2.use_skill("nonexistent_skill", unit1)
	_assert(invalid_skill == false, "Invalid skill name returns false")

	# Test 18: Personality defaults
	_assert(unit2.personality.has("aggression"), "Personality has aggression")
	_assert(unit2.personality.has("loyalty"), "Personality has loyalty")
	_assert(unit2.personality.has("intelligence"), "Personality has intelligence")

	# Test 19: Emotion defaults
	_assert(unit2.emotion.has("mood"), "Emotion has mood")
	_assert(unit2.emotion.has("intensity"), "Emotion has intensity")
	_assert(unit2.emotion["mood"] == "calm", "Default mood is calm")

	# Test 20: get_element returns element
	_assert(unit2.get_element() == "water", "get_element returns water")

	# Cleanup
	unit1.queue_free()
	unit2.queue_free()
