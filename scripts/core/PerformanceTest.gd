extends Node2D
## PerformanceTest - Technical validation scene for performance baseline testing
##
## This is NOT a game scene. It is a technical validation tool for measuring
## performance baselines: multi-sprite rendering, particle systems, lighting,
## and state sync latency. All test objects are generic placeholders.
##
## Controls:
##   1 - Start multi-sprite render test
##   2 - Start particle system test
##   3 - Start lighting test
##   4 - Start combined stress test
##   5 - Run all tests sequentially
##   R - Reset and clear all test objects
##   Space - Print current baseline results

## Test object containers
var _sprite_container: Node2D = null
var _particle_container: Node2D = null
var _light_container: Node2D = null

## Test parameters
var _sprite_counts: Array = [10, 50, 100, 200, 500]
var _particle_counts: Array = [1, 5, 10, 20]
var _light_counts: Array = [1, 5, 10, 20]

## Current test state
var _current_test: String = ""
var _test_running: bool = false
var _test_duration: float = 5.0
var _test_timer: float = 0.0

## Results storage
var _results: Dictionary = {}

## UI labels
var _status_label: Label = null
var _results_label: Label = null


func _ready() -> void:
	_setup_containers()
	_setup_ui()
	Logger.info("PerformanceTest scene ready - press 1-5 to run tests", "PerfTest")


func _process(delta: float) -> void:
	if _test_running:
		_test_timer += delta
		_update_status()
		if _test_timer >= _test_duration:
			_end_current_test()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed):
		if event is InputEventKey:
			match event.keycode:
				KEY_1: _start_test("multi_sprite")
				KEY_2: _start_test("particle")
				KEY_3: _start_test("lighting")
				KEY_4: _start_test("combined")
				KEY_5: _run_all_tests()
				KEY_R: _reset()
				KEY_SPACE: _print_results()


## --- Test Management ---

func _start_test(test_name: String) -> void:
	if _test_running:
		Logger.warning("PerformanceTest: Test already running", "PerfTest")
		return

	_reset_test_objects()
	_current_test = test_name
	_test_running = true
	_test_timer = 0.0

	PerformanceMonitor.start_baseline(test_name)

	match test_name:
		"multi_sprite":
			_run_multi_sprite_test()
		"particle":
			_run_particle_test()
		"lighting":
			_run_lighting_test()
		"combined":
			_run_combined_test()

	Logger.info("PerformanceTest: Started '%s' (%.1fs)" % [test_name, _test_duration], "PerfTest")


func _end_current_test() -> void:
	_test_running = false
	var results = PerformanceMonitor.end_baseline(_current_test)
	_results[_current_test] = results
	Logger.info("PerformanceTest: '%s' complete - avg FPS: %.1f" % [_current_test, results.get("avg_fps", 0)], "PerfTest")
	_update_results_display()


func _run_all_tests() -> void:
	if _test_running:
		return

	var tests := ["multi_sprite", "particle", "lighting", "combined"]
	for test_name in tests:
		_start_test(test_name)
		await _wait_for_test_complete()
		await get_tree().create_timer(0.5).timeout

	Logger.info("PerformanceTest: All tests complete", "PerfTest")
	_print_results()


func _wait_for_test_complete() -> void:
	while _test_running:
		await get_tree().process_frame


## --- Individual Tests ---

func _run_multi_sprite_test() -> void:
	# Spawn sprites in a grid pattern (generic colored rectangles)
	var count: int = _sprite_counts[_sprite_counts.size() - 1]
	var cols: int = int(sqrt(count)) + 1
	var spacing: float = 64.0

	for i in range(count):
		var sprite := ColorRect.new()
		sprite.size = Vector2(32, 32)
		sprite.color = Color.from_hsv(float(i) / count, 0.7, 0.9)
		sprite.position = Vector2(
			(i % cols) * spacing - (cols * spacing) / 2,
			(int(i / cols)) * spacing - (cols * spacing) / 2
		)
		_sprite_container.add_child(sprite)

	_test_duration = 5.0


func _run_particle_test() -> void:
	var count: int = _particle_counts[_particle_counts.size() - 1]

	for i in range(count):
		var particles := GPUParticles2D.new()
		particles.amount = 100
		particles.lifetime = 2.0
		particles.position = Vector2(randf_range(-300, 300), randf_range(-200, 200))
		particles.emitting = true

		# Simple particle process material
		var material := ParticleProcessMaterial.new()
		material.direction = Vector2(0, -1)
		material.spread = 90.0
		material.gravity = Vector2(0, 100)
		material.initial_velocity_min = 50.0
		material.initial_velocity_max = 150.0
		particles.process_material = material

		_particle_container.add_child(particles)

	_test_duration = 5.0


func _run_lighting_test() -> void:
	var count: int = _light_counts[_light_counts.size() - 1]

	# Add a canvas modulate for lighting effect
	for i in range(count):
		var light := PointLight2D.new()
		light.energy = 1.0
		light.color = Color.from_hsv(float(i) / count, 0.8, 1.0)
		light.position = Vector2(randf_range(-400, 400), randf_range(-300, 300))
		light.texture = _create_light_texture()
		light.texture_scale = 200.0
		_light_container.add_child(light)

	# Add some sprites to be lit
	for i in range(50):
		var sprite := ColorRect.new()
		sprite.size = Vector2(48, 48)
		sprite.color = Color(0.8, 0.8, 0.8)
		sprite.position = Vector2(randf_range(-500, 500), randf_range(-400, 400))
		_light_container.add_child(sprite)

	_test_duration = 5.0


func _run_combined_test() -> void:
	# Combined: sprites + particles + lights
	var sprite_count := 100
	var particle_count := 5
	var light_count := 5

	for i in range(sprite_count):
		var sprite := ColorRect.new()
		sprite.size = Vector2(32, 32)
		sprite.color = Color.from_hsv(randf(), 0.7, 0.9)
		sprite.position = Vector2(randf_range(-500, 500), randf_range(-400, 400))
		_sprite_container.add_child(sprite)

	for i in range(particle_count):
		var particles := GPUParticles2D.new()
		particles.amount = 100
		particles.lifetime = 2.0
		particles.emitting = true
		var material := ParticleProcessMaterial.new()
		material.direction = Vector2(0, -1)
		material.gravity = Vector2(0, 100)
		particles.process_material = material
		_particle_container.add_child(particles)

	for i in range(light_count):
		var light := PointLight2D.new()
		light.energy = 1.0
		light.color = Color.from_hsv(randf(), 0.8, 1.0)
		light.position = Vector2(randf_range(-400, 400), randf_range(-300, 300))
		light.texture = _create_light_texture()
		light.texture_scale = 150.0
		_light_container.add_child(light)

	_test_duration = 8.0


## --- Helpers ---

func _create_light_texture() -> Texture2D:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for x in range(64):
		for y in range(64):
			var dx := float(x - 32) / 32.0
			var dy := float(y - 32) / 32.0
			var dist := sqrt(dx * dx + dy * dy)
			var alpha := clamp(1.0 - dist, 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(image)


func _setup_containers() -> void:
	_sprite_container = Node2D.new()
	_sprite_container.name = "Sprites"
	add_child(_sprite_container)

	_particle_container = Node2D.new()
	_particle_container.name = "Particles"
	add_child(_particle_container)

	_light_container = Node2D.new()
	_light_container.name = "Lights"
	add_child(_light_container)


func _setup_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0, 0, 0, 0.7)
	background.set_anchors_preset(Control.PRESET_TOP_LEFT)
	background.offset_right = 400
	background.offset_bottom = 300
	background.position = Vector2(10, 10)
	add_child(background)

	_status_label = Label.new()
	_status_label.position = Vector2(20, 20)
	_status_label.size = Vector2(380, 100)
	_status_label.add_theme_font_size_override("font_size", 14)
	add_child(_status_label)

	_results_label = Label.new()
	_results_label.position = Vector2(20, 120)
	_results_label.size = Vector2(380, 170)
	_results_label.add_theme_font_size_override("font_size", 12)
	add_child(_results_label)

	_update_status()


func _update_status() -> void:
	if not _status_label:
		return

	var perf := PerformanceMonitor.get_snapshot()
	_status_label.text = "Performance Baseline Test\n"
	_status_label.text += "Current: %s (%.1f/%.1fs)\n" % [_current_test, _test_timer, _test_duration]
	_status_label.text += "FPS: %.0f (avg: %.0f, min: %.0f)\n" % [perf["fps_current"], perf["fps_avg"], perf["fps_min"]]
	_status_label.text += "Frame: %.2fms (peak: %.2fms)\n" % [perf["frame_time_avg_ms"], perf["frame_time_peak_ms"]]
	_status_label.text += "Draw calls: %d | Objects: %d\n" % [perf["draw_calls"], perf["object_count"]]
	_status_label.text += "Memory: %.1fMB (peak: %.1fMB)\n" % [perf["memory_static_mb"] + perf["memory_dynamic_mb"], perf["memory_peak_mb"]]
	_status_label.text += "\nKeys: 1=Sprites 2=Particles 3=Lighting 4=Combined 5=All R=Reset"


func _update_results_display() -> void:
	if not _results_label:
		return

	var text := "=== Results ===\n"
	for test_name in _results:
		var r = _results[test_name]
		text += "%s: avg=%.0ffps 1%%low=%.0ffps peak=%.1fms\n" % [
			test_name, r.get("avg_fps", 0), r.get("fps_1pct_low", 0), r.get("frame_time_peak_ms", 0)
		]
	_results_label.text = text


func _print_results() -> void:
	Logger.info("=== Performance Baseline Results ===", "PerfTest")
	for test_name in _results:
		var r = _results[test_name]
		Logger.info("  %s: avg_fps=%.1f, 1pct_low=%.1f, peak_frame=%.2fms, draw_calls=%d" % [
			test_name, r.get("avg_fps", 0), r.get("fps_1pct_low", 0),
			r.get("frame_time_peak_ms", 0), r.get("draw_calls", 0)
		], "PerfTest")


func _reset_test_objects() -> void:
	if _sprite_container:
		for child in _sprite_container.get_children():
			child.queue_free()
	if _particle_container:
		for child in _particle_container.get_children():
			child.queue_free()
	if _light_container:
		for child in _light_container.get_children():
			child.queue_free()


func _reset() -> void:
	_reset_test_objects()
	_results.clear()
	_current_test = ""
	_test_running = false
	_test_timer = 0.0
	PerformanceMonitor.reset()
	_update_results_display()
	Logger.info("PerformanceTest: Reset", "PerfTest")
