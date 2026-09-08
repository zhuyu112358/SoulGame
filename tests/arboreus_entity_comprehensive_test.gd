extends SceneTree

# Comprehensive ArboreusEntity position/API exploration

func _initialize():
	print("=== ARBOREUS ENTITY COMPREHENSIVE API EXPLORATION ===")

	for i in range(30):
		await process_frame

	var world = ClassDB.instantiate("ArboreusWorld")
	var config = {"name": "test", "width": 1280, "height": 600, "cell_size": 32}
	world = world.create(config)
	world.start()
	print("World created and started")

	# Create entity
	var entity = world.create_entity()
	print("\n=== ENTITY: %s ===" % entity)

	# List ALL properties including hidden
	print("\n=== ALL ENTITY PROPERTIES ===")
	var props = entity.get_property_list()
	for p in props:
		print("  %s (type=%d, class=%s)" % [p.name, p.type, p.class_name if p.has("class_name") else ""])

	# List ALL methods including hidden
	print("\n=== ALL ENTITY METHODS ===")
	var methods = entity.get_method_list()
	for m in methods:
		if not m.name.begins_with("__"):
			print("  %s (args=%d)" % [m.name, m.args.size() if m.has("args") else -1])

	# Try common component names
	print("\n=== TRY COMPONENTS ===")
	var comp_names = ["transform", "position", "spatial", "movement", "physics", "render", "health", "stats", "ai", "soul"]
	for comp in comp_names:
		var has = entity.has_component(comp)
		print("  has_component('%s'): %s" % [comp, has])

	# Try to find add_component method (maybe it's named differently)
	print("\n=== TRY ADD COMPONENT METHODS ===")
	var add_methods = ["add_component", "attach_component", "register_component", "create_component", "set_component"]
	for method in add_methods:
		if entity.has_method(method):
			print("  FOUND: %s" % method)
		else:
			print("  not found: %s" % method)

	# Explore ArboreusWorld methods for entity position
	print("\n=== ARBOREUSWORLD ENTITY-RELATED METHODS ===")
	var world_methods = world.get_method_list()
	for m in world_methods:
		if not m.name.begins_with("_") and m.name.find("entity") >= 0:
			print("  %s" % m.name)

	# Explore ArboreusMovementSystem
	print("\n=== MOVEMENT SYSTEM ===")
	var move_sys = world.get_movement_system()
	print("MovementSystem: %s" % move_sys)
	if move_sys != null:
		print("MovementSystem methods:")
		var move_methods = move_sys.get_method_list()
		for m in move_methods:
			if not m.name.begins_with("_") and m.name not in ["get","set","notification","get_property_list","get_method_list","has_method","has_signal","get_signal_list","connect","disconnect","emit_signal","call","call_deferred","set_deferred","to_string","init_ref","unreference","reference","unref","get_instance_id","set_script","get_script","get_class","is_class"]:
				print("  %s" % m.name)

	# Explore ArboreusPhysicsSystem
	print("\n=== PHYSICS SYSTEM ===")
	var phys_sys = world.get_physics_system()
	print("PhysicsSystem: %s" % phys_sys)
	if phys_sys != null:
		print("PhysicsSystem methods:")
		var phys_methods = phys_sys.get_method_list()
		for m in phys_methods:
			if not m.name.begins_with("_") and m.name not in ["get","set","notification","get_property_list","get_method_list","has_method","has_signal","get_signal_list","connect","disconnect","emit_signal","call","call_deferred","set_deferred","to_string","init_ref","unreference","reference","unref","get_instance_id","set_script","get_script","get_class","is_class"]:
				print("  %s" % m.name)

	# Explore ArboreusSpatialIndex
	print("\n=== SPATIAL INDEX ===")
	if world.has_method("get_spatial_index"):
		var spatial = world.get_spatial_index()
		print("SpatialIndex: %s" % spatial)
		if spatial != null:
			print("SpatialIndex methods:")
			var spatial_methods = spatial.get_method_list()
			for m in spatial_methods:
				if not m.name.begins_with("_") and m.name not in ["get","set","notification","get_property_list","get_method_list","has_method","has_signal","get_signal_list","connect","disconnect","emit_signal","call","call_deferred","set_deferred","to_string","init_ref","unreference","reference","unref","get_instance_id","set_script","get_script","get_class","is_class"]:
					print("  %s" % m.name)

	# Cleanup
	world.stop()
	print("\n=== TEST COMPLETE ===")
	quit(0)
