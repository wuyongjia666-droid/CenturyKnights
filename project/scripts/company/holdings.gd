class_name CKHoldings
extends RefCounted
## CMP-06. A second seat is not one of the four estate plots.
## The chain hook only records an offer. Silver moves when the company claims it.

const SEAT := "second_seat"

static func seat(host) -> Dictionary:
	var row = host.holdings.get(SEAT, {})
	return row if typeof(row) == TYPE_DICTIONARY else {}

static func owned(host) -> bool:
	return bool(seat(host).get("owned", false))

static func note_chain(chain_id: String) -> void:
	if chain_id == "":
		return
	World.second_hold_offer = chain_id

static func claim(host, city_id: String, reason: String = "chain") -> Dictionary:
	if owned(host):
		return {"ok": false, "msg": Locale.t("hold_already")}
	if city_id == "" or not World.nodes.has(city_id):
		return {"ok": false, "msg": Locale.t("hold_no_city")}
	host.holdings[SEAT] = {
		"owned": true,
		"city": city_id,
		"reason": reason,
		"garrison_home": 4,
		"garrison_away": 2,
		"yield_silver": 18,
		"yield_food": 6,
		"upkeep": 12,
	}
	host.mark_dirty()
	host.log_event(Locale.t("hold_claimed") % city_id)
	return {"ok": true, "city": city_id}

static func apply_month(host) -> String:
	if not owned(host):
		return ""
	var row := seat(host)
	var sil := int(row.get("yield_silver", 0)) - int(row.get("upkeep", 0))
	var food := int(row.get("yield_food", 0))
	host.silver += sil
	host.food += food
	return Locale.t("hold_month") % [sil, food]

static func transfer(host, count: int, to_away: bool) -> Dictionary:
	if not owned(host):
		return {"ok": false, "msg": Locale.t("hold_none")}
	var row := seat(host)
	var n := maxi(0, count)
	if to_away:
		if int(row.get("garrison_home", 0)) < n:
			return {"ok": false, "msg": Locale.t("hold_short")}
		row["garrison_home"] = int(row.garrison_home) - n
		row["garrison_away"] = int(row.garrison_away) + n
	else:
		if int(row.get("garrison_away", 0)) < n:
			return {"ok": false, "msg": Locale.t("hold_short")}
		row["garrison_away"] = int(row.garrison_away) - n
		row["garrison_home"] = int(row.garrison_home) + n
	host.holdings[SEAT] = row
	host.mark_dirty()
	return {"ok": true, "home": int(row.garrison_home), "away": int(row.garrison_away)}
