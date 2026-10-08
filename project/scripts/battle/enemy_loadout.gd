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

