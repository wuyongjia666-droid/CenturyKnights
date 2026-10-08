class_name CKCourt
extends RefCounted
## v9.0 court layer on top of v8.9 bloodlines.
## Lamp-seat bids, marriage rites, NPC royal houses, and the merit title ladder.
## The original ten crown loci still decide succession and tavern price.

const LADDER := ["knight", "baron", "viscount", "count", "duke"]
const LADDER_ZH := {
	"knight": "勋士", "baron": "男爵", "viscount": "子爵", "count": "伯爵", "duke": "侯爵",
}
const STEP_NEED := {
	"baron": {"merit": 4, "fiefs": 0, "married": false, "rep": 8},
	"viscount": {"merit": 10, "fiefs": 1, "married": true, "rep": 20},
	"count": {"merit": 18, "fiefs": 1, "married": true, "rep": 40},
	"duke": {"merit": 28, "fiefs": 2, "married": true, "rep": 70},
}
const RIVAL_NAMES := ["琉商·澄", "夜市·未", "港栈·石"]

static func ladder_zh(rank_id: String) -> String:
	return str(LADDER_ZH.get(rank_id, rank_id))

static func current_title(c: Object) -> String:
	if c == null:
		return "knight"
	var meta: Dictionary = c.get("blood_meta") if typeof(c.get("blood_meta")) == TYPE_DICTIONARY else {}
	var titled := str(meta.get("title", ""))
	if titled in LADDER:
		return titled
	var rank := str(c.get("rank"))
	if rank in LADDER:
		return rank
	return "knight"

static func next_title(c: Object) -> String:
	var i := LADDER.find(current_title(c))
	if i < 0 or i + 1 >= LADDER.size():
		return ""
	return str(LADDER[i + 1])

static func merit_of(c: Object) -> int:
	if c == null:
		return 0
	var meta: Dictionary = c.get("blood_meta") if typeof(c.get("blood_meta")) == TYPE_DICTIONARY else {}
	var honors: Array = c.get("honors") if typeof(c.get("honors")) == TYPE_ARRAY else []
	return int(c.get("level")) * 3 + honors.size() * 5 + int(meta.get("merit", 0))

static func _profile(c: Object, ctx: Dictionary) -> Dictionary:
	var married := str(c.get("spouse_id")) != "" if c != null else false
	var fiefs := 0
	var rep := 0
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() else null
	var world = Engine.get_main_loop().root.get_node_or_null("World") if Engine.get_main_loop() else null
	if gs != null and gs.get("holdings") is Dictionary:
		fiefs = (gs.holdings as Dictionary).size()
	if world != null and world.has_method("nation_rep"):
		rep = int(world.nation_rep("ashbanner"))
	return {
		"merit": int(ctx.get("merit", merit_of(c))),
		"fiefs": int(ctx.get("fiefs", fiefs)),
		"married": bool(ctx.get("married", married)),
		"rep": int(ctx.get("rep", rep)),
	}

static func promotion_block(c: Object, ctx: Dictionary = {}) -> String:
	var nxt := next_title(c)
	if nxt == "":
		return "爵位已到侯爵"
	var need: Dictionary = STEP_NEED.get(nxt, {})
	var got := _profile(c, ctx)
	var bits: Array = []
	if int(got["merit"]) < int(need.get("merit", 0)):
		bits.append("功勋 %d/%d" % [int(got["merit"]), int(need.get("merit", 0))])
	if int(got["fiefs"]) < int(need.get("fiefs", 0)):
		bits.append("封地 %d/%d" % [int(got["fiefs"]), int(need.get("fiefs", 0))])
	if bool(need.get("married", false)) and not bool(got["married"]):
		bits.append("尚无婚约")
	if int(got["rep"]) < int(need.get("rep", 0)):
		bits.append("邦交 %d/%d" % [int(got["rep"]), int(need.get("rep", 0))])
	if bits.is_empty():
		return ""
	return "升%s还差：%s" % [ladder_zh(nxt), "、".join(bits)]

## Display rows for the promotion screen. Same gates as promotion_block.
static func requirement_rows(c: Object, ctx: Dictionary = {}) -> Array:
	var nxt := next_title(c)
	if nxt == "":
		return []
	var need: Dictionary = STEP_NEED.get(nxt, {})
	var got := _profile(c, ctx)
	var married_need := 1 if bool(need.get("married", false)) else 0
	var married_have := 1 if bool(got["married"]) else 0
	return [
		{"id": "merit", "label": "功勋", "have": int(got["merit"]), "need": int(need.get("merit", 0))},
		{"id": "fiefs", "label": "封地", "have": int(got["fiefs"]), "need": int(need.get("fiefs", 0))},
		{"id": "married", "label": "婚约", "have": married_have, "need": married_need},
		{"id": "rep", "label": "邦交", "have": int(got["rep"]), "need": int(need.get("rep", 0))},
	]

static func news_events() -> Array:
	var world = Engine.get_main_loop().root.get_node_or_null("World") if Engine.get_main_loop() else null
	if world == null or typeof(world.get("royal_courts")) != TYPE_DICTIONARY:
		return []
	var nations: Dictionary = (world.royal_courts as Dictionary).get("nations", {})
	var out: Array = []
	for nid in nations.keys():
		var house: Dictionary = nations[nid] if typeof(nations[nid]) == TYPE_DICTIONARY else {}
		var crisis := str(house.get("crisis_name", ""))
		for ev in house.get("log", []):
			if typeof(ev) != TYPE_DICTIONARY:
				continue
			out.append({
				"year": int(ev.get("year", 0)),
				"kind": str(ev.get("kind", "")),
				"text": str(ev.get("text", "")),
				"nation": str(nid),
				"nation_zh": str(CKBloodline.nation(str(nid)).get("name", nid)),
				"crisis": crisis,
			})
	out.sort_custom(func(a, b): return int(a["year"]) > int(b["year"]))
	return out

static func latest_marker(nid: String) -> Dictionary:
	var world = Engine.get_main_loop().root.get_node_or_null("World") if Engine.get_main_loop() else null
	if world == null or typeof(world.get("royal_courts")) != TYPE_DICTIONARY:
		return {}
	var nations: Dictionary = (world.royal_courts as Dictionary).get("nations", {})
	var house: Dictionary = nations.get(nid, {}) if typeof(nations.get(nid, {})) == TYPE_DICTIONARY else {}
	if house.is_empty():
		return {}
	var crisis := str(house.get("crisis_name", ""))
	var log: Array = house.get("log", []) if typeof(house.get("log")) == TYPE_ARRAY else []
	if log.is_empty() and crisis == "":
		return {}
	var last: Dictionary = log[log.size() - 1] if not log.is_empty() and typeof(log[log.size() - 1]) == TYPE_DICTIONARY else {}
	var kind := "crisis" if crisis != "" else str(last.get("kind", ""))
	return {"kind": kind, "text": str(last.get("text", crisis)), "crisis": crisis}

## Raise one step. Reaching 伯爵 writes rank "count", which wakes the Ashbanner chart the same way a deed does.
static func promote(c: Object, ctx: Dictionary = {}) -> Dictionary:
	var block := promotion_block(c, ctx)
	if block != "":
		return {"ok": false, "msg": block, "title": current_title(c)}
	var nxt := next_title(c)
	if typeof(c.get("blood_meta")) != TYPE_DICTIONARY:
		c.set("blood_meta", {})
	(c.get("blood_meta") as Dictionary)["title"] = nxt
	if nxt in CKCharacter.RANK_ORDER:
		c.set("rank", nxt)
	return {"ok": true, "msg": "爵位升为%s" % ladder_zh(nxt), "title": nxt}

# ── lamp seat ─────────────────────────────────────────
static func _purity(c: Object) -> float:
	if c == null:
		return 0.0
	var mix: Dictionary = c.get("blood_mix") if typeof(c.get("blood_mix")) == TYPE_DICTIONARY else {}
	var royal := str(CKBloodline.nation("lantern").get("royal", "lt_filament"))
	return clampf(float(mix.get(royal, 0.0)), 0.0, 1.0)

static func lamp_board(c: Object, nation_rep: int, year: int) -> Dictionary:
	var paper: Dictionary = CKBloodline.nation("lantern").get("paper", {})
	var costs: Dictionary = paper.get("cost", {})
	var purity := _purity(c)
	var mul := 1.22 - 0.45 * purity
	var cut := clampi(nation_rep, 0, 80) / 2
	var ask_b := maxi(80, int(round(float(costs.get("baron", 160)) * mul)) - cut)
	var ask_c := maxi(ask_b + 60, int(round(float(costs.get("count", 420)) * mul)) - cut)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("lamp|%d" % year)
	var rivals: Array = []
	var top := 0
	for i in RIVAL_NAMES.size():
		var bid := ask_b + int(rng.randi_range(-20, 90)) + i * 15
		bid = clampi(bid, 70, ask_c + 40)
		rivals.append({"name": RIVAL_NAMES[i], "bid": bid})
		top = maxi(top, bid)
	return {
		"purity": purity, "ask_baron": ask_b, "ask_count": ask_c, "cut": cut,
		"rivals": rivals, "top": top, "rep_min": int(paper.get("nation_rep_min", 30)),
		"year": year,
	}

static func place_bid(c: Object, amount: int, nation_rep: int, year: int) -> Dictionary:
	var board := lamp_board(c, nation_rep, year)
	if nation_rep < int(board["rep_min"]):
		return {"ok": false, "msg": "灯市邦交未到「友善」，灯籍不卖", "board": board}
	if amount < int(board["top"]):
		return {"ok": false, "msg": "出价低于夜市对手（%d）" % int(board["top"]), "board": board}
	if amount < int(board["ask_baron"]):
		return {"ok": false, "msg": "低于灯籍底价 %d" % int(board["ask_baron"]), "board": board}
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() else null
	if gs != null and int(gs.silver) < amount:
		return {"ok": false, "msg": "银币不足", "board": board}
	if gs != null:
		gs.silver -= amount
	var tier := "count" if amount >= int(board["ask_count"]) else "baron"
	var honors: Array = c.get("honors") if typeof(c.get("honors")) == TYPE_ARRAY else []
	var honor := str(CKBloodline.nation("lantern").get("paper", {}).get("honor", "paper_patent"))
	if not (honor in honors):
		honors.append(honor)
		c.set("honors", honors)
	if CKCharacter.RANK_ORDER.find(tier) > CKCharacter.RANK_ORDER.find(str(c.get("rank"))):
		c.set("rank", tier)
	if typeof(c.get("blood_meta")) != TYPE_DICTIONARY:
		c.set("blood_meta", {})
	(c.get("blood_meta") as Dictionary)["title"] = tier
	(c.get("blood_meta") as Dictionary)["lamp_seat"] = tier
	return {"ok": true, "msg": "灯籍落槌：%s，没有灯丝" % ladder_zh(tier), "tier": tier, "board": board}

# ── marriage rites ────────────────────────────────────
static func _line_nation(c: Object) -> String:
	if c == null or not c.has_method("primary_bloodline"):
		return ""
	var id := str(c.call("primary_bloodline"))
	if CKBloodline.tier_of(id) not in ["royal", "noble"]:
		return ""
	return CKBloodline.nation_of_line(id)

static func _is_carrier(c: Object, nid: String) -> bool:
	if c == null:
		return false
	var honors: Array = c.get("honors") if typeof(c.get("honors")) == TYPE_ARRAY else []
	if nid == "frostcrown" and ("frost_bond" in honors):
		return true
	if c.has_method("ensure_genome"):
		c.call("ensure_genome")
	var e := CKBloodline.express_nation(c.get("genome") if typeof(c.get("genome")) == TYPE_DICTIONARY else {}, nid, CKBloodline.ctx_of(c))
	return str(e.get("tier", "none")) != "none"

static func required_rites(suitor: Object, target: Object) -> Array:
	var out: Array = []
	var seen := {}
	for pair in [[suitor, target], [target, suitor]]:
		var who: Object = pair[0]
		var nid := _line_nation(who)
		if nid == "" or seen.has(nid):
			continue
		seen[nid] = true
		match nid:
			"qinghe":
				out.append({"id": "register", "name": "入牒礼", "cost": 80,
					"desc": "清河婚约要先入牒。付入牒礼后，子女写入玉牒，才算牒内继承人。",
					"block": "清河贵胤要求入牒礼，否则子女牒外、不得承座"})
			"saltmarsh":
				out.append({"id": "matrilocal", "name": "从母居", "cost": 0,
					"desc": "盐泽婚后从母居。女儿承潮座，儿子是潮伯之子，不承座。",
					"block": "盐泽婚约须接受从母居，儿子不承潮座"})
			"southzephyr":
				if CKBloodline.tier_of(str(who.call("primary_bloodline"))) == "royal":
					out.append({"id": "firefly", "name": "萤约", "cost": 0,
						"desc": "娶萤母之女须立萤约：第一位女儿归雾林，不入本旗花名册。",
						"block": "萤母不外嫁，除非立萤约，以一女归林"})
			"frostcrown":
				out.append({"id": "frost", "name": "携霜契", "cost": 40,
					"desc": "霜冕只与携因者谈婚。祠堂验到霜因（或已持携霜契）之后，子女才入冰钟之议。",
					"block": "霜冕婚约须携霜契：先在祠堂验明霜因"})
	return out

static func rite_block(suitor: Object, target: Object, accepted: Array) -> String:
	for r in required_rites(suitor, target):
		if not (str(r["id"]) in accepted):
			return str(r["block"])
		if str(r["id"]) == "frost" and not _is_carrier(suitor, "frostcrown") and not _is_carrier(target, "frostcrown"):
			return "双方都没有霜因，携霜契开不出来"
	return ""

static func explain_zh(suitor: Object, target: Object) -> String:
	var rites := required_rites(suitor, target)
	if rites.is_empty():
		return ""
	var bits: Array = []
	for r in rites:
		var cost := int(r["cost"])
		bits.append("%s%s\n%s" % [str(r["name"]), ("（%d 银）" % cost) if cost > 0 else "", str(r["desc"])])
	return "\n\n".join(bits)

static func apply_rites(suitor: Object, target: Object, accepted: Array) -> void:
	var ids: Array = []
	for r in required_rites(suitor, target):
		if str(r["id"]) in accepted:
			ids.append(str(r["id"]))
	for c in [suitor, target]:
		if c == null:
			continue
		if typeof(c.get("blood_meta")) != TYPE_DICTIONARY:
			c.set("blood_meta", {})
		var meta: Dictionary = c.get("blood_meta")
		var have: Array = meta.get("rites", [])
		for id in ids:
			if not (id in have):
				have.append(id)
		meta["rites"] = have
		if "frost" in ids:
			var honors: Array = c.get("honors") if typeof(c.get("honors")) == TYPE_ARRAY else []
			if not ("frost_bond" in honors):
				honors.append("frost_bond")
				c.set("honors", honors)

static func _rites_of(c: Object) -> Array:
	if c == null or typeof(c.get("blood_meta")) != TYPE_DICTIONARY:
		return []
	var r = (c.get("blood_meta") as Dictionary).get("rites", [])
	return r if typeof(r) == TYPE_ARRAY else []

## Consequences written onto the child. Returns Chinese notes for the lineage log.
static func stamp_child(child: Object, father: Object, mother: Object) -> Array:
	var rites: Array = []
	for id in _rites_of(father) + _rites_of(mother):
		if not (id in rites):
			rites.append(id)
	if rites.is_empty() or child == null:
		return []
	if typeof(child.get("blood_meta")) != TYPE_DICTIONARY:
		child.set("blood_meta", {})
	var meta: Dictionary = child.get("blood_meta")
	var notes: Array = []
	if "register" in rites:
		meta["registered"] = "qinghe"
		notes.append("%s 入玉牒，牒内可承座。" % str(child.get("name")))
	if "matrilocal" in rites:
		meta["residence"] = "saltmarsh"
		if str(child.get("gender")) == "m":
			meta["succession_bar"] = "saltmarsh"
			notes.append("%s 从母居，为潮伯之子，不承潮座。" % str(child.get("name")))
		else:
			notes.append("%s 从母居，潮座由女儿承。" % str(child.get("name")))
	if "firefly" in rites and str(child.get("gender")) == "f" and not bool(meta.get("return_grove", false)):
		var already := false
		var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() else null
		if gs != null:
			for other in gs.characters.values():
				if other == child:
					continue
				var om: Dictionary = other.get("blood_meta") if typeof(other.get("blood_meta")) == TYPE_DICTIONARY else {}
				if bool(om.get("return_grove", false)):
					var ps: Array = other.get("parent_ids") if typeof(other.get("parent_ids")) == TYPE_ARRAY else []
					var cps: Array = child.get("parent_ids") if typeof(child.get("parent_ids")) == TYPE_ARRAY else []
					if ps == cps:
						already = true
		if not already:
			meta["return_grove"] = true
			meta["succession_bar"] = "player"
			child.set("in_roster", false)
			notes.append("%s 按萤约归雾林，不入本旗花名册。" % str(child.get("name")))
	if "frost" in rites:
		meta["frost_heir"] = true
		notes.append("%s 持携霜契出生，可入冰钟之议。" % str(child.get("name")))
	return notes

static func can_inherit(c: Object, nid: String) -> bool:
	if c == null:
		return false
	var meta: Dictionary = c.get("blood_meta") if typeof(c.get("blood_meta")) == TYPE_DICTIONARY else {}
	if str(meta.get("succession_bar", "")) == nid:
		return false
	if nid == "qinghe" and _rites_of(c).is_empty() and str(meta.get("registered", "")) == "" and bool(meta.get("needs_register", false)):
		return false
	return true

# ── NPC royal houses ──────────────────────────────────
static func _given(nid: String, sex: String, n: int) -> String:
	var bank := {
		"ashbanner": ["衡", "垣", "砾"], "shuoying": ["寂", "弦", "晦"], "qinghe": ["澜", "渚", "清"],
		"lantern": ["琉", "澄", "市"], "frostcrown": ["霜", "钟", "缄"], "emberold": ["窑", "瓷", "烬"],
		"saltmarsh": ["潮", "卤", "汐"], "irongorge": ["峡", "锻", "砺"], "starriver": ["津", "弧", "纬"],
		"southzephyr": ["萤", "雾", "苇"],
	}
	var arr: Array = bank.get(nid, ["无名"])
	return str(arr[n % arr.size()]) + ("娘" if sex == "f" and n == 0 else "")

static func _member(nid: String, idx: int, sex: String, age: int, royal: bool, rng: RandomNumberGenerator) -> Dictionary:
	var nat := CKBloodline.nation(nid)
	var line := str(nat.get("royal", ""))
	if not royal:
		var nobles: Array = nat.get("noble", []) if typeof(nat.get("noble")) == TYPE_ARRAY else []
		line = str(nobles[0]) if not nobles.is_empty() else str(nat.get("folk", "common_ash"))
	var c := CKCharacter.new()
	c.id = "court_%s_%d" % [nid, idx]
	c.name = str(nat.get("name", nid)) + _given(nid, sex, idx)
	c.gender = sex
	c.age = age
	c.rank = "count" if royal else "baron"
	c.level = 6 if royal else 3
	c.blood_mix = {line: 1.0}
	c.stats = {"str": 10, "vit": 10, "skl": 8, "agi": 8, "per": 8, "wil": 12}
	c.genome = CKGenome.founder(c.blood_mix, {}, rng, sex)
	if royal:
		CKBloodline.force_tier(c.genome, nid, "royal", sex)
		CKBloodline.stamp_traits(c.genome, nid, "full", sex, false)
	return {
		"id": c.id, "name": c.name, "gender": sex, "age": age, "alive": true, "rank": c.rank,
		"level": c.level, "blood_mix": c.blood_mix.duplicate(), "genome": c.genome.duplicate(true),
		"parent_ids": [], "spouse_id": "", "honors": [], "stats": c.stats.duplicate(), "line": line,
	}

static func _as_char(d: Dictionary) -> CKCharacter:
	var c := CKCharacter.new()
	c.id = str(d.get("id", ""))
	c.name = str(d.get("name", ""))
	c.gender = str(d.get("gender", "m"))
	c.age = int(d.get("age", 20))
	c.rank = str(d.get("rank", "knight"))
	c.level = int(d.get("level", 1))
	c.alive = bool(d.get("alive", true))
	c.blood_mix = (d.get("blood_mix", {}) as Dictionary).duplicate()
	c.genome = (d.get("genome", {}) as Dictionary).duplicate(true)
	c.parent_ids = (d.get("parent_ids", []) as Array).duplicate()
	c.spouse_id = str(d.get("spouse_id", ""))
	c.honors = (d.get("honors", []) as Array).duplicate()
	c.stats = (d.get("stats", {}) as Dictionary).duplicate()
	return c

static func blank_courts(seed_i: int = 1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i
	var nations := {}
	for nid in CKBloodline.nation_ids():
		var queen: bool = ["saltmarsh", "southzephyr", "frostcrown"].has(str(nid))
		var monarch_sex := "f" if queen else "m"
		var spouse_sex := "m" if queen else "f"
		if nid == "emberold":
			monarch_sex = "m"
			spouse_sex = "f"
		var monarch := _member(nid, 0, monarch_sex, 36 + (rng.randi() % 8), true, rng)
		var spouse := _member(nid, 1, spouse_sex, int(monarch["age"]) - 2, false, rng)
		monarch["spouse_id"] = spouse["id"]
		spouse["spouse_id"] = monarch["id"]
		var heir := _member(nid, 2, monarch_sex, 16, true, rng)
		heir["parent_ids"] = [monarch["id"], spouse["id"]]
		var spare := _member(nid, 3, spouse_sex, 12, true, rng)
		spare["parent_ids"] = [monarch["id"], spouse["id"]]
		nations[nid] = {
			"monarch": monarch["id"], "crisis": "", "crisis_name": "",
			"members": [monarch, spouse, heir, spare], "log": [],
		}
	return {"year": 0, "nations": nations, "rumors": []}

static func _ensure_spouse(house: Dictionary, monarch: Dictionary, nid: String, year: int, members: Array) -> void:
	var spouse := _find_member(house, str(monarch.get("spouse_id", "")))
	if not spouse.is_empty() and bool(spouse.get("alive", false)):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("spouse|%s|%s|%d" % [nid, str(monarch.get("id", "")), year])
	var sex := "f" if str(monarch.get("gender")) == "m" else "m"
	var age := maxi(16, int(monarch.get("age", 24)) - 2)
	var made := _member(nid, members.size() + year * 3 + 4, sex, age, false, rng)
	made["spouse_id"] = str(monarch.get("id", ""))
	monarch["spouse_id"] = made["id"]
	members.append(made)
	house["members"] = members
	var line := "%s 为新君配婚 %s。" % [CKBloodline.nation(nid).get("name", nid), made.get("name", "")]
	if typeof(house.get("log")) != TYPE_ARRAY:
		house["log"] = []
	house["log"].append({"year": year, "kind": "marriage", "text": line})

static func _find_member(house: Dictionary, id: String) -> Dictionary:
	for m in house.get("members", []):
		if str(m.get("id", "")) == id:
			return m
	return {}

static func tick(state: Dictionary, year: int) -> Dictionary:
	var nations: Dictionary = state.get("nations", {})
	var rumors: Array = state.get("rumors", [])
	for nid in nations.keys():
		var house: Dictionary = nations[nid]
		var members: Array = house.get("members", [])
		if typeof(house.get("log")) != TYPE_ARRAY:
			house["log"] = []
		var living := 0
		for m in members:
			if not bool(m.get("alive", false)):
				continue
			m["age"] = int(m.get("age", 20)) + 1
			living += 1
			var age := int(m["age"])
			var die := age >= 72 or (age >= 56 and posmod(hash("%s|%s|%d" % [nid, m["id"], year]), 7) == 0)
			if die:
				m["alive"] = false
				living -= 1
				var line := "%s %s 辞世（%d）。" % [CKBloodline.nation(nid).get("name", nid), m.get("name", ""), age]
				house["log"].append({"year": year, "kind": "death", "text": line})
				rumors.push_front(line)
		var monarch: Dictionary = _find_member(house, str(house.get("monarch", "")))
		if monarch.is_empty() or not bool(monarch.get("alive", false)):
			var cands: Array = []
			var chars := {}
			for m in members:
				if not bool(m.get("alive", false)):
					continue
				var ch := _as_char(m)
				chars[ch.id] = ch
				cands.append(ch)
			var sx := CKBloodline.succession(cands, str(nid), chars)
			house["crisis"] = str(sx.get("crisis", ""))
			house["crisis_name"] = str(sx.get("crisis_name", ""))
			var heir_id := str(sx.get("heir", ""))
			if heir_id == "":
				var eldest := {}
				var eldest_age := -1
				for m2 in members:
					if bool(m2.get("alive", false)) and int(m2.get("age", 0)) > eldest_age:
						eldest = m2
						eldest_age = int(m2.get("age", 0))
				heir_id = str(eldest.get("id", ""))
				if heir_id != "" and str(house.get("crisis_name", "")) == "":
					house["crisis"] = "vacant"
					house["crisis_name"] = str(CKBloodline.nation(nid).get("crisis", {}).get("vacant", "空位"))
			if heir_id != "":
				house["monarch"] = heir_id
			var cz := str(house.get("crisis_name", ""))
			var text := "%s王脉更替" % CKBloodline.nation(nid).get("name", nid)
			if cz != "":
				text += "，危机「%s」" % cz
			text += "。"
			if typeof(house.get("log")) != TYPE_ARRAY:
				house["log"] = []
			house["log"].append({"year": year, "kind": "succession", "text": text})
			if cz != "":
				house["crisis_total"] = int(house.get("crisis_total", 0)) + 1
			rumors.push_front(text)
			monarch = _find_member(house, str(house.get("monarch", "")))
		if living <= 0:
			var rng_c := RandomNumberGenerator.new()
			rng_c.seed = hash("cadet|%s|%d" % [nid, year])
			var recalled := _member(str(nid), members.size() + year * 3 + 11, "m" if rng_c.randf() < 0.5 else "f", 24, true, rng_c)
			var consort_sex := "f" if str(recalled.get("gender")) == "m" else "m"
			var consort := _member(str(nid), members.size() + year * 3 + 12, consort_sex, 22, false, rng_c)
			recalled["spouse_id"] = consort["id"]
			consort["spouse_id"] = recalled["id"]
			members.append(recalled)
			members.append(consort)
			house["monarch"] = recalled["id"]
			house["members"] = members
			living = 2
			var back := "%s流裔归国：%s 承灯未灭的王脉。" % [CKBloodline.nation(nid).get("name", nid), recalled.get("name", "")]
			house["log"].append({"year": year, "kind": "recall", "text": back})
			house["recall_total"] = int(house.get("recall_total", 0)) + 1
			rumors.push_front(back)
			monarch = recalled
		elif not monarch.is_empty() and bool(monarch.get("alive", false)):
			_ensure_spouse(house, monarch, str(nid), year, members)
			living = 0
			for m3 in members:
				if bool(m3.get("alive", false)):
					living += 1
		if living < 8 and not monarch.is_empty() and bool(monarch.get("alive", false)) and int(monarch.get("age", 99)) < 54:
			var spouse := _find_member(house, str(monarch.get("spouse_id", "")))
			if not spouse.is_empty() and bool(spouse.get("alive", false)) and posmod(hash("birth|%s|%d" % [nid, year]), 3) == 0:
				var rng := RandomNumberGenerator.new()
				rng.seed = hash("born|%s|%d" % [nid, year])
				var sex := "f" if rng.randf() < 0.5 else "m"
				var baby := _member(str(nid), members.size() + year, sex, 0, true, rng)
				var fa := monarch if str(monarch.get("gender")) == "m" else spouse
				var mo := spouse if fa == monarch else monarch
				var child := _as_char(baby)
				var fch := _as_char(fa)
				var mch := _as_char(mo)
				child.genome = CKGenome.cross(fch.genome, mch.genome, {str(CKBloodline.nation(nid).get("royal", "")): 1.0}, rng, sex)
				baby["genome"] = child.genome
				baby["parent_ids"] = [str(fa.get("id", "")), str(mo.get("id", ""))]
				baby["age"] = 0
				members.append(baby)
				var born := "%s 添丁 %s。" % [CKBloodline.nation(nid).get("name", nid), baby["name"]]
				house["log"].append({"year": year, "kind": "birth", "text": born})
				rumors.push_front(born)
		CKSchemes.record_year(house, str(nid), year)
		if typeof(house.get("log")) != TYPE_ARRAY:
			house["log"] = []
		if house["log"].size() > 48:
			house["log"] = (house["log"] as Array).slice(house["log"].size() - 48)
		nations[nid] = house
	if rumors.size() > 16:
		rumors = rumors.slice(0, 16)
	state["nations"] = nations
	state["rumors"] = rumors
	state["year"] = year
	return state

static func simulate(years: int, seed_i: int = 7) -> Dictionary:
	var st := blank_courts(seed_i)
	for y in years:
		st = tick(st, y + 1)
	return st

static func latest_rumor() -> String:
	var world = Engine.get_main_loop().root.get_node_or_null("World") if Engine.get_main_loop() else null
	if world == null or typeof(world.get("royal_courts")) != TYPE_DICTIONARY:
		return ""
	var rumors: Array = (world.royal_courts as Dictionary).get("rumors", [])
	if rumors.is_empty():
		return ""
	return str(rumors[0])

static func recruit_bias(nid: String) -> float:
	var world = Engine.get_main_loop().root.get_node_or_null("World") if Engine.get_main_loop() else null
	if world == null or typeof(world.get("royal_courts")) != TYPE_DICTIONARY:
		return 0.0
	var nations: Dictionary = (world.royal_courts as Dictionary).get("nations", {})
	var house: Dictionary = nations.get(nid, {})
	if str(house.get("crisis_name", "")) == "":
		return 0.0
	return 1.4

static func tick_live(year: int) -> Array:
	var world = Engine.get_main_loop().root.get_node_or_null("World") if Engine.get_main_loop() else null
	if world == null:
		return []
	var st: Dictionary = world.royal_courts if typeof(world.royal_courts) == TYPE_DICTIONARY and not (world.royal_courts as Dictionary).is_empty() else blank_courts(year * 17 + 3)
	var before: Dictionary = {}
	for nid in (st.get("nations", {}) as Dictionary).keys():
		before[nid] = str((st["nations"] as Dictionary)[nid].get("crisis_name", ""))
	st = tick(st, year)
	world.royal_courts = st
	var fresh: Array = []
	for nid in (st.get("nations", {}) as Dictionary).keys():
		var house: Dictionary = (st["nations"] as Dictionary)[nid]
		var log: Array = house.get("log", [])
		if log.is_empty():
			continue
		var last: Dictionary = log[log.size() - 1]
		if int(last.get("year", -1)) != year:
			continue
		fresh.append(str(last.get("text", "")))
		if world.tips is Array:
			world.tips.push_front(str(last.get("text", "")))
			if world.tips.size() > 8:
				world.tips.resize(8)
		if world.travel_log is Array:
			world.travel_log.push_front(str(last.get("text", "")))
			if world.travel_log.size() > 12:
				world.travel_log.resize(12)
		var delta := -3 if str(house.get("crisis_name", "")) != "" and str(house.get("crisis_name", "")) != str(before.get(nid, "")) else 1
		_nudge_rep(world, str(nid), delta)
	return fresh

static func _nudge_rep(world, nid: String, delta: int) -> void:
	if not world.has_method("nation_rep") or not world.has_method("rep_tier_index"):
		return
	var cur := int(world.nation_rep(nid))
	var nxt := clampi(cur + delta, 0, 100)
	if int(world.rep_tier_index(nxt)) < int(world.rep_tier_index(cur)):
		return
	world.add_nation_rep(nid, delta)

# ── Stitch panels (same kit as the city and the castle) ──
static func build_lamp_ui(host: Control, board: Dictionary, on_bid: Callable) -> void:
	var p := UIKit.panel_at(host, Rect2(0, 0, 820, 540), 12)
	p.name = "LampSeat"
	var en := UIKit.mono("LAMP SEAT // 灯籍竞价", 9, UIKit.ACCENT)
	en.position = Vector2(22, 16)
	p.add_child(en)
	var title := UIKit.title_label("灯籍", 28)
	title.position = Vector2(22, 32)
	p.add_child(title)
	var purity := int(round(float(board.get("purity", 0.0)) * 100.0))
	var purity_l := UIKit.mono("灯丝纯度", 9, UIKit.TEXT_FAINT)
	purity_l.position = Vector2(560, 18)
	p.add_child(purity_l)
	var purity_v := UIKit.mono("%d%%" % purity, 22, UIKit.ACCENT)
	purity_v.position = Vector2(560, 34)
	p.add_child(purity_v)
	var bar := UIKit.slim_bar(float(purity), 100.0, UIKit.ACCENT, 220, 4)
	bar.position = Vector2(560, 66)
	p.add_child(bar)
	var body := UIKit.body_label("灯丝不卖。灯籍只是名分。血越纯、邦交越高，底价越低。夜市按本年种子出价，落槌不改血。", UIKit.TEXT_DIM, 13)
	body.position = Vector2(22, 78)
	body.size = Vector2(500, 40)
	body.custom_minimum_size = Vector2(500, 0)
	p.add_child(body)
	var meta := UIKit.mono("男爵底价 %d    伯爵底价 %d    邦交折让 %d" % [int(board.get("ask_baron", 0)), int(board.get("ask_count", 0)), int(board.get("cut", 0))], 11, UIKit.TEXT_DIM, false)
	meta.position = Vector2(22, 124)
	p.add_child(meta)
	var track := Control.new()
	track.name = "BidTimeline"
	track.position = Vector2(22, 168)
	track.size = Vector2(776, 210)
	p.add_child(track)
	var rail := UIKit.hairline(Color(UIKit.ACCENT, 0.35))
	rail.position = Vector2(8, 78)
	rail.size = Vector2(760, 2)
	track.add_child(rail)
	var bids: Array = []
	var lo := int(board.get("ask_baron", 80))
	var hi := maxi(int(board.get("ask_count", lo + 1)), int(board.get("top", lo + 1)))
	for rv in board.get("rivals", []):
		bids.append({"name": str(rv.get("name", "")), "bid": int(rv.get("bid", 0)), "you": false})
	bids.append({"name": "男爵席", "bid": int(board.get("ask_baron", 0)), "you": true, "seat": "baron"})
	bids.append({"name": "伯爵席", "bid": maxi(int(board.get("ask_count", 0)), int(board.get("top", 0))), "you": true, "seat": "count"})
	var span := maxi(1, hi - mini(lo, int(board.get("ask_baron", lo))) + 40)
	var origin := mini(lo, int(board.get("ask_baron", lo))) - 20
	bids.sort_custom(func(a, b): return int(a["bid"]) < int(b["bid"]))
	for i in bids.size():
		var bid := int(bids[i]["bid"])
		var x := clampf(float(bid - origin) / float(span), 0.0, 1.0) * 720.0
		var you: bool = bool(bids[i].get("you", false))
		var dot := Panel.new()
		dot.position = Vector2(x, 70)
		dot.size = Vector2(16, 16)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var col: Color = UIKit.ACCENT if you else UIKit.TEXT_DIM
		dot.add_theme_stylebox_override("panel", UIKit.flat_box(col, col, 8))
		track.add_child(dot)
		var nm := UIKit.body_label("%s\n%d" % [str(bids[i]["name"]), bid], col, 12)
		nm.position = Vector2(x - 36, 22 if i % 2 == 0 else 96)
		nm.size = Vector2(110, 40)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		track.add_child(nm)
	var top := UIKit.body_label("压过夜市至少 %d。低于此数，灯籍不落槌。" % int(board.get("top", 0)), UIKit.ACCENT, 13)
	top.position = Vector2(22, 392)
	p.add_child(top)
	var bid_b := UIKit.cta_button("出价男爵 %d" % int(board.get("ask_baron", 0)), "", 240, 44)
	bid_b.name = "LampBidBaron"
	bid_b.position = Vector2(22, 468)
	bid_b.pressed.connect(func():
		Sfx.click()
		Sfx.play("lamp_flicker")
		on_bid.call(int(board.get("ask_baron", 0))))
	p.add_child(bid_b)
	var count_bid := maxi(int(board.get("ask_count", 0)), int(board.get("top", 0)))
	var bid_c := UIKit.ghost_button("出价伯爵 %d" % count_bid, 260, 44)
	bid_c.name = "LampBidCount"
	bid_c.position = Vector2(280, 468)
	bid_c.pressed.connect(func():
		Sfx.click()
		Sfx.play("lamp_flicker")
		on_bid.call(count_bid))
	p.add_child(bid_c)
	UIFX.wire_tree(p)
	UIFX.fade_in(track, 0.28)

static func build_promote_ui(host: Control, c: Object, ctx: Dictionary, on_promote: Callable) -> void:
	var p := UIKit.panel_at(host, Rect2(0, 0, 420, 300), 10)
	p.name = "PromoteSeat"
	var en := UIKit.mono("TITLE // 请爵", 9, UIKit.ACCENT)
	en.position = Vector2(16, 12)
	p.add_child(en)
	var now := current_title(c)
	var nxt := next_title(c)
	var title := UIKit.title_label("%s → %s" % [ladder_zh(now), ladder_zh(nxt) if nxt != "" else "—"], 18)
	title.position = Vector2(16, 28)
	p.add_child(title)
	var y := 68.0
	for row in requirement_rows(c, ctx):
		var have := int(row["have"])
		var need := int(row["need"])
		var ok := need <= 0 or have >= need
		var lab := UIKit.body_label("%s  %d / %d" % [str(row["label"]), have, need], UIKit.OK if ok else UIKit.TEXT, 13)
		lab.name = "Req" + str(row["id"]).capitalize()
		lab.position = Vector2(16, y)
		lab.size = Vector2(180, 18)
		p.add_child(lab)
		var bar := UIKit.slim_bar(float(have), float(maxi(need, 1)), UIKit.OK if ok else UIKit.ACCENT, 180, 4)
		bar.position = Vector2(210, y + 7)
		p.add_child(bar)
		y += 28.0
	var block := promotion_block(c, ctx)
	var body := UIKit.body_label(block if block != "" else "四项都够。升到伯爵时，烬图携因者的河图纹会醒。旗誓仍是另一条路。", UIKit.TEXT_DIM, 12)
	body.position = Vector2(16, 188)
	body.size = Vector2(388, 48)
	body.custom_minimum_size = Vector2(388, 0)
	p.add_child(body)
	var b := UIKit.cta_button("请爵", "", 160, 44)
	b.name = "PromoteTitle"
	b.position = Vector2(16, 240)
	b.disabled = block != ""
	b.pressed.connect(func():
		Sfx.click()
		on_promote.call())
	p.add_child(b)
	UIFX.wire_tree(p)
