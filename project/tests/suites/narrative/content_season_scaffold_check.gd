extends Node
## 内容季流水脚手架（多季）：index 内每季机器表 + 选题清单 + 验收 suite + 闸门。
## season_01 / season_02 / season_03（有 playable_chapter）：完整流水门禁（正文体量+可玩章）。
## season_04+：novel_allowed；NOVEL 须有正文（非纯「待写」stub）。

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
	var min_ver := 3 if sid == "season_01" else 2
	if int(d.get("version", 0)) < min_ver:
		fails.append("%s version want >= %d" % [sid, min_ver])
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
	var status := str(d.get("status", ""))
	var stage := str(d.get("stage", ""))
	if sid == "season_01":
		if not novel_allowed:
			fails.append("season_01 novel_allowed must be true (pipeline opened)")
		if not bool(gates.get("topic_user_ack", false)):
			fails.append("season_01 topic_user_ack must be true")
		if status not in ["playable_draft", "novel_draft", "in_pipeline"]:
			fails.append("season_01 status want playable_draft/novel_draft/in_pipeline got %s" % status)
		if stage not in ["novel", "bible", "playable", "systems", "art", "playtest"]:
			fails.append("season_01 stage want post-topic got %s" % stage)
		fails.append_array(_check_playable_chapter(d, sid))
	elif sid == "season_02" and str(d.get("playable_chapter", "")).strip_edges() != "":
		if not novel_allowed:
			fails.append("season_02 novel_allowed must be true")
		if not bool(gates.get("topic_user_ack", false)):
			fails.append("season_02 topic_user_ack must be true")
		if int(d.get("version", 0)) < 3:
			fails.append("season_02 version want >= 3")
		if status not in ["playable_draft", "novel_draft", "in_pipeline"]:
			fails.append("season_02 status want playable_draft/novel_draft/in_pipeline got %s" % status)
		if stage not in ["novel", "bible", "playable", "systems", "art", "playtest"]:
			fails.append("season_02 stage want post-topic got %s" % stage)
		fails.append_array(_check_playable_chapter(d, sid))
	elif sid == "season_03" and str(d.get("playable_chapter", "")).strip_edges() != "":
		if not novel_allowed:
			fails.append("season_03 novel_allowed must be true")
		if not bool(gates.get("topic_user_ack", false)):
			fails.append("season_03 topic_user_ack must be true")
		if int(d.get("version", 0)) < 3:
			fails.append("season_03 version want >= 3")
		if status not in ["playable_draft", "novel_draft", "in_pipeline"]:
			fails.append("season_03 status want playable_draft/novel_draft/in_pipeline got %s" % status)
		if stage not in ["novel", "bible", "playable", "systems", "art", "playtest"]:
			fails.append("season_03 stage want post-topic got %s" % stage)
		fails.append_array(_check_playable_chapter(d, sid))
	else:
		if not novel_allowed:
			fails.append("%s novel_allowed should be true (time-compress full content)" % sid)
		if status == "":
			fails.append("%s empty status" % sid)
		if stage == "" or not (stage in pipe):
			fails.append("%s bad stage %s" % [sid, stage])

	fails.append_array(_check_topic_checklist(d, folder, sid))
	fails.append_array(_check_acceptance(d, folder, sid))
	fails.append_array(_check_pipeline_stages(d, gates, sid, novel_allowed))
	fails.append_array(_check_docs(d, folder, sid, novel_allowed))
	return fails


func _check_playable_chapter(d: Dictionary, sid: String) -> Array:
	var fails: Array = []
	if not d.has("playable_chapter") and not d.has("playable_path"):
		return fails
	var ch := str(d.get("playable_chapter", "")).strip_edges()
	var p := str(d.get("playable_path", "")).strip_edges()
	if sid == "season_01":
		if ch != "cs01_01":
			fails.append("season_01 playable_chapter want cs01_01")
		if p != "res://data/story/chapters/cs01_01.json":
			fails.append("season_01 playable_path")
	elif sid == "season_02":
		if ch != "cs02_01":
			fails.append("season_02 playable_chapter want cs02_01")
		if p != "res://data/story/chapters/cs02_01.json":
			fails.append("season_02 playable_path")
	elif sid == "season_03":
		if ch != "cs03_01":
			fails.append("season_03 playable_chapter want cs03_01")
		if p != "res://data/story/chapters/cs03_01.json":
			fails.append("season_03 playable_path")
	if p != "" and not FileAccess.file_exists(p):
		fails.append("%s missing playable chapter file" % sid)
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
	var saw_playable := false
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
		if id == "playable_dialogue":
			saw_playable = true
	if sid == "season_01" and not saw_playable:
		fails.append("season_01 acceptance missing playable_dialogue")
	if sid == "season_02" and str(d.get("playable_chapter", "")).strip_edges() != "" and not saw_playable:
		fails.append("season_02 acceptance missing playable_dialogue")
	if sid == "season_03" and str(d.get("playable_chapter", "")).strip_edges() != "" and not saw_playable:
		fails.append("season_03 acceptance missing playable_dialogue")
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
			fails.append("%s stage %s must stay closed when novel_allowed false" % [sid, key])
		if novel_allowed and key in ["novel", "bible", "playable"]:
			if not open:
				fails.append("%s stage %s must be open when novel_allowed" % [sid, key])
			if gate != "novel_allowed":
				fails.append("%s stage %s gate want novel_allowed" % [sid, key])
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
					var min_len := 8000 if sid == "season_01" else 1200
					var s02_playable := sid == "season_02" and str(d.get("playable_chapter", "")).strip_edges() != ""
					var s03_playable := sid == "season_03" and str(d.get("playable_chapter", "")).strip_edges() != ""
					if s02_playable:
						var hanzi := _hanzi_count(body)
						if hanzi < 10000:
							fails.append("season_02 NOVEL hanzi %d < 10000" % hanzi)
						if body.find("回执") < 0:
							fails.append("season_02 NOVEL missing 回执")
					elif s03_playable:
						var hanzi := _hanzi_count(body)
						if hanzi < 12000:
							fails.append("season_03 NOVEL hanzi %d < 12000" % hanzi)
						if body.find("回执") < 0:
							fails.append("season_03 NOVEL missing 回执")
					else:
						if body.strip_edges().length() < min_len:
							fails.append("%s NOVEL too short" % sid)
						if body.find("待写") >= 0 and body.strip_edges().length() < 400:
							fails.append("%s NOVEL still stub" % sid)
						if sid == "season_01" and body.find("回执") < 0:
							fails.append("season_01 NOVEL missing 回执")
				elif str(rel).ends_with("BIBLE.md"):
					if body.strip_edges() == "":
						fails.append("%s empty %s" % [sid, rel])
					if sid == "season_01" and body.strip_edges().length() < 800:
						fails.append("season_01 BIBLE too short")
					if sid == "season_02" and str(d.get("playable_chapter", "")).strip_edges() != "":
						if body.strip_edges().length() < 800:
							fails.append("season_02 BIBLE too short")
						if body.find("一句话") < 0 and body.find("主题") < 0:
							fails.append("season_02 BIBLE missing 一句话/主题")
					if sid == "season_03" and str(d.get("playable_chapter", "")).strip_edges() != "":
						if body.strip_edges().length() < 800:
							fails.append("season_03 BIBLE too short")
						if body.find("一句话") < 0 and body.find("主题") < 0:
							fails.append("season_03 BIBLE missing 一句话/主题")
				elif str(rel).ends_with("PLAYABLE.md"):
					if body.strip_edges() == "":
						fails.append("%s empty %s" % [sid, rel])
					if sid == "season_01":
						if body.find("cs01_01") < 0:
							fails.append("season_01 PLAYABLE missing cs01_01")
						if body.find("60") < 0:
							fails.append("season_01 PLAYABLE missing 60-hanzi rule")
					if sid == "season_02" and str(d.get("playable_chapter", "")).strip_edges() != "":
						if body.find("cs02_01") < 0:
							fails.append("season_02 PLAYABLE missing cs02_01")
						if body.find("60") < 0:
							fails.append("season_02 PLAYABLE missing 60-hanzi rule")
					if sid == "season_03" and str(d.get("playable_chapter", "")).strip_edges() != "":
						if body.find("cs03_01") < 0:
							fails.append("season_03 PLAYABLE missing cs03_01")
						if body.find("60") < 0:
							fails.append("season_03 PLAYABLE missing 60-hanzi rule")
		elif body.strip_edges() == "":
			fails.append("%s empty stub %s" % [sid, rel])
	return fails


func _repo_doc_text(rel: String) -> String:
	var project_root := ProjectSettings.globalize_path("res://").rstrip("/")
	var abs := project_root.get_base_dir().path_join(rel)
	if not FileAccess.file_exists(abs):
		return ""
	return FileAccess.get_file_as_string(abs)


func _hanzi_count(text: String) -> int:
	var n := 0
	for i in text.length():
		var c := text.unicode_at(i)
		if c >= 0x4E00 and c <= 0x9FFF:
			n += 1
	return n
