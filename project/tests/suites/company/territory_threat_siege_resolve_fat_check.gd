extends Node
## Fat knife #4: 属地威胁→围城→解决整链 —
## HubTodo / ledger banner / hourglass → SiegeAlert 出战或缓兵 → threat_surface_state 三面一致。
## Deepens #711/#721/#723/#727; one fat PR; no thin chip/copy slices.

const CASTLE_SCN := preload("res://scenes/hub/castle_hub.tscn")
const LEDGER_SCN := preload("res://scenes/hub/territory_ledger.tscn")
const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const HOURGLASS_SCN := preload("res://scenes/hub/hourglass.tscn")
const Todo := preload("res://scripts/ui/widgets/todo_center.gd")
const SITE := "t_ash_cinderpit"
const MARKER := "TERRITORY THREAT SIEGE RESOLVE FAT PASS"
const SHOT_DIR := "user://threat_siege_resolve_shots"
const DESK := Vector2i(1600, 900)

var _shot_n := 0


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL territory threat siege resolve fat: ", err)
		get_tree().quit(1)
		return
	print(MARKER)
	get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	var err := _algebra()
	if err != "":
		return err
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	DisplayServer.window_set_size(DESK)
	await _settle(2)
	err = _api_surface_fight_and_bribe()
	if err != "":
		return err
	err = await _ui_threat_tip_ledger_siege_bribe()
	if err != "":
		return err
	err = await _ui_fight_clear_surfaces()
	if err != "":
		return err
	return ""


func _algebra() -> String:
	var terr := FileAccess.get_file_as_string("res://scripts/company/territory.gd")
	var ledger := FileAccess.get_file_as_string("res://scripts/hub/territory_ledger.gd")
	var hg := FileAccess.get_file_as_string("res://scripts/hub/hourglass.gd")
	if terr.find("func threat_surface_state") < 0:
		return "territory missing threat_surface_state"
	if terr.find("func _clear_siege_alert_for") < 0:
		return "territory missing _clear_siege_alert_for"
	if terr.find("downgraded") < 0:
		return "bribe_threat must report downgraded"
	if ledger.find("TerritoryThreatBanner") < 0 or ledger.find("TerritoryThreatGoto") < 0:
		return "ledger missing TerritoryThreatBanner/Goto"
	if ledger.find("func _on_threat_goto") < 0:
		return "ledger missing _on_threat_goto"
	if ledger.find("th.get(\"rival\"") >= 0:
		return "ledger still reads threat.rival (use name/by)"
	if hg.find("ThreatBribedNote") < 0 or hg.find("threat_surface_state") < 0:
		return "hourglass missing ThreatBribedNote / threat_surface_state"
	return ""


func _setup() -> void:
	GameState.new_game("威胁围城解决", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.silver = 9000
	GameState.food = 80
	GameState.morale = 80
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.last_siege_alert = {}
	World.last_threat_resolve = {}
	World.last_siege_loot = {}
	World.last_territory_month = {}
	CKTerritory.last_month_report = {}
	GameState.house_mods.erase("month_echo")
	Todo.reset_for_tests()


func _reset(id: String) -> void:
	var st: Dictionary = CKTerritory.state(id)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.stockade = false
	st.unrest = 0
	st.threat = {}
	st.cache_food = 0
	CKTerritory._put(id, st)


func _own_threatened(id: String) -> void:
	_reset(id)
	var anchor := str(CKTerritory.site(id).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	CKTerritory.capture(id, "chain")
	var st := CKTerritory.state(id)
	st.garrison = 4
	st.stockade = true
	st.cache_food = 4
	st.threat = {}
	CKTerritory._put(id, st)
	World.last_siege_alert = {}
	CKTerritory.start_threat(id)


func _has_todo_threat() -> bool:
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "territory_threat" and int(item.get("count", 0)) > 0:
			return true
	return false


func _agree_active(surf: Dictionary) -> String:
	var n := int(surf.get("count", 0))
	if n <= 0:
		return "surface count want >0"
	var lights := 0
	if bool(surf.get("hub_todo", false)):
		lights += 1
	if bool(surf.get("ledger_banner", false)):
		lights += 1
	if bool(surf.get("hourglass_pending", false)):
		lights += 1
	if lights < 2:
		return "active surface lights <%d want ≥2" % lights
	if _has_todo_threat() != bool(surf.get("hub_todo", false)):
		return "HubTodo chip disagree with surface.hub_todo"
	return ""


func _agree_cleared(surf: Dictionary) -> String:
	if not bool(surf.get("cleared", false)) or int(surf.get("count", 0)) != 0:
		return "surface not cleared: %s" % str(surf)
	if _has_todo_threat():
		return "HubTodo still lit after clear"
	return ""


func _api_fight_clear() -> String:
	_setup()
	_own_threatened(SITE)
	var err := _agree_active(CKTerritory.threat_surface_state())
	if err != "":
		return "api after threat: " + err
	World.mark_siege_alert({"id": SITE, "name": "x", "phase": "declared"})
	var note := CKTerritory.on_battle({"kind": "territory_defend", "site": SITE}, true)
	if note == "":
		return "api fight win empty note"
	if not (CKTerritory.state(SITE).threat as Dictionary).is_empty():
		return "api fight win threat still set"
	if not World.last_siege_alert.is_empty():
		return "api fight win left last_siege_alert"
	err = _agree_cleared(CKTerritory.threat_surface_state())
	if err != "":
		return "api fight clear: " + err
	if str(CKEconomyState.month_echo_snapshot().get("defend", "")) == "":
		return "api fight missing month_echo.defend"
	return ""


func _api_bribe_downgrade() -> String:
	_setup()
	_own_threatened(SITE)
	World.take_siege_alert()
	World.mark_siege_alert({"id": SITE, "name": "x", "months": 2, "bribed": false, "phase": "imminent"})
	var br: Dictionary = CKTerritory.bribe_threat(SITE)
	if not bool(br.get("ok", false)):
		return "api bribe fail: %s" % str(br.get("msg", ""))
	if not bool(br.get("downgraded", false)):
		return "api bribe missing downgraded"
	var th: Dictionary = CKTerritory.state(SITE).threat
	if th.is_empty() or not bool(th.get("bribed", false)) or int(th.get("months", -1)) != 0:
		return "api bribe threat state bad: %s" % str(th)
	if not bool(World.last_siege_alert.get("bribed", false)):
		return "api bribe did not sync last_siege_alert.bribed"
	var surf: Dictionary = CKTerritory.threat_surface_state()
	var err := _agree_active(surf)
	if err != "":
		return "api bribe surface: " + err
	if int(surf.get("bribed", 0)) < 1:
		return "api bribe surface.bribed want ≥1"
	return ""


func _api_surface_fight_and_bribe() -> String:
	var err := _api_fight_clear()
	if err != "":
		return err
	err = _api_bribe_downgrade()
	if err != "":
		return err
	print("api surface fight+bribe ok")
	return ""


func _ui_castle_threat_chip() -> String:
	print("ui tip: castle")
	var castle: Node = CASTLE_SCN.instantiate()
	add_child(castle)
	await _settle(16)
	var miss := castle.find_child("Todo_territory_threat", true, false) == null
	await _shot("threat_tip_hubtodo")
	castle.queue_free()
	await _settle(4)
	if miss:
		return "castle Todo_territory_threat missing"
	return ""


func _ui_ledger_banner_requeue() -> String:
	print("ui tip: ledger")
	var ledger: Control = LEDGER_SCN.instantiate()
	get_tree().root.add_child(ledger)
	await _settle(14)
	var banner := ledger.find_child("TerritoryThreatBanner", true, false) as Control
	var goto_btn := ledger.find_child("TerritoryThreatGoto", true, false) as Button
	var detail := ledger.find_child("TerritoryDetail", true, false) as RichTextLabel
	var err := ""
	if banner == null or not banner.visible:
		err = "TerritoryThreatBanner missing/hidden"
	elif goto_btn == null or not goto_btn.visible or goto_btn.disabled:
		err = "TerritoryThreatGoto missing/disabled"
	elif detail != null and detail.text.find("威胁：?") >= 0:
		err = "ledger detail still shows rival ?"
	await _shot("threat_tip_ledger")
	if err == "":
		if CKTerritory.hub_requeue_siege_alert() == "":
			err = "ledger goto requeue empty"
	ledger.queue_free()
	await _settle(4)
	return err


func _ui_siege_bribe_and_surfaces() -> String:
	print("ui tip: atlas siege")
	var atlas: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(atlas)
	await _settle(10)
	if atlas.has_method("_check_siege_alert"):
		atlas.call("_check_siege_alert")
	await _settle(10)
	var panel := atlas.find_child("SiegeAlertModal", true, false) as Control
	var err := ""
	if panel == null:
		err = "SiegeAlertModal missing after ledger goto"
	else:
		var relief := panel.find_child("SiegeRelief", true, false) as Button
		var bribe := panel.find_child("SiegeBribe", true, false) as Button
		if relief == null or bribe == null:
			err = "SiegeRelief/SiegeBribe CTA missing"
		elif relief.size.x < 40 or bribe.size.x < 40:
			err = "siege CTA clipped/tiny"
		else:
			await _shot("resolving_siege_modal")
			bribe.pressed.emit()
			await _settle(12)
			if str(CKEconomyState.month_echo_snapshot().get("bribe", "")) == "":
				err = "bribe echo missing after CTA"
	atlas.queue_free()
	await _settle(4)
	if err != "":
		return err
	var hg: Control = HOURGLASS_SCN.instantiate()
	get_tree().root.add_child(hg)
	await _settle(14)
	if hg.find_child("ThreatPending", true, false) == null:
		err = "hourglass ThreatPending missing after bribe"
	elif hg.find_child("ThreatBribedNote", true, false) == null:
		err = "hourglass ThreatBribedNote missing after bribe"
	elif hg.find_child("ToSiegeThreat", true, false) == null:
		err = "hourglass ToSiegeThreat missing"
	else:
		var surf: Dictionary = CKTerritory.threat_surface_state()
		err = _agree_active(surf)
		if err != "":
			err = "post-bribe surface: " + err
		elif int(surf.get("bribed", 0)) < 1:
			err = "post-bribe bribed count 0"
	var ledger2: Control = LEDGER_SCN.instantiate()
	get_tree().root.add_child(ledger2)
	await _settle(12)
	var banner2 := ledger2.find_child("TerritoryThreatBanner", true, false) as Label
	if err == "" and (banner2 == null or not banner2.visible):
		err = "ledger banner gone after bribe (should stay lit)"
	await _shot("resolved_bribe_surfaces")
	ledger2.queue_free()
	hg.queue_free()
	await _settle(2)
	return err


func _ui_threat_tip_ledger_siege_bribe() -> String:
	_setup()
	_own_threatened(SITE)
	World.take_siege_alert()
	var err := await _ui_castle_threat_chip()
	if err != "":
		return err
	err = await _ui_ledger_banner_requeue()
	if err != "":
		return err
	err = await _ui_siege_bribe_and_surfaces()
	if err != "":
		return err
	print("ui threat tip→ledger→siege bribe→surfaces ok")
	return ""


func _ui_fight_clear_surfaces() -> String:
	_setup()
	_own_threatened(SITE)
	World.mark_siege_alert({"id": SITE, "name": "x", "phase": "declared"})
	CKTerritory.on_battle({"kind": "territory_defend", "site": SITE}, true)
	await _settle(2)
	var err := _agree_cleared(CKTerritory.threat_surface_state())
	if err != "":
		return "fight clear api: " + err
	var castle: Node = CASTLE_SCN.instantiate()
	add_child(castle)
	await _settle(14)
	var chip_on := castle.find_child("Todo_territory_threat", true, false) != null
	castle.queue_free()
	await _settle(2)
	if chip_on:
		return "HubTodo threat chip still after fight clear"
	var ledger: Control = LEDGER_SCN.instantiate()
	get_tree().root.add_child(ledger)
	await _settle(12)
	var banner := ledger.find_child("TerritoryThreatBanner", true, false) as Control
	var banner_on := banner != null and banner.visible
	ledger.queue_free()
	await _settle(2)
	if banner_on:
		return "ledger threat banner still visible after fight clear"
	var hg: Control = HOURGLASS_SCN.instantiate()
	get_tree().root.add_child(hg)
	await _settle(12)
	var pending_on := hg.find_child("ThreatPending", true, false) != null
	var echo_ok := hg.find_child("EchoLine_defend", true, false) != null \
		or str(CKEconomyState.month_echo_snapshot().get("defend", "")) != ""
	await _shot("resolved_fight_clear")
	hg.queue_free()
	if pending_on:
		return "hourglass ThreatPending still after fight clear"
	if not echo_ok:
		return "missing defend echo after fight clear"
	print("ui fight clear surfaces ok")
	return ""


func _shot(tag: String) -> void:
	_shot_n += 1
	print("shot begin %s" % tag)
	var vp := get_viewport()
	if vp == null:
		print("shot skip no vp %s" % tag)
		return
	await get_tree().process_frame
	var tex = vp.get_texture()
	if tex == null:
		print("shot skip no tex %s" % tag)
		return
	var img: Image = tex.get_image()
	if img == null:
		print("shot skip no img %s" % tag)
		return
	var path := "%s/%02d_%s.png" % [SHOT_DIR, _shot_n, tag]
	var serr := img.save_png(path)
	print("shot %s err=%s size=%s" % [path, serr, img.get_size()])


func _settle(frames: int) -> void:
	for _i in frames:
		await get_tree().process_frame
