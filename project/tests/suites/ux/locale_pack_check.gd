extends Node
## Windows export used to import locale CSVs as translations, drop the source
## from the PCK, and show "..." / raw keys. importer=keep keeps FileAccess working.

const DIR := "res://data/locale"
const EXPECTED := {
	"menu_new": "新的旗号",
	"menu_continue": "继续历程",
	"end_turn": "结束回合",
	"shell_d95adbd6": "玩家回合",
}

func _ready() -> void:
	await get_tree().process_frame
	var fails: Array = []
	_imports(fails)
	_strings(fails)
	if fails.is_empty():
		print("LOCALE PACK PASS")
		get_tree().quit(0)
		return
	for f in fails:
		print("FAIL locale pack: ", f)
	get_tree().quit(1)

func _imports(fails: Array) -> void:
	var dir := DirAccess.open(DIR)
	if dir == null:
		fails.append("locale dir missing")
		return
	var csvs: Array = []
	for file_name in dir.get_files():
		if str(file_name).ends_with(".csv"):
			csvs.append(str(file_name))
	if csvs.is_empty():
		fails.append("no csv")
		return
	for name in csvs:
		var path := "%s/%s.import" % [DIR, name]
		if not FileAccess.file_exists(path):
			fails.append("missing import %s" % name)
			continue
		var text := FileAccess.get_file_as_string(path)
		if text.find("importer=\"keep\"") < 0:
			fails.append("not keep %s" % name)
		if text.find("csv_translation") >= 0:
			fails.append("still translation %s" % name)
	var preset := FileAccess.get_file_as_string("res://export_presets.cfg")
	if preset.find("include_filter=\"*.csv\"") < 0:
		fails.append("export include_filter missing *.csv")

func _strings(fails: Array) -> void:
	for key in EXPECTED.keys():
		var text := Locale.t(str(key))
		if text != str(EXPECTED[key]) or text == "..." or text == str(key):
			fails.append("%s -> %s" % [key, text])
	var danger := BattleObjectives.text("danger_toggle")
	var eye := BattleObjectives.text("obj_eyebrow")
	var undo := BattleObjectives.text("rewind_undo")
	if danger != "危险区" or danger == "danger_toggle":
		fails.append("danger_toggle -> %s" % danger)
	if eye != "目标" or eye == "obj_eyebrow":
		fails.append("obj_eyebrow -> %s" % eye)
	if undo != "撤回" or undo == "rewind_undo":
		fails.append("rewind_undo -> %s" % undo)
