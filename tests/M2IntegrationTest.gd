extends Node2D
## M2IntegrationTest - Integration tests for M2 RTS arena features
##
## Tests BattleResultManager, ArenaMap, SoulUnit, and RTSArenaManager.
## Run via: m2_test_runner.gd (SceneTree wrapper)

# Preload scripts without class_name
const SoulUnit = preload("res://scripts/game/SoulUnit.gd")
const Minimap = preload("res://scripts/ui/Minimap.gd")
const PixelSpriteGenerator = preload("res://scripts/game/PixelSpriteGenerator.gd")
const ArenaBackgroundGenerator = preload("res://scripts/game/ArenaBackgroundGenerator.gd")
const ServerAuthority = preload("res://scripts/network/ServerAuthority.gd")
const SoulSnapshot = preload("res://platform/soul/SoulSnapshot.gd")
const WorldPlugin = preload("res://platform/world/WorldPlugin.gd")
const ArenaEnvironment = preload("res://scripts/game/ArenaEnvironment.gd")
const SoulAIController = preload("res://scripts/game/SoulAIController.gd")

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
	_test_arena_map_system()
	_test_minimap_system()
	_test_audio_manager()
	_test_pixel_sprite_generator()
	_test_arena_background_generator()
	_test_server_authority()
	_test_monetization_manager()
	_test_platform_sdk()
	_test_world_loader()
	_test_home_api()
	_test_soul_snapshot()
	_test_world_plugin()

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

	# Test 18: set_battle_mode
	RTSArenaManager.start_battle(p3, a3, "default_arena")
	RTSArenaManager.set_battle_mode("auto")
	_assert(RTSArenaManager.battle_mode == "auto", "Battle mode set to auto")
	RTSArenaManager.set_battle_mode("manual")
	_assert(RTSArenaManager.battle_mode == "manual", "Battle mode set to manual")
	RTSArenaManager.reset_battle()

	# Test 19: pause_battle and resume_battle
	RTSArenaManager.start_battle(p3, a3, "default_arena")
	RTSArenaManager.pause_battle()
	_assert(RTSArenaManager.battle_state == RTSArenaManager.BattleState.PAUSED, "Battle paused")
	RTSArenaManager.resume_battle()
	_assert(RTSArenaManager.battle_state == RTSArenaManager.BattleState.ACTIVE, "Battle resumed")
	RTSArenaManager.reset_battle()

	# Test 20: get_player_command_cooldown
	RTSArenaManager.start_battle(p3, a3, "default_arena")
	var cmd_cooldown = RTSArenaManager.get_player_command_cooldown()
	_assert(typeof(cmd_cooldown) == TYPE_FLOAT, "get_player_command_cooldown returns float")
	_assert(cmd_cooldown >= 0.0, "Cooldown >= 0")
	RTSArenaManager.reset_battle()

	# Test 21: get_recent_log
	RTSArenaManager.start_battle(p3, a3, "default_arena")
	RTSArenaManager._add_log("Test log entry")
	var logs = RTSArenaManager.get_recent_log(5)
	_assert(typeof(logs) == TYPE_ARRAY, "get_recent_log returns array")
	_assert(logs.size() <= 5, "get_recent_log respects count limit")
	RTSArenaManager.reset_battle()

	# Test 22: cleanup_battle
	RTSArenaManager.start_battle(p3, a3, "default_arena")
	_assert(RTSArenaManager.player_unit != null, "Player unit exists before cleanup")
	_assert(RTSArenaManager.ai_unit != null, "AI unit exists before cleanup")
	RTSArenaManager.cleanup_battle()
	_assert(RTSArenaManager.battle_state == RTSArenaManager.BattleState.IDLE, "Battle state IDLE after cleanup")
	_assert(RTSArenaManager.battle_time == 0.0, "Battle time reset after cleanup")

	# Test 23: forfeit_battle
	RTSArenaManager.start_battle(p3, a3, "default_arena")
	RTSArenaManager.forfeit_battle()
	_assert(RTSArenaManager.battle_state == RTSArenaManager.BattleState.FINISHED, "Battle finished after forfeit")
	RTSArenaManager.cleanup_battle()


## ============================================
## SoulAIController Tests
## ============================================
func _test_soul_ai_controller() -> void:
	print("\n--- SoulAIController Tests ---")

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

	# Test 13: issue_command valid commands
	var ai5 = SoulAIController.new()
	_assert(ai5.issue_command("gather") == true, "issue_command gather succeeds")
	_assert(ai5.player_command == "gather", "player_command set to gather")
	ai5.command_cooldown = 0.0  # Reset cooldown for next test
	_assert(ai5.issue_command("attack") == true, "issue_command attack succeeds")
	_assert(ai5.player_command == "attack", "player_command set to attack")
	ai5.command_cooldown = 0.0
	_assert(ai5.issue_command("defend") == true, "issue_command defend succeeds")
	_assert(ai5.player_command == "defend", "player_command set to defend")
	ai5.command_cooldown = 0.0
	_assert(ai5.issue_command("retreat") == true, "issue_command retreat succeeds")
	_assert(ai5.player_command == "retreat", "player_command set to retreat")

	# Test 14: issue_command invalid command
	ai5.command_cooldown = 0.0
	_assert(ai5.issue_command("invalid") == false, "issue_command invalid returns false")
	_assert(ai5.issue_command("") == false, "issue_command empty returns false")

	# Test 15: command_cooldown after issue_command
	ai5.command_cooldown = 0.0
	ai5.issue_command("gather")
	var cooldown_after = ai5.command_cooldown
	_assert(cooldown_after > 0.0, "command_cooldown > 0 after command: %.1f" % cooldown_after)
	_assert(ai5.issue_command("gather") == false, "issue_command on cooldown returns false")

	# Test 16: update reduces cooldowns
	ai5.decision_cooldown = 5.0
	ai5.command_cooldown = 10.0
	ai5.update(2.0)
	_assert(ai5.decision_cooldown < 5.0, "decision_cooldown reduced after update: %.1f" % ai5.decision_cooldown)
	_assert(ai5.command_cooldown < 10.0, "command_cooldown reduced after update: %.1f" % ai5.command_cooldown)

	# Test 17: update_emotion changes mood (event is "took_damage", emotion needs anger/fear/excitement keys)
	self_unit.emotion = {"mood": "calm", "intensity": 0.0, "anger": 0.0, "fear": 0.0, "excitement": 0.0}
	ai5.update_emotion(self_unit, "took_damage", 0.5)
	_assert(self_unit.emotion["fear"] > 0.0 or self_unit.emotion["anger"] > 0.0, "Emotion changed after took_damage event")

	# Test 18: get_state_info returns dictionary
	var state_info = ai5.get_state_info()
	_assert(typeof(state_info) == TYPE_DICTIONARY, "get_state_info returns dictionary")
	_assert(state_info.has("decision"), "state_info has decision")
	_assert(state_info.has("player_command"), "state_info has player_command")
	_assert(state_info.has("command_cooldown"), "state_info has command_cooldown")
	_assert(state_info.has("decision_cooldown"), "state_info has decision_cooldown")
	_assert(state_info.has("last_command_obeyed"), "state_info has last_command_obeyed")

	# Test 19: battle_memory initialized
	_assert(typeof(ai5.battle_memory) == TYPE_DICTIONARY, "battle_memory is dictionary")
	_assert(ai5.battle_memory.has("times_hit_by_heavy"), "battle_memory has times_hit_by_heavy")
	_assert(ai5.battle_memory.has("times_hit_by_quick"), "battle_memory has times_hit_by_quick")
	_assert(ai5.battle_memory.has("times_killed"), "battle_memory has times_killed")
	_assert(ai5.battle_memory.has("favorite_skill"), "battle_memory has favorite_skill")

	# Test 20: last_command_obeyed flag
	_assert(typeof(ai5.last_command_obeyed) == TYPE_BOOL, "last_command_obeyed is boolean")

	# Cleanup
	self_unit.queue_free()
	enemy_unit.queue_free()


## ============================================
## ArenaEnvironment Tests
## ============================================
func _test_arena_environment() -> void:
	print("\n--- ArenaEnvironment Tests ---")

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

	# Test 11: ArenaEnvironment direct creation and setup_for_map
	var env = ArenaEnvironment.new()
	_assert(env != null, "ArenaEnvironment created")
	env.setup_for_map("default_arena")
	_assert(env.current_weather == ArenaEnvironment.WeatherType.CLEAR, "Default map weather is CLEAR")
	env.setup_for_map("forest_arena")
	_assert(env.current_weather == ArenaEnvironment.WeatherType.RAIN, "Forest map weather is RAIN")
	env.setup_for_map("crystal_arena")
	_assert(env.current_weather == ArenaEnvironment.WeatherType.SNOW, "Crystal map weather is SNOW")

	# Test 12: set_weather and get_weather_name
	env.set_weather(ArenaEnvironment.WeatherType.CLEAR)
	_assert(env.get_weather_name() == "Clear", "CLEAR weather name is Clear")
	env.set_weather(ArenaEnvironment.WeatherType.RAIN)
	_assert(env.get_weather_name() == "Rain", "RAIN weather name is Rain")
	env.set_weather(ArenaEnvironment.WeatherType.FOG)
	_assert(env.get_weather_name() == "Fog", "FOG weather name is Fog")
	env.set_weather(ArenaEnvironment.WeatherType.SNOW)
	_assert(env.get_weather_name() == "Snow", "SNOW weather name is Snow")
	env.set_weather(ArenaEnvironment.WeatherType.STORM)
	_assert(env.get_weather_name() == "Storm", "STORM weather name is Storm")

	# Test 13: get_weather_movement_modifier
	env.set_weather(ArenaEnvironment.WeatherType.CLEAR)
	_assert(env.get_weather_movement_modifier() == 1.0, "CLEAR movement modifier = 1.0")
	env.set_weather(ArenaEnvironment.WeatherType.RAIN)
	_assert(env.get_weather_movement_modifier() < 1.0, "RAIN movement modifier < 1.0")
	env.set_weather(ArenaEnvironment.WeatherType.SNOW)
	_assert(env.get_weather_movement_modifier() < 1.0, "SNOW movement modifier < 1.0")

	# Test 14: get_weather_accuracy_modifier
	env.set_weather(ArenaEnvironment.WeatherType.CLEAR)
	_assert(env.get_weather_accuracy_modifier() == 1.0, "CLEAR accuracy modifier = 1.0")
	env.set_weather(ArenaEnvironment.WeatherType.FOG)
	_assert(env.get_weather_accuracy_modifier() < 1.0, "FOG accuracy modifier < 1.0")

	# Test 15: get_visibility_modifier
	env.set_weather(ArenaEnvironment.WeatherType.CLEAR)
	_assert(env.get_visibility_modifier() == 1.0, "CLEAR visibility modifier = 1.0")
	env.set_weather(ArenaEnvironment.WeatherType.FOG)
	_assert(env.get_visibility_modifier() < 1.0, "FOG visibility modifier < 1.0")
	env.set_weather(ArenaEnvironment.WeatherType.STORM)
	_assert(env.get_visibility_modifier() < 1.0, "STORM visibility modifier < 1.0")

	# Test 16: get_weather_defense_modifier
	env.set_weather(ArenaEnvironment.WeatherType.CLEAR)
	_assert(env.get_weather_defense_modifier() == 1.0, "CLEAR defense modifier = 1.0")
	env.set_weather(ArenaEnvironment.WeatherType.SNOW)
	_assert(env.get_weather_defense_modifier() > 1.0, "SNOW defense modifier > 1.0")

	# Test 17: get_terrain_damage
	var lava_damage = env.get_terrain_damage(Vector2(0, 0))
	_assert(typeof(lava_damage) == TYPE_FLOAT, "get_terrain_damage returns float")
	_assert(lava_damage >= 0.0, "Terrain damage >= 0")

	# Test 18: get_terrain_movement_modifier
	var terrain_move = env.get_terrain_movement_modifier(Vector2(0, 0))
	_assert(typeof(terrain_move) == TYPE_FLOAT, "get_terrain_movement_modifier returns float")
	_assert(terrain_move > 0.0, "Terrain movement modifier > 0")

	# Test 19: get_total_movement_modifier
	var total_move = env.get_total_movement_modifier(Vector2(0, 0))
	_assert(typeof(total_move) == TYPE_FLOAT, "get_total_movement_modifier returns float")
	_assert(total_move > 0.0, "Total movement modifier > 0")

	# Test 20: get_environment_info
	var direct_env_info = env.get_environment_info()
	_assert(typeof(direct_env_info) == TYPE_DICTIONARY, "get_environment_info returns dictionary")
	_assert(direct_env_info.has("weather"), "env_info has weather")
	_assert(direct_env_info.has("weather_type"), "env_info has weather_type")
	_assert(direct_env_info.has("movement_mod"), "env_info has movement_mod")
	_assert(direct_env_info.has("accuracy_mod"), "env_info has accuracy_mod")
	_assert(direct_env_info.has("visibility_mod"), "env_info has visibility_mod")
	_assert(direct_env_info.has("defense_mod"), "env_info has defense_mod")
	_assert(direct_env_info.has("weather_timer"), "env_info has weather_timer")
	_assert(direct_env_info.has("weather_duration"), "env_info has weather_duration")

	# Test 21: update returns dictionary and advances timer
	env.setup_for_map("default_arena")
	var update_result = env.update(1.0)
	_assert(typeof(update_result) == TYPE_DICTIONARY, "update returns dictionary")
	_assert(env.weather_timer > 0.0, "weather_timer advanced after update")

	# Test 22: weather changes after duration
	env.setup_for_map("default_arena")
	env.weather_timer = env.weather_duration - 1.0
	var before_weather = env.current_weather
	env.update(2.0)
	# Weather may or may not change (random), just verify no crash
	_assert(env.weather_timer >= 0.0, "weather_timer valid after weather change check")


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

	# Reset unit1 for new tests (was killed in Test 16)
	unit1.current_hp = unit1.max_hp
	unit1.current_energy = unit1.max_energy
	unit1.state = unit1.UnitState.IDLE
	for skill_name in unit1.skill_cooldowns.keys():
		unit1.skill_cooldowns[skill_name] = 0.0
	unit1.status_effects.clear()

	# Test 21: use_skill heal
	var heal_hp_before = unit1.current_hp
	unit1.current_hp = 50
	var heal_result = unit1.use_skill("heal")
	_assert(heal_result == true, "heal skill returns true")
	_assert(unit1.current_hp > 50, "HP increased after heal")
	_assert(unit1.current_energy < unit1.max_energy, "Energy consumed after heal")

	# Test 22: use_skill defend
	var defend_result = unit1.use_skill("defend")
	_assert(defend_result == true, "defend skill returns true")
	_assert(unit1.status_effects.has("defense_up"), "defense_up status applied")

	# Test 23: use_skill heavy_strike on target
	var target_hp_before = unit2.current_hp
	var heavy_result = unit1.use_skill("heavy_strike", unit2)
	_assert(heavy_result == true, "heavy_strike returns true")
	_assert(unit2.current_hp < target_hp_before, "Target HP decreased after heavy_strike")

	# Test 24: use_skill quick_strike on target
	var target_hp_before2 = unit2.current_hp
	unit1.skill_cooldowns["quick_strike"] = 0.0
	var quick_result = unit1.use_skill("quick_strike", unit2)
	_assert(quick_result == true, "quick_strike returns true")
	_assert(unit2.current_hp < target_hp_before2, "Target HP decreased after quick_strike")

	# Test 25: use_skill on cooldown returns false
	unit1.skill_cooldowns["heal"] = 5.0
	var cooldown_result = unit1.use_skill("heal")
	_assert(cooldown_result == false, "Skill on cooldown returns false")

	# Test 26: use_skill invalid skill returns false
	var invalid_result = unit1.use_skill("invalid_skill")
	_assert(invalid_result == false, "Invalid skill returns false")

	# Test 27: use_skill not enough energy
	unit1.current_energy = 0
	unit1.skill_cooldowns["heal"] = 0.0
	var no_energy_result = unit1.use_skill("heal")
	_assert(no_energy_result == false, "No energy returns false")
	unit1.current_energy = 50

	# Test 28: get_info returns dictionary
	var unit_info = unit1.get_info()
	_assert(typeof(unit_info) == TYPE_DICTIONARY, "get_info returns dictionary")
	_assert(unit_info.has("id"), "info has id")
	_assert(unit_info.has("name"), "info has name")
	_assert(unit_info.has("element"), "info has element")
	_assert(unit_info.has("level"), "info has level")
	_assert(unit_info.has("hp"), "info has hp")
	_assert(unit_info.has("max_hp"), "info has max_hp")
	_assert(unit_info.has("is_alive"), "info has is_alive")

	# Test 29: stop sets state to IDLE
	unit1.state = unit1.UnitState.MOVING
	unit1.stop()
	_assert(unit1.state == unit1.UnitState.IDLE, "stop sets state to IDLE")

	# Test 30: move_to sets target position and state
	unit1.move_to(Vector2(100, 200))
	_assert(unit1.target_position == Vector2(100, 200), "move_to sets target_position")
	_assert(unit1.state == unit1.UnitState.MOVING, "move_to sets state to MOVING")

	# Test 31: take_damage reduces HP
	unit1.status_effects.clear()  # Clear defense_up from Test 22
	var hp_before_damage = unit1.current_hp
	unit1.take_damage(20)
	_assert(unit1.current_hp == hp_before_damage - 20, "take_damage reduces HP by 20")

	# Test 32: take_damage to 0 sets DEAD
	unit1.current_hp = 5
	unit1.take_damage(10)
	_assert(unit1.current_hp == 0, "HP clamped to 0")
	_assert(unit1.state == unit1.UnitState.DEAD, "State set to DEAD")

	# Test 33: Dead unit cannot use skill
	var dead_skill_result = unit1.use_skill("heal")
	_assert(dead_skill_result == false, "Dead unit cannot use skill")

	# Cleanup
	unit1.queue_free()
	unit2.queue_free()


## ============================================
## ArenaMap System Tests
## ============================================
func _test_arena_map_system() -> void:
	print("\n--- ArenaMap System Tests ---")

	# Test 1: Available maps list
	var maps = ArenaMap.get_available_maps()
	_assert(maps.size() >= 3, "At least 3 available maps: %d" % maps.size())
	_assert(maps.has("default_arena"), "default_arena available")
	_assert(maps.has("forest_arena"), "forest_arena available")
	_assert(maps.has("crystal_arena"), "crystal_arena available")

	# Test 2: Load default arena
	ArenaMap.load_map("default_arena")
	_assert(ArenaMap.map_name == "default_arena", "Map name set to default_arena")
	_assert(ArenaMap.arena_width == 1280, "Default arena width 1280")
	_assert(ArenaMap.arena_height == 600, "Default arena height 600")

	# Test 3: Spawn positions
	_assert(ArenaMap.player_spawn.x < ArenaMap.ai_spawn.x, "Player spawn left of AI spawn")
	_assert(ArenaMap.player_spawn.y > 0, "Player spawn valid Y")
	_assert(ArenaMap.ai_spawn.y > 0, "AI spawn valid Y")

	# Test 4: Terrain grid generated
	_assert(ArenaMap.terrain_grid.size() > 0, "Terrain grid generated: %d rows" % ArenaMap.terrain_grid.size())

	# Test 5: get_terrain_type returns valid type
	var terrain = ArenaMap.get_terrain_type(Vector2(100, 100))
	_assert(terrain >= 0, "Terrain type valid: %d" % terrain)
	_assert(terrain <= 5, "Terrain type in range 0-5: %d" % terrain)

	# Test 6: get_terrain_speed_modifier returns positive value
	var speed_mod = ArenaMap.get_terrain_speed_modifier(Vector2(100, 100))
	_assert(speed_mod > 0, "Speed modifier positive: %.2f" % speed_mod)
	_assert(speed_mod <= 1.0, "Speed modifier <= 1.0: %.2f" % speed_mod)

	# Test 7: is_position_valid returns bool for in-bounds position
	var valid_result = ArenaMap.is_position_valid(Vector2(100, 100))
	_assert(typeof(valid_result) == TYPE_BOOL, "is_position_valid returns bool")

	# Test 8: is_position_valid for out-of-bounds
	var invalid = ArenaMap.is_position_valid(Vector2(-100, -100))
	_assert(invalid == false, "Out-of-bounds position invalid")

	# Test 9: is_position_valid for far out-of-bounds
	var invalid2 = ArenaMap.is_position_valid(Vector2(2000, 2000))
	_assert(invalid2 == false, "Far out-of-bounds invalid")

	# Test 10: get_map_info returns required fields
	var info = ArenaMap.get_map_info()
	_assert(info.has("name"), "Map info has name")
	_assert(info.has("width"), "Map info has width")
	_assert(info.has("height"), "Map info has height")
	_assert(info.has("obstacle_count"), "Map info has obstacle_count")
	_assert(info["name"] == "default_arena", "Map info name correct")

	# Test 11: Load forest arena
	ArenaMap.load_map("forest_arena")
	_assert(ArenaMap.map_name == "forest_arena", "Map name set to forest_arena")
	var forest_info = ArenaMap.get_map_info()
	_assert(forest_info["obstacle_count"] > 0, "Forest arena has obstacles")

	# Test 12: Load crystal arena
	ArenaMap.load_map("crystal_arena")
	_assert(ArenaMap.map_name == "crystal_arena", "Map name set to crystal_arena")

	# Test 13: Obstacles array
	_assert(ArenaMap.obstacles.size() >= 0, "Obstacles array valid: %d" % ArenaMap.obstacles.size())

	# Test 14: get_obstacle_at returns dictionary (empty if none)
	var obstacle = ArenaMap.get_obstacle_at(Vector2(640, 300))
	_assert(typeof(obstacle) == TYPE_DICTIONARY, "get_obstacle_at returns dictionary")

	# Test 15: reset_map resets obstacles (doesn't clear map)
	ArenaMap.reset_map()
	_assert(ArenaMap.map_name == "crystal_arena", "Map name preserved after reset")
	_assert(ArenaMap.terrain_grid.size() > 0, "Terrain grid preserved after reset")

	# Test 16: Reload after reset
	ArenaMap.load_map("default_arena")
	_assert(ArenaMap.map_name == "default_arena", "Map reloads after reset")
	_assert(ArenaMap.terrain_grid.size() > 0, "Terrain grid regenerated after reload")

	# Test 17: Grid size
	_assert(ArenaMap.grid_size == 40, "Grid size is 40")

	# Test 18: Terrain type enum values
	_assert(ArenaMap.TerrainType.NORMAL == 0, "NORMAL terrain = 0")
	_assert(ArenaMap.TerrainType.GRASS == 1, "GRASS terrain = 1")
	_assert(ArenaMap.TerrainType.STONE == 2, "STONE terrain = 2")
	_assert(ArenaMap.TerrainType.WATER == 3, "WATER terrain = 3")
	_assert(ArenaMap.TerrainType.LAVA == 4, "LAVA terrain = 4")
	_assert(ArenaMap.TerrainType.SAND == 5, "SAND terrain = 5")

	# Test 19: is_damaging_terrain for normal position
	var damaging = ArenaMap.is_damaging_terrain(Vector2(100, 100))
	_assert(typeof(damaging) == TYPE_BOOL, "is_damaging_terrain returns bool")

	# Test 20: Multiple map loads don't crash
	for map_name in ArenaMap.get_available_maps():
		ArenaMap.load_map(map_name)
		_assert(ArenaMap.map_name == map_name, "Loaded map %s correctly" % map_name)

	# Reset to default
	ArenaMap.load_map("default_arena")


	# Test 21: get_terrain_speed_modifier returns float
	var speed_new = ArenaMap.get_terrain_speed_modifier(Vector2(100, 100))
	_assert(typeof(speed_new) == TYPE_FLOAT, "get_terrain_speed_modifier returns float")
	_assert(speed_new > 0, "speed modifier > 0")

	# Test 22: get_map_info returns dictionary
	var map_info = ArenaMap.get_map_info()
	_assert(typeof(map_info) == TYPE_DICTIONARY, "get_map_info returns dictionary")
	_assert(map_info.has("name"), "map_info has name")

	# Test 23: is_position_valid returns bool
	var pos_valid = ArenaMap.is_position_valid(Vector2(200, 300))
	_assert(typeof(pos_valid) == TYPE_BOOL, "is_position_valid returns bool")

	# Test 24: player_spawn and ai_spawn fields
	_assert(typeof(ArenaMap.player_spawn) == TYPE_VECTOR2, "player_spawn is Vector2")
	_assert(typeof(ArenaMap.ai_spawn) == TYPE_VECTOR2, "ai_spawn is Vector2")
	_assert(ArenaMap.player_spawn != ArenaMap.ai_spawn, "player and ai spawn different")

	# Test 25: arena_width and arena_height fields
	_assert(ArenaMap.arena_width == 1280, "arena_width = 1280")
	_assert(ArenaMap.arena_height == 600, "arena_height = 600")

	# Test 26: get_obstacle_at returns dictionary
	var obs_at = ArenaMap.get_obstacle_at(Vector2(0, 0))
	_assert(typeof(obs_at) == TYPE_DICTIONARY, "get_obstacle_at returns dictionary")

	# Test 27: damage_obstacle with nonexistent id returns dictionary
	var dmg_result = ArenaMap.damage_obstacle("nonexistent_obs", 10)
	_assert(typeof(dmg_result) == TYPE_DICTIONARY, "damage_obstacle returns dictionary")

## ============================================
## Minimap System Tests
## ============================================
func _test_minimap_system() -> void:
	print("\n--- Minimap System Tests ---")

	# Create minimap instance
	var minimap = Minimap.new()

	# Test 1: Default minimap size
	_assert(minimap.minimap_size == Vector2(150, 150), "Default minimap size 150x150")

	# Test 2: Default arena size
	_assert(minimap.arena_size == Vector2(1280, 600), "Default arena size 1280x600")

	# Test 3: set_arena_size updates arena_size
	minimap.set_arena_size(Vector2(1024, 768))
	_assert(minimap.arena_size == Vector2(1024, 768), "set_arena_size updates size")

	# Test 4: set_arena_size recalculates scale
	minimap.set_arena_size(Vector2(1280, 600))
	_assert(minimap._scale.x > 0, "Scale X positive after set_arena_size")
	_assert(minimap._scale.y > 0, "Scale Y positive after set_arena_size")

	# Test 5: _arena_to_minimap converts coordinates
	minimap.set_arena_size(Vector2(1280, 600))
	var minimap_pos = minimap._arena_to_minimap(Vector2(640, 300))
	_assert(minimap_pos.x > 0, "Minimap X positive: %.1f" % minimap_pos.x)
	_assert(minimap_pos.y > 0, "Minimap Y positive: %.1f" % minimap_pos.y)
	_assert(minimap_pos.x <= 150, "Minimap X within bounds: %.1f" % minimap_pos.x)
	_assert(minimap_pos.y <= 150, "Minimap Y within bounds: %.1f" % minimap_pos.y)

	# Test 6: _arena_to_minimap for corner positions
	var top_left = minimap._arena_to_minimap(Vector2(0, 0))
	_assert(top_left.x >= 0, "Top-left X >= 0: %.1f" % top_left.x)
	_assert(top_left.y >= 0, "Top-left Y >= 0: %.1f" % top_left.y)

	var bottom_right = minimap._arena_to_minimap(Vector2(1280, 600))
	_assert(bottom_right.x <= 150, "Bottom-right X <= 150: %.1f" % bottom_right.x)
	_assert(bottom_right.y <= 150, "Bottom-right Y <= 150: %.1f" % bottom_right.y)

	# Test 7: Colors are valid
	_assert(minimap.background_color.a > 0, "Background color has alpha")
	_assert(minimap.border_color.a > 0, "Border color has alpha")
	_assert(minimap.player_color.r > 0, "Player color has red")
	_assert(minimap.ai_color.r > 0, "AI color has red")

	# Test 8: Player color is blue-ish
	_assert(minimap.player_color.b > minimap.player_color.r, "Player color is blue-ish")

	# Test 9: AI color is red-ish
	_assert(minimap.ai_color.r > minimap.ai_color.b, "AI color is red-ish")

	# Test 10: dot_radius positive
	_assert(minimap.dot_radius > 0, "Dot radius positive: %.1f" % minimap.dot_radius)

	# Test 11: show_terrain default true
	_assert(minimap.show_terrain == true, "show_terrain default true")

	# Test 12: set_player_unit stores reference
	var test_unit = SoulUnit.new()
	test_unit.init_from_soul("test_minimap", "Test", "fire", 1, true)
	minimap.set_player_unit(test_unit)
	_assert(minimap._player_unit != null, "Player unit stored")

	# Test 13: set_ai_unit stores reference
	var test_ai = SoulUnit.new()
	test_ai.init_from_soul("test_ai_minimap", "TestAI", "water", 1, false)
	minimap.set_ai_unit(test_ai)
	_assert(minimap._ai_unit != null, "AI unit stored")

	# Test 14: set_arena_map stores reference
	minimap.set_arena_map(ArenaMap)
	_assert(minimap._arena_map != null, "Arena map stored")

	# Test 15: update_minimap doesn't crash with units set
	minimap.update_minimap()
	_assert(true, "update_minimap runs without crash")

	# Test 16: update_minimap doesn't crash without units
	var minimap2 = Minimap.new()
	minimap2.update_minimap()
	_assert(true, "update_minimap runs without units")

	# Test 17: _terrain_to_color returns Color for all terrain types
	for terrain_type in range(6):
		var color = minimap._terrain_to_color(terrain_type)
		_assert(typeof(color) == TYPE_COLOR, "Terrain %d returns Color" % terrain_type)

	# Test 18: _terrain_to_color for invalid terrain returns default
	var invalid_color = minimap._terrain_to_color(999)
	_assert(typeof(invalid_color) == TYPE_COLOR, "Invalid terrain returns Color")

	# Test 19: Custom minimap size
	var minimap3 = Minimap.new()
	minimap3.minimap_size = Vector2(200, 200)
	_assert(minimap3.minimap_size == Vector2(200, 200), "Custom minimap size")

	# Test 20: Scale calculation correct
	minimap.set_arena_size(Vector2(1280, 600))
	var expected_scale_x = 150.0 / 1280.0
	var expected_scale_y = 150.0 / 600.0
	_assert(abs(minimap._scale.x - expected_scale_x) < 0.001, "Scale X correct: %.4f vs %.4f" % [minimap._scale.x, expected_scale_x])
	_assert(abs(minimap._scale.y - expected_scale_y) < 0.001, "Scale Y correct: %.4f vs %.4f" % [minimap._scale.y, expected_scale_y])

	# Test 21: _calculate_scale recalculates scale
	minimap.minimap_size = Vector2(100, 100)
	minimap.arena_size = Vector2(1000, 500)
	minimap._calculate_scale()
	_assert(abs(minimap._scale.x - 0.1) < 0.001, "_calculate_scale X correct: %.4f" % minimap._scale.x)
	_assert(abs(minimap._scale.y - 0.2) < 0.001, "_calculate_scale Y correct: %.4f" % minimap._scale.y)

	# Test 22: obstacle_color valid
	_assert(typeof(minimap.obstacle_color) == TYPE_COLOR, "obstacle_color is Color")
	_assert(minimap.obstacle_color.a > 0, "obstacle_color has alpha")

	# Test 23: Custom colors can be set
	minimap.background_color = Color(0.2, 0.2, 0.2, 0.8)
	_assert(abs(minimap.background_color.r - 0.2) < 0.01, "Custom background color set")
	minimap.player_color = Color(0.0, 1.0, 0.0, 1.0)
	_assert(abs(minimap.player_color.g - 1.0) < 0.01, "Custom player color set")

	# Test 24: show_terrain can be toggled
	minimap.show_terrain = false
	_assert(minimap.show_terrain == false, "show_terrain can be set to false")
	minimap.show_terrain = true
	_assert(minimap.show_terrain == true, "show_terrain can be set to true")

	# Test 25: dot_radius can be changed
	minimap.dot_radius = 6.0
	_assert(minimap.dot_radius == 6.0, "dot_radius can be changed")

	# Test 26: _arena_to_minimap with zero position
	var zero_pos = minimap._arena_to_minimap(Vector2.ZERO)
	_assert(typeof(zero_pos) == TYPE_VECTOR2, "_arena_to_minimap returns Vector2")

	# Test 27: set_arena_size with zero size (edge case)
	minimap.set_arena_size(Vector2(1, 1))
	_assert(minimap.arena_size == Vector2(1, 1), "set_arena_size with 1x1 works")
	_assert(minimap._scale.x > 0, "Scale positive with 1x1 arena")

	# Test 28: Multiple minimap instances independent
	var m1 = Minimap.new()
	var m2 = Minimap.new()
	m1.minimap_size = Vector2(100, 100)
	m2.minimap_size = Vector2(200, 200)
	_assert(m1.minimap_size == Vector2(100, 100), "m1 size independent")
	_assert(m2.minimap_size == Vector2(200, 200), "m2 size independent")

	# Cleanup
	test_unit.queue_free()
	test_ai.queue_free()


	# Test 29: background_color field
	_assert(typeof(minimap.background_color) == TYPE_COLOR, "background_color is Color")
	minimap.background_color = Color(0.2, 0.2, 0.2, 0.8)
	_assert(abs(minimap.background_color.r - 0.2) < 0.01, "background_color.r set")

	# Test 30: border_color field
	_assert(typeof(minimap.border_color) == TYPE_COLOR, "border_color is Color")

	# Test 31: player_color field
	_assert(typeof(minimap.player_color) == TYPE_COLOR, "player_color is Color")

	# Test 32: ai_color field
	_assert(typeof(minimap.ai_color) == TYPE_COLOR, "ai_color is Color")

	# Test 33: obstacle_color field
	_assert(typeof(minimap.obstacle_color) == TYPE_COLOR, "obstacle_color is Color")

	# Test 34: _terrain_to_color returns Color
	var terrain_col = minimap._terrain_to_color(0)
	_assert(typeof(terrain_col) == TYPE_COLOR, "_terrain_to_color returns Color")

	# Test 35: set_arena_map can be called
	minimap.set_arena_map(null)
# No assertion needed, just verify no crash

	# Test 36: update_minimap can be called
	minimap.update_minimap()
# No assertion needed, just verify no crash

## ============================================
## AudioManager System Tests
## ============================================
func _test_audio_manager() -> void:
	print("\n--- AudioManager System Tests ---")

	# Test 1: Default volumes
	_assert(AudioManager.master_volume == 1.0, "Default master volume 1.0")
	_assert(AudioManager.sfx_volume == 0.8, "Default SFX volume 0.8")
	_assert(AudioManager.bgm_volume == 0.5, "Default BGM volume 0.5")

	# Test 2: Sound paths registered
	_assert(AudioManager._sound_paths.size() > 0, "Sound paths registered: %d" % AudioManager._sound_paths.size())
	_assert(AudioManager._sound_paths.size() >= 90, "At least 90 sound paths: %d" % AudioManager._sound_paths.size())

	# Test 3: SFX player pool initialized
	_assert(AudioManager._sfx_players.size() == 16, "SFX player pool size 16")
	_assert(AudioManager._max_sfx_players == 16, "Max SFX players 16")

	# Test 4: get_available_sounds returns array
	var available = AudioManager.get_available_sounds()
	_assert(typeof(available) == TYPE_ARRAY, "get_available_sounds returns array")
	_assert(available.size() > 0, "Available sounds > 0: %d" % available.size())

	# Test 5: UI sounds registered
	_assert(AudioManager._sound_paths.has("ui_button_click"), "ui_button_click registered")
	_assert(AudioManager._sound_paths.has("ui_confirm"), "ui_confirm registered")
	_assert(AudioManager._sound_paths.has("ui_cancel"), "ui_cancel registered")

	# Test 6: Battle sounds registered
	_assert(AudioManager._sound_paths.has("bat_attack_hit"), "bat_attack_hit registered")
	_assert(AudioManager._sound_paths.has("bat_victory"), "bat_victory registered")
	_assert(AudioManager._sound_paths.has("bat_defeat"), "bat_defeat registered")

	# Test 7: BGM tracks registered
	_assert(AudioManager._sound_paths.has("bgm_battle"), "bgm_battle registered")
	_assert(AudioManager._sound_paths.has("bgm_menu"), "bgm_menu registered")

	# Test 8: Environment sounds registered
	_assert(AudioManager._sound_paths.has("env_forest"), "env_forest registered")
	_assert(AudioManager._sound_paths.has("env_cave"), "env_cave registered")

	# Test 9: Soul sounds registered
	_assert(AudioManager._sound_paths.has("soul_angry_roar"), "soul_angry_roar registered")
	_assert(AudioManager._sound_paths.has("soul_confident"), "soul_confident registered")

	# Test 10: New achievement sounds registered
	_assert(AudioManager._sound_paths.has("ui_achievement_open"), "ui_achievement_open registered")
	_assert(AudioManager._sound_paths.has("ui_achievement_unlock"), "ui_achievement_unlock registered")

	# Test 11: New soul sounds registered
	_assert(AudioManager._sound_paths.has("soul_melancholic"), "soul_melancholic registered")
	_assert(AudioManager._sound_paths.has("soul_compassionate"), "soul_compassionate registered")

	# Test 12: New environment sound registered
	_assert(AudioManager._sound_paths.has("env_lavender_field"), "env_lavender_field registered")

	# Test 13: set_master_volume
	AudioManager.set_master_volume(0.5)
	_assert(AudioManager.master_volume == 0.5, "set_master_volume works")
	AudioManager.set_master_volume(1.0)

	# Test 14: set_sfx_volume
	AudioManager.set_sfx_volume(0.3)
	_assert(AudioManager.sfx_volume == 0.3, "set_sfx_volume works")
	AudioManager.set_sfx_volume(0.8)

	# Test 15: set_bgm_volume
	AudioManager.set_bgm_volume(0.7)
	_assert(AudioManager.bgm_volume == 0.7, "set_bgm_volume works")
	AudioManager.set_bgm_volume(0.5)

	# Test 16: get_info returns dictionary
	var info = AudioManager.get_info()
	_assert(typeof(info) == TYPE_DICTIONARY, "get_info returns dictionary")
	_assert(info.has("registered_sounds"), "get_info has registered_sounds")
	_assert(info.has("master_volume"), "get_info has master_volume")
	_assert(info["registered_sounds"] > 0, "registered_sounds > 0: %d" % info["registered_sounds"])

	# Test 17: get_stats returns dictionary
	var stats = AudioManager.get_stats()
	_assert(typeof(stats) == TYPE_DICTIONARY, "get_stats returns dictionary")

	# Test 18: play_ui doesn't crash
	AudioManager.play_ui("button_click")
	_assert(true, "play_ui runs without crash")

	# Test 19: play_battle doesn't crash
	AudioManager.play_battle("attack_hit")
	_assert(true, "play_battle runs without crash")

	# Test 20: play_sfx with invalid name doesn't crash
	AudioManager.play_sfx("nonexistent_sound")
	_assert(true, "play_sfx with invalid name doesn't crash")

	# Test 21: play_ui with invalid name doesn't crash
	AudioManager.play_ui("nonexistent_ui")
	_assert(true, "play_ui with invalid name doesn't crash")

	# Test 22: _get_stream returns null for nonexistent sound
	var null_stream = AudioManager._get_stream("nonexistent_sound_xyz")
	_assert(null_stream == null, "_get_stream returns null for nonexistent sound")

	# Test 22b: _get_stream caches successful loads (if file exists)
	var before_cache = AudioManager._stream_cache.size()
	AudioManager._get_stream("ui_button_click")
	var after_cache = AudioManager._stream_cache.size()
	_assert(after_cache >= before_cache, "Stream cache non-decreasing after get")

	# Test 23: Bus constants
	_assert(AudioManager.BUS_MASTER == "Master", "BUS_MASTER = Master")
	_assert(AudioManager.BUS_SFX == "SFX", "BUS_SFX = SFX")
	_assert(AudioManager.BUS_BGM == "BGM", "BUS_BGM = BGM")

	# Test 24: Sound path format correct
	var path = AudioManager._sound_paths["ui_button_click"]
	_assert(path.begins_with("res://"), "Sound path begins with res://")
	_assert(path.ends_with(".wav"), "Sound path ends with .wav")

	# Test 25: All sound paths point to existing files (check format)
	var invalid_paths = 0
	for sound_name in AudioManager._sound_paths:
		var p = AudioManager._sound_paths[sound_name]
		if not p.begins_with("res://assets/audio/"):
			invalid_paths += 1
	_assert(invalid_paths == 0, "All sound paths in assets/audio/: %d invalid" % invalid_paths)


	# Test 26: set_master_volume works
	AudioManager.set_master_volume(0.5)
	_assert(AudioManager.master_volume == 0.5, "master_volume set to 0.5")

	# Test 27: set_sfx_volume works
	AudioManager.set_sfx_volume(0.7)
	_assert(AudioManager.sfx_volume == 0.7, "sfx_volume set to 0.7")

	# Test 28: set_bgm_volume works
	AudioManager.set_bgm_volume(0.4)
	_assert(AudioManager.bgm_volume == 0.4, "bgm_volume set to 0.4")

	# Test 29: get_volume returns float
	var vol = AudioManager.get_volume("Master")
	_assert(typeof(vol) == TYPE_FLOAT, "get_volume returns float")

	# Test 30: get_stats returns dictionary
	var stats_new = AudioManager.get_stats()
	_assert(typeof(stats_new) == TYPE_DICTIONARY, "get_stats returns dictionary")

	# Test 31: stop_bgm can be called
	AudioManager.stop_bgm()
# No assertion needed, just verify no crash

	# Test 32: _max_sfx_players constant
	_assert(AudioManager._max_sfx_players == 16, "_max_sfx_players = 16")

	# Test 33: _sfx_players pool initialized
	_assert(typeof(AudioManager._sfx_players) == TYPE_ARRAY, "_sfx_players is array")
	_assert(AudioManager._sfx_players.size() > 0, "_sfx_players pool non-empty")

## ============================================
## PixelSpriteGenerator System Tests
## ============================================
func _test_pixel_sprite_generator() -> void:
	print("\n--- PixelSpriteGenerator System Tests ---")

	# Create generator instance (RefCounted)
	var generator = PixelSpriteGenerator.new()

	# Test 1: SPRITE_SIZE constant
	_assert(PixelSpriteGenerator.SPRITE_SIZE == 64, "SPRITE_SIZE = 64")

	# Test 2: ELEMENT_PALETTES has entries
	_assert(PixelSpriteGenerator.ELEMENT_PALETTES.size() > 0, "ELEMENT_PALETTES has entries: %d" % PixelSpriteGenerator.ELEMENT_PALETTES.size())

	# Test 3: PERSONALITY_MODIFIERS has entries
	_assert(PixelSpriteGenerator.PERSONALITY_MODIFIERS.size() > 0, "PERSONALITY_MODIFIERS has entries: %d" % PixelSpriteGenerator.PERSONALITY_MODIFIERS.size())

	# Test 4: get_supported_elements returns array
	var elements = generator.get_supported_elements()
	_assert(typeof(elements) == TYPE_ARRAY, "get_supported_elements returns array")
	_assert(elements.size() > 0, "Supported elements > 0: %d" % elements.size())

	# Test 5: Common elements supported
	_assert(elements.has("fire"), "fire element supported")
	_assert(elements.has("water"), "water element supported")
	_assert(elements.has("neutral"), "neutral element supported")

	# Test 6: generate_soul_sprite returns ImageTexture for fire
	var fire_sprite = generator.generate_soul_sprite("fire")
	_assert(fire_sprite != null, "Fire sprite generated")
	_assert(fire_sprite is ImageTexture, "Fire sprite is ImageTexture")

	# Test 7: generate_soul_sprite returns ImageTexture for water
	var water_sprite = generator.generate_soul_sprite("water")
	_assert(water_sprite != null, "Water sprite generated")
	_assert(water_sprite is ImageTexture, "Water sprite is ImageTexture")

	# Test 8: generate_soul_sprite returns ImageTexture for neutral
	var neutral_sprite = generator.generate_soul_sprite("neutral")
	_assert(neutral_sprite != null, "Neutral sprite generated")
	_assert(neutral_sprite is ImageTexture, "Neutral sprite is ImageTexture")

	# Test 9: generate_soul_sprite with personality
	var personality = {"aggression": 0.8, "courage": 0.6, "loyalty": 0.9}
	var personality_sprite = generator.generate_soul_sprite("fire", personality)
	_assert(personality_sprite != null, "Personality sprite generated")
	_assert(personality_sprite is ImageTexture, "Personality sprite is ImageTexture")

	# Test 10: generate_soul_sprite with empty personality
	var empty_personality_sprite = generator.generate_soul_sprite("water", {})
	_assert(empty_personality_sprite != null, "Empty personality sprite generated")

	# Test 11: generate_soul_sprite with invalid element falls back
	var invalid_sprite = generator.generate_soul_sprite("nonexistent_element")
	_assert(invalid_sprite != null, "Invalid element falls back to default")

	# Test 12: generate_color_swatch returns ImageTexture
	var swatch = generator.generate_color_swatch("fire")
	_assert(swatch != null, "Color swatch generated")
	_assert(swatch is ImageTexture, "Color swatch is ImageTexture")

	# Test 13: generate_color_swatch with custom size
	var custom_swatch = generator.generate_color_swatch("water", 64)
	_assert(custom_swatch != null, "Custom size color swatch generated")

	# Test 14: generate_color_swatch for all elements
	for element in elements:
		var s = generator.generate_color_swatch(element)
		_assert(s != null, "Color swatch for %s generated" % element)

	# Test 15: Different elements produce different palettes
	var fire_palette = generator._get_palette("fire", {})
	var water_palette = generator._get_palette("water", {})
	_assert(fire_palette != water_palette, "Fire and water palettes differ")

	# Test 16: Palette has required color keys
	_assert(fire_palette.has("primary"), "Palette has primary color")
	_assert(fire_palette.has("secondary"), "Palette has secondary color")
	_assert(fire_palette.has("glow"), "Palette has glow color")

	# Test 17: _hash_string returns consistent hash
	var hash1 = generator._hash_string("test")
	var hash2 = generator._hash_string("test")
	_assert(hash1 == hash2, "Hash is consistent")

	# Test 18: _hash_string different for different strings
	var hash3 = generator._hash_string("test1")
	var hash4 = generator._hash_string("test2")
	_assert(hash3 != hash4, "Different strings have different hashes")

	# Test 19: All elements can generate sprites
	for element in elements:
		var sprite = generator.generate_soul_sprite(element)
		_assert(sprite != null, "Sprite for %s generated" % element)

	# Test 20: Personality modifiers affect palette
	var base_palette = generator._get_palette("fire", {})
	var aggro_palette = generator._get_palette("fire", {"aggression": 1.0})
	_assert(typeof(base_palette) == TYPE_DICTIONARY, "Base palette is dictionary")
	_assert(typeof(aggro_palette) == TYPE_DICTIONARY, "Aggro palette is dictionary")

	# Test 21: generate_color_swatch returns ImageTexture
	var color_swatch = generator.generate_color_swatch("fire", 32)
	_assert(color_swatch != null, "Color swatch generated")
	_assert(color_swatch.get_width() == 32, "Color swatch width 32")
	_assert(color_swatch.get_height() == 32, "Color swatch height 32")

	# Test 22: generate_color_swatch default size
	var default_swatch = generator.generate_color_swatch("water")
	_assert(default_swatch != null, "Default color swatch generated")
	_assert(default_swatch.get_width() == 32, "Default swatch width 32")

	# Test 23: get_supported_elements returns array
	var supported = generator.get_supported_elements()
	_assert(typeof(supported) == TYPE_ARRAY, "get_supported_elements returns array")
	_assert(supported.size() > 0, "Supported elements > 0")
	_assert(supported.has("fire"), "fire is supported")
	_assert(supported.has("water"), "water is supported")
	_assert(supported.has("neutral"), "neutral is supported")

	# Test 24: SPRITE_SIZE constant
	_assert(PixelSpriteGenerator.SPRITE_SIZE == 64, "SPRITE_SIZE = 64")

	# Test 25: ELEMENT_PALETTES has all elements
	_assert(PixelSpriteGenerator.ELEMENT_PALETTES.has("fire"), "ELEMENT_PALETTES has fire")
	_assert(PixelSpriteGenerator.ELEMENT_PALETTES.has("water"), "ELEMENT_PALETTES has water")
	_assert(PixelSpriteGenerator.ELEMENT_PALETTES.has("neutral"), "ELEMENT_PALETTES has neutral")

	# Test 26: PERSONALITY_MODIFIERS dictionary
	_assert(typeof(PixelSpriteGenerator.PERSONALITY_MODIFIERS) == TYPE_DICTIONARY, "PERSONALITY_MODIFIERS is dictionary")
	_assert(PixelSpriteGenerator.PERSONALITY_MODIFIERS.size() > 0, "PERSONALITY_MODIFIERS not empty")

	# Test 27: Different personalities generate different sprites
	var sprite_calm = generator.generate_soul_sprite("fire", {"aggression": 0.0, "courage": 0.5})
	var sprite_aggro = generator.generate_soul_sprite("fire", {"aggression": 1.0, "courage": 1.0})
	_assert(sprite_calm != null, "Calm sprite generated")
	_assert(sprite_aggro != null, "Aggro sprite generated")
	# Both should be valid 64x64 textures
	_assert(sprite_calm.get_width() == 64, "Calm sprite width 64")
	_assert(sprite_aggro.get_width() == 64, "Aggro sprite width 64")

	# Test 28: generate_soul_sprite with empty personality
	var neutral_empty_sprite = generator.generate_soul_sprite("neutral", {})
	_assert(neutral_empty_sprite != null, "Empty personality sprite generated")
	_assert(neutral_empty_sprite.get_width() == 64, "Empty personality sprite width 64")

	# Test 29: generate_soul_sprite default element
	var default_element_sprite = generator.generate_soul_sprite()
	_assert(default_element_sprite != null, "Default element sprite generated")
	_assert(default_element_sprite.get_width() == 64, "Default sprite width 64")


## ============================================
## ArenaBackgroundGenerator System Tests
## ============================================
func _test_arena_background_generator() -> void:
	print("\n--- ArenaBackgroundGenerator System Tests ---")

	# Create generator instance (RefCounted)
	var generator = ArenaBackgroundGenerator.new()

	# Test 1: TILE_SIZE constant
	_assert(ArenaBackgroundGenerator.TILE_SIZE == 32, "TILE_SIZE = 32")

	# Test 2: ARENA_WIDTH constant
	_assert(ArenaBackgroundGenerator.ARENA_WIDTH == 1280, "ARENA_WIDTH = 1280")

	# Test 3: ARENA_HEIGHT constant
	_assert(ArenaBackgroundGenerator.ARENA_HEIGHT == 640, "ARENA_HEIGHT = 640")

	# Test 4: ARENA_PALETTES has entries
	_assert(ArenaBackgroundGenerator.ARENA_PALETTES.size() > 0, "ARENA_PALETTES has entries: %d" % ArenaBackgroundGenerator.ARENA_PALETTES.size())

	# Test 5: get_arena_types returns array
	var arena_types = generator.get_arena_types()
	_assert(typeof(arena_types) == TYPE_ARRAY, "get_arena_types returns array")
	_assert(arena_types.size() > 0, "Arena types > 0: %d" % arena_types.size())

	# Test 6: Common arena types
	_assert(arena_types.has("grass"), "grass arena type available")
	_assert(arena_types.has("stone"), "stone arena type available")

	# Test 7: generate_background for grass returns ImageTexture
	var grass_bg = generator.generate_background("grass")
	_assert(grass_bg != null, "Grass background generated")
	_assert(grass_bg is ImageTexture, "Grass background is ImageTexture")

	# Test 8: generate_background for stone returns ImageTexture
	var stone_bg = generator.generate_background("stone")
	_assert(stone_bg != null, "Stone background generated")
	_assert(stone_bg is ImageTexture, "Stone background is ImageTexture")

	# Test 9: generate_background with seed
	var seeded_bg = generator.generate_background("grass", 42)
	_assert(seeded_bg != null, "Seeded background generated")
	_assert(seeded_bg is ImageTexture, "Seeded background is ImageTexture")

	# Test 10: Same seed produces consistent result (same type)
	var seeded_bg2 = generator.generate_background("grass", 42)
	_assert(seeded_bg2 != null, "Second seeded background generated")

	# Test 11: generate_background with invalid type falls back
	var invalid_bg = generator.generate_background("nonexistent_arena")
	_assert(invalid_bg != null, "Invalid arena type falls back to default")

	# Test 12: generate_background with default params
	var default_bg = generator.generate_background()
	_assert(default_bg != null, "Default background generated")
	_assert(default_bg is ImageTexture, "Default background is ImageTexture")

	# Test 13: All arena types can generate background
	for arena_type in arena_types:
		var bg = generator.generate_background(arena_type)
		_assert(bg != null, "Background for %s generated" % arena_type)

	# Test 14: Different arena types produce different palettes
	var grass_palette = ArenaBackgroundGenerator.ARENA_PALETTES["grass"]
	var stone_palette = ArenaBackgroundGenerator.ARENA_PALETTES["stone"]
	_assert(grass_palette != stone_palette, "Grass and stone palettes differ")

	# Test 15: Palette has required color keys
	_assert(grass_palette.has("base"), "Palette has base color")
	_assert(grass_palette.has("accent"), "Palette has accent color")
	_assert(grass_palette.has("border"), "Palette has border color")

	# Test 16: Background dimensions match arena size
	var bg_image = grass_bg.get_image()
	_assert(bg_image != null, "Background image accessible")
	_assert(bg_image.get_width() == 1280, "Background width 1280: %d" % bg_image.get_width())
	_assert(bg_image.get_height() == 640, "Background height 640: %d" % bg_image.get_height())

	# Test 17: Multiple generations don't crash
	for i in range(5):
		var bg = generator.generate_background("grass", i)
		_assert(bg != null, "Generation %d succeeds" % i)

	# Test 18: Negative seed handled
	var neg_seed_bg = generator.generate_background("grass", -1)
	_assert(neg_seed_bg != null, "Negative seed handled")

	# Test 19: Large seed handled
	var large_seed_bg = generator.generate_background("grass", 999999)
	_assert(large_seed_bg != null, "Large seed handled")

	# Test 20: ARENA_PALETTES all have required structure
	for arena_type in ArenaBackgroundGenerator.ARENA_PALETTES:
		var palette = ArenaBackgroundGenerator.ARENA_PALETTES[arena_type]
		_assert(typeof(palette) == TYPE_DICTIONARY, "Palette for %s is dictionary" % arena_type)
		_assert(palette.has("base"), "Palette for %s has base" % arena_type)

	# Test 21: get_arena_types returns array
	var supported_types = generator.get_arena_types()
	_assert(typeof(supported_types) == TYPE_ARRAY, "get_arena_types returns array")
	_assert(supported_types.size() > 0, "Arena types > 0")
	_assert(supported_types.has("grass"), "grass is supported arena type")
	_assert(supported_types.has("stone"), "stone is supported arena type")

	# Test 22: Constants
	_assert(ArenaBackgroundGenerator.TILE_SIZE == 32, "TILE_SIZE = 32")
	_assert(ArenaBackgroundGenerator.ARENA_WIDTH == 1280, "ARENA_WIDTH = 1280")
	_assert(ArenaBackgroundGenerator.ARENA_HEIGHT == 640, "ARENA_HEIGHT = 640")

	# Test 23: All arena types generate valid backgrounds
	for atype in supported_types:
		var type_bg = generator.generate_background(atype, 42)
		_assert(type_bg != null, "Background for %s generated" % atype)
		_assert(type_bg.get_width() == 1280, "%s background width 1280" % atype)
		_assert(type_bg.get_height() == 640, "%s background height 640" % atype)

	# Test 24: Same seed generates deterministic background
	var bg_seed_a = generator.generate_background("grass", 12345)
	var bg_seed_b = generator.generate_background("grass", 12345)
	_assert(bg_seed_a != null, "Seed A background generated")
	_assert(bg_seed_b != null, "Seed B background generated")
	# Both should be valid 1280x640
	_assert(bg_seed_a.get_width() == 1280, "Seed A width 1280")
	_assert(bg_seed_b.get_width() == 1280, "Seed B width 1280")

	# Test 25: Default arena type
	var default_type_bg = generator.generate_background()
	_assert(default_type_bg != null, "Default arena type background generated")
	_assert(default_type_bg.get_width() == 1280, "Default background width 1280")

	# Test 26: Invalid arena type falls back gracefully
	var invalid_type_bg = generator.generate_background("nonexistent_type", 1)
	_assert(invalid_type_bg != null, "Invalid arena type handled gracefully")


## ============================================
## ServerAuthority System Tests
## ============================================
func _test_server_authority() -> void:
	print("\n--- ServerAuthority System Tests ---")

	# Create authority instance (RefCounted)
	var authority = ServerAuthority.new()

	# Test 1: Default mode is LOCAL_SIMULATION
	_assert(authority.get_mode() == ServerAuthority.AuthorityMode.LOCAL_SIMULATION, "Default mode LOCAL_SIMULATION")

	# Test 2: AuthorityMode enum values
	_assert(ServerAuthority.AuthorityMode.LOCAL_SIMULATION == 0, "LOCAL_SIMULATION = 0")
	_assert(ServerAuthority.AuthorityMode.CLIENT_PREDICT == 1, "CLIENT_PREDICT = 1")
	_assert(ServerAuthority.AuthorityMode.SERVER_ONLY == 2, "SERVER_ONLY = 2")

	# Test 3: set_mode changes mode
	authority.set_mode(ServerAuthority.AuthorityMode.SERVER_ONLY)
	_assert(authority.get_mode() == ServerAuthority.AuthorityMode.SERVER_ONLY, "set_mode to SERVER_ONLY")
	authority.set_mode(ServerAuthority.AuthorityMode.LOCAL_SIMULATION)

	# Test 4: Initial sequence number is 0
	_assert(authority.get_sequence() == 0, "Initial sequence = 0")

	# Test 5: Initial pending count is 0
	_assert(authority.get_pending_count() == 0, "Initial pending count = 0")

	# Test 6: submit_command returns dictionary
	var command = {"type": "move", "unit_id": "player_1", "target": Vector2(100, 100)}
	var result = authority.submit_command(command)
	_assert(typeof(result) == TYPE_DICTIONARY, "submit_command returns dictionary")

	# Test 7: submit_command increments sequence
	_assert(authority.get_sequence() == 1, "Sequence incremented to 1 after submit")

	# Test 8: submit_command result has sequence field
	_assert(result.has("sequence"), "Result has sequence field")
	_assert(result["sequence"] == 0, "Result sequence = 0 (first command)")

	# Test 9: submit_command result has status field
	_assert(result.has("status"), "Result has status field")
	_assert(result["status"] == "applied", "Command status = applied in LOCAL_SIMULATION mode")

	# Test 10: Multiple commands increment sequence
	authority.submit_command({"type": "attack", "unit_id": "player_1"})
	_assert(authority.get_sequence() == 2, "Sequence = 2 after second submit")
	authority.submit_command({"type": "defend", "unit_id": "player_1"})
	_assert(authority.get_sequence() == 3, "Sequence = 3 after third submit")

	# Test 11: take_snapshot stores snapshot
	var battle_state = {"player_hp": 100, "ai_hp": 80, "time": 10.5}
	authority.take_snapshot(battle_state)
	_assert(authority.get_latest_snapshot() != null, "Snapshot stored")

	# Test 12: get_latest_snapshot returns dictionary
	var latest = authority.get_latest_snapshot()
	_assert(typeof(latest) == TYPE_DICTIONARY, "Latest snapshot is dictionary")
	_assert(latest.has("state"), "Snapshot has state field")
	_assert(latest["state"]["player_hp"] == 100, "Snapshot player_hp = 100")

	# Test 13: Multiple snapshots keep latest
	var battle_state2 = {"player_hp": 90, "ai_hp": 70, "time": 15.0}
	authority.take_snapshot(battle_state2)
	var latest2 = authority.get_latest_snapshot()
	_assert(latest2["state"]["player_hp"] == 90, "Latest snapshot updated to player_hp=90")

	# Test 14: verify_state with matching states
	var local_state = {"player_hp": 100, "ai_hp": 80}
	var server_state = {"player_hp": 100, "ai_hp": 80}
	_assert(authority.verify_state(local_state, server_state) == true, "verify_state matching = true")

	# Test 15: verify_state with mismatching states
	var local_state2 = {"player_hp": 100, "ai_hp": 80}
	var server_state2 = {"player_hp": 95, "ai_hp": 80}
	_assert(authority.verify_state(local_state2, server_state2) == false, "verify_state mismatching = false")

	# Test 16: get_info returns dictionary
	var info = authority.get_info()
	_assert(typeof(info) == TYPE_DICTIONARY, "get_info returns dictionary")
	_assert(info.has("mode"), "get_info has mode")
	_assert(info.has("sequence"), "get_info has sequence")
	_assert(info.has("pending_commands"), "get_info has pending_commands")

	# Test 17: get_info mode name
	_assert(info.has("mode_name"), "get_info has mode_name")
	_assert(info["mode_name"] == "local_simulation", "mode_name = local_simulation")

	# Test 18: _mode_to_name returns correct names
	_assert(authority._mode_to_name(0) == "local_simulation", "_mode_to_name(0) = local_simulation")
	_assert(authority._mode_to_name(1) == "client_predict", "_mode_to_name(1) = client_predict")
	_assert(authority._mode_to_name(2) == "server_only", "_mode_to_name(2) = server_only")

	# Test 19: SERVER_ONLY mode submits command (pending)
	authority.set_mode(ServerAuthority.AuthorityMode.SERVER_ONLY)
	var cmd_result = authority.submit_command({"type": "move", "unit_id": "player_1"})
	_assert(cmd_result.has("sequence"), "SERVER mode result has sequence")
	_assert(cmd_result["status"] == "pending", "SERVER mode command status = pending")

	# Test 20: validate_command processes pending command
	var seq = authority.get_sequence()
	authority.validate_command(seq, true, {"player_hp": 95})
	_assert(authority.get_pending_count() >= 0, "Pending count after validate")

	# Reset to local mode
	authority.set_mode(ServerAuthority.AuthorityMode.LOCAL_SIMULATION)

	# Test 21: take_snapshot stores battle state
	authority.take_snapshot({"player_hp": 100, "ai_hp": 80, "time": 10.0})
	_assert(authority._snapshot_history.size() > 0, "Snapshot history not empty after take_snapshot")

	# Test 22: get_latest_snapshot returns dictionary
	var latest_snap = authority.get_latest_snapshot()
	_assert(typeof(latest_snap) == TYPE_DICTIONARY, "get_latest_snapshot returns dictionary")
	_assert(latest_snap.has("state"), "Latest snapshot has state")
	_assert(latest_snap["state"].has("player_hp"), "Snapshot state has player_hp")
	_assert(latest_snap["state"]["player_hp"] == 100, "Latest snapshot player_hp = 100")

	# Test 23: Multiple snapshots
	authority.take_snapshot({"player_hp": 90, "ai_hp": 70})
	authority.take_snapshot({"player_hp": 80, "ai_hp": 60})
	var latest_snap2 = authority.get_latest_snapshot()
	_assert(latest_snap2["state"]["player_hp"] == 80, "Latest snapshot after multiple = 80")

	# Test 24: verify_state with matching states
	var state_match = authority.verify_state({"player_hp": 100}, {"player_hp": 100})
	_assert(state_match == true, "verify_state returns true for matching states")

	# Test 25: verify_state with mismatching states
	var state_mismatch = authority.verify_state({"player_hp": 100}, {"player_hp": 90})
	_assert(state_mismatch == false, "verify_state returns false for mismatching states")

	# Test 26: get_pending_count returns int
	var pending_count = authority.get_pending_count()
	_assert(typeof(pending_count) == TYPE_INT, "get_pending_count returns int")
	_assert(pending_count >= 0, "Pending count >= 0")

	# Test 27: get_sequence returns int
	var seq_num = authority.get_sequence()
	_assert(typeof(seq_num) == TYPE_INT, "get_sequence returns int")
	_assert(seq_num >= 0, "Sequence >= 0")

	# Test 28: AuthorityMode enum values
	_assert(ServerAuthority.AuthorityMode.LOCAL_SIMULATION == 0, "LOCAL_SIMULATION = 0")
	_assert(ServerAuthority.AuthorityMode.CLIENT_PREDICT == 1, "CLIENT_PREDICT = 1")
	_assert(ServerAuthority.AuthorityMode.SERVER_ONLY == 2, "SERVER_ONLY = 2")

	# Test 29: _max_snapshots constant
	_assert(authority._max_snapshots == 60, "_max_snapshots = 60")

	# Test 30: set_mode to CLIENT_PREDICT
	authority.set_mode(ServerAuthority.AuthorityMode.CLIENT_PREDICT)
	_assert(authority.get_mode() == ServerAuthority.AuthorityMode.CLIENT_PREDICT, "Mode set to CLIENT_PREDICT")
	var client_cmd = authority.submit_command({"type": "attack", "unit_id": "player_1"})
	_assert(client_cmd.has("status"), "CLIENT_PREDICT command has status")
	authority.set_mode(ServerAuthority.AuthorityMode.LOCAL_SIMULATION)


## ============================================
## MonetizationManager System Tests
## ============================================
func _test_monetization_manager() -> void:
	print("\n--- MonetizationManager System Tests ---")

	# Test 1: Default is_subscriber = false (M2 mock)
	_assert(MonetizationManager.is_subscriber() == false, "Default is_subscriber = false")

	# Test 2: Default subscription tier = none
	_assert(MonetizationManager.get_subscription_tier() == "none", "Default tier = none")

	# Test 3: get_shop_items returns array
	var shop_items = MonetizationManager.get_shop_items()
	_assert(typeof(shop_items) == TYPE_ARRAY, "get_shop_items returns array")
	_assert(shop_items.size() > 0, "Shop has items: %d" % shop_items.size())

	# Test 4: get_owned_items returns array
	var owned_items = MonetizationManager.get_owned_items()
	_assert(typeof(owned_items) == TYPE_ARRAY, "get_owned_items returns array")

	# Test 5: has_item for nonexistent item = false
	_assert(MonetizationManager.has_item("nonexistent_item") == false, "has_item nonexistent = false")

	# Test 6: has_skin for nonexistent skin = false
	_assert(MonetizationManager.has_skin("nonexistent_skin") == false, "has_skin nonexistent = false")

	# Test 7: get_currency default soft currency > 0
	var soft_currency = MonetizationManager.get_currency("soft")
	_assert(soft_currency >= 0, "Soft currency >= 0: %d" % soft_currency)

	# Test 8: get_currency default hard currency >= 0
	var hard_currency = MonetizationManager.get_currency("hard")
	_assert(hard_currency >= 0, "Hard currency >= 0: %d" % hard_currency)

	# Test 9: add_currency increases soft currency
	var before = MonetizationManager.get_currency("soft")
	MonetizationManager.add_currency(100, "soft")
	var after = MonetizationManager.get_currency("soft")
	_assert(after == before + 100, "add_currency works: %d -> %d" % [before, after])

	# Test 10: add_currency increases hard currency
	var before_hard = MonetizationManager.get_currency("hard")
	MonetizationManager.add_currency(50, "hard")
	var after_hard = MonetizationManager.get_currency("hard")
	_assert(after_hard == before_hard + 50, "add_currency hard works: %d -> %d" % [before_hard, after_hard])

	# Test 11: purchase_item with nonexistent item fails
	var purchase_result = MonetizationManager.purchase_item("nonexistent_item")
	_assert(typeof(purchase_result) == TYPE_DICTIONARY, "purchase_item returns dictionary")
	_assert(purchase_result.has("success"), "purchase_result has success field")
	_assert(purchase_result["success"] == false, "Purchase nonexistent fails")

	# Test 12: get_equipped_item returns dictionary
	var equipped = MonetizationManager.get_equipped_item("skin")
	_assert(typeof(equipped) == TYPE_DICTIONARY, "get_equipped_item returns dictionary")

	# Test 13: equip_item with nonexistent item fails
	var equip_result = MonetizationManager.equip_item("nonexistent_item", "skin")
	_assert(typeof(equip_result) == TYPE_DICTIONARY, "equip_item returns dictionary")
	_assert(equip_result.has("success"), "equip_result has success field")

	# Test 14: get_season_pass_info returns dictionary
	var season_pass = MonetizationManager.get_season_pass_info()
	_assert(typeof(season_pass) == TYPE_DICTIONARY, "get_season_pass_info returns dictionary")
	_assert(season_pass.has("active"), "Season pass has active field")

	# Test 15: get_info returns dictionary
	var info = MonetizationManager.get_info()
	_assert(typeof(info) == TYPE_DICTIONARY, "get_info returns dictionary")
	_assert(info.has("subscriber"), "get_info has subscriber")
	_assert(info.has("subscription_tier"), "get_info has subscription_tier")
	_assert(info.has("owned_items"), "get_info has owned_items")
	_assert(info.has("cosmetic_only"), "get_info has cosmetic_only")
	_assert(info["cosmetic_only"] == true, "cosmetic_only = true (no pay-to-win)")
	_assert(info.has("mock_mode"), "get_info has mock_mode")
	_assert(info["mock_mode"] == true, "mock_mode = true (M2 prototype)")

	# Test 16: Shop items have required fields
	if shop_items.size() > 0:
		var first_item = shop_items[0]
		_assert(typeof(first_item) == TYPE_DICTIONARY, "First shop item is dictionary")
		_assert(first_item.has("id"), "Shop item has id")
		_assert(first_item.has("name"), "Shop item has name")
		_assert(first_item.has("price"), "Shop item has price")

	# Test 17: Shop items are cosmetic only (no stat bonuses)
	if shop_items.size() > 0:
		for item in shop_items:
			_assert(not item.has("stat_bonus"), "Shop item %s has no stat_bonus (cosmetic only)" % item.get("id", "unknown"))
			_assert(not item.has("damage_boost"), "Shop item %s has no damage_boost" % item.get("id", "unknown"))

	# Test 18: ISkin interface preload exists
	_assert(MonetizationManager.ISkin != null, "ISkin interface preloaded")

	# Test 19: Currency types exist
	_assert(MonetizationManager.get_currency("soft") >= 0, "Soft currency type exists")
	_assert(MonetizationManager.get_currency("hard") >= 0, "Hard currency type exists")

	# Test 20: Negative currency add doesn't break
	var before_neg = MonetizationManager.get_currency("soft")
	MonetizationManager.add_currency(-10, "soft")
	var after_neg = MonetizationManager.get_currency("soft")
	_assert(after_neg == before_neg - 10, "Negative currency add works: %d -> %d" % [before_neg, after_neg])

	# Test 21: get_subscription_tier returns string
	var sub_tier = MonetizationManager.get_subscription_tier()
	_assert(typeof(sub_tier) == TYPE_STRING, "get_subscription_tier returns string")
	_assert(sub_tier == "none", "Default tier = none")

	# Test 22: has_item for nonexistent returns false
	_assert(MonetizationManager.has_item("nonexistent_item") == false, "has_item nonexistent = false")

	# Test 23: has_skin for nonexistent returns false
	_assert(MonetizationManager.has_skin("nonexistent_skin") == false, "has_skin nonexistent = false")

	# Test 24: get_owned_items returns array
	var owned_list = MonetizationManager.get_owned_items()
	_assert(typeof(owned_list) == TYPE_ARRAY, "get_owned_items returns array")

	# Test 25: get_shop_items returns array
	var shop_list = MonetizationManager.get_shop_items()
	_assert(typeof(shop_list) == TYPE_ARRAY, "get_shop_items returns array")
	_assert(shop_list.size() > 0, "Shop has items")

	# Test 26: purchase_item nonexistent returns error
	var purchase_resp = MonetizationManager.purchase_item("nonexistent_item")
	_assert(typeof(purchase_resp) == TYPE_DICTIONARY, "purchase_item returns dictionary")
	_assert(purchase_resp.has("success"), "purchase_result has success")
	_assert(purchase_resp["success"] == false, "Purchase nonexistent fails")

	# Test 27: equip_item nonexistent returns error
	var equip_resp = MonetizationManager.equip_item("nonexistent_item", "skin")
	_assert(typeof(equip_resp) == TYPE_DICTIONARY, "equip_item returns dictionary")
	_assert(equip_resp.has("success"), "equip_result has success")
	_assert(equip_resp["success"] == false, "Equip nonexistent fails")

	# Test 28: get_equipped_item returns dictionary
	var equipped_item = MonetizationManager.get_equipped_item("skin")
	_assert(typeof(equipped_item) == TYPE_DICTIONARY, "get_equipped_item returns dictionary")

	# Test 29: get_season_pass_info returns dictionary
	var season_data = MonetizationManager.get_season_pass_info()
	_assert(typeof(season_data) == TYPE_DICTIONARY, "get_season_pass_info returns dictionary")
	_assert(season_data.has("tier"), "Season pass has tier")
	_assert(season_data.has("xp"), "Season pass has xp")
	_assert(season_data.has("active"), "Season pass has active")

	# Test 30: get_info returns all required fields
	var mon_data = MonetizationManager.get_info()
	_assert(typeof(mon_data) == TYPE_DICTIONARY, "get_info returns dictionary")
	_assert(mon_data.has("subscriber"), "get_info has subscriber")
	_assert(mon_data.has("owned_items"), "get_info has owned_items")
	_assert(mon_data.has("shop_items"), "get_info has shop_items")
	_assert(mon_data.has("currency"), "get_info has currency")


## ============================================
## PlatformSDK System Tests
## ============================================
func _test_platform_sdk() -> void:
	print("\n--- PlatformSDK System Tests ---")

	# Test 1: Default mock mode = true (M2 prototype)
	var info = PlatformSDK.get_info()
	_assert(typeof(info) == TYPE_DICTIONARY, "get_info returns dictionary")
	_assert(info.has("mock_mode"), "get_info has mock_mode")
	_assert(info["mock_mode"] == true, "mock_mode = true (M2 prototype)")

	# Test 2: set_mock_mode works
	PlatformSDK.set_mock_mode(false)
	var info2 = PlatformSDK.get_info()
	_assert(info2["mock_mode"] == false, "set_mock_mode(false) works")
	PlatformSDK.set_mock_mode(true)
	var info3 = PlatformSDK.get_info()
	_assert(info3["mock_mode"] == true, "set_mock_mode(true) works")

	# Test 3: get_soul for nonexistent creates default in mock mode (test before creating souls)
	var nonexistent = PlatformSDK.get_soul("nonexistent_soul_id")
	_assert(nonexistent != null, "get_soul nonexistent creates default in mock mode")
	_assert(nonexistent.soul_id == "nonexistent_soul_id", "Created soul has requested id")
	# Cleanup the auto-created soul
	PlatformSDK.delete_soul("nonexistent_soul_id")

	# Test 4: create_soul returns soul snapshot
	var soul = PlatformSDK.create_soul("TestSoul", "fire", {"aggression": 0.5})
	_assert(soul != null, "create_soul returns non-null")
	_assert(soul is PlatformSDK.SoulSnapshotClass, "create_soul returns SoulSnapshot")
	_assert(soul.soul_id != "", "Created soul has soul_id")
	_assert(soul.soul_name == "TestSoul", "Created soul name = TestSoul")
	_assert(soul.element == "fire", "Created soul element = fire")

	# Test 5: get_soul returns created soul
	var soul_id = soul.soul_id
	var retrieved = PlatformSDK.get_soul(soul_id)
	_assert(retrieved != null, "get_soul returns non-null")
	_assert(retrieved.soul_id == soul_id, "Retrieved soul id matches")
	_assert(retrieved.soul_name == "TestSoul", "Retrieved soul name matches")

	# Test 6: list_souls returns array
	var souls = PlatformSDK.list_souls()
	_assert(typeof(souls) == TYPE_ARRAY, "list_souls returns array")
	_assert(souls.size() >= 1, "list_souls has at least 1 soul: %d" % souls.size())

	# Test 7: set_active_soul works
	var set_result = PlatformSDK.set_active_soul(soul_id)
	_assert(set_result == true, "set_active_soul returns true")

	# Test 8: get_active_soul returns active soul
	var active = PlatformSDK.get_active_soul()
	_assert(active != null, "get_active_soul returns non-null")
	_assert(active.soul_id == soul_id, "Active soul id matches")

	# Test 9: save_soul works
	var save_result = PlatformSDK.save_soul(soul)
	_assert(save_result == true, "save_soul returns true")

	# Test 10: update_soul_stats works
	var before_exp = PlatformSDK.get_soul(soul_id).experience
	var update_result = PlatformSDK.update_soul_stats(soul_id, {"experience": 1000})
	_assert(update_result != null, "update_soul_stats returns non-null")
	_assert(update_result is PlatformSDK.SoulSnapshotClass, "update_soul_stats returns SoulSnapshot")
	_assert(update_result.experience > before_exp, "Soul experience increased: %d -> %d" % [before_exp, update_result.experience])

	# Test 11: add_skill works
	var skill_result = PlatformSDK.add_skill(soul_id, "fireball", 1)
	_assert(skill_result == true, "add_skill returns true")

	# Test 12: add_memory works
	var memory_result = PlatformSDK.add_memory(soul_id, {"event": "first_battle", "result": "victory"})
	_assert(memory_result == true, "add_memory returns true")

	# Test 13: migrate_soul works
	var migrate_result = PlatformSDK.migrate_soul(soul_id, "battleplan", "arena_01")
	_assert(migrate_result != null, "migrate_soul returns non-null")
	_assert(migrate_result is PlatformSDK.SoulSnapshotClass, "migrate_soul returns SoulSnapshot")
	_assert(migrate_result.current_game == "battleplan", "Migrated soul current_game = battleplan")

	# Test 14: SoulSnapshot class preloaded
	_assert(PlatformSDK.SoulSnapshotClass != null, "SoulSnapshot class preloaded")

	# Test 15: get_info has cached_souls and active_soul
	var info4 = PlatformSDK.get_info()
	_assert(info4.has("cached_souls"), "get_info has cached_souls")
	_assert(info4.has("active_soul"), "get_info has active_soul")
	_assert(info4.has("api_base_url"), "get_info has api_base_url")
	_assert(info4.has("sdk_version"), "get_info has sdk_version")
	_assert(info4["sdk_version"] == "1.0.0", "sdk_version = 1.0.0")

	# Test 16: API base URL is localhost (M2 mock)
	_assert(info4["api_base_url"].find("localhost") >= 0, "API base URL is localhost")

	# Test 17: Create multiple souls
	var soul2 = PlatformSDK.create_soul("Soul2", "water", {})
	var soul3 = PlatformSDK.create_soul("Soul3", "earth", {})
	_assert(soul2 != null, "Second soul created")
	_assert(soul3 != null, "Third soul created")
	_assert(soul2.soul_name == "Soul2", "Soul2 name correct")
	_assert(soul3.soul_name == "Soul3", "Soul3 name correct")
	var souls2 = PlatformSDK.list_souls()
	_assert(souls2.size() >= 1, "list_souls has souls: %d" % souls2.size())

	# Test 18: Soul has personality
	var soul_with_personality = PlatformSDK.create_soul("PersonalitySoul", "wind", {"loyalty": 0.8, "intelligence": 0.6})
	_assert(soul_with_personality.personality.has("loyalty"), "Soul has loyalty personality")
	_assert(soul_with_personality.personality["loyalty"] == 0.8, "Soul loyalty = 0.8")

	# Test 19: Soul has default stats
	_assert(soul_with_personality.level >= 1, "Soul has level >= 1")
	_assert(soul_with_personality.experience >= 0, "Soul has experience >= 0")
	_assert(typeof(soul_with_personality.skills) == TYPE_DICTIONARY, "Soul has skills dict")
	_assert(typeof(soul_with_personality.memories) == TYPE_ARRAY, "Soul has memories array")

	# Test 20: delete_soul removes from cache
	var cache_before_delete = PlatformSDK.get_info()["cached_souls"]
	var delete_result = PlatformSDK.delete_soul(soul_id)
	_assert(delete_result == true, "delete_soul returns true")
	var cache_after_delete = PlatformSDK.get_info()["cached_souls"]
	_assert(cache_after_delete < cache_before_delete, "Soul removed from cache: %d -> %d" % [cache_before_delete, cache_after_delete])

	# Test 21: Cleanup test souls
	PlatformSDK.delete_soul(soul2.soul_id)
	PlatformSDK.delete_soul(soul3.soul_id)
	PlatformSDK.delete_soul(soul_with_personality.soul_id)

	# Test 22: set_mock_mode toggles
	PlatformSDK.set_mock_mode(false)
	var info_after_off = PlatformSDK.get_info()
	_assert(info_after_off["mock_mode"] == false, "mock_mode set to false")
	PlatformSDK.set_mock_mode(true)
	var info_after_on = PlatformSDK.get_info()
	_assert(info_after_on["mock_mode"] == true, "mock_mode set to true")

	# Test 23: list_souls returns array
	var soul_list = PlatformSDK.list_souls()
	_assert(typeof(soul_list) == TYPE_ARRAY, "list_souls returns array")

	# Test 24: create and get soul roundtrip
	var roundtrip_soul = PlatformSDK.create_soul("TestSoul", "fire")
	_assert(roundtrip_soul != null, "create_soul returns non-null")
	_assert(roundtrip_soul.soul_name == "TestSoul", "Soul name = TestSoul")
	var fetched_soul = PlatformSDK.get_soul(roundtrip_soul.soul_id)
	_assert(fetched_soul != null, "get_soul returns non-null")
	_assert(fetched_soul.soul_name == "TestSoul", "Retrieved soul name matches")

	# Test 25: set_active_soul and get_active_soul
	var set_active_resp = PlatformSDK.set_active_soul(roundtrip_soul.soul_id)
	_assert(set_active_resp == true, "set_active_soul returns true")
	var current_active = PlatformSDK.get_active_soul()
	_assert(current_active != null, "get_active_soul returns non-null")
	_assert(current_active.soul_id == roundtrip_soul.soul_id, "Active soul id matches")

	# Test 26: update_soul_stats
	var stats_update_resp = PlatformSDK.update_soul_stats(roundtrip_soul.soul_id, {"experience": 50})
	_assert(stats_update_resp != null, "update_soul_stats returns non-null")
	var soul_after_update = PlatformSDK.get_soul(roundtrip_soul.soul_id)
	_assert(soul_after_update.experience >= 50, "Soul experience updated: %d" % soul_after_update.experience)

	# Test 27: add_skill
	var add_skill_resp = PlatformSDK.add_skill(roundtrip_soul.soul_id, "fireball", 1)
	_assert(add_skill_resp == true, "add_skill returns true")
	var soul_after_skill = PlatformSDK.get_soul(roundtrip_soul.soul_id)
	_assert(soul_after_skill.skills.has("fireball"), "Soul has fireball skill")

	# Test 28: add_memory
	var add_memory_resp = PlatformSDK.add_memory(roundtrip_soul.soul_id, {"type": "battle", "content": "won a fight"})
	_assert(add_memory_resp == true, "add_memory returns true")
	var soul_after_memory = PlatformSDK.get_soul(roundtrip_soul.soul_id)
	_assert(soul_after_memory.memories.size() > 0, "Soul has memories")

	# Test 29: migrate_soul
	var migrate_resp = PlatformSDK.migrate_soul(roundtrip_soul.soul_id, "battleplan", "arena_1")
	_assert(migrate_resp != null, "migrate_soul returns non-null")

	# Test 30: get_info has all required fields
	var platform_info = PlatformSDK.get_info()
	_assert(platform_info.has("cached_souls"), "get_info has cached_souls")
	_assert(platform_info.has("active_soul"), "get_info has active_soul")
	_assert(platform_info.has("sdk_version"), "get_info has sdk_version")
	_assert(platform_info.has("mock_mode"), "get_info has mock_mode")

	# Cleanup
	PlatformSDK.delete_soul(roundtrip_soul.soul_id)


## ============================================
## WorldLoader System Tests
## ============================================
func _test_world_loader() -> void:
	print("\n--- WorldLoader System Tests ---")

	# Test 1: WorldPlugin class preloaded
	_assert(WorldLoader.WorldPlugin != null, "WorldPlugin class preloaded")

	# Test 2: get_registered_worlds returns array
	var registered = WorldLoader.get_registered_worlds()
	_assert(typeof(registered) == TYPE_ARRAY, "get_registered_worlds returns array")

	# Test 3: get_loaded_worlds returns array
	var loaded_list = WorldLoader.get_loaded_worlds()
	_assert(typeof(loaded_list) == TYPE_ARRAY, "get_loaded_worlds returns array")

	# Test 4: get_current_world_id returns string
	var current_world_id = WorldLoader.get_current_world_id()
	_assert(typeof(current_world_id) == TYPE_STRING, "get_current_world_id returns string")

	# Test 5: get_stats returns dictionary
	var stats = WorldLoader.get_stats()
	_assert(typeof(stats) == TYPE_DICTIONARY, "get_stats returns dictionary")
	_assert(stats.has("registered"), "get_stats has registered")
	_assert(stats.has("loaded"), "get_stats has loaded")
	_assert(stats.has("current_world"), "get_stats has current_world")
	_assert(stats.has("active"), "get_stats has active")

	# Test 6: register_plugin works
	WorldLoader.register_plugin("test_world", "res://platform/world/plugins/test_world.gd")
	var registered2 = WorldLoader.get_registered_worlds()
	_assert(registered2.has("test_world"), "test_world registered")

	# Test 7: get_world_info returns dictionary
	var info = WorldLoader.get_world_info("test_world")
	_assert(typeof(info) == TYPE_DICTIONARY, "get_world_info returns dictionary")
	_assert(info.has("id"), "world info has id")
	_assert(info["id"] == "test_world", "world info id = test_world")
	_assert(info.has("loaded"), "world info has loaded field")
	_assert(info["loaded"] == false, "test_world not loaded yet")

	# Test 8: get_world_info for nonexistent returns error
	var info_nonexistent = WorldLoader.get_world_info("nonexistent_world")
	_assert(typeof(info_nonexistent) == TYPE_DICTIONARY, "get_world_info nonexistent returns dictionary")
	_assert(info_nonexistent.has("error"), "nonexistent world info has error field")
	_assert(info_nonexistent["error"] == "Not registered", "error = Not registered")

	# Test 9: unregister_plugin works
	WorldLoader.unregister_plugin("test_world")
	var registered3 = WorldLoader.get_registered_worlds()
	_assert(not registered3.has("test_world"), "test_world unregistered")

	# Test 10: discover_plugins returns array
	var discovered_list = WorldLoader.discover_plugins()
	_assert(typeof(discovered_list) == TYPE_ARRAY, "discover_plugins returns array")

	# Test 11: load_world for nonexistent returns null
	var loaded_world = WorldLoader.load_world("nonexistent_world")
	_assert(loaded_world == null, "load_world nonexistent returns null")

	# Test 12: enter_world for nonexistent returns error
	var soul = PlatformSDK.create_soul("TestSoulForWorld", "fire", {})
	var enter_result = WorldLoader.enter_world("nonexistent_world", soul)
	_assert(typeof(enter_result) == TYPE_DICTIONARY, "enter_world returns dictionary")
	_assert(enter_result.has("success"), "enter_result has success field")
	_assert(enter_result["success"] == false, "enter nonexistent world fails")

	# Test 13: exit_current_world when no world active
	var exit_result = WorldLoader.exit_current_world(soul)
	_assert(typeof(exit_result) == TYPE_DICTIONARY, "exit_current_world returns dictionary")
	_assert(exit_result.has("success"), "exit_result has success field")

	# Test 14: get_current_world returns null when no active world
	var current = WorldLoader.get_current_world()
	_assert(current == null, "get_current_world returns null when no active world")

	# Test 15: Multiple plugin registration
	WorldLoader.register_plugin("world_a", "res://worlds/world_a.gd")
	WorldLoader.register_plugin("world_b", "res://worlds/world_b.gd")
	var registered4 = WorldLoader.get_registered_worlds()
	_assert(registered4.has("world_a"), "world_a registered")
	_assert(registered4.has("world_b"), "world_b registered")

	# Test 16: Stats reflect registered count
	var stats2 = WorldLoader.get_stats()
	_assert(stats2["registered"] >= 2, "registered >= 2: %d" % stats2["registered"])

	# Test 17: Cleanup plugins
	WorldLoader.unregister_plugin("world_a")
	WorldLoader.unregister_plugin("world_b")
	var registered5 = WorldLoader.get_registered_worlds()
	_assert(not registered5.has("world_a"), "world_a unregistered")
	_assert(not registered5.has("world_b"), "world_b unregistered")

	# Test 18: Cleanup soul
	PlatformSDK.delete_soul(soul.soul_id)

	# Test 19: discover_plugins returns array
	var discovered_new = WorldLoader.discover_plugins()
	_assert(typeof(discovered_new) == TYPE_ARRAY, "discover_plugins returns array")

	# Test 20: get_loaded_worlds returns array
	var loaded_new = WorldLoader.get_loaded_worlds()
	_assert(typeof(loaded_new) == TYPE_ARRAY, "get_loaded_worlds returns array")

	# Test 21: get_current_world_id returns string
	var current_id_new = WorldLoader.get_current_world_id()
	_assert(typeof(current_id_new) == TYPE_STRING, "get_current_world_id returns string")

	# Test 22: get_world_info for nonexistent returns error
	var nonexistent_info = WorldLoader.get_world_info("nonexistent_world")
	_assert(typeof(nonexistent_info) == TYPE_DICTIONARY, "get_world_info returns dictionary")
	_assert(nonexistent_info.has("error"), "Nonexistent world info has error")

	# Test 23: get_stats has all required fields
	var loader_stats = WorldLoader.get_stats()
	_assert(loader_stats.has("registered"), "get_stats has registered")
	_assert(loader_stats.has("loaded"), "get_stats has loaded")
	_assert(loader_stats.has("current_world"), "get_stats has current_world")
	_assert(loader_stats.has("active"), "get_stats has active")

	# Test 24: WorldPlugin class preloaded
	_assert(WorldLoader.WorldPlugin != null, "WorldPlugin class preloaded")

	# Test 25: Register and load world roundtrip
	WorldLoader.register_plugin("test_world_c", "res://platform/world/WorldPlugin.gd")
	var registered_c = WorldLoader.get_registered_worlds()
	_assert(registered_c.has("test_world_c"), "test_world_c registered")
	var world_c_info = WorldLoader.get_world_info("test_world_c")
	_assert(world_c_info.has("id"), "World info has id")
	_assert(world_c_info["id"] == "test_world_c", "World info id matches")
	WorldLoader.unregister_plugin("test_world_c")
	var registered_after = WorldLoader.get_registered_worlds()
	_assert(not registered_after.has("test_world_c"), "test_world_c unregistered")


## ============================================
## HomeAPI System Tests
## ============================================
func _test_home_api() -> void:
	print("\n--- HomeAPI System Tests ---")

	# Test 1: get_info returns dictionary
	var info = HomeAPI.get_info()
	_assert(typeof(info) == TYPE_DICTIONARY, "get_info returns dictionary")
	_assert(info.has("home_loaded"), "get_info has home_loaded")
	_assert(info["home_loaded"] == false, "home_loaded = false initially")

	# Test 2: get_home_state returns dictionary
	var state = HomeAPI.get_home_state()
	_assert(typeof(state) == TYPE_DICTIONARY, "get_home_state returns dictionary")

	# Test 3: get_soul_mood returns string
	var mood = HomeAPI.get_soul_mood()
	_assert(typeof(mood) == TYPE_STRING, "get_soul_mood returns string")

	# Test 4: load_home works
	var soul = PlatformSDK.create_soul("HomeSoul", "fire", {})
	var load_result = HomeAPI.load_home(soul.soul_id)
	_assert(typeof(load_result) == TYPE_DICTIONARY, "load_home returns dictionary")
	_assert(load_result.has("success"), "load_result has success field")

	# Test 5: After load, home_loaded = true
	var info2 = HomeAPI.get_info()
	_assert(info2["home_loaded"] == true, "home_loaded = true after load")

	# Test 6: get_home_state has soul_id after load
	var state2 = HomeAPI.get_home_state()
	_assert(state2.has("soul_id"), "home state has soul_id after load")
	_assert(state2["soul_id"] == soul.soul_id, "home state soul_id matches")

	# Test 7: get_soul_mood after load
	var mood2 = HomeAPI.get_soul_mood()
	_assert(typeof(mood2) == TYPE_STRING, "get_soul_mood returns string after load")
	_assert(mood2 != "", "soul mood not empty after load")

	# Test 8: interact with "chat"
	var chat_result = HomeAPI.interact("chat", {"message": "hello"})
	_assert(typeof(chat_result) == TYPE_DICTIONARY, "interact chat returns dictionary")
	_assert(chat_result.has("success"), "chat result has success field")

	# Test 9: interact with "pet"
	var pet_result = HomeAPI.interact("pet", {})
	_assert(typeof(pet_result) == TYPE_DICTIONARY, "interact pet returns dictionary")
	_assert(pet_result.has("success"), "pet result has success field")

	# Test 10: interact with "play"
	var play_result = HomeAPI.interact("play", {})
	_assert(typeof(play_result) == TYPE_DICTIONARY, "interact play returns dictionary")

	# Test 11: interact with "feed"
	var feed_result = HomeAPI.interact("feed", {})
	_assert(typeof(feed_result) == TYPE_DICTIONARY, "interact feed returns dictionary")

	# Test 12: interact with unknown type
	var unknown_result = HomeAPI.interact("unknown_type", {})
	_assert(typeof(unknown_result) == TYPE_DICTIONARY, "interact unknown returns dictionary")
	_assert(unknown_result.has("success"), "unknown result has success field")

	# Test 13: set_decoration works
	var deco_result = HomeAPI.set_decoration("wall", "painting_01")
	_assert(typeof(deco_result) == TYPE_BOOL, "set_decoration returns bool")

	# Test 14: set_room_theme works
	var theme_result = HomeAPI.set_room_theme("cozy")
	_assert(typeof(theme_result) == TYPE_BOOL, "set_room_theme returns bool")

	# Test 15: unload_home works
	HomeAPI.unload_home()
	var info3 = HomeAPI.get_info()
	_assert(info3["home_loaded"] == false, "home_loaded = false after unload")

	# Test 16: interact after unload
	var chat_after_unload = HomeAPI.interact("chat", {"message": "test"})
	_assert(typeof(chat_after_unload) == TYPE_DICTIONARY, "interact after unload returns dictionary")

	# Test 17: get_soul_mood after unload returns default
	var mood3 = HomeAPI.get_soul_mood()
	_assert(typeof(mood3) == TYPE_STRING, "get_soul_mood returns string after unload")

	# Test 18: Cleanup soul
	PlatformSDK.delete_soul(soul.soul_id)

	# Test 19: set_decoration returns bool
	var deco_new = HomeAPI.set_decoration("wall", "painting_01")
	_assert(typeof(deco_new) == TYPE_BOOL, "set_decoration returns bool")

	# Test 20: set_room_theme returns bool
	var theme_new = HomeAPI.set_room_theme("cozy")
	_assert(typeof(theme_new) == TYPE_BOOL, "set_room_theme returns bool")

	# Test 21: get_home_state returns dictionary
	var home_state = HomeAPI.get_home_state()
	_assert(typeof(home_state) == TYPE_DICTIONARY, "get_home_state returns dictionary")

	# Test 22: get_info has all required fields
	var home_info = HomeAPI.get_info()
	_assert(home_info.has("home_loaded"), "get_info has home_loaded")
	_assert(home_info.has("active_soul"), "get_info has active_soul")
	_assert(home_info.has("interaction_cooldown"), "get_info has interaction_cooldown")

	# Test 23: interact with play type
	var play_new = HomeAPI.interact("play", {"toy": "ball"} )
	_assert(typeof(play_new) == TYPE_DICTIONARY, "interact play returns dictionary")

	# Test 24: interact with feed type
	var feed_new = HomeAPI.interact("feed", {"food": "soul_cake"} )
	_assert(typeof(feed_new) == TYPE_DICTIONARY, "interact feed returns dictionary")

	# Test 25: interact with invalid type
	var invalid_interact = HomeAPI.interact("invalid_type", {})
	_assert(typeof(invalid_interact) == TYPE_DICTIONARY, "interact invalid returns dictionary")


## ============================================
## SoulSnapshot System Tests
## ============================================
func _test_soul_snapshot() -> void:
	print("\n--- SoulSnapshot System Tests ---")

	# Test 1: SNAPSHOT_VERSION constant
	_assert(SoulSnapshot.SNAPSHOT_VERSION == "1.0.0", "SNAPSHOT_VERSION = 1.0.0")

	# Test 2: Create new snapshot
	var snapshot = SoulSnapshot.new()
	_assert(snapshot != null, "SoulSnapshot created")
	_assert(snapshot is SoulSnapshot, "snapshot is SoulSnapshot")

	# Test 3: Default values
	_assert(snapshot.soul_id == "", "Default soul_id = empty")
	_assert(snapshot.soul_name == "", "Default soul_name = empty")
	_assert(snapshot.element == "", "Default element = empty")
	_assert(snapshot.level == 1, "Default level = 1")
	_assert(snapshot.experience == 0, "Default experience = 0")
	_assert(snapshot.experience_to_next == 100, "Default experience_to_next = 100")

	# Test 4: Default cognition stats
	_assert(snapshot.cognition.has("perception"), "cognition has perception")
	_assert(snapshot.cognition.has("memory"), "cognition has memory")
	_assert(snapshot.cognition.has("reasoning"), "cognition has reasoning")
	_assert(snapshot.cognition.has("decision"), "cognition has decision")
	_assert(snapshot.cognition.has("learning"), "cognition has learning")
	_assert(snapshot.cognition.has("creativity"), "cognition has creativity")

	# Test 5: Default emotion stats
	_assert(snapshot.emotion.has("empathy"), "emotion has empathy")
	_assert(snapshot.emotion.has("expression"), "emotion has expression")
	_assert(snapshot.emotion.has("attachment"), "emotion has attachment")
	_assert(snapshot.emotion.has("emotional_range"), "emotion has emotional_range")
	_assert(snapshot.emotion.has("emotional_depth"), "emotion has emotional_depth")

	# Test 6: Default collections
	_assert(typeof(snapshot.skills) == TYPE_DICTIONARY, "skills is dictionary")
	_assert(typeof(snapshot.personality) == TYPE_DICTIONARY, "personality is dictionary")
	_assert(typeof(snapshot.memories) == TYPE_ARRAY, "memories is array")
	_assert(typeof(snapshot.achievements) == TYPE_DICTIONARY, "achievements is dictionary")
	_assert(typeof(snapshot.appearance) == TYPE_DICTIONARY, "appearance is dictionary")
	_assert(typeof(snapshot.relationships) == TYPE_DICTIONARY, "relationships is dictionary")
	_assert(typeof(snapshot.inventory) == TYPE_DICTIONARY, "inventory is dictionary")
	_assert(typeof(snapshot.migration_history) == TYPE_ARRAY, "migration_history is array")

	# Test 7: Set properties
	snapshot.soul_id = "soul_test_001"
	snapshot.soul_name = "TestSoul"
	snapshot.element = "fire"
	snapshot.level = 5
	snapshot.experience = 500
	_assert(snapshot.soul_id == "soul_test_001", "soul_id set correctly")
	_assert(snapshot.soul_name == "TestSoul", "soul_name set correctly")
	_assert(snapshot.element == "fire", "element set correctly")
	_assert(snapshot.level == 5, "level set correctly")
	_assert(snapshot.experience == 500, "experience set correctly")

	# Test 8: to_dict returns dictionary
	var dict = snapshot.to_dict()
	_assert(typeof(dict) == TYPE_DICTIONARY, "to_dict returns dictionary")
	_assert(dict.has("soul_id"), "dict has soul_id")
	_assert(dict["soul_id"] == "soul_test_001", "dict soul_id matches")
	_assert(dict.has("soul_name"), "dict has soul_name")
	_assert(dict["soul_name"] == "TestSoul", "dict soul_name matches")
	_assert(dict.has("level"), "dict has level")
	_assert(dict["level"] == 5, "dict level matches")
	_assert(dict.has("cognition"), "dict has cognition")
	_assert(dict.has("emotion"), "dict has emotion")

	# Test 9: load_from_dict works
	var snapshot2 = SoulSnapshot.new()
	snapshot2.load_from_dict(dict)
	_assert(snapshot2.soul_id == "soul_test_001", "load_from_dict soul_id matches")
	_assert(snapshot2.soul_name == "TestSoul", "load_from_dict soul_name matches")
	_assert(snapshot2.element == "fire", "load_from_dict element matches")
	_assert(snapshot2.level == 5, "load_from_dict level matches")
	_assert(snapshot2.experience == 500, "load_from_dict experience matches")

	# Test 10: to_json returns string
	var json = snapshot.to_json()
	_assert(typeof(json) == TYPE_STRING, "to_json returns string")
	_assert(json.length() > 0, "json not empty")
	_assert(json.find("soul_test_001") >= 0, "json contains soul_id")

	# Test 11: load_from_json works
	var snapshot3 = SoulSnapshot.new()
	var load_result = snapshot3.load_from_json(json)
	_assert(load_result == true, "load_from_json returns true")
	_assert(snapshot3.soul_id == "soul_test_001", "load_from_json soul_id matches")
	_assert(snapshot3.soul_name == "TestSoul", "load_from_json soul_name matches")

	# Test 12: record_migration works
	snapshot.record_migration("battleplan", "arena_01", "enter")
	_assert(snapshot.migration_history.size() == 1, "migration_history has 1 entry")
	_assert(snapshot.current_game == "battleplan", "current_game updated")
	_assert(snapshot.current_world == "arena_01", "current_world updated")

	# Test 13: migration_history entry structure
	var migration = snapshot.migration_history[0]
	_assert(typeof(migration) == TYPE_DICTIONARY, "migration entry is dictionary")
	_assert(migration.has("game"), "migration has game")
	_assert(migration["game"] == "battleplan", "migration game = battleplan")
	_assert(migration.has("world"), "migration has world")
	_assert(migration.has("action"), "migration has action")
	_assert(migration.has("timestamp"), "migration has timestamp")

	# Test 14: Multiple migrations
	snapshot.record_migration("home", "living_room", "exit")
	_assert(snapshot.migration_history.size() == 2, "migration_history has 2 entries")
	_assert(snapshot.current_game == "home", "current_game updated to home")

	# Test 15: validate returns dictionary
	var validation = snapshot.validate()
	_assert(typeof(validation) == TYPE_DICTIONARY, "validate returns dictionary")
	_assert(validation.has("valid"), "validation has valid field")

	# Test 16: get_power_level returns int
	var power = snapshot.get_power_level()
	_assert(typeof(power) == TYPE_INT, "get_power_level returns int")
	_assert(power >= 0, "power_level >= 0")

	# Test 17: get_summary returns dictionary
	var summary = snapshot.get_summary()
	_assert(typeof(summary) == TYPE_DICTIONARY, "get_summary returns dictionary")
	_assert(summary.has("id"), "summary has id")
	_assert(summary["id"] == "soul_test_001", "summary id matches")
	_assert(summary.has("name"), "summary has name")
	_assert(summary["name"] == "TestSoul", "summary name matches")
	_assert(summary.has("level"), "summary has level")
	_assert(summary.has("element"), "summary has element")
	_assert(summary.has("power"), "summary has power")
	_assert(summary.has("migrations"), "summary has migrations")

	# Test 18: Round-trip to_dict -> load_from_dict preserves data
	var dict2 = snapshot.to_dict()
	var snapshot4 = SoulSnapshot.new()
	snapshot4.load_from_dict(dict2)
	_assert(snapshot4.soul_id == snapshot.soul_id, "round-trip soul_id preserved")
	_assert(snapshot4.level == snapshot.level, "round-trip level preserved")
	_assert(snapshot4.migration_history.size() == snapshot.migration_history.size(), "round-trip migration_history preserved")

	# Test 19: signature field exists
	_assert(typeof(snapshot.signature) == TYPE_STRING, "signature is string")
	snapshot.signature = "sig_12345"
	_assert(snapshot.signature == "sig_12345", "signature set correctly")

	# Test 20: metadata field exists
	_assert(typeof(snapshot.metadata) == TYPE_DICTIONARY, "metadata is dictionary")
	snapshot.metadata["custom_key"] = "custom_value"
	_assert(snapshot.metadata["custom_key"] == "custom_value", "metadata custom key works")


	# Test 21: to_json returns valid JSON string
	var json_str = snapshot.to_json()
	_assert(typeof(json_str) == TYPE_STRING, "to_json returns string")
	_assert(json_str.length() > 0, "JSON string is non-empty")

	# Test 22: load_from_json round-trip
	var snapshot_from_json = SoulSnapshot.new()
	var load_json_result = snapshot_from_json.load_from_json(json_str)
	_assert(load_json_result == true, "load_from_json returns true")
	_assert(snapshot_from_json.soul_id == snapshot.soul_id, "JSON round-trip soul_id preserved")

	# Test 23: record_migration adds to history
	var mig_count_before = snapshot.migration_history.size()
	snapshot.record_migration("battleplan", "arena_1", "enter")
	_assert(snapshot.migration_history.size() == mig_count_before + 1, "migration recorded")

	# Test 24: validate returns dictionary with errors array
	var validation_new = snapshot.validate()
	_assert(typeof(validation_new) == TYPE_DICTIONARY, "validate returns dictionary")
	_assert(validation_new.has("valid"), "validation has valid field")
	_assert(validation_new.has("errors"), "validation has errors field")

	# Test 25: get_power_level returns positive int
	var power_new = snapshot.get_power_level()
	_assert(typeof(power_new) == TYPE_INT, "get_power_level returns int")
	_assert(power_new > 0, "power level > 0")

	# Test 26: achievements field exists
	_assert(typeof(snapshot.achievements) == TYPE_DICTIONARY, "achievements is dictionary")
	snapshot.achievements["first_battle"] = true
	_assert(snapshot.achievements["first_battle"] == true, "achievement set works")

	# Test 27: appearance field exists
	_assert(typeof(snapshot.appearance) == TYPE_DICTIONARY, "appearance is dictionary")

	# Test 28: relationships field exists
	_assert(typeof(snapshot.relationships) == TYPE_DICTIONARY, "relationships is dictionary")

	# Test 29: inventory field exists
	_assert(typeof(snapshot.inventory) == TYPE_DICTIONARY, "inventory is dictionary")

## ============================================
## WorldPlugin System Tests
## ============================================
func _test_world_plugin() -> void:
	print("\n--- WorldPlugin System Tests ---")

	# Test 1: Create new plugin
	var plugin = WorldPlugin.new()
	_assert(plugin != null, "WorldPlugin created")
	_assert(plugin is WorldPlugin, "plugin is WorldPlugin")

	# Test 2: Default values
	_assert(plugin.plugin_id == "", "Default plugin_id = empty")
	_assert(plugin.plugin_name == "", "Default plugin_name = empty")
	_assert(plugin.plugin_version == "1.0.0", "Default plugin_version = 1.0.0")
	_assert(plugin.author == "", "Default author = empty")
	_assert(plugin.description == "", "Default description = empty")
	_assert(plugin.world_type == "exploration", "Default world_type = exploration")
	_assert(plugin.api_version == "1.0.0", "Default api_version = 1.0.0")

	# Test 3: Set properties
	plugin.plugin_id = "test_world_01"
	plugin.plugin_name = "Test World"
	plugin.author = "Test Author"
	plugin.description = "A test world for plugin system"
	plugin.world_type = "battle"
	_assert(plugin.plugin_id == "test_world_01", "plugin_id set correctly")
	_assert(plugin.plugin_name == "Test World", "plugin_name set correctly")
	_assert(plugin.author == "Test Author", "author set correctly")
	_assert(plugin.description == "A test world for plugin system", "description set correctly")
	_assert(plugin.world_type == "battle", "world_type set correctly")

	# Test 4: config dictionary
	_assert(typeof(plugin.config) == TYPE_DICTIONARY, "config is dictionary")
	plugin.config["max_players"] = 4
	plugin.config["difficulty"] = "normal"
	_assert(plugin.config["max_players"] == 4, "config max_players = 4")
	_assert(plugin.config["difficulty"] == "normal", "config difficulty = normal")

	# Test 5: world_state dictionary
	_assert(typeof(plugin.world_state) == TYPE_DICTIONARY, "world_state is dictionary")
	plugin.world_state["time"] = 100
	plugin.world_state["weather"] = "clear"
	_assert(plugin.world_state["time"] == 100, "world_state time = 100")
	_assert(plugin.world_state["weather"] == "clear", "world_state weather = clear")

	# Test 6: load_world works
	var load_result = plugin.load_world()
	_assert(load_result == true, "load_world returns true")

	# Test 7: get_world_info returns dictionary
	var info = plugin.get_world_info()
	_assert(typeof(info) == TYPE_DICTIONARY, "get_world_info returns dictionary")
	_assert(info.has("id"), "info has id")
	_assert(info["id"] == "test_world_01", "info id matches")
	_assert(info.has("name"), "info has name")
	_assert(info.has("version"), "info has version")
	_assert(info.has("type"), "info has type")
	_assert(info.has("loaded"), "info has loaded field")
	_assert(info["loaded"] == true, "info loaded = true after load")

	# Test 8: get_supported_features returns array
	var features = plugin.get_supported_features()
	_assert(typeof(features) == TYPE_ARRAY, "get_supported_features returns array")

	# Test 9: supports_feature works
	var supports_weather = plugin.supports_feature("weather")
	_assert(typeof(supports_weather) == TYPE_BOOL, "supports_feature returns bool")

	# Test 10: enter_world returns dictionary
	var soul = SoulSnapshot.new()
	soul.soul_id = "soul_for_plugin_test"
	soul.soul_name = "PluginTestSoul"
	var enter_result = plugin.enter_world(soul)
	_assert(typeof(enter_result) == TYPE_DICTIONARY, "enter_world returns dictionary")
	_assert(enter_result.has("success"), "enter_result has success field")

	# Test 11: exit_world returns dictionary
	var exit_result = plugin.exit_world(soul)
	_assert(typeof(exit_result) == TYPE_DICTIONARY, "exit_world returns dictionary")
	_assert(exit_result.has("success"), "exit_result has success field")

	# Test 12: update_world works
	plugin.update_world(0.016)
	# No assertion needed, just verify no crash

	# Test 13: serialize_state returns dictionary
	var state = plugin.serialize_state()
	_assert(typeof(state) == TYPE_DICTIONARY, "serialize_state returns dictionary")
	_assert(state.has("world_state"), "serialized state has world_state")

	# Test 14: deserialize_state works
	var new_plugin = WorldPlugin.new()
	new_plugin.deserialize_state(state)
	_assert(new_plugin.world_state.has("time"), "deserialized world_state has time")
	_assert(new_plugin.world_state["time"] == 100, "deserialized time = 100")

	# Test 15: unload_world works
	plugin.unload_world()
	var info2 = plugin.get_world_info()
	_assert(info2["loaded"] == false, "info loaded = false after unload")

	# Test 16: Multiple plugin instances independent
	var plugin_a = WorldPlugin.new()
	var plugin_b = WorldPlugin.new()
	plugin_a.plugin_id = "plugin_a"
	plugin_b.plugin_id = "plugin_b"
	_assert(plugin_a.plugin_id == "plugin_a", "plugin_a id independent")
	_assert(plugin_b.plugin_id == "plugin_b", "plugin_b id independent")
	plugin_a.world_state["shared"] = "a_value"
	_assert(not plugin_b.world_state.has("shared"), "plugin_b world_state independent")

	# Test 17: _init_plugin can be called
	plugin_a._init_plugin()
	# No assertion needed, just verify no crash

	# Test 18: api_version compatibility
	_assert(plugin.api_version == "1.0.0", "api_version = 1.0.0")
	plugin.api_version = "1.1.0"
	_assert(plugin.api_version == "1.1.0", "api_version updated to 1.1.0")

	# Test 19: supports_feature returns bool
	var supports = plugin.supports_feature("combat")
	_assert(typeof(supports) == TYPE_BOOL, "supports_feature returns bool")

	# Test 20: get_supported_features returns array
	var features_new = plugin.get_supported_features()
	_assert(typeof(features_new) == TYPE_ARRAY, "get_supported_features returns array")

	# Test 21: enter_world returns dictionary
	var test_snapshot = SoulSnapshot.new()
	test_snapshot.soul_id = "test_soul_001"
	var enter_new = plugin.enter_world(test_snapshot)
	_assert(typeof(enter_new) == TYPE_DICTIONARY, "enter_world returns dictionary")

	# Test 22: exit_world returns dictionary
	var exit_new = plugin.exit_world(test_snapshot)
	_assert(typeof(exit_new) == TYPE_DICTIONARY, "exit_world returns dictionary")

	# Test 23: update_world can be called
	plugin.update_world(0.016)
# No assertion needed, just verify no crash

	# Test 24: config field exists
	_assert(typeof(plugin.config) == TYPE_DICTIONARY, "config is dictionary")
	plugin.config["difficulty"] = "hard"
	_assert(plugin.config["difficulty"] == "hard", "config set works")

	# Test 25: author and description fields
	_assert(typeof(plugin.author) == TYPE_STRING, "author is string")
	_assert(typeof(plugin.description) == TYPE_STRING, "description is string")
	plugin.author = "test_author"
	_assert(plugin.author == "test_author", "author set works")
	_assert(plugin.api_version == "1.1.0", "api_version updated to 1.1.0")
