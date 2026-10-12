class_name CKJobSeals
extends RefCounted
## v9.2 三阶职印与六门特殊职业门闩。

const DATA := "res://data/job_seals_v92.json"
static var _doc: Dictionary = {}


static func _load() -> Dictionary:
	if not _doc.is_empty():
		return _doc
	if not FileAccess.file_exists(DATA):
		_doc = {}
		return _doc
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	_doc = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	return _doc


static func seal_row(job_id: String) -> Dictionary:
	for row in _load().get("tier3", []):
		if str(row.get("job", "")) == job_id:
			return row
	for row in _load().get("special", []):
		if str(row.get("job", "")) == job_id:
			return row
	return {}


static func is_special(job_id: String) -> bool:
	for row in _load().get("special", []):
		if str(row.get("job", "")) == job_id:
			return true
	return false


static func promote_options(c: CKCharacter) -> Array:
	if c == null:
		return []
	var out: Array = []
	for row in _load().get("tier3", []):
		if str(row.get("from", "")) == c.job_id:
			out.append(str(row.get("job", "")))
	for row in _load().get("special", []):
		if str(row.get("from", "")) == c.job_id:
			out.append(str(row.get("job", "")))
	return out


static func can_take(c: CKCharacter, job_id: String, city: String) -> Dictionary:
	var row := seal_row(job_id)
	if row.is_empty():
		return {"ok": true, "msg": ""}
	if c == null or not c.alive:
		return {"ok": false, "msg": Locale.t("seal_no_person")}
	if str(row.get("from", "")) != c.job_id and not _has_seal(c, str(row.get("from", ""))):
		## 已有职印的可从并列侧换回
		if not _has_seal(c, job_id) and str(c.job_id) != str(row.get("from", "")):
			return {"ok": false, "msg": Locale.t("seal_wrong_job")}
	var need_city := str(row.get("city", ""))
	if city != need_city:
		return {"ok": false, "msg": Locale.t("seal_wrong_city") % _city_name(need_city)}
	var need_rep := int(_load().get("rep_friendly", 30))
	var rep := 0
	if World.has_method("city_rep"):
		rep = int(World.city_rep(city))
	elif World.has_method("rep_of"):
		rep = int(World.rep_of(city))
	if rep < need_rep:
		return {"ok": false, "msg": Locale.t("seal_rep") % need_rep}
	if not bool(GameState.flags.get("affair_%s" % city, false)):
		return {"ok": false, "msg": Locale.t("seal_affair")}
	var battles := int(c.blood_meta.get("job_battles", 0))
	if battles < int(_load().get("job_battles_min", 1)) and str(c.job_id) == str(row.get("from", "")):
		return {"ok": false, "msg": Locale.t("seal_battles")}
	if is_special(job_id):
		var mark := str(row.get("mark", ""))
		var duty_done := bool(c.blood_meta.get("seal_duty_%s" % job_id, false))
		var has_mark := mark != "" and CKLifeMarks.has(c, mark)
		if not has_mark and not duty_done:
			return {"ok": false, "msg": Locale.t("seal_mark_or_duty") % CKLifeMarks.zh(mark)}
	return {"ok": true, "msg": ""}


static func grant_seal(c: CKCharacter, job_id: String) -> void:
	if c == null:
		return
	var seals = c.blood_meta.get("job_seals", null)
	if typeof(seals) != TYPE_ARRAY:
		seals = []
	if job_id not in seals:
		seals.append(job_id)
	c.blood_meta["job_seals"] = seals


static func _has_seal(c: CKCharacter, job_id: String) -> bool:
	var seals = c.blood_meta.get("job_seals", [])
	return typeof(seals) == TYPE_ARRAY and job_id in seals



static func _city_name(cid: String) -> String:
	if World.has_method("node_name"):
		return str(World.node_name(cid))
	return cid


static func complete_duty(c: CKCharacter, job_id: String) -> void:
	if c == null:
		return
	c.blood_meta["seal_duty_%s" % job_id] = true
