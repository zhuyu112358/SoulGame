extends Control
## Battle configuration scene - map selection, tactical preset, team confirmation
## Follows GDD v2.0 Chapter 14: Complete Game Flow
## M2.1 Foundation Framework

# UI references
@onready var _map_container: HBoxContainer = $CenterContainer/VBoxContainer/MapSection/MapContainer
@onready var _tactic_container: GridContainer = $CenterContainer/VBoxContainer/TacticSection/TacticContainer
@onready var _team_container: HBoxContainer = $CenterContainer/VBoxContainer/TeamSection/TeamContainer
@onready var _start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var _back_button: Button = $CenterContainer/VBoxContainer/BackButton
@onready var _map_label: Label = $CenterContainer/VBoxContainer/MapSection/MapLabel
@onready var _tactic_label: Label = $CenterContainer/VBoxContainer/TacticSection/TacticLabel
@onready var _team_label: Label = $CenterContainer/VBoxContainer/TeamSection/TeamLabel

# Configuration state
var _selected_map: String = "aether_temple"
var _selected_tactic: String = "free"
var _selected_souls: Array = []  # Array of soul dictionaries
var _max_team_size: int = 4

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
	_setup_theme()
	_build_map_selection()
	_build_tactic_selection()
	_build_team_display()
	_connect_signals()
	_load_selected_souls()
	_update_start_button()

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
	if GameState.has("battle_config"):
		var config: Dictionary = GameState.get("battle_config")
		if config.has("player_souls"):
			_selected_souls = config["player_souls"]
			_update_team_display()
	elif GameState.has("selected_soul"):
		# Legacy: single soul from old flow
		var soul: Dictionary = GameState.get("selected_soul")
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

func _on_start_battle() -> void:
	# Create AI opponent soul (random element, similar level)
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
		"hp": 100 + player_level * 10,
		"attack": 12 + player_level * 2,
		"defense": 8 + player_level,
		"is_player": false
	}

	# Save battle config to GameState in RTSArenaController expected format
	var player_soul: Dictionary = {}
	if _selected_souls.size() > 0:
		player_soul = _selected_souls[0]

	GameState.set_value("battle", "player_soul", player_soul)
	GameState.set_value("battle", "ai_soul", ai_soul)
	GameState.set_value("battle", "map_name", MAPS[_selected_map]["name"])
	GameState.set_value("battle", "tactic", _selected_tactic)
	GameState.set_value("battle", "player_souls", _selected_souls)

	# Also store for battle config scene reference
	var config: Dictionary = {
		"map": _selected_map,
		"tactic": _selected_tactic,
		"player_souls": _selected_souls,
		"map_name": MAPS[_selected_map]["name"],
		"tactic_name": TACTICS[_selected_tactic]["name"]
	}
	GameState.set("battle_config", config)

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
