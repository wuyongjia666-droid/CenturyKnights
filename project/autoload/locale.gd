extends Node
## UI string table. CSV columns are keys, zh_CN, en.
## An empty English cell falls back to zh_CN. A missing key never echoes the key name.

var lang: String = "zh_CN"
var _zh: Dictionary = {}
var _en: Dictionary = {}
var _by_zh: Dictionary = {}

func _ready() -> void:
	_load_dir("res://data/locale")
	var saved := ""
	if GameState != null and GameState.settings is Dictionary:
		saved = str(GameState.settings.get("locale", ""))
	if saved.begins_with("en"):
		set_lang("en")
	else:
		TranslationServer.set_locale("zh_CN")

func _load_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	var names: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".csv"):
			names.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	names.sort()
	for csv_name in names:
		_merge_csv("%s/%s" % [path, csv_name])

func _merge_csv(path: String) -> void:
	var handle := FileAccess.open(path, FileAccess.READ)
	if handle == null:
		return
	var header := handle.get_csv_line()
	var key_i := header.find("keys")
	if key_i < 0:
		key_i = header.find("key")
	var zh_i := header.find("zh_CN")
	var en_i := header.find("en")
	if key_i < 0 or zh_i < 0:
		handle.close()
		return
	while not handle.eof_reached():
		var row := handle.get_csv_line()
		if row.is_empty():
			continue
		var need := maxi(key_i, zh_i)
		if en_i >= 0:
			need = maxi(need, en_i)
		if row.size() <= need:
			continue
		var key := str(row[key_i]).strip_edges()
		if key == "":
			continue
		var zh := str(row[zh_i])
		var en := str(row[en_i]) if en_i >= 0 and en_i < row.size() else ""
		if zh != "" and not _zh.has(key):
			_zh[key] = zh
		if en != "" and str(_en.get(key, "")) == "":
			_en[key] = en
		if zh != "" and en != "" and not _by_zh.has(zh):
			_by_zh[zh] = en
	handle.close()

func set_lang(code: String) -> void:
	lang = "en" if str(code).begins_with("en") else "zh_CN"
	TranslationServer.set_locale("en" if lang == "en" else "zh_CN")
	if GameState != null and GameState.settings is Dictionary:
		GameState.settings["locale"] = lang

func is_en() -> bool:
	return lang.begins_with("en")

func has_cjk(text: String) -> bool:
	for i in text.length():
		var code := text.unicode_at(i)
		if code >= 0x4E00 and code <= 0x9FFF:
			return true
	return false

## English mode shows a catalog hit, otherwise the ASCII fallback when the source is Chinese.
func latin(text: String, fallback: String) -> String:
	if not is_en():
		return text
	if _by_zh.has(text):
		return str(_by_zh[text])
	if has_cjk(text):
		return fallback
	return text

func t(key: String, args: Array = []) -> String:
	var value := _pick(key)
	if args.is_empty():
		return value
	return value % args

func _pick(key: String) -> String:
	var zh := str(_zh.get(key, ""))
	var en := str(_en.get(key, ""))
	if is_en() and en != "":
		return en
	if zh != "":
		return zh
	var fallback := str(_zh.get("locale_missing", ""))
	if fallback != "":
		return fallback
	return "..."
