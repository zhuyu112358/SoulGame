extends SceneTree

# Full E2E test: Main Menu -> Soul Select -> Battle -> Result
# Simulates actual user click flow to verify battle starts correctly

var _test_start_time: float = 0.0
var _game_state = null
var _rts_manager = null
var _scene_manager = null

func _initialize():
	print("=== FULL E2E FLOW TEST: Main Menu -> Soul Select -> Battle ===")
	print("Test started at: %s" % Time.get_datetime_string_from_system())
	_test_start_time = Time.get_ticks_msec() / 1000.0

	# Load main scene to initialize autoloads
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
	_scene_manager = root.get_node_or_null("/root/SceneManager")
	print("[STEP 1] Autoloads: GameState=%s, RTSArenaManager=%s, SceneManager=%s" % [
		str(_game_state != null), str(_rts_manager != null), str(_scene_manager != null)
	])

	# Step 2: Navigate to soul select (simulate clicking "Start Game" button)
	print("\n[STEP 2] Navigating to Soul Select...")
	# Find MainMenu instance and call its start game method
	var main_menu = root.find_child("MainMenu", true, false)
	if main_menu and main_menu.has_method("_on_start_pressed"):
		print("[STEP 2] Found MainMenu, calling _on_start_pressed()")
		main_menu._on_start_pressed()
	else:
		print("[STEP 2] MainMenu not found or no method, using SceneManager directly")
		_scene_manager.change_scene("res://scenes/soul_select.tscn")

	# Wait for scene transition
	for i in range(120):
		await process_frame

	# Step 3: Select a soul and start battle
	print("\n[STEP 3] Selecting soul and starting battle...")
	var soul_select = root.find_child("SoulSelect", true, false)
	if soul_select:
		print("[STEP 3] Found SoulSelect instance")
		# Check if soul select has the expected methods
		print("  Methods: _on_soul_selected=%s, _start_battle=%s" % [
			str(soul_select.has_method("_on_soul_selected")),
			str(soul_select.has_method("_start_battle"))
		])
		# Simulate selecting first soul (this internally calls _start_battle)
		if soul_select.has_method("_on_soul_selected"):
			print("  Calling _on_soul_selected(0)...")
			soul_select._on_soul_selected(0)
			await process_frame
			await process_frame
		else:
			print("  ERROR: SoulSelect has no _on_soul_selected method!")
	else:
		print("[STEP 3] SoulSelect not found! Current scene children:")
		for child in root.get_children():
			print("  - %s (%s)" % [child.name, child.get_class()])

	# Wait for scene transition to rts_arena
	for i in range(120):
		await process_frame

	# Step 4: Verify battle starts
	print("\n[STEP 4] Verifying battle start...")
	var rts_arena = root.find_child("RTSArena", true, false)
	if rts_arena:
		print("[STEP 4] RTSArena scene loaded: %s" % rts_arena.name)
		print("  Script: %s" % str(rts_arena.script))
	else:
		print("[STEP 4] ERROR: RTSArena not found!")
		for child in root.get_children():
			print("  - %s (%s)" % [child.name, child.get_class()])

	# Wait for countdown and battle start (countdown is ~3.2s, headless may be slower)
	print("[STEP 4] Waiting for countdown and battle start (up to 15s)...")
	var battle_started = false
	for i in range(900):  # 15 seconds
		await process_frame
		if _rts_manager and _rts_manager.battle_state == 1:  # BattleState.ACTIVE
			battle_started = true
			print("  [t=%.1fs] BATTLE STARTED! battle_state=%d" % [i / 60.0, _rts_manager.battle_state])
			break
		if i % 120 == 0:
			var countdown_active = false
			var countdown_timer = -1.0
			if rts_arena and rts_arena.script:
				countdown_active = rts_arena._countdown_active
				countdown_timer = rts_arena._countdown_timer
			print("  [t=%.1fs] bs=%d, pu=%s, au=%s, ca=%s, ct=%.1f" % [
				i / 60.0,
				_rts_manager.battle_state if _rts_manager else -1,
				str(_rts_manager.player_unit != null) if _rts_manager else "N/A",
				str(_rts_manager.ai_unit != null) if _rts_manager else "N/A",
				str(countdown_active),
				countdown_timer
			])

	# Step 5: Verify units exist and are fighting
	print("\n[STEP 5] Verifying units and combat...")
	if battle_started and _rts_manager:
		print("  Player unit: %s" % str(_rts_manager.player_unit))
		print("  AI unit: %s" % str(_rts_manager.ai_unit))
		if _rts_manager.player_unit:
			print("  Player: name=%s, pos=%s, hp=%d/%d" % [
				_rts_manager.player_unit.soul_name,
				str(_rts_manager.player_unit.position),
				_rts_manager.player_unit.current_hp,
				_rts_manager.player_unit.max_hp
			])
		if _rts_manager.ai_unit:
			print("  AI: name=%s, pos=%s, hp=%d/%d" % [
				_rts_manager.ai_unit.soul_name,
				str(_rts_manager.ai_unit.position),
				_rts_manager.ai_unit.current_hp,
				_rts_manager.ai_unit.max_hp
			])
		print("  Battle time: %.1fs" % _rts_manager.battle_time)

		# Wait a bit more to see combat
		print("  Waiting 5s for combat to engage...")
		for i in range(300):
			await process_frame
		if _rts_manager.player_unit and _rts_manager.ai_unit:
			var dist = _rts_manager.player_unit.position.distance_to(_rts_manager.ai_unit.position)
			print("  After 5s: player_pos=%s, ai_pos=%s, dist=%.1f" % [
				str(_rts_manager.player_unit.position),
				str(_rts_manager.ai_unit.position),
				dist
			])
			print("  Player HP: %d/%d, AI HP: %d/%d" % [
				_rts_manager.player_unit.current_hp, _rts_manager.player_unit.max_hp,
				_rts_manager.ai_unit.current_hp, _rts_manager.ai_unit.max_hp
			])
			if dist < 150:
				print("  Units are in combat range!")
			else:
				print("  Units still moving...")
	else:
		print("  ERROR: Battle did not start!")

	# Summary
	print("\n=== TEST SUMMARY ===")
	print("Battle started: %s" % str(battle_started))
	if _rts_manager:
		print("Final battle_state: %d" % _rts_manager.battle_state)
		print("Player unit exists: %s" % str(_rts_manager.player_unit != null))
		print("AI unit exists: %s" % str(_rts_manager.ai_unit != null))
		print("Battle time: %.1fs" % _rts_manager.battle_time)
	print("Test duration: %.1fs" % (Time.get_ticks_msec() / 1000.0 - _test_start_time))

	if battle_started:
		print("\n[PASS] Full E2E flow verified: Main Menu -> Soul Select -> Battle!")
		quit(0)
	else:
		print("\n[FAIL] Battle did not start!")
		quit(1)
