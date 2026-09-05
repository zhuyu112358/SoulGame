extends Node
## AudioManager - Audio bus management, SFX playback, music control, and fading
##
## Manages audio buses, one-shot SFX with priority, looping music with
## cross-fade, volume control, audio groups, and audio resource caching.
## Infrastructure only - no game-specific audio.
##
## Features:
## - 5 audio buses (Master/SFX/Music/UI/Ambient)
## - SFX player pool with priority-based stealing
## - Music playback with cross-fade transitions
## - Volume control per bus and per group
## - Mute/unmute per bus
## - Audio resource caching
## - Audio groups for collective volume control
##
## Usage:
##   AudioManager.play_sfx("res://assets/audio/hit.wav")
##   AudioManager.play_music("res://assets/audio/theme.ogg", 0.5, 1.0)  # fade in 1s
##   AudioManager.set_volume("master", 0.8)
##   AudioManager.stop_music(1.0)  # fade out 1s

## Audio bus names
const BUS_MASTER := "Master"
const BUS_SFX := "SFX"
const BUS_MUSIC := "Music"
const BUS_UI := "UI"
const BUS_AMBIENT := "Ambient"

## SFX priority levels
enum Priority {
	LOW = 0,
	NORMAL = 1,
	HIGH = 2,
	CRITICAL = 3
}

## SFX player pool: [{player, priority, playing}]
var _sfx_players: Array = []
var _max_sfx_players: int = 16

## Current music player
var _music_player: AudioStreamPlayer = null

## Secondary music player for cross-fade
var _music_player_fade: AudioStreamPlayer = null

## Current music stream
var _current_music: AudioStream = null

## Whether music is playing
var _music_playing: bool = false

## Music volume (0-1)
var _music_volume: float = 0.6

## SFX volume (0-1)
var _sfx_volume: float = 0.8

## Master volume (0-1)
var _master_volume: float = 1.0

## Cached audio streams: { path: AudioStream }
var _audio_cache: Dictionary = {}

## Currently playing SFX count
var _active_sfx: int = 0

## Audio groups: { name: {volume, muted, members: [bus_names]} }
var _audio_groups: Dictionary = {}

## Active fade tweens
var _active_fades: Array = []

## Statistics
var _stats: Dictionary = {
	"sfx_played": 0,
	"music_played": 0,
	"music_stopped": 0,
	"cache_hits": 0,
	"cache_misses": 0,
	"sfx_stolen": 0,
	"fades_started": 0,
	"fades_completed": 0
}


func _ready() -> void:
	_initialize_buses()
	_initialize_sfx_pool()
	_initialize_default_groups()
	GameLog.info("AudioManager initialized (%d SFX players)" % _max_sfx_players, "Audio")


## Initialize audio buses (create if missing)
func _initialize_buses() -> void:
	var bus_count := AudioServer.bus_count
	var bus_names := []
	for i in range(bus_count):
		bus_names.append(AudioServer.get_bus_name(i))

	# Create buses if they don't exist
	for bus_name in [BUS_SFX, BUS_MUSIC, BUS_UI, BUS_AMBIENT]:
		if not bus_names.has(bus_name):
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			GameLog.debug("AudioManager: Created bus '%s'" % bus_name, "Audio")

	# Set bus send targets
	var master_idx := AudioServer.get_bus_index(BUS_MASTER)
	for bus_name in [BUS_SFX, BUS_MUSIC, BUS_UI, BUS_AMBIENT]:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx >= 0 and master_idx >= 0:
			AudioServer.set_bus_send(idx, BUS_MASTER)


## Initialize SFX player pool
func _initialize_sfx_pool() -> void:
	for i in range(_max_sfx_players):
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SFX
		player.volume_db = linear_to_db(_sfx_volume)
		player.finished.connect(_on_sfx_finished.bind(player))
		add_child(player)
		_sfx_players.append({"player": player, "priority": Priority.LOW, "playing": false})


## Initialize default audio groups
func _initialize_default_groups() -> void:
	_audio_groups = {
		"gameplay": {"volume": 1.0, "muted": false, "buses": [BUS_SFX, BUS_AMBIENT]},
		"interface": {"volume": 1.0, "muted": false, "buses": [BUS_UI]},
		"background": {"volume": 1.0, "muted": false, "buses": [BUS_MUSIC, BUS_AMBIENT]}
	}


## --- SFX Playback ---

## Play a one-shot sound effect
## volume: 0-1 (multiplied by SFX bus volume)
## pitch: 0.5-2.0
## priority: LOW/NORMAL/HIGH/CRITICAL - higher priority won't be stolen by lower
func play_sfx(path: String, volume: float = 1.0, pitch: float = 1.0, priority: int = Priority.NORMAL) -> void:
	var stream := _get_cached_stream(path)
	if stream == null:
		GameLog.warning("AudioManager: Could not load SFX: %s" % path, "Audio")
		return

	var slot := _get_free_sfx_slot(priority)
	if slot == null:
		GameLog.debug("AudioManager: SFX pool full and no lower priority to steal", "Audio")
		return

	slot["player"].stream = stream
	slot["player"].volume_db = linear_to_db(_sfx_volume * volume)
	slot["player"].pitch_scale = clamp(pitch, 0.5, 2.0)
	slot["player"].play()
	slot["priority"] = priority
	slot["playing"] = true
	_active_sfx += 1
	_stats["sfx_played"] += 1


## Play a sound effect with random pitch variation (for variety)
func play_sfx_varied(path: String, volume: float = 1.0, pitch_variation: float = 0.1, priority: int = Priority.NORMAL) -> void:
	var pitch := 1.0 + randf_range(-pitch_variation, pitch_variation)
	play_sfx(path, volume, pitch, priority)


## Play UI sound (convenience, UI bus, high priority)
func play_ui_sfx(path: String, volume: float = 1.0, pitch: float = 1.0) -> void:
	var stream := _get_cached_stream(path)
	if stream == null:
		return
	# UI sounds use a dedicated player from pool with UI bus
	var slot := _get_free_sfx_slot(Priority.HIGH)
	if slot:
		slot["player"].bus = BUS_UI
		slot["player"].stream = stream
		slot["player"].volume_db = linear_to_db(volume)
		slot["player"].pitch_scale = clamp(pitch, 0.5, 2.0)
		slot["player"].play()
		slot["priority"] = Priority.HIGH
		slot["playing"] = true
		_active_sfx += 1
		_stats["sfx_played"] += 1
		# Reset bus after playback
		slot["player"].finished.connect(_on_ui_sfx_finished.bind(slot), CONNECT_ONE_SHOT)


## Stop all SFX
func stop_all_sfx() -> void:
	for slot in _sfx_players:
		slot["player"].stop()
		slot["playing"] = false
	_active_sfx = 0


## --- Music Playback ---

## Play background music (loops by default) with optional fade in
## volume: -1 = use default music volume
## fade_in: seconds to fade in (0 = immediate)
func play_music(path: String, volume: float = -1.0, fade_in: float = 0.0) -> void:
	var stream := _get_cached_stream(path)
	if stream == null:
		GameLog.error("AudioManager: Could not load music: %s" % path, "Audio")
		return

	var target_volume := _music_volume if volume < 0 else volume

	# If music is already playing, cross-fade
	if _music_player and _music_playing:
		_crossfade_music(stream, target_volume, fade_in)
		return

	if _music_player == null:
		_music_player = AudioStreamPlayer.new()
		_music_player.bus = BUS_MUSIC
		add_child(_music_player)

	_music_player.stream = stream
	_music_player.volume_db = linear_to_db(0.0 if fade_in > 0 else target_volume)
	_music_player.play()
	_music_playing = true
	_current_music = stream
	_stats["music_played"] += 1

	if fade_in > 0:
		_fade_volume(_music_player, target_volume, fade_in)

	GameLog.info("AudioManager: Playing music: %s (fade=%.1fs)" % [path, fade_in], "Audio")


## Cross-fade between current and new music
func _crossfade_music(new_stream: AudioStream, target_volume: float, fade_duration: float) -> void:
	# Create fade player if needed
	if _music_player_fade == null:
		_music_player_fade = AudioStreamPlayer.new()
		_music_player_fade.bus = BUS_MUSIC
		add_child(_music_player_fade)

	# Swap players
	var old_player := _music_player
	_music_player = _music_player_fade
	_music_player_fade = old_player

	# Start new music
	_music_player.stream = new_stream
	_music_player.volume_db = linear_to_db(0.0)
	_music_player.play()
	_current_music = new_stream
	_stats["music_played"] += 1

	# Fade in new, fade out old
	var fade_time: float = max(float(fade_duration), 0.5)
	_fade_volume(_music_player, target_volume, fade_time)
	_fade_volume(_music_player_fade, 0.0, fade_time, func():
		_music_player_fade.stop()
	)

	GameLog.info("AudioManager: Cross-fading music (%.1fs)" % fade_time, "Audio")


## Stop music with optional fade out
func stop_music(fade_out: float = 0.0) -> void:
	if _music_player and _music_playing:
		if fade_out > 0:
			_fade_volume(_music_player, 0.0, fade_out, func():
				_music_player.stop()
				_music_playing = false
				_current_music = null
				_stats["music_stopped"] += 1
			)
		else:
			_music_player.stop()
			_music_playing = false
			_current_music = null
			_stats["music_stopped"] += 1
		GameLog.info("AudioManager: Music stopped (fade=%.1fs)" % fade_out, "Audio")


## Pause music
func pause_music() -> void:
	if _music_player and _music_playing:
		_music_player.stream_paused = true


## Resume music
func resume_music() -> void:
	if _music_player:
		_music_player.stream_paused = false


## Check if music is playing
func is_music_playing() -> bool:
	return _music_playing


## Set music volume (0-1)
func set_music_volume(volume: float) -> void:
	_music_volume = clamp(volume, 0.0, 1.0)
	if _music_player and _music_playing:
		_music_player.volume_db = linear_to_db(_music_volume)


## --- Volume Fading ---

## Fade a player's volume to target over duration
func _fade_volume(player: AudioStreamPlayer, target_volume: float, duration: float, on_complete: Callable = Callable()) -> void:
	if not is_instance_valid(player):
		return

	_stats["fades_started"] += 1
	var tween := create_tween()
	tween.tween_property(player, "volume_db", linear_to_db(target_volume), duration)
	tween.tween_callback(func():
		_stats["fades_completed"] += 1
		if on_complete.is_valid():
			on_complete.call()
	)
	_active_fades.append(tween)
	tween.finished.connect(func(): _active_fades.erase(tween))


## Fade a bus volume to target over duration
func fade_bus_volume(bus_name: String, target_volume: float, duration: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return

	var tween := create_tween()
	tween.tween_method(
		func(v): AudioServer.set_bus_volume_db(idx, linear_to_db(v)),
		get_volume(bus_name),
		clamp(target_volume, 0.0, 1.0),
		duration
	)
	_active_fades.append(tween)
	tween.finished.connect(func(): _active_fades.erase(tween))


## --- Volume Control ---

## Set volume for a bus (0-1 linear)
func set_volume(bus_name: String, volume: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		GameLog.warning("AudioManager: Bus not found: %s" % bus_name, "Audio")
		return

	var clamped: float = clamp(float(volume), 0.0, 1.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(clamped))

	match bus_name:
		BUS_MASTER: _master_volume = clamped
		BUS_SFX: _sfx_volume = clamped
		BUS_MUSIC: _music_volume = clamped

	GameLog.debug("AudioManager: Volume '%s' = %.2f" % [bus_name, clamped], "Audio")


## Get volume for a bus (0-1 linear)
func get_volume(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return 1.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))


## Mute/unmute a bus
func set_muted(bus_name: String, muted: bool) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_mute(idx, muted)


## Check if bus is muted
func is_muted(bus_name: String) -> bool:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		return AudioServer.is_bus_mute(idx)
	return false


## --- Audio Groups ---

## Set volume for an audio group (affects all buses in group)
func set_group_volume(group_name: String, volume: float) -> void:
	if not _audio_groups.has(group_name):
		GameLog.warning("AudioManager: Group not found: %s" % group_name, "Audio")
		return

	var group = _audio_groups[group_name]
	group["volume"] = clamp(volume, 0.0, 1.0)
	for bus_name in group["buses"]:
		if not group["muted"]:
			set_volume(bus_name, group["volume"])


## Get group volume
func get_group_volume(group_name: String) -> float:
	if _audio_groups.has(group_name):
		return _audio_groups[group_name]["volume"]
	return 1.0


## Mute/unmute an audio group
func set_group_muted(group_name: String, muted: bool) -> void:
	if not _audio_groups.has(group_name):
		return

	var group = _audio_groups[group_name]
	group["muted"] = muted
	for bus_name in group["buses"]:
		set_muted(bus_name, muted)


## Check if group is muted
func is_group_muted(group_name: String) -> bool:
	if _audio_groups.has(group_name):
		return _audio_groups[group_name]["muted"]
	return false


## Register a custom audio group
func register_group(group_name: String, buses: Array) -> void:
	_audio_groups[group_name] = {"volume": 1.0, "muted": false, "buses": buses}
	GameLog.info("AudioManager: Registered group '%s' with %d buses" % [group_name, buses.size()], "Audio")


## --- Cache Management ---

## Preload audio files
func preload_audio(paths: Array) -> void:
	for path in paths:
		_get_cached_stream(path)
	GameLog.info("AudioManager: Preloaded %d audio files" % paths.size(), "Audio")


## Clear audio cache
func clear_cache() -> void:
	_audio_cache.clear()
	GameLog.info("AudioManager: Cache cleared", "Audio")


## Get statistics
func get_stats() -> Dictionary:
	var stats := _stats.duplicate()
	stats["active_sfx"] = _active_sfx
	stats["music_playing"] = _music_playing
	stats["cached_streams"] = _audio_cache.size()
	stats["active_fades"] = _active_fades.size()
	stats["audio_groups"] = _audio_groups.size()
	stats["sfx_pool_size"] = _max_sfx_players
	if _stats["cache_hits"] + _stats["cache_misses"] > 0:
		stats["cache_hit_rate"] = float(_stats["cache_hits"]) / float(_stats["cache_hits"] + _stats["cache_misses"])
	else:
		stats["cache_hit_rate"] = 0.0
	return stats


## --- Internal ---

func _get_cached_stream(path: String) -> AudioStream:
	if _audio_cache.has(path):
		_stats["cache_hits"] += 1
		return _audio_cache[path]

	_stats["cache_misses"] += 1
	var stream: AudioStream = load(path)
	if stream:
		_audio_cache[path] = stream
	return stream


## Get a free SFX player slot, stealing lower priority if needed
func _get_free_sfx_slot(priority: int) -> Dictionary:
	# First try to find a free (not playing) slot
	for slot in _sfx_players:
		if not slot["playing"]:
			return slot

	# No free slot, try to steal a lower priority one
	var lowest_priority_slot: Dictionary = {}
	var lowest_priority := Priority.CRITICAL + 1
	for slot in _sfx_players:
		if slot["priority"] < priority and slot["priority"] < lowest_priority:
			lowest_priority = slot["priority"]
			lowest_priority_slot = slot

	if lowest_priority_slot.is_empty() == false:
		lowest_priority_slot["player"].stop()
		lowest_priority_slot["playing"] = false
		_stats["sfx_stolen"] += 1
		return lowest_priority_slot

	return {}


func _on_sfx_finished(player: AudioStreamPlayer) -> void:
	for slot in _sfx_players:
		if slot["player"] == player:
			slot["playing"] = false
			break
	if _active_sfx > 0:
		_active_sfx -= 1


func _on_ui_sfx_finished(slot: Dictionary) -> void:
	slot["player"].bus = BUS_SFX
	slot["playing"] = false
	if _active_sfx > 0:
		_active_sfx -= 1
