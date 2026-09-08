extends SceneTree

# Arboreus World/GridMap/Physics API exploration test

func _initialize():
	print("=== ARBOREUS WORLD/GRIDMAP/PHYSICS API EXPLORATION ===")

	for i in range(30):
		await process_frame

	# Explore each class
	var classes_to_explore = [
		"ArboreusWorld",
		"ArboreusGridMap",
		"ArboreusPhysicsSystem",
		"ArboreusEntity",
		"ArboreusWorldClock",
		"ArboreusWeatherSystem"
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

		# List methods
		print("  Methods:")
		var methods = obj.get_method_list()
		for m in methods:
			var n = m.name
			if not n.begins_with("_") and n not in ["get","set","notification","get_property_list","get_method_list","has_method","has_signal","get_signal_list","connect","disconnect","emit_signal","call","call_deferred","set_deferred","to_string","init_ref","unreference","reference","unref","get_instance_id","set_script","get_script","get_class","is_class"]:
				print("    %s" % n)

		# List properties
		print("  Properties:")
		var props = obj.get_property_list()
		for p in props:
			if not p.name.begins_with("_") and p.name not in ["script","resource_path","resource_local_to_scene","resource_name"]:
				var val = obj.get(p.name)
				print("    %s = %s" % [p.name, val])

	print("\n=== TEST COMPLETE ===")
	quit(0)
