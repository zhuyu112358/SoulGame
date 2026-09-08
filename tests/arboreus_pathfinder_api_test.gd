extends SceneTree

# Test Arboreus Pathfinder API

func _initialize():
	print("=== ARBOREUS PATHFINDER API TEST ===")

	for i in range(60):
		await process_frame

	# Instantiate ArboreusPathfinder
	if not ClassDB.class_exists("ArboreusPathfinder"):
		print("ERROR: ArboreusPathfinder not found")
		quit(1)
		return

	var pf = ClassDB.instantiate("ArboreusPathfinder")
	print("Pathfinder instantiated: %s" % pf)

	# List all methods
	var methods = pf.get_method_list()
	print("\n=== PATHFINDER METHODS ===")
	for m in methods:
		if not m.name.begins_with("_"):
			print("  %s (args: %d)" % [m.name, m.args.size()])
			for arg in m.args:
				print("    - %s: %s" % [arg.name, arg.type])

	# List properties
	var props = pf.get_property_list()
	print("\n=== PATHFINDER PROPERTIES ===")
	for p in props:
		if not p.name.begins_with("_") and p.type != 0:
			print("  %s: %s (default: %s)" % [p.name, p.type, p.default_value])

	# Test ArboreusGridMap
	print("\n=== ARBOREUS GRIDMAP ===")
	if ClassDB.class_exists("ArboreusGridMap"):
		var gm = ClassDB.instantiate("ArboreusGridMap")
		print("GridMap instantiated: %s" % gm)
		var gm_methods = gm.get_method_list()
		print("GridMap methods:")
		for m in gm_methods:
			if not m.name.begins_with("_"):
				print("  %s (args: %d)" % [m.name, m.args.size()])
	else:
		print("ArboreusGridMap not found")

	# Test Ember Soul API
	print("\n=== EMBER SOUL API ===")
	if ClassDB.class_exists("Soul"):
		var soul = ClassDB.instantiate("Soul")
		print("Soul instantiated: %s" % soul)
		var soul_methods = soul.get_method_list()
		print("Soul methods:")
		for m in soul_methods:
			if not m.name.begins_with("_"):
				print("  %s (args: %d)" % [m.name, m.args.size()])

		var soul_props = soul.get_property_list()
		print("Soul properties:")
		for p in soul_props:
			if not p.name.begins_with("_") and p.type != 0:
				print("  %s: %s" % [p.name, p.type])

	print("\n=== API TEST COMPLETE ===")
	quit(0)
