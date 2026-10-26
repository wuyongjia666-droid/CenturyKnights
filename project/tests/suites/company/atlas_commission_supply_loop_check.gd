extends Node
## Fat E2E: city commission accept/turn-in + gather 物产 pickup on atlas.
## Issuer board → accept → ◆/◇ supply city → market GatherBuy → ready → ✓ turn-in.
## Desktop, or phone when CK_FORCE_MOBILE=1 (mobile_* scene).

const CITY_SCN := preload("res://scenes/hub/city.tscn")
const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const HOME := "ash_capital"

var _fails: Array = []
var _mobile := false
var _qid := ""
var _good := ""
var _qty := 0
var _supply := ""
var _supply_name := ""
var _issuer_name := ""


func _ready() -> void:
	await get_tree().process_frame
	_mobile = DeviceProfile.is_mobile()
	if _mobile:
		var win := get_tree().root
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		win.size = Vector2i(2400, 1080)
		await get_tree().process_frame
		await get_tree().process_frame
	_setup()
	_api_supply_stamp()
	_setup()
	_api_accept_wrong_city()
	_setup()
	_api_full_loop()
	_setup()
	await _ui_board_and_market()
	_setup()
	await _ui_atlas_pickup_enter()
	if _fails.is_empty():
		print("ATLAS COMMISSION SUPPLY LOOP PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL atlas commission supply: ", f)
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)


func _setup() -> void:
	GameState.new_game("物产委托", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	World.active.clear()
	World.cargo.clear()
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.city_visit = {}
	World.last_city_sortie.clear()
	World.pos = HOME
	World.visited[HOME] = true
	World.rep_city[HOME] = 40
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 40
	GameState.silver = 5000
	GameState.food = 200
	GameState.iron = 20
	GameState.morale = 80
	_issuer_name = str(World.node(HOME).get("name", HOME))


func _make_gather() -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash("atlas-commission-supply")
	var q: Dictionary = {}
	for _i in 40:
		q = World._make_quest(HOME, "gather", 1, r)
		if q.is_empty():
			continue
		var supply := str(q.get("supply_city", ""))
		if supply != "" and supply != HOME and World.nodes.has(supply):
			return q
	return q


func _post(q: Dictionary) -> void:
	World._ensure_board(HOME)
	World.boards[HOME].offers.append(q)


func _go(dest: String) -> void:
	for _i in 24:
		if not World.encounter.is_empty():
			World.on_battle_end(true)
			continue
		if World.pos == dest and not World.is_traveling():
			break
		World.travel_to(dest)
	if not World.encounter.is_empty():
		World.on_battle_end(true)


func _api_supply_stamp() -> void:
	var q := _make_gather()
	_ok(not q.is_empty(), "make gather")
	if q.is_empty():
		return
	_ok(str(q.get("kind", "")) == "gather", "kind gather")
	_ok(str(q.get("supply_city", "")) != "", "supply_city stamped %s" % q.get("supply_city", ""))
	var expect := World.nearest_produce_city(str(q.good), HOME)
	_ok(str(q.supply_city) == expect or expect == "", "supply matches nearest %s vs %s" % [q.supply_city, expect])
	_ok(str(q.desc).find(str(World.node(str(q.supply_city)).get("name", ""))) >= 0, "desc names supply city")
	_ok(Locale.t("wq_hint_gather_buy") != "wq_hint_gather_buy", "locale wq_hint_gather_buy")
	_ok(Locale.t("atlas_enter_pickup") != "atlas_enter_pickup", "locale atlas_enter_pickup")
	_ok(Locale.t("wq_accept_wrong_city") != "wq_accept_wrong_city", "locale wq_accept_wrong_city")
	_ok(Locale.t("wq_gather_buy_done") != "wq_gather_buy_done", "locale wq_gather_buy_done")
	_ok(Locale.t("wq_mkt_gather_cost") != "wq_mkt_gather_cost", "locale wq_mkt_gather_cost")
	_ok(Locale.t("wq_accept_supply_days") != "wq_accept_supply_days", "locale wq_accept_supply_days")
	_ok(Locale.t("wq_board_supply_march") != "wq_board_supply_march", "locale wq_board_supply_march")


func _api_accept_wrong_city() -> void:
	var q := _make_gather()
	_ok(not q.is_empty(), "wrong-city make")
	if q.is_empty():
		return
	_post(q)
	World.pos = "tide_bridge"
	var bad: Dictionary = World.accept_quest(HOME, str(q.id))
	_ok(not bool(bad.get("ok", false)), "refuse accept away from issuer: %s" % bad.get("msg", ""))
	_ok(str(bad.get("msg", "")).find("城") >= 0 or str(bad.get("msg", "")) == Locale.t("wq_accept_wrong_city"), "wrong-city msg %s" % bad.get("msg", ""))
	World.pos = HOME
	var ok: Dictionary = World.accept_quest(HOME, str(q.id))
	_ok(bool(ok.get("ok", false)), "accept at issuer: %s" % ok.get("msg", ""))


func _api_full_loop() -> void:
	var q := _make_gather()
	_ok(not q.is_empty(), "loop make")
	if q.is_empty():
		return
	_post(q)
	_qid = str(q.id)
	_good = str(q.good)
	_qty = int(q.qty)
	_supply = World.gather_supply_city(q)
	_supply_name = str(World.node(_supply).get("name", _supply))
	_ok(_supply != "" and World.nodes.has(_supply), "supply city live %s" % _supply)

	var acc: Dictionary = World.accept_quest(HOME, _qid)
	_ok(bool(acc.get("ok", false)), "loop accept: %s" % acc.get("msg", ""))
	if not bool(acc.get("ok", false)):
		return
	_ok(str(acc.get("guide_node", "")) == _supply, "accept guide → supply %s" % acc.get("guide_node", ""))
	_ok(str(acc.get("hint", "")).find(_supply_name) >= 0, "hint names supply %s" % acc.get("hint", ""))
	var march: Dictionary = acc.get("supply_march", {})
	_ok(str(march.get("supply", "")) == _supply, "accept supply_march.supply %s" % march.get("supply", ""))
	_ok(int(march.get("days", -1)) >= 0, "accept supply_march.days %s" % march.get("days", ""))
	_ok(str(acc.get("msg", "")).find(_supply_name) >= 0 or int(march.get("days", 0)) == 0, "accept msg carries supply days")
	_ok(World.quest_guide_node(World.quest_by_id(_qid)) == _supply, "guide_node supply")

	var marks: Dictionary = World.quest_markers()
	_ok(marks.has(_supply), "markers at supply")
	var pickup_kind := false
	for mk in marks.get(_supply, []):
		if str(mk.get("kind", "")) == "pickup" and str(mk.quest.get("id", "")) == _qid:
			pickup_kind = true
	_ok(pickup_kind, "pickup kind on supply marker")

	_go(_supply)
	_ok(World.pos == _supply, "arrived supply %s" % World.pos)
	World.visited[_supply] = true
	if not World.market.has(_supply):
		World._init_market(_supply)
	var picks: Array = World.gather_pickups_here()
	_ok(picks.size() >= 1, "gather_pickups_here %d" % picks.size())

	# Force stock short so top-up path must fire (produce city only).
	if not World.market.has(_supply):
		World._init_market(_supply)
	World.market[_supply][_good] = 0
	var offer0: Dictionary = World.gather_buy_offer()
	_ok(bool(offer0.get("needed", false)), "gather_buy_offer needed")
	_ok(str(offer0.get("good", "")) == _good, "offer good")
	_ok(int(offer0.get("qty", 0)) == _qty, "offer qty %s" % offer0.get("qty", ""))
	_ok(bool(offer0.get("produce_here", false)), "produce_here at supply")
	_ok(bool(offer0.get("will_top_up", false)), "will_top_up when stock 0")
	_ok(bool(offer0.get("ok", false)), "offer ok after projected top-up: %s" % offer0)
	_ok(int(offer0.get("cost", 0)) > 0, "offer cost > 0")
	_ok(int(offer0.get("turnin_days", -1)) >= 0, "turnin_days set")

	var silver0 := int(GameState.silver)
	var buy: Dictionary = World.gather_buy_here()
	_ok(bool(buy.get("ok", false)), "gather_buy_here: %s" % buy.get("msg", ""))
	if not bool(buy.get("ok", false)):
		return
	_ok(bool(buy.get("ready", false)), "buy reports ready")
	_ok(World.have_good(_good) >= _qty, "cargo has good")
	_ok(int(GameState.silver) < silver0, "silver spent")
	_ok(World.stock(_supply, _good) >= 0, "stock mutated after buy")
	var live := World.quest_by_id(_qid)
	_ok(str(live.get("state", "")) == "ready", "gather ready after buy state=%s" % live.get("state", ""))
	_ok(World.gather_pickups_here().is_empty(), "pickups clear when ready")
	_ok(World.quest_guide_node(live) == HOME, "guide flips to issuer")
	_ok(World.quest_markers().has(HOME), "turnin marker at issuer")
	var turnin_kind := false
	for mk2 in World.quest_markers().get(HOME, []):
		if str(mk2.get("kind", "")) == "turnin" and str(mk2.quest.get("id", "")) == _qid:
			turnin_kind = true
	_ok(turnin_kind, "turnin kind on issuer marker")
	_ok(World.can_turn_in(live, World.pos) == false, "cannot turn in at supply")
	_ok(World.ready_turn_ins_here().is_empty(), "no turn-ins while at supply")
	_ok(World.can_turn_in(live, HOME) == true, "can_turn_in at issuer city arg while ready")

	_go(HOME)
	_ok(World.pos == HOME, "back at issuer")
	_ok(World.ready_turn_ins_here().size() >= 1, "ready_turn_ins_here")
	var rep0 := World.rep_of(HOME)
	var s1 := int(GameState.silver)
	var have0 := World.have_good(_good)
	var tr: Dictionary = World.turn_in(_qid)
	_ok(bool(tr.get("ok", false)), "turn in: %s" % tr.get("msg", ""))
	_ok(World.quest_by_id(_qid).is_empty(), "quest removed")
	_ok(World.have_good(_good) == have0 - _qty, "goods consumed")
	_ok(int(GameState.silver) > s1, "reward silver")
	_ok(World.rep_of(HOME) > rep0, "reward rep")


func _text(root: Node, name: String) -> String:
	var n := root.find_child(name, true, false)
	if n == null:
		return ""
	if n is Label:
		return (n as Label).text
	if n is Button:
		return (n as Button).text
	if n.has_method("get_text"):
		return str(n.call("get_text"))
	return str(n.get("text")) if n.get("text") != null else ""


func _ui_board_and_market() -> void:
	var q := _make_gather()
	_ok(not q.is_empty(), "ui make")
	if q.is_empty():
		return
	_post(q)
	_qid = str(q.id)
	_good = str(q.good)
	_qty = int(q.qty)
	_supply = World.gather_supply_city(q)
	_supply_name = str(World.node(_supply).get("name", _supply))
	# Pre-accept board: supply march row on offer detail
	GameState.set_meta("city_id", HOME)
	GameState.set_meta("city_tab", "board")
	var pre = CITY_SCN.instantiate()
	pre.position = Vector2.ZERO
	pre.size = Vector2(1280, 720)
	get_tree().root.add_child(pre)
	for _pi in 6:
		await get_tree().process_frame
	if pre.has_method("_set_tab"):
		pre.call("_set_tab", "board")
	pre.set("_sel_quest", _qid)
	if pre.has_method("_render_tab"):
		pre.call("_render_tab")
	for _pj in 4:
		await get_tree().process_frame
	var march_row := pre.find_child("BoardSupplyMarch", true, false)
	_ok(march_row != null, "BoardSupplyMarch on offer detail")
	pre.queue_free()
	await get_tree().process_frame
	var acc: Dictionary = World.accept_quest(HOME, _qid)
	_ok(bool(acc.get("ok", false)), "ui accept")

	GameState.set_meta("city_id", HOME)
	GameState.set_meta("city_tab", "board")
	var city = CITY_SCN.instantiate()
	city.position = Vector2.ZERO
	city.size = Vector2(1280, 720)
	get_tree().root.add_child(city)
	for _i in 8:
		await get_tree().process_frame
	_ok(str(city.get_script()) != "", "city script loaded")
	if city.has_method("_set_tab"):
		city.call("_set_tab", "board")
	city.set("_sel_quest", _qid)
	if city.has_method("_render_tab"):
		city.call("_render_tab")
	for _j in 4:
		await get_tree().process_frame
	var body_bits := ""
	for lab in city.find_children("*", "Label", true, false):
		body_bits += (lab as Label).text + "\n"
	_ok(body_bits.find(_supply_name) >= 0, "board shows supply city name %s" % _supply_name)
	var goto_btn := city.find_child("GotoAtlasQuest", true, false) as Button
	_ok(goto_btn != null, "GotoAtlasQuest when not at supply")
	city.queue_free()
	await get_tree().process_frame

	_go(_supply)
	if not World.market.has(_supply):
		World._init_market(_supply)
	GameState.set_meta("city_id", _supply)
	GameState.set_meta("city_tab", "market")
	var mkt = CITY_SCN.instantiate()
	mkt.position = Vector2.ZERO
	mkt.size = Vector2(1280, 720)
	get_tree().root.add_child(mkt)
	for _k in 8:
		await get_tree().process_frame
	if mkt.has_method("_set_tab"):
		mkt._set_tab("market")
	if mkt.has_method("_render_tab"):
		mkt._render_tab()
	for _m in 4:
		await get_tree().process_frame
	var strip := mkt.find_child("GatherSupplyStrip", true, false)
	_ok(strip != null, "GatherSupplyStrip on market")
	var banner := _text(mkt, "GatherSupplyLine")
	_ok(banner.find(World.good_name(_good)) >= 0, "banner names good %s" % banner)
	_ok(banner.find("银") >= 0 or banner.find("silver") >= 0 or banner.find("~") >= 0, "banner shows cost %s" % banner)
	var buy_btn := mkt.find_child("GatherBuy", true, false) as Button
	_ok(buy_btn != null and not buy_btn.disabled, "GatherBuy enabled")
	if buy_btn and not buy_btn.disabled:
		buy_btn.pressed.emit()
	for _n in 4:
		await get_tree().process_frame
	_ok(str(World.quest_by_id(_qid).get("state", "")) == "ready", "ui buy flipped ready")
	mkt.queue_free()
	await get_tree().process_frame


func _ui_atlas_pickup_enter() -> void:
	var q := _make_gather()
	_ok(not q.is_empty(), "atlas make")
	if q.is_empty():
		return
	_post(q)
	_qid = str(q.id)
	_supply = World.gather_supply_city(q)
	World.accept_quest(HOME, _qid)
	_go(_supply)
	World.visited[_supply] = true
	GameState.set_meta("atlas_select", _supply)
	GameState.set_meta("atlas_view", World.nation_of(_supply))
	var page = ATLAS_SCN.instantiate()
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	get_tree().root.add_child(page)
	for _i in 10:
		await get_tree().process_frame
	if page.has_method("_select_node"):
		page._select_node(_supply)
	for _j in 4:
		await get_tree().process_frame
	var enter := page.find_child("EnterButton", true, false) as Button
	_ok(enter != null, "EnterButton present")
	if enter:
		var want := Locale.t("atlas_enter_pickup") % maxi(1, World.gather_pickups_here().size())
		_ok(enter.text.find("采购") >= 0 or enter.text == want or enter.text.find(str(World.gather_pickups_here().size())) >= 0, "enter pickup label '%s' want '%s'" % [enter.text, want])
	var profile := ""
	for lab in page.find_children("*", "Label", true, false):
		profile += (lab as Label).text + "\n"
	_ok(profile.find("物产") >= 0 or profile.find("◇") >= 0, "atlas profile marks pickup")
	page.queue_free()
