extends SceneTree
## TestRunnerWrapper - Wrapper to run TestRunner in --script mode
##
## In --script mode, autoloads and class_name globals are not initialized.
## This wrapper loads a test scene which triggers full project initialization.
##
## Usage: godot --headless -s res://tests/test_runner_wrapper.gd --path D:\SoulGame

func _initialize() -> void:
	var test_scene = load("res://tests/test_runner.tscn")
	if test_scene == null:
		print("ERROR: Failed to load test_runner.tscn")
		quit(1)
		return

	var test_instance = test_scene.instantiate()
	root.add_child(test_instance)

	await process_frame
	await create_timer(3.0).timeout

	print("Test runner timeout - forcing quit")
	quit(0)
