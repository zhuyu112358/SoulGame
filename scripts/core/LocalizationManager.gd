extends Node
## LocalizationManager - Multi-language text localization
##
## Manages language files, text translation, and language switching.
## Uses CSV-based translation files compatible with Godot's translation system.
## Infrastructure only - no game-specific text.
##
## Usage:
##   LocalizationManager.set_language("zh")
##   var text = LocalizationManager.tr("HELLO_WORLD")
##   LocalizationManager.load_translations("res://translations/")

## Current language code (e.g., "en", "zh")
var _current_language: String = "en"

## Default/fallback language
var _default_language: String = "en"

## Available languages: { code: { name, native_name } }
var _available_languages: Dictionary = {}

## Translation strings: { language: { key: text } }
var _translations: Dictionary = {}

## Translation directory
var _translation_dir: String = "res://translations/"

## Whether to log missing translations
var _log_missing: bool = true

## Missing translation keys (for debugging)
var _missing_keys: Dictionary = {}

## Statistics
var _stats: Dictionary = {
	"translations_loaded": 0,
	"text_translated": 0,
	"missing_translations": 0
}


func _ready() -> void:
	_register_default_languages()
	_load_builtin_translations()
	Logger.info("LocalizationManager initialized (lang=%s)" % _current_language, "Locale")


## Set current language
func set_language(lang_code: String) -> void:
	if not _available_languages.has(lang_code):
		Logger.warning("LocalizationManager: Unknown language: %s" % lang_code, "Locale")
		return

	_current_language = lang_code
	GameState.set("game", "language", lang_code)

	# Update Godot's translation server
	TranslationServer.set_locale(lang_code)

	Logger.info("LocalizationManager: Language set to %s" % lang_code, "Locale")
	EventBus.emit("language_changed", {"language": lang_code, "name": _available_languages[lang_code]["name"]})


## Get current language code
func get_language() -> String:
	return _current_language


## Get available languages
func get_available_languages() -> Dictionary:
	return _available_languages.duplicate(true)


## Translate a key to current language
## Falls back to default language, then to the key itself
func tr(key: String) -> String:
	_stats["text_translated"] += 1

	# Try current language
	if _translations.has(_current_language) and _translations[_current_language].has(key):
		return _translations[_current_language][key]

	# Try default language
	if _translations.has(_default_language) and _translations[_default_language].has(key):
		_log_missing_key(key, _current_language)
		return _translations[_default_language][key]

	# Fallback to key
	_log_missing_key(key, _current_language)
	return key


## Translate with formatting (replaces {0}, {1}, etc.)
func trf(key: String, args: Array) -> String:
	var text := tr(key)
	for i in range(args.size()):
		text = text.replace("{%d}" % i, str(args[i]))
	return text


## Check if a key has a translation
func has_translation(key: String, language: String = "") -> bool:
	var lang := language if not language.is_empty() else _current_language
	return _translations.has(lang) and _translations[lang].has(key)


## Add a translation programmatically
func add_translation(language: String, key: String, text: String) -> void:
	if not _translations.has(language):
		_translations[language] = {}
	_translations[language][key] = text


## Load translations from a CSV file
## Format: key,en,zh,ja (first row is header with language codes)
func load_translation_csv(path: String) -> bool:
	if not FileAccess.file_exists(path):
		Logger.error("LocalizationManager: Translation file not found: %s" % path, "Locale")
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false

	var lines := file.get_as_text().split("\n")
	file.close()

	if lines.is_empty():
		return false

	# Parse header (language codes)
	var headers := lines[0].split(",")
	var lang_codes: Array = []
	for i in range(1, headers.size()):
		var code := headers[i].strip_edges()
		if not code.is_empty():
			lang_codes.append(code)
			if not _translations.has(code):
				_translations[code] = {}

	# Parse translations
	var count := 0
	for i in range(1, lines.size()):
		var line := lines[i].strip_edges()
		if line.is_empty():
			continue
		var parts := line.split(",")
		if parts.is_empty():
			continue
		var key := parts[0].strip_edges()
		if key.is_empty():
			continue
		for j in range(lang_codes.size()):
			if j + 1 < parts.size():
				var text := parts[j + 1].strip_edges()
				if not text.is_empty():
					_translations[lang_codes[j]][key] = text
		count += 1

	_stats["translations_loaded"] += count
	Logger.info("LocalizationManager: Loaded %d translations from %s" % [count, path], "Locale")
	return true


## Load all translation files from directory
func load_translations_dir(dir_path: String) -> int:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		Logger.warning("LocalizationManager: Directory not found: %s" % dir_path, "Locale")
		return 0

	var count := 0
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if file_name.ends_with(".csv"):
			if load_translation_csv(dir_path + file_name):
				count += 1
		file_name = dir.get_next()
	dir.list_dir_end()

	return count


## Get missing translation keys
func get_missing_keys() -> Dictionary:
	return _missing_keys.duplicate()


## Clear missing key log
func clear_missing_log() -> void:
	_missing_keys.clear()
	_stats["missing_translations"] = 0


## Get statistics
func get_stats() -> Dictionary:
	return _stats.duplicate()


## Reset to default language
func reset_to_default() -> void:
	set_language(_default_language)


## --- Internal ---

func _register_default_languages() -> void:
	_available_languages = {
		"en": {"name": "English", "native_name": "English"},
		"zh": {"name": "Chinese", "native_name": "中文"},
		"ja": {"name": "Japanese", "native_name": "日本語"}
	}


func _load_builtin_translations() -> void:
	# Built-in infrastructure strings (not game text)
	_translations["en"] = {
		"LOADING": "Loading...",
		"ERROR": "Error",
		"OK": "OK",
		"CANCEL": "Cancel",
		"YES": "Yes",
		"NO": "No",
		"BACK": "Back",
		"SETTINGS": "Settings",
		"LANGUAGE": "Language",
		"VOLUME": "Volume",
		"PAUSED": "Paused",
		"RESUME": "Resume",
		"QUIT": "Quit",
		"CONNECTING": "Connecting...",
		"CONNECTION_FAILED": "Connection Failed",
		"RETRY": "Retry",
		"PERFORMANCE_TEST": "Performance Test",
		"FPS": "FPS",
		"MEMORY": "Memory"
	}

	_translations["zh"] = {
		"LOADING": "加载中...",
		"ERROR": "错误",
		"OK": "确定",
		"CANCEL": "取消",
		"YES": "是",
		"NO": "否",
		"BACK": "返回",
		"SETTINGS": "设置",
		"LANGUAGE": "语言",
		"VOLUME": "音量",
		"PAUSED": "已暂停",
		"RESUME": "继续",
		"QUIT": "退出",
		"CONNECTING": "连接中...",
		"CONNECTION_FAILED": "连接失败",
		"RETRY": "重试",
		"PERFORMANCE_TEST": "性能测试",
		"FPS": "帧率",
		"MEMORY": "内存"
	}

	_stats["translations_loaded"] = _translations["en"].size() + _translations["zh"].size()


func _log_missing_key(key: String, language: String) -> void:
	if not _log_missing:
		return

	if not _missing_keys.has(key):
		_missing_keys[key] = {"count": 0, "language": language}
	_missing_keys[key]["count"] += 1
	_stats["missing_translations"] += 1

	if _missing_keys[key]["count"] == 1:
		Logger.debug("LocalizationManager: Missing translation '%s' for '%s'" % [key, language], "Locale")
