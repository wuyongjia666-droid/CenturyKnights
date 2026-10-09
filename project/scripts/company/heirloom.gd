class_name CKHeirloom
extends RefCounted
## CMP-08. Forge plus lives on World.gear so the existing save bag keeps it.
## A heirloom grows when it is passed down. The treasury scene is CMP-03; without it the piece stays with the bearer.

const SUCCESS := {1: 0.80, 2: 0.55, 3: 0.30}
const PLUS_MAX := 3

static func row(cid: String) -> Dictionary:
	var g = World.gear.get(cid, {})
	if typeof(g) != TYPE_DICTIONARY:
		g = {}
	return g

static func _write(cid: String, g: Dictionary) -> void:
	World.gear[cid] = g

static func plus_of(cid: String) -> int:
	return clampi(int(row(cid).get("plus", 0)), 0, PLUS_MAX)

static func succeeds(next_plus: int, roll: float) -> bool:
	return roll < float(SUCCESS.get(next_plus, 0.0))

static func cost_for(next_plus: int) -> Dictionary:
	return {"iron": 2 * next_plus, "silver": 15 * next_plus}

static func apply_roll(host, cid: String, roll: float) -> Dictionary:
	var cur := plus_of(cid)
	if cur >= PLUS_MAX:
		return {"ok": false, "msg": Locale.t("forge_plus_max"), "plus": cur}
	var nxt := cur + 1
	var cost := cost_for(nxt)
	if int(host.iron) < int(cost.iron) or int(host.silver) < int(cost.silver):
		return {"ok": false, "msg": Locale.t("forge_plus_short"), "plus": cur}
	host.iron -= int(cost.iron)
	host.silver -= int(cost.silver)
	if not succeeds(nxt, roll):
		host.log_event(Locale.t("forge_plus_fail") % nxt)
		return {"ok": false, "result": "fail", "plus": cur, "msg": Locale.t("forge_plus_fail") % nxt}
	var g := row(cid)
	g["plus"] = nxt
	_write(cid, g)
	host.log_event(Locale.t("forge_plus_ok") % nxt)
	return {"ok": true, "result": "success", "plus": nxt, "msg": Locale.t("forge_plus_ok") % nxt}

static func try_modify(host, cid: String) -> Dictionary:
	return apply_roll(host, cid, host.rng.randf())

static func mark_heirloom(cid: String, generation: int = 1) -> void:
	var g := row(cid)
	g["heirloom"] = true
	g["gen"] = maxi(1, generation)
	if not g.has("merit"):
		g["merit"] = 0
	_write(cid, g)

static func add_merit(cid: String, amount: int = 1) -> void:
	var g := row(cid)
	if not bool(g.get("heirloom", false)):
		return
	g["merit"] = int(g.get("merit", 0)) + amount
	_write(cid, g)

static func grown_atk(generation: int, merit: int) -> int:
	var extra := 0
	if generation >= 3:
		extra = 2
	elif generation >= 2:
		extra = 1
	extra += mini(3, int(merit) / 4)
	return extra

static func pass_down(from_id: String, to_id: String) -> Dictionary:
	var g := row(from_id)
	if not bool(g.get("heirloom", false)):
		return {"ok": false}
	var nxt := row(to_id)
	nxt["heirloom"] = true
	nxt["gen"] = int(g.get("gen", 1)) + 1
	nxt["merit"] = int(g.get("merit", 0))
	nxt["plus"] = int(g.get("plus", 0))
	_write(to_id, nxt)
	g["heirloom"] = false
	g["in_vault"] = false
	_write(from_id, g)
	return {"ok": true, "gen": int(nxt.gen)}

static func vault_cap(host) -> int:
	return maxi(0, int(host.buildings.get("treasury", 0)))

static func vault_count() -> int:
	var n := 0
	for cid in World.gear.keys():
		var g = World.gear[cid]
		if typeof(g) == TYPE_DICTIONARY and bool(g.get("in_vault", false)):
			n += 1
	return n

static func store(host, cid: String) -> Dictionary:
	var g := row(cid)
	if not bool(g.get("heirloom", false)):
		return {"ok": false, "msg": Locale.t("heirloom_none")}
	if bool(g.get("in_vault", false)):
		return {"ok": true, "msg": Locale.t("heirloom_vaulted")}
	if vault_count() >= vault_cap(host):
		return {"ok": false, "msg": Locale.t("heirloom_vault_full")}
	g["in_vault"] = true
	_write(cid, g)
	host.log_event(Locale.t("heirloom_vaulted"))
	return {"ok": true, "msg": Locale.t("heirloom_vaulted")}

static func withdraw(host, cid: String) -> Dictionary:
	var g := row(cid)
	if not bool(g.get("in_vault", false)):
		return {"ok": false, "msg": Locale.t("heirloom_not_vaulted")}
	g["in_vault"] = false
	_write(cid, g)
	host.log_event(Locale.t("heirloom_withdrawn"))
	return {"ok": true, "msg": Locale.t("heirloom_withdrawn")}

static func plus_bonus(c, stat: String) -> int:
	if c == null or str(stat) != "atk":
		return 0
	var g := row(str(c.id))
	if bool(g.get("in_vault", false)):
		return 0
	var bonus := int(g.get("plus", 0))
	if bool(g.get("heirloom", false)):
		bonus += grown_atk(int(g.get("gen", 1)), int(g.get("merit", 0)))
	return bonus
