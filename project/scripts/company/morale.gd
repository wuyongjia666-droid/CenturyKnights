class_name CKMorale
extends RefCounted
## CMP-07: company morale bands for battle, and desertion after two unpaid months.
## The century sim never goes unpaid, and this path does not touch GameState.rng.

const BANDS := [
	{"id": "high", "min": 80, "hit": 3, "atk": 1},
	{"id": "steady", "min": 50, "hit": 0, "atk": 0},
	{"id": "low", "min": 25, "hit": -3, "atk": 0},
	{"id": "broken", "min": 0, "hit": -5, "atk": -1},
]


static func battle_mods(morale: int) -> Dictionary:
	var m := clampi(morale, 0, 100)
	var pick: Dictionary = BANDS[BANDS.size() - 1]
	for band in BANDS:
		if m >= int(band.get("min", 0)):
			pick = band
			break
	return {"id": str(pick.get("id", "")), "hit": int(pick.get("hit", 0)), "atk": int(pick.get("atk", 0))}


static func stamp(battle: Node) -> void:
	if battle == null or not battle.has_signal("battle_finished"):
		return
	battle.set_meta("company_morale_mods", battle_mods(int(GameState.morale)))


static func hold_back(host) -> void:
	host.house_mods["morale_hold"] = true


static func unpaid_months(host) -> int:
	return int(host.house_mods.get("unpaid_months", 0))


static func on_payday(host, paid: bool) -> String:
	if paid:
		host.house_mods["unpaid_months"] = 0
		host.house_mods.erase("morale_hold")
		return ""
	var n := unpaid_months(host) + 1
	host.house_mods["unpaid_months"] = n
	if n < 2:
		return "欠饷 %d 个月" % n
	if bool(host.house_mods.get("morale_hold", false)):
		host.house_mods.erase("morale_hold")
		host.log_event("欠饷已两月，挽留下了要走的人")
		return "欠饷已两月，挽留下了要走的人"
	var who := _lowest(host)
	if who == null:
		return "欠饷已两月，没有可走的人"
	who.in_roster = false
	if typeof(who.blood_meta) != TYPE_DICTIONARY:
		who.blood_meta = {}
	who.blood_meta["deserted"] = true
	var kept: Array = []
	for id in host.deploy_ids:
		if str(id) != who.id:
			kept.append(id)
	host.deploy_ids = kept
	var text := "%s 因连续欠饷离队" % who.name
	host.log_event(text)
	host.add_lineage_event(text)
	return text


static func _lowest(host) -> CKCharacter:
	var best: CKCharacter = null
	var best_wil := 999
	var best_id := ""
	for c in host.roster():
		if c.is_leader:
			continue
		var wil := int(c.stats.get("wil", 0))
		var cid := str(c.id)
		if best == null or wil < best_wil or (wil == best_wil and cid < best_id):
			best = c
			best_wil = wil
			best_id = cid
	return best
