extends SceneTree

# Correct functional test for ArboreusPathfinder via ArboreusWorld

func _initialize():
	print("=== ARBOREUS PATHFINDER CORRECT TEST ===")

	for i in range(30):
		await process_frame

	# Create ArboreusWorld (this properly initializes GridMap and Pathfinder)
	var world_factory = ClassDB.instantiate("ArboreusWorld")
	var config = {"name": "pf_test", "width": 1280, "height": 608, "cell_size": 32}
	var world = world_factory.create(config)
	world.start()
	print("World created and started")

	# Get pathfinder from world
	var pf = world.get_pathfinder()
	print("Pathfinder from world: %s" % pf)

	if pf == null:
		print("ERROR: Pathfinder is null!")
		quit(1)
		return

	# Check Pathfinder methods
	print("\n=== PATHFINDER METHODS ===")
	var pf_methods = pf.get_method_list()
	for m in pf_methods:
		if not m.name.begins_with("_") and m.name not in ["init_ref","reference","unreference","get_reference_count","free","get_class","is_class","set","get","set_indexed","get_indexed","get_property_list","get_method_list","property_can_revert","property_get_revert","notification","to_string","get_instance_id","set_script","get_script","set_meta","remove_meta","get_meta","has_meta","get_meta_list","add_user_signal","has_user_signal","emit_signal","has_signal","get_signal_list","get_signal_connection_list","get_incoming_connections","connect","disconnect","is_connected","has_connections","set_block_signals","is_blocking_signals","notify_property_list_changed","set_message_translation","can_translate_messages","tr","tr_n","get_translation_domain","set_translation_domain","is_queued_for_deletion","cancel_free"]:
			print("  %s (args: %d)" % [m.name, m.args.size()])

	# Get grid map from world
	var grid = world.get_grid_map()
	print("\nGridMap from world: %s" % grid)

	if grid != null:
		print("GridMap width: %s" % grid.get_width())
		print("GridMap height: %s" % grid.get_height())
		print("GridMap cell_size: %s" % grid.get_cell_size())
		print("GridMap walkable count: %s" % grid.get_walkable_count())

	# Test find_path with world coordinates
	print("\n=== TEST FIND_PATH (world coords) ===")
	var start_world = Vector2(100, 100)
	var goal_world = Vector2(500, 400)

	if pf.has_method("find_path"):
		var path = pf.find_path(start_world, goal_world)
		print("find_path(%s, %s) returned: %s" % [start_world, goal_world, path])
		if path and path.size() > 0:
			print("Path size: %d" % path.size())
			print("First point: %s" % path[0])
			print("Last point: %s" % path[path.size()-1])
			print("SUCCESS: Path found!")
		else:
			print("EMPTY PATH - trying grid coords...")

	# Test find_path with grid coordinates
	print("\n=== TEST FIND_PATH (grid coords) ===")
	var start_grid = Vector2i(3, 3)
	var goal_grid = Vector2i(15, 12)

	if pf.has_method("find_path"):
		var path2 = pf.find_path(start_grid, goal_grid)
		print("find_path(%s, %s) returned: %s" % [start_grid, goal_grid, path2])
		if path2 and path2.size() > 0:
			print("Path size: %d" % path2.size())
			print("First point: %s" % path2[0])
			print("Last point: %s" % path2[path2.size()-1])
			print("SUCCESS: Path found with grid coords!")
		else:
			print("EMPTY PATH with grid coords too")

	# Test with obstacles
	print("\n=== TEST FIND_PATH WITH OBSTACLE ===")
	if grid != null:
		# Block some cells
		for x in range(5, 10):
			for y in range(5, 10):
				grid.set_walkable(x, y, false)
		print("Blocked 5x5 area at (5,5)-(9,9)")
		print("Walkable count after block: %s" % grid.get_walkable_count())

		# Find path around obstacle
		var path3 = pf.find_path(Vector2(100, 100), Vector2(500, 400))
		print("find_path around obstacle: size=%d" % (path3.size() if path3 else 0))
		if path3 and path3.size() > 0:
			print("First: %s, Last: %s" % [path3[0], path3[path3.size()-1]])
			print("SUCCESS: Path found around obstacle!")

	world.stop()
	print("\n=== TEST COMPLETE ===")
	quit(0)
