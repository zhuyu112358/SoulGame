extends Node
## FriendSystem - Friend management system framework
## Follows GDD v2.0 Chapter 11: Battle Modes (Friend System)
## M2.11 Battle Modes - Friend System Framework
##
## Manages friend list, friend requests, online status, and basic
## social interactions. M2 provides offline/local framework for
## future online multiplayer integration.

## Friend status
enum FriendStatus {
	OFFLINE,   # Friend is offline
	ONLINE,    # Friend is online
	IN_BATTLE, # Friend is in a battle
	AWAY       # Friend is away
}

## Friend request status
enum RequestStatus {
	PENDING,   # Request pending
	ACCEPTED,  # Request accepted
	REJECTED,  # Request rejected
	EXPIRED    # Request expired
}

## Friend data structure
## {id, name, level, status, element, added_time, last_seen}

## Friend list (persistent)
var _friends: Dictionary = {}

## Friend requests (incoming)
var _incoming_requests: Array = []

## Friend requests (outgoing)
var _outgoing_requests: Array = []

## Blocked players
var _blocked: Array = []

## Max friends
const MAX_FRIENDS: int = 100

## Max pending requests
const MAX_PENDING_REQUESTS: int = 20

## Signals
signal friend_added(friend_id, friend_data)
signal friend_removed(friend_id)
signal friend_status_changed(friend_id, new_status)
signal friend_request_received(request_id, from_id, from_name)
signal friend_request_accepted(request_id, friend_id)
signal friend_request_rejected(request_id)
signal friend_message_received(friend_id, message)


func _ready() -> void:
	_load_friends()
	GameLog.info("FriendSystem: Ready with %d friends, %d pending requests" % [
		_friends.size(), _incoming_requests.size()
	], "Friends")


## Get friend list
func get_friends() -> Array:
	var result: Array = []
	for friend_id in _friends.keys():
		var friend = _friends[friend_id].duplicate()
		friend["id"] = friend_id
		result.append(friend)
	# Sort by status (online first), then by name
	result.sort_custom(func(a, b):
		if a["status"] != b["status"]:
			return a["status"] > b["status"]
		return a["name"] < b["name"]
	)
	return result


## Get friend count
func get_friend_count() -> int:
	return _friends.size()


## Get online friend count
func get_online_friend_count() -> int:
	var count = 0
	for friend_id in _friends.keys():
		if _friends[friend_id]["status"] == FriendStatus.ONLINE:
			count += 1
	return count


## Get friend by ID
func get_friend(p_friend_id: String) -> Dictionary:
	if not _friends.has(p_friend_id):
		return {}
	var friend = _friends[p_friend_id].duplicate()
	friend["id"] = p_friend_id
	return friend


## Check if player is friend
func is_friend(p_friend_id: String) -> bool:
	return _friends.has(p_friend_id)


## Add friend (after accepting request or direct add in offline mode)
func add_friend(p_friend_id: String, p_friend_name: String, p_level: int = 1, p_element: String = "fire") -> Dictionary:
	# Check max friends
	if _friends.size() >= MAX_FRIENDS:
		return {"success": false, "reason": "好友列表已满（最多%d人）" % MAX_FRIENDS}

	# Check already friend
	if _friends.has(p_friend_id):
		return {"success": false, "reason": "已经是好友了"}

	# Check blocked
	if p_friend_id in _blocked:
		return {"success": false, "reason": "该玩家已被屏蔽"}

	# Add friend
	var friend_data = {
		"name": p_friend_name,
		"level": p_level,
		"element": p_element,
		"status": FriendStatus.OFFLINE,
		"added_time": Time.get_datetime_string_from_system(),
		"last_seen": Time.get_datetime_string_from_system()
	}
	_friends[p_friend_id] = friend_data
	_save_friends()

	friend_added.emit(p_friend_id, friend_data)
	GameLog.info("FriendSystem: Added friend %s (%s)" % [p_friend_name, p_friend_id], "Friends")

	return {"success": true, "friend_id": p_friend_id, "friend_data": friend_data}


## Remove friend
func remove_friend(p_friend_id: String) -> Dictionary:
	if not _friends.has(p_friend_id):
		return {"success": false, "reason": "不是好友"}

	var friend_name = _friends[p_friend_id]["name"]
	_friends.erase(p_friend_id)
	_save_friends()

	friend_removed.emit(p_friend_id)
	GameLog.info("FriendSystem: Removed friend %s (%s)" % [friend_name, p_friend_id], "Friends")

	return {"success": true, "friend_id": p_friend_id}


## Send friend request
func send_friend_request(p_target_id: String, p_target_name: String) -> Dictionary:
	# Check already friend
	if _friends.has(p_target_id):
		return {"success": false, "reason": "已经是好友了"}

	# Check max outgoing requests
	if _outgoing_requests.size() >= MAX_PENDING_REQUESTS:
		return {"success": false, "reason": "待处理请求过多"}

	# Check already sent
	for req in _outgoing_requests:
		if req["target_id"] == p_target_id and req["status"] == RequestStatus.PENDING:
			return {"success": false, "reason": "已发送过好友请求"}

	# Create request
	var request = {
		"request_id": "req_%d_%s" % [Time.get_unix_time_from_system(), p_target_id],
		"target_id": p_target_id,
		"target_name": p_target_name,
		"status": RequestStatus.PENDING,
		"sent_time": Time.get_datetime_string_from_system()
	}
	_outgoing_requests.append(request)
	_save_friends()

	GameLog.info("FriendSystem: Sent friend request to %s" % p_target_name, "Friends")

	return {"success": true, "request": request}


## Accept friend request
func accept_friend_request(p_request_id: String) -> Dictionary:
	# Find request
	var request_idx = -1
	for i in range(_incoming_requests.size()):
		if _incoming_requests[i]["request_id"] == p_request_id:
			request_idx = i
			break

	if request_idx == -1:
		return {"success": false, "reason": "请求不存在"}

	var request = _incoming_requests[request_idx]
	if request["status"] != RequestStatus.PENDING:
		return {"success": false, "reason": "请求已处理"}

	# Add as friend
	var add_result = add_friend(request["from_id"], request["from_name"])
	if not add_result["success"]:
		return add_result

	# Mark request as accepted
	_incoming_requests[request_idx]["status"] = RequestStatus.ACCEPTED
	_save_friends()

	friend_request_accepted.emit(p_request_id, request["from_id"])

	return {"success": true, "friend_id": request["from_id"]}


## Reject friend request
func reject_friend_request(p_request_id: String) -> Dictionary:
	# Find request
	var request_idx = -1
	for i in range(_incoming_requests.size()):
		if _incoming_requests[i]["request_id"] == p_request_id:
			request_idx = i
			break

	if request_idx == -1:
		return {"success": false, "reason": "请求不存在"}

	_incoming_requests[request_idx]["status"] = RequestStatus.REJECTED
	_save_friends()

	friend_request_rejected.emit(p_request_id)

	return {"success": true}


## Get incoming friend requests
func get_incoming_requests() -> Array:
	var result: Array = []
	for req in _incoming_requests:
		if req["status"] == RequestStatus.PENDING:
			result.append(req.duplicate())
	return result


## Get outgoing friend requests
func get_outgoing_requests() -> Array:
	var result: Array = []
	for req in _outgoing_requests:
		if req["status"] == RequestStatus.PENDING:
			result.append(req.duplicate())
	return result


## Get pending request count
func get_pending_request_count() -> int:
	var count = 0
	for req in _incoming_requests:
		if req["status"] == RequestStatus.PENDING:
			count += 1
	return count


## Set friend status (simulated for offline mode)
func set_friend_status(p_friend_id: String, p_status: int) -> void:
	if not _friends.has(p_friend_id):
		return

	var old_status = _friends[p_friend_id]["status"]
	_friends[p_friend_id]["status"] = p_status

	if p_status == FriendStatus.OFFLINE:
		_friends[p_friend_id]["last_seen"] = Time.get_datetime_string_from_system()

	if old_status != p_status:
		friend_status_changed.emit(p_friend_id, p_status)


## Block player
func block_player(p_player_id: String, p_player_name: String) -> Dictionary:
	if p_player_id in _blocked:
		return {"success": false, "reason": "已经屏蔽了该玩家"}

	_blocked.append(p_player_id)

	# Remove from friends if blocked
	if _friends.has(p_player_id):
		_friends.erase(p_player_id)

	_save_friends()
	GameLog.info("FriendSystem: Blocked player %s" % p_player_name, "Friends")

	return {"success": true}


## Unblock player
func unblock_player(p_player_id: String) -> Dictionary:
	if p_player_id not in _blocked:
		return {"success": false, "reason": "没有屏蔽该玩家"}

	_blocked.erase(p_player_id)
	_save_friends()

	return {"success": true}


## Get blocked players
func get_blocked_players() -> Array:
	return _blocked.duplicate()


## Send message to friend (offline/local storage)
func send_message(p_friend_id: String, p_message: String) -> Dictionary:
	if not _friends.has(p_friend_id):
		return {"success": false, "reason": "不是好友"}

	# In offline mode, just log the message
	GameLog.info("FriendSystem: Message to %s: %s" % [p_friend_id, p_message], "Friends")

	return {"success": true, "message": p_message, "time": Time.get_datetime_string_from_system()}


## Get status name
func get_status_name(p_status: int) -> String:
	match p_status:
		FriendStatus.OFFLINE: return "离线"
		FriendStatus.ONLINE: return "在线"
		FriendStatus.IN_BATTLE: return "战斗中"
		FriendStatus.AWAY: return "离开"
	return "未知"


## Get status color
func get_status_color(p_status: int) -> Color:
	match p_status:
		FriendStatus.OFFLINE: return Color(0.5, 0.5, 0.5)
		FriendStatus.ONLINE: return Color(0.3, 0.9, 0.4)
		FriendStatus.IN_BATTLE: return Color(1.0, 0.7, 0.2)
		FriendStatus.AWAY: return Color(0.8, 0.8, 0.3)
	return Color.WHITE


## Save friends to file
func _save_friends() -> void:
	var config = ConfigFile.new()

	# Save friends
	config.set_value("system", "friend_count", _friends.size())
	for friend_id in _friends.keys():
		var section = "friend_%s" % friend_id
		var friend = _friends[friend_id]
		config.set_value(section, "name", friend["name"])
		config.set_value(section, "level", friend["level"])
		config.set_value(section, "element", friend["element"])
		config.set_value(section, "status", friend["status"])
		config.set_value(section, "added_time", friend["added_time"])
		config.set_value(section, "last_seen", friend["last_seen"])

	# Save blocked
	config.set_value("system", "blocked_count", _blocked.size())
	for i in range(_blocked.size()):
		config.set_value("blocked", "player_%d" % i, _blocked[i])

	var err = config.save("user://friends.cfg")
	if err == OK:
		GameLog.info("FriendSystem: Saved %d friends" % _friends.size(), "Friends")
	else:
		GameLog.warning("FriendSystem: Failed to save (error %d)" % err, "Friends")


## Load friends from file
func _load_friends() -> void:
	var config = ConfigFile.new()
	var err = config.load("user://friends.cfg")
	if err != OK:
		GameLog.info("FriendSystem: No saved friends data", "Friends")
		return

	# Load friends
	var sections = config.get_sections()
	for section in sections:
		if section.begins_with("friend_"):
			var friend_id = section.substr(7)  # len("friend_") = 7
			_friends[friend_id] = {
				"name": config.get_value(section, "name", "未知"),
				"level": config.get_value(section, "level", 1),
				"element": config.get_value(section, "element", "fire"),
				"status": FriendStatus.OFFLINE,  # Always offline on load
				"added_time": config.get_value(section, "added_time", ""),
				"last_seen": config.get_value(section, "last_seen", "")
			}

	# Load blocked
	var blocked_count = config.get_value("system", "blocked_count", 0)
	for i in range(blocked_count):
		var player_id = config.get_value("blocked", "player_%d" % i, "")
		if player_id != "":
			_blocked.append(player_id)

	GameLog.info("FriendSystem: Loaded %d friends, %d blocked" % [_friends.size(), _blocked.size()], "Friends")


## Add simulated friend (for testing/demo)
func add_simulated_friend(p_name: String, p_level: int, p_element: String, p_status: int) -> Dictionary:
	var friend_id = "sim_%s_%d" % [p_element, randi()]
	return add_friend(friend_id, p_name, p_level, p_element)
