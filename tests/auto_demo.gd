extends SceneTree

# Auto-demo script: runs full game flow in GUI mode for visual verification
# Main Menu -> Soul Select -> Battle -> auto-quit after 20s of combat

var _demo_phase: int = 0
var _phase_timer: float = 0.0
var _game_state = null
var _rts_manager = null
var _scene_manager = null

func _initialize():
	print("=== AUTO DEMO: Visual verification of full battle flow ===")
	print("This script auto-plays the game so you can see the visuals.")

	# Load main scene to initialize autoloads
	var main_scene = load("res://scenes/main.tscn")
	if main_scene == null:
		print("ERROR: Failed to load main scene")
		quit(1)
		return
	var main_instance = main_scene.instantiate()
	root.add_child(main_instance)

	for i in range(60):
		await process_frame

	_game_state = root.get_node_or_null("/root/GameState")
	_rts_manager = root.get_node_or_null("/root/RTSArenaManager")
	_scene_manager = root.get_node_or_null("/root/SceneManager")

	print("[DEMO] Autoloads ready. Starting auto-play in 2 seconds...")
	_phase_timer = 2.0
	_demo_phase = 1
	var last_tick := Time.get_ticks_msec()

	# Main loop
	while true:
		await process_frame
		var now := Time.get_ticks_msec()
		var delta := (now - last_tick) / 1000.0
		last_tick = now
		_phase_timer -= delta

		if _demo_phase == 1 and _phase_timer <= 0:
			# Phase 1: Click start game from main menu
			print("\n[DEMO] Phase 1: Clicking 'Start Game' from main menu...")
			var main_menu = root.find_child("MainMenu", true, false)
			if main_menu and main_menu.has_method("_on_start_pressed"):
				main_menu._on_start_pressed()
				print("[DEMO] Navigated to Soul Select")
			else:
				print("[DEMO] MainMenu not found, using SceneManager")
				_scene_manager.change_scene("res://scenes/soul_select.tscn")
			_phase_timer = 2.0
			_demo_phase = 2

		elif _demo_phase == 2 and _phase_timer <= 0:
			# Phase 2: Select first soul
			print("\n[DEMO] Phase 2: Selecting first soul (炎灵)...")
			var soul_select = root.find_child("SoulSelect", true, false)
			if soul_select and soul_select.has_method("_on_soul_selected"):
				soul_select._on_soul_selected(0)
				print("[DEMO] Soul selected, starting battle...")
			else:
				print("[DEMO] SoulSelect not found!")
			_phase_timer = 5.0  # Wait for scene transition + countdown
			_demo_phase = 3

		elif _demo_phase == 3 and _phase_timer <= 0:
			# Phase 3: Verify battle started
			print("\n[DEMO] Phase 3: Verifying battle state...")
			if _rts_manager:
				print("  battle_state: %d" % _rts_manager.battle_state)
				print("  player_unit: %s" % str(_rts_manager.player_unit))
				print("  ai_unit: %s" % str(_rts_manager.ai_unit))
				print("  battle_time: %.1fs" % _rts_manager.battle_time)
				if _rts_manager.player_unit:
					print("  Player: %s at %s, HP %d/%d" % [
						_rts_manager.player_unit.soul_name,
						str(_rts_manager.player_unit.position),
						_rts_manager.player_unit.current_hp,
						_rts_manager.player_unit.max_hp
					])
				if _rts_manager.ai_unit:
					print("  AI: %s at %s, HP %d/%d" % [
						_rts_manager.ai_unit.soul_name,
						str(_rts_manager.ai_unit.position),
						_rts_manager.ai_unit.current_hp,
						_rts_manager.ai_unit.max_hp
					])
			_phase_timer = 15.0  # Let combat play out for visual verification
			_demo_phase = 4

		elif _demo_phase == 4 and _phase_timer <= 0:
			# Phase 4: Final status and quit
			print("\n[DEMO] Phase 4: Final combat status...")
			if _rts_manager:
				print("  battle_time: %.1fs" % _rts_manager.battle_time)
				if _rts_manager.player_unit and _rts_manager.ai_unit:
					var dist = _rts_manager.player_unit.position.distance_to(_rts_manager.ai_unit.position)
					print("  Player HP: %d/%d at %s" % [
						_rts_manager.player_unit.current_hp, _rts_manager.player_unit.max_hp,
						str(_rts_manager.player_unit.position)
					])
					print("  AI HP: %d/%d at %s" % [
						_rts_manager.ai_unit.current_hp, _rts_manager.ai_unit.max_hp,
						str(_rts_manager.ai_unit.position)
					])
					print("  Distance: %.1f" % dist)
			print("\n[DEMO] Visual verification complete. Quitting in 3 seconds...")
			_phase_timer = 3.0
			_demo_phase = 5

		elif _demo_phase == 5 and _phase_timer <= 0:
			print("[DEMO] Done!")
			quit(0)
