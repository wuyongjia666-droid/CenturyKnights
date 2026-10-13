class_name CKJobSeals
extends RefCounted
## v9.2 职印：特殊职业要先在指定的城盖印才能转。三阶职业照旧不设城门，保证永远转得了。
## 盖印条件：人现在就是那门二阶、人在那座城、这城声望到「友善」、本城之事已办。

const DATA := "res://data/job_seals_v92.json"
static var _doc: Dictionary = {}


static func _load() -> Dictionary:
	if _doc.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA)) if FileAccess.file_exists(DATA) else null
		_doc = parsed if typeof(parsed) == TYPE_DICTIONARY else {"special": []}
	return _doc


static func seal_row(job_id: String) -> Dictionary:
	for r in _load().get("special", []):
		if str(r.get("job", "")) == job_id:
			return r
	return {}


static func rows_for_city(city: String) -> Array:
	var out: Array = []
	for r in _load().get("special", []):
		if str(r.get("city", "")) == city:
			out.append(r)
	return out


static func has_seal(c: CKCharacter, job_id: String) -> bool:
	if c == null:
		return false
	var seals = c.blood_meta.get("job_seals", [])
	return typeof(seals) == TYPE_ARRAY and job_id in seals


static func can_stamp(c: CKCharacter, job_id: String, city: String) -> Dictionary:
	var r := seal_row(job_id)
	if r.is_empty():
		return {"ok": false, "msg": Locale.t("js_4b8f35c4")}
	if c == null or not c.alive:
		return {"ok": false, "msg": Locale.t("js_858ac10f")}
	if has_seal(c, job_id):
		return {"ok": false, "msg": Locale.t("js_36ebe4cd") % c.name}
	var nm := str(r.get("name", job_id))
	if str(r.get("city", "")) != city:
		return {"ok": false, "msg": Locale.t("js_747937cc") % [nm, str(World.node(str(r.get("city", ""))).get("name", r.get("city", "")))]}
	var from_name := str(GameState.get_job(str(r.get("from", ""))).get("name", r.get("from", "")))
	if c.job_id != str(r.get("from", "")):
		return {"ok": false, "msg": Locale.t("js_16f4d3d9") % [from_name, nm]}
	var need := int(_load().get("rep_friendly", 30))
	if World.rep_of(city) < need:
		return {"ok": false, "msg": Locale.t("js_a6b0b659") % [need, World.rep_of(city)]}
	if not CKCityAffairs.done(city):
		return {"ok": false, "msg": Locale.t("js_80a18b3b")}
	return {"ok": true, "msg": ""}


static func stamp(c: CKCharacter, job_id: String, city: String) -> Dictionary:
	var chk := can_stamp(c, job_id, city)
	if not bool(chk.get("ok", false)):
		return chk
	var seals = c.blood_meta.get("job_seals", [])
	if typeof(seals) != TYPE_ARRAY:
		seals = []
	seals.append(job_id)
	c.blood_meta["job_seals"] = seals
	GameState.mark_dirty()
	return {"ok": true, "msg": Locale.t("js_820fde2c") % [c.name, str(seal_row(job_id).get("name", job_id))]}


## try_promote 用：特殊职业没印不让转；其它职业不管。
static func promote_gate(c: CKCharacter, job_id: String) -> Dictionary:
	var r := seal_row(job_id)
	if r.is_empty() or has_seal(c, job_id):
		return {"ok": true, "msg": ""}
	return {"ok": false, "msg": Locale.t("js_e4c54013") % [str(r.get("name", job_id)), str(World.node(str(r.get("city", ""))).get("name", r.get("city", "")))]}
