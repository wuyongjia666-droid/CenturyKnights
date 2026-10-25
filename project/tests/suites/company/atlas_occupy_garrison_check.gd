extends Node
## Fat atlas: territory assault win → OccupyGarrisonModal reinforce/stockade E2E.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_setup()
	_api_assault_aftermath_occupy()
	await _ui_occupy_reinforce_stockade()
	if _fails.is_empty():
		print("ATLAS OCCUPY GARRISON PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL atlas occupy/garrison: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _setup() -> void:
	GameState.new_game("占领驻防", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.food = 40
	GameState.silver = 12000
	GameState.morale = 80
	World.hub_tour.clear()
	World.pos = "ash_capital"
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.active.clear()
	World.cargo.clear()
	World.cargo_basis.clear()
	World.last_aftermath.clear()
	World.last_battle_aftermath.clear()

func _reset_site() -> void:
	var st: Dictionary = CKTerritory.state(SITE)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.stockade = false
	st.unrest = 0
	st.threat = {}
	CKTerritory._put(SITE, st)

func _api_assault_aftermath_occupy() -> void:
	_reset_site()
	var anchor := str(CKTerritory.site(SITE).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	World.encounter = {}
	World.last_battle_aftermath.clear()
	var ar: Dictionary = CKTerritory.assault(SITE)
	_ok(bool(ar.get("ok", false)), "assault ok: %s" % ar.get("msg", ""))
	_ok(str(World.encounter.get("site", "")) == SITE, "encounter tagged site")
	_ok(str(World.encounter.get("kind", "")) == "territory_assault", "kind territory_assault")
	var silver0 := GameState.silver
	var r: Dictionary = World.on_battle_end(true)
	_ok(bool(r.get("ok", false)), "on_battle_end win")
	_ok(CKTerritory.owned(SITE), "site owned after win")
	var af: Dictionary = r.get("aftermath", World.last_battle_aftermath)
	_ok(bool(af.get("site_captured", false)), "site_captured in aftermath")
	_ok(str(af.get("site", "")) == SITE, "aftermath site id")
	_ok(str(af.get("site_kind", "")) == "territory_assault", "site_kind")
	_ok(af.has("site_name") and str(af.get("site_name", "")) != "", "site_name set")
	_ok(int(af.get("garrison", -1)) == 0, "assault capture starts garrison 0")
	_ok(GameState.silver >= silver0, "loot did not drain silver")
	# lose path: no capture flag
	_reset_site()
	World.pos = anchor
	World.arrive(anchor)
	CKTerritory.assault(SITE)
	var lose: Dictionary = World.on_battle_end(false)
	var laf: Dictionary = lose.get("aftermath", {})
	_ok(not bool(laf.get("site_captured", true)), "lose: no site_captured")
	_ok(not CKTerritory.owned(SITE), "lose: still neutral")

func _ui_occupy_reinforce_stockade() -> void:
	_reset_site()
	var anchor := str(CKTerritory.site(SITE).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	GameState.silver = 12000
	var ar: Dictionary = CKTerritory.assault(SITE)
	_ok(bool(ar.get("ok", false)), "ui assault ok")
	World.on_battle_end(true)
	_ok(CKTerritory.owned(SITE), "ui site owned")
	_ok(bool(World.last_battle_aftermath.get("site_captured", false)), "ui aftermath site_captured")
	GameState.set_meta("atlas_after_battle", true)
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	for _i in 10:
		await get_tree().process_frame
	var bam: Node = page.find_child("BattleAftermathModal", true, false)
	_ok(bam != null, "BattleAftermathModal after resume")
	if bam != null:
		var cont: Button = bam.get_node_or_null("BattleAftermathContinue") as Button
		_ok(cont != null, "BattleAftermathContinue")
		if cont:
			cont.pressed.emit()
			for _j in 8:
				await get_tree().process_frame
	var occ: Node = page.find_child("OccupyGarrisonModal", true, false)
	_ok(occ != null, "OccupyGarrisonModal after continue")
	if occ == null:
		page.queue_free()
		return
	_ok(occ.get_node_or_null("OccupyBody") != null, "OccupyBody")
	_ok(occ.get_node_or_null("OccupyReinforce") != null, "OccupyReinforce")
	_ok(occ.get_node_or_null("OccupyStockade") != null, "OccupyStockade")
	_ok(occ.get_node_or_null("OccupyLater") != null, "OccupyLater")
	var gar0 := int(CKTerritory.state(SITE).garrison)
	var rf: Button = occ.get_node_or_null("OccupyReinforce") as Button
	var sk: Button = occ.get_node_or_null("OccupyStockade") as Button
	if rf:
		rf.pressed.emit()
		for _k in 10:
			await get_tree().process_frame
	_ok(int(CKTerritory.state(SITE).garrison) == gar0 + 1, "garrison +1 after reinforce UI")
	_ok(page.find_child("OccupyGarrisonModal", true, false) != null, "OccupyGarrisonModal stays after reinforce")
	_ok(sk != null, "OccupyStockade on same modal")
	if sk:
		sk.pressed.emit()
		for _m in 10:
			await get_tree().process_frame
	_ok(bool(CKTerritory.state(SITE).stockade), "stockade built via UI")
	_ok(page.find_child("OccupyGarrisonModal", true, false) == null, "occupy modal closed after stockade")
	page.queue_free()
	for _z in 3:
		await get_tree().process_frame
