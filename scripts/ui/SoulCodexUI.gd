extends Control
## SoulCodexUI - Soul codex (bestiary) UI interface
## Follows GDD v2.0 Chapter 13: Achievements and Meta Game
## M2.13 Achievements & Meta Game - Soul Codex UI
##
## Displays all 8 element souls with detailed information.
## Locked souls show as question marks.

## SoulCodexSystem preload
const SoulCodexSystem = preload("res://scripts/game/SoulCodexSystem.gd")

## UI node references
@onready var _progress_label: Label = $MarginContainer/VBox/Header/ProgressLabel
@onready var _progress_bar: ProgressBar = $MarginContainer/VBox/Header/ProgressBar
@onready var _soul_list: VBoxContainer = $MarginContainer/VBox/Body/SoulList/ScrollContainer/VBox
@onready var _detail_panel: Panel = $MarginContainer/VBox/Body/DetailPanel
@onready var _portrait_texture: TextureRect = $MarginContainer/VBox/Body/DetailPanel/VBox/PortraitContainer/PortraitTexture
@onready var _detail_name: Label = $MarginContainer/VBox/Body/DetailPanel/VBox/NameLabel
@onready var _detail_rarity: Label = $MarginContainer/VBox/Body/DetailPanel/VBox/RarityLabel
@onready var _detail_element: Label = $MarginContainer/VBox/Body/DetailPanel/VBox/ElementLabel
@onready var _detail_personality: Label = $MarginContainer/VBox/Body/DetailPanel/VBox/PersonalityLabel
@onready var _detail_description: Label = $MarginContainer/VBox/Body/DetailPanel/VBox/DescriptionLabel
@onready var _detail_stats: Label = $MarginContainer/VBox/Body/DetailPanel/VBox/StatsLabel
@onready var _detail_skills: Label = $MarginContainer/VBox/Body/DetailPanel/VBox/SkillsLabel
@onready var _detail_lore: Label = $MarginContainer/VBox/Body/DetailPanel/VBox/LoreLabel
@onready var _back_button: Button = $MarginContainer/VBox/Footer/BackButton

## Codex system instance
var _codex: SoulCodexSystem = null

## Selected soul element
var _selected_element: String = ""

## Soul button references
var _soul_buttons: Dictionary = {}


func _ready() -> void:
	# Initialize codex system
	_codex = SoulCodexSystem.new()
	add_child(_codex)

	# Connect signals
	_codex.codex_updated.connect(_on_codex_updated)
	_back_button.pressed.connect(_on_back_pressed)

	# Setup button hover
	_setup_button_hover(_back_button)

	# Build soul list
	_build_soul_list()
	_update_progress()

	# Apply 9-slice panel styles
	var codex_panel_style_path = "res://assets/ui/ui_character_select_panel_style.tres"
	if ResourceLoader.exists(codex_panel_style_path):
		var codex_panel_style = load(codex_panel_style_path)
		if codex_panel_style:
			_detail_panel.add_theme_stylebox_override("panel", codex_panel_style)
			var soul_list_panel = get_node_or_null("MarginContainer/VBox/Body/SoulList")
			if soul_list_panel:
				soul_list_panel.add_theme_stylebox_override("panel", codex_panel_style)
	else:
		var codex_fallback = StyleBoxFlat.new()
		codex_fallback.bg_color = Color(0.08, 0.05, 0.15, 0.9)
		codex_fallback.border_color = Color(0.83, 0.66, 0.36)
		codex_fallback.border_width_left = 2
		codex_fallback.border_width_right = 2
		codex_fallback.border_width_top = 2
		codex_fallback.border_width_bottom = 2
		codex_fallback.corner_radius_top_left = 8
		codex_fallback.corner_radius_top_right = 8
		codex_fallback.corner_radius_bottom_left = 8
		codex_fallback.corner_radius_bottom_right = 8
		_detail_panel.add_theme_stylebox_override("panel", codex_fallback)
		var soul_list_panel = get_node_or_null("MarginContainer/VBox/Body/SoulList")
		if soul_list_panel:
			soul_list_panel.add_theme_stylebox_override("panel", codex_fallback)

	# Apply game-level UI styles
	_setup_ui_styles()

	# Auto-select first unlocked soul
	var unlocked = _codex.get_unlocked_souls()
	if not unlocked.is_empty():
		_select_soul(unlocked[0])

	GameLog.info("SoulCodexUI: Ready (game-level UI)", "UI")
	_animate_entrance()


## Animate UI entrance with staggered fade-in + scale (game-level UI)
func _animate_entrance() -> void:
	# Title fade-in
	var title = get_node_or_null("MarginContainer/VBox/TitleLabel")
	if title and title is CanvasItem:
		title.modulate.a = 0.0
		var title_tween = create_tween()
		title_tween.set_ease(Tween.EASE_OUT)
		title_tween.tween_property(title, "modulate:a", 1.0, 0.4)
	# Soul list panel fade-in + scale
	var soul_list_panel = get_node_or_null("MarginContainer/VBox/Body/SoulList")
	if soul_list_panel and soul_list_panel is CanvasItem:
		soul_list_panel.modulate.a = 0.0
		soul_list_panel.scale = Vector2(0.95, 0.95)
		var list_tween = create_tween()
		list_tween.set_ease(Tween.EASE_OUT)
		list_tween.set_trans(Tween.TRANS_BACK)
		list_tween.tween_interval(0.2)
		list_tween.tween_property(soul_list_panel, "modulate:a", 1.0, 0.4)
		list_tween.parallel().tween_property(soul_list_panel, "scale", Vector2(1.0, 1.0), 0.4)
	# Detail panel fade-in + scale
	if _detail_panel and _detail_panel is CanvasItem:
		_detail_panel.modulate.a = 0.0
		_detail_panel.scale = Vector2(0.95, 0.95)
		var detail_tween = create_tween()
		detail_tween.set_ease(Tween.EASE_OUT)
		detail_tween.set_trans(Tween.TRANS_BACK)
		detail_tween.tween_interval(0.4)
		detail_tween.tween_property(_detail_panel, "modulate:a", 1.0, 0.4)
		detail_tween.parallel().tween_property(_detail_panel, "scale", Vector2(1.0, 1.0), 0.4)
	# Back button fade-in
	if _back_button and _back_button is CanvasItem:
		_back_button.modulate.a = 0.0
		var back_tween = create_tween()
		back_tween.set_ease(Tween.EASE_OUT)
		back_tween.tween_interval(0.6)
		back_tween.tween_property(_back_button, "modulate:a", 1.0, 0.3)
	# Staggered fade-in for soul list items
	await get_tree().create_timer(0.5).timeout
	var btn_index = 0
	for element in _soul_buttons.keys():
		var btn = _soul_buttons[element]
		if btn and is_instance_valid(btn):
			btn.modulate.a = 0.0
			btn.scale = Vector2(0.9, 0.9)
			var btn_tween = create_tween()
			btn_tween.set_ease(Tween.EASE_OUT)
			btn_tween.set_trans(Tween.TRANS_BACK)
			btn_tween.tween_interval(btn_index * 0.06)
			btn_tween.tween_property(btn, "modulate:a", 1.0, 0.25)
			btn_tween.parallel().tween_property(btn, "scale", Vector2(1.0, 1.0), 0.25)
			btn_index += 1


## Build soul list buttons
## Build soul list with card-style buttons (portrait thumbnail + element color border)
func _build_soul_list() -> void:
	# Clear existing
	for child in _soul_list.get_children():
		child.queue_free()
	_soul_buttons.clear()

	var souls = _codex.get_all_souls()
	var element_file_map = {
		"fire": "fire", "water": "water", "earth": "earth", "wind": "wind",
		"light": "light", "dark": "shadow", "thunder": "thunder", "ice": "ice"
	}

	for soul in souls:
		var element = soul["element"]
		var is_unlocked = soul["unlocked"]
		var soul_color = soul["color"]

		# Create card container (Panel with element color border)
		var card = Panel.new()
		card.custom_minimum_size = Vector2(0, 64)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card_style = StyleBoxFlat.new()
		if is_unlocked:
			card_style.bg_color = Color(0.08, 0.05, 0.15, 0.9)
			card_style.border_color = soul_color
		else:
			card_style.bg_color = Color(0.05, 0.05, 0.08, 0.7)
			card_style.border_color = Color(0.3, 0.3, 0.35, 0.5)
		card_style.border_width_left = 2
		card_style.border_width_right = 2
		card_style.border_width_top = 2
		card_style.border_width_bottom = 2
		card_style.corner_radius_top_left = 6
		card_style.corner_radius_top_right = 6
		card_style.corner_radius_bottom_left = 6
		card_style.corner_radius_bottom_right = 6
		card.add_theme_stylebox_override("panel", card_style)

		# HBox for layout: portrait + name
		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		hbox.add_theme_constant_override("separation", 10)
		card.add_child(hbox)

		# Portrait thumbnail (48x48)
		var portrait_rect = TextureRect.new()
		portrait_rect.custom_minimum_size = Vector2(48, 48)
		portrait_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if is_unlocked:
			var file_name = element_file_map.get(element, element)
			var portrait_path = "res://assets/art/characters/character_%s_soul_portrait.png" % file_name
			if ResourceLoader.exists(portrait_path):
				portrait_rect.texture = load(portrait_path)
			else:
				portrait_rect.texture = null
		else:
			portrait_rect.modulate = Color(0.2, 0.2, 0.25, 0.5)
		hbox.add_child(portrait_rect)

		# Name label
		var name_label = Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if is_unlocked:
			name_label.text = "%s" % soul["name"]
			name_label.add_theme_color_override("font_color", soul_color)
			name_label.add_theme_font_size_override("font_size", 15)
		else:
			name_label.text = "??? (locked)"
			name_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
			name_label.add_theme_font_size_override("font_size", 14)
		hbox.add_child(name_label)

		# Clickable button overlay (transparent, covers entire card)
		var button = Button.new()
		button.custom_minimum_size = Vector2(0, 64)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.flat = true
		button.text = ""
		button.pressed.connect(_on_soul_selected.bind(element))
		_setup_button_hover(button)
		card.add_child(button)

		_soul_list.add_child(card)
		_soul_buttons[element] = card


## Select a soul (card highlight with gold border)
func _select_soul(p_element: String) -> void:
	_selected_element = p_element

	# Update card styles: selected gets gold border + brighter bg
	for element in _soul_buttons.keys():
		var card = _soul_buttons[element]
		if card and card is Panel:
			var style = card.get_theme_stylebox("panel")
			if style and style is StyleBoxFlat:
				if element == p_element:
					style.border_color = Color(1.0, 0.85, 0.4, 1.0)
					style.bg_color = Color(0.12, 0.08, 0.2, 0.95)
					style.border_width_left = 3
					style.border_width_right = 3
					style.border_width_top = 3
					style.border_width_bottom = 3
				else:
					var soul = _codex.get_soul_data(element)
					if soul and !soul.is_empty():
						style.border_color = soul.get("color", Color(0.5, 0.5, 0.5))
						style.bg_color = Color(0.08, 0.05, 0.15, 0.9)
					style.border_width_left = 2
					style.border_width_right = 2
					style.border_width_top = 2
					style.border_width_bottom = 2

	# Update detail panel
	_update_detail_panel(p_element)


## Update detail panel (game-level UI: portrait glow + gold frame + stat bars)
func _update_detail_panel(p_element: String) -> void:
	var soul = _codex.get_soul_data(p_element)
	if soul.is_empty():
		return

	var is_unlocked = _codex.is_soul_unlocked(p_element)

	# Element color map for glow
	var element_colors = {
		"fire": Color(1.0, 0.4, 0.15, 0.2), "water": Color(0.2, 0.5, 1.0, 0.2),
		"earth": Color(0.4, 0.7, 0.3, 0.2), "wind": Color(0.3, 0.9, 0.8, 0.2),
		"light": Color(1.0, 0.85, 0.3, 0.25), "dark": Color(0.6, 0.3, 0.9, 0.2),
		"thunder": Color(0.9, 0.8, 0.2, 0.2), "ice": Color(0.5, 0.85, 1.0, 0.2)
	}

	# Add/remove glow behind portrait
	var portrait_parent = _portrait_texture.get_parent()
	if portrait_parent:
		# Remove old glow
		var old_glow = portrait_parent.get_node_or_null("PortraitGlow")
		if old_glow:
			old_glow.queue_free()
		var old_frame = portrait_parent.get_node_or_null("PortraitFrame")
		if old_frame:
			old_frame.queue_free()

		if is_unlocked:
			# Add element glow
			var glow = ColorRect.new()
			glow.name = "PortraitGlow"
			glow.size = Vector2(220, 260)
			glow.position = Vector2(-10, -10)
			glow.color = element_colors.get(p_element, Color(0.5, 0.5, 0.5, 0.2))
			portrait_parent.add_child(glow)
			# Glow pulse animation
			var glow_tween = create_tween()
			glow_tween.set_loops()
			glow_tween.tween_property(glow, "color:a", glow.color.a * 1.8, 2.0).set_ease(Tween.EASE_IN_OUT)
			glow_tween.tween_property(glow, "color:a", glow.color.a * 0.6, 2.0).set_ease(Tween.EASE_IN_OUT)

			# Add gold frame
			var frame = Panel.new()
			frame.name = "PortraitFrame"
			frame.custom_minimum_size = Vector2(206, 246)
			frame.position = Vector2(-3, -3)
			var frame_style = StyleBoxFlat.new()
			frame_style.bg_color = Color(0, 0, 0, 0)
			frame_style.border_color = Color(0.83, 0.66, 0.36, 0.9)
			frame_style.border_width_left = 3
			frame_style.border_width_right = 3
			frame_style.border_width_top = 3
			frame_style.border_width_bottom = 3
			frame_style.corner_radius_top_left = 8
			frame_style.corner_radius_top_right = 8
			frame_style.corner_radius_bottom_left = 8
			frame_style.corner_radius_bottom_right = 8
			frame.add_theme_stylebox_override("panel", frame_style)
			portrait_parent.add_child(frame)

	if not is_unlocked:
		_portrait_texture.texture = null
		_detail_name.text = "???"
		_detail_rarity.text = "稀有度: ???"
		_detail_element.text = "元素: ???"
		_detail_personality.text = "个性: ???"
		_detail_description.text = "尚未发现这个灵魂。在战斗中遇到它即可解锁图鉴。"
		_detail_stats.text = ""
		_detail_skills.text = ""
		_detail_lore.text = ""
		return

	_detail_name.text = soul["name"]
	_detail_name.add_theme_color_override("font_color", soul["color"])

	# Load soul portrait
	var element_file_map = {
		"fire": "fire", "water": "water", "earth": "earth", "wind": "wind",
		"light": "light", "dark": "shadow", "thunder": "thunder", "ice": "ice"
	}
	var file_name = element_file_map.get(p_element, p_element)
	var portrait_path = "res://assets/art/characters/character_%s_soul_portrait.png" % file_name
	if ResourceLoader.exists(portrait_path):
		_portrait_texture.texture = load(portrait_path)
		_portrait_texture.modulate = Color.WHITE
	else:
		_portrait_texture.texture = null

	var rarity_name = _codex.get_rarity_name(soul["rarity"])
	var rarity_color = _codex.get_rarity_color(soul["rarity"])
	_detail_rarity.text = "稀有度: %s" % rarity_name
	_detail_rarity.add_theme_color_override("font_color", rarity_color)

	_detail_element.text = "元素: %s" % soul["element_name"]
	_detail_personality.text = "个性: %s" % soul["personality"]
	_detail_description.text = soul["description"]

	# Stats
	var stats = soul["base_stats"]
	_detail_stats.text = "基础属性:\n  生命: %d  攻击: %d  防御: %d\n  速度: %d  暴击: %.0f%%  暴伤: %.1fx" % [
		stats["hp"], stats["attack"], stats["defense"],
		stats["speed"], stats["crit_rate"] * 100, stats["crit_multiplier"]
	]

	# Skills
	_detail_skills.text = "技能: " + ", ".join(soul["skills"])

	# Lore
	_detail_lore.text = "背景故事:\n" + soul["lore"]


## Update progress display
func _update_progress() -> void:
	var progress = _codex.get_discovery_progress()
	_progress_label.text = "图鉴进度: %d/%d (%.0f%%)" % [
		progress["discovered"], progress["total"], progress["percentage"]
	]
	_progress_bar.value = progress["percentage"]


## Soul selected callback
func _on_soul_selected(p_element: String) -> void:
	if AudioManager:
		AudioManager.play_sfx("ui_button_click")
	_select_soul(p_element)


## Codex updated callback
func _on_codex_updated() -> void:
	_build_soul_list()
	_update_progress()


## Back button pressed
func _on_back_pressed() -> void:
	if AudioManager:
		AudioManager.play_sfx("ui_button_click")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


## Apply game-level UI styles to panels and buttons
func _setup_ui_styles() -> void:
	# Detail panel: dark purple + gold border
	var detail_style = StyleBoxFlat.new()
	detail_style.bg_color = Color(0.06, 0.04, 0.12, 0.92)
	detail_style.border_color = Color(0.83, 0.66, 0.36, 0.7)
	detail_style.border_width_left = 2
	detail_style.border_width_right = 2
	detail_style.border_width_top = 2
	detail_style.border_width_bottom = 2
	detail_style.corner_radius_top_left = 10
	detail_style.corner_radius_top_right = 10
	detail_style.corner_radius_bottom_left = 10
	detail_style.corner_radius_bottom_right = 10
	_detail_panel.add_theme_stylebox_override("panel", detail_style)

	# Soul list panel
	var list_panel = get_node_or_null("MarginContainer/VBox/Body/SoulList")
	if list_panel and list_panel is Panel:
		list_panel.add_theme_stylebox_override("panel", detail_style)

	# Back button: three-state style
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.12, 0.08, 0.22, 0.95)
	btn_normal.border_color = Color(0.7, 0.55, 0.3, 0.8)
	btn_normal.border_width_left = 2
	btn_normal.border_width_right = 2
	btn_normal.border_width_top = 2
	btn_normal.border_width_bottom = 2
	btn_normal.corner_radius_top_left = 6
	btn_normal.corner_radius_top_right = 6
	btn_normal.corner_radius_bottom_left = 6
	btn_normal.corner_radius_bottom_right = 6

	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.18, 0.12, 0.3, 0.98)
	btn_hover.border_color = Color(0.95, 0.78, 0.45, 1.0)
	btn_hover.border_width_left = 2
	btn_hover.border_width_right = 2
	btn_hover.border_width_top = 2
	btn_hover.border_width_bottom = 2
	btn_hover.corner_radius_top_left = 6
	btn_hover.corner_radius_top_right = 6
	btn_hover.corner_radius_bottom_left = 6
	btn_hover.corner_radius_bottom_right = 6

	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.08, 0.05, 0.15, 1.0)
	btn_pressed.border_color = Color(0.6, 0.48, 0.25, 0.9)
	btn_pressed.border_width_left = 2
	btn_pressed.border_width_right = 2
	btn_pressed.border_width_top = 2
	btn_pressed.border_width_bottom = 2
	btn_pressed.corner_radius_top_left = 6
	btn_pressed.corner_radius_top_right = 6
	btn_pressed.corner_radius_bottom_left = 6
	btn_pressed.corner_radius_bottom_right = 6

	_back_button.add_theme_stylebox_override("normal", btn_normal)
	_back_button.add_theme_stylebox_override("hover", btn_hover)
	_back_button.add_theme_stylebox_override("pressed", btn_pressed)
	_back_button.add_theme_color_override("font_color", Color(0.95, 0.88, 0.65))

	# Title labels: gold
	var progress_label = get_node_or_null("MarginContainer/VBox/Header/ProgressLabel")
	if progress_label and progress_label is Label:
		progress_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
		progress_label.add_theme_font_size_override("font_size", 18)

	GameLog.info("SoulCodexUI: Game-level UI styles applied", "UI")


## Setup button hover effects
func _setup_button_hover(p_button: Button) -> void:
	if p_button == null:
		return
	p_button.mouse_entered.connect(_on_button_hover.bind(p_button))
	p_button.mouse_exited.connect(_on_button_exit.bind(p_button))


## Button hover visual feedback
func _on_button_hover(p_button: Button) -> void:
	if AudioManager:
		AudioManager.play_sfx("ui_hover")
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(p_button, "modulate", Color(1.25, 1.1, 0.75), 0.15)


## Button exit visual reset
func _on_button_exit(p_button: Button) -> void:
	if p_button.text == _selected_element:
		return
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(p_button, "modulate", Color(1.0, 1.0, 1.0), 0.2)
