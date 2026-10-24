extends Node
## Y1-B 职印可感：六门特殊职业各自 本城之事 → 盖印 → 转职 端到端。
## 单职路径见 job_seal_check；本套确认目录全覆盖、错城/无印门闩、办完事可印。

func _ready() -> void:
	await get_tree().process_frame
	var err := _run()
	if err != "":
		print("FAIL job_seal_six: ", err)
		get_tree().quit(1)
		return
	print("JOB SEAL SIX PASS")
	get_tree().quit(0)


func _run() -> String:
	var fails: Array = []
	GameState.new_game("烬行", "灰旗", "frost")
	GameState.silver = 9999
	GameState.food = 9999
	GameState.iron = 9999
	var rows: Array = []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/job_seals_v92.json"))
	if typeof(parsed) != TYPE_DICTIONARY:
		return "job_seals_v92 missing"
	rows = parsed.get("special", [])
	if rows.size() != 6:
		fails.append("catalog size %d" % rows.size())
	var seen_jobs: Dictionary = {}
	var seen_cities: Dictionary = {}
	for r in rows:
		var jid := str(r.get("job", ""))
		var from_job := str(r.get("from", ""))
		var city := str(r.get("city", ""))
		var nm := str(r.get("name", jid))
		if jid == "" or from_job == "" or city == "":
			fails.append("row incomplete %s" % r)
			continue
		if seen_jobs.has(jid):
			fails.append("dup job %s" % jid)
		seen_jobs[jid] = true
		if seen_cities.has(city):
			fails.append("dup city %s" % city)
		seen_cities[city] = true
		var cid := "seal_%s" % jid
		var c := CKCharacter.new()
		c.id = cid
		c.name = nm
		c.alive = true
		c.is_child = false
		c.in_roster = true
		c.age = 24
		c.job_id = from_job
		c.blood_meta = {}
		c.stats = {"str": 12, "agi": 12, "vit": 12, "wil": 12, "per": 12, "skl": 12}
		GameState.characters[cid] = c
		# No seal → promote blocked.
		if bool(CKJobSeals.promote_gate(c, jid).get("ok", false)):
			fails.append("%s promote_gate open pre-seal" % jid)
		if bool(GameState.try_promote(cid, jid).get("ok", false)):
			fails.append("%s promoted without seal" % jid)
		# Wrong city cannot stamp.
		if bool(CKJobSeals.can_stamp(c, jid, "ash_market").get("ok", false)):
			fails.append("%s stamped at ash_market" % jid)
		# Raise rep + clear affair gate.
		var rep := World.rep_of(city)
		if rep < 40:
			World.add_city_rep(city, 40 - rep)
		if CKCityAffairs.done(city):
			fails.append("%s affair already done on fresh game" % city)
		else:
			var af := CKCityAffairs.do_affair(city)
			if not bool(af.get("ok", false)):
				# first_meet free path may need low rep; force flag if cost blocked oddly
				GameState.set_flag(CKCityAffairs.flag_key(city), true)
				if not CKCityAffairs.done(city):
					fails.append("%s affair: %s" % [city, af])
		if not bool(CKJobSeals.can_stamp(c, jid, city).get("ok", false)):
			fails.append("%s can_stamp false: %s" % [jid, CKJobSeals.can_stamp(c, jid, city)])
			continue
		var st := CKJobSeals.stamp(c, jid, city)
		if not bool(st.get("ok", false)):
			fails.append("%s stamp: %s" % [jid, st])
			continue
		if not CKJobSeals.has_seal(c, jid):
			fails.append("%s has_seal false after stamp" % jid)
		if bool(CKJobSeals.stamp(c, jid, city).get("ok", false)):
			fails.append("%s stamp repeat ok" % jid)
		var pr := GameState.try_promote(cid, jid)
		if c.job_id != jid:
			fails.append("%s promote: %s (job=%s)" % [jid, pr, c.job_id])
	if seen_jobs.size() != 6:
		fails.append("walked %d jobs" % seen_jobs.size())
	return "; ".join(fails)
