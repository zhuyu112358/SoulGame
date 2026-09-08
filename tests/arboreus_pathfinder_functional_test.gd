extends SceneTree

# Functional test for ArboreusPathfinder

func _initialize():
	print("=== ARBOREUS PATHFINDER FUNCTIONAL TEST ===")

	for i in range(60):
		await process_frame

	# Create GridMap
	var grid = ClassDB.instantiate("ArboreusGridMap")
	print("GridMap created: %s" % grid)

	# Check GridMap methods
	var grid_methods = grid.get_method_list()
	print("\nGridMap custom methods:")
	for m in grid_methods:
		if not m.name.begins_with("_") and m.name not in ["init_ref","reference","unreference","get_reference_count","free","get_class","is_class","set","get","set_indexed","get_indexed","get_property_list","get_method_list","property_can_revert","property_get_revert","notification","to_string","get_instance_id","set_script","get_script","set_meta","remove_meta","get_meta","has_meta","get_meta_list","add_user_signal","has_user_signal","emit_signal","has_signal","get_signal_list","get_signal_connection_list","get_incoming_connections","connect","disconnect","is_connected","has_connections","set_block_signals","is_blocking_signals","notify_property_list_changed","set_message_translation","can_translate_messages","tr","tr_n","get_translation_domain","set_translation_domain","is_queued_for_deletion","cancel_free"]:
			print("  %s (args: %d)" % [m.name, m.args.size()])
			for arg in m.args:
				print("    - %s (type %d)" % [arg.name, arg.type])

	# Try to initialize grid with common method names
	print("\n=== TRYING GRID INITIALIZATION ===")

	# Try set_size
	if grid.has_method("set_size"):
		print("Calling set_size(40, 19)...")
		grid.set_size(40, 19)
	elif grid.has_method("resize"):
		print("Calling resize(40, 19)...")
		grid.resize(40, 19)
	elif grid.has_method("initialize"):
		print("Calling initialize(40, 19)...")
		grid.initialize(40, 19)

	# Try set_cell_size
	if grid.has_method("set_cell_size"):
		print("Calling set_cell_size(32)...")
		grid.set_cell_size(32)

	# Create Pathfinder
	var pf = ClassDB.instantiate("ArboreusPathfinder")
	print("\nPathfinder created: %s" % pf)

	# Set grid
	if pf.has_method("set_grid"):
		print("Calling set_grid(grid)...")
		pf.set_grid(grid)

	# Set allow diagonal
	if pf.has_method("set_allow_diagonal"):
		pf.set_allow_diagonal(true)
		print("Diagonal movement enabled")

	# Try to find a path
	print("\n=== TRYING FIND_PATH ===")
	var start = Vector2(0, 0)
	var goal = Vector2(10, 10)

	if pf.has_method("find_path"):
		var path = pf.find_path(start, goal)
		print("find_path(%s, %s) returned: %s" % [start, goal, path])
		if path:
			print("Path type: %s" % path.get_class())
			print("Path size: %d" % path.size())
			if path.size() > 0:
				print("First point: %s" % path[0])
				print("Last point: %s" % path[path.size()-1])

	print("\n=== FUNCTIONAL TEST COMPLETE ===")
	quit(0)
