extends SceneTree

# Automated battle flow test - simulates full game battle
# Records complete log for debugging

var _test_start_time: float = 0.0
var _battle_started: bool = false
var _battle_duration: float = 20.0  # Run battle for 20 seconds
var _rts_manager: Node = null
var _game_log: Node = null

func _initialize():
	print("=== AUTOMATED BATTLE FLOW TEST ===")
	print("Test started at: %s" % Time.get_datetime_string_from_system())
	
	# Load main scene to trigger autoload initialization
	print("\n[TEST] Loading main scene to initialize autoloads...")
	var main_scene = load("res://scenes/main.tscn")
	if main_scene == null:
		print("ERROR: Failed to load main scene")
		quit(1)
		return
	
	var main_instance = main_scene.instantiate()
	root.add_child(main_instance)
	
	# Wait for autoloads and scene to initialize
	await create_timer(3.0).timeout
	
	# Get autoload references
	_rts_manager = root.get_node("/root/RTSArenaManager")
	_game_log = root.get_node("/root/GameLog")
	
	if _rts_manager == null:
		print("ERROR: RTSArenaManager autoload not found!")
		quit(1)
		return
	
	print("[TEST] RTSArenaManager autoload found: %s" % _rts_manager.name)
	
	_test_start_time = Time.get_ticks_msec() / 1000.0
	print("\n[TEST] Autoloads initialized, starting battle simulation...")
	
	# Create test souls
	var player_soul = {
		"id": "test_player",
		"name": "测试玩家灵魂",
		"element": "fire",
		"level": 1,
		"personality": {"aggression": 70, "curiosity": 50, "calmness": 40}
	}
	
	var ai_soul = {
		"id": "test_ai",
		"name": "测试AI灵魂",
		"element": "water",
		"level": 1,
		"personality": {"aggression": 60, "curiosity": 40, "calmness": 50}
	}
	
	# Start battle directly
	print("[TEST] Starting RTS battle...")
	print("[TEST] Player: %s (%s, Lvl %d)" % [player_soul["name"], player_soul["element"], player_soul["level"]])
	print("[TEST] AI: %s (%s, Lvl %d)" % [ai_soul["name"], ai_soul["element"], ai_soul["level"]])
	
	_rts_manager.start_battle(player_soul, ai_soul)
	_battle_started = true
	
	print("\n[TEST] Battle started! Running for %.0f seconds..." % _battle_duration)
	print("[TEST] Monitoring unit movement and AI decisions...\n")
	
	# Monitor battle state periodically (wait 60 frames ~ 1 second)
	var monitor_timer = 0.0
	var frame_count = 0
	while Time.get_ticks_msec() / 1000.0 - _test_start_time < _battle_duration:
		await process_frame
		frame_count += 1
		if frame_count < 60:
			continue
		frame_count = 0
		monitor_timer += 1.0
		
		# Log battle state every second
		var p = _rts_manager.player_unit
		var a = _rts_manager.ai_unit
		if p and a:
			var dist = p.position.distance_to(a.position)
			print("[MONITOR %.0fs] Player: pos=(%.0f,%.0f) HP=%d/%d state=%d | AI: pos=(%.0f,%.0f) HP=%d/%d state=%d | dist=%.1f" % [
				monitor_timer,
				p.position.x, p.position.y, p.current_hp, p.max_hp, p.state,
				a.position.x, a.position.y, a.current_hp, a.max_hp, a.state,
				dist
			])
			
			# Check if battle ended
			if not p.is_alive or not a.is_alive:
				print("\n[TEST] Battle ended!")
				print("[TEST] Player alive: %s, AI alive: %s" % [p.is_alive, a.is_alive])
				break
		else:
			print("[MONITOR %.0fs] Units not initialized yet (p=%s, a=%s)" % [monitor_timer, p != null, a != null])
	
	# Final summary
	print("\n=== TEST SUMMARY ===")
	print("Test duration: %.1f seconds" % (Time.get_ticks_msec() / 1000.0 - _test_start_time))
	
	var p = _rts_manager.player_unit
	var a = _rts_manager.ai_unit
	if p and a:
		print("Final player position: (%.0f, %.0f)" % [p.position.x, p.position.y])
		print("Final AI position: (%.0f, %.0f)" % [a.position.x, a.position.y])
		print("Final distance: %.1f" % p.position.distance_to(a.position))
		print("Player HP: %d/%d" % [p.current_hp, p.max_hp])
		print("AI HP: %d/%d" % [a.current_hp, a.max_hp])
		print("Player state: %d" % p.state)
		print("AI state: %d" % a.state)
		
		# Check if units moved from spawn positions
		var player_moved = p.position.distance_to(Vector2(200, 300)) > 10
		var ai_moved = a.position.distance_to(Vector2(1080, 300)) > 10
		print("Player moved from spawn: %s (delta=%.1f)" % [player_moved, p.position.distance_to(Vector2(200, 300))])
		print("AI moved from spawn: %s (delta=%.1f)" % [ai_moved, a.position.distance_to(Vector2(1080, 300))])
		
		if not player_moved and not ai_moved:
			print("\n[WARNING] NEITHER UNIT MOVED FROM SPAWN! Movement system may be broken!")
		elif not player_moved:
			print("\n[WARNING] PLAYER UNIT DID NOT MOVE!")
		elif not ai_moved:
			print("\n[WARNING] AI UNIT DID NOT MOVE!")
		else:
			print("\n[OK] Both units moved from spawn positions")
	else:
		print("[ERROR] Units not initialized!")
	
	print("\n=== TEST COMPLETE ===")
	quit()
