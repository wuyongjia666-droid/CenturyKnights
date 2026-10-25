extends Node
## Mobile E2E: TerritoryMonthModal + TerritoryMonthOk.

const PHONE := Vector2i(2400, 1080)
const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile atlas territory month: ", err)
		get_tree().quit(1)
	else:
		print("MOBILE ATLAS TERRITORY MONTH RECLAIM PASS")
		get_tree().quit(0)

func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	_boot()
	CKTerritory.capture(SITE, "chain")
	var st := CKTerritory.state(SITE)
	st.garrison = 2
	CKTerritory._put(SITE, st)
	CKTerritory.apply_month(0.99)
	World.last_territory_month = CKTerritory.last_month_report.duplicate(true)
	if World.last_territory_month.is_empty():
		World.last_territory_month = {
			"silver": 10, "food": 0, "owned": 1, "owned_before": 1,
			"drains": [], "lost": [], "held": [], "threats": [], "line": "ok", "reclaims": [],
		}
	var page := await _mount_atlas()
	var modal: Node = page.find_child("TerritoryMonthModal", true, false)
	if modal == null and page.has_method("_check_territory_month"):
		page.call("_check_territory_month")
		for _j in 8:
			await get_tree().process_frame
		modal = page.find_child("TerritoryMonthModal", true, false)
	if modal == null:
		page.queue_free()
		return "TerritoryMonthModal missing"
	var ok_btn: Button = modal.get_node_or_null("TerritoryMonthOk") as Button
	if ok_btn == null:
		page.queue_free()
		return "TerritoryMonthOk missing"
	ok_btn.pressed.emit()
	for _k in 6:
		await get_tree().process_frame
	if page.find_child("TerritoryMonthModal", true, false) != null:
		page.queue_free()
		return "modal not cleared"
	page.queue_free()
	return ""

func _boot() -> void:
	GameState.new_game("TerrMonthMob", "AshBanner", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.food = 40
	GameState.silver = 400
	World.pos = "ash_capital"
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.last_territory_month = {}

func _mount_atlas() -> Node:
	var page: Node = ATLAS_SCN.instantiate()
	add_child(page)
	for _i in 12:
		await get_tree().process_frame
	return page

func _set_phone_window() -> void:
	DisplayServer.window_set_size(PHONE)
	await get_tree().process_frame
