extends Node
## AudioManager - Unified audio playback manager
##
## Manages all game audio: UI sounds, battle sounds, BGM, environment, soul sounds.
## Provides a simple API for playing sounds by name with volume control.
##
## Audio categories:
## - ui: Button clicks, menus, notifications
## - battle: Attack hits, skills, victory/defeat
## - bgm: Background music (looping)
## - environment: Ambient sounds
## - soul: Soul emotion sounds

## Audio bus names
const BUS_MASTER = "Master"
const BUS_SFX = "SFX"
const BUS_BGM = "BGM"

## Volume settings (0.0 - 1.0)
var master_volume: float = 1.0
var sfx_volume: float = 0.8
var bgm_volume: float = 0.5

## Currently playing BGM
var _current_bgm: AudioStreamPlayer = null
var _current_bgm_name: String = ""

## Sound effect players pool
var _sfx_players: Array = []
var _max_sfx_players: int = 16

## Loaded audio streams cache
var _stream_cache: Dictionary = {}
var _failed_streams: Dictionary = {}

## Sound name to path mapping
var _sound_paths: Dictionary = {}


func _ready() -> void:
	GameLog.info("AudioManager: Initialized", "Audio")
	_setup_audio_buses()
	_init_sound_paths()
	_init_sfx_pool()
	load_settings()


## Save volume settings to config file
func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "bgm_volume", bgm_volume)
	var err = config.save("user://settings.cfg")
	if err == OK:
		GameLog.info("AudioManager: Settings saved", "Audio")
	else:
		GameLog.warning("AudioManager: Failed to save settings (error %d)" % err, "Audio")


## Load volume settings from config file
func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err == OK:
		master_volume = config.get_value("audio", "master_volume", 1.0)
		sfx_volume = config.get_value("audio", "sfx_volume", 0.8)
		bgm_volume = config.get_value("audio", "bgm_volume", 0.5)
		_apply_volumes()
		GameLog.info("AudioManager: Settings loaded (master=%.2f, sfx=%.2f, bgm=%.2f)" % [master_volume, sfx_volume, bgm_volume], "Audio")
	else:
		GameLog.info("AudioManager: No saved settings, using defaults", "Audio")


## Apply current volume settings to audio buses
func _apply_volumes() -> void:
	set_master_volume(master_volume)
	set_sfx_volume(sfx_volume)
	set_bgm_volume(bgm_volume)


## Setup audio buses if they don't exist
func _setup_audio_buses() -> void:
	# Godot has Master bus by default. Add SFX and BGM buses if needed.
	# In M2 prototype, we use Master bus only with volume scaling.
	pass


## Initialize sound file paths
func _init_sound_paths() -> void:
	# UI sounds
	var ui_sounds: Array = [
		"button_click", "cancel", "confirm", "error", "notification",
		"success_prompt", "failure_prompt", "warning_alert", "levelup",
		"exp_get", "item_get", "item_use", "shop_buy", "shop_open",
		"battle_start", "battle_end", "match_found", "match_cancel",
		"panel_open", "panel_close", "tab_switch", "loading_complete", "progress_loading",
		"soul_detail_open", "soul_evolve", "achievement", "achievement_unlock",
		"rank_up", "season_start", "season_end", "revive", "teleport",
		"coin_get", "equip_wear", "equip_remove", "item_discard",
		"checkbox", "dropdown", "radio", "slider_adjust", "number_input",
		"color_picker", "toggle_switch", "title_unlock", "connection_success",
		"spectator_enter", "spectator_leave", "replay_start", "replay_end",
		"settings_open", "settings_save",
		"quest_open", "quest_complete",
		"inventory_open", "item_use",
		"achievement_open", "shop_sell",
		"teleport_cast", "teleport_open",
		"matchmaking_open",
		"battle_result_open", "battle_victory",
		"accept", "back", "close", "confirm", "error",
		"hover", "menu_open", "notification", "open",
		"select", "success", "tab", "tick", "toggle", "warning",
		"exp_gain", "game_start", "level_up", "loading", "panel_switch",
		"confirm_dialog", "codex_open", "codex_unlock", "item_pickup", "mail_open",
		"button_hover", "friends_open", "friend_request", "leaderboard_open",
		"mail_receive", "season_open", "season_reward", "settings_close",
		"soul_select_confirm", "soul_select_hover"
	]
	for sound_name in ui_sounds:
		_sound_paths["ui_%s" % sound_name] = "res://assets/audio/ui/ui_%s.wav" % sound_name

	# Battle sounds
	var battle_sounds: Array = [
		"attack_hit", "critical_hit", "defeat", "defend", "dodge",
		"skill_cast", "skill_ready", "turn_end", "turn_start", "victory"
	]
	for sound_name in battle_sounds:
		_sound_paths["bat_%s" % sound_name] = "res://assets/audio/battle/bat_%s.wav" % sound_name

	# Additional battle sounds with battle_ prefix (design assets)
	var battle_extra_sounds: Array = [
		"skill_hit", "heal", "shield", "countdown", "gather",
		"tension", "calm", "unit_move", "unit_attack", "upgrade",
		"attack_hit", "build", "critical", "defeat", "defend",
		"dodge", "end", "skill_cast", "start", "victory"
	]
	for sound_name in battle_extra_sounds:
		_sound_paths["battle_%s" % sound_name] = "res://assets/audio/battle/battle_%s.wav" % sound_name

	# Skill cast sounds (design assets round 7)
	var skill_sounds: Array = [
		"fireball", "waterarrow", "rock", "windblade", "heal", "defend"
	]
	for skill_sound_name in skill_sounds:
		_sound_paths["skill_%s" % skill_sound_name] = "res://assets/audio/skill_%s.wav" % skill_sound_name

	# Soul unit sounds (design assets round 6)
	var soul_unit_sounds: Array = [
		"idle", "attack", "hurt", "death", "move", "skill"
	]
	for unit_sound_name in soul_unit_sounds:
		_sound_paths["soul_unit_%s" % unit_sound_name] = "res://assets/audio/soul_unit_%s.wav" % unit_sound_name

	# Battle UI sounds (design assets round 8) - high quality versions
	var battle_ui_sounds: Array = [
		"start", "end", "victory", "defeat", "countdown"
	]
	for battle_ui_name in battle_ui_sounds:
		_sound_paths["battle_ui_%s" % battle_ui_name] = "res://assets/audio/battle_%s.wav" % battle_ui_name
	_sound_paths["unit_select"] = "res://assets/audio/unit_select.wav"

	# Steam achievement sounds (design assets for Steam EA)
	var steam_achievement_sounds: Array = [
		"unlock", "notify", "progress", "rare", "share", "view"
	]
	for ach_name in steam_achievement_sounds:
		_sound_paths["steam_achievement_%s" % ach_name] = "res://assets/audio/steam_achievement_%s.wav" % ach_name

	# Soul home interaction sounds (design task round 25)
	var soul_home_sounds: Array = [
		"ambience", "dialogue", "equipment", "growth", "interaction", "training"
	]
	for sh_name in soul_home_sounds:
		_sound_paths["soul_home_%s" % sh_name] = "res://assets/audio/soul_home_%s.wav" % sh_name

	# BGM
	var bgm_tracks: Array = ["battle", "explore", "home_main", "menu",
		"main_menu", "battle_calm", "battle_tension",
		"soul_home_day", "soul_home_night", "victory_celebration", "explore_mystery"]
	for track_name in bgm_tracks:
		_sound_paths["bgm_%s" % track_name] = "res://assets/audio/bgm/bgm_%s.wav" % track_name

	# Environment sounds (ambient arena backgrounds)
	var env_sounds: Array = [
		"ancient_battlefield", "canyon", "cave", "cliff",
		"forest", "lava", "wind_chimes",
		"frozen_forest", "lava_cave", "ancient_ruins", "mushroom_swamp",
		"lavender_field", "autumn_forest", "rainforest", "rainforest_canopy",
		"snow_mountain_lake", "starfield_grassland",
		"cloud_peak", "volcano_crater",
		"crystal_cavern", "mangrove_swamp",
		"campfire", "coral_reef", "crystal_cave", "dawn",
		"desert", "ocean", "rain", "river",
		"snow", "storm", "thunder", "volcano",
		"waterfall", "wind",
		"floating_island", "aurora_icefield", "home_indoor", "glowing_cave",
		"crystal_garden", "firefly_forest", "cherry_blossom", "bamboo_forest",
		"lake", "grassland",
		"aurora", "desert_oasis", "flowerfield", "garden_birds",
		"glacier", "highland", "hot_spring", "mangrove",
		"meadow", "meteor_shower",
		"aurora_snowfield", "cherry_blossom_valley", "moonlit_garden", "mountaintop",
		"mushroom_forest", "night", "ocean", "pond",
		"sakura_shrine", "savanna",
		"seaside", "snow_mountain", "soul_home", "soul_home_day",
		"soul_home_night", "starlight", "stream", "sunset",
		"tundra", "underground_cavern",
		"underground_city", "underground_river", "volcanic_wasteland", "volcano",
		"waterfall_canyon", "wetland", "wind_erosion"
	]
	for sound_name in env_sounds:
		_sound_paths["env_%s" % sound_name] = "res://assets/audio/environment/env_%s.wav" % sound_name

	# Soul emotion sounds (design doc: emotion affects battle)
	var soul_sounds: Array = [
		"angry_roar", "brave_courage", "confident", "determined_resolve",
		"communication_blip", "curious_blip",
		"overwhelmed", "envious", "energetic", "relaxed",
		"drowsy", "alert", "melancholic", "compassionate",
		"anticipating", "astonished", "contemplative", "empathetic",
		"resolute", "devoted",
		"persistent", "sentimental",
		"affectionate", "affinity_heart", "amazed_wonder", "amused",
		"balanced", "benevolent", "calm_meditation", "caring",
		"content_smile", "curious_peek", "dedicated",
		"gentle", "happy", "harmonious", "joyful",
		"kind", "peaceful", "serene", "tender", "warm",
		"awaken", "calm", "chat", "curious", "delighted",
		"ecstatic", "embarrassed", "excited", "grateful", "hopeful",
		"absorbed", "aggressive", "anxious", "bored", "calm_pulse",
		"chivalrous", "confused", "dejected", "dependable", "disappointed",
		"ashamed", "enthusiastic", "evolve", "excited_bounce", "excited_sparkle",
		"expectant", "fear_tremble", "fierce", "focused_concentrate", "forgiving",
		"confused_tilt", "disheartened", "furious", "gallant", "generous",
		"gracious", "grateful_thanks", "grow_up", "guilty", "happy_chime",
		"expectant_wait", "feed", "heroic", "honorable", "humble",
		"inquisitive", "inspired", "jealous", "lonely", "loving",
		"lonely_whisper", "loyal", "magnanimous", "merciful", "motivated",
		"nostalgic_memory", "optimistic", "passionate", "peaceful_calm", "pet",
		"play", "playful", "proud", "proud_pose", "reliable",
		"relieved_sigh", "resentful", "righteous", "sad_hum", "satisfied_purr",
		"shy", "shy_blush", "skeptical", "sleep", "sleep_breath",
		"smug", "spawn", "supportive", "surprised", "surprised_gasp",
		"tenacious", "terrified", "thinking_hum", "timid", "tired_sigh",
		"train", "tranquil", "trust", "trustworthy", "trust_warm",
		"understanding", "valiant", "wistful", "zealous"
	]
	for sound_name in soul_sounds:
		_sound_paths["soul_%s" % sound_name] = "res://assets/audio/soul/soul_%s.wav" % sound_name

	# Action sounds (player actions)
	var action_sounds: Array = [
		"attack_swing", "craft", "door_open", "harvest",
		"interact", "pickup", "use_item", "walk_wood"
	]
	for sound_name in action_sounds:
		_sound_paths["act_%s" % sound_name] = "res://assets/audio/actions/act_%s.wav" % sound_name

	GameLog.info("AudioManager: Registered %d sound paths" % _sound_paths.size(), "Audio")


## Initialize SFX player pool
func _init_sfx_pool() -> void:
	for i in range(_max_sfx_players):
		var player = AudioStreamPlayer.new()
		player.bus = BUS_MASTER
		add_child(player)
		_sfx_players.append(player)


## Get a free SFX player from pool
func _get_free_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_players:
		if not player.playing:
			return player
	# All busy, return first (will cut off oldest)
	return _sfx_players[0]


## Load and cache audio stream
func _get_stream(p_sound_name: String) -> AudioStream:
	if _stream_cache.has(p_sound_name):
		return _stream_cache[p_sound_name]
	if _failed_streams.has(p_sound_name):
		return null
	if not _sound_paths.has(p_sound_name):
		_failed_streams[p_sound_name] = true
		return null
	var path = _sound_paths[p_sound_name]
	var stream = load(path)
	if stream == null:
		_failed_streams[p_sound_name] = true
		GameLog.warning("AudioManager: Failed to load %s (suppressing future warnings)" % path, "Audio")
		return null
	_stream_cache[p_sound_name] = stream
	return stream


## Play a sound effect by name
## Example: play_sfx("ui_button_click") or play_sfx("bat_attack_hit")
func play_sfx(p_sound_name: String, p_volume: float = -1.0) -> void:
	var stream = _get_stream(p_sound_name)
	if stream == null:
		return

	var player = _get_free_sfx_player()
	player.stream = stream
	var vol = p_volume if p_volume >= 0 else sfx_volume
	player.volume_db = linear_to_db(vol * master_volume)
	player.play()


## Play UI sound (convenience)
func play_ui(p_sound_name: String) -> void:
	play_sfx("ui_%s" % p_sound_name)


## Play battle sound (convenience)
func play_battle(p_sound_name: String) -> void:
	play_sfx("bat_%s" % p_sound_name)


## Play BGM by name (loops, stops current BGM)
## Example: play_bgm("battle") or play_bgm("menu")
func play_bgm(p_bgm_name: String, p_volume: float = -1.0) -> void:
	if _current_bgm_name == p_bgm_name and _current_bgm and _current_bgm.playing:
		return  # Already playing

	# Stop current BGM
	stop_bgm()

	var stream = _get_stream("bgm_%s" % p_bgm_name)
	if stream == null:
		return

	# Create BGM player
	_current_bgm = AudioStreamPlayer.new()
	_current_bgm.bus = BUS_MASTER
	var vol = p_volume if p_volume >= 0 else bgm_volume
	_current_bgm.volume_db = linear_to_db(vol * master_volume)
	_current_bgm.stream = stream
	# Enable looping if supported
	if stream is AudioStreamWAV:
		# WAV doesn't support loop by default, set loop mode
		pass
	add_child(_current_bgm)
	_current_bgm.play()
	_current_bgm_name = p_bgm_name

	GameLog.info("AudioManager: Playing BGM '%s'" % p_bgm_name, "Audio")


## Stop current BGM
func stop_bgm() -> void:
	if _current_bgm and is_instance_valid(_current_bgm):
		_current_bgm.stop()
		_current_bgm.queue_free()
		_current_bgm = null
	_current_bgm_name = ""


## Set master volume (0.0 - 1.0)
func set_master_volume(p_volume: float) -> void:
	master_volume = clampf(p_volume, 0.0, 1.0)
	_update_all_volumes()


## Set SFX volume (0.0 - 1.0)
func set_sfx_volume(p_volume: float) -> void:
	sfx_volume = clampf(p_volume, 0.0, 1.0)


## Set BGM volume (0.0 - 1.0)
func set_bgm_volume(p_volume: float) -> void:
	bgm_volume = clampf(p_volume, 0.0, 1.0)
	if _current_bgm:
		_current_bgm.volume_db = linear_to_db(bgm_volume * master_volume)


## Update all player volumes
func _update_all_volumes() -> void:
	if _current_bgm:
		_current_bgm.volume_db = linear_to_db(bgm_volume * master_volume)


## Get available sound names
func get_available_sounds() -> Array:
	return _sound_paths.keys()


## Get audio manager info
func get_info() -> Dictionary:
	return {
		"master_volume": master_volume,
		"sfx_volume": sfx_volume,
		"bgm_volume": bgm_volume,
		"current_bgm": _current_bgm_name,
		"registered_sounds": _sound_paths.size(),
		"cached_streams": _stream_cache.size(),
		"sfx_pool_size": _max_sfx_players
	}


## Get stats (alias for get_info, for DebugOverlay compatibility)
func get_stats() -> Dictionary:
	# Count currently playing SFX players
	var sfx_playing: int = 0
	for player in _sfx_players:
		if player.playing:
			sfx_playing += 1

	return {
		"master_volume": master_volume,
		"sfx_volume": sfx_volume,
		"bgm_volume": bgm_volume,
		"current_bgm": _current_bgm_name,
		"music_playing": _current_bgm != null and _current_bgm.playing,
		"sfx_playing": sfx_playing,
		"sfx_pool_size": _max_sfx_players,
		"registered_sounds": _sound_paths.size(),
		"cached_streams": _stream_cache.size()
	}


## Get volume for bus (DebugOverlay compatibility)
func get_volume(p_bus_name: String) -> float:
	match p_bus_name.to_lower():
		"master":
			return master_volume
		"sfx":
			return sfx_volume
		"bgm", "music":
			return bgm_volume
	return master_volume
