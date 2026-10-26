class_name CKCitySpecialty
extends RefCounted
## Regional specialty crate: resolve the city affair, pack the city's produce, walk it on the atlas,
## deliver at the nearest city that demands that good. Flag + silver + reputation + a cargo gift.
## The crate id is spec_<city> so it does not count as a market produce buy (no CitySortie).

const RUN_KEY := "specialty_run"
const TAKE_SILVER := 8
const PAY_SILVER := 24
const REP_DEST := 4
const REP_FROM := 2
const QTY := 1
const REWARD_QTY := 1
const _REWARD_PREFER: Array[String] = ["silk", "tea", "spice", "fur", "jade", "saltcrystal"]


static func flag_key(city: String) -> String:
	return "spec_done_%s" % city


static func parcel_id(city: String) -> String:
	return "spec_%s" % city


static func done(city: String) -> bool:
	return bool(GameState.story.flags.get(flag_key(city), false))


static func run() -> Dictionary:
	var raw = GameState.story.flags.get(RUN_KEY, {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	return raw


static func good_id(city: String) -> String:
	var picked := ""
	for g in World.node(city).get("produce", []):
		var gs := str(g)
		if picked == "":
			picked = gs
		if str(World.goods.get(gs, {}).get("store", "")) == "":
			return gs
	return picked


static func flavor(city: String) -> String:
	var raw := str(World.node(city).get("specialty", ""))
	var head := str(raw.split("·")[0]).strip_edges()
	if head != "":
		return head
	var gid := good_id(city)
	return World.good_name(gid) if gid != "" else raw


static func dest_for(city: String) -> String:
	var good := good_id(city)
	if good == "" or not World.nodes.has(city):
		return ""
	var best := ""
	var best_days := 1 << 30
	for id in World.nodes.keys():
		var nid := str(id)
		if nid == city or not _demands(nid, good):
			continue
		var rt: Dictionary = World.route(city, nid)
		if rt.is_empty():
			continue
		var days := int(rt.get("days", 1 << 30))
		if days < best_days or (days == best_days and (best == "" or nid < best)):
			best = nid
			best_days = days
	return best


static func hud_text() -> String:
	var r := run()
	if r.is_empty():
		return ""
	var good := World.good_name(str(r.get("good", "")))
	var dest := str(World.node(str(r.get("to", ""))).get("name", r.get("to", "")))
	return Locale.t("spec_hud") % [good, dest]


static func card(city: String) -> Dictionary:
	var head := Locale.t("spec_head")
	var empty := {
		"head": head,
		"body": "",
		"cost": "",
		"pay": "",
		"hold": "",
		"action": Locale.t("spec_locked_btn"),
		"enabled": false,
		"why": "",
		"phase": "locked",
	}
	if city == "" or World.node(city).is_empty():
		empty["why"] = Locale.t("spec_not_here")
		empty["body"] = empty["why"]
		return empty
	if done(city) and run().is_empty():
		empty["phase"] = "done"
		empty["body"] = Locale.t("spec_done_body")
		empty["action"] = Locale.t("spec_done_btn")
		empty["why"] = Locale.t("spec_repeat")
		return empty
	var active := run()
	if not active.is_empty():
		return _carry_card(city, active, head)
	var good := good_id(city)
	var dest := dest_for(city)
	var gname := World.good_name(good) if good != "" else ""
	var dname := str(World.node(dest).get("name", dest)) if dest != "" else ""
	var body := ""
	if good != "" and dest != "":
		body = Locale.t("spec_take_body") % [flavor(city), gname, QTY, dname]
	elif good == "":
		body = Locale.t("spec_no_dest")
	else:
		body = Locale.t("spec_no_dest")
	var base := {
		"head": head,
		"body": body,
		"cost": Locale.t("spec_take_cost") % TAKE_SILVER if dest != "" else "",
		"pay": _pay_line(dest) if dest != "" else "",
		"hold": "",
		"action": Locale.t("spec_take_btn"),
		"enabled": false,
		"why": "",
		"phase": "take",
	}
	if not CKCityAffairs.done(city):
		base["phase"] = "need_affair"
		base["why"] = Locale.t("spec_need_affair")
		base["action"] = Locale.t("spec_locked_btn")
		return base
	var gate := _take_gate(city, good, dest)
	if not bool(gate.get("ok", false)):
		base["phase"] = "blocked"
		base["why"] = str(gate.get("msg", ""))
		base["action"] = Locale.t("spec_locked_btn")
		return base
	base["enabled"] = true
	return base


static func act(city: String) -> Dictionary:
	var info := card(city)
	var phase := str(info.get("phase", ""))
	if phase == "take" and bool(info.get("enabled", false)):
		return _take(city)
	if phase == "deliver" and bool(info.get("enabled", false)):
		return _deliver()
	var why := str(info.get("why", ""))
	if why == "":
		why = str(info.get("body", ""))
	return {"ok": false, "msg": why, "phase": phase}


static func _carry_card(city: String, active: Dictionary, head: String) -> Dictionary:
	var dest := str(active.get("to", ""))
	var origin := str(active.get("from", ""))
	var gname := World.good_name(str(active.get("good", "")))
	var dname := str(World.node(dest).get("name", dest))
	var oname := str(World.node(origin).get("name", origin))
	var hold := Locale.t("spec_hold") % [gname, _held(origin)]
	var here := World.pos == dest and city == dest
	if here:
		var missing := _held(origin) < int(active.get("qty", QTY))
		return {
			"head": head,
			"body": Locale.t("spec_deliver_body") % [oname, gname],
			"cost": "",
			"pay": _pay_line(dest, active),
			"hold": hold,
			"action": Locale.t("spec_deliver_btn"),
			"enabled": not missing,
			"why": Locale.t("spec_hold_empty") if missing else "",
			"phase": "deliver",
		}
	return {
		"head": head,
		"body": Locale.t("spec_carry_away") % [gname, dname],
		"cost": "",
		"pay": _pay_line(dest, active),
		"hold": hold,
		"action": Locale.t("spec_deliver_btn"),
		"enabled": false,
		"why": Locale.t("spec_carry_away") % [gname, dname],
		"phase": "carrying",
	}


static func _take_gate(city: String, good: String, dest: String) -> Dictionary:
	if city == "" or World.pos != city or World.node(city).is_empty():
		return {"ok": false, "msg": Locale.t("spec_not_here")}
	if done(city):
		return {"ok": false, "msg": Locale.t("spec_repeat")}
	if not run().is_empty():
		var dest_name := str(World.node(str(run().get("to", ""))).get("name", ""))
		return {"ok": false, "msg": Locale.t("spec_busy") % dest_name}
	if not CKCityAffairs.done(city):
		return {"ok": false, "msg": Locale.t("spec_need_affair")}
	if good == "" or dest == "":
		return {"ok": false, "msg": Locale.t("spec_no_dest")}
	if GameState.silver < TAKE_SILVER:
		return {"ok": false, "msg": Locale.t("spec_no_silver") % [TAKE_SILVER, int(GameState.silver)]}
	if World.cargo_used() + QTY > World.cargo_cap():
		return {"ok": false, "msg": Locale.t("spec_cargo_full") % [World.cargo_used(), World.cargo_cap()]}
	return {"ok": true, "msg": ""}


static func _take(city: String) -> Dictionary:
	var good := good_id(city)
	var dest := dest_for(city)
	var gate := _take_gate(city, good, dest)
	if not bool(gate.get("ok", false)):
		return gate
	var reward := _reward_good(dest)
	GameState.silver -= TAKE_SILVER
	_cargo_add(parcel_id(city), QTY)
	GameState.story.flags[RUN_KEY] = {
		"from": city,
		"to": dest,
		"good": good,
		"qty": QTY,
		"reward": reward,
		"reward_qty": REWARD_QTY if reward != "" else 0,
		"pay_silver": PAY_SILVER,
		"rep_to": REP_DEST,
		"rep_from": REP_FROM,
	}
	var cname := str(World.node(city).get("name", city))
	var dname := str(World.node(dest).get("name", dest))
	var gname := World.good_name(good)
	CKEconomyState.month_echo_note(
		"produce",
		Locale.t("atlas_produce_echo_specialty_take") % [cname, gname, QTY, TAKE_SILVER, dname]
	)
	GameState.mark_dirty()
	World.world_changed.emit()
	return {
		"ok": true,
		"phase": "carrying",
		"msg": Locale.t("spec_took") % [gname, QTY, dname, TAKE_SILVER],
	}


static func _deliver() -> Dictionary:
	var active := run()
	if active.is_empty():
		return {"ok": false, "msg": Locale.t("spec_repeat")}
	var origin := str(active.get("from", ""))
	var dest := str(active.get("to", ""))
	if World.pos != dest:
		var dname := str(World.node(dest).get("name", dest))
		return {"ok": false, "msg": Locale.t("spec_carry_away") % [World.good_name(str(active.get("good", ""))), dname]}
	var qty := int(active.get("qty", QTY))
	if _held(origin) < qty:
		return {"ok": false, "msg": Locale.t("spec_hold_empty")}
	_cargo_add(parcel_id(origin), -qty)
	var pay := int(active.get("pay_silver", PAY_SILVER))
	var rep_to := int(active.get("rep_to", REP_DEST))
	var rep_from := int(active.get("rep_from", REP_FROM))
	GameState.silver += pay
	World.add_city_rep(dest, rep_to)
	if origin != "" and origin != dest:
		World.add_city_rep(origin, rep_from)
	GameState.set_flag(flag_key(origin), true)
	var reward := str(active.get("reward", ""))
	var rq := int(active.get("reward_qty", 0))
	var gifted := false
	if reward != "" and rq > 0 and World.cargo_used() + rq <= World.cargo_cap():
		_cargo_add(reward, rq)
		gifted = true
	GameState.story.flags.erase(RUN_KEY)
	var oname := str(World.node(origin).get("name", origin))
	var gname := World.good_name(str(active.get("good", "")))
	var city_name := str(World.node(dest).get("name", dest))
	CKEconomyState.month_echo_note(
		"produce",
		Locale.t("atlas_produce_echo_specialty_deliver") % [city_name, gname, pay, oname]
	)
	GameState.mark_dirty()
	World.world_changed.emit()
	if gifted:
		return {
			"ok": true,
			"phase": "done",
			"msg": Locale.t("spec_delivered") % [city_name, gname, pay, city_name, rep_to, World.good_name(reward), rq],
		}
	return {
		"ok": true,
		"phase": "done",
		"msg": Locale.t("spec_delivered_nospace") % [city_name, gname, pay, city_name, rep_to],
		"skipped_reward": true,
		"from_name": oname,
	}


static func _pay_line(dest: String, active: Dictionary = {}) -> String:
	var pay := int(active.get("pay_silver", PAY_SILVER)) if not active.is_empty() else PAY_SILVER
	var rep_to := int(active.get("rep_to", REP_DEST)) if not active.is_empty() else REP_DEST
	var reward := str(active.get("reward", "")) if not active.is_empty() else _reward_good(dest)
	var rq := int(active.get("reward_qty", REWARD_QTY)) if not active.is_empty() else REWARD_QTY
	var dname := str(World.node(dest).get("name", dest))
	if reward == "" or rq <= 0:
		return Locale.t("spec_pay_plain") % [pay, dname, rep_to]
	return Locale.t("spec_deliver_pay") % [pay, dname, rep_to, World.good_name(reward), rq]


static func _reward_good(dest: String) -> String:
	var produced: Array = World.node(dest).get("produce", [])
	for g in _REWARD_PREFER:
		if not World.goods.has(g):
			continue
		if str(g) in produced:
			continue
		if str(World.goods.get(g, {}).get("store", "")) != "":
			continue
		return str(g)
	return ""


static func _demands(city: String, good: String) -> bool:
	for g in World.node(city).get("demand", []):
		if str(g) == good:
			return true
	return false


static func _held(origin: String) -> int:
	return int(World.cargo.get(parcel_id(origin), 0))


static func _cargo_add(g: String, q: int) -> void:
	var next := int(World.cargo.get(g, 0)) + q
	if next <= 0:
		World.cargo.erase(g)
	else:
		World.cargo[g] = next
