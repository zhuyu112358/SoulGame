extends Control
## SoulDebugPanel - Real-time soul state inspector for debugging
##
## Attach to any Control node, set `target_soul` to a Soul instance,
## and the panel will display live personality, emotion, memory, and
## cognitive state. Useful for debugging NPC AI in Battleplan.
##
## Usage:
##   var panel = preload("res://addons/ember/debug/soul_debug_panel.tscn").instantiate()
##   panel.target_soul = my_soul
##   add_child(panel)

@export var target_soul: Soul = null
@export var auto_refresh: bool = true
@export var refresh_interval: float = 0.5

var _refresh_timer: float = 0.0

# UI references (assigned in _build_ui)
var name_label: Label = null
var status_label: Label = null
var personality_box: VBoxContainer = null
var emotion_box: VBoxContainer = null
var memory_box: VBoxContainer = null
var cognitive_label: Label = null


func _ready() -> void:
	# Create UI programmatically if scene nodes don't exist
	_build_ui()
	_refresh()


func _process(delta: float) -> void:
	if not auto_refresh or target_soul == null:
		return
	_refresh_timer += delta
	if _refresh_timer >= refresh_interval:
		_refresh_timer = 0.0
		_refresh()


func set_soul(soul: Soul) -> void:
	target_soul = soul
	_refresh()


func _refresh() -> void:
	if target_soul == null:
		if name_label: name_label.text = "No soul selected"
		return

	var status = target_soul.get_status()

	# Name and basic status
	if name_label:
		name_label.text = "%s (Lv.%d) %s" % [
			status.get("name", "?"),
			status.get("level", 0),
			"ALIVE" if status.get("is_alive", true) else "DEAD"
		]

	if status_label:
		var stats = status.get("stats", {})
		var hp = stats.get("health", 0)
		var max_hp = stats.get("max_health", 1)
		status_label.text = "HP: %d/%d  |  XP: %d  |  ID: %s" % [
			int(hp), int(max_hp), int(status.get("experience", 0)), status.get("id", "?")
		]

	# Personality
	_refresh_personality()

	# Emotion
	_refresh_emotion()

	# Memory
	_refresh_memory()

	# Cognitive
	if cognitive_label:
		var cog = status.get("cognitive", {})
		cognitive_label.text = "Cognitive: %d decisions, phase=%s" % [
			int(cog.get("decisions_made", 0)),
			cog.get("current_phase", "?")
		]


func _refresh_personality() -> void:
	if personality_box == null or target_soul == null:
		return
	var p = target_soul.get_personality()
	if p == null:
		return

	_clear_container(personality_box)

	_add_trait_bar(personality_box, "Openness", p.get_openness())
	_add_trait_bar(personality_box, "Conscientiousness", p.get_conscientiousness())
	_add_trait_bar(personality_box, "Extraversion", p.get_extraversion())
	_add_trait_bar(personality_box, "Agreeableness", p.get_agreeableness())
	_add_trait_bar(personality_box, "Neuroticism", p.get_neuroticism())
	_add_trait_bar(personality_box, "Aggression", p.get_aggression())

	var style_label = Label.new()
	style_label.text = "Style: %s" % p.get_behavior_style()
	personality_box.add_child(style_label)


func _add_trait_bar(parent: Node, label_text: String, value: float) -> void:
	var row = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(120, 0)
	var bar = ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 1
	bar.value = value
	bar.custom_minimum_size = Vector2(100, 16)
	var val = Label.new()
	val.text = "%.2f" % value
	row.add_child(label)
	row.add_child(bar)
	row.add_child(val)
	parent.add_child(row)


func _refresh_emotion() -> void:
	if emotion_box == null or target_soul == null:
		return
	var e = target_soul.get_emotion()
	if e == null:
		return

	_clear_container(emotion_box)

	# PAD values
	_add_pad_bar(emotion_box, "Pleasure", e.get_pleasure(), -1.0, 1.0)
	_add_pad_bar(emotion_box, "Arousal", e.get_arousal(), 0.0, 1.0)
	_add_pad_bar(emotion_box, "Dominance", e.get_dominance(), 0.0, 1.0)

	# Dominant emotion and mood
	var dom_label = Label.new()
	dom_label.text = "Dominant: %s  |  Mood: %s (%.2f)" % [
		e.get_dominant_emotion(), e.get_mood(), e.get_mood_intensity()
	]
	emotion_box.add_child(dom_label)


func _add_pad_bar(parent: Node, label_text: String, value: float, min_v: float, max_v: float) -> void:
	var row = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(80, 0)
	var bar = ProgressBar.new()
	bar.min_value = min_v
	bar.max_value = max_v
	bar.value = value
	bar.custom_minimum_size = Vector2(100, 16)
	var val = Label.new()
	val.text = "%.2f" % value
	row.add_child(label)
	row.add_child(bar)
	row.add_child(val)
	parent.add_child(row)


func _refresh_memory() -> void:
	if memory_box == null or target_soul == null:
		return
	var mem = target_soul.get_memory()
	if mem == null:
		return

	_clear_container(memory_box)

	var summary = mem.get_memory_summary()
	var count_label = Label.new()
	count_label.text = "Total: %d  |  Working: %d  |  Short: %d  |  Long: %d" % [
		int(summary.get("total_count", 0)),
		int(summary.get("working_memory_count", 0)),
		int(summary.get("short_term_count", 0)),
		int(summary.get("long_term_count", 0))
	]
	memory_box.add_child(count_label)

	# Recent memories
	var recent = mem.get_recent_memories(5)
	for m in recent:
		var mem_label = Label.new()
		var content = str(m.get("content", "?"))
		if content.length() > 50:
			content = content.substr(0, 47) + "..."
		mem_label.text = "- [%.1f] %s" % [m.get("importance", 0), content]
		mem_label.add_theme_font_size_override("font_size", 10)
		memory_box.add_child(mem_label)


func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _build_ui() -> void:
	# If UI nodes already exist from scene file, skip
	if name_label != null:
		return

	# Build minimal UI programmatically
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	custom_minimum_size = Vector2(320, 400)

	var panel = Panel.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)

	var margin = MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(status_label)

	# Personality section
	var p_label = Label.new()
	p_label.text = "--- Personality ---"
	p_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(p_label)

	var p_scroll = ScrollContainer.new()
	p_scroll.name = "PersonalityScroll"
	p_scroll.custom_minimum_size = Vector2(0, 120)
	vbox.add_child(p_scroll)

	personality_box = VBoxContainer.new()
	personality_box.name = "Contents"
	p_scroll.add_child(personality_box)

	# Emotion section
	var e_label = Label.new()
	e_label.text = "--- Emotion ---"
	e_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(e_label)

	var e_scroll = ScrollContainer.new()
	e_scroll.name = "EmotionScroll"
	e_scroll.custom_minimum_size = Vector2(0, 80)
	vbox.add_child(e_scroll)

	emotion_box = VBoxContainer.new()
	emotion_box.name = "Contents"
	e_scroll.add_child(emotion_box)

	# Memory section
	var m_label = Label.new()
	m_label.text = "--- Memory ---"
	m_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(m_label)

	var m_scroll = ScrollContainer.new()
	m_scroll.name = "MemoryScroll"
	m_scroll.custom_minimum_size = Vector2(0, 100)
	vbox.add_child(m_scroll)

	memory_box = VBoxContainer.new()
	memory_box.name = "Contents"
	m_scroll.add_child(memory_box)

	cognitive_label = Label.new()
	cognitive_label.name = "CognitiveLabel"
	cognitive_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(cognitive_label)
