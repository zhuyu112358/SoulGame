extends SceneTree

# Ember SDK API exploration test
# Explores CognitiveEngine, PerceptionSystem, Soul, SoulData APIs

func _initialize():
	print("=== EMBER SDK API EXPLORATION TEST ===")

	for i in range(60):
		await process_frame

	# List all Ember classes
	print("\n=== EMBER CLASSES ===")
	var ember_classes = ["SoulData", "Personality", "EmotionState", "CognitiveEngine", "MemorySystem", "Soul", "PerceptionSystem"]
	for cls in ember_classes:
		if ClassDB.class_exists(cls):
			print("  [OK] %s" % cls)
		else:
			print("  [MISSING] %s" % cls)

	# Test SoulData
	print("\n=== SoulData TEST ===")
	var soul_data = ClassDB.instantiate("SoulData")
	if soul_data:
		print("  SoulData created: %s" % soul_data)
		_print_methods(soul_data, "SoulData")

	# Test Personality
	print("\n=== Personality TEST ===")
	var personality = ClassDB.instantiate("Personality")
	if personality:
		print("  Personality created: %s" % personality)
		_print_methods(personality, "Personality")
		# Try setting properties
		if personality.has_method("set") or personality.has_method("set_property"):
			print("  Has set method")

	# Test EmotionState
	print("\n=== EmotionState TEST ===")
	var emotion = ClassDB.instantiate("EmotionState")
	if emotion:
		print("  EmotionState created: %s" % emotion)
		_print_methods(emotion, "EmotionState")

	# Test PerceptionSystem
	print("\n=== PerceptionSystem TEST ===")
	var perception = ClassDB.instantiate("PerceptionSystem")
	if perception:
		print("  PerceptionSystem created: %s" % perception)
		_print_methods(perception, "PerceptionSystem")
		# Try perceive
		if perception.has_method("perceive"):
			var stimuli = [{"type": "visual", "position": Vector2(100, 100), "distance": 50.0}]
			var result = perception.perceive(stimuli)
			print("  perceive result: %s" % result)

	# Test CognitiveEngine
	print("\n=== CognitiveEngine TEST ===")
	var cognitive = ClassDB.instantiate("CognitiveEngine")
	if cognitive:
		print("  CognitiveEngine created: %s" % cognitive)
		_print_methods(cognitive, "CognitiveEngine")
		# Try decide
		if cognitive.has_method("decide"):
			var context = {"battle_state": "active", "health_percent": 0.8, "enemy_distance": 200.0}
			var decision = cognitive.decide(context)
			print("  decide result: %s" % decision)
		# Try perceive
		if cognitive.has_method("perceive"):
			var stimuli = [{"type": "enemy", "position": Vector2(100, 100)}]
			var result = cognitive.perceive(stimuli)
			print("  perceive result: %s" % result)

	# Test Soul
	print("\n=== Soul TEST ===")
	var soul = ClassDB.instantiate("Soul")
	if soul:
		print("  Soul created: %s" % soul)
		_print_methods(soul, "Soul")
		# Try init
		if soul.has_method("init") or soul.has_method("initialize"):
			print("  Has init method")
		# Try decide
		if soul.has_method("decide"):
			var context = {"battle_state": "active", "health_percent": 0.8}
			var decision = soul.decide(context)
			print("  soul.decide result: %s" % decision)

	print("\n=== TEST COMPLETE ===")
	quit(0)


func _print_methods(obj: Object, name: String):
	print("  %s methods:" % name)
	var methods = obj.get_method_list()
	for m in methods:
		if m.name.begins_with("_") or m.name in ["get", "set", "notification", "get_property_list", "get_method_list", "has_method", "has_signal", "get_signal_list", "get_signals", "connect", "disconnect", "emit_signal", "call", "call_deferred", "set_deferred", "set_block_signals", "is_blocking_signals", "set_message_translation", "can_translate_messages", "is_inside_tree", "get_tree", "get_node", "get_node_or_null", "has_node", "get_parent", "find_child", "find_children", "get_children", "get_child_count", "get_child", "has_node_and_resource", "get_path", "get_path_to", "add_child", "remove_child", "reparent", "get_index", "print_tree", "print_tree_pretty", "set_name", "get_name", "propagate_call", "propagate_notification", "set_owner", "get_owner", "get_owner_node", "remove_and_skip", "duplicate", "replace_by", "set_scene_instance_load_placeholder", "get_scene_instance_load_placeholder", "get_viewport", "set_visible", "is_visible", "is_visible_in_tree", "show", "hide", "set_process", "is_processing", "set_process_input", "is_processing_input", "set_process_unhandled_input", "is_processing_unhandled_input", "set_process_unhandled_key_input", "is_processing_unhandled_key_input", "set_pause_mode", "get_pause_mode", "can_process", "print_stray_nodes", "print_orphan_nodes", "set_process_mode", "get_process_mode", "set_process_priority", "get_process_priority", "set_process_thread_group", "get_process_thread_group", "set_process_thread_messages", "get_process_thread_messages", "set_process_internal", "is_processing_internal", "set_physics_process", "is_physics_processing", "set_physics_process_internal", "is_physics_processing_internal", "set_process_shortcut_input", "is_processing_shortcut_input", "set_process_unhandled_shortcut_input", "is_processing_unhandled_shortcut_input", "set_process_mode", "get_process_mode", "set_editor_description", "get_editor_description", "set_meta", "get_meta", "has_meta", "remove_meta", "get_meta_list", "add_user_signal", "has_user_signal", "emit_signal", "connect", "disconnect", "is_connected", "get_signal_list", "get_signal_connection_list", "get_incoming_connections", "set_deferred", "call_deferred", "call", "set", "get", "notification", "to_string", "init_ref", "unreference", "reference", "unref", "get_instance_id", "set_script", "get_script", "set_scene_file_path", "get_scene_file_path", "set_instance_id", "get_class", "is_class", "get_class_name", "set_class_name", "get_native_class", "is_inside_tree", "get_tree", "root", "get_root", "get_viewport", "get_window", "get_viewport_rect", "get_global_transform", "set_global_transform", "get_transform", "set_transform", "get_position", "set_position", "get_global_position", "set_global_position", "get_rotation", "set_rotation", "get_global_rotation", "set_global_rotation", "get_scale", "set_scale", "get_global_scale", "set_global_scale", "get_z_index", "set_z_index", "get_z_as_relative", "set_z_as_relative", "get_y_sort_enabled", "set_y_sort_enabled", "is_visible_in_tree", "set_visible", "is_visible", "show", "hide", "queue_redraw", "update_configuration_warnings", "get_configuration_warnings", "set_texture_filter", "get_texture_filter", "set_texture_repeat", "get_texture_repeat", "set_material", "get_material", "set_use_parent_material", "get_use_parent_material", "set_light_mask", "get_light_mask", "set_modulate", "get_modulate", "set_self_modulate", "get_self_modulate", "set_z_index", "get_z_index", "set_y_sort_enabled", "get_y_sort_enabled", "set_visible", "is_visible", "show", "hide", "queue_free", "is_queued_for_deletion", "free", "notification", "get_class", "is_class", "set", "get", "get_indexed", "set_indexed", "get_property_list", "validate_property", "property_can_revert", "property_get_revert", "set_script", "get_script", "get_meta_list", "has_meta", "get_meta", "set_meta", "remove_meta", "add_user_signal", "has_user_signal", "emit_signal", "connect", "disconnect", "is_connected", "get_signal_list", "get_signal_connection_list", "get_incoming_connections", "set_deferred", "call_deferred", "call", "set", "get", "notification", "to_string", "init_ref", "unreference", "reference", "unref", "get_instance_id"]:
			continue
		print("    %s (args: %d)" % [m.name, m.args.size() if m.has("args") else -1])
