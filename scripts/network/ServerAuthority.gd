extends RefCounted
class_name ServerAuthority
## ServerAuthority - Server-authoritative architecture interface
##
## In M2 prototype, all calculations run locally (client-side simulation).
## This class provides the abstraction layer for future server-authoritative
## validation. All battle state changes go through this interface so that
## when a real server is added, only the implementation changes.
##
## Architecture:
## - Client sends input commands only (move, attack, skill)
## - Server validates and calculates damage/cooldown/movement
## - Client receives authoritative state updates
## - M2: local simulation with server validation hooks reserved
##
## Anti-cheat:
## - Critical operations have signature fields reserved
## - State snapshots can be verified against server
## - Input commands are timestamped for replay validation

## Server authority mode
enum AuthorityMode {
	LOCAL_SIMULATION,  # M2 prototype: all local
	CLIENT_PREDICT,    # Client predicts, server corrects
	SERVER_ONLY        # Full server authority
}

## Current authority mode (M2: LOCAL_SIMULATION)
var _mode: int = AuthorityMode.LOCAL_SIMULATION

## Pending input commands awaiting server validation
var _pending_commands: Array = []

## Server validation callback (null in local mode)
var _validation_callback: Callable = Callable()

## Input command sequence number (for ordering and replay)
var _sequence_number: int = 0

## State snapshot history (for verification)
var _snapshot_history: Array = []
var _max_snapshots: int = 60  # 1 second at 60fps


## Initialize server authority
func _init() -> void:
	pass


## Set authority mode
func set_mode(p_mode: int) -> void:
	_mode = p_mode
	GameLog.info("ServerAuthority: Mode set to %d" % p_mode, "Network")


## Get current authority mode
func get_mode() -> int:
	return _mode


## Submit an input command from client
## In local mode, immediately applies locally
## In server mode, sends to server for validation
##
## Command format:
## {
##   "type": "move" | "attack" | "skill",
##   "player_id": "soul_id",
##   "target": Vector2 | soul_id,
##   "skill_id": "skill_name",
##   "timestamp": float,
##   "sequence": int,
##   "signature": ""  # Reserved for future cryptographic signing
## }
func submit_command(p_command: Dictionary) -> Dictionary:
	# Add sequence number and timestamp
	p_command["sequence"] = _sequence_number
	p_command["timestamp"] = Time.get_ticks_msec() / 1000.0
	p_command["signature"] = ""  # Reserved field

	_sequence_number += 1

	match _mode:
		AuthorityMode.LOCAL_SIMULATION:
			# M2: apply locally immediately
			return _apply_command_local(p_command)
		AuthorityMode.CLIENT_PREDICT:
			# Predict locally, queue for server validation
			_pending_commands.append(p_command)
			return _apply_command_local(p_command)
		AuthorityMode.SERVER_ONLY:
			# Queue for server, don't apply locally
			_pending_commands.append(p_command)
			return {"status": "pending", "sequence": p_command["sequence"]}

	return {"status": "error", "message": "Unknown authority mode"}


## Apply command locally (M2 simulation)
func _apply_command_local(p_command: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"status": "applied",
		"sequence": p_command["sequence"],
		"validated": false,  # Not server-validated in local mode
		"server_timestamp": 0.0
	}

	# Route to appropriate handler
	match p_command.get("type", ""):
		"move":
			result["action"] = "move"
		"attack":
			result["action"] = "attack"
		"skill":
			result["action"] = "skill"
		_:
			result["status"] = "error"
			result["message"] = "Unknown command type"

	return result


## Validate a command (server-side, called when server responds)
func validate_command(p_sequence: int, p_valid: bool, p_server_state: Dictionary) -> void:
	# Find and remove from pending
	for i in range(_pending_commands.size()):
		if _pending_commands[i].get("sequence", -1) == p_sequence:
			_pending_commands.remove_at(i)
			break

	if not p_valid:
		# Server rejected command - rollback client prediction
		GameLog.warning("ServerAuthority: Command %d rejected by server" % p_sequence, "Network")
		_rollback_to_state(p_server_state)


## Rollback to server state (client prediction correction)
func _rollback_to_state(p_server_state: Dictionary) -> void:
	# M2: reserved for future server-authoritative mode
	# In local mode, this is a no-op
	pass


## Take a state snapshot for verification
func take_snapshot(p_battle_state: Dictionary) -> void:
	var snapshot: Dictionary = {
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"sequence": _sequence_number,
		"state": p_battle_state.duplicate(true),
		"hash": ""  # Reserved for state hash verification
	}

	_snapshot_history.append(snapshot)
	if _snapshot_history.size() > _max_snapshots:
		_snapshot_history.pop_front()


## Get latest snapshot
func get_latest_snapshot() -> Dictionary:
	if _snapshot_history.is_empty():
		return {}
	return _snapshot_history[-1]


## Verify local state against server state
## Returns true if states match (within tolerance)
func verify_state(p_local_state: Dictionary, p_server_state: Dictionary) -> bool:
	# M2: basic field comparison
	# Future: cryptographic hash verification
	if p_local_state.is_empty() or p_server_state.is_empty():
		return false

	# Compare critical fields
	var critical_fields: Array = ["player_hp", "ai_hp", "battle_time", "battle_state"]
	for field in critical_fields:
		if p_local_state.has(field) and p_server_state.has(field):
			if p_local_state[field] != p_server_state[field]:
				GameLog.warning("ServerAuthority: State mismatch on %s: local=%s server=%s" % [
					field, str(p_local_state[field]), str(p_server_state[field])
				], "Network")
				return false

	return true


## Get pending command count
func get_pending_count() -> int:
	return _pending_commands.size()


## Get sequence number
func get_sequence() -> int:
	return _sequence_number


## Get authority info
func get_info() -> Dictionary:
	return {
		"mode": _mode,
		"mode_name": _mode_to_name(_mode),
		"sequence": _sequence_number,
		"pending_commands": _pending_commands.size(),
		"snapshots": _snapshot_history.size(),
		"server_connected": false  # M2: no real server
	}


## Convert mode to name
func _mode_to_name(p_mode: int) -> String:
	match p_mode:
		AuthorityMode.LOCAL_SIMULATION:
			return "local_simulation"
		AuthorityMode.CLIENT_PREDICT:
			return "client_predict"
		AuthorityMode.SERVER_ONLY:
			return "server_only"
	return "unknown"
