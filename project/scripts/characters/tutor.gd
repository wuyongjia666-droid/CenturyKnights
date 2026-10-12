class_name CKTutor
extends RefCounted
## v9.2 banner-school tutoring. Board #5: 1 pupil base, 2 with shi-xing; academy adds pairs.

const SHI_XING := {
	"shoulder": {"key": "ux_shi_shoulder", "stat": "str", "w": 12},
	"lamp": {"key": "ux_shi_lamp", "stat": "wil", "w": 12},
	"market": {"key": "ux_shi_market", "stat": "skl", "w": 10},
	"tide": {"key": "ux_shi_tide", "stat": "vit", "w": 12},
	"alley": {"key": "ux_shi_alley", "stat": "per", "w": 8},
	"road": {"key": "ux_shi_road", "stat": "agi", "w": 10},
}

const TEACHABLE := {
	"diligent": {"trait": "scholar", "jobs": ["mystic", "chanter", "banner", "singer", "adept"], "zh_key": "ux_teach_diligent"},
	"steady_gut": {"trait": "iron_gut", "jobs": ["heavy_inf", "sentinel", "warrior", "guard"], "zh_key": "ux_teach_gut"},
	"wound_first": {"trait": "lucky", "jobs": ["priest"], "zh_key": "ux_teach_wound"},
	"stand_firm": {"trait": "sturdy", "jobs": ["sentinel", "heavy_inf", "guard"], "zh_key": "ux_teach_stand"},
}


static func _book() -> Dictionary:
	var raw = GameState.house_mods.get("tutors", null)
	if typeof(raw) != TYPE_DICTIONARY:
		raw = {}
		GameState.house_mods["tutors"] = raw
	return raw


static func _year_counts() -> Dictionary:
	var raw = GameState.house_mods.get("tutor_year", null)
	if typeof(raw) != TYPE_DICTIONARY:
		raw = {}
		GameState.house_mods["tutor_year"] = raw
	return raw


static func pair_cap(host = null) -> int:
	var h = host if host != null else GameState
	return 1 + CKCastleServices.annex_level(h, "academy")


static func tutor_of(child_id: String) -> String:
	return str(_book().get(child_id, ""))


static func pupils_of(tutor_id: String) -> Array:
	var out: Array = []
	var book := _book()
	for cid in book.keys():
		if str(book[cid]) == tutor_id:
			out.append(str(cid))
	return out


static func shi_xing_of(cid: String) -> String:
	var book = GameState.house_mods.get("shi_xing", null)
	if typeof(book) != TYPE_DICTIONARY:
		return ""
	return str(book.get(cid, ""))


static func tutor_pupil_cap(tutor: CKCharacter) -> int:
	if tutor == null:
		return 1
	return 2 if shi_xing_of(tutor.id) != "" else 1


static func can_be_pupil(c: CKCharacter) -> bool:
	if c == null or not c.alive:
		return false
	if c.age < 1 or c.age > 15:
		return false
	if c.in_roster:
		return false
	return c.is_child or not c.parent_ids.is_empty()


static func can_be_tutor(c: CKCharacter) -> bool:
	if c == null or not c.alive or not c.in_roster:
		return false
	if c.age < 16:
		return false
	if c.injured:
		return false
	return true


static func assign(child_id: String, tutor_id: String) -> Dictionary:
	var child: CKCharacter = GameState.characters.get(child_id)
	var tutor: CKCharacter = GameState.characters.get(tutor_id)
	if not can_be_pupil(child):
		return {"ok": false, "msg": Locale.t("ux_tutor_bad_pupil")}
	if not can_be_tutor(tutor):
		return {"ok": false, "msg": Locale.t("ux_tutor_bad_tutor")}
	if child_id == tutor_id:
		return {"ok": false, "msg": Locale.t("ux_tutor_self")}
	var book := _book()
	var prev := str(book.get(child_id, ""))
	if prev == tutor_id:
		return {"ok": true, "msg": Locale.t("ux_tutor_same")}
	var pairs := 0
	for cid in book.keys():
		if str(cid) == child_id:
			continue
		if str(book[cid]) != "":
			pairs += 1
	if pairs >= pair_cap():
		return {"ok": false, "msg": Locale.t("ux_tutor_pairs_full")}
	if pupils_of(tutor_id).size() >= tutor_pupil_cap(tutor) and prev != tutor_id:
		var already := false
		for pid in pupils_of(tutor_id):
			if pid == child_id:
				already = true
		if not already:
			return {"ok": false, "msg": Locale.t("ux_tutor_full")}
	book[child_id] = tutor_id
	GameState.mark_dirty()
	return {"ok": true, "msg": Locale.t("ux_tutor_assign") % [child.name, tutor.name]}


static func clear_pupil(child_id: String) -> void:
	_book().erase(child_id)


static func year_limit(host = null) -> int:
	var h = host if host != null else GameState
	var lv := CKEconomyState.building_level(h, "barracks")
	if lv >= 5:
		return 4
	if lv >= 3:
		return 3
	return 2


static func year_used(child_id: String, tutor_id: String) -> int:
	var key := "%s|%s|%d" % [child_id, tutor_id, Calendar.year]
	return int(_year_counts().get(key, 0))


static func _bump_year(child_id: String, tutor_id: String) -> void:
	var key := "%s|%s|%d" % [child_id, tutor_id, Calendar.year]
	var book := _year_counts()
	book[key] = int(book.get(key, 0)) + 1


static func peak_stat(c: CKCharacter) -> String:
	var best := "wil"
	var best_v := -1
	for k in CKCharacter.STAT_KEYS:
		var v := int(c.stats.get(k, 0))
		if v > best_v:
			best_v = v
			best = k
		elif v == best_v and not GameState.advisor_bonus.is_empty():
			if GameState.advisor_bonus.has(k) and not GameState.advisor_bonus.has(best):
				best = k
	return best


static func preview(child_id: String) -> Dictionary:
	var child: CKCharacter = GameState.characters.get(child_id)
	var tid := tutor_of(child_id)
	var tutor: CKCharacter = GameState.characters.get(tid)
	if child == null or tutor == null:
		return {"ok": false, "msg": Locale.t("ux_tutor_no_tutor")}
	if year_used(child_id, tid) >= year_limit():
		return {"ok": false, "msg": Locale.t("ux_tutor_year_full")}
	if not can_be_tutor(tutor):
		return {"ok": false, "msg": Locale.t("ux_tutor_hurt")}
	var key := peak_stat(tutor)
	var special := _is_special(tutor)
	var gain := 2 if special else 1
	var shi := shi_xing_of(tid)
	var shi_stat := ""
	if special and shi != "" and SHI_XING.has(shi):
		shi_stat = str(SHI_XING[shi].get("stat", ""))
	var mark := CKLifeMarks.job_mark(tutor.job_id)
	var shi_extra := ""
	if shi_stat != "":
		shi_extra = Locale.t("ux_tutor_shi_extra") % Locale.t("stat_" + shi_stat)
	return {
		"ok": true,
		"stat": key,
		"gain": gain,
		"shi_stat": shi_stat,
		"mark": mark,
		"special": special,
		"msg": Locale.t("ux_tutor_preview") % [Locale.t("stat_" + key), gain, shi_extra, CKLifeMarks.zh(mark)],
	}


static func _is_special(tutor: CKCharacter) -> bool:
	if shi_xing_of(tutor.id) != "":
		return true
	for k in CKCharacter.STAT_KEYS:
		if int(tutor.stats.get(k, 0)) >= 14:
			return true
	return false


static func teach(child_id: String) -> Dictionary:
	var prev := preview(child_id)
	if not bool(prev.get("ok", false)):
		return prev
	var child: CKCharacter = GameState.characters.get(child_id)
	var tid := tutor_of(child_id)
	var tutor: CKCharacter = GameState.characters.get(tid)
	Calendar.advance(1)
	var key := str(prev.get("stat", "wil"))
	var gain := int(prev.get("gain", 1))
	child.stats[key] = mini(int(child.apt_max.get(key, 20)), int(child.stats.get(key, 8)) + gain)
	var shi_stat := str(prev.get("shi_stat", ""))
	if shi_stat != "":
		child.stats[shi_stat] = mini(int(child.apt_max.get(shi_stat, 20)), int(child.stats.get(shi_stat, 8)) + 1)
	var mark_id := str(prev.get("mark", ""))
	var mark_res := CKLifeMarks.add(child, mark_id, "tutor")
	if bool(prev.get("special", false)):
		_try_teach_trait(tutor, child)
	_bump_year(child_id, tid)
	child.recalc_hp()
	GameState.mark_dirty()
	var msg := Locale.t("ux_tutor_teach") % [child.name, tutor.name, Locale.t("stat_" + key), gain]
	if shi_stat != "":
		msg += Locale.t("ux_tutor_shi_gain") % Locale.t("stat_" + shi_stat)
	if bool(mark_res.get("ok", false)):
		msg += "; " + str(mark_res.get("msg", ""))
		if str(mark_res.get("evicted", "")) != "":
			msg += Locale.t("ux_tutor_evict") % CKLifeMarks.zh(str(mark_res.get("evicted", "")))
	return {"ok": true, "msg": msg}


static func _try_teach_trait(tutor: CKCharacter, child: CKCharacter) -> void:
	for _name in TEACHABLE.keys():
		var row: Dictionary = TEACHABLE[_name]
		var trait_id := str(row.get("trait", ""))
		if trait_id == "" or trait_id in child.traits:
			continue
		var jobs: Array = row.get("jobs", [])
		var suited := trait_id in tutor.traits or tutor.job_id in jobs
		if not suited:
			continue
		var tries_key := "teach_try_%s_%s" % [child.id, trait_id]
		var fails_key := "teach_fail_%s_%s" % [child.id, trait_id]
		var tries := int(GameState.house_mods.get(tries_key, 0))
		if tries >= 3 or bool(GameState.house_mods.get(fails_key, false)):
			continue
		GameState.house_mods[tries_key] = tries + 1
		if GameState.rng.randi() % 100 < 40:
			if child.traits.size() < 6:
				child.traits.append(trait_id)
				GameState.log_event(Locale.t("ux_tutor_trait") % [child.name, Locale.t(str(row.get("zh_key", _name)))])
		elif tries + 1 >= 3:
			GameState.house_mods[fails_key] = true
		return


static func promote_list(c: CKCharacter) -> Array:
	if c == null:
		return []
	var job: Dictionary = GameState.get_job(c.job_id)
	var to = job.get("promote_to", [])
	if typeof(to) != TYPE_ARRAY:
		to = [to] if str(to) != "" else []
	var out: Array = []
	for jid in to:
		out.append(str(jid))
	return out


static func monthly_shi_xing() -> void:
	for c in GameState.roster():
		if c == null or not c.alive or c.age < 30:
			continue
		if shi_xing_of(c.id) != "":
			continue
		var peak := 0
		for k in CKCharacter.STAT_KEYS:
			peak = maxi(peak, int(c.stats.get(k, 0)))
		var battles := int(c.blood_meta.get("job_battles", 0))
		if peak < 14 and battles < 10:
			continue
		var pool: Array = []
		for sid in SHI_XING.keys():
			pool.append({"id": sid, "w": int(SHI_XING[sid].get("w", 10))})
		var pick := CKLifeMarks._pick_pool(pool, GameState.rng)
		if pick == "":
			continue
		if GameState.rng.randi() % 100 >= 35:
			continue
		var book = GameState.house_mods.get("shi_xing", null)
		if typeof(book) != TYPE_DICTIONARY:
			book = {}
			GameState.house_mods["shi_xing"] = book
		book[c.id] = pick
		var zh := Locale.t(str(SHI_XING[pick].get("key", pick)))
		GameState.log_event(Locale.t("ux_tutor_shi_got") % [c.name, zh])
