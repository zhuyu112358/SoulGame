extends Control
## SoulSelect - Soul selection scene controller (Diablo 3 style redesign)
##
## Large portrait center display, character bar at bottom, detail panel on right.
## Inspired by Diablo 3 character selection / StarCraft race selection.

const FontLoader = preload("res://scripts/core/FontLoader.gd")

@onready var _title_label: Label = $TitleLabel
@onready var _subtitle_label: Label = $SubtitleLabel
@onready var _portrait_texture: TextureRect = $PortraitContainer/PortraitTexture
@onready var _soul_name_label: Label = $SoulNameLabel
@onready var _soul_element_label: Label = $SoulElementLabel
@onready var _stats_label: Label = $DetailPanel/DetailVBox/StatsLabel
@onready var _skills_label: Label = $DetailPanel/DetailVBox/SkillsLabel
@onready var _description_label: Label = $DetailPanel/DetailVBox/DescriptionLabel
@onready var _character_bar: HBoxContainer = $CharacterBar
@onready var _back_button: Button = $BackButton
@onready var _start_button: Button = $StartButton

var _souls: Array = []
var _selected_index: int = -1
var _character_buttons: Array = []
var _portrait_glow: ColorRect = null
var _portrait_frame: Panel = null
var _stat_bars: Dictionary = {}

## Compatibility: soul list alias for tests
var _soul_list: VBoxContainer = null

## Individual portrait textures (8 element portraits)
var _portrait_textures: Dictionary = {}
const PORTRAIT_PATH_TEMPLATE := "res://assets/art/characters/character_%s_soul_portrait.png"

## Element name mapping for portrait files (shadow = dark)
const ELEMENT_FILE_NAMES := {
	"fire": "fire",
	"water": "water",
	"earth": "earth",
	"wind": "wind",
	"thunder": "thunder",
	"ice": "ice",
	"dark": "shadow",
	"light": "light"
}

## Element display names
const ELEMENT_DISPLAY_NAMES := {
	"fire": "火元素",
	"water": "水元素",
	"earth": "土元素",
	"wind": "风元素",
	"thunder": "雷元素",
	"ice": "冰元素",
	"dark": "暗元素",
	"light": "光元素"
}

## Element descriptions
const ELEMENT_DESCRIPTIONS := {
	"fire": "炽热的火焰灵魂，拥有强大的爆发伤害和暴击能力。擅长快速击杀敌人，但生命值较低。",
	"water": "温柔的水元素灵魂，拥有治疗和辅助能力。可以为队友恢复生命，是团队中不可或缺的支援。",
	"earth": "坚韧的土元素灵魂，拥有极高的生命值和防御力。是团队中的坚实盾牌，保护队友免受伤害。",
	"wind": "轻盈的风元素灵魂，拥有极高的速度和闪避能力。擅长游击战术，让敌人难以捉摸。",
	"thunder": "狂暴的雷元素灵魂，拥有最高的攻击力但生命脆弱。是典型的玻璃大炮，一击必杀。",
	"ice": "冷静的冰元素灵魂，拥有控制和减速能力。可以冻结敌人，为团队创造输出机会。",
	"dark": "神秘的暗元素灵魂，拥有吸血和消耗能力。通过吸取敌人生命来维持自身战斗。",
	"light": "圣洁的光元素灵魂，拥有保护和护盾能力。可以为队友提供护盾，抵御致命伤害。"
}


func _ready() -> void:
	GameLog.info("SoulSelect initialized (Diablo 3 style redesign)", "SoulSelect")
	_apply_ui_theme()
	FontLoader.apply_font_to_control(self)
	_back_button.pressed.connect(_on_back_pressed)
	_start_button.pressed.connect(_on_start_pressed)
	_setup_button_hover(_back_button)
	_setup_button_hover(_start_button)
	_load_portrait_textures()
	_load_available_souls()
	_populate_soul_list()
	_play_select_music()
	_setup_portrait_frame()
	_setup_stat_bars()
	_animate_entrance()


## Setup decorative frame and glow around main portrait
func _setup_portrait_frame() -> void:
	if not _portrait_texture:
		return
	var container = _portrait_texture.get_parent()
	if not container:
		return

	# Element glow behind portrait
	_portrait_glow = ColorRect.new()
	_portrait_glow.color = Color(0.8, 0.6, 0.3, 0.15)
	_portrait_glow.custom_minimum_size = Vector2(420, 420)
	container.add_child(_portrait_glow)
	container.move_child(_portrait_glow, 0)

	# Gold frame border
	_portrait_frame = Panel.new()
	_portrait_frame.custom_minimum_size = Vector2(410, 410)
	var frame_style = StyleBoxFlat.new()
	frame_style.bg_color = Color(0, 0, 0, 0)
	frame_style.border_color = Color(0.9, 0.75, 0.35, 0.8)
	frame_style.border_width_left = 3
	frame_style.border_width_right = 3
	frame_style.border_width_top = 3
	frame_style.border_width_bottom = 3
	frame_style.corner_radius_top_left = 12
	frame_style.corner_radius_top_right = 12
	frame_style.corner_radius_bottom_left = 12
	frame_style.corner_radius_bottom_right = 12
	_portrait_frame.add_theme_stylebox_override("panel", frame_style)
	container.add_child(_portrait_frame)
	container.move_child(_portrait_frame, 1)

	# Pulse glow animation
	var glow_tween = create_tween()
	glow_tween.set_loops()
	glow_tween.tween_property(_portrait_glow, "color:a", 0.25, 1.5).set_ease(Tween.EASE_IN_OUT)
	glow_tween.tween_property(_portrait_glow, "color:a", 0.12, 1.5).set_ease(Tween.EASE_IN_OUT)


## Setup stat bars in detail panel (replace plain text with progress bars)
func _setup_stat_bars() -> void:
	if not _stats_label:
		return
	var detail_vbox = _stats_label.get_parent()
	if not detail_vbox:
		return

	# Hide old plain text stats label
	_stats_label.visible = false

	# Stats section title
	var stats_title = Label.new()
	stats_title.text = "属 性"
	stats_title.add_theme_font_size_override("font_size", 18)
	stats_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
	detail_vbox.add_child(stats_title)

	# Create stat bars: HP, ATK, DEF
	var stats = [
		{"key": "hp", "label": "生命值", "color": Color(0.9, 0.3, 0.3), "max": 200},
		{"key": "attack", "label": "攻击力", "color": Color(0.95, 0.7, 0.2), "max": 40},
		{"key": "defense", "label": "防御力", "color": Color(0.3, 0.6, 0.95), "max": 30},
	]
	for s in stats:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var stat_label = Label.new()
		stat_label.text = s["label"]
		stat_label.custom_minimum_size = Vector2(60, 0)
		stat_label.add_theme_font_size_override("font_size", 13)
		stat_label.add_theme_color_override("font_color", Color(0.8, 0.78, 0.72))
		row.add_child(stat_label)

		var bar = ProgressBar.new()
		bar.custom_minimum_size = Vector2(180, 18)
		bar.max_value = s["max"]
		bar.value = 0
		bar.show_percentage = false
		var bar_style = StyleBoxFlat.new()
		bar_style.bg_color = Color(0.1, 0.08, 0.15, 0.8)
		bar_style.corner_radius_top_left = 3
		bar_style.corner_radius_top_right = 3
		bar_style.corner_radius_bottom_left = 3
		bar_style.corner_radius_bottom_right = 3
		bar.add_theme_stylebox_override("background", bar_style)
		var fill_style = StyleBoxFlat.new()
		fill_style.bg_color = s["color"]
		fill_style.corner_radius_top_left = 3
		fill_style.corner_radius_top_right = 3
		fill_style.corner_radius_bottom_left = 3
		fill_style.corner_radius_bottom_right = 3
		bar.add_theme_stylebox_override("fill", fill_style)
		row.add_child(bar)

		var value_label = Label.new()
		value_label.text = "0"
		value_label.custom_minimum_size = Vector2(36, 0)
		value_label.add_theme_font_size_override("font_size", 13)
		value_label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value_label)

		detail_vbox.add_child(row)
		_stat_bars[s["key"]] = {"bar": bar, "value": value_label, "max": s["max"]}

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	detail_vbox.add_child(spacer)


## Load individual portrait files
func _load_portrait_textures() -> void:
	for element in ELEMENT_FILE_NAMES.keys():
		var file_name = ELEMENT_FILE_NAMES[element]
		var path = PORTRAIT_PATH_TEMPLATE % file_name
		if ResourceLoader.exists(path):
			_portrait_textures[element] = load(path)
	GameLog.info("SoulSelect: Loaded %d portrait textures" % _portrait_textures.size(), "SoulSelect")


## Get portrait texture for element
func _get_portrait_texture(element: String) -> Texture2D:
	if _portrait_textures.has(element):
		return _portrait_textures[element]
	return null


## Get element color
func _get_element_color(element: String) -> Color:
	match element:
		"fire": return Color(1.0, 0.4, 0.2)
		"water": return Color(0.2, 0.5, 1.0)
		"earth": return Color(0.6, 0.5, 0.3)
		"wind": return Color(0.4, 0.9, 0.7)
		"thunder": return Color(0.9, 0.8, 0.2)
		"ice": return Color(0.5, 0.8, 1.0)
		"dark": return Color(0.6, 0.3, 0.8)
		"light": return Color(1.0, 0.9, 0.5)
	return Color(1, 1, 1)


## Animate entrance
func _animate_entrance() -> void:
	if _title_label:
		_title_label.modulate = Color(1, 1, 1, 0)
		var title_tween = create_tween()
		title_tween.tween_property(_title_label, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT)
	if _back_button:
		_back_button.modulate = Color(1, 1, 1, 0)
		var back_tween = create_tween()
		back_tween.tween_interval(0.3)
		back_tween.tween_property(_back_button, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)
	if _start_button:
		_start_button.modulate = Color(1, 1, 1, 0)
		var start_tween = create_tween()
		start_tween.tween_interval(0.5)
		start_tween.tween_property(_start_button, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)


## Setup button hover effects
func _setup_button_hover(p_button: Button) -> void:
	if p_button == null:
		return
	if not p_button.mouse_entered.is_connected(_on_button_hover.bind(p_button)):
		p_button.mouse_entered.connect(_on_button_hover.bind(p_button))
	if not p_button.mouse_exited.is_connected(_on_button_exit.bind(p_button)):
		p_button.mouse_exited.connect(_on_button_exit.bind(p_button))


func _on_button_hover(p_button: Button) -> void:
	_play_hover_sound()
	var target = p_button.get_meta("card_root", p_button) as Control
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "scale", Vector2(1.05, 1.05), 0.15)
	tween.parallel().tween_property(target, "modulate", Color(1.2, 1.1, 0.8), 0.15)


func _on_button_exit(p_button: Button) -> void:
	var target = p_button.get_meta("card_root", p_button) as Control
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "scale", Vector2(1.0, 1.0), 0.2)
	tween.parallel().tween_property(target, "modulate", Color(1.0, 1.0, 1.0), 0.2)


func _play_hover_sound() -> void:
	if AudioManager:
		AudioManager.play_sfx("ui_soul_select_hover")


func _play_select_music() -> void:
	if AudioManager:
		AudioManager.play_bgm("menu")
		# Play aurora icefield environment ambience
		AudioManager.play_sfx("env_aurora_icefield")
		GameLog.info("SoulSelect: Playing menu BGM", "SoulSelect")


## Load available souls
func _load_available_souls() -> void:
	_souls = []
	var invalid_names := ["main_menu", "rts_arena", "soul_select", "home", "battle", "menu"]
	if PlatformSDK:
		var soul_list = PlatformSDK.list_souls()
		if soul_list.size() > 0:
			for soul in soul_list:
				var soul_name: String = soul.get("name", "")
				if soul_name == "" or invalid_names.has(soul_name.to_lower()):
					continue
				if not soul.has("hp"):
					soul["hp"] = 100 + soul.get("level", 1) * 10
				if not soul.has("attack"):
					soul["attack"] = 12 + soul.get("level", 1) * 2
				if not soul.has("defense"):
					soul["defense"] = 8 + soul.get("level", 1)
				_souls.append(soul)

	if _souls.size() == 0:
		_souls = [
			{"id": "soul_fire_01", "name": "炎灵", "element": "fire", "level": 1, "hp": 100, "attack": 15, "defense": 8},
			{"id": "soul_water_01", "name": "水灵", "element": "water", "level": 1, "hp": 120, "attack": 12, "defense": 10},
			{"id": "soul_earth_01", "name": "岩灵", "element": "earth", "level": 1, "hp": 150, "attack": 10, "defense": 15},
			{"id": "soul_wind_01", "name": "风灵", "element": "wind", "level": 1, "hp": 90, "attack": 18, "defense": 6},
			{"id": "soul_thunder_01", "name": "雷灵", "element": "thunder", "level": 1, "hp": 85, "attack": 20, "defense": 5},
			{"id": "soul_ice_01", "name": "冰灵", "element": "ice", "level": 1, "hp": 110, "attack": 14, "defense": 11},
			{"id": "soul_dark_01", "name": "暗灵", "element": "dark", "level": 1, "hp": 95, "attack": 16, "defense": 9},
			{"id": "soul_light_01", "name": "光灵", "element": "light", "level": 1, "hp": 130, "attack": 11, "defense": 12},
		]


## Populate character bar with soul portrait cards (portrait + name)
func _populate_soul_list() -> void:
	for child in _character_bar.get_children():
		child.queue_free()
	_character_buttons.clear()

	for i in range(_souls.size()):
		var soul = _souls[i]
		var element_color = _get_element_color(soul["element"])

		# Card root: Button with transparent bg, VBox child
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(96, 120)
		btn.tooltip_text = soul["name"]
		btn.flat = true

		# Transparent normal style
		var transparent = StyleBoxEmpty.new()
		btn.add_theme_stylebox_override("normal", transparent)
		btn.add_theme_stylebox_override("hover", transparent)
		btn.add_theme_stylebox_override("pressed", transparent)
		btn.add_theme_stylebox_override("disabled", transparent)

		# Card VBox: portrait + name
		var card_vbox = VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 4)
		card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		btn.add_child(card_vbox)

		# Portrait frame panel
		var portrait_panel = Panel.new()
		portrait_panel.custom_minimum_size = Vector2(80, 80)
		var panel_style = StyleBoxFlat.new()
		panel_style.bg_color = Color(0.06, 0.04, 0.12, 0.9)
		panel_style.border_color = element_color * 0.7
		panel_style.border_width_left = 2
		panel_style.border_width_right = 2
		panel_style.border_width_top = 2
		panel_style.border_width_bottom = 2
		panel_style.corner_radius_top_left = 6
		panel_style.corner_radius_top_right = 6
		panel_style.corner_radius_bottom_left = 6
		panel_style.corner_radius_bottom_right = 6
		portrait_panel.add_theme_stylebox_override("panel", panel_style)
		portrait_panel.set_meta("base_style", panel_style)
		card_vbox.add_child(portrait_panel)

		# Portrait texture inside panel
		var portrait_tex = TextureRect.new()
		portrait_tex.custom_minimum_size = Vector2(72, 72)
		portrait_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var portrait = _get_portrait_texture(soul["element"])
		if portrait:
			portrait_tex.texture = portrait
		portrait_panel.add_child(portrait_tex)

		# Name label
		var name_label = Label.new()
		name_label.text = soul["name"]
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_vbox.add_child(name_label)

		btn.set_meta("card_root", btn)
		btn.set_meta("portrait_panel", portrait_panel)
		btn.set_meta("name_label", name_label)
		btn.set_meta("element_color", element_color)

		btn.pressed.connect(_on_soul_selected.bind(i))

		# Hover: scale up + brighten border
		btn.mouse_entered.connect(func():
			var t = create_tween()
			t.set_parallel(true)
			t.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.15).set_ease(Tween.EASE_OUT)
			var pp = btn.get_meta("portrait_panel") as Panel
			if pp:
				var hs = pp.get_meta("base_style") as StyleBoxFlat
				var hover_s = StyleBoxFlat.new()
				hover_s.bg_color = Color(0.1, 0.07, 0.18, 0.95)
				hover_s.border_color = element_color * 1.3
				hover_s.border_width_left = 2
				hover_s.border_width_right = 2
				hover_s.border_width_top = 2
				hover_s.border_width_bottom = 2
				hover_s.corner_radius_top_left = 6
				hover_s.corner_radius_top_right = 6
				hover_s.corner_radius_bottom_left = 6
				hover_s.corner_radius_bottom_right = 6
				pp.add_theme_stylebox_override("panel", hover_s)
			var nl = btn.get_meta("name_label") as Label
			if nl:
				nl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
		)
		btn.mouse_exited.connect(func():
			var t = create_tween()
			t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT)
			var pp = btn.get_meta("portrait_panel") as Panel
			if pp and i != _selected_index:
				pp.add_theme_stylebox_override("panel", pp.get_meta("base_style"))
			var nl = btn.get_meta("name_label") as Label
			if nl and i != _selected_index:
				nl.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
		)

		_character_bar.add_child(btn)
		_character_buttons.append(btn)

		# Staggered fade in
		btn.modulate = Color(1, 1, 1, 0)
		var btn_tween = create_tween()
		btn_tween.tween_interval(0.3 + i * 0.08)
		btn_tween.tween_property(btn, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)


## Called when a soul is selected from character bar
func _on_soul_selected(index: int) -> void:
	_selected_index = index
	var soul = _souls[index]

	# Update large portrait
	var portrait = _get_portrait_texture(soul["element"])
	if portrait:
		_portrait_texture.texture = portrait
		# Portrait entrance animation
		_portrait_texture.modulate = Color(1, 1, 1, 0)
		_portrait_texture.scale = Vector2(0.9, 0.9)
		var portrait_tween = create_tween()
		portrait_tween.set_parallel(true)
		portrait_tween.tween_property(_portrait_texture, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)
		portrait_tween.tween_property(_portrait_texture, "scale", Vector2(1.0, 1.0), 0.4).set_ease(Tween.EASE_OUT)
		portrait_tween.set_parallel(false)
		# Start breathing animation after entrance
		portrait_tween.tween_callback(_start_portrait_breathing)

	# Update name and element
	_soul_name_label.text = "%s  [Lv.%d]" % [soul["name"], soul["level"]]
	var element_name = ELEMENT_DISPLAY_NAMES.get(soul["element"], soul["element"])
	_soul_element_label.text = element_name
	_soul_element_label.modulate = _get_element_color(soul["element"])

	# Update detail panel
	var hp = soul.get("hp", 100)
	var atk = soul.get("attack", 12)
	var def = soul.get("defense", 8)
	_stats_label.text = "【属性】\n生命值: %d\n攻击力: %d\n防御力: %d" % [hp, atk, def]

	_skills_label.text = "【技能】\n重击 (Heavy Strike)\n快速攻击 (Quick Strike)\n元素爆发 (Element Burst)"

	var desc = ELEMENT_DESCRIPTIONS.get(soul["element"], "神秘的灵魂战士。")
	_description_label.text = "【背景】\n%s" % desc

	# Highlight selected button, unhighlight others
	for i in range(_character_buttons.size()):
		var btn = _character_buttons[i]
		if i == _selected_index:
			btn.modulate = Color(1.2, 1.1, 0.7)
			btn.scale = Vector2(1.1, 1.1)
		else:
			btn.modulate = Color(1, 1, 1)
			btn.scale = Vector2(1.0, 1.0)

	# Enable start button
	_start_button.disabled = false

	# Play select sound
	_play_soul_select_sound(soul["element"])


## Start portrait breathing animation
func _start_portrait_breathing() -> void:
	if _portrait_texture == null:
		return
	var breath_tween = create_tween()
	breath_tween.set_loops()
	breath_tween.tween_property(_portrait_texture, "scale", Vector2(1.03, 1.03), 1.5).set_ease(Tween.EASE_IN_OUT)
	breath_tween.tween_property(_portrait_texture, "scale", Vector2(1.0, 1.0), 1.5).set_ease(Tween.EASE_IN_OUT)


## Play soul select sound
func _play_soul_select_sound(p_element: String) -> void:
	if AudioManager:
		match p_element:
			"fire": AudioManager.play_sfx("soul_angry_roar")
			"water": AudioManager.play_sfx("soul_calm_meditation")
			"earth": AudioManager.play_sfx("soul_brave_courage")
			"wind": AudioManager.play_sfx("soul_joyful")
			"light": AudioManager.play_sfx("soul_confident")
			"dark": AudioManager.play_sfx("soul_serene")
			_: AudioManager.play_sfx("ui_soul_select_hover")


## Start battle with selected soul
func _on_start_pressed() -> void:
	if _selected_index < 0 or _selected_index >= _souls.size():
		return
	var soul = _souls[_selected_index]
	_start_battle(soul)


func _start_battle(soul: Dictionary) -> void:
	GameLog.info("Soul selected: %s, entering battle config" % soul["name"], "SoulSelect")
	# Store selected soul in GameState for BattleConfig to read
	GameState.set_value("battle", "selected_soul", soul)
	GameState.set_value("game", "selected_soul", soul)
	# Also store in battle_config format
	GameState.set_value("game", "battle_config", {"player_souls": [soul]})
	# Play transition sounds
	if AudioManager:
		AudioManager.play_sfx("soul_excited")
		AudioManager.play_sfx("ui_soul_select_confirm")
	# Change to battle config scene
	if SceneManager:
		SceneManager.change_scene("res://scenes/battle_config.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/battle_config.tscn")


func _on_back_pressed() -> void:
	if AudioManager:
		AudioManager.play_sfx("ui_button_click")
	if SceneManager:
		SceneManager.change_scene("res://scenes/main_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _apply_ui_theme() -> void:
	_title_label.add_theme_font_size_override("font_size", 40)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	_subtitle_label.add_theme_font_size_override("font_size", 16)
	_subtitle_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))

	# Apply character select panel style (9-slice UI component)
	var panel_style_path = "res://assets/ui/ui_character_select_panel_style.tres"
	if ResourceLoader.exists(panel_style_path):
		var panel_style = load(panel_style_path)
		if panel_style:
			_detail_panel.add_theme_stylebox_override("panel", panel_style)
	else:
		# Fallback to StyleBoxFlat if 9-slice style not available
		var fallback_style = StyleBoxFlat.new()
		fallback_style.bg_color = Color(0.08, 0.05, 0.15, 0.9)
		fallback_style.border_color = Color(0.83, 0.66, 0.36)
		fallback_style.border_width_left = 3
		fallback_style.border_width_right = 3
		fallback_style.border_width_top = 3
		fallback_style.border_width_bottom = 3
		fallback_style.corner_radius_top_left = 10
		fallback_style.corner_radius_top_right = 10
		fallback_style.corner_radius_bottom_left = 10
		fallback_style.corner_radius_bottom_right = 10
		_detail_panel.add_theme_stylebox_override("panel", fallback_style)


## Compatibility: legacy soul card creation (tests expect this method)
func _create_soul_card(soul: Dictionary, index: int) -> Control:
	var card_root = Control.new()
	var click_button = Button.new()
	_setup_button_hover(click_button)
	card_root.add_child(click_button)
	return card_root
