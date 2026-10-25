class_name CKCastleServices
extends RefCounted
## CMP-03 annexes. Old works stay on the five-building ladder.
## A missing annex is unbuilt (0). building_level() would report 1 for a missing key.

const ANNEX := {
	"infirmary": "annex_infirmary",
	"academy": "annex_academy",
	"treasury": "annex_treasury",
	"embassy": "annex_embassy",
}
const OLD := ["hall", "barracks", "market", "forge", "shrine"]
const ANNEX_MAX := 3
const ANNEX_COST := {
	1: {"silver": 40, "iron": 1, "food": 4},
	2: {"silver": 80, "iron": 2, "food": 8},
	3: {"silver": 120, "iron": 3, "food": 12},
}

static func annex_level(host, id: String) -> int:
	return int(host.buildings.get(id, 0))

static func tier_of(level: int) -> int:
	if level <= 0:
		return 0
	if level == 1:
		return 1
	if level <= 3:
		return 2
	return 3

static func recovery_months(host, base_months: int) -> int:
	return maxi(1, base_months - annex_level(host, "infirmary"))


## Paid rest at the infirmary: silver sink that clears light wounds, shortens grave,
## restores HP. Lasting wounds stay (clinic/herb via CKInjury.mitigate). Unbuilt → refuse.
static func rest_cost(host) -> int:
	var lv := annex_level(host, "infirmary")
	return maxi(8, 28 - lv * 6)


static func rest_heal(host, cid: String) -> Dictionary:
	var lv := annex_level(host, "infirmary")
	if lv < 1:
		return {"ok": false, "msg": Locale.t("a1_rest_need")}
	var c: CKCharacter = host.characters.get(cid)
	if c == null or not c.alive:
		return {"ok": false, "msg": Locale.t("a1_rest_none")}
	var rec: Dictionary = CKInjury.record(c)
	var tier := str(rec.get("tier", ""))
	var needs: bool = c.injured or c.hp < c.max_hp or not rec.is_empty()
	if not needs:
		return {"ok": false, "msg": Locale.t("a1_rest_none")}
	if tier == "lasting":
		return {"ok": false, "msg": Locale.t("a1_rest_lasting")}
	var cost := rest_cost(host)
	if host.silver < cost:
		return {"ok": false, "msg": Locale.t("a1_rest_broke") % cost}
	host.silver -= cost
	if tier == "grave":
		var left := maxi(0, int(rec.get("months_left", 0)) - maxi(1, lv))
		if left <= 0:
			if typeof(c.blood_meta) == TYPE_DICTIONARY:
				c.blood_meta.erase("injury")
			c.injured = false
		else:
			rec["months_left"] = left
			if typeof(c.blood_meta) != TYPE_DICTIONARY:
				c.blood_meta = {}
			c.blood_meta["injury"] = rec
			c.injured = true
	else:
		## light / legacy injured flag / HP-only
		if typeof(c.blood_meta) == TYPE_DICTIONARY:
			c.blood_meta.erase("injury")
		c.injured = false
	c.hp = c.max_hp
	host.log_event(Locale.t("a1_rest_ok") % c.name)
	host.mark_dirty()
	return {"ok": true, "msg": Locale.t("a1_rest_ok") % c.name, "cost": cost}


static func educate(host, child) -> int:
	## v9.2：学舍不再直接加意。返回学舍提供的专师名额增量（Lv → +pairs）；未建为 0。
	## 兼容旧测试：child 为 null 或不合法时返回 0；合法时返回 annex 等级（名额增量）。
	if child == null or not child.alive or not child.is_child:
		return 0
	return annex_level(host, "academy")

static func tutor_pair_cap(host) -> int:
	return 1 + annex_level(host, "academy")

static func treasury_slots(host) -> int:
	return annex_level(host, "treasury")

static func can_counter(host) -> bool:
	return annex_level(host, "embassy") >= 1

static func upgrade_annex(host, id: String) -> Dictionary:
	if not ANNEX.has(id):
		return {"ok": false, "msg": Locale.t("annex_unknown")}
	var lv := annex_level(host, id)
	if lv >= ANNEX_MAX:
		return {"ok": false, "msg": Locale.t("annex_max")}
	var next_lv := lv + 1
	var cost: Dictionary = ANNEX_COST.get(next_lv, {})
	var need_s := int(cost.get("silver", 0))
	var need_i := int(cost.get("iron", 0))
	var need_f := int(cost.get("food", 0))
	if host.silver < need_s or host.iron < need_i or host.food < need_f:
		return {"ok": false, "msg": Locale.t("annex_short") % [need_s, need_i, need_f]}
	host.silver -= need_s
	host.iron -= need_i
	host.food -= need_f
	host.buildings[id] = next_lv
	host.log_event(Locale.t("annex_up") % [Locale.t(str(ANNEX[id])), next_lv])
	host.mark_dirty()
	return {"ok": true, "level": next_lv, "msg": Locale.t("annex_up") % [Locale.t(str(ANNEX[id])), next_lv]}
