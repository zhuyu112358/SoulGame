extends Control
## CollectionUI - Collection and gallery interface
## Follows GDD v2.0 Chapter 13: Achievements & Meta Game (Collection UI)
## M2.13 Achievements & Meta Game - Collection UI
##
## Displays collected items, concept art, and discovered traps.
## Unlocked content shows details, locked content shows as "???".

## Collection system
const CollectionSystem = preload("res://scripts/game/CollectionSystem.gd")

## Collection system instance
var _collection_system: CollectionSystem = null

## UI nodes
var _total_progress_label: Label = null
var _total_progress_bar: ProgressBar = null
var _tab_container: TabContainer = null
var _item_grid: GridContainer = null
var _art_grid: GridContainer = null
var _trap_grid: GridContainer = null
var _item_progress_label: Label = null
var _art_progress_label: Label = null
var _trap_progress_label: Label = null
var _back_button: Button = null

## Element colors
var _rarity_colors: Dictionary = {
	"common": Color(0.7, 0.7, 0.7),
	"uncommon": Color(0.3, 0.9, 0.4),
	"rare": Color(0.3, 0.6, 1.0),
	"epic": Color(0.7, 0.4, 1.0),
	"legendary": Color(1.0, 0.85, 0.3)
}


func _ready() -> void:
	_collection_system = CollectionSystem.new()
	add_child(_collection_system)
	_find_ui_nodes()
	_setup_ui()
	_refresh_all()
	GameLog.info("CollectionUI: Ready", "UI")

	# Apply 9-slice panel styles to TopBar and BottomBar
	var coll_panel_style_path = "res://assets/ui/ui_character_select_panel_style.tres"
	if ResourceLoader.exists(coll_panel_style_path):
		var coll_panel_style = load(coll_panel_style_path)
		if coll_panel_style:
			var top_bar = get_node_or_null("TopBar")
			if top_bar:
				top_bar.add_theme_stylebox_override("panel", coll_panel_style)
			var bottom_bar = get_node_or_null("BottomBar")
			if bottom_bar:
				bottom_bar.add_theme_stylebox_override("panel", coll_panel_style)
	else:
		var coll_fallback = StyleBoxFlat.new()
		coll_fallback.bg_color = Color(0.08, 0.05, 0.15, 0.9)
		coll_fallback.border_color = Color(0.83, 0.66, 0.36)
		coll_fallback.border_width_left = 2
		coll_fallback.border_width_right = 2
		coll_fallback.border_width_top = 2
		coll_fallback.border_width_bottom = 2
		coll_fallback.corner_radius_top_left = 8
		coll_fallback.corner_radius_top_right = 8
		coll_fallback.corner_radius_bottom_left = 8
		coll_fallback.corner_radius_bottom_right = 8
		var top_bar = get_node_or_null("TopBar")
		if top_bar:
			top_bar.add_theme_stylebox_override("panel", coll_fallback)
		var bottom_bar = get_node_or_null("BottomBar")
		if bottom_bar:
			bottom_bar.add_theme_stylebox_override("panel", coll_fallback)


func _find_ui_nodes() -> void:
	_total_progress_label = get_node_or_null("TopBar/TotalProgressLabel")
	_total_progress_bar = get_node_or_null("TopBar/TotalProgressBar")
	_tab_container = get_node_or_null("Main/TabContainer")
	_item_grid = get_node_or_null("Main/TabContainer/Items/ScrollContainer/ItemGrid")
	_art_grid = get_node_or_null("Main/TabContainer/ConceptArt/ScrollContainer/ArtGrid")
	_trap_grid = get_node_or_null("Main/TabContainer/Traps/ScrollContainer/TrapGrid")
	_item_progress_label = get_node_or_null("Main/TabContainer/Items/ProgressLabel")
	_art_progress_label = get_node_or_null("Main/TabContainer/ConceptArt/ProgressLabel")
	_trap_progress_label = get_node_or_null("Main/TabContainer/Traps/ProgressLabel")
	_back_button = get_node_or_null("BottomBar/BackButton")


func _setup_ui() -> void:
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


func _refresh_all() -> void:
	_refresh_total_progress()
	_refresh_items()
	_refresh_concept_art()
	_refresh_traps()


func _refresh_total_progress() -> void:
	var progress = _collection_system.get_total_progress()
	if _total_progress_label:
		_total_progress_label.text = "总收藏进度: %d/%d (%.0f%%)" % [
			progress["collected"], progress["total"], progress["percentage"] * 100
		]
	if _total_progress_bar:
		_total_progress_bar.value = progress["percentage"] * 100


func _refresh_items() -> void:
	if _item_grid == null:
		return

	# Clear existing
	for child in _item_grid.get_children():
		child.queue_free()

	var items = _collection_system.get_all_items()
	var progress = _collection_system.get_collection_progress(CollectionSystem.CollectionCategory.ITEM)

	if _item_progress_label:
		_item_progress_label.text = "道具: %d/%d" % [progress["collected"], progress["total"]]

	for item in items:
		_item_grid.add_child(_create_item_card(item))


func _create_item_card(p_item: Dictionary) -> Control:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(180, 80)

	var vbox = VBoxContainer.new()
	vbox.layout_mode = 1
	vbox.anchors_preset = 15
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 5.0
	vbox.offset_top = 5.0
	vbox.offset_right = -5.0
	vbox.offset_bottom = -5.0
	panel.add_child(vbox)

	if p_item["collected"]:
		# Collected - show details
		var name_label = Label.new()
		name_label.text = p_item["name"]
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.add_theme_color_override("font_color", _rarity_colors.get(p_item.get("rarity", "common"), Color.WHITE))
		vbox.add_child(name_label)

		var rarity_label = Label.new()
		rarity_label.text = _collection_system.get_rarity_name(p_item.get("rarity", "common"))
		rarity_label.add_theme_font_size_override("font_size", 10)
		rarity_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		vbox.add_child(rarity_label)

		var desc_label = Label.new()
		desc_label.text = p_item["description"]
		desc_label.add_theme_font_size_override("font_size", 9)
		desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc_label)
	else:
		# Not collected - show ???
		var unknown_label = Label.new()
		unknown_label.text = "???\n未收集"
		unknown_label.add_theme_font_size_override("font_size", 14)
		unknown_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		unknown_label.horizontal_alignment = 1
		vbox.add_child(unknown_label)

	return panel


func _refresh_concept_art() -> void:
	if _art_grid == null:
		return

	# Clear existing
	for child in _art_grid.get_children():
		child.queue_free()

	var art_list = _collection_system.get_all_concept_art()
	var progress = _collection_system.get_collection_progress(CollectionSystem.CollectionCategory.CONCEPT_ART)

	if _art_progress_label:
		_art_progress_label.text = "概念图: %d/%d" % [progress["collected"], progress["total"]]

	for art in art_list:
		_art_grid.add_child(_create_art_card(art))


func _create_art_card(p_art: Dictionary) -> Control:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(180, 80)

	var vbox = VBoxContainer.new()
	vbox.layout_mode = 1
	vbox.anchors_preset = 15
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 5.0
	vbox.offset_top = 5.0
	vbox.offset_right = -5.0
	vbox.offset_bottom = -5.0
	panel.add_child(vbox)

	if p_art["unlocked"]:
		var name_label = Label.new()
		name_label.text = p_art["name"]
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.add_theme_color_override("font_color", Color(0.85, 0.65, 0.3))
		vbox.add_child(name_label)

		var category_label = Label.new()
		category_label.text = "分类: %s" % p_art.get("category", "未知")
		category_label.add_theme_font_size_override("font_size", 10)
		category_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		vbox.add_child(category_label)

		var desc_label = Label.new()
		desc_label.text = p_art["description"]
		desc_label.add_theme_font_size_override("font_size", 9)
		desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc_label)
	else:
		var unknown_label = Label.new()
		unknown_label.text = "???\n未解锁"
		unknown_label.add_theme_font_size_override("font_size", 14)
		unknown_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		unknown_label.horizontal_alignment = 1
		vbox.add_child(unknown_label)

	return panel


func _refresh_traps() -> void:
	if _trap_grid == null:
		return

	# Clear existing
	for child in _trap_grid.get_children():
		child.queue_free()

	var traps = _collection_system.get_all_traps()
	var progress = _collection_system.get_collection_progress(CollectionSystem.CollectionCategory.TRAP)

	if _trap_progress_label:
		_trap_progress_label.text = "陷阱: %d/%d" % [progress["collected"], progress["total"]]

	for trap in traps:
		_trap_grid.add_child(_create_trap_card(trap))


func _create_trap_card(p_trap: Dictionary) -> Control:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(180, 80)

	var vbox = VBoxContainer.new()
	vbox.layout_mode = 1
	vbox.anchors_preset = 15
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 5.0
	vbox.offset_top = 5.0
	vbox.offset_right = -5.0
	vbox.offset_bottom = -5.0
	panel.add_child(vbox)

	if p_trap["discovered"]:
		var name_label = Label.new()
		name_label.text = p_trap["name"]
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
		vbox.add_child(name_label)

		var count_label = Label.new()
		count_label.text = "遇到次数: %d" % p_trap.get("encounter_count", 1)
		count_label.add_theme_font_size_override("font_size", 10)
		count_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		vbox.add_child(count_label)

		var desc_label = Label.new()
		desc_label.text = p_trap["description"]
		desc_label.add_theme_font_size_override("font_size", 9)
		desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc_label)
	else:
		var unknown_label = Label.new()
		unknown_label.text = "???\n未发现"
		unknown_label.add_theme_font_size_override("font_size", 14)
		unknown_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		unknown_label.horizontal_alignment = 1
		vbox.add_child(unknown_label)

	return panel


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	GameLog.info("CollectionUI: Back to main menu", "UI")
