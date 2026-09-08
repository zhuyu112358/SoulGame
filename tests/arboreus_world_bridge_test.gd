extends SceneTree

# ArboreusWorldBridge simple initialization test

func _initialize():
	print("=== ARBOREUS WORLD BRIDGE TEST ===")

	for i in range(30):
		await process_frame

	var Bridge = load("res://scripts/game/ArboreusWorldBridge.gd")
	if Bridge == null:
		print("FAILED: Could not load ArboreusWorldBridge")
		quit(1)
		return

	# Create bridge with config
	var config = {
		"name": "test_arena",
		"width": 1280,
		"height": 600,
		"cell_size": 32
	}
	var bridge = Bridge.new(config)
	print("Bridge created: %s" % bridge)
	print("Arboreus available: %s" % bridge.is_arboreus_available())

	# Start world
	print("\n=== start() ===")
	bridge.start()
	print("Is running: %s" % bridge.is_running())

	# Create entity
	print("\n=== create_entity() ===")
	var entity_id = bridge.create_entity("test_soul", Vector2(100, 200))
	print("Entity ID: %d" % entity_id)
	print("Entity count: %d" % bridge.get_entity_count())

	# Update
	print("\n=== update(0.016) ===")
	bridge.update(0.016)
	print("Update done")

	# Get status
	print("\n=== get_status() ===")
	var status = bridge.get_status()
	print("Status: %s" % status)

	# Get subsystems
	print("\n=== SUBSYSTEMS ===")
	print("GridMap: %s" % bridge.get_grid_map())
	print("Pathfinder: %s" % bridge.get_pathfinder())
	print("Physics: %s" % bridge.get_physics_system())

	# Remove entity
	print("\n=== remove_entity() ===")
	if entity_id >= 0:
		var removed = bridge.remove_entity(entity_id)
		print("Removed: %s" % removed)
		print("Entity count after remove: %d" % bridge.get_entity_count())

	# Stop
	print("\n=== stop() ===")
	bridge.stop()
	print("Is running: %s" % bridge.is_running())

	print("\n=== TEST COMPLETE ===")
	quit(0)
