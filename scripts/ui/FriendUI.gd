extends Control
## FriendUI - Friend management interface
## Follows GDD v2.0 Chapter 11: Battle Modes (Friend System UI)
## M2.11 Battle Modes - Friend System UI
##
## Displays friend list, friend requests, and provides basic
## friend management actions.

## Friend system
const FriendSystem = preload("res://scripts/game/FriendSystem.gd")

## Friend system instance
var _friend_system: FriendSystem = null

## UI nodes
var _friend_count_label: Label = null
var _online_count_label: Label = null
var _friend_list: VBoxContainer = null
var _request_list: VBoxContainer = null
var _add_friend_button: Button = null
var _refresh_button: Button = null
var _back_button: Button = null
var _tab_container: TabContainer = null

## Element colors
var _element_colors: Dictionary = {
	"fire": Color(1.0, 0.4, 0.2),
	"water": Color(0.2, 0.5, 1.0),
	"earth": Color(0.6, 0.4, 0.2),
	"wind": Color(0.3, 0.9, 0.6),
	"thunder": Color(0.8, 0.6, 1.0),
	"ice": Color(0.5, 0.9, 1.0),
	"dark": Color(0.5, 0.3, 0.7),
	"light": Color(1.0, 0.9, 0.4)
}


func _ready() -> void:
	_friend_system = FriendSystem.new()
	add_child(_friend_system)
	_find_ui_nodes()
	_setup_ui()
	_refresh_friend_list()
	_refresh_request_list()
	_update_counts()
	GameLog.info("FriendUI: Ready", "UI")

	# Apply 9-slice panel style to all Panel nodes
	var panel_style_path = "res://assets/ui/ui_character_select_panel_style.tres"
	var panel_style_to_apply = null
	if ResourceLoader.exists(panel_style_path):
		panel_style_to_apply = load(panel_style_path)
	else:
		panel_style_to_apply = StyleBoxFlat.new()
		panel_style_to_apply.bg_color = Color(0.08, 0.05, 0.15, 0.9)
		panel_style_to_apply.border_color = Color(0.83, 0.66, 0.36)
		panel_style_to_apply.border_width_left = 2
		panel_style_to_apply.border_width_right = 2
		panel_style_to_apply.border_width_top = 2
		panel_style_to_apply.border_width_bottom = 2
		panel_style_to_apply.corner_radius_top_left = 8
		panel_style_to_apply.corner_radius_top_right = 8
		panel_style_to_apply.corner_radius_bottom_left = 8
		panel_style_to_apply.corner_radius_bottom_right = 8
	if panel_style_to_apply:
		for child in get_children():
			if child is Panel or child is PanelContainer:
				child.add_theme_stylebox_override("panel", panel_style_to_apply)
			for grandchild in child.get_children():
				if grandchild is Panel or grandchild is PanelContainer:
					grandchild.add_theme_stylebox_override("panel", panel_style_to_apply)



func _find_ui_nodes() -> void:
	_friend_count_label = get_node_or_null("TopBar/FriendCountLabel")
	_online_count_label = get_node_or_null("TopBar/OnlineCountLabel")
	_friend_list = get_node_or_null("Main/FriendListPanel/ScrollContainer/FriendContainer")
	_request_list = get_node_or_null("Main/RequestListPanel/ScrollContainer/RequestContainer")
	_add_friend_button = get_node_or_null("BottomBar/AddFriendButton")
	_refresh_button = get_node_or_null("BottomBar/RefreshButton")
	_back_button = get_node_or_null("BottomBar/BackButton")
	_tab_container = get_node_or_null("Main/TabContainer")


func _setup_ui() -> void:
	if _add_friend_button:
		_add_friend_button.pressed.connect(_on_add_friend_pressed)
		_setup_button_hover(_add_friend_button)

	if _refresh_button:
		_refresh_button.pressed.connect(_on_refresh_pressed)
		_setup_button_hover(_refresh_button)

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


func _refresh_friend_list() -> void:
	if _friend_list == null:
		return

	# Clear existing
	for child in _friend_list.get_children():
		child.queue_free()

	var friends = _friend_system.get_friends()

	if friends.is_empty():
		var empty_label = Label.new()
		empty_label.text = "还没有好友\n点击下方按钮添加好友吧！"
		empty_label.add_theme_font_size_override("font_size", 14)
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		empty_label.horizontal_alignment = 1
		_friend_list.add_child(empty_label)
		return

	for friend in friends:
		_friend_list.add_child(_create_friend_item(friend))


func _create_friend_item(p_friend: Dictionary) -> Control:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(0, 70)

	var hbox = HBoxContainer.new()
	hbox.layout_mode = 1
	hbox.anchors_preset = 15
	hbox.anchor_right = 1.0
	hbox.anchor_bottom = 1.0
	hbox.offset_left = 5.0
	hbox.offset_top = 5.0
	hbox.offset_right = -5.0
	hbox.offset_bottom = -5.0
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	# Friend avatar (element-colored square with first letter)
	var avatar_container = VBoxContainer.new()
	avatar_container.custom_minimum_size = Vector2(48, 0)
	avatar_container.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(avatar_container)

	var avatar_bg = ColorRect.new()
	avatar_bg.custom_minimum_size = Vector2(40, 40)
	var element_color = _element_colors.get(p_friend["element"], Color(0.5, 0.5, 0.5))
	avatar_bg.color = Color(element_color.r * 0.6, element_color.g * 0.6, element_color.b * 0.6, 0.9)
	avatar_container.add_child(avatar_bg)

	var avatar_label = Label.new()
	avatar_label.text = p_friend["name"].substr(0, 1)
	avatar_label.add_theme_font_size_override("font_size", 18)
	avatar_label.add_theme_color_override("font_color", Color.WHITE)
	avatar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar_label.position = Vector2(0, -38)
	avatar_label.custom_minimum_size = Vector2(40, 40)
	avatar_container.add_child(avatar_label)

	# Status indicator
	var status_vbox = VBoxContainer.new()
	status_vbox.custom_minimum_size = Vector2(16, 0)
	status_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(status_vbox)

	var status_color = _friend_system.get_status_color(p_friend["status"])
	var status_dot = ColorRect.new()
	status_dot.custom_minimum_size = Vector2(12, 12)
	status_dot.color = status_color
	status_vbox.add_child(status_dot)

	# Name and level
	var name_vbox = VBoxContainer.new()
	name_vbox.size_flags_horizontal = 3
	hbox.add_child(name_vbox)

	var name_label = Label.new()
	name_label.text = p_friend["name"]
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", _element_colors.get(p_friend["element"], Color.WHITE))
	name_vbox.add_child(name_label)

	var level_label = Label.new()
	level_label.text = "Lv.%d  %s" % [p_friend["level"], _friend_system.get_status_name(p_friend["status"])]
	level_label.add_theme_font_size_override("font_size", 11)
	level_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	name_vbox.add_child(level_label)

	# Action buttons
	var button_vbox = VBoxContainer.new()
	button_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(button_vbox)

	var button_hbox = HBoxContainer.new()
	button_hbox.add_theme_constant_override("separation", 5)
	button_vbox.add_child(button_hbox)

	var message_button = Button.new()
	message_button.text = "私聊"
	message_button.custom_minimum_size = Vector2(60, 30)
	message_button.add_theme_font_size_override("font_size", 11)
	message_button.pressed.connect(func():
		_on_message_pressed(p_friend["id"], p_friend["name"])
	)
	_setup_button_hover(message_button)
	button_hbox.add_child(message_button)

	var remove_button = Button.new()
	remove_button.text = "删除"
	remove_button.custom_minimum_size = Vector2(60, 30)
	remove_button.add_theme_font_size_override("font_size", 11)
	remove_button.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	remove_button.pressed.connect(func():
		_on_remove_friend_pressed(p_friend["id"], p_friend["name"])
	)
	_setup_button_hover(remove_button)
	button_hbox.add_child(remove_button)

	return panel

func _refresh_request_list() -> void:
	if _request_list == null:
		return

	# Clear existing
	for child in _request_list.get_children():
		child.queue_free()

	var requests = _friend_system.get_incoming_requests()

	if requests.is_empty():
		var empty_label = Label.new()
		empty_label.text = "没有待处理的好友请求"
		empty_label.add_theme_font_size_override("font_size", 14)
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		empty_label.horizontal_alignment = 1
		_request_list.add_child(empty_label)
		return

	for req in requests:
		_request_list.add_child(_create_request_item(req))


func _create_request_item(p_request: Dictionary) -> Control:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(0, 50)

	var hbox = HBoxContainer.new()
	hbox.layout_mode = 1
	hbox.anchors_preset = 15
	hbox.anchor_right = 1.0
	hbox.anchor_bottom = 1.0
	hbox.offset_left = 5.0
	hbox.offset_top = 5.0
	hbox.offset_right = -5.0
	hbox.offset_bottom = -5.0
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	var name_label = Label.new()
	name_label.text = p_request.get("from_name", "未知玩家")
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.size_flags_horizontal = 3
	hbox.add_child(name_label)

	var accept_button = Button.new()
	accept_button.text = "接受"
	accept_button.custom_minimum_size = Vector2(60, 30)
	accept_button.add_theme_font_size_override("font_size", 11)
	accept_button.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	accept_button.pressed.connect(func():
		_friend_system.accept_friend_request(p_request["request_id"])
		_refresh_friend_list()
		_refresh_request_list()
		_update_counts()
	)
	_setup_button_hover(accept_button)
	hbox.add_child(accept_button)

	var reject_button = Button.new()
	reject_button.text = "拒绝"
	reject_button.custom_minimum_size = Vector2(60, 30)
	reject_button.add_theme_font_size_override("font_size", 11)
	reject_button.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	reject_button.pressed.connect(func():
		_friend_system.reject_friend_request(p_request["request_id"])
		_refresh_request_list()
	)
	_setup_button_hover(reject_button)
	hbox.add_child(reject_button)

	return panel


func _update_counts() -> void:
	if _friend_count_label:
		_friend_count_label.text = "好友: %d/%d" % [_friend_system.get_friend_count(), FriendSystem.MAX_FRIENDS]
	if _online_count_label:
		_online_count_label.text = "在线: %d" % _friend_system.get_online_friend_count()


func _on_add_friend_pressed() -> void:
	# In offline mode, add a simulated friend for demo
	var names = ["剑灵使者", "幻影刺客", "星辰守护", "烈焰战魂", "冰霜法师"]
	var elements = ["fire", "water", "earth", "wind", "thunder", "ice", "dark", "light"]
	var random_name = names[randi() % names.size()]
	var random_element = elements[randi() % elements.size()]
	var random_level = randi_range(1, 30)
	var random_status = randi() % 4  # Random status for demo

	var result = _friend_system.add_friend(
		"player_%d" % randi(),
		random_name,
		random_level,
		random_element
	)
	if result["success"]:
		# Set random status for demo
		_friend_system.set_friend_status(result["friend_id"], random_status)
		_refresh_friend_list()
		_update_counts()
		GameLog.info("FriendUI: Added friend %s" % random_name, "UI")


func _on_refresh_pressed() -> void:
	_refresh_friend_list()
	_refresh_request_list()
	_update_counts()
	GameLog.info("FriendUI: Refreshed", "UI")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	GameLog.info("FriendUI: Back to main menu", "UI")


func _on_message_pressed(p_friend_id: String, p_friend_name: String) -> void:
	GameLog.info("FriendUI: Open chat with %s" % p_friend_name, "UI")


func _on_remove_friend_pressed(p_friend_id: String, p_friend_name: String) -> void:
	var result = _friend_system.remove_friend(p_friend_id)
	if result["success"]:
		_refresh_friend_list()
		_update_counts()
		GameLog.info("FriendUI: Removed friend %s" % p_friend_name, "UI")
