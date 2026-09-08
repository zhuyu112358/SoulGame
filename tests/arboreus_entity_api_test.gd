extends SceneTree

# ArboreusEntity API exploration test

func _initialize():
	print("=== ARBOREUS ENTITY API EXPLORATION ===")

	for i in range(30):
		await process_frame

	var world = ClassDB.instantiate("ArboreusWorld")
	var config = {"name": "test", "width": 1280, "height": 600, "cell_size": 32}
	world = world.create(config)
	world.start()
	print("World created and started")

	# Create entity
	print("\n=== CREATE ENTITY ===")
	var entity = world.create_entity()
	print("Entity: %s" % entity)
	print("Entity class: %s" % entity.get_class())

	# List all entity methods
	print("\n=== ENTITY METHODS ===")
	var methods = entity.get_method_list()
	for m in methods:
		if not m.name.begins_with("_") and m.name not in ["get","set","notification","get_property_list","get_method_list","has_method","has_signal","get_signal_list","connect","disconnect","emit_signal","call","call_deferred","set_deferred","to_string","init_ref","unreference","reference","unref","get_instance_id","set_script","get_script","get_class","is_class"]:
			print("  %s" % m.name)

	# List entity properties
	print("\n=== ENTITY PROPERTIES ===")
	var props = entity.get_property_list()
	for p in props:
		if not p.name.begins_with("_") and p.name not in ["script","instance_id","process_mode","process_priority"]:
			print("  %s (%s)" % [p.name, p.type])

	# Try common position methods
	print("\n=== TRY POSITION METHODS ===")
	var pos_methods = ["set_position", "set_pos", "set_location", "set_transform", "set_global_position", "position", "pos", "location"]
	for method in pos_methods:
		if entity.has_method(method):
			print("  HAS METHOD: %s" % method)
			# Try calling with Vector2
			var result = entity.call(method, Vector2(100, 200))
			print("    %s(Vector2(100,200)) -> %s" % [method, result])

	# Try get position methods
	print("\n=== TRY GET POSITION METHODS ===")
	var get_methods = ["get_position", "get_pos", "get_location", "get_transform", "get_global_position"]
	for method in get_methods:
		if entity.has_method(method):
			print("  HAS METHOD: %s" % method)
			var result = entity.call(method)
			print("    %s() -> %s" % [method, result])

	# Try set_name/get_name
	print("\n=== TRY NAME METHODS ===")
	if entity.has_method("set_name"):
		entity.set_name("player_soul")
		print("  set_name('player_soul') done")
	if entity.has_method("get_name"):
		print("  get_name() -> %s" % entity.get_name())

	# Try update entity
	print("\n=== TRY ENTITY UPDATE ===")
	if entity.has_method("update"):
		entity.update(0.016)
		print("  entity.update(0.016) done")

	# Test remove_entity with different arg types
	print("\n=== TEST remove_entity PARAMETERS ===")
	var entity2 = world.create_entity()
	print("  Created entity2: %s" % entity2)

	# Try with entity object
	print("  Trying remove_entity(entity_object)...")
	var world2 = ClassDB.instantiate("ArboreusWorld")
	world2 = world2.create(config)
	world2.start()
	var e3 = world2.create_entity()
	var removed = false
	match "object":
		"object":
			removed = world2.remove_entity(e3)
	print("  remove_entity(object) -> %s" % removed)

	# Try with int
	print("  Trying remove_entity(int=0)...")
	var world3 = ClassDB.instantiate("ArboreusWorld")
	world3 = world3.create(config)
	world3.start()
	var e4 = world3.create_entity()
	var removed_int = false
	removed_int = world3.remove_entity(0)
	print("  remove_entity(int=0) -> %s" % removed_int)

	# Try with string
	print("  Trying remove_entity(string)...")
	var world4 = ClassDB.instantiate("ArboreusWorld")
	world4 = world4.create(config)
	world4.start()
	var e5 = world4.create_entity()
	var removed_str = false
	removed_str = world4.remove_entity("entity")
	print("  remove_entity(string) -> %s" % removed_str)

	# Cleanup
	world.stop()
	print("\n=== TEST COMPLETE ===")
	quit(0)
