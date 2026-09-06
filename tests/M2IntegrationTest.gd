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
