extends Node
## Y1-B 内容季流水脚手架加深（v2）：机器表 + 选题清单 + 验收 suite 路径 + 闸门。
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
	for k in [
		"id", "version", "title_zh", "status", "pipeline", "stage", "flag_lamp",
		"system_deepen", "system_deepen_zh", "gates", "docs_rel",
		"topic_checklist", "acceptance", "pipeline_stages",
	]:
		if not d.has(k):
			fails.append("missing field %s" % k)
	if int(d.get("version", 0)) < 2:
		fails.append("version want >= 2")
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

	fails.append_array(_check_topic_checklist(d))
	fails.append_array(_check_acceptance(d))
	fails.append_array(_check_pipeline_stages(d, gates))
	fails.append_array(_check_docs(d))
	fails.append_array(_check_index())
	return "; ".join(fails)


func _check_topic_checklist(d: Dictionary) -> Array:
	var fails: Array = []
	var items: Variant = d.get("topic_checklist", [])
	if typeof(items) != TYPE_ARRAY or (items as Array).is_empty():
		fails.append("topic_checklist empty")
		return fails
	var topic_body := _repo_doc_text("docs/content-seasons/season-01/TOPIC.md")
	var checklist_body := _repo_doc_text("docs/content-seasons/season-01/CHECKLIST.md")
	if topic_body == "":
		fails.append("TOPIC.md unreadable")
	if checklist_body == "":
		fails.append("CHECKLIST.md unreadable")
	for it in items:
		if typeof(it) != TYPE_DICTIONARY:
			fails.append("topic_checklist item not dict")
			continue
		var id := str(it.get("id", "")).strip_edges()
		var label := str(it.get("label_zh", "")).strip_edges()
		if id == "" or label == "":
			fails.append("topic_checklist missing id/label")
			continue
		if topic_body.find(label) < 0:
			fails.append("TOPIC missing checklist label %s" % label)
		if checklist_body.find(id) < 0:
			fails.append("CHECKLIST missing id %s" % id)
	return fails


func _check_acceptance(d: Dictionary) -> Array:
	var fails: Array = []
	var items: Variant = d.get("acceptance", [])
	if typeof(items) != TYPE_ARRAY or (items as Array).is_empty():
		fails.append("acceptance empty")
		return fails
	var acc_body := _repo_doc_text("docs/content-seasons/season-01/ACCEPTANCE.md")
	if acc_body == "":
		fails.append("ACCEPTANCE.md unreadable")
	for it in items:
		if typeof(it) != TYPE_DICTIONARY:
			fails.append("acceptance item not dict")
			continue
		var id := str(it.get("id", "")).strip_edges()
		var suite := str(it.get("suite", "")).strip_edges()
		var label := str(it.get("label_zh", "")).strip_edges()
		if id == "" or suite == "" or label == "":
			fails.append("acceptance missing id/suite/label")
			continue
		if not suite.begins_with("res://") or not suite.ends_with(".tscn"):
			fails.append("acceptance suite path %s" % suite)
			continue
		if not FileAccess.file_exists(suite):
			fails.append("missing suite %s" % suite)
		if acc_body.find(id) < 0:
			fails.append("ACCEPTANCE missing id %s" % id)
	return fails


func _check_pipeline_stages(d: Dictionary, gates: Dictionary) -> Array:
	var fails: Array = []
	var stages: Variant = d.get("pipeline_stages", {})
	if typeof(stages) != TYPE_DICTIONARY:
		fails.append("pipeline_stages not dict")
		return fails
	var pipe: Array = d.get("pipeline", [])
	for step in pipe:
		var key := str(step)
		if not (stages as Dictionary).has(key):
			fails.append("pipeline_stages missing %s" % key)
			continue
		var st: Variant = (stages as Dictionary)[key]
		if typeof(st) != TYPE_DICTIONARY:
			fails.append("pipeline_stages.%s not dict" % key)
			continue
		var gate_v: Variant = st.get("gate", null)
		var gate := "" if gate_v == null else str(gate_v).strip_edges()
		if gate == "<null>":
			gate = ""
		var open := bool(st.get("open", false))
		if gate != "" and bool(gates.get(gate, false)) == false and open:
			fails.append("stage %s open while gate %s false" % [key, gate])
		if key in ["novel", "bible", "playable"] and open:
			fails.append("stage %s must stay closed pre-signoff" % key)
	return fails


func _check_docs(d: Dictionary) -> Array:
	var fails: Array = []
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
		elif str(rel).ends_with("NOVEL.md") or str(rel).ends_with("BIBLE.md") or str(rel).ends_with("PLAYABLE.md"):
			## Stubs only: keep short and gated; no novel body yet.
			if body.find("闸门") < 0 and body.find("待写") < 0:
				fails.append("stub %s missing 闸门/待写" % rel)
			if body.strip_edges().length() > 240:
				fails.append("stub %s too long (novel body not allowed yet)" % rel)
		elif body.strip_edges() == "":
			fails.append("empty stub %s" % rel)
	return fails


func _check_index() -> Array:
	var fails: Array = []
	var idx := "res://data/content_seasons/index.json"
	if not FileAccess.file_exists(idx):
		fails.append("missing index.json")
		return fails
	var ix = JSON.parse_string(FileAccess.get_file_as_string(idx))
	if typeof(ix) != TYPE_DICTIONARY or not (ix.get("seasons", []) is Array):
		fails.append("index shape")
	elif not ("season_01" in ix.get("seasons", [])):
		fails.append("index missing season_01")
	return fails


func _repo_doc_text(rel: String) -> String:
	var project_root := ProjectSettings.globalize_path("res://").rstrip("/")
	var abs := project_root.get_base_dir().path_join(rel)
	if not FileAccess.file_exists(abs):
		return ""
	return FileAccess.get_file_as_string(abs)
