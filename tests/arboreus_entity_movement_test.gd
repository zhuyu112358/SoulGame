extends SceneTree

# Test ArboreusEntity component system and MovementSystem position

func _initialize():
	print("=== ARBOREUS ENTITY COMPONENT + MOVEMENT TEST ===")

	for i in range(30):
		await process_frame

	var world = ClassDB.instantiate("ArboreusWorld")
	var config = {"name": "test", "width": 1280, "height": 600, "cell_size": 32}
	world = world.create(config)
	world.start()
	print("World created and started")

	# Get movement system
	var move_sys = world.get_movement_system()
	print("\n=== MOVEMENT SYSTEM: %s ===" % move_sys)

	# Create entity
	var entity = world.create_entity()
	print("\n=== ENTITY: %s ===" % entity)

	# Test add_component with different args
	print("\n=== TEST add_component ===")
	# add_component returns void
	entity.add_component("transform", {"position": Vector2(100, 200)})
	print("add_component('transform', {position: Vector2(100,200)}) called")

	# Check component types
	print("\n=== get_component_types ===")
	var types = entity.get_component_types()
	print("Component types: %s" % types)

	# Check all components
	print("\n=== get_all_components ===")
	var comps = entity.get_all_components()
	print("All components: %s" % comps)

	# Test get_component
	print("\n=== get_component('transform') ===")
	var comp = entity.get_component("transform")
	print("Transform component: %s" % comp)

	# Test MovementSystem register_entity (needs 2 args, first might be int ID)
	print("\n=== TEST register_entity (int ID) ===")
	# Try int ID + position
	move_sys.register_entity(0, Vector2(150, 250))
	print("register_entity(0, Vector2(150,250)) called")

	# Test set_position with int ID
	print("\n=== TEST set_position (int ID) ===")
	move_sys.set_position(0, Vector2(200, 300))
	print("set_position(0, Vector2(200,300)) called")

	# Test get_position with int ID
	print("\n=== TEST get_position (int ID) ===")
	var pos = move_sys.get_position(0)
	print("get_position(0) -> %s" % pos)

	# Create second entity and test with ID 1
	print("\n=== SECOND ENTITY (ID 1) ===")
	var entity2 = world.create_entity()
	move_sys.register_entity(1, Vector2(500, 300))
	move_sys.set_position(1, Vector2(550, 350))
	var pos2 = move_sys.get_position(1)
	print("Entity2 position: %s" % pos2)

	# Test world status
	print("\n=== WORLD STATUS ===")
	var status = world.get_status()
	print("Status: %s" % status)

	# Cleanup
	world.stop()
	print("\n=== TEST COMPLETE ===")
	quit(0)
