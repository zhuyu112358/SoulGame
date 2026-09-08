extends SceneTree

# Detailed debug test for ArboreusPathfinder

func _initialize():
	print("=== ARBOREUS PATHFINDER DEBUG TEST ===")

	for i in range(60):
		await process_frame

	var grid_factory = ClassDB.instantiate("ArboreusGridMap")
	var grid = grid_factory.create(10, 10, 1.0)  # Small grid, cell_size=1 for easy debugging

	print("Grid: %dx%d, cell_size=%s" % [grid.get_width(), grid.get_height(), grid.get_cell_size()])

	# No obstacles, simple path from (0,0) to (5,5)
	var pf = ClassDB.instantiate("ArboreusPathfinder")
	pf.set_grid(grid)
	pf.set_allow_diagonal(true)

	print("\n=== TEST 1: Simple path (0,0) to (5,5), no obstacles ===")
	var path1 = pf.find_path(Vector2i(0, 0), Vector2i(5, 5))
	print("Path length: %d" % path1.size())
	for i in range(path1.size()):
		print("  [%d] %s (type: %s)" % [i, path1[i], path1[i].get_class() if path1[i] is Object else typeof(path1[i])])

	# Test with integer coordinates
	print("\n=== TEST 2: Path with int coords ===")
	var path2 = pf.find_path(Vector2i(0, 0), Vector2i(9, 9))
	print("Path length: %d" % path2.size())
	if path2.size() > 0:
		print("  First: %s, Last: %s" % [path2[0], path2[path2.size()-1]])

	# Test with obstacles
	print("\n=== TEST 3: Path with obstacle wall ===")
	var grid2 = grid_factory.create(10, 10, 1.0)
	for y in range(0, 10):
		grid2.set_walkable(5, y, false)
	print("Wall at x=5, all y")

	var pf2 = ClassDB.instantiate("ArboreusPathfinder")
	pf2.set_grid(grid2)
	pf2.set_allow_diagonal(true)

	var path3 = pf2.find_path(Vector2i(2, 5), Vector2i(8, 5))
	print("Path (2,5)->(8,5) length: %d" % path3.size())
	if path3.size() > 0:
		for i in range(path3.size()):
			var p = path3[i]
			print("  [%d] %s" % [i, p])

	# Check if set_walkable works
	print("\n=== TEST 4: Verify set_walkable ===")
	var grid3 = grid_factory.create(10, 10, 1.0)
	print("Before block - is_walkable(5,5): %s" % grid3.is_walkable(5, 5))
	grid3.set_walkable(5, 5, false)
	print("After block - is_walkable(5,5): %s" % grid3.is_walkable(5, 5))
	grid3.set_walkable(5, 5, true)
	print("After unblock - is_walkable(5,5): %s" % grid3.is_walkable(5, 5))

	# Test get_path_length
	print("\n=== TEST 5: get_path_length ===")
	if path1.size() > 0:
		var len = pf.get_path_length(path1)
		print("Path1 length: %s" % len)

	# List all Pathfinder methods again to verify
	print("\n=== PATHFINDER METHODS (custom only) ===")
	var methods = pf.get_method_list()
	for m in methods:
		if not m.name.begins_with("_") and m.name not in ["init_ref","reference","unreference","get_reference_count","free","get_class","is_class","set","get","set_indexed","get_indexed","get_property_list","get_method_list","property_can_revert","property_get_revert","notification","to_string","get_instance_id","set_script","get_script","set_meta","remove_meta","get_meta","has_meta","get_meta_list","add_user_signal","has_user_signal","emit_signal","has_signal","get_signal_list","get_signal_connection_list","get_incoming_connections","connect","disconnect","is_connected","has_connections","set_block_signals","is_blocking_signals","notify_property_list_changed","set_message_translation","can_translate_messages","tr","tr_n","get_translation_domain","set_translation_domain","is_queued_for_deletion","cancel_free"]:
			print("  %s (args: %d)" % [m.name, m.args.size()])

	print("\n=== DEBUG TEST COMPLETE ===")
	quit(0)
