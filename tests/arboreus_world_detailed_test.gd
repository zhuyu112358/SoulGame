extends SceneTree

# ArboreusWorld API exploration - conservative parameter testing

func _initialize():
	print("=== ARBOREUS WORLD API EXPLORATION (CONSERVATIVE) ===")

	for i in range(30):
		await process_frame

	if not ClassDB.class_exists("ArboreusWorld"):
		print("ArboreusWorld class NOT found")
		quit(1)
		return

	var world = ClassDB.instantiate("ArboreusWorld")
	if world == null:
		print("Failed to instantiate ArboreusWorld")
		quit(1)
		return

	print("Created: %s" % world)

	# Test create() with different argument types
	print("\n=== TEST create() ===")
	var create_success = false
	var test_args = [
		{"name": "String", "value": "test_world"},
		{"name": "Dictionary", "value": {"name": "test", "width": 1280, "height": 600}},
		{"name": "int", "value": 1},
		{"name": "Vector2", "value": Vector2(1280, 600)},
	]
	for arg in test_args:
		print("  Trying create(%s)..." % arg.name)
		var world2 = ClassDB.instantiate("ArboreusWorld")
		if world2 != null:
			var result = null
			match arg.name:
				"String":
					result = world2.create("test_world")
				"Dictionary":
					result = world2.create({"name": "test", "width": 1280, "height": 600})
				"int":
					result = world2.create(1)
				"Vector2":
					result = world2.create(Vector2(1280, 600))
			print("    Result: %s" % result)
			if result != null or result == true:
				print("    SUCCESS with %s!" % arg.name)
				create_success = true
				world = world2
				break

	if not create_success:
		print("  create() failed with all tested types")

	# Test start()
	print("\n=== TEST start() ===")
	if world.has_method("start"):
		world.start()
		print("  start() called")

	# Test create_entity with different args
	print("\n=== TEST create_entity() ===")
	if world.has_method("create_entity"):
		var entity = null
		# Try 1 arg (name)
		print("  Trying create_entity(name)...")
		entity = world.create_entity("test_soul")
		if entity != null:
			print("  SUCCESS! Entity: %s" % entity)
			# List entity methods
			print("  Entity methods:")
			var methods = entity.get_method_list()
			for m in methods:
				if not m.name.begins_with("_") and m.name not in ["get","set","notification","get_property_list","get_method_list","has_method","has_signal","get_signal_list","connect","disconnect","emit_signal","call","call_deferred","set_deferred","to_string","init_ref","unreference","reference","unref","get_instance_id","set_script","get_script","get_class","is_class"]:
					print("    %s" % m.name)
		else:
			print("  create_entity(name) returned null")

	# Test get_entity_count
	print("\n=== TEST get_entity_count() ===")
	if world.has_method("get_entity_count"):
		print("  Count: %s" % world.get_entity_count())

	# Test update
	print("\n=== TEST update() ===")
	if world.has_method("update"):
		world.update(0.016)
		print("  update(0.016) called")

	# Test get_subsystems
	print("\n=== TEST SUBSYSTEMS ===")
	for subsystem in ["get_grid_map", "get_pathfinder", "get_physics_system", "get_movement_system", "get_event_bus", "get_world_clock"]:
		if world.has_method(subsystem):
			var obj = world.call(subsystem)
			print("  %s(): %s" % [subsystem, obj])

	# Test get_status
	print("\n=== TEST get_status() ===")
	if world.has_method("get_status"):
		print("  Status: %s" % world.get_status())

	# Cleanup
	print("\n=== CLEANUP ===")
	if world.has_method("stop"):
		world.stop()
		print("  stop() called")

	print("\n=== TEST COMPLETE ===")
	quit(0)
