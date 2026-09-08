extends SceneTree

# ArboreusWorldBridge updated test - remove_entity and component system

func _initialize():
	print("=== ARBOREUS WORLD BRIDGE TEST v2 ===")

	for i in range(30):
		await process_frame

	var Bridge = load("res://scripts/game/ArboreusWorldBridge.gd")
	var bridge = Bridge.new({"name": "test", "width": 1280, "height": 600})
	print("Bridge created, Arboreus available: %s" % bridge.is_arboreus_available())

	bridge.start()
	print("World started")

	# Create entities
	print("\n=== CREATE ENTITIES ===")
	var id1 = bridge.create_entity("player_soul", Vector2(100, 200))
	var id2 = bridge.create_entity("enemy_soul", Vector2(500, 300))
	print("Entity 1: id=%d, name=%s" % [id1, bridge.get_entity_name(id1)])
	print("Entity 2: id=%d, name=%s" % [id2, bridge.get_entity_name(id2)])
	print("Entity count: %d" % bridge.get_entity_count())

	# Test set_entity_name
	print("\n=== SET ENTITY NAME ===")
	bridge.set_entity_name(id1, "updated_player")
	print("Entity 1 new name: %s" % bridge.get_entity_name(id1))

	# Test component system
	print("\n=== COMPONENT SYSTEM ===")
	var has_comp = bridge.entity_has_component(id1, "transform")
	print("Entity 1 has 'transform' component: %s" % has_comp)
	var has_tag = bridge.entity_has_tag(id1, "player")
	print("Entity 1 has 'player' tag: %s" % has_tag)

	# Test update
	print("\n=== UPDATE ===")
	bridge.update(0.016)
	print("Update done")

	# Test get_status
	print("\n=== STATUS ===")
	var status = bridge.get_status()
	print("Status: %s" % status)

	# Test remove_entity
	print("\n=== REMOVE ENTITY ===")
	var removed = bridge.remove_entity(id2)
	print("Removed entity 2: %s" % removed)
	print("Entity count after remove: %d" % bridge.get_entity_count())

	# Test get_all_entities
	print("\n=== ALL ENTITIES ===")
	var all = bridge.get_all_entities()
	print("All entities count: %d" % all.size())

	# Cleanup
	bridge.stop()
	print("\n=== TEST COMPLETE ===")
	quit(0)
