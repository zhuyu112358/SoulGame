extends Control
## Battle configuration scene - map selection, tactical preset, team confirmation
## Follows GDD v2.0 Chapter 14: Complete Game Flow
## M2.1 Foundation Framework

# UI references (dynamically created in _build_ui)
var _map_container: HBoxContainer = null
var _tactic_container: GridContainer = null
var _team_container: HBoxContainer = null
var _difficulty_container: HBoxContainer = null
var _start_button: Button = null
var _back_button: Button = null
var _map_label: Label = null
var _tactic_label: Label = null
var _team_label: Label = null
var _difficulty_label: Label = null

# Configuration state
var _selected_map: String = "aether_temple"
var _selected_tactic: String = "free"
var _selected_difficulty: String = "normal"
var _selected_souls: Array = []  # Array of soul dictionaries
var _max_team_size: int = 4

# AI difficulty levels (GDD v2.0: 4 difficulties)
const DIFFICULTIES: Dictionary = {
	"easy": {"name": "简单", "name_en": "EASY", "desc": "AI基础行为，适合新手", "color": Color(0.4, 0.8, 0.4), "ai_level": 0.5, "hp_mult": 0.8, "atk_mult": 0.8},
	"normal": {"name": "普通", "name_en": "NORMAL", "desc": "AI标准行为，平衡挑战", "color": Color(0.4, 0.6, 0.9), "ai_level": 1.0, "hp_mult": 1.0, "atk_mult": 1.0},
	"hard": {"name": "困难", "name_en": "HARD", "desc": "AI高级行为，学习记忆启用", "color": Color(0.9, 0.6, 0.3), "ai_level": 1.3, "hp_mult": 1.2, "atk_mult": 1.2},
	"nightmare": {"name": "噩梦", "name_en": "NIGHTMARE", "desc": "AI完全体，协作+情绪+环境交互", "color": Color(0.9, 0.3, 0.3), "ai_level": 1.6, "hp_mult": 1.5, "atk_mult": 1.5}
}

# Map definitions (GDD v2.0: 3-5 maps, M2 starts with 2)
const MAPS: Dictionary = {
	"aether_temple": {
		"name": "以太神殿",
		"name_en": "Aether Temple",
		"description": "古老的魔法竞技场，水晶柱与神圣结界",
		"bg_color": Color(0.15, 0.1, 0.25),
		"accent_color": Color(0.6, 0.4, 0.9)
	},
	"crystal_cave": {
		"name": "水晶洞穴",
		"name_en": "Crystal Cave",
		"description": "闪耀的水晶洞穴，回声与魔法共鸣",
		"bg_color": Color(0.1, 0.15, 0.25),
		"accent_color": Color(0.4, 0.7, 0.9)
	}
}

# Tactical presets (GDD v2.0 Chapter 2.1.1: 6 commands)
const TACTICS: Dictionary = {
	"aggressive": {"name": "进攻", "name_en": "ATTACK", "desc": "主动寻找敌人，优先攻击", "color": Color(0.9, 0.3, 0.3)},
	"defensive": {"name": "防守", "name_en": "DEFEND", "desc": "保持距离，防守反击", "color": Color(0.3, 0.5, 0.9)},
	"retreat": {"name": "撤退", "name_en": "RETREAT", "desc": "向后撤退，脱离战斗", "color": Color(0.7, 0.7, 0.3)},
	"focus": {"name": "集火", "name_en": "FOCUS", "desc": "优先攻击标记目标", "color": Color(0.9, 0.5, 0.2)},
	"follow": {"name": "跟随", "name_en": "FOLLOW", "desc": "跟随指定友方单位", "color": Color(0.3, 0.8, 0.5)},
	"free": {"name": "自由", "name_en": "FREE", "desc": "完全自主决策", "color": Color(0.7, 0.7, 0.7)}
}

func _ready() -> void:
	_build_ui()
	_setup_theme()
	_build_map_selection()
	_build_tactic_selection()
	_build_difficulty_selection()
	_build_team_display()
	_connect_signals()
	_load_selected_souls()
	_update_start_button()
	_animate_entrance()

## Animate UI entrance with staggered fade-in + scale (game-level UI)
func _animate_entrance() -> void:
	# Main panel fade-in + scale
	var main_panel = get_node_or_null("CenterContainer/MainPanel")
	if main_panel and main_panel is CanvasItem:
		main_panel.modulate.a = 0.0
		main_panel.scale = Vector2(0.95, 0.95)
		var panel_tween = create_tween()
		panel_tween.set_ease(Tween.EASE_OUT)
		panel_tween.set_trans(Tween.TRANS_BACK)
		panel_tween.tween_property(main_panel, "modulate:a", 1.0, 0.5)
		panel_tween.parallel().tween_property(main_panel, "scale", Vector2(1.0, 1.0), 0.5)
	# Staggered fade-in for child sections
	var vbox = get_node_or_null("CenterContainer/MainPanel/MainVBox")
	if vbox:
		var children = vbox.get_children()
		for i in range(children.size()):
			var child = children[i]
			if child and child is CanvasItem:
				child.modulate.a = 0.0
				var child_tween = create_tween()
				child_tween.set_ease(Tween.EASE_OUT)
				child_tween.tween_interval(0.2 + i * 0.1)
				child_tween.tween_property(child, "modulate:a", 1.0, 0.3)


## Build entire UI dynamically (no .tscn file needed)
func _build_ui() -> void:
	# Root layout
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Main panel with 9-slice style (UI component integration)
	var main_panel = PanelContainer.new()
	main_panel.name = "MainPanel"
	main_panel.custom_minimum_size = Vector2(900, 650)
	var panel_style_path = "res://assets/ui/ui_battle_config_panel_style.tres"
	if ResourceLoader.exists(panel_style_path):
		var panel_style = load(panel_style_path)
		if panel_style:
			main_panel.add_theme_stylebox_override("panel", panel_style)
	else:
		# Fallback to StyleBoxFlat
		var fallback_style = StyleBoxFlat.new()
		fallback_style.bg_color = Color(0.08, 0.05, 0.15, 0.92)
		fallback_style.border_color = Color(0.83, 0.66, 0.36)
		fallback_style.border_width_left = 3
		fallback_style.border_width_right = 3
		fallback_style.border_width_top = 3
		fallback_style.border_width_bottom = 3
		fallback_style.corner_radius_top_left = 12
		fallback_style.corner_radius_top_right = 12
		fallback_style.corner_radius_bottom_left = 12
		fallback_style.corner_radius_bottom_right = 12
		main_panel.add_theme_stylebox_override("panel", fallback_style)
	center.add_child(main_panel)

	var vbox = VBoxContainer.new()
	vbox.name = "MainVBox"
	vbox.add_theme_constant_override("separation", 15)
	vbox.add_theme_constant_override("margin_left", 30)
	vbox.add_theme_constant_override("margin_right", 30)
	vbox.add_theme_constant_override("margin_top", 20)
	vbox.add_theme_constant_override("margin_bottom", 20)
	main_panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "战斗配置"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Map section
	var map_section = VBoxContainer.new()
	map_section.add_theme_constant_override("separation", 8)
	vbox.add_child(map_section)

	_map_label = Label.new()
	_map_label.text = "选择地图"
	_map_label.add_theme_font_size_override("font_size", 18)
	_map_label.add_theme_color_override("font_color", Color(0.83, 0.66, 0.36))
	map_section.add_child(_map_label)

	_map_container = HBoxContainer.new()
	_map_container.add_theme_constant_override("separation", 10)
	map_section.add_child(_map_container)

	# Tactic section
	var tactic_section = VBoxContainer.new()
	tactic_section.add_theme_constant_override("separation", 8)
	vbox.add_child(tactic_section)

	_tactic_label = Label.new()
	_tactic_label.text = "战术预设"
	_tactic_label.add_theme_font_size_override("font_size", 18)
	_tactic_label.add_theme_color_override("font_color", Color(0.83, 0.66, 0.36))
	tactic_section.add_child(_tactic_label)

	_tactic_container = GridContainer.new()
	_tactic_container.columns = 3
	_tactic_container.add_theme_constant_override("h_separation", 10)
	_tactic_container.add_theme_constant_override("v_separation", 10)
	tactic_section.add_child(_tactic_container)

	# Team section
	var team_section = VBoxContainer.new()
	team_section.add_theme_constant_override("separation", 8)
	vbox.add_child(team_section)

	_team_label = Label.new()
	_team_label.text = "出战队伍"
	_team_label.add_theme_font_size_override("font_size", 18)
	_team_label.add_theme_color_override("font_color", Color(0.83, 0.66, 0.36))
	team_section.add_child(_team_label)

	_team_container = HBoxContainer.new()
	_team_container.add_theme_constant_override("separation", 10)
	team_section.add_child(_team_container)

	# Difficulty section
	var diff_section = VBoxContainer.new()
	diff_section.add_theme_constant_override("separation", 8)
	vbox.add_child(diff_section)

	_difficulty_label = Label.new()
	_difficulty_label.text = "AI难度"
	_difficulty_label.add_theme_font_size_override("font_size", 18)
	_difficulty_label.add_theme_color_override("font_color", Color(0.83, 0.66, 0.36))
	diff_section.add_child(_difficulty_label)

	_difficulty_container = HBoxContainer.new()
	_difficulty_container.add_theme_constant_override("separation", 10)
	diff_section.add_child(_difficulty_container)

	# Buttons
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 20)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)

	_back_button = _create_game_button("返回", Vector2(150, 50), 16)
	btn_hbox.add_child(_back_button)

	_start_button = _create_game_button("开始战斗", Vector2(280, 60), 20)
	_start_button.modulate = Color(1.0, 0.92, 0.5)  # Gold highlight for primary action
	# Add golden glowing border for primary action
	var start_normal = StyleBoxFlat.new()
	start_normal.bg_color = Color(0.15, 0.1, 0.25, 0.95)
	start_normal.border_color = Color(1.0, 0.85, 0.4)
	start_normal.border_width_left = 3
	start_normal.border_width_right = 3
	start_normal.border_width_top = 3
	start_normal.border_width_bottom = 3
	start_normal.corner_radius_top_left = 8
	start_normal.corner_radius_top_right = 8
	start_normal.corner_radius_bottom_left = 8
	start_normal.corner_radius_bottom_right = 8
	_start_button.add_theme_stylebox_override("normal", start_normal)
	var start_hover = StyleBoxFlat.new()
	start_hover.bg_color = Color(0.25, 0.15, 0.35, 1.0)
	start_hover.border_color = Color(1.0, 0.95, 0.6)
	start_hover.border_width_left = 3
	start_hover.border_width_right = 3
	start_hover.border_width_top = 3
	start_hover.border_width_bottom = 3
	start_hover.corner_radius_top_left = 8
	start_hover.corner_radius_top_right = 8
	start_hover.corner_radius_bottom_left = 8
	start_hover.corner_radius_bottom_right = 8
	_start_button.add_theme_stylebox_override("hover", start_hover)
	btn_hbox.add_child(_start_button)

	GameLog.info("BattleConfig: UI built dynamically", "UI")


## Create a game-style button with 9-slice UI component textures
func _create_game_button(p_text: String, p_size: Vector2, p_font_size: int = 16) -> Button:
	var btn = Button.new()
	btn.text = p_text
	btn.custom_minimum_size = p_size
	btn.add_theme_font_size_override("font_size", p_font_size)
	btn.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.85))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.85, 0.5))

	# Hover animation: scale up + brightness boost
	btn.mouse_entered.connect(func():
		var t = create_tween()
		t.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.15).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(btn, "modulate", Color(1.15, 1.1, 0.9), 0.15)
	)
	btn.mouse_exited.connect(func():
		var t = create_tween()
		t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(btn, "modulate", Color(1.0, 1.0, 1.0), 0.2)
	)

	# Button styling handled by theme
	return btn


## Create a styled card panel with 9-slice background
func _create_card_panel(p_bg_color: Color, p_border_color: Color) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = p_bg_color
	style.border_color = p_border_color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _setup_theme() -> void:
	# Apply battleplan theme (deep purple + gold)
	var theme_path := "res://assets/ui/battleplan_theme.tres"
	if ResourceLoader.exists(theme_path):
		theme = load(theme_path)

func _build_map_selection() -> void:
	# Create map selection cards (UI-3: card style with bg color + border)
	for map_id in MAPS.keys():
		var map_data: Dictionary = MAPS[map_id]
		var card = _create_card_panel(map_data["bg_color"], map_data["accent_color"])
		card.custom_minimum_size = Vector2(220, 130)
		card.name = "MapCard_" + map_id

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		card.add_child(vbox)

		var name_label = Label.new()
		name_label.text = map_data["name"]
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_label)

		var en_label = Label.new()
		en_label.text = map_data["name_en"]
		en_label.add_theme_font_size_override("font_size", 12)
		en_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
		en_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(en_label)

		var desc_label = Label.new()
		desc_label.text = map_data["description"]
		desc_label.add_theme_font_size_override("font_size", 11)
		desc_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.45))
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(desc_label)

		# Transparent click button overlay
		var click_btn = Button.new()
		click_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		click_btn.text = ""
		var transparent_style = StyleBoxEmpty.new()
		click_btn.add_theme_stylebox_override("normal", transparent_style)
		click_btn.add_theme_stylebox_override("hover", transparent_style)
		click_btn.add_theme_stylebox_override("pressed", transparent_style)
		click_btn.add_theme_stylebox_override("focus", transparent_style)
		click_btn.tooltip_text = map_data["description"]
		click_btn.pressed.connect(_on_map_selected.bind(map_id))
		card.add_child(click_btn)

		_map_container.add_child(card)
		# Highlight selected
		if map_id == _selected_map:
			card.modulate = Color(1.2, 1.1, 0.8)

func _build_tactic_selection() -> void:
	# Create tactical preset buttons (2 rows x 3 columns) with 9-slice style
	for tactic_id in TACTICS.keys():
		var tactic_data: Dictionary = TACTICS[tactic_id]
		var btn = _create_game_button(tactic_data["name"] + "\n" + tactic_data["name_en"], Vector2(150, 60), 14)
		btn.modulate = tactic_data["color"]
		btn.tooltip_text = tactic_data["desc"]
		btn.name = "TacticBtn_" + tactic_id
		btn.pressed.connect(_on_tactic_selected.bind(tactic_id))
		_tactic_container.add_child(btn)
		# Highlight selected
		if tactic_id == _selected_tactic:
			btn.modulate = Color(1.2, 1.1, 0.7)

func _build_difficulty_selection() -> void:
	# Create AI difficulty selection buttons (GDD v2.0: 4 difficulties) with badge style
	for diff_id in DIFFICULTIES.keys():
		var diff_data: Dictionary = DIFFICULTIES[diff_id]
		var btn = _create_game_button(diff_data["name"] + "\n" + diff_data["name_en"], Vector2(140, 55), 13)
		btn.modulate = diff_data["color"]
		btn.tooltip_text = diff_data["desc"]
		btn.name = "DiffBtn_" + diff_id
		btn.pressed.connect(_on_difficulty_selected.bind(diff_id))
		_difficulty_container.add_child(btn)
		# Highlight selected
		if diff_id == _selected_difficulty:
			btn.modulate = Color(1.2, 1.1, 0.7)

func _build_team_display() -> void:
	# Create team slots (4 slots per GDD v2.0) with portrait display
	for i in _max_team_size:
		var slot = _create_card_panel(Color(0.1, 0.08, 0.18, 0.9), Color(0.5, 0.4, 0.3))
		slot.custom_minimum_size = Vector2(150, 180)
		slot.name = "TeamSlot_" + str(i)

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		slot.add_child(vbox)

		var slot_label = Label.new()
		slot_label.text = "槽位 " + str(i + 1)
		slot_label.add_theme_font_size_override("font_size", 12)
		slot_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.45))
		slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(slot_label)

		var empty_label = Label.new()
		empty_label.text = "+"
		empty_label.add_theme_font_size_override("font_size", 36)
		empty_label.add_theme_color_override("font_color", Color(0.4, 0.35, 0.3))
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.name = "EmptyLabel"
		vbox.add_child(empty_label)

		_team_container.add_child(slot)

func _connect_signals() -> void:
	_start_button.pressed.connect(_on_start_battle)
	_back_button.pressed.connect(_on_back)

func _load_selected_souls() -> void:
	# Load souls selected in soul_select scene via GameState
	if GameState.has("game", "battle_config"):
		var config: Dictionary = GameState.get_value("game", "battle_config")
		if config.has("player_souls"):
			_selected_souls = config["player_souls"]
			_update_team_display()
			return
	# SoulSelect scene stores selected soul in "battle" namespace
	if GameState.has("battle", "selected_soul"):
		var soul: Dictionary = GameState.get_value("battle", "selected_soul")
		if soul != null and soul is Dictionary:
			_selected_souls = [soul]
			_update_team_display()
			return
	# Legacy: single soul from old flow in "game" namespace
	if GameState.has("game", "selected_soul"):
		var soul: Dictionary = GameState.get_value("game", "selected_soul")
		if soul != null and soul is Dictionary:
			_selected_souls = [soul]
			_update_team_display()

func _update_team_display() -> void:
	# Update team slots with selected souls, portraits, element glow, and stat bars
	var element_colors = {
		"fire": Color(1.0, 0.4, 0.2),
		"water": Color(0.3, 0.6, 1.0),
		"earth": Color(0.5, 0.7, 0.3),
		"wind": Color(0.4, 0.9, 0.8),
		"light": Color(1.0, 0.9, 0.4),
		"dark": Color(0.7, 0.4, 0.9),
		"shadow": Color(0.7, 0.4, 0.9),
		"thunder": Color(0.9, 0.8, 0.2),
		"ice": Color(0.6, 0.9, 1.0),
	}
	for i in _max_team_size:
		var slot = _team_container.get_child(i)
		if slot == null:
			continue
		var vbox = slot.get_child(0)
		if vbox == null:
			continue
		# Remove all children except slot_label (first child)
		while vbox.get_child_count() > 1:
			vbox.get_child(1).queue_free()
		if i < _selected_souls.size():
			var soul: Dictionary = _selected_souls[i]
			var soul_name: String = soul.get("name", "未知")
			var element: String = soul.get("element", "unknown")
			var elem_color = element_colors.get(element, Color(0.7, 0.6, 0.4))
			# Update slot border to element color
			var slot_style = StyleBoxFlat.new()
			slot_style.bg_color = Color(0.08, 0.06, 0.14, 0.95)
			slot_style.border_color = elem_color
			slot_style.border_width_left = 2
			slot_style.border_width_right = 2
			slot_style.border_width_top = 2
			slot_style.border_width_bottom = 2
			slot_style.corner_radius_top_left = 8
			slot_style.corner_radius_top_right = 8
			slot_style.corner_radius_bottom_left = 8
			slot_style.corner_radius_bottom_right = 8
			slot.add_theme_stylebox_override("panel", slot_style)
			# Portrait container with glow background
			var portrait_container = VBoxContainer.new()
			portrait_container.alignment = BoxContainer.ALIGNMENT_CENTER
			portrait_container.add_theme_constant_override("separation", 2)
			vbox.add_child(portrait_container)
			# Element glow behind portrait
			var glow = ColorRect.new()
			glow.color = Color(elem_color.r, elem_color.g, elem_color.b, 0.15)
			glow.custom_minimum_size = Vector2(100, 100)
			portrait_container.add_child(glow)
			# Try to load and display soul portrait
			var portrait_path = "res://assets/art/characters/character_%s_soul_portrait.png" % element
			if element == "dark":
				portrait_path = "res://assets/art/characters/character_shadow_soul_portrait.png"
			if ResourceLoader.exists(portrait_path):
				var portrait_tex = load(portrait_path)
				if portrait_tex:
					var portrait_rect = TextureRect.new()
					portrait_rect.custom_minimum_size = Vector2(90, 90)
					portrait_rect.texture = portrait_tex
					portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					portrait_rect.position = Vector2(5, 5)
					glow.add_child(portrait_rect)
			# Gold frame border around portrait
			var frame = Panel.new()
			frame.custom_minimum_size = Vector2(100, 100)
			var frame_style = StyleBoxFlat.new()
			frame_style.bg_color = Color(0, 0, 0, 0)
			frame_style.border_color = Color(0.9, 0.75, 0.35, 0.8)
			frame_style.border_width_left = 2
			frame_style.border_width_right = 2
			frame_style.border_width_top = 2
			frame_style.border_width_bottom = 2
			frame_style.corner_radius_top_left = 6
			frame_style.corner_radius_top_right = 6
			frame_style.corner_radius_bottom_left = 6
			frame_style.corner_radius_bottom_right = 6
			frame.add_theme_stylebox_override("panel", frame_style)
			frame.position = Vector2(0, 0)
			portrait_container.add_child(frame)
			# Add soul name label
			var name_label = Label.new()
			name_label.text = soul_name
			name_label.add_theme_font_size_override("font_size", 14)
			name_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(name_label)
			# Add element label with element color
			var elem_label = Label.new()
			elem_label.text = "[" + element + "]"
			elem_label.add_theme_font_size_override("font_size", 11)
			elem_label.add_theme_color_override("font_color", elem_color)
			elem_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(elem_label)
			# Stat bars: HP and ATK
			var hp = soul.get("hp", 100)
			var atk = soul.get("attack", 10)
			var max_hp = soul.get("max_hp", 100)
			var hp_bar = ProgressBar.new()
			hp_bar.custom_minimum_size = Vector2(130, 10)
			hp_bar.max_value = max_hp
			hp_bar.value = hp
			hp_bar.show_percentage = false
			var hp_bg = StyleBoxFlat.new()
			hp_bg.bg_color = Color(0.15, 0.05, 0.05, 0.9)
			hp_bg.corner_radius_top_left = 3
			hp_bg.corner_radius_top_right = 3
			hp_bg.corner_radius_bottom_left = 3
			hp_bg.corner_radius_bottom_right = 3
			var hp_fill = StyleBoxFlat.new()
			hp_fill.bg_color = Color(0.85, 0.25, 0.25, 1.0)
			hp_fill.corner_radius_top_left = 2
			hp_fill.corner_radius_top_right = 2
			hp_fill.corner_radius_bottom_left = 2
			hp_fill.corner_radius_bottom_right = 2
			hp_bar.add_theme_stylebox_override("background", hp_bg)
			hp_bar.add_theme_stylebox_override("fill", hp_fill)
			vbox.add_child(hp_bar)
			var atk_bar = ProgressBar.new()
			atk_bar.custom_minimum_size = Vector2(130, 10)
			atk_bar.max_value = 30
			atk_bar.value = atk
			atk_bar.show_percentage = false
			var atk_bg = StyleBoxFlat.new()
			atk_bg.bg_color = Color(0.1, 0.08, 0.05, 0.9)
			atk_bg.corner_radius_top_left = 3
			atk_bg.corner_radius_top_right = 3
			atk_bg.corner_radius_bottom_left = 3
			atk_bg.corner_radius_bottom_right = 3
			var atk_fill = StyleBoxFlat.new()
			atk_fill.bg_color = Color(0.95, 0.6, 0.2, 1.0)
			atk_fill.corner_radius_top_left = 2
			atk_fill.corner_radius_top_right = 2
			atk_fill.corner_radius_bottom_left = 2
			atk_fill.corner_radius_bottom_right = 2
			atk_bar.add_theme_stylebox_override("background", atk_bg)
			atk_bar.add_theme_stylebox_override("fill", atk_fill)
			vbox.add_child(atk_bar)
		else:
			# Empty slot with dashed-style placeholder
			var empty_label = Label.new()
			empty_label.text = "+"
			empty_label.add_theme_font_size_override("font_size", 36)
			empty_label.add_theme_color_override("font_color", Color(0.4, 0.35, 0.3))
			empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			vbox.add_child(empty_label)

func _update_start_button() -> void:
	# Enable start button only if at least 1 soul selected
	_start_button.disabled = _selected_souls.is_empty()

func _on_map_selected(map_id: String) -> void:
	_selected_map = map_id
	# Update highlights (cards are PanelContainer, not Button)
	for child in _map_container.get_children():
		if child is PanelContainer:
			if child.name == "MapCard_" + map_id:
				child.modulate = Color(1.2, 1.1, 0.8)
			else:
				child.modulate = Color(1.0, 1.0, 1.0)

func _on_tactic_selected(tactic_id: String) -> void:
	_selected_tactic = tactic_id
	# Update highlights
	for child in _tactic_container.get_children():
		if child is Button:
			if child.name == "TacticBtn_" + tactic_id:
				child.modulate = Color(1.2, 1.1, 0.7)
			else:
				var tactic_data = TACTICS.get(tactic_id, {})
				child.modulate = tactic_data.get("color", Color(1, 1, 1))

func _on_difficulty_selected(diff_id: String) -> void:
	_selected_difficulty = diff_id
	# Update highlights
	for child in _difficulty_container.get_children():
		if child is Button:
			if child.name == "DiffBtn_" + diff_id:
				child.modulate = Color(1.2, 1.1, 0.7)
			else:
				var diff_data = DIFFICULTIES.get(diff_id, {})
				child.modulate = diff_data.get("color", Color(1, 1, 1))

func _on_start_battle() -> void:
	# Get difficulty settings
	var diff_data: Dictionary = DIFFICULTIES[_selected_difficulty]
	var hp_mult: float = diff_data["hp_mult"]
	var atk_mult: float = diff_data["atk_mult"]
	var ai_level: float = diff_data["ai_level"]

	# GAP-001: Build player team (4 souls) - auto-fill if less than 4 selected
	var player_team: Array = []
	var player_level: int = 1
	if _selected_souls.size() > 0:
		player_level = _selected_souls[0].get("level", 1)
	# Add selected souls first
	for soul in _selected_souls:
		if player_team.size() < 4:
			player_team.append(soul)
	# Auto-fill remaining slots with random element souls
	var fill_elements = ["fire", "water", "earth", "wind", "thunder", "ice", "light", "dark"]
	var element_names = {"fire": "炎灵", "water": "水灵", "earth": "岩灵", "wind": "风灵", "thunder": "雷灵", "ice": "冰灵", "light": "光灵", "dark": "暗灵"}
	while player_team.size() < 4:
		var elem = fill_elements[randi() % fill_elements.size()]
		player_team.append({
			"id": "player_soul_%02d" % (player_team.size() + 1),
			"name": element_names.get(elem, elem),
			"element": elem,
			"level": player_level,
			"hp": 100 + player_level * 10,
			"attack": 12 + player_level * 2,
			"defense": 8 + player_level,
			"is_player": true
		})

	# GAP-001: Build AI team (4 souls) with different elements and difficulty-scaled stats
	var ai_team: Array = []
	var ai_elements = ["fire", "water", "earth", "wind", "thunder", "ice", "light", "dark"]
	ai_elements.shuffle()
	for i in 4:
		var ai_elem = ai_elements[i % ai_elements.size()]
		ai_team.append({
			"id": "ai_soul_%02d" % (i + 1),
			"name": "敌方" + element_names.get(ai_elem, ai_elem),
			"element": ai_elem,
			"level": player_level,
			"hp": int((100 + player_level * 10) * hp_mult),
			"attack": int((12 + player_level * 2) * atk_mult),
			"defense": int((8 + player_level) * hp_mult),
			"is_player": false,
			"difficulty": _selected_difficulty,
			"ai_level": ai_level
		})

	# Save battle config to GameState in team battle format (GAP-001)
	GameState.set_value("battle", "player_souls", player_team)
	GameState.set_value("battle", "ai_souls", ai_team)
	GameState.set_value("battle", "map_name", MAPS[_selected_map]["name"])
	GameState.set_value("battle", "tactic", _selected_tactic)
	GameState.set_value("battle", "difficulty", _selected_difficulty)
	GameState.set_value("battle", "is_team_battle", true)

	# Also store single soul for backward compatibility
	if player_team.size() > 0:
		GameState.set_value("battle", "player_soul", player_team[0])
	if ai_team.size() > 0:
		GameState.set_value("battle", "ai_soul", ai_team[0])

	# Also store for battle config scene reference
	var config: Dictionary = {
		"map": _selected_map,
		"tactic": _selected_tactic,
		"difficulty": _selected_difficulty,
		"player_souls": player_team,
		"ai_souls": ai_team,
		"map_name": MAPS[_selected_map]["name"],
		"tactic_name": TACTICS[_selected_tactic]["name"],
		"difficulty_name": diff_data["name"],
		"is_team_battle": true
	}
	GameState.set_value("game", "battle_config", config)

	# Play battle start sound
	if AudioManager:
		AudioManager.play_sfx("ui_button_click")
		AudioManager.play_sfx("battle_start")

	# Transition to battle scene
	SceneManager.change_scene("res://scenes/rts_arena.tscn")

func _on_back() -> void:
	SceneManager.change_scene("res://scenes/soul_select.tscn")

func _highlight_button(btn: Button, selected: bool) -> void:
	# Visual feedback for selected state
	if selected:
		btn.modulate = Color(1.2, 1.1, 0.8)  # Gold tint for selected
	else:
		btn.modulate = Color(1, 1, 1)
