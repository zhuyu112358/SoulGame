extends SceneTree

# ArboreusWorld simple test - direct Dictionary create

func _initialize():
	print("=== ARBOREUS WORLD SIMPLE TEST ===")

	for i in range(30):
		await process_frame

	var world = ClassDB.instantiate("ArboreusWorld")
	print("Created: %s" % world)

	# create() with Dictionary
	print("\n=== create(Dictionary) ===")
	var config = {
		"name": "rts_arena",
		"width": 1280,
		"height": 600,
		"cell_size": 32
	}
	var result = world.create(config)
	print("create() result: %s" % result)

	# start()
	print("\n=== start() ===")
	world.start()
	print("start() done")

	# create_entity with 1 arg
	print("\n=== create_entity(name) ===")
	var entity = world.create_entity("player_soul")
	print("Entity: %s" % entity)
	if entity != null:
		print("Entity methods:")
		var methods = entity.get_method_list()
		for m in methods:
			if not m.name.begins_with("_") and m.name not in ["get","set","notification","get_property_list","get_method_list","has_method","has_signal","get_signal_list","connect","disconnect","emit_signal","call","call_deferred","set_deferred","to_string","init_ref","unreference","reference","unref","get_instance_id","set_script","get_script","get_class","is_class"]:
				print("  %s" % m.name)

	# get_entity_count
	print("\n=== get_entity_count() ===")
	print("Count: %s" % world.get_entity_count())

	# update
	print("\n=== update(0.016) ===")
	world.update(0.016)
	print("update done")

	# subsystems
	print("\n=== SUBSYSTEMS ===")
	for ss in ["get_grid_map", "get_pathfinder", "get_physics_system", "get_movement_system", "get_event_bus", "get_world_clock"]:
		if world.has_method(ss):
			var obj = world.call(ss)
			print("  %s: %s" % [ss, obj])

	# get_status
	print("\n=== get_status() ===")
	print("Status: %s" % world.get_status())

	# cleanup
	world.stop()
	print("\n=== TEST COMPLETE ===")
	quit(0)
