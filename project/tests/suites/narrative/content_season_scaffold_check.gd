extends Node
## 内容季流水脚手架（v2 多季）：index 内每季机器表 + 选题清单 + 验收 suite + 闸门。
## season_01：签收前 novel_allowed 必须 false，小说 stub 宜短。
## season_02+：允许 novel_allowed true；NOVEL 须有正文（非纯「待写」stub）。

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
	fails.append_array(_check_index_and_seasons())
	return "; ".join(fails)


func _check_index_and_seasons() -> Array:
	var fails: Array = []
	var idx := "res://data/content_seasons/index.json"
	if not FileAccess.file_exists(idx):
		fails.append("missing index.json")
		return fails
	var ix = JSON.parse_string(FileAccess.get_file_as_string(idx))
	if typeof(ix) != TYPE_DICTIONARY or not (ix.get("seasons", []) is Array):
		fails.append("index shape")
		return fails
	var seasons: Array = ix.get("seasons", [])
	if not ("season_01" in seasons):
		fails.append("index missing season_01")
	if not ("season_02" in seasons):
		fails.append("index missing season_02")
	if not ("season_03" in seasons):
		fails.append("index missing season_03")
	for sid_v in seasons:
		var sid := str(sid_v)
		fails.append_array(_check_one_season(sid))
	return fails


func _check_one_season(sid: String) -> Array:
	var fails: Array = []
	var path := "res://data/content_seasons/%s.json" % sid
	if not FileAccess.file_exists(path):
		fails.append("missing " + path)
		return fails
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		fails.append("%s not a dict" % sid)
		return fails
	var d: Dictionary = parsed
	for k in [
		"id", "version", "title_zh", "status", "pipeline", "stage", "flag_lamp",
		"system_deepen", "system_deepen_zh", "gates", "docs_rel",
		"topic_checklist", "acceptance", "pipeline_stages",
	]:
		if not d.has(k):
			fails.append("%s missing field %s" % [sid, k])
	if int(d.get("version", 0)) < 2:
		fails.append("%s version want >= 2" % sid)
	if str(d.get("id", "")) != sid:
		fails.append("%s id" % sid)
	var pipe: Array = d.get("pipeline", [])
	var want_pipe := ["topic", "novel", "bible", "playable", "systems", "art", "playtest"]
	if pipe != want_pipe:
		fails.append("%s pipeline %s" % [sid, str(pipe)])
	var fl: Dictionary = d.get("flag_lamp", {})
	if str(fl.get("flag", "")).strip_edges() == "" or str(fl.get("lamp", "")).strip_edges() == "":
		fails.append("%s flag_lamp empty" % sid)
	if str(d.get("system_deepen", "")).strip_edges() == "":
		fails.append("%s system_deepen empty" % sid)
	var gates: Dictionary = d.get("gates", {})
	var novel_allowed := bool(gates.get("novel_allowed", false))
	var folder := sid.replace("_", "-")
	# season_01 keeps pre-signoff lock unless explicitly opened later by its own knife.
	if sid == "season_01":
		if novel_allowed:
			fails.append("season_01 novel_allowed must stay false pre-signoff")
		if bool(gates.get("y1a_device_signoff", true)):
			fails.append("season_01 y1a_device_signoff must be false until user signs")
		if str(d.get("status", "")) != "topic_scaffold":
			fails.append("season_01 status want topic_scaffold")
		if str(d.get("stage", "")) != "topic":
			fails.append("season_01 stage want topic")
	else:
		if not novel_allowed:
			fails.append("%s novel_allowed should be true (time-compress full content)" % sid)
		var st := str(d.get("status", ""))
		if st == "":
			fails.append("%s empty status" % sid)
		var stage := str(d.get("stage", ""))
		if stage == "" or not (stage in pipe):
			fails.append("%s bad stage %s" % [sid, stage])

	fails.append_array(_check_topic_checklist(d, folder, sid))
	fails.append_array(_check_acceptance(d, folder, sid))
	fails.append_array(_check_pipeline_stages(d, gates, sid, novel_allowed))
	fails.append_array(_check_docs(d, folder, sid, novel_allowed))
	return fails


func _check_topic_checklist(d: Dictionary, folder: String, sid: String) -> Array:
	var fails: Array = []
	var items: Variant = d.get("topic_checklist", [])
	if typeof(items) != TYPE_ARRAY or (items as Array).is_empty():
		fails.append("%s topic_checklist empty" % sid)
		return fails
	var topic_body := _repo_doc_text("docs/content-seasons/%s/TOPIC.md" % folder)
	var checklist_body := _repo_doc_text("docs/content-seasons/%s/CHECKLIST.md" % folder)
	if topic_body == "":
		fails.append("%s TOPIC.md unreadable" % sid)
	if checklist_body == "":
		fails.append("%s CHECKLIST.md unreadable" % sid)
	for it in items:
		if typeof(it) != TYPE_DICTIONARY:
			fails.append("%s topic_checklist item not dict" % sid)
			continue
		var id := str(it.get("id", "")).strip_edges()
		var label := str(it.get("label_zh", "")).strip_edges()
		if id == "" or label == "":
			fails.append("%s topic_checklist missing id/label" % sid)
			continue
		if topic_body.find(label) < 0:
			fails.append("%s TOPIC missing checklist label %s" % [sid, label])
		if checklist_body.find(id) < 0:
			fails.append("%s CHECKLIST missing id %s" % [sid, id])
	return fails


func _check_acceptance(d: Dictionary, folder: String, sid: String) -> Array:
	var fails: Array = []
	var items: Variant = d.get("acceptance", [])
	if typeof(items) != TYPE_ARRAY or (items as Array).is_empty():
		fails.append("%s acceptance empty" % sid)
		return fails
	var acc_body := _repo_doc_text("docs/content-seasons/%s/ACCEPTANCE.md" % folder)
	if acc_body == "":
		fails.append("%s ACCEPTANCE.md unreadable" % sid)
	for it in items:
		if typeof(it) != TYPE_DICTIONARY:
			fails.append("%s acceptance item not dict" % sid)
			continue
		var id := str(it.get("id", "")).strip_edges()
		var suite := str(it.get("suite", "")).strip_edges()
		var label := str(it.get("label_zh", "")).strip_edges()
		if id == "" or suite == "" or label == "":
			fails.append("%s acceptance missing id/suite/label" % sid)
			continue
		if not suite.begins_with("res://") or not suite.ends_with(".tscn"):
			fails.append("%s acceptance suite path %s" % [sid, suite])
			continue
		if not FileAccess.file_exists(suite):
			fails.append("%s missing suite %s" % [sid, suite])
		if acc_body.find(id) < 0:
			fails.append("%s ACCEPTANCE missing id %s" % [sid, id])
	return fails


func _check_pipeline_stages(d: Dictionary, gates: Dictionary, sid: String, novel_allowed: bool) -> Array:
	var fails: Array = []
	var stages: Variant = d.get("pipeline_stages", {})
	if typeof(stages) != TYPE_DICTIONARY:
		fails.append("%s pipeline_stages not dict" % sid)
		return fails
	var pipe: Array = d.get("pipeline", [])
	for step in pipe:
		var key := str(step)
		if not (stages as Dictionary).has(key):
			fails.append("%s pipeline_stages missing %s" % [sid, key])
			continue
		var st: Variant = (stages as Dictionary)[key]
		if typeof(st) != TYPE_DICTIONARY:
			fails.append("%s pipeline_stages.%s not dict" % [sid, key])
			continue
		var gate_v: Variant = st.get("gate", null)
		var gate := "" if gate_v == null else str(gate_v).strip_edges()
		if gate == "<null>":
			gate = ""
		var open := bool(st.get("open", false))
		if gate != "" and bool(gates.get(gate, false)) == false and open:
			fails.append("%s stage %s open while gate %s false" % [sid, key, gate])
		if not novel_allowed and key in ["novel", "bible", "playable"] and open:
			fails.append("%s stage %s must stay closed pre-signoff" % [sid, key])
		if novel_allowed and key == "novel" and not open:
			fails.append("%s novel stage should be open when novel_allowed" % sid)
	return fails


func _check_docs(d: Dictionary, folder: String, sid: String, novel_allowed: bool) -> Array:
	var fails: Array = []
	var project_root := ProjectSettings.globalize_path("res://").rstrip("/")
	var repo := project_root.get_base_dir()
	for rel in d.get("docs_rel", []):
		var abs := repo.path_join(str(rel))
		if not FileAccess.file_exists(abs):
			fails.append("%s missing doc %s" % [sid, rel])
			continue
		var body := FileAccess.get_file_as_string(abs)
		if str(rel).ends_with("TOPIC.md"):
			if body.find("旗") < 0 and body.find("灯") < 0:
				fails.append("%s TOPIC missing 旗/灯" % sid)
			var deepen_zh := str(d.get("system_deepen_zh", ""))
			if deepen_zh != "" and body.find(deepen_zh) < 0:
				# soft: also accept system_deepen id fragment in topic
				if body.find(str(d.get("system_deepen", ""))) < 0 and body.find("本季加深的系统") < 0:
					fails.append("%s TOPIC missing system deepen" % sid)
		elif str(rel).ends_with("NOVEL.md") or str(rel).ends_with("BIBLE.md") or str(rel).ends_with("PLAYABLE.md"):
			if not novel_allowed:
				if body.find("闸门") < 0 and body.find("待写") < 0:
					fails.append("%s stub %s missing 闸门/待写" % [sid, rel])
				if body.strip_edges().length() > 240:
					fails.append("%s stub %s too long (novel body not allowed yet)" % [sid, rel])
			else:
				if str(rel).ends_with("NOVEL.md"):
					if body.strip_edges().length() < 1200:
						fails.append("%s NOVEL too short" % sid)
					if body.find("待写") >= 0 and body.strip_edges().length() < 400:
						fails.append("%s NOVEL still stub" % sid)
				elif body.strip_edges() == "":
					fails.append("%s empty %s" % [sid, rel])
		elif body.strip_edges() == "":
			fails.append("%s empty stub %s" % [sid, rel])
	return fails


func _repo_doc_text(rel: String) -> String:
	var project_root := ProjectSettings.globalize_path("res://").rstrip("/")
	var abs := project_root.get_base_dir().path_join(rel)
	if not FileAccess.file_exists(abs):
		return ""
	return FileAccess.get_file_as_string(abs)
