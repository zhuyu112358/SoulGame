extends Control
## GrowthVisualizer - Visualizes soul growth data with progress bars and radar chart
##
## Provides reusable UI components for displaying soul growth progress:
## - XP progress bar
## - Energy bar
## - Dimension progress bars (cognitive, emotional, skills)
## - Radar chart for sub-dimensions
## - Level display with milestone indicators
##
## Usage: Add as a child control and call set_soul_growth(data) to update.

## Soul growth data reference
var soul_growth = null

## Radar chart center position
var radar_center: Vector2 = Vector2(150, 150)

## Radar chart radius
var radar_radius: float = 100.0

## Radar chart dimensions (labels and values)
var radar_dimensions: Array = []

## Progress bars
var xp_bar: ProgressBar = null
var energy_bar: ProgressBar = null
var cognitive_bar: ProgressBar = null
var emotional_bar: ProgressBar = null
var skill_bar: ProgressBar = null

## Labels
var level_label: Label = null
var xp_label: Label = null
var milestone_label: Label = null


func _ready() -> void:
	GameLog.info("GrowthVisualizer: Initialized", "UI")
	_setup_node_refs()
	_setup_ui_styles()
	_animate_entrance()
	GameLog.info("GrowthVisualizer: Game-level UI styles applied", "UI")


## Apply game-level UI styles (panels, progress bars, text hierarchy, buttons)
func _setup_ui_styles() -> void:
	# Radar panel style - deep purple bg + gold border + rounded corners
	var radar_panel = get_node_or_null("RadarPanel")
	if radar_panel and radar_panel is Panel:
		var panel_style = StyleBoxFlat.new()
		panel_style.bg_color = Color(0.06, 0.04, 0.12, 0.9)
		panel_style.border_color = Color(0.83, 0.66, 0.36, 0.9)
		panel_style.border_width_left = 2
		panel_style.border_width_right = 2
		panel_style.border_width_top = 2
		panel_style.border_width_bottom = 2
		panel_style.corner_radius_top_left = 8
		panel_style.corner_radius_top_right = 8
		panel_style.corner_radius_bottom_left = 8
		panel_style.corner_radius_bottom_right = 8
		radar_panel.add_theme_stylebox_override("panel", panel_style)
	# Radar title - gold color, larger font
	var radar_title = get_node_or_null("RadarPanel/RadarTitle")
	if radar_title and radar_title is Label:
		radar_title.add_theme_font_size_override("font_size", 16)
		radar_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	# Level label - gold, larger
	if level_label:
		level_label.add_theme_font_size_override("font_size", 28)
		level_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	# Progress bar labels - gray-white
	for label_name in ["XPLabel", "EnergyLabel", "CognitiveLabel", "EmotionalLabel", "SkillLabel", "MilestoneLabel"]:
		var label = get_node_or_null("BarsContainer/" + label_name)
		if label and label is Label:
			label.add_theme_font_size_override("font_size", 13)
			label.add_theme_color_override("font_color", Color(0.8, 0.78, 0.72))
	# Progress bars - gold fill style
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = Color(0.1, 0.08, 0.18, 0.8)
	bar_style.border_color = Color(0.7, 0.55, 0.3, 0.6)
	bar_style.border_width_left = 1
	bar_style.border_width_right = 1
	bar_style.border_width_top = 1
	bar_style.border_width_bottom = 1
	bar_style.corner_radius_top_left = 4
	bar_style.corner_radius_top_right = 4
	bar_style.corner_radius_bottom_left = 4
	bar_style.corner_radius_bottom_right = 4
	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.9, 0.7, 0.3, 0.9)
	bar_fill.corner_radius_top_left = 3
	bar_fill.corner_radius_top_right = 3
	bar_fill.corner_radius_bottom_left = 3
	bar_fill.corner_radius_bottom_right = 3
	for bar in [xp_bar, energy_bar, cognitive_bar, emotional_bar, skill_bar]:
		if bar:
			bar.add_theme_stylebox_override("background", bar_style)
			bar.add_theme_stylebox_override("fill", bar_fill)
	# Back button - three-state StyleBoxFlat
	var back_btn = get_node_or_null("BackButton")
	if back_btn and back_btn is Button:
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
		btn_hover.bg_color = Color(0.18, 0.12, 0.3, 0.95)
		btn_hover.border_color = Color(1.0, 0.85, 0.5, 1.0)
		btn_hover.border_width_left = 2
		btn_hover.border_width_right = 2
		btn_hover.border_width_top = 2
		btn_hover.border_width_bottom = 2
		btn_hover.corner_radius_top_left = 6
		btn_hover.corner_radius_top_right = 6
		btn_hover.corner_radius_bottom_left = 6
		btn_hover.corner_radius_bottom_right = 6
		var btn_pressed = StyleBoxFlat.new()
		btn_pressed.bg_color = Color(0.08, 0.05, 0.15, 0.95)
		btn_pressed.border_color = Color(0.6, 0.45, 0.2, 0.9)
		btn_pressed.border_width_left = 2
		btn_pressed.border_width_right = 2
		btn_pressed.border_width_top = 2
		btn_pressed.border_width_bottom = 2
		btn_pressed.corner_radius_top_left = 6
		btn_pressed.corner_radius_top_right = 6
		btn_pressed.corner_radius_bottom_left = 6
		btn_pressed.corner_radius_bottom_right = 6
		back_btn.add_theme_stylebox_override("normal", btn_normal)
		back_btn.add_theme_stylebox_override("hover", btn_hover)
		back_btn.add_theme_stylebox_override("pressed", btn_pressed)
		back_btn.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
		back_btn.add_theme_font_size_override("font_size", 14)


## Animate UI entrance with staggered fade-in + scale (game-level UI)
func _animate_entrance() -> void:
	# Radar panel fade-in + scale
	var radar_panel = get_node_or_null("RadarPanel")
	if radar_panel and radar_panel is CanvasItem:
		radar_panel.modulate.a = 0.0
		radar_panel.scale = Vector2(0.9, 0.9)
		var radar_tween = create_tween()
		radar_tween.set_ease(Tween.EASE_OUT)
		radar_tween.set_trans(Tween.TRANS_BACK)
		radar_tween.tween_property(radar_panel, "modulate:a", 1.0, 0.5)
		radar_tween.parallel().tween_property(radar_panel, "scale", Vector2(1.0, 1.0), 0.5)
	# Bars container fade-in + scale
	var bars_container = get_node_or_null("BarsContainer")
	if bars_container and bars_container is CanvasItem:
		bars_container.modulate.a = 0.0
		bars_container.scale = Vector2(0.95, 0.95)
		var bars_tween = create_tween()
		bars_tween.set_ease(Tween.EASE_OUT)
		bars_tween.set_trans(Tween.TRANS_BACK)
		bars_tween.tween_interval(0.2)
		bars_tween.tween_property(bars_container, "modulate:a", 1.0, 0.4)
		bars_tween.parallel().tween_property(bars_container, "scale", Vector2(1.0, 1.0), 0.4)
	# Back button fade-in
	var back_btn = get_node_or_null("BackButton")
	if back_btn and back_btn is CanvasItem:
		back_btn.modulate.a = 0.0
		var back_tween = create_tween()
		back_tween.set_ease(Tween.EASE_OUT)
		back_tween.tween_interval(0.5)
		back_tween.tween_property(back_btn, "modulate:a", 1.0, 0.3)


## Setup references to scene nodes
func _setup_node_refs() -> void:
	level_label = get_node_or_null("BarsContainer/LevelLabel")
	xp_label = get_node_or_null("BarsContainer/XPLabel")
	xp_bar = get_node_or_null("BarsContainer/XPBar")
	energy_bar = get_node_or_null("BarsContainer/EnergyBar")
	cognitive_bar = get_node_or_null("BarsContainer/CognitiveBar")
	emotional_bar = get_node_or_null("BarsContainer/EmotionalBar")
	skill_bar = get_node_or_null("BarsContainer/SkillBar")
	milestone_label = get_node_or_null("BarsContainer/MilestoneLabel")
	# Set radar center based on panel size
	radar_center = Vector2(160, 170)

	# Auto-load active soul growth data
	if SoulManager and SoulManager.active_soul:
		set_soul_growth(SoulManager.active_soul)
		GameLog.info("GrowthVisualizer: Loaded soul %s data" % SoulManager.active_soul.soul_name, "UI")


## Set soul growth data and update display
func set_soul_growth(data) -> void:
	soul_growth = data
	_update_display()


## Update all visual elements
func _update_display() -> void:
	if not soul_growth:
		return

	_update_progress_bars()
	_update_radar_data()
	_update_labels()
	queue_redraw()


## Update progress bars
func _update_progress_bars() -> void:
	if xp_bar:
		var xp_pct = float(soul_growth.experience) / float(soul_growth.experience_to_next) * 100.0 if soul_growth.experience_to_next > 0 else 0.0
		xp_bar.value = clamp(xp_pct, 0.0, 100.0)

	if energy_bar:
		var energy = soul_growth.emotional.get("energy", 100)
		energy_bar.value = clamp(float(energy), 0.0, 100.0)

	if cognitive_bar:
		cognitive_bar.value = clamp(float(soul_growth.cognitive["level"]) / 100.0 * 100.0, 0.0, 100.0)

	if emotional_bar:
		emotional_bar.value = clamp(float(soul_growth.emotional["level"]) / 100.0 * 100.0, 0.0, 100.0)

	if skill_bar:
		skill_bar.value = clamp(float(soul_growth.skills.get("level", 1)) / 100.0 * 100.0, 0.0, 100.0)


## Update radar chart data from soul growth
func _update_radar_data() -> void:
	radar_dimensions.clear()

	if not soul_growth:
		return

	var cog = soul_growth.cognitive["sub_dimensions"]
	var emo = soul_growth.emotional["sub_dimensions"]

	# 8 dimensions for radar chart
	radar_dimensions = [
		{"label": "Perception", "value": int(cog.get("perception", {}).get("value", 10))},
		{"label": "Memory", "value": int(cog.get("memory", {}).get("value", 10))},
		{"label": "Reasoning", "value": int(cog.get("reasoning", {}).get("value", 10))},
		{"label": "Decision", "value": int(cog.get("decision", {}).get("value", 10))},
		{"label": "Empathy", "value": int(emo.get("empathy", {}).get("value", 10))},
		{"label": "Expression", "value": int(emo.get("emotion_expression", {}).get("value", 10))},
		{"label": "Attachment", "value": int(emo.get("attachment", {}).get("value", 10))},
		{"label": "Creativity", "value": int(cog.get("creativity", {}).get("value", 10))}
	]


## Update text labels
func _update_labels() -> void:
	if level_label:
		level_label.text = "Lv.%d" % soul_growth.level

	if xp_label:
		xp_label.text = "XP: %d/%d" % [soul_growth.experience, soul_growth.experience_to_next]

	if milestone_label:
		milestone_label.text = "Milestones: %d" % soul_growth.milestones.size()


## Draw radar chart
func _draw() -> void:
	if radar_dimensions.is_empty():
		return

	var count = radar_dimensions.size()
	if count < 3:
		return

	# Draw background grid
	_draw_radar_grid(count)

	# Draw data polygon
	_draw_radar_data(count)

	# Draw labels
	_draw_radar_labels(count)


## Draw radar chart background grid
func _draw_radar_grid(count: int) -> void:
	var angle_step = TAU / count

	# Draw concentric circles (4 levels)
	for ring in range(1, 5):
		var ring_radius = radar_radius * float(ring) / 4.0
		var points: PackedVector2Array = PackedVector2Array()
		for i in range(count):
			var angle = angle_step * i - PI / 2.0
			points.append(radar_center + Vector2(cos(angle), sin(angle)) * ring_radius)
		points.append(points[0])
		draw_polyline(points, Color(0.3, 0.3, 0.4, 0.5), 1.0)

	# Draw axis lines
	for i in range(count):
		var angle = angle_step * i - PI / 2.0
		var end_pos = radar_center + Vector2(cos(angle), sin(angle)) * radar_radius
		draw_line(radar_center, end_pos, Color(0.3, 0.3, 0.4, 0.5), 1.0)


## Draw radar chart data polygon
func _draw_radar_data(count: int) -> void:
	var angle_step = TAU / count
	var points: PackedVector2Array = PackedVector2Array()
	var max_value = 100.0

	for i in range(count):
		var dim = radar_dimensions[i]
		var value = clamp(float(dim["value"]) / max_value, 0.0, 1.0)
		var angle = angle_step * i - PI / 2.0
		var radius = radar_radius * value
		points.append(radar_center + Vector2(cos(angle), sin(angle)) * radius)

	# Draw filled polygon
	var colors: PackedColorArray = PackedColorArray()
	for i in range(count):
		colors.append(Color(0.4, 0.6, 1.0, 0.3))
	draw_polygon(points, colors)

	# Draw outline
	points.append(points[0])
	draw_polyline(points, Color(0.5, 0.7, 1.0, 0.9), 2.0)

	# Draw data points
	for i in range(count):
		var dim = radar_dimensions[i]
		var value = clamp(float(dim["value"]) / max_value, 0.0, 1.0)
		var angle = angle_step * i - PI / 2.0
		var radius = radar_radius * value
		var pos = radar_center + Vector2(cos(angle), sin(angle)) * radius
		draw_circle(pos, 4.0, Color(0.7, 0.85, 1.0, 1.0))


## Draw radar chart labels
func _draw_radar_labels(count: int) -> void:
	var angle_step = TAU / count
	var font = ThemeDB.fallback_font
	var font_size = 12

	for i in range(count):
		var dim = radar_dimensions[i]
		var angle = angle_step * i - PI / 2.0
		var label_pos = radar_center + Vector2(cos(angle), sin(angle)) * (radar_radius + 20.0)

		# Center align text
		var text = dim["label"]
		var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var draw_pos = label_pos - Vector2(text_size.x / 2.0, text_size.y / 2.0)

		draw_string(font, draw_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.8, 0.8, 0.9, 1.0))


## Create a default layout with progress bars and radar
func create_default_layout() -> void:
	# Clear existing children
	for child in get_children():
		child.queue_free()

	# Create radar chart area
	var radar_panel = Panel.new()
	radar_panel.name = "RadarPanel"
	radar_panel.custom_minimum_size = Vector2(300, 300)
	add_child(radar_panel)

	# Create progress bars container
	var bars_container = VBoxContainer.new()
	bars_container.name = "BarsContainer"
	bars_container.position = Vector2(320, 10)
	bars_container.custom_minimum_size = Vector2(250, 280)
	add_child(bars_container)

	# Level label
	level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.text = "Lv.1"
	level_label.add_theme_font_size_override("font_size", 20)
	bars_container.add_child(level_label)

	# XP bar
	xp_bar = _create_progress_bar("XP", bars_container)
	xp_label = Label.new()
	xp_label.name = "XPLabel"
	xp_label.text = "XP: 0/100"
	bars_container.add_child(xp_label)

	# Energy bar
	energy_bar = _create_progress_bar("Energy", bars_container)

	# Cognitive bar
	cognitive_bar = _create_progress_bar("Cognitive", bars_container)

	# Emotional bar
	emotional_bar = _create_progress_bar("Emotional", bars_container)

	# Skill bar
	skill_bar = _create_progress_bar("Skills", bars_container)

	# Milestone label
	milestone_label = Label.new()
	milestone_label.name = "MilestoneLabel"
	milestone_label.text = "Milestones: 0"
	bars_container.add_child(milestone_label)

	GameLog.info("GrowthVisualizer: Default layout created", "UI")


## Helper: create a labeled progress bar
func _create_progress_bar(label_text: String, parent: Node) -> ProgressBar:
	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 12)
	parent.add_child(label)

	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(230, 18)
	bar.max_value = 100.0
	bar.value = 0.0
	parent.add_child(bar)

	return bar
