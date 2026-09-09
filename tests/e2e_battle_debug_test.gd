extends SceneTree

# E2E battle flow test - simulates full game flow from SoulSelect to battle
# Debug why units don't appear in actual game flow

var _test_start_time: float = 0.0
var _game_state = null
var _rts_manager = null

func _initialize():
	print("=== E2E BATTLE FLOW DEBUG TEST ===")
	print("Test started at: %s" % Time.get_datetime_string_from_system())
	_test_start_time = Time.get_ticks_msec() / 1000.0

	# Step 1: Load main scene to initialize autoloads
	print("\n[STEP 1] Loading main scene...")
	var main_scene = load("res://scenes/main.tscn")
	if main_scene == null:
		print("ERROR: Failed to load main scene")
		quit(1)
		return
	var main_instance = main_scene.instantiate()
	root.add_child(main_instance)

	for i in range(120):
		await process_frame

	# Get autoload references
	_game_state = root.get_node_or_null("/root/GameState")
	_rts_manager = root.get_node_or_null("/root/RTSArenaManager")
	print("[STEP 1] Main scene loaded, GameState=%s, RTSArenaManager=%s" % [
		str(_game_state != null), str(_rts_manager != null)
	])

	# Step 2: Simulate SoulSelect setting battle config (like _start_battle)
	print("\n[STEP 2] Simulating SoulSelect._start_battle()...")
	var player_soul = {
		"id": "test_player_001",
		"name": "测试玩家灵魂",
		"element": "water",
		"level": 1,
		"hp": 120,
		"attack": 13,
		"defense": 8,
		"is_player": true
	}
	var ai_soul = {
		"id": "ai_soul_01",
		"name": "敌方灵魂",
		"element": "fire",
		"level": 1,
		"hp": 110,
		"attack": 14,
		"defense": 9,
		"is_player": false
	}
	_game_state.set_value("battle", "player_soul", player_soul)
	_game_state.set_value("battle", "ai_soul", ai_soul)
	_game_state.set_value("battle", "map_name", "default_arena")
	print("[STEP 2] Battle config set in GameState")
	print("  player_soul: %s" % str(_game_state.get_value("battle", "player_soul", null) != null))
	print("  ai_soul: %s" % str(_game_state.get_value("battle", "ai_soul", null) != null))

	# Step 3: Switch to rts_arena scene
	print("\n[STEP 3] Switching to rts_arena scene...")
	root.remove_child(main_instance)
	main_instance.queue_free()

	var rts_scene = load("res://scenes/rts_arena.tscn")
	if rts_scene == null:
		print("ERROR: Failed to load rts_arena scene")
		quit(1)
		return
	var rts_instance = rts_scene.instantiate()
	root.add_child(rts_instance)

	# Wait for _ready and countdown
	print("[STEP 3] Waiting for RTSArenaController._ready() and countdown...")
	for i in range(900):  # 15 seconds at 60fps
		await process_frame
		if i % 60 == 0:
			if _rts_manager:
				var controller = root.get_node_or_null("RTSArena")
				var countdown_active = false
				var countdown_timer = -1.0
				var battle_active = false
				if controller and controller.script:
					countdown_active = controller._countdown_active
					countdown_timer = controller._countdown_timer
					battle_active = controller._battle_active
				print("  [t=%.1fs] bs=%d pu=%s au=%s bt=%.1f ca=%s ct=%.1f ba=%s" % [
					i / 60.0,
					_rts_manager.battle_state,
					str(_rts_manager.player_unit != null),
					str(_rts_manager.ai_unit != null),
					_rts_manager.battle_time,
					str(countdown_active),
					countdown_timer,
					str(battle_active)
				])

	# Step 4: Check final state
	print("\n[STEP 4] Final state check:")
	if _rts_manager:
		print("  battle_state: %d" % _rts_manager.battle_state)
		print("  player_unit: %s" % str(_rts_manager.player_unit))
		print("  ai_unit: %s" % str(_rts_manager.ai_unit))
		print("  battle_time: %.1f" % _rts_manager.battle_time)
		if _rts_manager.player_unit:
			print("  player position: %s" % str(_rts_manager.player_unit.position))
			print("  player hp: %d/%d" % [_rts_manager.player_unit.current_hp, _rts_manager.player_unit.max_hp])
		if _rts_manager.ai_unit:
			print("  ai position: %s" % str(_rts_manager.ai_unit.position))
	else:
		print("  ERROR: RTSArenaManager not found!")

	# Check GameState after
	print("\n[STEP 5] GameState after:")
	print("  player_soul: %s" % str(_game_state.get_value("battle", "player_soul", null)))
	print("  ai_soul: %s" % str(_game_state.get_value("battle", "ai_soul", null)))

	print("\n=== E2E TEST COMPLETE ===")
	quit(0)
