extends Node
## Bootstrap - Initialization entry point
##
## This is the first script that runs. It initializes all core systems
## in the correct order and verifies infrastructure connectivity.
##
## This is infrastructure code, NOT game logic.

func _ready() -> void:
	GameLog.info("=== SoulGame Bootstrap ===", "Bootstrap")
	GameLog.info("Version: %s" % GameState.get_value("game", "version", "0.1.0"), "Bootstrap")

	# Initialize systems in dependency order
	_initialize_config()
	_initialize_state()
	_verify_sdk_connectivity()

	GameLog.info("Bootstrap complete - infrastructure ready", "Bootstrap")
	GameLog.info("Game design not frozen - only base architecture active", "Bootstrap")

	EventBus.emit("bootstrap_complete", {})


func _initialize_config() -> void:
	GameLog.info("Loading configurations...", "Bootstrap")
	# ConfigManager autoload already loads configs in _ready
	var game_cfg = ConfigManager.get_value("game", "display", "target_fps", 60)
	GameLog.info("Target FPS: %d" % game_cfg, "Bootstrap")


func _initialize_state() -> void:
	GameLog.info("Initializing game state...", "Bootstrap")
	GameState.set_value("game", "current_scene", "main")
	GameState.set_value("game", "infrastructure_ready", true)
	GameState.set_value("game", "design_frozen", false)


func _verify_sdk_connectivity() -> void:
	GameLog.info("Verifying SDK connectivity...", "Bootstrap")

	# Check SoulArena
	var sa_reachable = SoulArenaClient.check_connection()
	GameLog.info("SoulArena (%s): %s" % [SoulArenaClient.get_base_url(), "reachable" if sa_reachable else "NOT reachable"], "Bootstrap")
	GameState.set_value("game", "soularena_connected", sa_reachable)

	# Check Seed
	var seed_reachable = SeedClient.check_connection()
	GameLog.info("Seed (%s): %s" % [SeedClient.get_base_url(), "reachable" if seed_reachable else "NOT reachable"], "Bootstrap")
	GameState.set_value("game", "seed_connected", seed_reachable)

	if not sa_reachable:
		GameLog.warning("SoulArena not reachable - API calls will fail until server starts", "Bootstrap")
	if not seed_reachable:
		GameLog.warning("Seed not reachable - world API calls will fail until server starts", "Bootstrap")
