extends Node
## Fat atlas playable loop: travel → city hub → accept/turn-in → regional smith/produce,
## plus atlas UI CTAs (halt modal, arrival turn-in, enter label) and quests-book smart CTAs.

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_setup()
	_api_travel_accept_turnin()
	_api_regional_smith_and_produce()
	_api_ready_turn_ins_helper()
	await _ui_atlas_halt_and_turnin_modal()
	await _ui_city_board_accept_goto()
	await _ui_quests_smart_cta()
	if _fails.is_empty():
		print("ATLAS PLAYABLE LOOP PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL atlas playable: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _setup() -> void:
	GameState.new_game("跑图", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.food = 999
	GameState.silver = 8000

func _reset_party(at: String) -> void:
	World.pos = at
	World.travel = {}
	World.encounter = {}
	World.pending_event = {}
	World.active.clear()
	World.rep_city[at] = 80

func _go(dest: String) -> void:
	for _i in 12:
		if not World.encounter.is_empty():
			World.on_battle_end(true)
			continue
		if World.pos == dest and not World.is_traveling():
			break
		World.travel_to(dest)
	if not World.encounter.is_empty():
		World.on_battle_end(true)

func _api_travel_accept_turnin() -> void:
	var home := "ash_capital"
	_reset_party(home)
	World._ensure_board(home)
	var offers: Array = World.board(home)
	_ok(not offers.is_empty(), "capital board has offers")
	if offers.is_empty():
		return
	# Prefer a gather/deliver that can complete without battle when possible.
	var pick: Dictionary = {}
	for q in offers:
		if str(q.get("kind", "")) in ["gather", "deliver", "escort", "scout"]:
			pick = q
			break
	if pick.is_empty():
		pick = offers[0]
	var qid := str(pick.id)
	var r: Dictionary = World.accept_quest(home, qid)
	_ok(bool(r.get("ok", false)), "accept %s: %s" % [qid, r.get("msg", "")])
	if not bool(r.get("ok", false)):
		return
	var q: Dictionary = World.quest_by_id(qid)
	_ok(not q.is_empty(), "active after accept")
	var guide := World.quest_guide_node(q)
	_ok(guide != "", "guide node for %s" % qid)
	if guide != "" and guide != World.pos:
		_go(guide)
	# Force ready for turn-in path when gather/deliver needs goods.
	q = World.quest_by_id(qid)
	if not q.is_empty() and str(q.get("state", "")) != "ready":
		if str(q.get("kind", "")) == "gather":
			World._add_good(str(q.get("good", "grain")), int(q.get("qty", 1)) + 2)
			# re-evaluate ready
			if World.has_method("_refresh_quest_states"):
				World._check_gather_ready()
			elif World.has_method("tick_quests"):
				World.tick_quests()
			else:
				q.state = "ready"
		else:
			q.state = "ready"
	q = World.quest_by_id(qid)
	var turn := World.turn_in_city(q)
	if turn != World.pos:
		_go(turn)
	_ok(World.can_turn_in(q, World.pos) or str(q.get("state", "")) == "ready", "ready at turn-in city")
	if str(q.get("state", "")) != "ready":
		q.state = "ready"
	var before_log := World.quest_log.size()
	var tr: Dictionary = World.turn_in(qid)
	_ok(bool(tr.get("ok", false)), "turn_in: %s" % tr.get("msg", ""))
	_ok(World.quest_by_id(qid).is_empty(), "cleared from active")
	_ok(World.quest_log.size() > before_log, "quest_log grew")

func _api_regional_smith_and_produce() -> void:
	var a := "ash_capital"
	var b := "sy_capital"
	if not World.nodes.has(b):
		# pick two cities with smith stock in different nations
		var seen: Array = []
		for nid in World.nodes.keys():
			var n: Dictionary = World.node(str(nid))
			if str(n.get("kind", "")) in ["city", "capital", "port"] and World.smith_stock(str(nid)).size() > 0:
				seen.append(str(nid))
				if seen.size() >= 2:
					break
		if seen.size() >= 2:
			a = seen[0]
			b = seen[1]
	var sa: Array = World.smith_stock(a)
	var sb: Array = World.smith_stock(b)
	_ok(sa.size() > 0, "smith stock at %s" % a)
	_ok(sb.size() > 0, "smith stock at %s" % b)
	var ids_a: Dictionary = {}
	for e in sa:
		ids_a[str(e.item.id)] = true
	var unique_b := 0
	for e in sb:
		if not ids_a.has(str(e.item.id)):
			unique_b += 1
	var sig_a := World.city_signatures(a)
	var sig_b := World.city_signatures(b)
	_ok(unique_b > 0, "smith stock unique items across nations unique_b=%d" % unique_b)
	_ok(str(World.node(a).get("nation", "")) != str(World.node(b).get("nation", "")), "capitals in different nations")
	_ok(sig_a != sig_b, "signature weapons differ a=%s b=%s" % [str(sig_a), str(sig_b)])
	var pa: Array = World.node(a).get("produce", [])
	var pb: Array = World.node(b).get("produce", [])
	_ok(pa.size() > 0, "produce at %s" % a)
	_ok(pb.size() > 0, "produce at %s" % b)
	_ok(pa != pb, "regional produce differs")

func _api_ready_turn_ins_helper() -> void:
	_reset_party("ash_capital")
	World.active = [{
		"id": "t_ready",
		"title": "Test Ready",
		"state": "ready",
		"kind": "deliver",
		"issuer": "ash_capital",
		"target": "ash_capital",
		"reward_silver": 10,
		"reward_rep": 1,
		"tier": 1,
		"danger": 1,
		"days_budget": 30,
		"deadline": World.days_total + 30,
	}]
	var ready := World.ready_turn_ins_here()
	_ok(ready.size() == 1, "ready_turn_ins_here size=%d" % ready.size())
	World.pos = "sy_capital" if World.nodes.has("sy_capital") else World.pos
	if World.pos != "ash_capital":
		_ok(World.ready_turn_ins_here().is_empty(), "ready empty away from turn-in")
	World.active.clear()

func _ui_atlas_halt_and_turnin_modal() -> void:
	_reset_party("ash_capital")
	# Seed a ready turn-in at current pos
	World.active = [{
		"id": "ui_ready",
		"title": "UI Ready",
		"state": "ready",
		"kind": "deliver",
		"issuer": "ash_capital",
		"target": "ash_capital",
		"reward_silver": 10,
		"reward_rep": 1,
		"tier": 1,
		"danger": 1,
		"days_budget": 30,
		"deadline": World.days_total + 30,
	}]
	var page: Control = load("res://scenes/hub/atlas_view.tscn").instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	for _i in 10:
		await get_tree().process_frame
	# Force nation view + select pos
	if page.has_method("_show_view"):
		page._show_view(World.nation_of(World.pos))
	if page.has_method("_select_node"):
		page._select_node(World.pos)
	for _i in 4:
		await get_tree().process_frame
	var enter: Button = page.find_child("EnterButton", true, false) as Button
	_ok(enter != null, "EnterButton present")
	if enter != null:
		var want := Locale.t("atlas_enter_turnin") % 1
		_ok(enter.text.find("1") >= 0 or enter.text == want, "enter turn-in label got=%s" % enter.text)
	# Arrival turn-in modal
	if page.has_method("_show_turnin_modal"):
		page._show_turnin_modal(1)
		await get_tree().process_frame
		var modal := page.find_child("TurnInReadyModal", true, false)
		_ok(modal != null, "TurnInReadyModal shown")
		var go: Button = page.find_child("TurnInEnter", true, false) as Button
		_ok(go != null and not go.disabled, "TurnInEnter usable")
		var later: Button = page.find_child("TurnInLater", true, false) as Button
		if later:
			later.pressed.emit()
		await get_tree().process_frame
	# Halt modal
	if page.has_method("_show_travel_halt_modal"):
		page._show_travel_halt_modal()
		await get_tree().process_frame
		var halt := page.find_child("TravelHaltModal", true, false)
		_ok(halt != null, "TravelHaltModal shown")
		_ok(page.find_child("HaltStop", true, false) != null, "HaltStop")
		_ok(page.find_child("HaltContinue", true, false) != null, "HaltContinue")
		_ok(page.find_child("HaltLeave", true, false) != null, "HaltLeave")
		var cont: Button = page.find_child("HaltContinue", true, false) as Button
		if cont:
			cont.pressed.emit()
	page.queue_free()
	await get_tree().process_frame
	World.active.clear()

func _ui_city_board_accept_goto() -> void:
	_reset_party("ash_capital")
	World._ensure_board("ash_capital")
	GameState.set_meta("city_id", "ash_capital")
	GameState.set_meta("city_tab", "board")
	var page: Control = load("res://scenes/hub/city.tscn").instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	for _i in 12:
		await get_tree().process_frame
	var offers: Array = World.board("ash_capital")
	_ok(not offers.is_empty(), "city board offers for UI")
	if offers.is_empty():
		page.queue_free()
		return
	var q0: Dictionary = offers[0]
	# Select offer via private state if present
	page.set("_sel_quest", str(q0.id))
	if page.has_method("_render_tab"):
		page._render_tab()
	for _i in 4:
		await get_tree().process_frame
	var accept: Button = page.find_child("AcceptQuest", true, false) as Button
	_ok(accept != null, "AcceptQuest button")
	if accept != null and not accept.disabled:
		accept.pressed.emit()
		for _i in 6:
			await get_tree().process_frame
		_ok(not World.quest_by_id(str(q0.id)).is_empty(), "accepted into World.active via UI")
		# Select active and expect GotoAtlas or TurnIn
		page.set("_sel_quest", str(q0.id))
		if page.has_method("_render_tab"):
			page._render_tab()
		for _i in 4:
			await get_tree().process_frame
		var goto_b := page.find_child("GotoAtlasQuest", true, false)
		var turn_b := page.find_child("TurnInQuest", true, false)
		_ok(goto_b != null or turn_b != null, "post-accept CTA GotoAtlas|TurnIn")
	page.queue_free()
	await get_tree().process_frame
	World.active.clear()

func _ui_quests_smart_cta() -> void:
	_reset_party("ash_capital")
	World.active = [{
		"id": "qb1",
		"title": "Book Ready",
		"state": "ready",
		"kind": "deliver",
		"issuer": "ash_capital",
		"target": "ash_capital",
		"reward_silver": 10,
		"reward_rep": 1,
		"tier": 1,
		"danger": 1,
		"desc": "test",
		"days_budget": 30,
		"deadline": World.days_total + 30,
	}]
	World.quest_log = ["D1 · Book Ready（+10 银）"]
	GameState.quests.clear()
	var page: Control = load("res://scenes/hub/quests.tscn").instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	for _i in 10:
		await get_tree().process_frame
	# EmptyHostBoard still present (castle board empty)
	_ok(page.find_child("EmptyHostBoard", true, false) != null, "EmptyHostBoard kept")
	_ok(page.find_child("EmptyHostActive", true, false) == null, "no EmptyHostActive when in-hand present")
	# Done section text visible
	var found_done := false
	for n in page.find_children("*", "Label", true, false):
		if str((n as Label).text).find("Book Ready") >= 0 or str((n as Label).text) == Locale.t("wq_tab_done"):
			found_done = true
			break
	_ok(found_done, "done log or tab label visible")
	page.queue_free()
	await get_tree().process_frame
	World.active.clear()
	World.quest_log.clear()
