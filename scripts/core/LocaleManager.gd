extends Node

## Thin wrapper around Godot's TranslationServer.
## Loads all CSV files from res://locales/ at startup.
## Use LocaleManager.t("KEY") or LocaleManager.t("KEY", {"param": value}) everywhere.

signal language_changed(code: String)

const SUPPORTED_LANGUAGES: Array[String] = ["it"]
const DEFAULT_LOCALE:       String        = "it"
const LOCALE_DIR:           String        = "res://locales/"
const CSV_FILES: Array[String] = [
	"strings_ui",
	"strings_notifications",
	"strings_data",
	"strings_dialogue",
	"strings_classes",
	"strings_items",
	"strings_enemies",
	"strings_factions",
	"strings_cities",
]

var _locale: String = DEFAULT_LOCALE


func _ready() -> void:
	_load_all_translations()
	TranslationServer.set_locale(_locale)


# ── public API ────────────────────────────────────────────────────────────────

## Translate a key. Supports named format params: t("KEY", {"name": "Mario"})
## Uses String.format() syntax: {name}, {amount}, {qty}, etc.
func t(key: String, params: Dictionary = {}) -> String:
	var text: String = TranslationServer.translate(key, _locale)
	if text == key:
		push_warning("LocaleManager: missing key '%s' [%s]" % [key, _locale])
	if params.is_empty():
		return text
	return text.format(params)


## Like t() but returns `fallback` instead of the key when not found — no warning.
func t_or(key: String, fallback: String, params: Dictionary = {}) -> String:
	var text: String = TranslationServer.translate(key, _locale)
	if text == key:
		return fallback if params.is_empty() else fallback.format(params)
	if params.is_empty():
		return text
	return text.format(params)


func set_language(code: String) -> void:
	if code not in SUPPORTED_LANGUAGES:
		push_warning("LocaleManager: unsupported language '%s'" % code)
		return
	_locale = code
	TranslationServer.set_locale(code)
	language_changed.emit(code)
	if get_tree():
		get_tree().root.propagate_notification(NOTIFICATION_TRANSLATION_CHANGED)


func get_language() -> String:
	return _locale


func get_display_name(code: String = "") -> String:
	match (code if code != "" else _locale):
		"it": return "Italiano"
		"en": return "English"
		"de": return "Deutsch"
		"fr": return "Français"
		"es": return "Español"
		"pt": return "Português"
		_:    return code


# ── internal ──────────────────────────────────────────────────────────────────

func _load_all_translations() -> void:
	for lang: String in SUPPORTED_LANGUAGES:
		var translation := Translation.new()
		translation.locale = lang
		for csv_name: String in CSV_FILES:
			_parse_csv(translation, LOCALE_DIR + csv_name + ".csv", lang)
		TranslationServer.add_translation(translation)


func _parse_csv(translation: Translation, path: String, lang: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("LocaleManager: file not found: " + path)
		return
	var header: PackedStringArray = f.get_csv_line()
	var col: int = -1
	for i: int in range(1, header.size()):
		if header[i].strip_edges() == lang:
			col = i
			break
	if col < 0:
		push_warning("LocaleManager: column '%s' not found in %s" % [lang, path])
		f.close()
		return
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() > col and row[0].strip_edges() != "":
			translation.add_message(row[0].strip_edges(), row[col])
	f.close()
