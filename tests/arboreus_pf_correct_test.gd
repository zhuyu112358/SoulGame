extends SceneTree

# Correct functional test for ArboreusPathfinder with proper GridMap initialization

func _initialize():
	print("=== ARBOREUS PATHFINDER CORRECT TEST ===")

	for i in range(60):
		await process_frame

	# Step 1: Create ArboreusGridMap factory
	var grid_factory = ClassDB.instantiate("ArboreusGridMap")
	print("GridMap factory created: %s" % grid_factory)

	# Step 2: Create actual grid using create(width, height, cell_size)
	var grid = grid_factory.create(40, 19, 32.0)
	print("Grid created: %s" % grid)

	if grid:
		print("  width: %s" % grid.get_width())
		print("  height: %s" % grid.get_height())
		print("  cell_size: %s" % grid.get_cell_size())
		print("  is_walkable(5,5): %s" % grid.is_walkable(5, 5))

		# Mark some cells as blocked (obstacles)
		grid.set_walkable(20, 9, false)
		grid.set_walkable(20, 10, false)
		grid.set_walkable(21, 9, false)
		grid.set_walkable(21, 10, false)
		print("  Blocked center 2x2 area")
		print("  is_walkable(20,9) after block: %s" % grid.is_walkable(20, 9))

		# Test coordinate conversion
		var world_pos = grid.grid_to_world(Vector2i(3, 4))
		print("  grid_to_world(3,4): %s" % world_pos)
		var grid_pos = grid.world_to_grid(world_pos)
		print("  world_to_grid back: %s" % grid_pos)

	# Step 3: Create ArboreusPathfinder and set grid
	var pf = ClassDB.instantiate("ArboreusPathfinder")
	print("\nPathfinder created: %s" % pf)

	pf.set_grid(grid)
	pf.set_allow_diagonal(true)
	print("Grid set, diagonal enabled")

	# Step 4: Find path from (0,0) to (39, 18) - should go around blocked center
	var start = Vector2i(0, 0)
	var goal = Vector2i(39, 18)
	var path = pf.find_path(start, goal)
	print("\nfind_path(%s, %s):" % [start, goal])
	print("  Path length: %d" % path.size())

	if path.size() > 0:
		print("  First point: %s" % path[0])
		print("  Last point: %s" % path[path.size()-1])
		print("  Path points (first 5):")
		for i in range(min(5, path.size())):
			print("    [%d] %s" % [i, path[i]])

		# Check if path goes through blocked cells
		var goes_through_blocked = false
		for p in path:
			if not grid.is_walkable(p.x, p.y):
				goes_through_blocked = true
				print("  WARNING: Path goes through blocked cell %s!" % p)
		if not goes_through_blocked:
			print("  [OK] Path does not go through blocked cells")

		# Test smooth_path
		var smoothed = pf.smooth_path(path)
		print("  Smoothed path length: %d" % smoothed.size())
	else:
		print("  [FAIL] No path found!")

	# Step 5: Test path around a wall
	print("\n=== TEST PATH AROUND WALL ===")
	var grid2 = grid_factory.create(20, 20, 1.0)
	# Create a vertical wall at x=10 from y=0 to y=15
	for y in range(0, 16):
		grid2.set_walkable(10, y, false)
	print("Created vertical wall at x=10, y=0..15")

	var pf2 = ClassDB.instantiate("ArboreusPathfinder")
	pf2.set_grid(grid2)
	pf2.set_allow_diagonal(true)

	var path2 = pf2.find_path(Vector2i(5, 10), Vector2i(15, 10))
	print("Path from (5,10) to (15,10) around wall:")
	print("  Length: %d" % path2.size())
	if path2.size() > 0:
		print("  First: %s, Last: %s" % [path2[0], path2[path2.size()-1]])
		# Check if path goes around wall (should have y > 15 or y < 0 at some point)
		var goes_around = false
		for p in path2:
			if p.y > 15:
				goes_around = true
		print("  Goes around wall: %s" % goes_around)
	else:
		print("  [FAIL] No path found around wall!")

	print("\n=== TEST COMPLETE ===")
	quit(0)
