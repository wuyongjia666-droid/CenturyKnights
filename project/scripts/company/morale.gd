class_name CKMorale
extends RefCounted
## CMP-07: company morale bands for battle, and desertion after two unpaid months.
## This path does not touch GameState.rng.
## CKCampaignSim sets suppress_desertion so the headless century keeps its roster.
## Seeds 1113, 1116 and 1119 skim zero; letting people leave rewrites about 500
## portrait-bank buckets in the art farm queue. The player payroll path still deserts.

static var suppress_desertion := false

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
	if suppress_desertion:
		return ""
	if paid:
		host.house_mods["unpaid_months"] = 0
		host.house_mods.erase("morale_hold")
		return ""
	var n := unpaid_months(host) + 1
	host.house_mods["unpaid_months"] = n
	if n < 2:
		return Locale.t("morale.unpaid_months") % n
	if bool(host.house_mods.get("morale_hold", false)):
		host.house_mods.erase("morale_hold")
		host.log_event(Locale.t("morale.held_back"))
		return Locale.t("morale.held_back")
	var who := _lowest(host)
	if who == null:
		return Locale.t("morale.nobody_left")
	who.in_roster = false
	if typeof(who.blood_meta) != TYPE_DICTIONARY:
		who.blood_meta = {}
	who.blood_meta["deserted"] = true
	var kept: Array = []
	for id in host.deploy_ids:
		if str(id) != who.id:
			kept.append(id)
	host.deploy_ids = kept
	var text := Locale.t("morale.deserted") % who.name
	host.log_event(text)
	host.add_lineage_event(text)
	return text


static func _lowest(host) -> CKCharacter:
	var best: CKCharacter = null
	var best_wil := 999
	var best_id := ""
	var prologue: bool = host.has_method("flag") and not host.flag("chapter0_done")
	var leader_spouse := ""
	for c in host.roster():
		if c.is_leader:
			leader_spouse = str(c.spouse_id)
	for c in host.roster():
		if c.is_leader:
			continue
		# Opening review A-05: in the prologue the story companions and the spouse stay put.
		if prologue and (str(c.cast_key) in ["wantan", "dengying"] or str(c.id) == leader_spouse):
			continue
		var wil := int(c.stats.get("wil", 0))
		var cid := str(c.id)
		if best == null or wil < best_wil or (wil == best_wil and cid < best_id):
			best = c
			best_wil = wil
			best_id = cid
	return best
