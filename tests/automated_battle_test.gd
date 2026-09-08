extends SceneTree

# Automated battle flow test - simulates full game battle
# Records complete log for debugging

var _test_start_time: float = 0.0
var _battle_started: bool = false
var _battle_duration: float = 20.0
var _rts_manager: Node = null

func _initialize():
	print("=== AUTOMATED BATTLE FLOW TEST ===")
	print("Test started at: %s" % Time.get_datetime_string_from_system())
	_test_start_time = Time.get_ticks_msec() / 1000.0

	# Load main scene to trigger autoload initialization
	print("\n[TEST] Loading main scene to initialize autoloads...")
	var main_scene = load("res://scenes/main.tscn")
	if main_scene == null:
		print("ERROR: Failed to load main scene")
		quit(1)
		return

	var main_instance = main_scene.instantiate()
	root.add_child(main_instance)

	# Wait for autoloads and scene to initialize (frame-based for headless)
	for i in range(180):
		await process_frame

	# Get autoload references
	_rts_manager = root.get_node_or_null("/root/RTSArenaManager")
	if _rts_manager == null:
		print("ERROR: RTSArenaManager not found in autoloads")
		quit(1)
		return

	print("[TEST] RTSArenaManager found: %s" % _rts_manager.name)

	# Create test soul data
	var player_soul = {
		"id": "test_player_001",
		"name": "测试玩家灵魂",
		"element": "water",
		"level": 1,
		"hp": 120,
		"attack": 13,
		"defense": 8,
		"speed": 150,
		"personality": "brave"
	}

	var ai_soul = {
		"id": "test_ai_001",
		"name": "测试AI灵魂",
		"element": "fire",
		"level": 1,
		"hp": 120,
		"attack": 13,
		"defense": 8,
		"speed": 150,
		"personality": "aggressive"
	}

	# Start battle directly
	print("\n[TEST] Starting RTS battle...")
	print("[TEST] Player: %s (%s, Lvl %d)" % [player_soul["name"], player_soul["element"], player_soul["level"]])
	print("[TEST] AI: %s (%s, Lvl %d)" % [ai_soul["name"], ai_soul["element"], ai_soul["level"]])

	_rts_manager.start_battle(player_soul, ai_soul)
	_battle_started = true

	print("\n[TEST] Battle started! Running for %.0f seconds..." % _battle_duration)
	print("[TEST] Monitoring unit movement and AI decisions...\n")

	# Monitor battle state using frame counting (60 frames ~ 1 second)
	var monitor_timer = 0.0
	var frame_count = 0
	var elapsed = 0.0

	while elapsed < _battle_duration:
		await process_frame
		frame_count += 1
		elapsed = Time.get_ticks_msec() / 1000.0 - _test_start_time - 3.0  # subtract init wait

		if frame_count < 60:
			continue
		frame_count = 0
		monitor_timer += 1.0

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

			if p.current_hp <= 0 or a.current_hp <= 0:
				print("\n[TEST] Battle ended early!")
				print("[TEST] Player HP: %d, AI HP: %d" % [p.current_hp, a.current_hp])
				break
		else:
			print("[MONITOR %.0fs] Units not ready (p=%s, a=%s)" % [monitor_timer, p != null, a != null])

	# Final summary
	print("\n=== TEST SUMMARY ===")
	print("Test duration: %.1f seconds" % elapsed)

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

		var player_moved = p.position.distance_to(Vector2(200, 300)) > 10
		var ai_moved = a.position.distance_to(Vector2(1080, 300)) > 10
		print("Player moved from spawn: %s (delta=%.1f)" % [player_moved, p.position.distance_to(Vector2(200, 300))])
		print("AI moved from spawn: %s (delta=%.1f)" % [ai_moved, a.position.distance_to(Vector2(1080, 300))])

		if player_moved and ai_moved:
			print("\n[OK] Both units moved successfully!")
		elif not player_moved and not ai_moved:
			print("\n[WARNING] NEITHER UNIT MOVED!")
		else:
			print("\n[WARNING] One unit did not move!")

	print("\n=== TEST COMPLETE ===")
	quit(0)
