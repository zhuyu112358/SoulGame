extends CanvasLayer
## DebugOverlay - In-game debug panel with FPS, state viewer, and network monitor
##
## Toggle with ` (backtick) key. Shows performance metrics, game state,
## network stats, and recent logs.
##
## This is a development tool, not game UI.

## Whether overlay is visible
var _visible: bool = false

## Root control
var _panel: PanelContainer = null

## Labels for various metrics
var _fps_label: Label = null
var _state_label: Label = null
var _network_label: Label = null
var _log_label: RichTextLabel = null

## Update interval
var _update_interval: float = 0.5
var _update_timer: float = 0.0

## FPS history for graph
var _fps_history: Array = []
var _max_fps_history: int = 60


func _ready() -> void:
	layer = 1000
	_build_ui()
	_visible = ConfigManager.get_value("game", "debug", "show_debug_overlay", true)
	_panel.visible = _visible
	Logger.info("DebugOverlay initialized", "Debug")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		_toggle()


func _process(delta: float) -> void:
	if not _visible:
		return

	_update_timer += delta
	if _update_timer >= _update_interval:
		_update_timer = 0.0
		_update_display()


## Toggle overlay visibility
func _toggle() -> void:
	_visible = not _visible
	_panel.visible = _visible
	if _visible:
		_update_display()


## Build the debug UI
func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.offset_right = 420
	_panel.offset_bottom = 500
	_panel.position = Vector2(10, 10)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "=== SoulGame Debug ==="
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	# FPS / Performance
	_fps_label = Label.new()
	_fps_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_fps_label)

	# Game State
	var state_title := Label.new()
	state_title.text = "-- Game State --"
	state_title.add_theme_font_size_override("font_size", 12)
	vbox.add_child(state_title)

	_state_label = Label.new()
	_state_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_state_label)

	# Network
	var net_title := Label.new()
	net_title.text = "-- Network --"
	net_title.add_theme_font_size_override("font_size", 12)
	vbox.add_child(net_title)

	_network_label = Label.new()
	_network_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_network_label)

	# Logs
	var log_title := Label.new()
	log_title.text = "-- Recent Logs --"
	log_title.add_theme_font_size_override("font_size", 12)
	vbox.add_child(log_title)

	_log_label = RichTextLabel.new()
	_log_label.custom_minimum_size = Vector2(400, 200)
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_label.bbcode_enabled = true
	_log_label.scroll_following = true
	vbox.add_child(_log_label)


## Update all display values
func _update_display() -> void:
	# FPS
	var fps := Engine.get_frames_per_second()
	_fps_history.append(fps)
	if _fps_history.size() > _max_fps_history:
		_fps_history.pop_front()
	var avg_fps := 0.0
	if not _fps_history.is_empty():
		avg_fps = _fps_history.reduce(func(a, b): return a + b, 0.0) / _fps_history.size()

	var fps_color := "[color=green]" if fps >= 55 else ("[color=yellow]" if fps >= 30 else "[color=red]")
	_fps_label.text = "FPS: %s%d[/color] (avg: %.1f) | Frame: %.2fms | Objects: %d" % [
		fps_color, fps, avg_fps, 1000.0 / max(fps, 1), get_tree().get_node_count()
	]

	# Game State
	var state_summary := GameState.get_summary()
	_state_label.text = "Scene: %s\nSouls: %d\nSession: %s\nTick: %d\nTime Scale: %.2f" % [
		state_summary["current_scene"],
		state_summary["soul_count"],
		state_summary["session_id"],
		state_summary["tick"],
		GameState.get_world_state("time_scale", 1.0)
	]

	# Network
	var net_stats := NetworkClient.get_stats()
	var sa_stats := SoulArenaClient.get_stats()
	var seed_stats := SeedClient.get_stats()
	_network_label.text = "HTTP: %d req (%d ok / %d fail) | Retries: %d\nAvg resp: %.0fms | WS: %d conns\nSoulArena: %d calls | Seed: %d calls | Ticks: %d" % [
		net_stats["total_requests"], net_stats["successful"], net_stats["failed"],
		net_stats["retries"], net_stats["avg_response_ms"], net_stats["ws_connections"],
		sa_stats["total_calls"], seed_stats["total_calls"], seed_stats["total_ticks"]
	]

	# Logs
	var logs := Logger.get_recent_entries(15)
	var log_text := ""
	for entry in logs:
		var color := "white"
		match entry["level"]:
			"DEBUG": color = "gray"
			"INFO": color = "white"
			"WARN": color = "yellow"
			"ERROR": color = "red"
		log_text += "[color=%s][%s] %s: %s[/color]\n" % [color, entry["level"], entry["category"], entry["message"]]
	_log_label.text = log_text


## Show a temporary toast message
func toast(message: String, duration: float = 2.0) -> void:
	var toast_label := Label.new()
	toast_label.text = message
	toast_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast_label.position = Vector2(0, -50)
	toast_label.add_theme_font_size_override("font_size", 16)
	add_child(toast_label)

	var tween := create_tween()
	tween.tween_property(toast_label, "modulate:a", 1.0, 0.2)
	tween.tween_interval(duration)
	tween.tween_property(toast_label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(toast_label.queue_free)
