extends SceneTree

# Isolated test for ArboreusPathfinder with battle-like scenario

func _initialize():
	print("=== ARBOREUS PATHFINDER BATTLE SCENARIO TEST ===")

	for i in range(60):
		await process_frame

	var grid_factory = ClassDB.instantiate("ArboreusGridMap")
	var grid = grid_factory.create(40, 19, 32.0)
	print("Grid: %dx%d, cell_size=%s" % [grid.get_width(), grid.get_height(), grid.get_cell_size()])

	# Add obstacles like default_arena (center crystal at 640,300 size 45x45)
	# Convert to grid cells: 640/32=20, 300/32=9, size 45/32=1.4 -> 2 cells
	print("\n=== Adding obstacles ===")
	# Center crystal (640,300) size 45x45 -> grid (20,9) 2x2
	for cx in range(19, 22):
		for cy in range(8, 11):
			grid.set_walkable(cx, cy, false)
			print("  Blocked (%d,%d)" % [cx, cy])

	print("  is_walkable(33,9) (start): %s" % grid.is_walkable(33, 9))
	print("  is_walkable(6,9) (goal): %s" % grid.is_walkable(6, 9))
	print("  is_walkable(20,9) (crystal): %s" % grid.is_walkable(20, 9))

	# Create pathfinder
	var pf = ClassDB.instantiate("ArboreusPathfinder")
	pf.set_grid(grid)
	pf.set_allow_diagonal(true)

	# Find path from (33,9) to (6,9) - should go around center crystal
	print("\n=== Finding path (33,9) -> (6,9) ===")
	var path = pf.find_path(Vector2(33, 9), Vector2(6, 9))
	print("Path length: %d" % path.size())
	for i in range(path.size()):
		var p = path[i]
		print("  [%d] (%.1f, %.1f) -> grid (%d,%d)" % [i, p.x, p.y, int(p.x/32), int(p.y/32)])

	if path.size() > 0:
		print("  First: %s" % path[0])
		print("  Last: %s" % path[path.size()-1])

	# Test without obstacles
	print("\n=== Test without obstacles ===")
	var grid2 = grid_factory.create(40, 19, 32.0)
	var pf2 = ClassDB.instantiate("ArboreusPathfinder")
	pf2.set_grid(grid2)
	pf2.set_allow_diagonal(true)
	var path2 = pf2.find_path(Vector2(33, 9), Vector2(6, 9))
	print("Path length (no obstacles): %d" % path2.size())
	if path2.size() > 0:
		print("  First: %s" % path2[0])
		print("  Last: %s" % path2[path2.size()-1])
		for i in range(min(5, path2.size())):
			print("  [%d] %s" % [i, path2[i]])

	# Test simple small grid
	print("\n=== Test small grid (0,0)->(5,5) ===")
	var grid3 = grid_factory.create(10, 10, 1.0)
	var pf3 = ClassDB.instantiate("ArboreusPathfinder")
	pf3.set_grid(grid3)
	pf3.set_allow_diagonal(true)
	var path3 = pf3.find_path(Vector2(0, 0), Vector2(5, 5))
	print("Path length: %d" % path3.size())
	for i in range(path3.size()):
		print("  [%d] %s" % [i, path3[i]])

	print("\n=== TEST COMPLETE ===")
	quit(0)
