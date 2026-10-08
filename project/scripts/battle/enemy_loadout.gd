class_name CKEnemyLoadout
extends RefCounted
## Battle difficulty and the skill lists handed to enemies and jobs.
## Merged ownership moves to the battle stream.

static func get_skill(host, sid: String) -> Dictionary:
	for s in host.data_skills.get("skills", []):
		if s.get("id") == sid:
			return s
	return {"id": sid, "name": sid}

static func skills_for_job(host, job_id: String) -> Array:
	var out: Array = []
	for s in host.data_skills.get("skills", []):
		var jobs: Array = s.get("jobs", [])
		if job_id in jobs:
			out.append(s)
	return out

static func battle_difficulty_from_map(host, map_id: String) -> int:
	## 0=教学 1=前中期 2=中期 3=后期 4=终局/精锐图
	var mid = map_id.to_lower()
	if mid.begins_with("ch0") or mid.find("tutorial") >= 0:
		return 0
	var ch := 0
	# ch12_foo / ch_heir → parse leading digits after ch
	var i = 0
	if mid.begins_with("ch"):
		var num = ""
		for j in range(2, mini(mid.length(), 5)):
			var chs = mid.substr(j, 1)
			if chs.is_valid_int():
				num += chs
			else:
				break
		if num != "":
			ch = int(num)
	if mid.find("heir") >= 0 or mid.find("boss") >= 0 or mid.find("bloodseal") >= 0:
		return maxi(ch / 3, 3)
	if ch <= 0:
		return 1
	if ch <= 2:
		return 1
	if ch <= 4:
		return 2
	if ch <= 6:
		return 3
	return 4

static func enemy_skill_table_for(host, map_id: String) -> Dictionary:
	var root = host.data_enemy_skills.get("maps", host.data_enemy_skills)
	if root.has(map_id):
		return root[map_id]
	# chapter wildcard: ch5_* → try nothing; fall to diff defaults
	return {}

static func _grant_theme_skill(host, c: CKCharacter, elite: bool, template_id: String, granted: Array) -> void:
	if not elite or template_id == "":
		return
	var sid := CKTacticsAI.theme_skill(str(UnitModel.parse_enemy_template(template_id).get("theme", "")))
	if sid != "" and not (sid in granted):
		granted.append(sid)

static func _apply_skill_list(host, c: CKCharacter, sids: Array) -> void:
	for sid in sids:
		var id = str(sid)
		if id == "":
			continue
		var sk = CKEnemyLoadout.get_skill(host, id)
		if sk.is_empty():
			continue
		if id not in c.skills:
			c.skills.append(id)
		if id not in c.unlocked_skills:
			c.unlocked_skills.append(id)

static func _skills_from_table_entry(host, entry) -> Array:
	# by_template 值可以是 Array 或 {skills, elite_skills}
	if typeof(entry) == TYPE_ARRAY:
		return entry
	if typeof(entry) == TYPE_DICTIONARY:
		return entry.get("skills", [])
	return []

static func _elite_from_table_entry(host, entry) -> Array:
	if typeof(entry) == TYPE_DICTIONARY:
		return entry.get("elite_skills", [])
	return []

static func grant_battle_enemy_skills(host, c: CKCharacter, elite: bool = false, difficulty: int = 1, map_id: String = "", template_id: String = "") -> void:
	## 优先 per-map 表 / 全局 _by_template；再回退难度曲线
	CKEnemyLoadout.grant_job_skills(host, c)
	var root = host.data_enemy_skills.get("maps", host.data_enemy_skills)
	var table = CKEnemyLoadout.enemy_skill_table_for(host, map_id) if map_id != "" else {}
	var granted: Array = []
	var used_table := false
	if not table.is_empty():
		used_table = true
		var by_t: Dictionary = table.get("by_template", {})
		if template_id != "" and by_t.has(template_id):
			var entry = by_t[template_id]
			granted.append_array(CKEnemyLoadout._skills_from_table_entry(host, entry))
			if elite:
				granted.append_array(CKEnemyLoadout._elite_from_table_entry(host, entry))
		else:
			granted.append_array(table.get("default", []))
		if elite:
			granted.append_array(table.get("elite", []))
	# 全局模板表补全（地图未写到的模板）
	if template_id != "" and granted.is_empty():
		var glob: Dictionary = root.get("_by_template", {})
		if glob.has(template_id):
			used_table = true
			var gentry = glob[template_id]
			granted.append_array(CKEnemyLoadout._skills_from_table_entry(host, gentry))
			if elite:
				granted.append_array(CKEnemyLoadout._elite_from_table_entry(host, gentry))
		if used_table:
			CKEnemyLoadout._grant_theme_skill(host, c, elite, template_id, granted)
			CKEnemyLoadout._apply_skill_list(host, c, granted)
			return
	# 回退：_defaults by diff
	var defaults = root.get("_defaults", {})
	var key = "diff_%d" % clampi(difficulty, 0, 4)
	var dtab: Dictionary = defaults.get(key, {})
	if not dtab.is_empty():
		var granted2: Array = []
		granted2.append_array(dtab.get("default", []))
		if elite:
			granted2.append_array(dtab.get("elite", []))
		CKEnemyLoadout._grant_theme_skill(host, c, elite, template_id, granted2)
		CKEnemyLoadout._apply_skill_list(host, c, granted2)
		return
	# 最终回退：旧曲线（稳定选取）
	if difficulty <= 0 and not elite:
		return
	var t2: Array = []
	var t3: Array = []
	for s in CKEnemyLoadout.skills_for_job(host, c.job_id):
		var tier = int(s.get("tier", 1))
		var sid = str(s.get("id"))
		if tier == 2:
			t2.append(sid)
		elif tier >= 3:
			t3.append(sid)
	for sid in ["lock_breaker", "terrain_ward", "anchor_guard", "disengage_step"]:
		var sk = CKEnemyLoadout.get_skill(host, sid)
		if sk.is_empty():
			continue
		var jobs = sk.get("jobs", [])
		if (jobs.is_empty() or c.job_id in jobs) and sid not in t2 and int(sk.get("tier", 1)) == 2:
			t2.append(sid)
	var need_t2 := 0
	var need_t3 := 0
	match difficulty:
		0:
			need_t2 = 1 if elite else 0
		1:
			need_t2 = 1 if elite else 0
		2:
			need_t2 = 1
			need_t3 = 1 if elite else 0
		3:
			need_t2 = 2
			need_t3 = 1 if elite else 0
		_:
			need_t2 = 2
			need_t3 = 2 if elite else 1
	t2.sort()
	t3.sort()
	var salt = abs(hash(c.id)) % 7
	if t2.size() > 0:
		var start = salt % t2.size()
		for k in need_t2:
			var sid2 = str(t2[(start + k) % t2.size()])
			CKEnemyLoadout._apply_skill_list(host, c, [sid2])
	if t3.size() > 0 and need_t3 > 0:
		var start3 = salt % t3.size()
		for k in need_t3:
			var sid3 = str(t3[(start3 + k) % t3.size()])
			CKEnemyLoadout._apply_skill_list(host, c, [sid3])
	var themed: Array = []
	CKEnemyLoadout._grant_theme_skill(host, c, elite, template_id, themed)
	if not themed.is_empty():
		CKEnemyLoadout._apply_skill_list(host, c, themed)

static func grant_job_skills(host, c: CKCharacter) -> void:
	if c == null:
		return
	for s in CKEnemyLoadout.skills_for_job(host, c.job_id):
		var sid = str(s.get("id"))
		if int(s.get("tier", 1)) > 1:
			continue  # 二阶需战技树解锁
		if sid not in c.skills:
			c.skills.append(sid)
	for sid in c.unlocked_skills:
		if sid not in c.skills:
			c.skills.append(sid)
	CKBloodline.sync_signature_skills(c)


static var _difficulty: Dictionary = {}


static func profiles() -> Dictionary:
	if not _difficulty.is_empty():
		return _difficulty
	var f := FileAccess.open("res://data/difficulty.json", FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		_difficulty = parsed
	return _difficulty


static func mode_of(host) -> String:
	var fallback := str(profiles().get("default", "standard"))
	var picked := str(host.settings.get("battle_mode", fallback))
	if not profiles().get("modes", {}).has(picked):
		return fallback
	return picked


static func profile(mode: String) -> Dictionary:
	var row = profiles().get("modes", {}).get(mode, {})
	return row if typeof(row) == TYPE_DICTIONARY else {}


static func rank_of(mode: String) -> int:
	return int(profile(mode).get("rank", 1))


## First pick may be any tier. After that the campaign can only step down.
static func choose(host, mode: String) -> bool:
	if profile(mode).is_empty():
		return false
	if host.settings.has("battle_mode") and rank_of(mode) > rank_of(mode_of(host)):
		return false
	host.settings["battle_mode"] = mode
	if host.has_method("mark_dirty"):
		host.mark_dirty()
	return true


static func unlock_for_new_game(host) -> void:
	host.settings.erase("battle_mode")


static func lamp_rule(map_diff: int, mode: String) -> Dictionary:
	# Same base table as the lamp rewind card. Kept local so this branch
	# compiles before that card is on main.
	var table := {0: 3, 1: 2, 2: 1, 3: 0, 4: 0}
	var base := {
		"charges": int(table.get(clampi(map_diff, 0, 4), 1)),
		"refill": false,
	}
	var prof := profile(mode)
	var charges := maxi(0, int(base.get("charges", 0)) + int(prof.get("lamp_bonus", 0)))
	var refill := bool(base.get("refill", false)) or bool(prof.get("lamp_refill", false))
	return {
		"charges": charges,
		"refill": refill,
		"ai_tier": int(prof.get("ai_tier", 1)),
		"defeat": str(prof.get("defeat", "injury")),
	}


static func stamp_enemy(c: CKCharacter, mode: String) -> void:
	if c == null or c.has_meta("btl_mode_stamped"):
		return
	var flat := int(profile(mode).get("stat_flat", 0))
	c.set_meta("btl_mode_stamped", true)
	c.set_meta("btl_str0", int(c.stats.get("str", 8)))
	c.set_meta("btl_vit0", int(c.stats.get("vit", 8)))
	if flat == 0:
		return
	c.stats["str"] = maxi(1, int(c.stats.get("str", 8)) + flat)
	c.stats["vit"] = maxi(1, int(c.stats.get("vit", 8)) + flat)


static func unstamp(c: CKCharacter) -> void:
	if c == null or not c.has_meta("btl_mode_stamped"):
		return
	c.stats["str"] = int(c.get_meta("btl_str0"))
	c.stats["vit"] = int(c.get_meta("btl_vit0"))
	c.remove_meta("btl_mode_stamped")
	c.remove_meta("btl_str0")
	c.remove_meta("btl_vit0")


static func apply_defeat(units: Array, mode: String) -> void:
	var kind := str(profile(mode).get("defeat", "injury"))
	for u in units:
		if str(u.get("team", "")) != "player":
			continue
		var c: CKCharacter = u.char
		if kind == "retreat":
			c.hp = c.max_hp
		elif kind == "permadeath":
			c.hp = 0
			c.injured = true
			c.set_meta("classic_down", true)
		else:
			c.injured = true
			c.hp = maxi(1, int(c.max_hp * 0.3))

