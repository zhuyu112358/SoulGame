extends Node
## AudioManager - Audio bus management, SFX playback, and music control
##
## Manages audio buses, one-shot SFX, looping music, volume control,
## and audio resource caching. Infrastructure only - no game-specific audio.
##
## Usage:
##   AudioManager.play_sfx("res://assets/audio/hit.wav")
##   AudioManager.play_music("res://assets/audio/theme.ogg")
##   AudioManager.set_volume("master", 0.8)
##   AudioManager.stop_music()

## Audio bus names
const BUS_MASTER := "Master"
const BUS_SFX := "SFX"
const BUS_MUSIC := "Music"
const BUS_UI := "UI"
const BUS_AMBIENT := "Ambient"

## SFX player pool
var _sfx_players: Array = []
var _max_sfx_players: int = 16

## Current music player
var _music_player: AudioStreamPlayer = null

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

## Statistics
var _stats: Dictionary = {
	"sfx_played": 0,
	"music_played": 0,
	"cache_hits": 0,
	"cache_misses": 0
}


func _ready() -> void:
	_initialize_buses()
	_initialize_sfx_pool()
	Logger.info("AudioManager initialized (%d SFX players)" % _max_sfx_players, "Audio")


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
			Logger.debug("AudioManager: Created bus '%s'" % bus_name, "Audio")

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
		_sfx_players.append(player)


## --- SFX Playback ---

## Play a one-shot sound effect
## volume: 0-1 (multiplied by SFX bus volume)
## pitch: 0.5-2.0
func play_sfx(path: String, volume: float = 1.0, pitch: float = 1.0) -> void:
	var stream := _get_cached_stream(path)
	if stream == null:
		Logger.warning("AudioManager: Could not load SFX: %s" % path, "Audio")
		return

	var player := _get_free_sfx_player()
	if player == null:
		Logger.debug("AudioManager: SFX pool full, stealing oldest", "Audio")
		player = _sfx_players[0]
		player.stop()

	player.stream = stream
	player.volume_db = linear_to_db(_sfx_volume * volume)
	player.pitch_scale = clamp(pitch, 0.5, 2.0)
	player.play()
	_active_sfx += 1
	_stats["sfx_played"] += 1


## Play a sound effect with random pitch variation (for variety)
func play_sfx_varied(path: String, volume: float = 1.0, pitch_variation: float = 0.1) -> void:
	var pitch := 1.0 + randf_range(-pitch_variation, pitch_variation)
	play_sfx(path, volume, pitch)


## Stop all SFX
func stop_all_sfx() -> void:
	for player in _sfx_players:
		player.stop()
	_active_sfx = 0


## --- Music Playback ---

## Play background music (loops by default)
func play_music(path: String, volume: float = -1.0, fade_in: float = 0.0) -> void:
	var stream := _get_cached_stream(path)
	if stream == null:
		Logger.error("AudioManager: Could not load music: %s" % path, "Audio")
		return

	# Stop current music
	if _music_player and _music_playing:
		_music_player.stop()

	if _music_player == null:
		_music_player = AudioStreamPlayer.new()
		_music_player.bus = BUS_MUSIC
		add_child(_music_player)

	_music_player.stream = stream
	_music_player.volume_db = linear_to_db(_music_volume if volume < 0 else volume)
	_music_player.play()
	_music_playing = true
	_current_music = stream
	_stats["music_played"] += 1

	Logger.info("AudioManager: Playing music: %s" % path, "Audio")


## Stop music with optional fade out
func stop_music(fade_out: float = 0.0) -> void:
	if _music_player and _music_playing:
		_music_player.stop()
		_music_playing = false
		_current_music = null
		Logger.info("AudioManager: Music stopped", "Audio")


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


## --- Volume Control ---

## Set volume for a bus (0-1 linear)
func set_volume(bus_name: String, volume: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		Logger.warning("AudioManager: Bus not found: %s" % bus_name, "Audio")
		return

	var clamped := clamp(volume, 0.0, 1.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(clamped))

	match bus_name:
		BUS_MASTER: _master_volume = clamped
		BUS_SFX: _sfx_volume = clamped
		BUS_MUSIC: _music_volume = clamped

	Logger.debug("AudioManager: Volume '%s' = %.2f" % [bus_name, clamped], "Audio")


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
		return AudioServer.is_bus_muted(idx)
	return false


## --- Cache Management ---

## Preload audio files
func preload_audio(paths: Array) -> void:
	for path in paths:
		_get_cached_stream(path)
	Logger.info("AudioManager: Preloaded %d audio files" % paths.size(), "Audio")


## Clear audio cache
func clear_cache() -> void:
	_audio_cache.clear()
	Logger.info("AudioManager: Cache cleared", "Audio")


## Get statistics
func get_stats() -> Dictionary:
	return _stats.duplicate()


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


func _get_free_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_players:
		if not player.playing:
			return player
	return null


func _on_sfx_finished(player: AudioStreamPlayer) -> void:
	if _active_sfx > 0:
		_active_sfx -= 1
