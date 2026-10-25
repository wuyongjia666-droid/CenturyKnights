extends Node
## Mobile E2E: assault win → BattleAftermath → OccupyGarrisonModal reinforce/stockade.

const PHONE := Vector2i(2400, 1080)
const ROOT := Vector2(1600, 720)
const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile atlas occupy/garrison: ", err)
		get_tree().quit(1)
	else:
		print("MOBILE ATLAS OCCUPY GARRISON PASS")
		get_tree().quit(0)

func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	_boot()
	_reset_site()
	var seed_err := _seed_capture()
	if seed_err != "":
		return seed_err
	GameState.set_meta("atlas_after_battle", true)
	var page := await _mount_atlas()
	var ui_err := await _drive_occupy_ui(page)
	page.queue_free()
	for _z in 3:
		await get_tree().process_frame
	return ui_err

func _boot() -> void:
	GameState.new_game("手机占领驻防", "灰旗", GameState.crest_color)
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
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.active.clear()
	World.last_battle_aftermath.clear()

func _seed_capture() -> String:
	var anchor := str(CKTerritory.site(SITE).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	var ar: Dictionary = CKTerritory.assault(SITE)
	if not bool(ar.get("ok", false)):
		return "assault: %s" % ar.get("msg", "")
	World.on_battle_end(true)
	if not CKTerritory.owned(SITE):
		return "not owned after win"
	if not bool(World.last_battle_aftermath.get("site_captured", false)):
		return "no site_captured"
	return ""

func _drive_occupy_ui(page: Control) -> String:
	if not bool(page.get("_mob")):
		return "_mob false"
	var bam: Node = page.find_child("BattleAftermathModal", true, false)
	if bam == null:
		return "no BattleAftermathModal"
	var cont: Button = bam.get_node_or_null("BattleAftermathContinue") as Button
	if cont == null:
		return "no Continue"
	cont.pressed.emit()
	for _j in 10:
		await get_tree().process_frame
	var occ: Node = page.find_child("OccupyGarrisonModal", true, false)
	if occ == null:
		return "no OccupyGarrisonModal"
	var rf: Button = occ.get_node_or_null("OccupyReinforce") as Button
	if rf == null:
		return "no OccupyReinforce"
	var sk: Button = occ.get_node_or_null("OccupyStockade") as Button
	if sk == null:
		return "no OccupyStockade"
	var g0 := int(CKTerritory.state(SITE).garrison)
	rf.pressed.emit()
	for _k in 10:
		await get_tree().process_frame
	if int(CKTerritory.state(SITE).garrison) != g0 + 1:
		return "garrison not +1"
	if page.find_child("OccupyGarrisonModal", true, false) == null:
		return "modal closed early"
	sk.pressed.emit()
	for _m in 8:
		await get_tree().process_frame
	if not bool(CKTerritory.state(SITE).stockade):
		return "stockade not built"
	return ""

func _reset_site() -> void:
	var st: Dictionary = CKTerritory.state(SITE)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.stockade = false
	st.unrest = 0
	st.threat = {}
	CKTerritory._put(SITE, st)

func _set_phone_window() -> void:
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = PHONE
	await get_tree().process_frame
	await get_tree().process_frame

func _mount_atlas() -> Control:
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = ROOT
	for _i in 6:
		await get_tree().process_frame
	if page.has_method("apply_mobile_layout"):
		page.apply_mobile_layout()
	for _j in 4:
		await get_tree().process_frame
	return page
