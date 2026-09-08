extends SceneTree

# Arboreus API detailed exploration - no filtering

func _initialize():
	print("=== ARBOREUS DETAILED API EXPLORATION ===")

	for i in range(30):
		await process_frame

	var classes_to_explore = [
		"ArboreusWorld",
		"ArboreusGridMap",
		"ArboreusPhysicsSystem",
		"ArboreusEntity"
	]

	for cls_name in classes_to_explore:
		print("\n=== %s ===" % cls_name)
		if not ClassDB.class_exists(cls_name):
			print("  CLASS NOT FOUND")
			continue

		var obj = ClassDB.instantiate(cls_name)
		if obj == null:
			print("  FAILED TO INSTANTIATE")
			continue

		print("  Created: %s" % obj)

		# List ALL methods (no filtering)
		print("  All Methods (%d):" % obj.get_method_list().size())
		var methods = obj.get_method_list()
		for m in methods:
			print("    %s" % m.name)

		# List ALL properties
		print("  All Properties (%d):" % obj.get_property_list().size())
		var props = obj.get_property_list()
		for p in props:
			print("    %s (type: %d)" % [p.name, p.type])

		# Try common method calls
		print("  Trying common methods...")
		var common_methods = ["update", "tick", "initialize", "setup", "add_entity", "remove_entity", "get_entity", "get_entities", "set_size", "get_size", "set_cell", "get_cell", "is_walkable", "set_walkable", "move_entity", "check_collision", "get_position", "set_position"]
		for method_name in common_methods:
			if obj.has_method(method_name):
				print("    HAS METHOD: %s" % method_name)

	print("\n=== TEST COMPLETE ===")
	quit(0)
