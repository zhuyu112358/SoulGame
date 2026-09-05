extends Node
## TestRunner - Minimal unit test framework for GDScript
##
## Lightweight test runner (no external dependencies).
## Usage: godot --headless -s res://tests/TestRunner.gd
##
## This is infrastructure, not game logic.

## Test results
var _results: Array = []
var _passed: int = 0
var _failed: int = 0
var _errors: int = 0


func _ready() -> void:
	Logger.info("=== SoulGame Test Runner ===", "Test")
	_run_all_tests()
	_print_summary()


func _run_all_tests() -> void:
	# Run each test suite
	_test_event_bus()
	_test_game_state()
	_test_config_manager()
	_test_logger()
	_test_save_system()
	_test_object_pool()
	_test_input_manager()
	_test_performance_monitor()


func _assert(condition: bool, test_name: String, message: String = "") -> void:
	if condition:
		_passed += 1
		_results.append({"name": test_name, "status": "PASS", "message": message})
		print("[PASS] %s" % test_name)
	else:
		_failed += 1
		_results.append({"name": test_name, "status": "FAIL", "message": message})
		print("[FAIL] %s - %s" % [test_name, message])


# --- EventBus Tests ---

func _test_event_bus() -> void:
	print("\n--- EventBus Tests ---")

	var received := []
	func _on_test_event(data):
		received.append(data)

	EventBus.subscribe("test_event", self, "_on_test_event")
	_assert(EventBus.has_subscribers("test_event"), "EventBus.subscribe")

	EventBus.emit("test_event", {"value": 42})
	_assert(received.size() == 1 and received[0]["value"] == 42, "EventBus.emit delivers data")

	EventBus.unsubscribe("test_event", self, "_on_test_event")
	_assert(not EventBus.has_subscribers("test_event"), "EventBus.unsubscribe")


# --- GameState Tests ---

func _test_game_state() -> void:
	print("\n--- GameState Tests ---")

	GameState.set("test", "key1", "value1")
	_assert(GameState.get("test", "key1") == "value1", "GameState.set/get")

	_assert(GameState.get("test", "nonexistent", "default") == "default", "GameState.get with default")

	var soul_state_received := false
	func _on_soul_state(data):
		soul_state_received = true

	GameState.set_soul_state("soul_test", "emotion", "happy")
	_assert(GameState.get_soul_state("soul_test", "emotion") == "happy", "GameState.soul state")
	_assert(GameState.get_soul_ids().has("soul_test"), "GameState.get_soul_ids")

	GameState.remove_soul("soul_test")
	_assert(not GameState.get_soul_ids().has("soul_test"), "GameState.remove_soul")


# --- ConfigManager Tests ---

func _test_config_manager() -> void:
	print("\n--- ConfigManager Tests ---")

	var fps = ConfigManager.get_value("game", "display", "target_fps", 60)
	_assert(fps > 0, "ConfigManager.get_value returns valid FPS")

	var sa_url = ConfigManager.get_value("sdk", "soularena", "base_url", "")
	_assert(not sa_url.is_empty(), "ConfigManager SDK config loaded")

	ConfigManager.set_value("user", "test", "key", "test_value")
	_assert(ConfigManager.get_value("user", "test", "key") == "test_value", "ConfigManager.set_value")


# --- Logger Tests ---

func _test_logger() -> void:
	print("\n--- Logger Tests ---")

	Logger.info("Test info message", "Test")
	Logger.warning("Test warning message", "Test")
	Logger.error("Test error message", "Test")

	var stats = Logger.get_stats()
	_assert(stats["info"] >= 1, "Logger.info count")
	_assert(stats["warning"] >= 1, "Logger.warning count")
	_assert(stats["error"] >= 1, "Logger.error count")

	var entries = Logger.get_recent_entries(5)
	_assert(entries.size() > 0, "Logger.get_recent_entries")


# --- SaveSystem Tests ---

func _test_save_system() -> void:
	print("\n--- SaveSystem Tests ---")

	var test_data := {"player": {"name": "test", "level": 1}, "world": {"time": 100}}
	var saved = SaveSystem.save_game(9, test_data, "Test Save")
	_assert(saved, "SaveSystem.save_game")

	var loaded = SaveSystem.load_game(9)
	_assert(not loaded.is_empty(), "SaveSystem.load_game returns data")

	_assert(SaveSystem.has_save(9), "SaveSystem.has_save")

	SaveSystem.delete_save(9)
	_assert(not SaveSystem.has_save(9), "SaveSystem.delete_save")


# --- ObjectPool Tests ---

func _test_object_pool() -> void:
	print("\n--- ObjectPool Tests ---")

	# Create a simple test scene programmatically
	var test_scene := PackedScene.new()
	var node := Node2D.new()
	node.name = "TestObject"
	test_scene.pack(node)

	ObjectPool.register_pool("test_pool", test_scene, 3, 10)
	var info = ObjectPool.get_pool_info("test_pool")
	_assert(info["available"] == 3, "ObjectPool.register_pool preloads min_size")
	_assert(info["total_created"] == 3, "ObjectPool.register_pool creates instances")

	var obj1 = ObjectPool.acquire("test_pool")
	_assert(obj1 != null, "ObjectPool.acquire returns object")
	_assert(obj1.visible == true, "ObjectPool.acquire makes object visible")
	info = ObjectPool.get_pool_info("test_pool")
	_assert(info["active"] == 1 and info["available"] == 2, "ObjectPool.acquire moves to active")

	var obj2 = ObjectPool.acquire("test_pool")
	var obj3 = ObjectPool.acquire("test_pool")
	var obj4 = ObjectPool.acquire("test_pool")  # Should create new (pool miss)
	_assert(obj4 != null, "ObjectPool.acquire creates new when pool empty")
	info = ObjectPool.get_pool_info("test_pool")
	_assert(info["total_created"] == 4, "ObjectPool.acquire grows pool on miss")

	ObjectPool.release("test_pool", obj1)
	info = ObjectPool.get_pool_info("test_pool")
	_assert(info["active"] == 3 and info["available"] == 1, "ObjectPool.release returns to pool")

	ObjectPool.clear_pool("test_pool")
	info = ObjectPool.get_pool_info("test_pool")
	_assert(info["active"] == 0 and info["available"] == 0, "ObjectPool.clear_pool frees all")


# --- InputManager Tests ---

func _test_input_manager() -> void:
	print("\n--- InputManager Tests ---")

	InputManager.bind_action("test_action", [KEY_X, KEY_Y])
	var keys = InputManager.get_action_keys("test_action")
	_assert(keys.size() == 2, "InputManager.bind_action")
	_assert(keys.has(KEY_X), "InputManager.bind_action contains key")

	InputManager.add_action_key("test_action", KEY_Z)
	_assert(InputManager.get_action_keys("test_action").size() == 3, "InputManager.add_action_key")

	InputManager.remove_action_key("test_action", KEY_X)
	_assert(not InputManager.get_action_keys("test_action").has(KEY_X), "InputManager.remove_action_key")

	# Context tests
	_assert(InputManager.get_current_context() == "default", "InputManager default context")
	InputManager.push_context("menu")
	_assert(InputManager.get_current_context() == "menu", "InputManager.push_context")
	InputManager.set_context_actions("menu", ["ui_accept"])
	_assert(InputManager.get_context_stack().size() == 1, "InputManager context stack")

	var popped = InputManager.pop_context()
	_assert(popped == "menu", "InputManager.pop_context")
	_assert(InputManager.get_current_context() == "default", "InputManager returns to default")

	# Input enable/disable
	InputManager.set_input_enabled(false)
	_assert(not InputManager.is_input_enabled(), "InputManager.set_input_enabled(false)")
	InputManager.set_input_enabled(true)
	_assert(InputManager.is_input_enabled(), "InputManager.set_input_enabled(true)")

	# Export/import
	var bindings = InputManager.export_bindings()
	_assert(bindings.has("test_action"), "InputManager.export_bindings")
	InputManager.reset_to_defaults()
	_assert(not InputManager.get_action_keys("test_action").has(KEY_Y), "InputManager.reset_to_defaults")


# --- PerformanceMonitor Tests ---

func _test_performance_monitor() -> void:
	print("\n--- PerformanceMonitor Tests ---")

	PerformanceMonitor.start_baseline("test_baseline")
	_assert(PerformanceMonitor.get_snapshot()["active_baselines"] == 1, "PerformanceMonitor.start_baseline")

	# Simulate some frames
	for i in range(10):
		await get_tree().create_timer(0.01).timeout

	var results = PerformanceMonitor.end_baseline("test_baseline")
	_assert(not results.is_empty(), "PerformanceMonitor.end_baseline returns results")
	_assert(results.has("avg_fps"), "PerformanceMonitor.baseline has avg_fps")
	_assert(results.has("frames"), "PerformanceMonitor.baseline has frame count")
	_assert(results["frames"] >= 5, "PerformanceMonitor.baseline recorded frames")

	# Custom metrics
	PerformanceMonitor.record_metric("test_metric", 42.0)
	PerformanceMonitor.record_metric("test_metric", 58.0)
	var stats = PerformanceMonitor.get_metric_stats("test_metric")
	_assert(stats["count"] == 2, "PerformanceMonitor.record_metric count")
	_assert(stats["min"] == 42.0, "PerformanceMonitor.record_metric min")
	_assert(stats["max"] == 58.0, "PerformanceMonitor.record_metric max")
	_assert(stats["avg"] == 50.0, "PerformanceMonitor.record_metric avg")

	var snapshot = PerformanceMonitor.get_snapshot()
	_assert(snapshot.has("fps_current"), "PerformanceMonitor.snapshot has fps")
	_assert(snapshot.has("memory_static_mb"), "PerformanceMonitor.snapshot has memory")

	PerformanceMonitor.reset()
	_assert(PerformanceMonitor.get_all_baselines().is_empty(), "PerformanceMonitor.reset clears baselines")


func _print_summary() -> void:
	print("\n" + "=" * 50)
	print("TEST SUMMARY")
	print("=" * 50)
	print("Passed: %d" % _passed)
	print("Failed: %d" % _failed)
	print("Errors: %d" % _errors)
	print("Total:  %d" % (_passed + _failed + _errors))
	print("=" * 50)

	if _failed > 0 or _errors > 0:
		print("\nFAILED TESTS:")
		for result in _results:
			if result["status"] != "PASS":
				print("  - %s: %s" % [result["name"], result["message"]])

	get_tree().quit(_failed > 0 or _errors > 0)
