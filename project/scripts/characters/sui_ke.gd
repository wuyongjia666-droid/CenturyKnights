class_name CKSuiKe
extends RefCounted
## v9.2 yearly lesson — full catalogues for ill/mishap/seen/shame/near/yao and five rival seats.
##
## Personality auto-pick (no player left/right):
##   Left / follow ≈ 稳妥照料（care、pay、wil/per、watch/copy/ledger）
##   Right / let   ≈ 大胆冒险（scarred/malnourished、str/agi、seize/slip、survivor）
##   Child boldness from traits/marks/stats/bloodline/path; carefulness likewise.
##   Prefer the option whose risk score matches the child; near-ties use seeded RNG
##   (child id + year + card id) so reloads stay stable.
##   Birthday fire auto-resolves into sui_inbox (read-only result card).

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
const SEAT_DOC := {
	"sibling": "rival_sibling",
	"cousin": "rival_cousin",
	"sibling_adult": "rival_sibling_adult",
	"uncle": "rival_uncle",
}
const CATALOG_BANDS := ["ill", "mishap", "seen", "shame", "near"]

static var _doc: Dictionary = {}


static func _load() -> void:
	if not _doc.is_empty():
		return
	if not FileAccess.file_exists(DATA_PATH):
		_doc = {"copy": {}, "grand_cards": [], "daily_pairs": []}
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	_doc = parsed if typeof(parsed) == TYPE_DICTIONARY else {"copy": {}, "grand_cards": [], "daily_pairs": []}


static func reload_for_tests() -> void:
	_doc = {}
	_load()


static func _c(key: String) -> String:
	_load()
	var copy = _doc.get("copy", {})
	if typeof(copy) != TYPE_DICTIONARY:
		return key
	return str(copy.get(key, key))


static func ensure() -> void:
	if bool(GameState.get_meta("sui_ke_hooked", false)):
		_drain_legacy_pending()
		return
	GameState.set_meta("sui_ke_hooked", true)
	Calendar.register("family", Callable(CKSuiKe, "on_month"), 45)
	_drain_legacy_pending()


static func on_month(_ctx: Dictionary) -> void:
	_drain_legacy_pending()
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
		fire_and_resolve_card(card)


static func _ch0_open() -> bool:
	if bool(GameState.chapter0_flags.get("chapter0_done", false)):
		return false
	return bool(GameState.chapter0_flags.get("ch0_playing", false))


static func _born_this_month(c: CKCharacter) -> bool:
	return str(c.blood_meta.get("birth_ym", "")) == "%d-%d" % [Calendar.year, Calendar.month]


static func _eligible(c: CKCharacter) -> bool:
	if c == null or not c.alive:
		return false
	if c.in_roster:
		return false
	if int(c.age) < 1 or int(c.age) > 15:
		return false
	if c.is_child:
		return true
	return _is_house_kin(c)


static func _is_house_kin(c: CKCharacter) -> bool:
	var leader := GameState.get_leader()
	if leader == null:
		return false
	if c.id == leader.id or c.id == leader.spouse_id:
		return false
	for pid in c.parent_ids:
		if str(pid) == leader.id or str(pid) == leader.spouse_id:
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
	if band in CATALOG_BANDS:
		var got := _draw_catalog(c, band, rng)
		if not got.is_empty():
			return got
	return _draw_daily(c, rng)


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


static func _speaker(band: String) -> String:
	_load()
	var sp = _doc.get("speakers", {})
	if typeof(sp) == TYPE_DICTIONARY and sp.has(band):
		return str(sp[band])
	return _c("daily_speaker")


static func _draw_catalog(c: CKCharacter, band: String, rng: RandomNumberGenerator) -> Dictionary:
	_load()
	var rows: Array = _doc.get(band, [])
	var pool: Array = []
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var cid := "%s_%s" % [band, str(row.get("id", ""))]
		if cid in _fired_ids(c.id):
			continue
		if int(c.age) < int(row.get("age_min", 1)) or int(c.age) > int(row.get("age_max", 15)):
			continue
		if not _need_ok(c, null, str(row.get("need", "")), {}):
			continue
		pool.append(row)
	if pool.is_empty():
		return {}
	var chosen: Dictionary = pool[rng.randi() % pool.size()]
	var oid := str(chosen.get("id", ""))
	return {
		"cid": c.id, "band": band, "id": "%s_%s" % [band, oid],
		"title": str(chosen.get("title", oid)), "speaker": _speaker(band),
		"body": str(chosen.get("body", "")),
		"survivor": str(chosen.get("survivor", "")),
		"options": [
			_opt_from_side("left", chosen.get("left", {})),
			_opt_from_side("right", chosen.get("right", {})),
		],
		"death_immune": false,
	}


static func _opt_from_side(oid: String, side: Dictionary) -> Dictionary:
	var out := {
		"id": oid,
		"label": str(side.get("act", oid)),
		"stat": str(side.get("stat", "")),
		"mark": str(side.get("mark", "")),
		"gain": int(side.get("gain", 0)),
		"care": bool(side.get("care", false)),
		"morale": int(side.get("morale", 0)),
		"pay": int(side.get("pay", 0)),
		"trait": str(side.get("trait", "")),
		"food": int(side.get("food", 0)),
		"herb": int(side.get("herb", 0)),
		"rep": int(side.get("rep", 0)),
		"mother_rep": int(side.get("mother_rep", 0)),
		"rep_or_morale": int(side.get("rep_or_morale", 0)),
		"other_mark": str(side.get("other_mark", "")),
		"other_leave_work": bool(side.get("other_leave_work", false)),
		"mark_soft": bool(side.get("mark_soft", false)),
		"survivor": str(side.get("survivor", "")),
		"halt_march": bool(side.get("halt_march", false)),
		"survive": bool(side.get("survive", false)),
		"kill": bool(side.get("kill", false)),
		"epitaph": str(side.get("epitaph", "")),
	}
	if out["gain"] == 0 and (out["stat"] != "" or (oid == "left" and out["mark"] != "")):
		if out["stat"] != "" and int(side.get("gain", 0)) == 0 and not side.has("gain"):
			out["gain"] = 1
	return out


static func _draw_yao(c: CKCharacter, rng: RandomNumberGenerator) -> Dictionary:
	_load()
	var age := int(c.age)
	var rows: Array = _doc.get("yao", [])
	var pool: Array = []
	var water_open := false
	var furnace_open := false
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		if age < int(row.get("age_min", 1)) or age > int(row.get("age_max", 15)):
			continue
		var need := str(row.get("need", ""))
		var ok := _need_ok(c, null, need, {})
		var id := str(row.get("id", ""))
		if id == "yao_water":
			water_open = ok
		if id == "yao_furnace":
			furnace_open = ok
		if not ok and need != "":
			continue
		pool.append(row)
	# Weight merge when gates closed (design §夭)
	var merged: Array = []
	for row in pool:
		var id := str(row.get("id", ""))
		var w := int(row.get("w", 1))
		if id == "yao_dawn" and not water_open:
			# water weight 14 folds into night-death style; dawn already absorbs via separate card
			pass
		merged.append({"row": row, "w": w})
	# Fold closed water into a synthetic "夜里没了" by boosting dawn if present, else fever
	if not water_open:
		for i in range(merged.size()):
			var id2 := str(merged[i]["row"].get("id", ""))
			if id2 == "yao_dawn":
				merged[i]["w"] = int(merged[i]["w"]) + 14
				break
	if not furnace_open:
		for i in range(merged.size()):
			var id3 := str(merged[i]["row"].get("id", ""))
			if age >= 8 and id3 == "yao_wall":
				merged[i]["w"] = int(merged[i]["w"]) + 15
				break
			elif id3 == "yao_fever":
				merged[i]["w"] = int(merged[i]["w"]) + 15
				break
	if merged.is_empty():
		return _draw_daily(c, rng)
	var total := 0
	for m in merged:
		total += int(m["w"])
	var roll := rng.randi() % maxi(1, total)
	var acc := 0
	var chosen: Dictionary = merged[0]["row"]
	for m in merged:
		acc += int(m["w"])
		if roll < acc:
			chosen = m["row"]
			break
	var opts: Array = []
	for o in chosen.get("options", []):
		if typeof(o) != TYPE_DICTIONARY:
			continue
		var opt: Dictionary = (o as Dictionary).duplicate(true)
		# Infirmary discount on fever pay
		if int(opt.get("pay", 0)) == 12 and CKEconomyState.building_level(GameState, "infirmary") >= 1 and int(GameState.herb) >= 1:
			opt["pay"] = 6
			opt["herb_cost"] = 1
			opt["label"] = Locale.t("sui_infirmary_pay")
		opts.append(opt)
	return {
		"cid": c.id, "band": "yao", "id": str(chosen.get("id", "")),
		"kind": str(chosen.get("kind", "end")),
		"title": str(chosen.get("title", "")), "speaker": _speaker("yao"),
		"body": str(chosen.get("body", "")),
		"options": opts,
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
	# Seat only counts open if at least one card gate opens for someone in it
	var cleaned := {}
	for k in out.keys():
		if out[k].is_empty():
			continue
		if k == "grand":
			cleaned[k] = out[k]
			continue
		var any_card := false
		for oid in out[k]:
			var other2: CKCharacter = chars.get(oid)
			if other2 == null:
				continue
			if not _seat_cards_open(c, other2, k).is_empty():
				any_card = true
				break
		if any_card:
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
	var follow = GameState.house_mods.get("follow_banner", [])
	if typeof(follow) == TYPE_ARRAY and c.id in follow:
		return "field"
	if bool(c.blood_meta.get("follow_banner", false)) or (c.in_roster and c.id in GameState.deploy_ids):
		return "field"
	var job := str(c.blood_meta.get("estate_job", ""))
	if job != "":
		return "estate:%s" % job
	if bool(c.blood_meta.get("retinue", false)):
		return "field"
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
	return _draw_seat_card(c, other, seat, rng)


static func _seat_cards_open(c: CKCharacter, other: CKCharacter, seat: String) -> Array:
	_load()
	var key := str(SEAT_DOC.get(seat, ""))
	if key == "":
		return []
	var rows: Array = _doc.get(key, [])
	var pool: Array = []
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var cid := "rival_%s_%s" % [seat, str(row.get("id", ""))]
		if cid in _fired_ids(c.id):
			continue
		if int(c.age) < int(row.get("age_min", 1)) or int(c.age) > int(row.get("age_max", 15)):
			continue
		if not _need_ok(c, other, str(row.get("need", "")), {"seat": seat}):
			continue
		pool.append(row)
	return pool


static func _draw_seat_card(c: CKCharacter, other: CKCharacter, seat: String, rng: RandomNumberGenerator) -> Dictionary:
	var pool := _seat_cards_open(c, other, seat)
	if pool.is_empty():
		return _draw_daily(c, rng)
	var chosen: Dictionary = pool[rng.randi() % pool.size()]
	var role := other.name if other else seat
	return {
		"cid": c.id, "band": "rival", "id": "rival_%s_%s" % [seat, str(chosen.get("id", ""))],
		"seat": seat, "other_id": other.id if other else "",
		"title": str(chosen.get("title", "")), "speaker": role,
		"body": str(chosen.get("body", "")),
		"options": [
			_opt_from_side("left", chosen.get("left", {})),
			_opt_from_side("right", chosen.get("right", {})),
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
	return _need_ok(child, grand, need, {"seat": "grand"})


static func _need_ok(child: CKCharacter, other: CKCharacter, need: String, ctx: Dictionary) -> bool:
	if need == "":
		return true
	var node := _node_of(child)
	var month := int(Calendar.month)
	var world = Engine.get_main_loop().root.get_node_or_null("World") if Engine.get_main_loop() else null
	var pos := str(world.pos) if world != null else "ash_keep"
	var nation := str(world.nation_of(pos)) if world != null else "ashbanner"
	match need:
		"home":
			return node == "home" and (other == null or _node_of(other) == "home")
		"same":
			return other != null and _same_node(child, other)
		"home_or_reed":
			return node == "home" or node.begins_with("estate:")
		"roster_weapon", "other_roster_weapon":
			return other != null and other.in_roster and str(other.weapon_id) != ""
		"field", "on_field":
			return str(child.blood_meta.get("estate_job", "")) != ""
		"parent_present":
			for pid in child.parent_ids:
				var p: CKCharacter = GameState.characters.get(str(pid))
				if p != null and p.alive and _same_node(child, p):
					return true
			return false
		"winter":
			return month in [11, 12, 1, 2]
		"winter_or_frost":
			return month in [11, 12, 1, 2] or nation in ["frostcrown", "ironpass", "frost"]
		"summer_not_frost":
			return month in [6, 7, 8] and nation not in ["frostcrown", "frost"]
		"city_herb":
			return _in_city() and (int(GameState.herb) > 0 or _city_sells_herb())
		"has_copy":
			return CKLifeMarks.has(child, "copy")
		"forge_place":
			return node == "home" or _city_has_forge()
		"on_road":
			return node == "field" or _node_links_road()
		"bridge_node":
			return _at_bridge_or_ferry() or _node_links_bridge()
		"holding_lv2":
			for hid in GameState.holdings.keys():
				if CKEconomyState.holding_level(GameState, str(hid)) >= 2:
					return true
			return false
		"herb_place":
			return _holding_unlocked("fog_herb") or _city_sells_herb()
		"ferry_place":
			return _holding_unlocked("tide_ferry") or _at_bridge_or_ferry()
		"visible_blood":
			return _has_visible_blood(child)
		"mother_nation":
			return _mother_nation(child) != ""
		"ch0_banner":
			return bool(GameState.chapter0_flags.get("banner_kept", true)) or bool(GameState.house_mods.get("ch0_banner", true))
		"blood_verified":
			return bool(child.blood_meta.get("verified", false))
		"in_city":
			return _in_city()
		"hire_and_soft":
			return _has_hireling() and _soft_peak(child)
		"other_kids":
			return _other_house_kids(child) > 0
		"sibling_at_water":
			return other != null and other.alive and _same_node(child, other) and (_at_bridge_or_ferry() or node.begins_with("estate:"))
		"ferry_or_winter_water":
			return _at_bridge_or_ferry() or (month in [11, 12, 1, 2] and _near_water())
		"water_place":
			return node == "home" or _at_bridge_or_ferry() or node.begins_with("estate:")
		"both_work_age":
			return other != null and int(child.age) >= 8 and int(other.age) >= 8 and _has_any_holding()
		"both_home_or_field":
			return other != null and _has_any_holding() and (_same_node(child, other))
		"half_sibling_gate":
			return _half_sibling_gate(child, other)
		"dead_sibling_stele":
			return _has_dead_sibling_stele(child)
		"other_older2_home_reed":
			return other != null and int(other.age) >= int(child.age) + 2 and (node == "home" or node.begins_with("estate:"))
		"has_mal_or_scar":
			return "malnourished" in child.traits or "scarred" in child.traits
		"home_both_parents":
			return node == "home" and _both_sides_parent_home(child, other)
		"same_field":
			return other != null and str(child.blood_meta.get("estate_job", "")) != "" and str(child.blood_meta.get("estate_job", "")) == str(other.blood_meta.get("estate_job", ""))
		"home_other_has_copy":
			return node == "home" and other != null and CKLifeMarks.has(other, "copy") and not CKLifeMarks.has(child, "copy")
		"other_enlisted":
			return other != null and other.in_roster
		"heir_present_other":
			return _heir_present_other(child)
		"other_roster_same_place":
			return other != null and other.in_roster and _same_node(child, other)
		"home_or_same_road":
			return node == "home" or (other != null and _same_node(child, other))
		"same_city_or_home":
			return node == "home" or _in_city()
		"other_field_same":
			return other != null and str(other.blood_meta.get("estate_job", "")) != "" and str(other.blood_meta.get("estate_job", "")) == str(child.blood_meta.get("estate_job", ""))
		"older_sib_alive":
			return _older_sib_alive(child)
		"other_still_child_parent":
			return other != null and int(other.age) <= 15 and not other.in_roster and _parent_present_bool(child)
		_:
			return true


static func _in_city() -> bool:
	var world = Engine.get_main_loop().root.get_node_or_null("World") if Engine.get_main_loop() else null
	if world == null:
		return false
	var kind := str(world.node(str(world.pos)).get("kind", ""))
	return kind in ["city", "town", "capital", "port"]


static func _city_sells_herb() -> bool:
	return int(GameState.herb) > 0 or _in_city()


static func _city_has_forge() -> bool:
	return _in_city()


static func _node_links_road() -> bool:
	return true  # overworld edges are roads; field node already covers march


static func _node_links_bridge() -> bool:
	return _at_bridge_or_ferry()


static func _at_bridge_or_ferry() -> bool:
	var world = Engine.get_main_loop().root.get_node_or_null("World") if Engine.get_main_loop() else null
	if world == null:
		return false
	var kind := str(world.node(str(world.pos)).get("kind", ""))
	return kind in ["bridge", "ferry", "pass", "port", "ford"]


static func _near_water() -> bool:
	return _at_bridge_or_ferry() or _node_of(GameState.get_leader() if GameState.get_leader() else CKCharacter.new()) == "home"


static func _holding_unlocked(hid: String) -> bool:
	return CKEconomyState.holding_unlocked(GameState, hid)


static func _has_any_holding() -> bool:
	for hid in GameState.holdings.keys():
		if CKEconomyState.holding_unlocked(GameState, str(hid)):
			return true
	return false


static func _has_visible_blood(c: CKCharacter) -> bool:
	var signs := ["lamp_thread", "firefly", "frost_lash", "river_chart", "lamp"]
	for s in signs:
		if bool(c.blood_meta.get(s, false)):
			return true
	for tr in c.traits:
		if str(tr) in ["heir_mark", "lamp_thread"]:
			return true
	# genome visible flags
	var g = c.genome if typeof(c.genome) == TYPE_DICTIONARY else {}
	if typeof(g) == TYPE_DICTIONARY and bool(g.get("visible_sign", false)):
		return true
	return false


static func _mother_nation(c: CKCharacter) -> String:
	if c.parent_ids.size() < 2:
		return ""
	var mo: CKCharacter = GameState.characters.get(str(c.parent_ids[1]))
	if mo == null:
		return ""
	return CKFamilyState.candidate_nation(mo)


static func _has_hireling() -> bool:
	for x in GameState.characters.values():
		if x == null or not x.alive or not x.in_roster:
			continue
		if x.is_leader or x.is_child:
			continue
		if x.parent_ids.is_empty() and str(x.spouse_id) == "":
			return true
	return false


static func _soft_peak(c: CKCharacter) -> bool:
	var best := ""
	var best_v := -1
	for k in ["str", "vit", "skl", "agi", "per", "wil"]:
		var v := int(c.stats.get(k, 0))
		if v > best_v:
			best_v = v
			best = k
	return best in ["skl", "wil", "per"]


static func _other_house_kids(c: CKCharacter) -> int:
	var n := 0
	for x in GameState.characters.values():
		if x == null or x.id == c.id or not x.alive:
			continue
		if _eligible(x):
			n += 1
	return n


static func _half_sibling_gate(child: CKCharacter, other: CKCharacter) -> bool:
	if other == null:
		return false
	var shared := 0
	var shared_pid := ""
	for pid in child.parent_ids:
		if str(pid) in other.parent_ids:
			shared += 1
			shared_pid = str(pid)
	if shared != 1:
		return false
	var shared_p: CKCharacter = GameState.characters.get(shared_pid)
	if shared_p == null or not shared_p.alive or not _same_node(child, shared_p):
		return false
	for pid2 in child.parent_ids:
		if str(pid2) == shared_pid:
			continue
		var other_p: CKCharacter = GameState.characters.get(str(pid2))
		if other_p == null or not other_p.alive:
			return false
		if _same_node(child, other_p):
			return false
	return true


static func _has_dead_sibling_stele(child: CKCharacter) -> bool:
	for x in GameState.characters.values():
		if x == null or x.alive or x.id == child.id:
			continue
		if CKBloodline.kinship_degree(child, x, GameState.characters) == 2:
			if str(x.blood_meta.get("stele_cause", "")) != "":
				return true
	return false


static func _both_sides_parent_home(child: CKCharacter, other: CKCharacter) -> bool:
	if other == null:
		return false
	var a := false
	var b := false
	for pid in child.parent_ids:
		var p: CKCharacter = GameState.characters.get(str(pid))
		if p != null and p.alive and _node_of(p) == "home":
			a = true
	for pid2 in other.parent_ids:
		var p2: CKCharacter = GameState.characters.get(str(pid2))
		if p2 != null and p2.alive and _node_of(p2) == "home":
			b = true
	return a and b


static func _heir_present_other(child: CKCharacter) -> bool:
	var heir_id := str(GameState.house_mods.get("named_heir", ""))
	if heir_id == "" or heir_id == child.id:
		# fallback: first living house adult child of leader
		var leader := GameState.get_leader()
		if leader == null:
			return false
		for x in GameState.characters.values():
			if x == null or not x.alive or x.id == child.id:
				continue
			if leader.id in x.parent_ids and x.age >= 15:
				return _same_node(child, x)
		return false
	var h: CKCharacter = GameState.characters.get(heir_id)
	return h != null and h.alive and h.id != child.id and _same_node(child, h)


static func _older_sib_alive(child: CKCharacter) -> bool:
	for x in GameState.characters.values():
		if x == null or not x.alive or x.id == child.id:
			continue
		if CKBloodline.kinship_degree(child, x, GameState.characters) == 2 and int(x.age) > int(child.age):
			return true
	return false


static func _parent_present_bool(child: CKCharacter) -> bool:
	for pid in child.parent_ids:
		var p: CKCharacter = GameState.characters.get(str(pid))
		if p != null and p.alive and _same_node(child, p):
			return true
	return false


## --- Personality auto-pick -------------------------------------------------
## Scoring rule (also docs/design/sui-ke-auto-v92.md):
## 1) Child axes: bold vs careful from traits / 习痕 / six stats / lineage_path / blood signs.
## 2) Option risk: kill/scar/survivor/str·agi up → bold; care/pay/wil·per/soft marks → careful.
## 3) Side labels nudge: left/follow careful (−1), right/let bold (+1).
## 4) Prefer matching extreme; |bold−careful| < 0.75 → seeded RNG (id|year|card).
## 5) If preferred side needs care/pay and resolve fails, try next by preference.

const BOLD_TRAITS := ["brave", "temper", "scarred", "iron_gut", "sturdy", "night_owl", "lucky"]
const CARE_TRAITS := ["scholar", "keen_eye", "charmer", "heir_mark", "malnourished"]
const BOLD_MARKS := ["seize", "slip", "furnace", "hone", "bridge"]
const CARE_MARKS := ["watch", "copy", "ledger", "lamp", "lie_age", "tide"]


## bold − careful bias for this child (can be negative).
static func personality_bias(c: CKCharacter) -> float:
	return _boldness(c) - _carefulness(c)


static func _boldness(c: CKCharacter) -> float:
	if c == null:
		return 0.0
	var v := 0.0
	for t in c.traits:
		if str(t) in BOLD_TRAITS:
			v += 2.0
	for mid in CKLifeMarks.ids(c):
		if str(mid) in BOLD_MARKS:
			v += 1.0
	v += (float(c.stats.get("str", 8)) - 8.0) * 0.5
	v += (float(c.stats.get("agi", 8)) - 8.0) * 0.4
	v += (float(c.stats.get("vit", 8)) - 8.0) * 0.3
	var path := str(GameState.lineage_path.get(c.id, ""))
	if path == "martial":
		v += 2.0
	elif path == "merchant":
		v += 0.5
	if _has_visible_blood(c):
		v += 0.5
	return v


static func _carefulness(c: CKCharacter) -> float:
	if c == null:
		return 0.0
	var v := 0.0
	for t in c.traits:
		if str(t) in CARE_TRAITS:
			v += 2.0
	for mid in CKLifeMarks.ids(c):
		if str(mid) in CARE_MARKS:
			v += 1.0
	v += (float(c.stats.get("wil", 8)) - 8.0) * 0.5
	v += (float(c.stats.get("per", 8)) - 8.0) * 0.4
	v += (float(c.stats.get("skl", 8)) - 8.0) * 0.3
	var path := str(GameState.lineage_path.get(c.id, ""))
	if path == "scholar":
		v += 2.0
	elif path == "merchant":
		v += 0.5
	return v


## Higher = bolder / riskier option (left/care usually lower).
static func option_risk(opt: Dictionary) -> float:
	var score := 0.0
	var oid := str(opt.get("id", ""))
	if bool(opt.get("kill", false)):
		score += 8.0
	var trait_id := str(opt.get("trait", ""))
	if trait_id in ["scarred", "malnourished"]:
		score += 4.0
	if bool(opt.get("survive", false)):
		score += 3.0
	if str(opt.get("survivor", "")) != "":
		score += 2.0
	if bool(opt.get("care", false)):
		score -= 4.0
	if int(opt.get("pay", 0)) > 0:
		score -= 2.0
	if bool(opt.get("halt_march", false)):
		score -= 1.5
	var stat := str(opt.get("stat", ""))
	var gain := int(opt.get("gain", 0))
	if gain > 0 and stat in ["str", "agi", "vit"]:
		score += 2.0
	if gain > 0 and stat in ["wil", "per", "skl"]:
		score -= 2.0
	if gain < 0:
		score += 2.0
	var mark := str(opt.get("mark", ""))
	if mark in BOLD_MARKS:
		score += 2.0
	if mark in CARE_MARKS:
		score -= 2.0
	if oid in ["left", "follow"]:
		score -= 1.0
	elif oid in ["right", "let"]:
		score += 1.0
	if int(opt.get("morale", 0)) <= -2:
		score += 1.0
	return score


## Stable pick of option id for this child + card. year defaults to Calendar.year.
static func pick_option_id(c: CKCharacter, card: Dictionary, year: int = -1) -> String:
	var opts: Array = card.get("options", [])
	if opts.is_empty():
		return ""
	if opts.size() == 1:
		return str(opts[0].get("id", ""))
	var ordered := _options_by_preference(c, card, year)
	if ordered.is_empty():
		return str(opts[0].get("id", ""))
	return str(ordered[0])


static func _options_by_preference(c: CKCharacter, card: Dictionary, year: int = -1) -> Array:
	var y := Calendar.year if year < 0 else year
	var opts: Array = card.get("options", [])
	var scored: Array = []
	for o in opts:
		if typeof(o) != TYPE_DICTIONARY:
			continue
		scored.append({
			"id": str(o.get("id", "")),
			"risk": option_risk(o),
		})
	if scored.is_empty():
		return []
	var bias := personality_bias(c)
	var prefer_bold := bias > 0.75
	var prefer_care := bias < -0.75
	if prefer_bold:
		scored.sort_custom(func(a, b): return float(a["risk"]) > float(b["risk"]))
	elif prefer_care:
		scored.sort_custom(func(a, b): return float(a["risk"]) < float(b["risk"]))
	else:
		# Tie: seeded order so reloads match (not player choice).
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s|%d|%s|sui_pick" % [c.id if c else "", y, str(card.get("id", ""))])
		for row in scored:
			row["jitter"] = rng.randf()
		scored.sort_custom(func(a, b): return float(a["jitter"]) < float(b["jitter"]))
	var out: Array = []
	for row in scored:
		out.append(str(row["id"]))
	return out


## Human-readable effect hint for inbox / UI (no buttons).
static func effect_hint(opt: Dictionary) -> String:
	var bits: PackedStringArray = PackedStringArray()
	var trait_id := str(opt.get("trait", ""))
	if trait_id != "":
		bits.append(Locale.t("sui_hint_trait", [trait_id]))
	var mark := str(opt.get("mark", ""))
	if mark != "":
		bits.append(Locale.t("sui_hint_mark", [CKLifeMarks.zh(mark)]))
	var stat := str(opt.get("stat", ""))
	var gain := int(opt.get("gain", 0))
	if stat != "" and gain != 0:
		var signed := ("+" if gain > 0 else "") + str(gain)
		bits.append(Locale.t("sui_hint_stat", [stat, signed]))
	if bool(opt.get("care", false)):
		bits.append(Locale.t("sui_hint_care"))
	if int(opt.get("pay", 0)) > 0:
		bits.append(Locale.t("sui_hint_pay", [int(opt.get("pay", 0))]))
	if bool(opt.get("kill", false)):
		bits.append(Locale.t("sui_hint_kill"))
	if int(opt.get("morale", 0)) != 0:
		bits.append(Locale.t("sui_hint_morale", [int(opt.get("morale", 0))]))
	return " · ".join(bits)


## Apply personality pick, drop pending, append read-only inbox row.
## Tries preferred options in order when care/pay blocks the first.
static func fire_and_resolve_card(card: Dictionary, year: int = -1) -> Dictionary:
	var cid := str(card.get("cid", ""))
	var card_id := str(card.get("id", ""))
	if cid == "" or card_id == "":
		return {}
	var c: CKCharacter = GameState.characters.get(cid)
	if c == null:
		return {}
	var y := Calendar.year if year < 0 else year
	if _find_pending(cid, card_id).is_empty():
		_pending().append(card)
	var order := _options_by_preference(c, card, y)
	if order.is_empty():
		_drop_pending(cid, card_id)
		return {}
	var applied := {}
	var picked := ""
	for oid in order:
		var r: Dictionary = resolve(cid, card_id, str(oid))
		if bool(r.get("ok", false)):
			applied = r
			picked = str(oid)
			break
	if picked == "":
		# Last resort: drop so the month does not soft-lock remittance.
		_drop_pending(cid, card_id)
		_mark_fired(cid, card_id)
		return {}
	var opt := {}
	for o in card.get("options", []):
		if str(o.get("id", "")) == picked:
			opt = o
			break
	var outcome := str(opt.get("label", picked))
	var hint := effect_hint(opt)
	if hint != "":
		outcome = "%s（%s）" % [outcome, hint] if outcome != "" else hint
	var side := picked
	if picked == "follow":
		side = "left"
	elif picked == "let":
		side = "right"
	elif picked.begins_with("epitaph") or picked in ["stay", "go"]:
		side = picked
	var row := {
		"cid": cid,
		"id": card_id,
		"side": side,
		"option_id": picked,
		"outcome": outcome,
		"title": str(card.get("title", "")),
		"body": str(card.get("body", "")),
		"band": str(card.get("band", "")),
		"year": y,
		"month": Calendar.month,
		"dead": bool(applied.get("dead", false)),
		"hint": hint,
	}
	_inbox_rows().append(row)
	if GameState.has_method("add_lineage_event"):
		GameState.add_lineage_event(Locale.t("sui_auto_log", [str(card.get("title", card_id)), c.name, outcome]))
	return row


static func inbox() -> Array:
	return _inbox_rows().duplicate()


static func inbox_for(cid: String) -> Array:
	var out: Array = []
	for item in _inbox_rows():
		if str(item.get("cid", "")) == cid:
			out.append(item)
	return out


static func inbox_count() -> int:
	return _inbox_rows().size()


static func ack(cid: String, card_id: String) -> void:
	var kept: Array = []
	var dropped := false
	for item in _inbox_rows():
		if not dropped and str(item.get("cid", "")) == cid and str(item.get("id", "")) == card_id:
			dropped = true
			continue
		kept.append(item)
	GameState.house_mods["sui_inbox"] = kept


static func _inbox_rows() -> Array:
	var raw = GameState.house_mods.get("sui_inbox", null)
	if typeof(raw) != TYPE_ARRAY:
		raw = []
		GameState.house_mods["sui_inbox"] = raw
	return raw


## Old saves may still hold unresolved left/right rows — settle with personality pick.
static func _drain_legacy_pending() -> void:
	var rows: Array = _pending().duplicate()
	if rows.is_empty():
		return
	for item in rows:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var cid := str(item.get("cid", ""))
		var eid := str(item.get("id", ""))
		if cid == "" or eid == "":
			_drop_pending(cid, eid)
			continue
		# Still in pending — fire_and_resolve_card will find it.
		fire_and_resolve_card(item)


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
		# dead purse → spouse then flag treasury
		CKPurse.on_death(c)
		GameState.morale = maxi(0, int(GameState.morale) + int(opt.get("morale", -3)))
		if bool(opt.get("halt_march", false)):
			GameState.house_mods["halt_march_month"] = "%d-%d" % [Calendar.year, Calendar.month]
		GameState.log_event(_c("yao_log") % [c.name, epitaph])
		_drop_pending(cid, card_id)
		_mark_fired(cid, card_id)
		GameState.mark_dirty()
		return {"ok": true, "msg": _c("yao_dead_msg"), "dead": true}
	# Pay from present self or parent purse
	if int(opt.get("pay", 0)) > 0:
		var pay := int(opt.get("pay", 0))
		var paid := CKPurse.pay_for_child(c, pay)
		if not bool(paid.get("ok", false)):
			return {"ok": false, "msg": str(paid.get("msg", _c("purse_short") % [0, pay]))}
		if int(opt.get("herb_cost", 0)) > 0:
			GameState.herb = maxi(0, int(GameState.herb) - int(opt.get("herb_cost", 0)))
	if bool(opt.get("care", false)):
		var care_id := str(card.get("other_id", ""))
		if care_id == "":
			care_id = _pick_care_adult(c)
		if care_id == "":
			return {"ok": false, "msg": _c("no_care_adult")}
		var carer: CKCharacter = GameState.characters.get(care_id)
		if carer == null or not carer.alive or not carer.in_roster:
			return {"ok": false, "msg": _c("no_care_adult")}
		GameState.house_mods["care_lock_%s" % care_id] = "%d-%d" % [Calendar.year, Calendar.month]
		carer.blood_meta["care_lock"] = true
	if str(opt.get("trait", "")) != "":
		_add_trait(c, str(opt.get("trait", "")))
	var stat := str(opt.get("stat", ""))
	var gain := int(opt.get("gain", 0))
	if stat != "" and gain != 0:
		if gain > 0:
			c.stats[stat] = mini(int(c.apt_max.get(stat, 20)), int(c.stats.get(stat, 8)) + gain)
		else:
			c.stats[stat] = maxi(1, int(c.stats.get(stat, 8)) + gain)
	var mark := str(opt.get("mark", ""))
	if bool(opt.get("mark_soft", false)):
		mark = "ledger" if not CKLifeMarks.has(c, "ledger") else "hone"
	var mark_msg := ""
	if mark != "":
		var mr := CKLifeMarks.add(c, mark, "sui")
		if bool(mr.get("ok", false)):
			mark_msg = str(mr.get("msg", ""))
			if str(mr.get("evicted", "")) != "":
				mark_msg += Locale.t("ux_tutor_evict") % CKLifeMarks.zh(str(mr.get("evicted", "")))
	var other_id := str(card.get("other_id", ""))
	if other_id != "" and str(opt.get("other_mark", "")) != "":
		var oth: CKCharacter = GameState.characters.get(other_id)
		if oth != null and oth.alive and int(oth.age) <= 15 and not oth.in_roster:
			CKLifeMarks.add(oth, str(opt.get("other_mark", "")), "sui")
	if bool(opt.get("other_leave_work", false)) and other_id != "":
		var o2: CKCharacter = GameState.characters.get(other_id)
		if o2 != null and int(o2.age) >= 8 and int(o2.age) <= 15 and str(o2.blood_meta.get("estate_job", "")) != "":
			o2.blood_meta["estate_job"] = ""
			o2.blood_meta["care_lock"] = true
			GameState.house_mods["care_lock_%s" % other_id] = "%d-%d" % [Calendar.year, Calendar.month]
	if int(opt.get("food", 0)) != 0:
		GameState.food = maxi(0, int(GameState.food) + int(opt.get("food", 0)))
	if int(opt.get("herb", 0)) != 0:
		GameState.herb = maxi(0, int(GameState.herb) + int(opt.get("herb", 0)))
	if int(opt.get("rep", 0)) != 0:
		GameState.add_rep("ashland", int(opt.get("rep", 0)))
	if int(opt.get("mother_rep", 0)) != 0:
		var mn := _mother_nation(c)
		if mn != "":
			GameState.add_rep(mn, int(opt.get("mother_rep", 0)))
	if int(opt.get("rep_or_morale", 0)) != 0:
		if _in_city():
			GameState.add_rep(str(Engine.get_main_loop().root.get_node("World").nation_of(Engine.get_main_loop().root.get_node("World").pos)), int(opt.get("rep_or_morale", 0)))
		else:
			GameState.morale = clampi(int(GameState.morale) + int(opt.get("rep_or_morale", 0)), 0, 100)
	if int(opt.get("morale", 0)) != 0:
		GameState.morale = clampi(int(GameState.morale) + int(opt.get("morale", 0)), 0, 100)
	if bool(opt.get("strict_morale", false)) and str(GameState.house_mods.get("doctrine", "")) == "strict":
		GameState.morale = maxi(0, int(GameState.morale) - 1)
	_drop_pending(cid, card_id)
	_mark_fired(cid, card_id)
	c.recalc_hp()
	GameState.mark_dirty()
	var msg := _c("resolve_ok")
	if mark_msg != "":
		msg += mark_msg
	var surv := str(opt.get("survivor", card.get("survivor", "")))
	if surv != "":
		msg += " " + _c("survivor_prefix") + surv
	return {"ok": true, "msg": msg, "dead": false}


static func _add_trait(c: CKCharacter, tid: String) -> void:
	if tid == "":
		return
	if tid in c.traits:
		# design: malnourished already → vit-1; scarred already → skip to mark side (handled by caller)
		if tid == "malnourished":
			c.stats["vit"] = maxi(1, int(c.stats.get("vit", 8)) - 1)
		return
	if c.traits.size() >= 6:
		return
	c.traits.append(tid)


static func _pick_care_adult(c: CKCharacter) -> String:
	# parents → grandparents → adult siblings → uncle → other roster adults
	var chars: Dictionary = GameState.characters
	var ordered: Array = []
	for pid in c.parent_ids:
		ordered.append(str(pid))
	for other in chars.values():
		if grandparent_role(c, other, chars) != "":
			ordered.append(other.id)
	for other2 in chars.values():
		if other2 == null or other2.id == c.id:
			continue
		if CKBloodline.kinship_degree(c, other2, chars) == 2 and int(other2.age) >= 16:
			ordered.append(other2.id)
	for other3 in chars.values():
		if other3 == null:
			continue
		if _is_uncle_aunt(c, other3, chars) and int(other3.age) >= 16:
			ordered.append(other3.id)
	for other4 in chars.values():
		if other4 != null and other4.in_roster:
			ordered.append(other4.id)
	var seen := {}
	for id in ordered:
		if seen.has(id):
			continue
		seen[id] = true
		var p: CKCharacter = chars.get(id)
		if p == null or not p.alive or p.id == c.id:
			continue
		if int(p.age) < 16:
			continue
		if not _same_node(c, p):
			continue
		if not p.in_roster and not _is_house_person(p):
			continue
		if bool(p.blood_meta.get("care_lock", false)):
			continue
		return p.id
	return ""


static func pending_for(cid: String) -> Dictionary:
	for item in _pending():
		if str(item.get("cid", "")) == cid:
			return item
	return {}


static func pending_count() -> int:
	return _pending().size()


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
