extends Node
## Fat atlas: enter city → signature arm + regional produce + commission,
## leave → CitySortieModal / HUD → march to the turn-in city → turn in.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const CITY_SCN := preload("res://scenes/hub/city.tscn")
const HOME := "ash_capital"
const DEST := "tide_bridge"
const SIG := "ash_capital_sig1"
const LEGEND := "ash_capital_sig2"
const PRODUCE := "ashsteel"

var _fails: Array = []
var _quest_title := ""
var _quest_id := ""


func _ready() -> void:
	await get_tree().process_frame
	_setup()
	_api_visit_diff()
	_setup()
	await _ui_city_sortie_march_turnin()
	if _fails.is_empty():
		print("ATLAS CITY SORTIE LOOP PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL atlas city sortie: ", f)
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)


func _setup() -> void:
	GameState.new_game("出城备战", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.food = 80
	GameState.silver = 8000
	GameState.morale = 80
	World.hub_tour.clear()
	World.pos = HOME
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.active.clear()
	World.cargo.clear()
	World.cargo_basis.clear()
	World.armory.clear()
	World.done_sig.clear()
	World.city_visit.clear()
	World.last_city_sortie.clear()
	World.last_chain_follow.clear()
	World.arrive(HOME)
	World.rep_city[HOME] = maxi(World.rep_of(HOME), 12)
	for sid in World.list_signature_ids():
		World.mark_smith_revealed(str(sid))
	var q: Dictionary = World.seed_deliver_offer(HOME, DEST)
	q["tier"] = 3
	_quest_id = str(q.get("id", ""))
	_quest_title = str(q.get("title", ""))


func _api_visit_diff() -> void:
	World.begin_city_visit()
	var empty: Dictionary = World.close_city_visit()
	_ok(empty.is_empty(), "empty visit does not raise a sortie")
	World.begin_city_visit()
	World.pos = DEST
	var dropped: Dictionary = World.close_city_visit()
	_ok(dropped.is_empty(), "visit closed away from the city is dropped")
	World.pos = HOME
	World.begin_city_visit()
	var bought: Dictionary = World.buy_item(HOME, SIG)
	_ok(bool(bought.get("ok", false)), "api buy signature: %s" % bought.get("msg", ""))
	var mkt: Dictionary = World.market_buy(HOME, PRODUCE, 1)
	_ok(bool(mkt.get("ok", false)), "api buy produce: %s" % mkt.get("msg", ""))
	var acc: Dictionary = World.accept_quest(HOME, _quest_id)
	_ok(bool(acc.get("ok", false)), "api accept deliver: %s" % acc.get("msg", ""))
	var card: Dictionary = World.close_city_visit()
	_ok(str(card.get("signature_id", "")) == SIG, "sortie signature %s" % card.get("signature_id", ""))
	_ok(str(card.get("signature_name", "")) == "白垣制式长剑", "sortie names the arm")
	_ok(str(card.get("produce_id", "")) == PRODUCE, "sortie produce id")
	_ok(int(card.get("produce_qty", 0)) >= 1, "sortie produce qty")
	_ok(str(card.get("turn_in", "")) == DEST, "turn-in city is tide_bridge")
	_ok(str(card.get("turn_in_name", "")) == "断潮渡哨", "turn-in name readable")
	_ok(str(card.get("quest_title", "")) == _quest_title, "quest title on the card")
	_ok(int(card.get("days", 0)) >= 1, "route days on the card")
	_ok(str(card.get("guide", "")) == DEST, "guide node is the turn-in")
	var hud := World.city_sortie_hud_text()
	_ok(hud.find("白垣制式长剑") >= 0 and hud.find("烬灰钢") >= 0 and hud.find("断潮渡哨") >= 0, "hud text %s" % hud)
	var ash: Array = World.city_signatures(HOME)
	var other: Array = World.city_signatures("sy_capital")
	_ok(ash != other, "signature sets differ across capitals")
	var saved: Dictionary = World.to_save()
	World.from_save(saved)
	_ok(World.last_city_sortie.is_empty(), "sortie card is not a save field")
	World.pos = HOME
	World.active.clear()
	World.armory.clear()
	World.cargo.clear()


func _ui_city_sortie_march_turnin() -> void:
	World.hub_tour.erase(HOME)
	World.begin_city_visit()
	GameState.set_meta("city_id", HOME)
	var city: Control = CITY_SCN.instantiate()
	city.position = Vector2.ZERO
	city.size = Vector2(1280, 720)
	get_tree().root.add_child(city)
	for _i in 8:
		await get_tree().process_frame
	var discover := city.find_child("HubDiscover", true, false)
	_ok(discover != null, "HubDiscover on first visit")
	var goto_smith: Button = city.find_child("GotoHub_smith", true, false) as Button
	_ok(goto_smith != null, "GotoHub_smith")
	if goto_smith:
		goto_smith.pressed.emit()
		for _j in 6:
			await get_tree().process_frame
	_ok(bool(World.hub_tour.get(HOME, {}).get("smith", false)), "opening smith marks the hub seen")
	var reveal: Button = city.find_child("SmithRevealSkip", true, false) as Button
	if reveal:
		reveal.pressed.emit()
		await get_tree().process_frame
	var item_b: Button = city.find_child("Item_" + SIG, true, false) as Button
	_ok(item_b != null, "signature row Item_%s" % SIG)
	if item_b:
		item_b.pressed.emit()
		for _k in 4:
			await get_tree().process_frame
	var buy: Button = city.find_child("BuyItem", true, false) as Button
	_ok(buy != null and not buy.disabled, "BuyItem enabled for signature")
	if buy and not buy.disabled:
		buy.pressed.emit()
		for _n in 6:
			await get_tree().process_frame
	_ok(int(World.armory.get(SIG, 0)) >= 1, "armory holds the signature")
	if city.has_method("_set_tab"):
		city.call("_set_tab", "market")
	for _m in 4:
		await get_tree().process_frame
	var mb: Button = city.find_child("Mkt_%s_买1" % PRODUCE, true, false) as Button
	_ok(mb != null and not mb.disabled, "regional produce buy button")
	var had := World.have_good(PRODUCE)
	if mb and not mb.disabled:
		mb.pressed.emit()
		for _p in 4:
			await get_tree().process_frame
	_ok(World.have_good(PRODUCE) == had + 1, "produce cargo +1")
	if city.has_method("_set_tab"):
		city.call("_set_tab", "board")
	for _q in 4:
		await get_tree().process_frame
	var offer: Button = city.find_child("Offer_" + _quest_id, true, false) as Button
	_ok(offer != null, "seeded offer row")
	if offer:
		offer.pressed.emit()
		for _r in 3:
			await get_tree().process_frame
	var accept: Button = city.find_child("AcceptQuest", true, false) as Button
	_ok(accept != null and not accept.disabled, "AcceptQuest enabled")
	if accept and not accept.disabled:
		accept.pressed.emit()
		for _s in 4:
			await get_tree().process_frame
	_ok(not World.quest_by_id(_quest_id).is_empty(), "commission active")
	city.queue_free()
	await get_tree().process_frame
	var page: Control = ATLAS_SCN.instantiate()
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	get_tree().root.add_child(page)
	var modal: Node = await _wait_named(page, "CitySortieModal", 2000)
	if modal == null and page.has_method("_check_city_sortie"):
		page.call("_check_city_sortie")
		modal = await _wait_named(page, "CitySortieModal", 1000)
	_ok(modal != null, "CitySortieModal after leaving the city")
	if modal == null:
		page.queue_free()
		return
	var sig_l := str(_label_text(page, "CitySortieSig"))
	var prod_l := str(_label_text(page, "CitySortieProduce"))
	var quest_l := str(_label_text(page, "CitySortieQuest"))
	var route_l := str(_label_text(page, "CitySortieRoute"))
	var body_l := str(_label_text(page, "CitySortieBody"))
	_ok(sig_l.find("白垣制式长剑") >= 0, "sig line %s" % sig_l)
	_ok(prod_l.find("烬灰钢") >= 0, "produce line %s" % prod_l)
	_ok(quest_l.find(_quest_title) >= 0 and quest_l.find("断潮渡哨") >= 0, "quest line %s" % quest_l)
	_ok(route_l.find("断潮渡哨") >= 0 and route_l.find("险") >= 0, "route line %s" % route_l)
	_ok(body_l.find("白垣制式长剑") >= 0 and body_l.find("断潮渡哨") >= 0, "body %s" % body_l)
	var hud0 := str(_label_text(page, "CitySortieHud"))
	_ok(hud0.find("烬灰钢") >= 0 and hud0.find("断潮渡哨") >= 0, "garrison hud %s" % hud0)
	var party := str(_label_text(page, "CitySortieParty"))
	_ok(party.find("断潮渡哨") >= 0, "party chip %s" % party)
	var march: Button = page.find_child("CitySortieMarch", true, false) as Button
	_ok(march != null and not march.disabled, "CitySortieMarch enabled")
	var silver0 := GameState.silver
	if march:
		march.pressed.emit()
	var noted: Node = await _wait_named(page, "CommissionMarchNote", 1500)
	_ok(noted != null, "CommissionMarchNote on the route")
	if noted != null:
		var note := str(_label_text(page, "CommissionMarchNote"))
		_ok(note.find(_quest_title) >= 0 and note.find("断潮渡哨") >= 0, "march note %s" % note)
	var event: Node = await _wait_named(page, "EventModal", 8000)
	_ok(event != null, "camp event on the one-day leg")
	if event != null:
		var opt: Button = page.find_child("EventOpt0", true, false) as Button
		_ok(opt != null, "EventOpt0")
		if opt:
			opt.pressed.emit()
		var aft: Node = await _wait_named(page, "AftermathModal", 4000)
		_ok(aft != null, "AftermathModal after camp")
		var cont: Button = page.find_child("AftermathContinue", true, false) as Button
		if cont:
			cont.pressed.emit()
	var turn: Node = await _wait_named(page, "TurnInReadyModal", 8000)
	_ok(turn != null, "TurnInReadyModal at 断潮渡哨")
	_ok(World.pos == DEST, "arrived at turn-in city pos=%s" % World.pos)
	if turn != null:
		var now: Button = page.find_child("TurnInNow", true, false) as Button
		_ok(now != null, "TurnInNow")
		if now:
			now.pressed.emit()
			for _t in 8:
				await get_tree().process_frame
	_ok(World.quest_by_id(_quest_id).is_empty(), "commission cleared")
	_ok(GameState.silver > silver0, "silver increased %d → %d" % [silver0, GameState.silver])
	_ok(World.have_good(PRODUCE) >= 1, "produce still in cargo")
	var done := str(_label_text(page, "CitySortieHud"))
	_ok(done.find(_quest_title) >= 0, "hud shows the turned-in commission %s" % done)
	var dismiss: Button = page.find_child("CitySortieDismiss", true, false) as Button
	_ok(dismiss != null, "CitySortieDismiss after turn-in")
	if dismiss:
		dismiss.pressed.emit()
		for _u in 4:
			await get_tree().process_frame
	_ok(page.find_child("CitySortieHud", true, false) == null, "hud sortie cleared")
	var locked := true
	for e in World.smith_stock(HOME):
		if str(e.item.id) == LEGEND:
			locked = not bool(e.get("available", false))
	_ok(locked, "legendary stays locked without the honor commission")
	page.queue_free()
	await get_tree().process_frame


func _label_text(page: Node, node_name: String) -> String:
	var n := page.find_child(node_name, true, false)
	if n is Label:
		return str((n as Label).text)
	return ""


func _wait_named(page: Node, node_name: String, ms: int) -> Node:
	var until := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		var n := page.find_child(node_name, true, false)
		if n != null:
			return n
		await get_tree().process_frame
	return null
