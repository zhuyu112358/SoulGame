extends SceneTree

# Explore ArboreusEventBus API

func _initialize():
	print("=== ARBOREUS EVENTBUS API EXPLORATION ===")

	for i in range(30):
		await process_frame

	var bus = ClassDB.instantiate("ArboreusEventBus")
	print("EventBus: %s" % bus)

	# List all methods
	print("\n=== ALL METHODS ===")
	for m in bus.get_method_list():
		if not m.name.begins_with("_") and m.name not in ["init_ref","reference","unreference","get_reference_count","free","get_class","is_class","set","get","set_indexed","get_indexed","get_property_list","get_method_list","property_can_revert","property_get_revert","notification","to_string","get_instance_id","set_script","get_script","set_meta","remove_meta","get_meta","has_meta","get_meta_list","add_user_signal","has_user_signal","emit_signal","has_signal","get_signal_list","get_signal_connection_list","get_incoming_connections","connect","disconnect","is_connected","has_connections","set_block_signals","is_blocking_signals","notify_property_list_changed","set_message_translation","can_translate_messages","tr","tr_n","get_translation_domain","set_translation_domain","is_queued_for_deletion","cancel_free","call","call_deferred","set_deferred","callv","has_method","get_method_argument_count"]:
			print("  %s (args: %d)" % [m.name, m.args.size()])
			for arg in m.args:
				print("    - %s (type %d)" % [arg.name, arg.type])

	# Test emit with different arg counts
	print("\n=== TEST EMIT SIGNATURES ===")

	# Create a test receiver
	var receiver = TestReceiver.new()
	bus.subscribe("test_event", receiver, "_on_test")

	# Try emit with 1 arg (event name only)
	print("Try emit('test_event')...")
	bus.emit("test_event")

	# Try emit with 2 args (event name + data)
	print("Try emit('test_event', {data: 1})...")
	bus.emit("test_event", {"data": 1})

	# Try emit with 3 args
	print("Try emit('test_event', {data: 1}, extra)...")
	bus.emit("test_event", {"data": 1}, "extra")

	print("\nReceiver received count: %d" % receiver.received_count)
	print("Last data: %s" % receiver.last_data)

	print("\n=== TEST COMPLETE ===")
	quit(0)


class TestReceiver:
	var received_count: int = 0
	var last_data: Variant = null

	func _on_test(p_data = null):
		received_count += 1
		last_data = p_data
		print("  TestReceiver._on_test called with: %s" % p_data)
