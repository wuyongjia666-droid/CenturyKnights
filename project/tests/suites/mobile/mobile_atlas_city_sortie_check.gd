extends Node
## Mobile E2E: city signature + produce + commission, then CitySortieModal HUD.

const PHONE := Vector2i(2400, 1080)
const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const CITY_SCN := preload("res://scenes/hub/city.tscn")
const HOME := "ash_capital"
const DEST := "tide_bridge"
const SIG := "ash_capital_sig1"
const PRODUCE := "ashsteel"


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile atlas city sortie: ", err)
		get_tree().quit(1)
	else:
		print("MOBILE ATLAS CITY SORTIE PASS")
		get_tree().quit(0)


func _run() -> String:
	var err := ""
	if not DeviceProfile.is_mobile():
		err = "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	if err == "":
		await _set_phone_window()
		_boot()
		err = await _city_loop()
	var page: Control = null
	if err == "":
		page = ATLAS_SCN.instantiate()
		page.size = Vector2(1280, 720)
		get_tree().root.add_child(page)
		err = await _assert_sortie(page)
		page.queue_free()
	return err


func _city_loop() -> String:
	World.begin_city_visit()
	GameState.set_meta("city_id", HOME)
	var city: Control = CITY_SCN.instantiate()
	city.size = Vector2(1280, 720)
	get_tree().root.add_child(city)
	var err := ""
	for _i in 10:
		await get_tree().process_frame
	var goto_smith: Button = city.find_child("GotoHub_smith", true, false) as Button
	if goto_smith == null:
		err = "GotoHub_smith missing"
	else:
		goto_smith.pressed.emit()
		for _j in 6:
			await get_tree().process_frame
	if err == "":
		var reveal: Button = city.find_child("SmithRevealSkip", true, false) as Button
		if reveal:
			reveal.pressed.emit()
			await get_tree().process_frame
		var item_b: Button = city.find_child("Item_" + SIG, true, false) as Button
		if item_b == null:
			err = "signature row missing"
		else:
			item_b.pressed.emit()
			for _k in 4:
				await get_tree().process_frame
	if err == "":
		var buy: Button = city.find_child("BuyItem", true, false) as Button
		if buy == null or buy.disabled:
			err = "BuyItem missing or disabled"
		else:
			buy.pressed.emit()
			for _n in 6:
				await get_tree().process_frame
			if int(World.armory.get(SIG, 0)) < 1:
				err = "signature not bought"
	if err == "":
		if city.has_method("_set_tab"):
			city.call("_set_tab", "market")
		for _m in 4:
			await get_tree().process_frame
		var mb: Button = city.find_child("Mkt_%s_买1" % PRODUCE, true, false) as Button
		if mb == null or mb.disabled:
			err = "produce buy missing"
		else:
			mb.pressed.emit()
			for _p in 4:
				await get_tree().process_frame
			if World.have_good(PRODUCE) < 1:
				err = "produce not in cargo"
	if err == "":
		if city.has_method("_set_tab"):
			city.call("_set_tab", "board")
		for _q in 4:
			await get_tree().process_frame
		var offer: Button = city.find_child("Offer_" + _qid(), true, false) as Button
		if offer == null:
			err = "offer row missing"
		else:
			offer.pressed.emit()
			for _r in 3:
				await get_tree().process_frame
			var accept: Button = city.find_child("AcceptQuest", true, false) as Button
			if accept == null or accept.disabled:
				err = "AcceptQuest missing"
			else:
				accept.pressed.emit()
				for _s in 4:
					await get_tree().process_frame
	city.queue_free()
	await get_tree().process_frame
	return err


func _assert_sortie(page: Control) -> String:
	var modal: Node = await _wait_named(page, "CitySortieModal", 2500)
	if modal == null and page.has_method("_check_city_sortie"):
		page.call("_check_city_sortie")
		modal = await _wait_named(page, "CitySortieModal", 1000)
	if modal == null:
		return "CitySortieModal missing"
	var sig_l := _label(page, "CitySortieSig")
	var prod_l := _label(page, "CitySortieProduce")
	var quest_l := _label(page, "CitySortieQuest")
	var err := ""
	if sig_l.find("白垣制式长剑") < 0:
		err = "sig line unreadable: %s" % sig_l
	elif prod_l.find("烬灰钢") < 0:
		err = "produce line unreadable: %s" % prod_l
	elif quest_l.find("断潮渡哨") < 0:
		err = "turn-in city unreadable: %s" % quest_l
	if err == "":
		var later: Button = page.find_child("CitySortieLater", true, false) as Button
		if later == null:
			err = "CitySortieLater missing"
		else:
			later.pressed.emit()
			for _t in 6:
				await get_tree().process_frame
	if err == "" and page.find_child("CitySortieModal", true, false) != null:
		err = "modal still open"
	if err == "":
		var hud := _label(page, "CitySortieHud")
		if hud.find("白垣制式长剑") < 0 or hud.find("断潮渡哨") < 0:
			err = "mobile hud unreadable: %s" % hud
	if err == "":
		var go: Button = page.find_child("CitySortieGo", true, false) as Button
		if go == null or go.disabled:
			err = "CitySortieGo missing"
	return err


func _qid() -> String:
	for q in World.board(HOME):
		if str(q.get("target", "")) == DEST and str(q.get("kind", "")) == "deliver":
			return str(q.get("id", ""))
	return ""


func _boot() -> void:
	GameState.new_game("手机出城", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.food = 80
	GameState.silver = 8000
	World.hub_tour.clear()
	World.pos = HOME
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.active.clear()
	World.cargo.clear()
	World.armory.clear()
	World.city_visit.clear()
	World.last_city_sortie.clear()
	World.arrive(HOME)
	World.rep_city[HOME] = maxi(World.rep_of(HOME), 12)
	for sid in World.list_signature_ids():
		World.mark_smith_revealed(str(sid))
	var q: Dictionary = World.seed_deliver_offer(HOME, DEST)
	q["tier"] = 3


func _set_phone_window() -> void:
	DisplayServer.window_set_size(PHONE)
	get_tree().root.content_scale_size = PHONE
	await get_tree().process_frame


func _label(page: Node, node_name: String) -> String:
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
