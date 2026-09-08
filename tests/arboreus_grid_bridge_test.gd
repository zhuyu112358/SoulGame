extends SceneTree

# ArboreusGridMapBridge test

func _initialize():
	print("=== ARBOREUS GRIDMAP BRIDGE TEST ===")

	for i in range(30):
		await process_frame

	# Import the bridge
	var Bridge = load("res://scripts/game/ArboreusGridMapBridge.gd")
	if Bridge == null:
		print("FAILED: Could not load ArboreusGridMapBridge")
		quit(1)
		return

	# Create bridge instance
	var grid = Bridge.new(32.0, 40, 19, 0.0, 0.0, true)
	print("Created bridge: %s" % grid)
	print("Arboreus available: %s" % grid.is_arboreus_available())

	# Test coordinate conversion
	print("\n=== Coordinate Conversion ===")
	var world_pos = Vector2(100, 200)
	var cell_x = grid.world_to_cell_x(world_pos.x)
	var cell_y = grid.world_to_cell_y(world_pos.y)
	print("World (100,200) -> Cell (%d,%d)" % [cell_x, cell_y])

	var back_x = grid.cell_to_world_x(cell_x)
	var back_y = grid.cell_to_world_y(cell_y)
	print("Cell (%d,%d) -> World (%.1f,%.1f)" % [cell_x, cell_y, back_x, back_y])

	# Test walkability
	print("\n=== Walkability ===")
	var walkable = grid.is_walkable(100, 200)
	print("is_walkable(100,200): %s" % walkable)

	# Test set_cell
	print("\n=== Set Cell ===")
	grid.set_cell(5, 5, true)  # Block cell (5,5)
	var blocked_walkable = grid.is_walkable(grid.cell_to_world_x(5), grid.cell_to_world_y(5))
	print("After set_cell(5,5,blocked), is_walkable: %s" % blocked_walkable)

	grid.set_cell(5, 5, false)  # Unblock
	var unblocked_walkable = grid.is_walkable(grid.cell_to_world_x(5), grid.cell_to_world_y(5))
	print("After set_cell(5,5,unblocked), is_walkable: %s" % unblocked_walkable)

	# Test block_region
	print("\n=== Block Region ===")
	grid.block_region(100, 100, 200, 200)
	var region_walkable = grid.is_walkable(150, 150)
	print("After block_region(100,100,200,200), is_walkable(150,150): %s" % region_walkable)

	# Test neighbors
	print("\n=== Neighbors ===")
	var neighbors = grid.get_neighbors(10, 10)
	print("get_neighbors(10,10): %d neighbors" % neighbors.size())

	# Test in_bounds
	print("\n=== In Bounds ===")
	print("in_bounds(0,0): %s" % grid.in_bounds(0, 0))
	print("in_bounds(39,18): %s" % grid.in_bounds(39, 18))
	print("in_bounds(40,19): %s" % grid.in_bounds(40, 19))
	print("in_bounds(-1,0): %s" % grid.in_bounds(-1, 0))

	# Test clear
	print("\n=== Clear ===")
	grid.clear()
	var cleared_walkable = grid.is_walkable(150, 150)
	print("After clear(), is_walkable(150,150): %s" % cleared_walkable)

	print("\n=== TEST COMPLETE ===")
	quit(0)
