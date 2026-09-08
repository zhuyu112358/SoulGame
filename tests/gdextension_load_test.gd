extends SceneTree

# GDExtension SDK load verification test

func _initialize():
	print("=== GDEXTENSION SDK LOAD VERIFICATION ===")
	print("Time: %s" % Time.get_datetime_string_from_system())

	# Wait for GDExtension to load
	for i in range(60):
		await process_frame

	# Check Ember classes
	print("\n=== EMBER CLASSES ===")
	var ember_classes = [
		"SoulData", "Personality", "EmotionState", "CognitiveEngine",
		"MemorySystem", "Soul", "PerceptionSystem"
	]
	var ember_found = 0
	for cls in ember_classes:
		if ClassDB.class_exists(cls):
			print("  [OK] %s" % cls)
			ember_found += 1
		else:
			print("  [MISSING] %s" % cls)
	print("Ember: %d/%d classes found" % [ember_found, ember_classes.size()])

	# Check Arboreus classes
	print("\n=== ARBOREUS CLASSES ===")
	var arboreus_classes = [
		"World", "Entity", "SpatialIndex", "Pathfinder",
		"GridMap", "EventBus", "Event", "PhysicsSystem",
		"MovementSystem", "WorldClock"
	]
	var arboreus_found = 0
	for cls in arboreus_classes:
		if ClassDB.class_exists(cls):
			print("  [OK] %s" % cls)
			arboreus_found += 1
		else:
			print("  [MISSING] %s" % cls)
	print("Arboreus: %d/%d classes found" % [arboreus_found, arboreus_classes.size()])

	# Try to instantiate key classes
	print("\n=== INSTANTIATION TEST ===")

	# Test Arboreus Pathfinder
	if ClassDB.class_exists("Pathfinder"):
		var pf = ClassDB.instantiate("Pathfinder")
		if pf:
			print("  [OK] Pathfinder instantiated: %s" % pf)
			# Check methods
			var methods = pf.get_method_list()
			print("  Pathfinder methods: %d" % methods.size())
			for m in methods:
				if not m.name.begins_with("_"):
					print("    - %s" % m.name)
		else:
			print("  [FAIL] Pathfinder instantiation returned null")
	else:
		print("  [SKIP] Pathfinder class not found")

	# Test Arboreus GridMap
	if ClassDB.class_exists("GridMap"):
		var gm = ClassDB.instantiate("GridMap")
		if gm:
			print("  [OK] GridMap instantiated: %s" % gm)
			var methods = gm.get_method_list()
			print("  GridMap methods: %d" % methods.size())
			for m in methods:
				if not m.name.begins_with("_"):
					print("    - %s" % m.name)
		else:
			print("  [FAIL] GridMap instantiation returned null")
	else:
		print("  [SKIP] GridMap class not found")

	# Test Ember Soul
	if ClassDB.class_exists("Soul"):
		var soul = ClassDB.instantiate("Soul")
		if soul:
			print("  [OK] Soul instantiated: %s" % soul)
			var methods = soul.get_method_list()
			print("  Soul methods: %d" % methods.size())
			for m in methods:
				if not m.name.begins_with("_"):
					print("    - %s" % m.name)
		else:
			print("  [FAIL] Soul instantiation returned null")
	else:
		print("  [SKIP] Soul class not found")

	print("\n=== VERIFICATION COMPLETE ===")
	quit(0)
