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
	_setup_ui_styles()
	GameLog.info("CollectionUI: Ready (game-level UI)", "UI")

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
	panel.custom_minimum_size = Vector2(180, 96)

	# Rarity-colored border style
	var rarity = p_item.get("rarity", "common")
	var rarity_color = _rarity_colors.get(rarity, Color(0.7, 0.7, 0.7))
	var card_style = StyleBoxFlat.new()
	if p_item["collected"]:
		card_style.bg_color = Color(0.08, 0.05, 0.15, 0.92)
		card_style.border_color = rarity_color
	else:
		card_style.bg_color = Color(0.05, 0.05, 0.08, 0.7)
		card_style.border_color = Color(0.3, 0.3, 0.35, 0.5)
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_left = 8
	card_style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", card_style)

	# Hover effect: scale up + brighter border
	var hover_tween = null
	panel.mouse_entered.connect(func():
		var s = panel.get_theme_stylebox("panel")
		if s and s is StyleBoxFlat:
			s.border_width_left = 3
			s.border_width_right = 3
			s.border_width_top = 3
			s.border_width_bottom = 3
			if p_item["collected"]:
				s.border_color = rarity_color.lightened(0.3)
		panel.scale = Vector2(1.03, 1.03)
	)
	panel.mouse_exited.connect(func():
		var s = panel.get_theme_stylebox("panel")
		if s and s is StyleBoxFlat:
			s.border_width_left = 2
			s.border_width_right = 2
			s.border_width_top = 2
			s.border_width_bottom = 2
			if p_item["collected"]:
				s.border_color = rarity_color
		panel.scale = Vector2(1.0, 1.0)
	)

	var hbox = HBoxContainer.new()
	hbox.layout_mode = 1
	hbox.anchors_preset = 15
	hbox.anchor_right = 1.0
	hbox.anchor_bottom = 1.0
	hbox.offset_left = 8.0
	hbox.offset_top = 8.0
	hbox.offset_right = -8.0
	hbox.offset_bottom = -8.0
	panel.add_child(hbox)

	# Item icon
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(48, 48)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(icon_rect)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	if p_item["collected"]:
		# Load item icon based on item id
		var item_id = p_item.get("id", "")
		var icon_map = {
			"health_potion": "item_consumable_health_potion.png",
			"energy_potion": "item_consumable_energy_potion.png",
			"attack_boost": "item_buff_attack_boost.png",
			"defense_boost": "item_buff_defense_boost.png",
			"speed_boost": "item_buff_speed_boost.png",
			"crit_boost": "item_buff_focus.png",
			"shield": "item_buff_shield.png",
			"revive": "item_consumable_revival_potion.png",
			"teleport": "item_special_teleport_scroll.png",
			"invisibility": "item_buff_invisibility.png",
			"damage_amplify": "item_buff_attack_boost.png",
			"heal_aura": "item_consumable_full_restore.png",
			"energy_surge": "item_consumable_energy_potion.png",
			"rage": "item_buff_attack_boost.png",
			"freeze": "item_special_smoke_bomb.png",
			"lightning": "item_special_flash_bang.png",
			"soul_stone": "item_special_summon_stone.png"
		}
		var icon_file = icon_map.get(item_id, "")
		if icon_file != "":
			var icon_path = "res://assets/art/items/%s" % icon_file
			if ResourceLoader.exists(icon_path):
				icon_rect.texture = load(icon_path)

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
	panel.custom_minimum_size = Vector2(180, 86)

	# Art card style
	var art_style = StyleBoxFlat.new()
	if p_art.get("unlocked", false):
		art_style.bg_color = Color(0.08, 0.05, 0.15, 0.92)
		art_style.border_color = Color(0.83, 0.66, 0.36, 0.7)
	else:
		art_style.bg_color = Color(0.05, 0.05, 0.08, 0.7)
		art_style.border_color = Color(0.3, 0.3, 0.35, 0.5)
	art_style.border_width_left = 2
	art_style.border_width_right = 2
	art_style.border_width_top = 2
	art_style.border_width_bottom = 2
	art_style.corner_radius_top_left = 8
	art_style.corner_radius_top_right = 8
	art_style.corner_radius_bottom_left = 8
	art_style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", art_style)

	# Hover effect
	panel.mouse_entered.connect(func():
		var s = panel.get_theme_stylebox("panel")
		if s and s is StyleBoxFlat:
			s.border_color = Color(0.95, 0.78, 0.45, 1.0)
		panel.scale = Vector2(1.03, 1.03)
	)
	panel.mouse_exited.connect(func():
		var s = panel.get_theme_stylebox("panel")
		if s and s is StyleBoxFlat:
			s.border_color = Color(0.83, 0.66, 0.36, 0.7)
		panel.scale = Vector2(1.0, 1.0)
	)

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
	panel.custom_minimum_size = Vector2(180, 86)

	# Trap card style
	var trap_style = StyleBoxFlat.new()
	if p_trap.get("discovered", false):
		trap_style.bg_color = Color(0.08, 0.05, 0.15, 0.92)
		trap_style.border_color = Color(0.9, 0.4, 0.3, 0.7)
	else:
		trap_style.bg_color = Color(0.05, 0.05, 0.08, 0.7)
		trap_style.border_color = Color(0.3, 0.3, 0.35, 0.5)
	trap_style.border_width_left = 2
	trap_style.border_width_right = 2
	trap_style.border_width_top = 2
	trap_style.border_width_bottom = 2
	trap_style.corner_radius_top_left = 8
	trap_style.corner_radius_top_right = 8
	trap_style.corner_radius_bottom_left = 8
	trap_style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", trap_style)

	# Hover effect
	panel.mouse_entered.connect(func():
		var s = panel.get_theme_stylebox("panel")
		if s and s is StyleBoxFlat:
			s.border_color = Color(1.0, 0.5, 0.4, 1.0)
		panel.scale = Vector2(1.03, 1.03)
	)
	panel.mouse_exited.connect(func():
		var s = panel.get_theme_stylebox("panel")
		if s and s is StyleBoxFlat:
			s.border_color = Color(0.9, 0.4, 0.3, 0.7)
		panel.scale = Vector2(1.0, 1.0)
	)

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


## Apply game-level UI styles to panels and buttons
func _setup_ui_styles() -> void:
	# Top bar and bottom bar: dark purple + gold border
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = Color(0.06, 0.04, 0.12, 0.95)
	bar_style.border_color = Color(0.83, 0.66, 0.36, 0.6)
	bar_style.border_width_left = 2
	bar_style.border_width_right = 2
	bar_style.border_width_top = 2
	bar_style.border_width_bottom = 2
	bar_style.corner_radius_top_left = 8
	bar_style.corner_radius_top_right = 8
	bar_style.corner_radius_bottom_left = 8
	bar_style.corner_radius_bottom_right = 8

	var top_bar = get_node_or_null("TopBar")
	if top_bar and top_bar is Panel:
		top_bar.add_theme_stylebox_override("panel", bar_style)
	var bottom_bar = get_node_or_null("BottomBar")
	if bottom_bar and bottom_bar is Panel:
		bottom_bar.add_theme_stylebox_override("panel", bar_style)

	# Back button: three-state style
	if _back_button:
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

	# Progress labels: gold
	if _total_progress_label:
		_total_progress_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
		_total_progress_label.add_theme_font_size_override("font_size", 16)

	GameLog.info("CollectionUI: Game-level UI styles applied", "UI")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	GameLog.info("CollectionUI: Back to main menu", "UI")
