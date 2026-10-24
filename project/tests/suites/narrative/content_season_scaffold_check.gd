extends Node
## Y1-B 内容季选题脚手架：机器表字段 + 目录骨架。
## 不要求小说正文；gates.novel_allowed 必须为 false，直到 Y1-A 签收。

func _ready() -> void:
	await get_tree().process_frame
	var err := _run()
	if err != "":
		print("FAIL content_season_scaffold: ", err)
		get_tree().quit(1)
		return
	print("CONTENT SEASON SCAFFOLD PASS")
	get_tree().quit(0)


func _run() -> String:
	var fails: Array = []
	var path := "res://data/content_seasons/season_01.json"
	if not FileAccess.file_exists(path):
		return "missing " + path
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return "season_01.json not a dict"
	var d: Dictionary = parsed
	for k in ["id", "version", "title_zh", "status", "pipeline", "stage", "flag_lamp", "system_deepen", "system_deepen_zh", "gates", "docs_rel"]:
		if not d.has(k):
			fails.append("missing field %s" % k)
	if str(d.get("id", "")) != "season_01":
		fails.append("id")
	if str(d.get("status", "")) != "topic_scaffold":
		fails.append("status want topic_scaffold")
	if str(d.get("stage", "")) != "topic":
		fails.append("stage want topic")
	var pipe: Array = d.get("pipeline", [])
	var want_pipe := ["topic", "novel", "bible", "playable", "systems", "art", "playtest"]
	if pipe != want_pipe:
		fails.append("pipeline %s" % str(pipe))
	var fl: Dictionary = d.get("flag_lamp", {})
	if str(fl.get("flag", "")).strip_edges() == "" or str(fl.get("lamp", "")).strip_edges() == "":
		fails.append("flag_lamp empty")
	if str(d.get("system_deepen", "")).strip_edges() == "":
		fails.append("system_deepen empty")
	var gates: Dictionary = d.get("gates", {})
	if bool(gates.get("novel_allowed", true)):
		fails.append("novel_allowed must stay false pre-signoff")
	if bool(gates.get("y1a_device_signoff", true)):
		fails.append("y1a_device_signoff must be false until user signs")
	# Repo-root docs (sibling of project/).
	var project_root := ProjectSettings.globalize_path("res://").rstrip("/")
	var repo := project_root.get_base_dir()
	for rel in d.get("docs_rel", []):
		var abs := repo.path_join(str(rel))
		if not FileAccess.file_exists(abs):
			fails.append("missing doc %s" % rel)
			continue
		var body := FileAccess.get_file_as_string(abs)
		if str(rel).ends_with("TOPIC.md"):
			if body.find("旗") < 0 and body.find("灯") < 0:
				fails.append("TOPIC missing 旗/灯")
			if body.find("岁课") < 0 and body.find(str(d.get("system_deepen_zh", ""))) < 0:
				fails.append("TOPIC missing system deepen")
		elif body.strip_edges() == "":
			fails.append("empty stub %s" % rel)
	# Index of seasons.
	var idx := "res://data/content_seasons/index.json"
	if not FileAccess.file_exists(idx):
		fails.append("missing index.json")
	else:
		var ix = JSON.parse_string(FileAccess.get_file_as_string(idx))
		if typeof(ix) != TYPE_DICTIONARY or not (ix.get("seasons", []) is Array):
			fails.append("index shape")
		elif not ("season_01" in ix.get("seasons", [])):
			fails.append("index missing season_01")
	return "; ".join(fails)
