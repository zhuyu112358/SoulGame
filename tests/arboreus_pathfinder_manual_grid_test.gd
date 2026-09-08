extends SceneTree

# Test manual GridMap setup for Pathfinder (simplified)

func _initialize():
	print("=== ARBOREUS PATHFINDER MANUAL GRID TEST ===")

	for i in range(30):
		await process_frame

	# Create ArboreusWorld
	var world_factory = ClassDB.instantiate("ArboreusWorld")
	var config = {"name": "pf_test2", "width": 1280, "height": 608, "cell_size": 32}
	var world = world_factory.create(config)
	world.start()
	print("World created and started")

	# Get pathfinder
	var pf = world.get_pathfinder()
	print("Pathfinder: %s" % pf)

	# List all pf methods
	print("\n=== ALL PATHFINDER METHODS ===")
	for m in pf.get_method_list():
		if not m.name.begins_with("_") and m.name not in ["init_ref","reference","unreference","get_reference_count","free","get_class","is_class","set","get","set_indexed","get_indexed","get_property_list","get_method_list","property_can_revert","property_get_revert","notification","to_string","get_instance_id","set_script","get_script","set_meta","remove_meta","get_meta","has_meta","get_meta_list","add_user_signal","has_user_signal","emit_signal","has_signal","get_signal_list","get_signal_connection_list","get_incoming_connections","connect","disconnect","is_connected","has_connections","set_block_signals","is_blocking_signals","notify_property_list_changed","set_message_translation","can_translate_messages","tr","tr_n","get_translation_domain","set_translation_domain","is_queued_for_deletion","cancel_free"]:
			print("  %s (args: %d)" % [m.name, m.args.size()])

	# Create GridMap manually
	print("\n=== CREATE GRIDMAP ===")
	var grid_factory = ClassDB.instantiate("ArboreusGridMap")
	print("GridMap factory: %s" % grid_factory)

	# List GridMap create/init methods
	print("\nGridMap create/init methods:")
	for m in grid_factory.get_method_list():
		if m.name.find("create") >= 0 or m.name.find("init") >= 0 or m.name.find("setup") >= 0:
			print("  %s (args: %d)" % [m.name, m.args.size()])

	# Try create with 3 args
	var grid = grid_factory.create(40, 19, 32)
	print("create(40, 19, 32) returned: %s" % grid)

	if grid != null:
		print("\nGridMap created!")
		print("  width: %s" % grid.get_width())
		print("  height: %s" % grid.get_height())
		print("  cell_size: %s" % grid.get_cell_size())
		print("  walkable_count: %s" % grid.get_walkable_count())

		# Set grid to pathfinder - try various method names
		print("\n=== SET GRID TO PATHFINDER ===")
		if pf.has_method("set_grid"):
			pf.set_grid(grid)
			print("set_grid(grid) called")
		elif pf.has_method("set_grid_map"):
			pf.set_grid_map(grid)
			print("set_grid_map(grid) called")
		elif pf.has_method("initialize"):
			pf.initialize(grid)
			print("initialize(grid) called")
		else:
			print("No set_grid method found!")

		# Test find_path
		print("\n=== TEST FIND_PATH ===")
		var path = pf.find_path(Vector2(0, 0), Vector2(10, 10))
		print("find_path((0,0), (10,10)): size=%d" % (path.size() if path else 0))
		if path and path.size() > 0:
			print("  First: %s, Last: %s" % [path[0], path[path.size()-1]])
			print("  SUCCESS!")

		# Test find_path_world
		if pf.has_method("find_path_world"):
			var path_world = pf.find_path_world(Vector2(100, 100), Vector2(500, 400))
			print("find_path_world((100,100), (500,400)): size=%d" % (path_world.size() if path_world else 0))
			if path_world and path_world.size() > 0:
				print("  First: %s, Last: %s" % [path_world[0], path_world[path_world.size()-1]])
				print("  SUCCESS with world coords!")
	else:
		print("FAILED to create GridMap")

	world.stop()
	print("\n=== TEST COMPLETE ===")
	quit(0)
