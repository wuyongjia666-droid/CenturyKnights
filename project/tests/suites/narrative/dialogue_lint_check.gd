extends Node
## NAR-08：归档反例必须响，chapters 必须干净。

const LintScript := preload("res://scripts/narrative/dialogue_lint.gd")
const NEED := [
	"volume_ordinal",
	"chapter_done",
	"version_tag",
	"volume_mid",
	"system_speaker",
	"line_too_long",
	"anti_trope",
	"unregistered_speaker",
]

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL dialogue: ", err)
		get_tree().quit(1)
	else:
		print("DIALOGUE LINT PASS")
		get_tree().quit(0)

func _run() -> String:
	var lint = LintScript.new()
	var loaded: String = lint.load_rules()
	if loaded != "":
		return loaded
	var archive: Dictionary = lint.scan_dir("res://data/story/archive_v6")
	var chapters: Dictionary = lint.scan_dir("res://data/story/chapters")
	if int(archive.get("lines", 0)) < 1:
		return "archive scanned no lines"
	if int(chapters.get("lines", 0)) < 1:
		return "chapters scanned no lines"
	var bad: Array = archive.get("violations", [])
	var good: Array = chapters.get("violations", [])
	print("DIALOGUE LINT archive violations=%d lines=%d" % [bad.size(), int(archive.get("lines", 0))])
	var seen := {}
	for hit in bad:
		var rule := str(hit.get("rule", ""))
		seen[rule] = true
		print("HIT %s %s" % [rule, str(hit.get("detail", ""))])
	for rule in NEED:
		if not seen.has(rule):
			return "archive missed rule " + rule
	if good.size() != 0:
		for hit in good:
			print("CHAPTER HIT %s %s" % [str(hit.get("rule", "")), str(hit.get("file", ""))])
		return "chapters violations=%d" % good.size()
	print("DIALOGUE LINT chapters violations=0")
	# 现役模板章还没搬进 archive。抽一章证明同一套规则打得中真文本。
	var live := "res://data/chapter156.json"
	if FileAccess.file_exists(live):
		var sample: Dictionary = lint.scan_file(live)
		var sample_hits: Array = sample.get("violations", [])
		var live_seen := {}
		for hit in sample_hits:
			live_seen[str(hit.get("rule", ""))] = true
		if not live_seen.has("volume_mid") or not live_seen.has("version_tag"):
			return "live template chapter156 was not flagged"
		print("DIALOGUE LINT live chapter156 violations=%d" % sample_hits.size())
	return ""
