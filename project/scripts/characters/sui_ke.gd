class_name CKSuiKe
extends RefCounted
## v9.2 yearly lesson. Rival seats include grandparents. Board #6: no death immunity.

const DATA_PATH := "res://data/sui_ke.json"
const BANDS := ["daily", "ill", "mishap", "rival", "seen", "shame", "near", "yao"]
const BAND_W_BASE := {
	"daily": 640, "ill": 62, "mishap": 52, "rival": 54,
	"seen": 48, "shame": 40, "near": 86, "yao": 18,
}
const DAILY_W_BY_AGE := {
	"1-3": {"daily": 630, "yao": 28},
	"4-7": {"daily": 640, "yao": 18},
	"8-12": {"daily": 648, "yao": 10},
	"13-15": {"daily": 652, "yao": 6},
}
const SEAT_W := {"sibling": 50, "cousin": 18, "sibling_adult": 16, "uncle": 16, "grand": 16}

static var _doc: Dictionary = {}


static func _load() -> void:
	if not _doc.is_empty():
		return
	if not FileAccess.file_exists(DATA_PATH):
		_doc = {"copy": {}, "grand_cards": [], "daily_pairs": []}
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	_doc = parsed if typeof(parsed) == TYPE_DICTIONARY else {"copy": {}, "grand_cards": [], "daily_pairs": []}


static func _c(key: String) -> String:
	_load()
	var copy = _doc.get("copy", {})
	if typeof(copy) != TYPE_DICTIONARY:
		return key
	return str(copy.get(key, key))


static func ensure() -> void:
	if bool(GameState.get_meta("sui_ke_hooked", false)):
		return
	GameState.set_meta("sui_ke_hooked", true)
	Calendar.register("family", Callable(CKSuiKe, "on_month"), 45)


static func on_month(_ctx: Dictionary) -> void:
	if _ch0_open():
		return
	var people: Array = GameState.characters.values()
	people.sort_custom(func(a, b): return str(a.id) < str(b.id))
	for c in people:
		if not _eligible(c):
			continue
		if int(c.birthday_month) != int(Calendar.month):
			continue
		if int(c.age) < 1:
			continue
		if int(c.age) == 1 and _born_this_month(c):
			continue
		if _has_pending(c.id):
			continue
		var card := draw_card(c)
		if card.is_empty():
			continue
		_pending().append(card)


static func _ch0_open() -> bool:
	if bool(GameState.chapter0_flags.get("chapter0_done", false)):
		return false
	return bool(GameState.chapter0_flags.get("ch0_playing", false))


static func _born_this_month(c: CKCharacter) -> bool:
	return str(c.blood_meta.get("birth_ym", "")) == "%d-%d" % [Calendar.year, Calendar.month]


static func _eligible(c: CKCharacter) -> bool:
	if c == null or not c.alive:
		return false
	if c.age < 1 or c.age > 15:
		return false
	if c.in_roster:
		return false
	if c.is_child:
		return true
	return _is_house_kin(c)


static func _is_house_kin(c: CKCharacter) -> bool:
	var leader := GameState.get_leader()
	if leader == null:
		return false
	if leader.id in c.parent_ids:
		return true
	for pid in c.parent_ids:
		var p: CKCharacter = GameState.characters.get(str(pid))
		if p != null and (leader.id in p.parent_ids or p.id == leader.id or leader.id in p.children_ids):
			return true
	return false


static func is_house_child_for_life_queue(c: CKCharacter) -> bool:
	return _eligible(c)


static func draw_card(c: CKCharacter) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d|sui" % [c.id, c.age])
	var band := _pick_band(c, rng)
	if band == "rival":
		var seats := open_seats(c)
		if seats.is_empty():
			band = "daily"
		else:
			return _draw_rival(c, seats, rng)
	if band == "yao":
		return _draw_yao(c, rng)
	if band == "daily":
		return _draw_daily(c, rng)
	var daily := _draw_daily(c, rng)
	daily["band"] = band
	daily["id"] = "%s_fallback_%d" % [band, c.age]
	return daily


static func _pick_band(c: CKCharacter, rng: RandomNumberGenerator) -> String:
	var ages := _age_key(c.age)
	var w := BAND_W_BASE.duplicate()
	var adj: Dictionary = DAILY_W_BY_AGE.get(ages, {})
	if not adj.is_empty():
		w["daily"] = int(adj.get("daily", w["daily"]))
		w["yao"] = int(adj.get("yao", w["yao"]))
	var keys: Array = []
	var weights: Array = []
	for b in BANDS:
		keys.append(b)
		weights.append(int(w.get(b, 0)))
	var idx := CKLifeMarks._pick_weighted(weights, rng)
	return str(keys[idx])


static func _age_key(age: int) -> String:
	if age <= 3:
		return "1-3"
	if age <= 7:
		return "4-7"
	if age <= 12:
		return "8-12"
	return "13-15"


static func _draw_daily(c: CKCharacter, rng: RandomNumberGenerator) -> Dictionary:
	_load()
	var fired: Array = _fired_ids(c.id)
	var pairs: Array = _doc.get("daily_pairs", [])
	var pool: Array = []
	for i in range(pairs.size()):
		var pid := "daily_%d" % i
		if pid in fired:
			continue
		pool.append(i)
	if pool.is_empty():
		return {
			"cid": c.id, "band": "daily", "id": "daily_empty",
			"title": _c("daily_title"), "speaker": _c("daily_speaker"),
			"body": _c("daily_empty_body"),
			"options": [{"id": "ok", "label": _c("daily_empty_label"), "stat": _path_stat(c), "mark": "", "gain": 1}],
		}
	var idx: int = pool[rng.randi() % pool.size()]
	var pair: Dictionary = pairs[idx]
	return {
		"cid": c.id, "band": "daily", "id": "daily_%d" % idx,
		"title": _c("daily_title"), "speaker": _c("daily_speaker"),
		"body": _c("daily_body"),
		"options": [
			{"id": "follow", "label": _c("follow") % CKLifeMarks.zh(str(pair.lesson)), "stat": _path_stat(c, str(pair.stat_l)), "mark": str(pair.lesson), "gain": 1},
			{"id": "let", "label": _c("let") % CKLifeMarks.zh(str(pair.play)), "stat": str(pair.stat_p), "mark": str(pair.play), "gain": 1, "strict_morale": true},
		],
	}


static func _path_stat(c: CKCharacter, fallback: String = "wil") -> String:
	var path := str(GameState.lineage_path.get(c.id, ""))
	match path:
		"martial":
			return "str" if fallback in ["str", "vit"] else fallback
		"scholar":
			return "wil" if fallback in ["wil", "per"] else fallback
		"merchant":
			return "agi" if fallback in ["agi", "skl"] else fallback
		_:
			return fallback


static func _draw_yao(c: CKCharacter, rng: RandomNumberGenerator) -> Dictionary:
	var age := int(c.age)
	var pool: Array = []
	if age >= 1 and age <= 4:
		pool.append({"id": "yao_dawn", "kind": "end", "w": 18, "title": _c("yao_dawn_title"), "body": _c("yao_dawn_body"),
			"options": [
				{"id": "epitaph_a", "label": _c("epitaph_dawn_a"), "kill": true, "morale": -3, "epitaph": _c("epitaph_dawn_a_word")},
				{"id": "epitaph_b", "label": _c("epitaph_dawn_b"), "kill": true, "morale": -3, "epitaph": _c("epitaph_dawn_b_word")},
			]})
	if age >= 1 and age <= 8:
		pool.append({"id": "yao_fever", "kind": "contest", "w": 15, "title": _c("yao_fever_title"), "body": _c("yao_fever_body"),
			"options": [
				{"id": "pay", "label": _c("pay12"), "pay": 12, "mark": "", "trait": "malnourished", "survive": true},
				{"id": "leave", "label": _c("leave_fever"), "kill": true, "morale": -3, "epitaph": _c("epitaph_fever")},
			]})
	if age >= 8 and age <= 15:
		pool.append({"id": "yao_beam", "kind": "end", "w": 8, "title": _c("yao_beam_title"), "body": _c("yao_beam_body"),
			"options": [
				{"id": "epitaph_a", "label": _c("epitaph_beam_a"), "kill": true, "morale": -3, "epitaph": _c("epitaph_beam_a_word")},
				{"id": "epitaph_b", "label": _c("epitaph_beam_b"), "kill": true, "morale": -3, "epitaph": _c("epitaph_beam_b_word")},
			]})
	if pool.is_empty():
		return _draw_daily(c, rng)
	var total := 0
	for row in pool:
		total += int(row.get("w", 1))
	var roll := rng.randi() % total
	var acc := 0
	var chosen: Dictionary = pool[0]
	for row in pool:
		acc += int(row.get("w", 1))
		if roll < acc:
			chosen = row
			break
	return {
		"cid": c.id, "band": "yao", "id": str(chosen.get("id", "")),
		"kind": str(chosen.get("kind", "end")),
		"title": str(chosen.get("title", "")), "speaker": _c("daily_speaker"),
		"body": str(chosen.get("body", "")),
		"options": chosen.get("options", []),
		"death_immune": false,
	}


static func open_seats(c: CKCharacter) -> Dictionary:
	var out := {"sibling": [], "cousin": [], "sibling_adult": [], "uncle": [], "grand": []}
	var chars: Dictionary = GameState.characters
	for other in chars.values():
		if other == null or other.id == c.id or not other.alive:
			continue
		if not _same_node(c, other):
			continue
		if not _is_house_person(other):
			continue
		var seat := _seat_of(c, other, chars)
		if seat != "" and out.has(seat):
			out[seat].append(other.id)
	var cleaned := {}
	for k in out.keys():
		if not out[k].is_empty():
			cleaned[k] = out[k]
	return cleaned


static func _is_house_person(c: CKCharacter) -> bool:
	if c.is_child or c.in_roster:
		return true
	var leader := GameState.get_leader()
	if leader == null:
		return false
	if c.id == leader.id or c.id == leader.spouse_id:
		return true
	return _is_house_kin(c)


static func _same_node(a: CKCharacter, b: CKCharacter) -> bool:
	return _node_of(a) == _node_of(b)


static func _node_of(c: CKCharacter) -> String:
	if c.in_roster and c.id in GameState.deploy_ids:
		return "field"
	var job := str(c.blood_meta.get("estate_job", ""))
	if job != "":
		return "estate:%s" % job
	return "home"


static func _seat_of(child: CKCharacter, other: CKCharacter, chars: Dictionary) -> String:
	var g := grandparent_role(child, other, chars)
	if g != "":
		return "grand"
	var deg := CKBloodline.kinship_degree(child, other, chars)
	if deg == 3 and _is_uncle_aunt(child, other, chars):
		return "uncle"
	if deg == 2:
		if other.age <= 15 and not other.in_roster:
			return "sibling"
		return "sibling_adult"
	if deg == 4 and other.age <= 15 and not other.in_roster:
		return "cousin"
	return ""


static func grandparent_role(child: CKCharacter, other: CKCharacter, chars: Dictionary) -> String:
	if other == null or not other.alive:
		return ""
	_load()
	var roles: Dictionary = _doc.get("grand_roles", {})
	var pids: Array = child.parent_ids
	if pids.is_empty():
		return ""
	var father: CKCharacter = chars.get(str(pids[0])) if str(pids[0]) != "" else null
	var mother: CKCharacter = chars.get(str(pids[1])) if pids.size() > 1 and str(pids[1]) != "" else null
	if father != null:
		var fp: Array = father.parent_ids
		if fp.size() > 0 and str(fp[0]) == other.id:
			return str(roles.get("gf0", "gf0"))
		if fp.size() > 1 and str(fp[1]) == other.id:
			return str(roles.get("gf1", "gf1"))
	if mother != null:
		var mp: Array = mother.parent_ids
		if mp.size() > 0 and str(mp[0]) == other.id:
			return str(roles.get("gm0", "gm0"))
		if mp.size() > 1 and str(mp[1]) == other.id:
			return str(roles.get("gm1", "gm1"))
	return ""


static func _is_uncle_aunt(child: CKCharacter, other: CKCharacter, chars: Dictionary) -> bool:
	for pid in child.parent_ids:
		var p: CKCharacter = chars.get(str(pid))
		if p == null:
			continue
		if CKBloodline.kinship_degree(p, other, chars) == 2:
			return true
	return false


static func _draw_rival(c: CKCharacter, seats: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var seat_keys: Array = []
	var ws: Array = []
	for k in seats.keys():
		seat_keys.append(k)
		ws.append(int(SEAT_W.get(k, 1)))
	var si := CKLifeMarks._pick_weighted(ws, rng)
	var seat := str(seat_keys[si])
	var ids: Array = seats[seat]
	ids.sort()
	var oid: String = ids[rng.randi() % ids.size()]
	var other: CKCharacter = GameState.characters.get(oid)
	if seat == "grand":
		return _draw_grand(c, other, rng)
	var role := other.name if other else seat
	return {
		"cid": c.id, "band": "rival", "id": "rival_%s_bowl" % seat, "seat": seat, "other_id": oid,
		"title": _c("rival_title"), "speaker": role,
		"body": _c("rival_body") % role,
		"options": [
			{"id": "take", "label": _c("rival_take"), "stat": "skl", "mark": "ledger", "gain": 1},
			{"id": "leave", "label": _c("rival_leave"), "stat": "", "mark": "", "gain": 0},
		],
		"death_immune": false,
	}


static func _draw_grand(c: CKCharacter, other: CKCharacter, rng: RandomNumberGenerator) -> Dictionary:
	_load()
	var role := grandparent_role(c, other, GameState.characters)
	if role == "":
		role = other.name
	var pool: Array = []
	for card in _doc.get("grand_cards", []):
		if c.age < int(card.get("age_min", 1)) or c.age > int(card.get("age_max", 15)):
			continue
		if not _grand_need_ok(c, other, str(card.get("need", ""))):
			continue
		var cid := "grand_%s" % str(card.get("id", ""))
		if cid in _fired_ids(c.id):
			continue
		pool.append(card)
	if pool.is_empty():
		return _draw_daily(c, rng)
	var card2: Dictionary = pool[rng.randi() % pool.size()]
	var left: Dictionary = card2.get("left", {})
	var right: Dictionary = card2.get("right", {})
	return {
		"cid": c.id, "band": "rival", "id": "grand_%s" % str(card2.get("id", "")),
		"seat": "grand", "other_id": other.id, "role": role,
		"title": _c("grand_title") % role, "speaker": other.name,
		"body": _c("grand_body") % role,
		"options": [
			_side_option("left", left),
			_side_option("right", right),
		],
		"death_immune": false,
	}



static func _side_option(oid: String, side: Dictionary) -> Dictionary:
	var stat := str(side.get("stat", ""))
	var mark := str(side.get("mark", ""))
	var gain := 1 if stat != "" or (oid == "left" and mark != "") else 0
	if oid == "right":
		gain = 1 if stat != "" else 0
	return {
		"id": oid,
		"label": _c(str(side.get("act_key", ""))),
		"stat": stat,
		"mark": mark,
		"gain": gain,
		"care": bool(side.get("care", false)),
		"morale": int(side.get("morale", 0)),
	}


static func _grand_need_ok(child: CKCharacter, grand: CKCharacter, need: String) -> bool:
	match need:
		"home":
			return _node_of(child) == "home" and _node_of(grand) == "home"
		"same":
			return _same_node(child, grand)
		"home_or_reed":
			var n := _node_of(child)
			return n == "home" or n.begins_with("estate:")
		"roster_weapon":
			return grand.in_roster and str(grand.weapon_id) != ""
		"field":
			return str(grand.blood_meta.get("estate_job", "")) != "" and _same_node(child, grand)
		"parent_present":
			for pid in child.parent_ids:
				var p: CKCharacter = GameState.characters.get(str(pid))
				if p != null and p.alive and _same_node(child, p):
					return true
			return false
		_:
			return true


static func resolve(cid: String, card_id: String, option_id: String) -> Dictionary:
	var card := _find_pending(cid, card_id)
	if card.is_empty():
		return {"ok": false, "msg": _c("no_card")}
	var c: CKCharacter = GameState.characters.get(cid)
	if c == null:
		return {"ok": false, "msg": _c("no_person")}
	var opt := {}
	for o in card.get("options", []):
		if str(o.get("id", "")) == option_id:
			opt = o
			break
	if opt.is_empty():
		return {"ok": false, "msg": _c("no_opt")}
	if bool(opt.get("kill", false)):
		c.alive = false
		c.in_roster = false
		CKTutor.clear_pupil(c.id)
		var epitaph := str(opt.get("epitaph", ""))
		c.blood_meta["stele_cause"] = "yao"
		c.blood_meta["stele_epitaph"] = epitaph
		GameState.morale = maxi(0, int(GameState.morale) + int(opt.get("morale", -3)))
		GameState.log_event(_c("yao_log") % [c.name, epitaph])
		_drop_pending(cid, card_id)
		_mark_fired(cid, card_id)
		GameState.mark_dirty()
		return {"ok": true, "msg": _c("yao_dead_msg"), "dead": true}
	if bool(opt.get("survive", false)) and int(opt.get("pay", 0)) > 0:
		var pay := int(opt.get("pay", 0))
		var purse := int(c.blood_meta.get("purse", 0))
		var payer := c
		if purse < pay:
			for pid in c.parent_ids:
				var p: CKCharacter = GameState.characters.get(str(pid))
				if p != null and p.alive and _same_node(c, p) and int(p.blood_meta.get("purse", 0)) >= pay:
					payer = p
					purse = int(p.blood_meta.get("purse", 0))
					break
		if purse < pay:
			return {"ok": false, "msg": _c("purse_short") % [purse, pay]}
		payer.blood_meta["purse"] = purse - pay
	if str(opt.get("trait", "")) != "" and str(opt.get("trait", "")) not in c.traits and c.traits.size() < 6:
		c.traits.append(str(opt.get("trait", "")))
	var stat := str(opt.get("stat", ""))
	var gain := int(opt.get("gain", 0))
	if stat != "" and gain > 0:
		c.stats[stat] = mini(int(c.apt_max.get(stat, 20)), int(c.stats.get(stat, 8)) + gain)
	var mark := str(opt.get("mark", ""))
	var mark_msg := ""
	if mark != "":
		var mr := CKLifeMarks.add(c, mark, "sui")
		if bool(mr.get("ok", false)):
			mark_msg = str(mr.get("msg", ""))
			if str(mr.get("evicted", "")) != "":
				mark_msg += Locale.t("ux_tutor_evict") % CKLifeMarks.zh(str(mr.get("evicted", "")))
	if int(opt.get("morale", 0)) != 0:
		GameState.morale = clampi(int(GameState.morale) + int(opt.get("morale", 0)), 0, 100)
	if bool(opt.get("strict_morale", false)) and str(GameState.house_mods.get("doctrine", "")) == "strict":
		GameState.morale = maxi(0, int(GameState.morale) - 1)
	if bool(opt.get("care", false)):
		var oid := str(card.get("other_id", ""))
		if oid != "":
			GameState.house_mods["care_lock_%s" % oid] = "%d-%d" % [Calendar.year, Calendar.month]
	_drop_pending(cid, card_id)
	_mark_fired(cid, card_id)
	c.recalc_hp()
	GameState.mark_dirty()
	var msg := _c("resolve_ok")
	if mark_msg != "":
		msg += mark_msg
	return {"ok": true, "msg": msg, "dead": false}


static func pending_for(cid: String) -> Dictionary:
	for item in _pending():
		if str(item.get("cid", "")) == cid:
			return item
	return {}


static func _find_pending(cid: String, card_id: String) -> Dictionary:
	for item in _pending():
		if str(item.get("cid", "")) == cid and str(item.get("id", "")) == card_id:
			return item
	return {}


static func _pending() -> Array:
	var raw = GameState.house_mods.get("sui_pending", null)
	if typeof(raw) != TYPE_ARRAY:
		raw = []
		GameState.house_mods["sui_pending"] = raw
	return raw


static func _has_pending(cid: String) -> bool:
	for item in _pending():
		if str(item.get("cid", "")) == cid:
			return true
	return false


static func _drop_pending(cid: String, card_id: String) -> void:
	var kept: Array = []
	for item in _pending():
		if str(item.get("cid", "")) == cid and str(item.get("id", "")) == card_id:
			continue
		kept.append(item)
	GameState.house_mods["sui_pending"] = kept


static func _fired_ids(cid: String) -> Array:
	var book = GameState.house_mods.get("sui_fired", null)
	if typeof(book) != TYPE_DICTIONARY:
		book = {}
		GameState.house_mods["sui_fired"] = book
	if typeof(book.get(cid, null)) != TYPE_ARRAY:
		book[cid] = []
	return book[cid]


static func _mark_fired(cid: String, card_id: String) -> void:
	var row := _fired_ids(cid)
	if not row.has(card_id):
		row.append(card_id)
