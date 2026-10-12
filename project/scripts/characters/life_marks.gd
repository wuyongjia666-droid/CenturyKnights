class_name CKLifeMarks
extends RefCounted
## v9.2 life marks on the margin. Cap 9; keep birth; evict oldest non-birth.

const CAP := 9
const DATA_PATH := "res://data/life_marks.json"

static var _doc: Dictionary = {}


static func _load() -> void:
	if not _doc.is_empty():
		return
	if not FileAccess.file_exists(DATA_PATH):
		_doc = {"marks": {}}
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	_doc = parsed if typeof(parsed) == TYPE_DICTIONARY else {"marks": {}}


static func marks() -> Dictionary:
	_load()
	var m = _doc.get("marks", {})
	return m if typeof(m) == TYPE_DICTIONARY else {}


static func zh(id: String) -> String:
	return str(marks().get(id, id))


static func rows(c: CKCharacter) -> Array:
	var raw = c.blood_meta.get("life_marks", null)
	if typeof(raw) != TYPE_ARRAY:
		raw = []
		c.blood_meta["life_marks"] = raw
	return raw


static func ids(c: CKCharacter) -> Array:
	var out: Array = []
	for row in rows(c):
		if typeof(row) == TYPE_DICTIONARY:
			out.append(str(row.get("id", "")))
		elif typeof(row) == TYPE_STRING:
			out.append(str(row))
	return out


static func has(c: CKCharacter, mark_id: String) -> bool:
	return mark_id in ids(c)


static func add(c: CKCharacter, mark_id: String, source: String) -> Dictionary:
	if mark_id == "" or not marks().has(mark_id):
		return {"ok": false, "msg": Locale.t("ux_mark_none"), "evicted": ""}
	if has(c, mark_id):
		return {"ok": false, "msg": Locale.t("ux_mark_has") % zh(mark_id), "evicted": ""}
	var book: Array = rows(c)
	var evicted := ""
	if book.size() >= CAP:
		evicted = _evict(book)
		if evicted == "":
			return {"ok": false, "msg": Locale.t("ux_mark_full"), "evicted": ""}
	book.append({"id": mark_id, "source": source, "seq": book.size()})
	c.blood_meta["life_marks"] = book
	return {"ok": true, "msg": Locale.t("ux_mark_write") % zh(mark_id), "evicted": evicted, "id": mark_id}


static func _evict(book: Array) -> String:
	var best_i := -1
	var best_seq := 999999
	for i in range(book.size()):
		var row: Dictionary = book[i] if typeof(book[i]) == TYPE_DICTIONARY else {"id": str(book[i]), "source": "sui", "seq": i}
		if str(row.get("source", "sui")) == "birth":
			continue
		var seq := int(row.get("seq", i))
		if seq < best_seq:
			best_seq = seq
			best_i = i
	if best_i < 0:
		best_seq = 999999
		for i in range(book.size()):
			var row2: Dictionary = book[i] if typeof(book[i]) == TYPE_DICTIONARY else {"id": str(book[i]), "source": "birth", "seq": i}
			var seq2 := int(row2.get("seq", i))
			if seq2 < best_seq:
				best_seq = seq2
				best_i = i
	if best_i < 0:
		return ""
	var gone: Dictionary = book[best_i] if typeof(book[best_i]) == TYPE_DICTIONARY else {"id": str(book[best_i])}
	var gid := str(gone.get("id", ""))
	book.remove_at(best_i)
	return gid


static func roll_birth(c: CKCharacter, rng: RandomNumberGenerator = null) -> Array:
	_load()
	var r := rng
	if r == null:
		r = RandomNumberGenerator.new()
		r.seed = hash(str(c.id) + "|birth_marks")
	var count_w: Array = _doc.get("count_w", [180, 240, 220, 160, 100, 60, 25, 10, 4, 1])
	var count := _pick_weighted(count_w, r)
	var pool: Array = []
	for mid in _doc.get("meet", []):
		pool.append({"id": str(mid), "w": int(_doc.get("meet_w", 16))})
	for mid in _doc.get("mischief", []):
		pool.append({"id": str(mid), "w": int(_doc.get("mischief_w", 12))})
	for mid in _doc.get("lesson", []):
		pool.append({"id": str(mid), "w": int(_doc.get("lesson_w", 6))})
	var got: Array = []
	for _i in range(count):
		if pool.is_empty():
			break
		var pick := _pick_pool(pool, r)
		if pick == "":
			break
		var res := add(c, pick, "birth")
		if bool(res.get("ok", false)):
			got.append(pick)
		for j in range(pool.size() - 1, -1, -1):
			if str(pool[j].get("id", "")) == pick:
				pool.remove_at(j)
				break
	return got


static func job_mark(job_id: String) -> String:
	match job_id:
		"light_cavalry", "cavalry", "scout":
			return "bridge"
		"skirmisher", "light_inf", "light_infantry":
			return "slip"
		"archer", "hunter", "marksman":
			return "watch"
		"heavy_inf", "sentinel", "guard":
			return "hone"
		"warrior":
			return "seize"
		"priest", "chanter", "singer":
			return "lamp"
		"mystic", "adept":
			return "copy"
		"banner", "standard", "flagbearer":
			return "seize"
		_:
			return "hone"


static func _pick_weighted(weights: Array, rng: RandomNumberGenerator) -> int:
	var total := 0
	for w in weights:
		total += int(w)
	if total <= 0:
		return 0
	var roll := rng.randi() % total
	var acc := 0
	for i in range(weights.size()):
		acc += int(weights[i])
		if roll < acc:
			return i
	return weights.size() - 1


static func _pick_pool(pool: Array, rng: RandomNumberGenerator) -> String:
	var total := 0
	for row in pool:
		total += int(row.get("w", 1))
	if total <= 0:
		return ""
	var roll := rng.randi() % total
	var acc := 0
	for row in pool:
		acc += int(row.get("w", 1))
		if roll < acc:
			return str(row.get("id", ""))
	return str(pool.back().get("id", ""))
