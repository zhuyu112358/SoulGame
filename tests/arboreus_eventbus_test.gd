extends SceneTree

# Arboreus EventBus API exploration test (simplified)

func _initialize():
	print("=== ARBOREUS EVENTBUS API EXPLORATION ===")

	for i in range(30):
		await process_frame

	# List all Arboreus classes
	print("\n=== ALL ARBOREUS CLASSES ===")
	var all_classes = ClassDB.get_class_list()
	var arb_classes = []
	for c in all_classes:
		if c.begins_with("Arboreus"):
			arb_classes.append(c)
			print("  %s" % c)

	# Find EventBus class
	var eb_class = ""
	for c in arb_classes:
		if c.to_lower().find("event") >= 0 or c.to_lower().find("bus") >= 0 or c.to_lower().find("message") >= 0:
			eb_class = c
			print("\nFound EventBus-like class: %s" % c)

	if eb_class == "":
		print("\nNo EventBus class found in Arboreus SDK")
		print("Available classes: %s" % arb_classes)
		quit(0)
		return

	# Instantiate and explore
	print("\n=== EVENTBUS INSTANCE ===")
	var event_bus = ClassDB.instantiate(eb_class)
	if event_bus == null:
		print("Failed to instantiate %s" % eb_class)
		quit(0)
		return

	print("Created: %s" % event_bus)

	# List methods
	print("\nMethods:")
	var methods = event_bus.get_method_list()
	for m in methods:
		var n = m.name
		if not n.begins_with("_") and n not in ["get","set","notification","get_property_list","get_method_list","has_method","has_signal","get_signal_list","connect","disconnect","emit_signal","call","call_deferred","set_deferred","to_string","init_ref","unreference","reference","unref","get_instance_id","set_script","get_script","get_class","is_class","get","set","notification","get_property_list","get_method_list","has_method","has_signal","get_signal_list","connect","disconnect","emit_signal","call","call_deferred","set_deferred"]:
			print("  %s" % n)

	# List properties
	print("\nProperties:")
	var props = event_bus.get_property_list()
	for p in props:
		if not p.name.begins_with("_") and p.name not in ["script","resource_path","resource_local_to_scene","resource_name"]:
			print("  %s = %s" % [p.name, event_bus.get(p.name)])

	# Test basic subscribe/emit
	print("\n=== BASIC TEST ===")
	if event_bus.has_method("subscribe"):
		print("Has subscribe method")
	if event_bus.has_method("emit") or event_bus.has_method("publish"):
		print("Has emit/publish method")
	if event_bus.has_method("unsubscribe"):
		print("Has unsubscribe method")

	print("\n=== TEST COMPLETE ===")
	quit(0)
