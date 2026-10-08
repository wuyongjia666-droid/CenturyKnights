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

static func educate(host, child) -> int:
	var bonus := annex_level(host, "academy")
	if bonus <= 0 or child == null or not child.alive or not child.is_child:
		return 0
	var key := "wil"
	child.stats[key] = mini(int(child.apt_max.get(key, 20)), int(child.stats.get(key, 8)) + bonus)
	return bonus

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
