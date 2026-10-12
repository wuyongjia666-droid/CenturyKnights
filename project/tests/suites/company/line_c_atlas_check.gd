extends Node
## WS-C #41/#42/#45：舆图名单联动、出战编成返回舆图、领地归属+驻军、失守弹窗、跨月提示。

var _fails: Array = []


func _ready() -> void:
	await get_tree().process_frame
	GameState.new_game("霜行", "灰旗", GameState.crest_color)
	World.reset()
	World.events_enabled = false
	await _atlas()
	if _fails.is_empty():
		print("LINE C ATLAS PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL line_c_atlas: ", f)
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)


func _atlas() -> void:
	var sid := "t_ash_millrun"
	CKTerritory.capture(sid, "chain")
	CKTerritory.lose(sid, "")
	var saved := CKTerritory.to_save()
	World.territory = CKTerritory.from_save(saved)
	_ok((World.territory.get("news", []) as Array).size() == 1, "news not kept across save")
	var packed: PackedScene = load("res://scenes/hub/atlas_view.tscn")
	var a := packed.instantiate()
	add_child(a)
	for _i in 4:
		await get_tree().process_frame
	_ok(a.find_child("LossModal", true, false) != null, "loss modal not shown")
	_ok(CKTerritory.take_news().is_empty(), "news not consumed")
	a.call("_clear_modal")
	_ok(not a.call("_check_losses"), "loss modal repeats")
	var site_btn := a.find_child("Site_" + sid, true, false)
	_ok(site_btn != null and site_btn.find_child("OwnerChip", true, false) != null, "no owner chip on site flag")
	a.call("_show_view", "")
	await get_tree().process_frame
	a.call("hilite", "ashbanner")
	var rb: Control = a.find_child("Region_ashbanner", true, false)
	var lb: Control = a.find_child("View_ashbanner", true, false)
	_ok(rb != null and rb.modulate.r > 1.1, "map region not lit from list")
	_ok(lb != null and lb.modulate.r > 1.1, "list row not lit")
	a.call("hilite", "")
	_ok(rb != null and is_equal_approx(rb.modulate.r, 1.0), "hilite not cleared")
	var cal0 := Calendar.label()
	World.advance_days(31)
	a.call("_month_feedback", cal0)
	var toast: Label = a.get("_toast")
	_ok(toast.visible and toast.text.find("过了一个月") >= 0, "no month toast: " + toast.text)
	GameState.set_meta("deploy_return", "res://scenes/hub/atlas_view.tscn")
	_ok(FileAccess.get_file_as_string("res://scripts/hub/deploy.gd").find("deploy_return") >= 0, "deploy ignores return")
	GameState.remove_meta("deploy_return")
	a.queue_free()
