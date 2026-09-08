@tool
extends Control
## Ember Soul Inspector Dock
## Editor dock for inspecting Soul instances during playtesting.
## Scans the current scene tree for nodes with Soul references and displays their state.

var _selected_soul: Soul = null
var _soul_nodes: Array = []  # Array of {node, soul_path}
var _refresh_timer: float = 0.0
var _auto_refresh: bool = true

# UI nodes
var _scan_button: Button = null
var _refresh_check: CheckBox = null
var _soul_list: ItemList = null
var _info_label: RichTextLabel = null
var _personality_label: RichTextLabel = null
var _emotion_label: RichTextLabel = null
var _memory_label: RichTextLabel = null
var _tab_container: TabContainer = null


func _ready() -> void:
	_build_ui()


func _process(delta: float) -> void:
	if not _auto_refresh:
		return
	_refresh_timer += delta
	if _refresh_timer >= 0.5:
		_refresh_timer = 0.0
		_refresh_info()


func _build_ui() -> void:
	# Main layout
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# Header
	var header = Label.new()
	header.text = "Ember Soul Inspector"
	header.add_theme_font_size_override("font_size", 14)
	vbox.add_child(header)

	# Controls row
	var controls = HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	vbox.add_child(controls)

	_scan_button = Button.new()
	_scan_button.text = "Scan Scene"
	_scan_button.pressed.connect(_on_scan)
	controls.add_child(_scan_button)

	_refresh_check = CheckBox.new()
	_refresh_check.text = "Auto"
	_refresh_check.button_pressed = true
	_refresh_check.toggled.connect(_on_auto_refresh_toggled)
	controls.add_child(_refresh_check)

	# Soul list
	_soul_list = ItemList.new()
	_soul_list.custom_minimum_size = Vector2(0, 100)
	_soul_list.item_selected.connect(_on_soul_selected)
	vbox.add_child(_soul_list)

	# Tabs for detailed info
	_tab_container = TabContainer.new()
	_tab_container.custom_minimum_size = Vector2(0, 200)
	vbox.add_child(_tab_container)

	# Overview tab
	_info_label = RichTextLabel.new()
	_info_label.bbcode_enabled = true
	_info_label.scroll_following = false
	_tab_container.add_child(_info_label)
	_tab_container.set_tab_title(0, "Overview")

	# Personality tab
	_personality_label = RichTextLabel.new()
	_personality_label.bbcode_enabled = true
	_tab_container.add_child(_personality_label)
	_tab_container.set_tab_title(1, "Personality")

	# Emotion tab
	_emotion_label = RichTextLabel.new()
	_emotion_label.bbcode_enabled = true
	_tab_container.add_child(_emotion_label)
	_tab_container.set_tab_title(2, "Emotion")

	# Memory tab
	_memory_label = RichTextLabel.new()
	_memory_label.bbcode_enabled = true
	_tab_container.add_child(_memory_label)
	_tab_container.set_tab_title(3, "Memory")


func _on_scan() -> void:
	_soul_nodes.clear()
	_soul_list.clear()
	_selected_soul = null

	var scene_root = get_tree().current_scene
	if scene_root == null:
		_info_label.text = "[i]No scene loaded. Run the game to inspect souls.[/i]"
		return

	_scan_node(scene_root)

	if _soul_nodes.is_empty():
		_info_label.text = "[i]No Soul instances found in scene.[/i]\n\nTip: Souls are usually stored in script variables on NPC nodes."
	else:
		for entry in _soul_nodes:
			_soul_list.add_item(entry.node.name)


func _scan_node(node: Node) -> void:
	# Check if this node has a Soul variable
	if node.has_method("get_soul") or node.get("soul") != null:
		var soul = null
		if node.has_method("get_soul"):
			soul = node.get_soul()
		elif node.get("soul") != null:
			soul = node.get("soul")
		if soul != null and soul is Soul:
			_soul_nodes.append({"node": node, "soul": soul})

	# Recurse children
	for child in node.get_children():
		_scan_node(child)


func _on_soul_selected(index: int) -> void:
	if index >= 0 and index < _soul_nodes.size():
		_selected_soul = _soul_nodes[index].soul
		_refresh_info()


func _on_auto_refresh_toggled(pressed: bool) -> void:
	_auto_refresh = pressed


func _refresh_info() -> void:
	if _selected_soul == null:
		return

	var status = _selected_soul.get_status()

	# Overview
	var text = "[b]%s[/b] (Lv.%d)\n" % [status.get("name", "?"), status.get("level", 0)]
	text += "ID: %s\n" % status.get("id", "?")
	text += "Alive: %s\n" % str(status.get("is_alive", true))
	var stats = status.get("stats", {})
	text += "HP: %s / %s\n" % [str(stats.get("health", "?")), str(stats.get("max_health", "?"))]
	text += "XP: %s\n\n" % str(status.get("experience", 0))

	var cog = status.get("cognitive", {})
	text += "[b]Cognitive[/b]\n"
	text += "Decisions: %s\n" % str(cog.get("decisions_made", 0))
	text += "Phase: %s\n" % str(cog.get("current_phase", "?"))
	_info_label.text = text

	# Personality
	var p = _selected_soul.get_personality()
	if p:
		var ptext = "[b]Big Five[/b]\n"
		ptext += "Openness: %.2f\n" % p.get_openness()
		ptext += "Conscientiousness: %.2f\n" % p.get_conscientiousness()
		ptext += "Extraversion: %.2f\n" % p.get_extraversion()
		ptext += "Agreeableness: %.2f\n" % p.get_agreeableness()
		ptext += "Neuroticism: %.2f\n" % p.get_neuroticism()
		ptext += "Aggression: %.2f\n\n" % p.get_aggression()
		var style = p.get_behavior_style()
		ptext += "[b]Style[/b]\n%s" % str(style)
		_personality_label.text = ptext

	# Emotion
	var e = _selected_soul.get_emotion()
	if e:
		var etext = "[b]PAD Model[/b]\n"
		etext += "Pleasure: %.2f\n" % e.get_pleasure()
		etext += "Arousal: %.2f\n" % e.get_arousal()
		etext += "Dominance: %.2f\n\n" % e.get_dominance()
		etext += "[b]Mood[/b]\n"
		etext += "Dominant: %s\n" % str(e.get_dominant_emotion())
		etext += "Mood: %s (%.2f)\n" % [str(e.get_mood()), e.get_mood_intensity()]
		_emotion_label.text = etext

	# Memory
	var m = _selected_soul.get_memory()
	if m:
		var summary = m.get_memory_summary()
		var mtext = "[b]Memory Counts[/b]\n"
		mtext += "Total: %s\n" % str(summary.get("total_count", 0))
		mtext += "Working: %s\n" % str(summary.get("working_memory_count", 0))
		mtext += "Short-term: %s\n" % str(summary.get("short_term_count", 0))
		mtext += "Long-term: %s\n\n" % str(summary.get("long_term_count", 0))
		mtext += "[b]Recent Memories[/b]\n"
		var recent = m.get_recent_memories(10)
		for mem in recent:
			var content = str(mem.get("content", "?"))
			if content.length() > 60:
				content = content.substr(0, 57) + "..."
			mtext += "- [%.1f] %s\n" % [mem.get("importance", 0), content]
		if recent.is_empty():
			mtext += "(none)"
		_memory_label.text = mtext
