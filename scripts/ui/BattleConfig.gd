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

## Build entire UI dynamically (no .tscn file needed)
func _build_ui() -> void:
	# Root layout
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox = VBoxContainer.new()
	vbox.name = "MainVBox"
	vbox.add_theme_constant_override("separation", 15)
	center.add_child(vbox)

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

	_back_button = Button.new()
	_back_button.text = "返回"
	_back_button.custom_minimum_size = Vector2(150, 50)
	_back_button.add_theme_font_size_override("font_size", 16)
	btn_hbox.add_child(_back_button)

	_start_button = Button.new()
	_start_button.text = "开始战斗"
	_start_button.custom_minimum_size = Vector2(200, 50)
	_start_button.add_theme_font_size_override("font_size", 18)
	btn_hbox.add_child(_start_button)

	GameLog.info("BattleConfig: UI built dynamically", "UI")

func _setup_theme() -> void:
	# Apply battleplan theme (deep purple + gold)
	var theme_path := "res://assets/ui/battleplan_theme.tres"
	if ResourceLoader.exists(theme_path):
		theme = load(theme_path)

func _build_map_selection() -> void:
	# Create map selection buttons
	for map_id in MAPS.keys():
		var map_data: Dictionary = MAPS[map_id]
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(200, 120)
		btn.text = map_data["name"] + "\n" + map_data["name_en"]
		btn.tooltip_text = map_data["description"]
		btn.name = "MapBtn_" + map_id
		btn.pressed.connect(_on_map_selected.bind(map_id))
		_map_container.add_child(btn)
		# Highlight selected
		if map_id == _selected_map:
			_highlight_button(btn, true)

func _build_tactic_selection() -> void:
	# Create tactical preset buttons (2 rows x 3 columns)
	for tactic_id in TACTICS.keys():
		var tactic_data: Dictionary = TACTICS[tactic_id]
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(140, 60)
		btn.text = tactic_data["name"] + "\n" + tactic_data["name_en"]
		btn.tooltip_text = tactic_data["desc"]
		btn.name = "TacticBtn_" + tactic_id
		btn.pressed.connect(_on_tactic_selected.bind(tactic_id))
		_tactic_container.add_child(btn)
		# Highlight selected
		if tactic_id == _selected_tactic:
			_highlight_button(btn, true)

func _build_difficulty_selection() -> void:
	# Create AI difficulty selection buttons (GDD v2.0: 4 difficulties)
	for diff_id in DIFFICULTIES.keys():
		var diff_data: Dictionary = DIFFICULTIES[diff_id]
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(130, 55)
		btn.text = diff_data["name"] + "\n" + diff_data["name_en"]
		btn.tooltip_text = diff_data["desc"]
		btn.name = "DiffBtn_" + diff_id
		btn.pressed.connect(_on_difficulty_selected.bind(diff_id))
		_difficulty_container.add_child(btn)
		# Highlight selected
		if diff_id == _selected_difficulty:
			_highlight_button(btn, true)

func _build_team_display() -> void:
	# Create team slots (4 slots per GDD v2.0)
	for i in _max_team_size:
		var slot: PanelContainer = PanelContainer.new()
		slot.custom_minimum_size = Vector2(120, 140)
		slot.name = "TeamSlot_" + str(i)
		var label: Label = Label.new()
		label.text = "槽位 " + str(i + 1) + "\n(空)"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_child(label)
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
	elif GameState.has("game", "selected_soul"):
		# Legacy: single soul from old flow
		var soul: Dictionary = GameState.get_value("game", "selected_soul")
		_selected_souls = [soul]
		_update_team_display()

func _update_team_display() -> void:
	# Update team slots with selected souls
	for i in _max_team_size:
		var slot = _team_container.get_child(i)
		if slot and slot.get_child_count() > 0:
			var label: Label = slot.get_child(0)
			if i < _selected_souls.size():
				var soul: Dictionary = _selected_souls[i]
				var soul_name: String = soul.get("name", "未知")
				var element: String = soul.get("element", "unknown")
				label.text = soul_name + "\n[" + element + "]"
			else:
				label.text = "槽位 " + str(i + 1) + "\n(空)"

func _update_start_button() -> void:
	# Enable start button only if at least 1 soul selected
	_start_button.disabled = _selected_souls.is_empty()

func _on_map_selected(map_id: String) -> void:
	_selected_map = map_id
	# Update highlights
	for child in _map_container.get_children():
		if child is Button:
			_highlight_button(child, child.name == "MapBtn_" + map_id)

func _on_tactic_selected(tactic_id: String) -> void:
	_selected_tactic = tactic_id
	# Update highlights
	for child in _tactic_container.get_children():
		if child is Button:
			_highlight_button(child, child.name == "TacticBtn_" + tactic_id)

func _on_difficulty_selected(diff_id: String) -> void:
	_selected_difficulty = diff_id
	# Update highlights
	for child in _difficulty_container.get_children():
		if child is Button:
			_highlight_button(child, child.name == "DiffBtn_" + diff_id)

func _on_start_battle() -> void:
	# Get difficulty settings
	var diff_data: Dictionary = DIFFICULTIES[_selected_difficulty]
	var hp_mult: float = diff_data["hp_mult"]
	var atk_mult: float = diff_data["atk_mult"]
	var ai_level: float = diff_data["ai_level"]

	# Create AI opponent soul (random element, similar level, difficulty-scaled stats)
	var ai_elements = ["fire", "water", "earth", "wind", "light", "dark"]
	var ai_element = ai_elements[randi() % ai_elements.size()]
	var player_level: int = 1
	if _selected_souls.size() > 0:
		player_level = _selected_souls[0].get("level", 1)
	var ai_soul = {
		"id": "ai_soul_01",
		"name": "敌方灵魂",
		"element": ai_element,
		"level": player_level,
		"hp": int((100 + player_level * 10) * hp_mult),
		"attack": int((12 + player_level * 2) * atk_mult),
		"defense": int((8 + player_level) * hp_mult),
		"is_player": false,
		"difficulty": _selected_difficulty,
		"ai_level": ai_level
	}

	# Save battle config to GameState in RTSArenaController expected format
	var player_soul: Dictionary = {}
	if _selected_souls.size() > 0:
		player_soul = _selected_souls[0]

	GameState.set_value("battle", "player_soul", player_soul)
	GameState.set_value("battle", "ai_soul", ai_soul)
	GameState.set_value("battle", "map_name", MAPS[_selected_map]["name"])
	GameState.set_value("battle", "tactic", _selected_tactic)
	GameState.set_value("battle", "difficulty", _selected_difficulty)
	GameState.set_value("battle", "player_souls", _selected_souls)

	# Also store for battle config scene reference
	var config: Dictionary = {
		"map": _selected_map,
		"tactic": _selected_tactic,
		"difficulty": _selected_difficulty,
		"player_souls": _selected_souls,
		"map_name": MAPS[_selected_map]["name"],
		"tactic_name": TACTICS[_selected_tactic]["name"],
		"difficulty_name": diff_data["name"]
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
