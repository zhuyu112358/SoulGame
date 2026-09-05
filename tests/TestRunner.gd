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
