extends Control
## SoulCustomizationUI - Soul customization (face sculpting) interface
## Follows GDD v2.0 Chapter 6: Soul Character System (Customization)
## M2.6 Soul Character - 7-Layer Customization UI
##
## Allows players to customize soul appearance across 7 layers:
## body, eyes, mouth, hair, accessory, color, effect.

## Soul customization system
const SoulCustomizationSystem = preload("res://scripts/game/SoulCustomizationSystem.gd")

## Customization system instance
var _customization_system: SoulCustomizationSystem = null

## Current soul being customized
var _current_soul_id: String = "fire_soul"
var _current_soul_name: String = "火灵·小焰"
var _current_element: String = "fire"

## UI nodes
var _soul_name_label: Label = null
var _layer_list: VBoxContainer = null
var _option_grid: GridContainer = null
var _preview_panel: Panel = null
var _summary_label: Label = null
var _random_button: Button = null
var _reset_button: Button = null
var _save_button: Button = null
var _back_button: Button = null

## Currently selected layer
var _selected_layer: int = 0

## Element colors
var _element_colors: Dictionary = {
	"fire": Color(1.0, 0.4, 0.2),
	"water": Color(0.2, 0.5, 1.0),
	"earth": Color(0.6, 0.4, 0.2),
	"wind": Color(0.3, 0.9, 0.6),
	"thunder": Color(0.8, 0.6, 1.0),
	"ice": Color(0.5, 0.9, 1.0),
	"dark": Color(0.5, 0.3, 0.7),
	"light": Color(1.0, 0.9, 0.4)
}


func _ready() -> void:
	_customization_system = SoulCustomizationSystem.new()
	add_child(_customization_system)
	_find_ui_nodes()
	_setup_ui()
	_refresh_layer_list()
	_refresh_options()
	_refresh_summary()
	GameLog.info("SoulCustomizationUI: Ready", "UI")

	# Setup button hover effects
	for btn in [_random_button, _reset_button, _save_button, _back_button]:
		if btn:
			btn.mouse_entered.connect(func():
				var tw = create_tween()
				tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.15)
			)
			btn.mouse_exited.connect(func():
				var tw = create_tween()
				tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2)
			)


func _find_ui_nodes() -> void:
	_soul_name_label = get_node_or_null("TopBar/SoulNameLabel")
	_layer_list = get_node_or_null("Main/LayerList/ScrollContainer/LayerContainer")
	_option_grid = get_node_or_null("Main/OptionPanel/OptionGrid")
	_preview_panel = get_node_or_null("Main/PreviewPanel")
	_summary_label = get_node_or_null("BottomBar/SummaryLabel")
	_random_button = get_node_or_null("BottomBar/RandomButton")
	_reset_button = get_node_or_null("BottomBar/ResetButton")
	_save_button = get_node_or_null("BottomBar/SaveButton")
	_back_button = get_node_or_null("BottomBar/BackButton")


func _setup_ui() -> void:
	if _soul_name_label:
		_soul_name_label.text = _current_soul_name
		_soul_name_label.add_theme_color_override("font_color", _element_colors.get(_current_element, Color.WHITE))

	if _random_button:
		_random_button.pressed.connect(_on_random_pressed)
		_setup_button_hover(_random_button)

	if _reset_button:
		_reset_button.pressed.connect(_on_reset_pressed)
		_setup_button_hover(_reset_button)

	if _save_button:
		_save_button.pressed.connect(_on_save_pressed)
		_setup_button_hover(_save_button)

	if _back_button:
		_back_button.pressed.connect(_on_back_pressed)
		_setup_button_hover(_back_button)


func _setup_button_hover(p_button: Button) -> void:
	if p_button == null:
		return
	p_button.mouse_entered.connect(func():
		var tween = create_tween()
		tween.tween_property(p_button, "modulate", Color(1.25, 1.1, 0.75), 0.15)
	)
	p_button.mouse_exited.connect(func():
		var tween = create_tween()
		tween.tween_property(p_button, "modulate", Color.WHITE, 0.15)
	)


func _refresh_layer_list() -> void:
	if _layer_list == null:
		return

	# Clear existing
	for child in _layer_list.get_children():
		child.queue_free()

	var layers = _customization_system.get_all_layers()
	for layer_data in layers:
		var layer_idx = layer_data["layer"]
		var button = Button.new()
		button.text = layer_data["name"]
		button.custom_minimum_size = Vector2(140, 40)
		button.add_theme_font_size_override("font_size", 14)

		# Highlight selected layer
		if layer_idx == _selected_layer:
			button.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			button.add_theme_stylebox_override("normal", _create_gold_border_style())

		button.pressed.connect(func():
			_selected_layer = layer_idx
			_refresh_layer_list()
			_refresh_options()
		)
		_setup_button_hover(button)
		_layer_list.add_child(button)


func _refresh_options() -> void:
	if _option_grid == null:
		return

	# Clear existing
	for child in _option_grid.get_children():
		child.queue_free()

	var options = _customization_system.get_layer_options(_selected_layer)
	var current_option = _customization_system.get_current_option(_current_soul_id, _selected_layer)

	for option in options:
		var button = Button.new()
		button.text = option["name"]
		button.custom_minimum_size = Vector2(120, 50)
		button.add_theme_font_size_override("font_size", 13)

		# Highlight current option
		if current_option and current_option.get("id", "") == option["id"]:
			button.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			button.add_theme_stylebox_override("normal", _create_gold_border_style())

		button.pressed.connect(func():
			_customization_system.set_customization(_current_soul_id, _selected_layer, option["id"])
			_refresh_options()
			_refresh_summary()
			_refresh_preview()
		)
		_setup_button_hover(button)
		_option_grid.add_child(button)


func _refresh_summary() -> void:
	if _summary_label == null:
		return
	var summary = _customization_system.get_customization_summary(_current_soul_id)
	_summary_label.text = "当前配置: " + summary


func _refresh_preview() -> void:
	# Preview would render the customized soul
	# For M2, show a simple color indicator
	if _preview_panel == null:
		return
	var customization = _customization_system.get_customization(_current_soul_id)
	if customization.has("color"):
		var color_id = customization["color"]
		var tint = Color.WHITE
		match color_id:
			"golden": tint = Color(1.2, 1.0, 0.6)
			"pastel": tint = Color(1.1, 0.95, 1.05)
			"dark": tint = Color(0.7, 0.7, 0.8)
			"rainbow": tint = Color(1.0, 0.9, 0.95)
		_preview_panel.modulate = tint


func _create_gold_border_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.1, 0.25, 0.9)
	style.border_color = Color(0.85, 0.65, 0.3)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style


func _on_random_pressed() -> void:
	_customization_system.randomize_customization(_current_soul_id)
	_refresh_layer_list()
	_refresh_options()
	_refresh_summary()
	_refresh_preview()
	GameLog.info("SoulCustomizationUI: Randomized customization for %s" % _current_soul_id, "UI")


func _on_reset_pressed() -> void:
	_customization_system.reset_customization(_current_soul_id)
	_refresh_layer_list()
	_refresh_options()
	_refresh_summary()
	_refresh_preview()
	GameLog.info("SoulCustomizationUI: Reset customization for %s" % _current_soul_id, "UI")


func _on_save_pressed() -> void:
	_customization_system.save_customizations()
	GameLog.info("SoulCustomizationUI: Saved customization for %s" % _current_soul_id, "UI")


func _on_back_pressed() -> void:
	_customization_system.save_customizations()
	get_tree().change_scene_to_file("res://scenes/soul_select.tscn")
	GameLog.info("SoulCustomizationUI: Back to soul select", "UI")


## Set soul to customize (called from soul select)
func set_soul(p_soul_id: String, p_soul_name: String, p_element: String) -> void:
	_current_soul_id = p_soul_id
	_current_soul_name = p_soul_name
	_current_element = p_element
	if _soul_name_label:
		_soul_name_label.text = _current_soul_name
		_soul_name_label.add_theme_color_override("font_color", _element_colors.get(_current_element, Color.WHITE))
	_refresh_layer_list()
	_refresh_options()
	_refresh_summary()
	_refresh_preview()
