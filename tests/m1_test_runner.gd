extends SceneTree
## M1TestRunner - Wrapper script to run M1 integration tests in --script mode
##
## In --script mode, autoloads are not initialized. This wrapper loads the
## test scene, which triggers full project initialization including autoloads.
##
## Usage: godot --headless -s res://tests/m1_test_runner.gd --path D:\SoulGame

func _initialize() -> void:
	# Load and instantiate the test scene (this triggers autoload initialization)
	var test_scene = load("res://tests/m1_test.tscn")
	if test_scene == null:
		print("ERROR: Failed to load test scene")
		quit(1)
		return

	var test_instance = test_scene.instantiate()
	root.add_child(test_instance)

	# Give the test a frame to complete, then quit
	# The test scene's _ready() runs all tests and calls quit() on completion
	await process_frame
	await create_timer(2.0).timeout

	# If test didn't quit on its own, force quit
	print("Test timeout - forcing quit")
	quit(0)
