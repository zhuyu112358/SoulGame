extends SceneTree

# Ember Soul+SoulData API exploration test
# Explores Soul, SoulData, Personality, EmotionState APIs for SoulUnit replacement

func _initialize():
	print("=== EMBER SOUL+SOULDATA API EXPLORATION ===")

	for i in range(30):
		await process_frame

	# Test SoulData
	print("\n=== SoulData ===")
	var soul_data = ClassDB.instantiate("SoulData")
	if soul_data:
		print("  Created: %s" % soul_data)
		# List properties
		var props = soul_data.get_property_list()
		for p in props:
			if not p.name.begins_with("_") and p.name not in ["script", "resource_path", "resource_local_to_scene", "resource_name", "resource_path"]:
				print("  prop: %s = %s (type: %d)" % [p.name, soul_data.get(p.name), p.type])
		# List methods
		var methods = soul_data.get_method_list()
		for m in methods:
			if not m.name.begins_with("_") and m.name not in ["get", "set", "notification", "get_property_list", "get_method_list", "has_method", "has_signal", "get_signal_list", "connect", "disconnect", "emit_signal", "call", "call_deferred", "set_deferred", "to_string", "init_ref", "unreference", "reference", "unref", "get_instance_id", "set_script", "get_script", "get_class", "is_class"]:
				print("  method: %s" % m.name)

	# Test Personality
	print("\n=== Personality ===")
	var personality = ClassDB.instantiate("Personality")
	if personality:
		print("  Created: %s" % personality)
		var props = personality.get_property_list()
		for p in props:
			if not p.name.begins_with("_") and p.name not in ["script", "resource_path", "resource_local_to_scene", "resource_name"]:
				print("  prop: %s = %s" % [p.name, personality.get(p.name)])

	# Test EmotionState
	print("\n=== EmotionState ===")
	var emotion = ClassDB.instantiate("EmotionState")
	if emotion:
		print("  Created: %s" % emotion)
		var props = emotion.get_property_list()
		for p in props:
			if not p.name.begins_with("_") and p.name not in ["script", "resource_path", "resource_local_to_scene", "resource_name"]:
				print("  prop: %s = %s" % [p.name, emotion.get(p.name)])

	# Test Soul
	print("\n=== Soul ===")
	var soul = ClassDB.instantiate("Soul")
	if soul:
		print("  Created: %s" % soul)
		var props = soul.get_property_list()
		for p in props:
			if not p.name.begins_with("_") and p.name not in ["script", "resource_path", "resource_local_to_scene", "resource_name"]:
				print("  prop: %s = %s" % [p.name, soul.get(p.name)])
		# Test methods
		if soul.has_method("get_personality"):
			var p = soul.get_personality()
			print("  get_personality(): %s" % p)
		if soul.has_method("decide"):
			var ctx = {"battle_state": "active", "health_percent": 0.8, "enemy_distance": 50.0, "enemy_in_range": true}
			var d = soul.decide(ctx)
			print("  decide(in_range=true): %s" % d)
		if soul.has_method("perceive"):
			var stimuli = [{"type": "enemy", "position": Vector2(50, 0), "distance": 50.0}]
			var r = soul.perceive(stimuli)
			print("  perceive(): %s" % r)

	print("\n=== TEST COMPLETE ===")
	quit(0)
