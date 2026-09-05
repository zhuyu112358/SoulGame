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

## Test state variables (for nested function compatibility)
var _test_received: Array = []

## Utility class preloads (class_name may not be registered in test context)
const MathUtils = preload("res://scripts/core/MathUtils.gd")
const PhysicsUtils = preload("res://scripts/core/PhysicsUtils.gd")
var _test_soul_state_received: bool = false
var _test_callback_fired: bool = false
var _test_repeat_count: int = 0


func _ready() -> void:
	GameLog.info("=== SoulGame Test Runner ===", "Test")
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
	_test_time_manager()
	_test_error_handler()
	_test_math_utils()
	_test_physics_utils()
	_test_localization_manager()


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

	_test_received.clear()

	EventBus.subscribe("test_event", self, "_on_test_event")
	_assert(EventBus.has_subscribers("test_event"), "EventBus.subscribe")

	EventBus.emit("test_event", {"value": 42})
	_assert(_test_received.size() == 1 and _test_received[0]["value"] == 42, "EventBus.emit delivers data")

	EventBus.unsubscribe("test_event", self, "_on_test_event")
	_assert(not EventBus.has_subscribers("test_event"), "EventBus.unsubscribe")


# --- GameState Tests ---

func _test_game_state() -> void:
	print("\n--- GameState Tests ---")

	GameState.set_value("test", "key1", "value1")
	_assert(GameState.get_value("test", "key1") == "value1", "GameState.set/get")

	_assert(GameState.get_value("test", "nonexistent", "default") == "default", "GameState.get with default")

	_test_soul_state_received = false

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

	GameLog.info("Test info message", "Test")
	GameLog.warning("Test warning message", "Test")
	GameLog.error("Test error message", "Test")

	var stats = GameLog.get_stats()
	_assert(stats["info"] >= 1, "Logger.info count")
	_assert(stats["warning"] >= 1, "Logger.warning count")
	_assert(stats["error"] >= 1, "Logger.error count")

	var entries = GameLog.get_recent_entries(5)
	_assert(entries.size() > 0, "Logger.get_recent_entries")


# --- SaveSystem Tests ---

func _test_save_system() -> void:
	print("\n--- SaveSystem Tests ---")

	var test_data: Dictionary = {"player": {"name": "test", "level": 1}, "world": {"time": 100}}
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
	var test_scene: PackedScene = PackedScene.new()
	var node: Node2D = Node2D.new()
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


# --- TimeManager Tests ---

func _test_time_manager() -> void:
	print("\n--- TimeManager Tests ---")

	# Time scale
	TimeManager.set_time_scale(0.5)
	_assert(TimeManager.get_time_scale() == 0.5, "TimeManager.set_time_scale")
	TimeManager.set_time_scale(1.0)
	_assert(TimeManager.get_time_scale() == 1.0, "TimeManager.set_time_scale reset")

	# Pause/resume
	TimeManager.pause()
	_assert(TimeManager.is_paused(), "TimeManager.pause")
	TimeManager.resume()
	_assert(not TimeManager.is_paused(), "TimeManager.resume")

	# Scheduling
	_test_callback_fired = false

	var id = TimeManager.schedule_once(0.1, self, "_on_schedule")
	_assert(id > 0, "TimeManager.schedule_once returns id")
	_assert(TimeManager.is_scheduled(id), "TimeManager.is_scheduled")

	await get_tree().create_timer(0.2).timeout
	_assert(_test_callback_fired, "TimeManager.schedule_once fires callback")
	_assert(not TimeManager.is_scheduled(id), "TimeManager schedule auto-removes")

	# Repeating schedule
	_test_repeat_count = 0

	var repeat_id = TimeManager.schedule_repeating(0.05, self, "_on_repeat")
	await get_tree().create_timer(0.2).timeout
	_assert(_test_repeat_count >= 2, "TimeManager.schedule_repeating fires multiple times")
	TimeManager.cancel(repeat_id)
	_assert(not TimeManager.is_scheduled(repeat_id), "TimeManager.cancel")

	# Time of day
	TimeManager.set_time_of_day(14.5)
	_assert(TimeManager.get_time_of_day() == 14.5, "TimeManager.set_time_of_day")
	_assert(TimeManager.get_time_of_day_string() == "14:30", "TimeManager.get_time_of_day_string")
	_assert(TimeManager.get_day_phase() == "day", "TimeManager.get_day_phase (afternoon)")

	TimeManager.set_time_of_day(22.0)
	_assert(TimeManager.get_day_phase() == "night", "TimeManager.get_day_phase (night)")


# --- ErrorHandler Tests ---

func _test_error_handler() -> void:
	print("\n--- ErrorHandler Tests ---")

	ErrorHandler.track_error("TestCategory", "Test error message", {"code": 42}, "error")
	var history = ErrorHandler.get_error_history(10)
	_assert(history.size() >= 1, "ErrorHandler.track_error records error")
	_assert(history[0]["category"] == "TestCategory", "ErrorHandler error category")
	_assert(history[0]["message"] == "Test error message", "ErrorHandler error message")
	_assert(history[0]["severity"] == "error", "ErrorHandler error severity")

	# Track different severities
	ErrorHandler.track_error("Net", "Warning test", {}, "warning")
	ErrorHandler.track_error("Sys", "Info test", {}, "info")

	var stats = ErrorHandler.get_stats()
	_assert(stats["total_errors"] >= 3, "ErrorHandler.get_stats total")
	_assert(stats["by_severity"]["error"] >= 1, "ErrorHandler stats by severity")
	_assert(stats["by_category"].has("TestCategory"), "ErrorHandler stats by category")

	# Filter by category
	var net_errors = ErrorHandler.get_errors_by_category("Net")
	_assert(net_errors.size() >= 1, "ErrorHandler.get_errors_by_category")

	# Critical error
	ErrorHandler.track_error("Critical", "Critical test", {}, "critical")
	_assert(ErrorHandler.has_critical_errors(), "ErrorHandler.has_critical_errors")

	# Clear
	ErrorHandler.clear_history()
	_assert(ErrorHandler.get_stats()["total_errors"] == 0, "ErrorHandler.clear_history")


# --- MathUtils Tests ---

func _test_math_utils() -> void:
	print("\n--- MathUtils Tests ---")

	# Clamp
	_assert(MathUtils.clamp(15.0, 0.0, 10.0) == 10.0, "MathUtils.clamp high")
	_assert(MathUtils.clamp(-5.0, 0.0, 10.0) == 0.0, "MathUtils.clamp low")
	_assert(MathUtils.clamp(5.0, 0.0, 10.0) == 5.0, "MathUtils.clamp in range")

	# Lerp
	_assert(MathUtils.lerp(0.0, 10.0, 0.5) == 5.0, "MathUtils.lerp")
	_assert(MathUtils.lerp(0.0, 10.0, 0.0) == 0.0, "MathUtils.lerp t=0")
	_assert(MathUtils.lerp(0.0, 10.0, 1.0) == 10.0, "MathUtils.lerp t=1")

	# Map range
	_assert(MathUtils.map_range(5.0, 0.0, 10.0, 0.0, 100.0) == 50.0, "MathUtils.map_range")

	# Distance
	_assert(MathUtils.approx(MathUtils.distance(Vector2.ZERO, Vector2(3, 4)), 5.0), "MathUtils.distance")

	# Approx
	_assert(MathUtils.approx(1.0, 1.0001, 0.001), "MathUtils.approx true")
	_assert(not MathUtils.approx(1.0, 1.1, 0.001), "MathUtils.approx false")

	# Wrap
	_assert(MathUtils.wrap(370.0, 0.0, 360.0) == 10.0, "MathUtils.wrap")

	# Angle normalize
	_assert(MathUtils.approx(MathUtils.normalize_angle(PI + 0.5), -PI + 0.5, 0.01), "MathUtils.normalize_angle")

	# Easing
	_assert(MathUtils.ease_in(0.5) == 0.25, "MathUtils.ease_in")
	_assert(MathUtils.approx(MathUtils.ease_out(0.5), 0.75), "MathUtils.ease_out")
	_assert(MathUtils.ease_in_out(0.5) == 0.5, "MathUtils.ease_in_out midpoint")

	# Smoothstep
	_assert(MathUtils.smoothstep(0.0, 1.0, 0.0) == 0.0, "MathUtils.smoothstep start")
	_assert(MathUtils.smoothstep(0.0, 1.0, 1.0) == 1.0, "MathUtils.smoothstep end")


# --- PhysicsUtils Tests ---

func _test_physics_utils() -> void:
	print("\n--- PhysicsUtils Tests ---")

	# Circle collision
	_assert(PhysicsUtils.check_circle_collision(Vector2.ZERO, 5.0, Vector2(3, 0), 5.0), "PhysicsUtils.circle_collision overlap")
	_assert(not PhysicsUtils.check_circle_collision(Vector2.ZERO, 1.0, Vector2(10, 0), 1.0), "PhysicsUtils.circle_collision no overlap")

	# Rect collision
	_assert(PhysicsUtils.check_rect_collision(Rect2(0, 0, 10, 10), Rect2(5, 5, 10, 10)), "PhysicsUtils.rect_collision overlap")
	_assert(not PhysicsUtils.check_rect_collision(Rect2(0, 0, 5, 5), Rect2(10, 10, 5, 5)), "PhysicsUtils.rect_collision no overlap")

	# Point in shapes
	_assert(PhysicsUtils.point_in_circle(Vector2(2, 0), Vector2.ZERO, 5.0), "PhysicsUtils.point_in_circle inside")
	_assert(not PhysicsUtils.point_in_circle(Vector2(10, 0), Vector2.ZERO, 5.0), "PhysicsUtils.point_in_circle outside")
	_assert(PhysicsUtils.point_in_rect(Vector2(2, 2), Rect2(0, 0, 10, 10)), "PhysicsUtils.point_in_rect inside")
	_assert(not PhysicsUtils.point_in_rect(Vector2(15, 15), Rect2(0, 0, 10, 10)), "PhysicsUtils.point_in_rect outside")

	# Distance to segment
	var seg_result: Dictionary = PhysicsUtils.distance_to_segment(Vector2(0, 5), Vector2(-10, 0), Vector2(10, 0))
	_assert(MathUtils.approx(seg_result["distance"], 5.0), "PhysicsUtils.distance_to_segment")
	_assert(seg_result["closest_point"] == Vector2(0, 0), "PhysicsUtils.distance_to_segment closest")

	# Friction
	var vel: Vector2 = Vector2(100, 0)
	var after_friction: Vector2 = PhysicsUtils.apply_friction(vel, 0.5, 1.0)
	_assert(after_friction.x < vel.x, "PhysicsUtils.apply_friction reduces velocity")

	# Gravity
	var with_gravity: Vector2 = PhysicsUtils.apply_gravity(Vector2.ZERO, 9.8, 1.0)
	_assert(MathUtils.approx(with_gravity.y, 9.8), "PhysicsUtils.apply_gravity")

	# Clamp velocity
	_assert(PhysicsUtils.clamp_velocity(Vector2(100, 0), 50.0).length() == 50.0, "PhysicsUtils.clamp_velocity")
	_assert(PhysicsUtils.clamp_velocity(Vector2(10, 0), 50.0).length() == 10.0, "PhysicsUtils.clamp_velocity under max")

	# Bounce
	var bounced: Vector2 = PhysicsUtils.bounce(Vector2(10, -10), Vector2.UP, 1.0)
	_assert(MathUtils.approx(bounced.y, 10.0), "PhysicsUtils.bounce")

	# Line intersection
	var intersect: Vector2 = PhysicsUtils.line_intersection(Vector2(-10, 0), Vector2(10, 0), Vector2(0, -10), Vector2(0, 10))
	_assert(intersect == Vector2.ZERO, "PhysicsUtils.line_intersection")

	# Segment intersection
	_assert(PhysicsUtils.segments_intersect(Vector2(-10, 0), Vector2(10, 0), Vector2(0, -10), Vector2(0, 10)), "PhysicsUtils.segments_intersect true")
	_assert(not PhysicsUtils.segments_intersect(Vector2(-10, 0), Vector2(-5, 0), Vector2(5, 0), Vector2(10, 0)), "PhysicsUtils.segments_intersect false")

	# Look at rotation
	var rot: float = PhysicsUtils.look_at_rotation(0.0, PI / 2, PI, 0.1)
	_assert(rot > 0.0, "PhysicsUtils.look_at_rotation moves toward target")

	# Spring damper
	var spring: Dictionary = PhysicsUtils.spring_damper(10.0, 0.0, 0.0, 10.0, 2.0, 0.1)
	_assert(spring["position"] < 10.0, "PhysicsUtils.spring_damper moves toward target")


# --- LocalizationManager Tests ---

func _test_localization_manager() -> void:
	print("\n--- LocalizationManager Tests ---")

	# Default language
	_assert(LocalizationManager.get_language() == "en", "LocalizationManager default language")

	# Available languages
	var langs = LocalizationManager.get_available_languages()
	_assert(langs.has("en"), "LocalizationManager has en")
	_assert(langs.has("zh"), "LocalizationManager has zh")
	_assert(langs.has("ja"), "LocalizationManager has ja")

	# Translation
	_assert(LocalizationManager.tr("LOADING") == "Loading...", "LocalizationManager.tr en")
	_assert(LocalizationManager.has_translation("LOADING"), "LocalizationManager.has_translation true")
	_assert(not LocalizationManager.has_translation("NONEXISTENT_KEY"), "LocalizationManager.has_translation false")

	# Format translation
	var formatted: String = LocalizationManager.trf("LOADING", [])
	_assert(formatted == "Loading...", "LocalizationManager.trf no args")

	# Switch language
	LocalizationManager.set_language("zh")
	_assert(LocalizationManager.get_language() == "zh", "LocalizationManager.set_language zh")
	_assert(LocalizationManager.tr("LOADING") == "闂備礁鎲″缁樻叏閹灐褰掑炊閵娧€鏋?..", "LocalizationManager.tr zh")

	# Fallback to default
	LocalizationManager.set_language("ja")
	_assert(LocalizationManager.tr("LOADING") == "Loading...", "LocalizationManager fallback to en for missing ja")

	# Add translation
	LocalizationManager.add_translation("ja", "LOADING", "闂佽崵鍠撻搹搴ㄥ储鐟欏嫬顕遍柍鍝勫€圭紞鍥╃磼濡ゅ嫭銆冪紓鍌氼槸閳?..")
	_assert(LocalizationManager.tr("LOADING") == "闂佽崵鍠撻搹搴ㄥ储鐟欏嫬顕遍柍鍝勫€圭紞鍥╃磼濡ゅ嫭銆冪紓鍌氼槸閳?..", "LocalizationManager.add_translation ja")

	# Reset
	LocalizationManager.reset_to_default()
	_assert(LocalizationManager.get_language() == "en", "LocalizationManager.reset_to_default")

	# Missing key tracking
	var missing_before = LocalizationManager.get_missing_keys().size()
	LocalizationManager.tr("COMPLETELY_FAKE_KEY")
	var missing_after = LocalizationManager.get_missing_keys().size()
	_assert(missing_after > missing_before, "LocalizationManager tracks missing keys")

	# Stats
	var stats = LocalizationManager.get_stats()
	_assert(stats["translations_loaded"] > 0, "LocalizationManager.stats has translations")
	_assert(stats["text_translated"] > 0, "LocalizationManager.stats has translated count")


func _print_summary() -> void:
	print("\n" + "==================================================")
	print("TEST SUMMARY")
	print("==================================================")
	print("Passed: %d" % _passed)
	print("Failed: %d" % _failed)
	print("Errors: %d" % _errors)
	print("Total:  %d" % (_passed + _failed + _errors))
	print("==================================================")

	if _failed > 0 or _errors > 0:
		print("\nFAILED TESTS:")
		for result in _results:
			if result["status"] != "PASS":
				print("  - %s: %s" % [result["name"], result["message"]])

	get_tree().quit(_failed > 0 or _errors > 0)


# --- Callback functions (class-level for Godot 4.7 compatibility) ---

func _on_test_event(data) -> void:
	_test_received.append(data)


func _on_soul_state(data) -> void:
	_test_soul_state_received = true


func _on_schedule() -> void:
	_test_callback_fired = true


func _on_repeat() -> void:
	_test_repeat_count += 1
