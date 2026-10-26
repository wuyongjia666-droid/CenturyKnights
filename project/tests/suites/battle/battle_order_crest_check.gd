extends Node
## Fat heraldry E2E: in-battle initiative strip via CKHeraldryField.
## Player chips are 族徽|旗徽, enemy chips are 敌徽, the lead chip is the
## ready actor. Marking that actor done advances the order. Desk + mobile.

const SCN := "res://scenes/battle/battle.tscn"
var _fails: Array = []


func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	_run_sort_probe()
	if _fails.is_empty():
		print("BATTLE ORDER CREST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL battle order crest: ", f)
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)


func _settle(n: int = 6) -> void:
	for _i in n:
		await get_tree().process_frame


func _boot() -> void:
	GameState.new_game("先攻徽", "霜旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	World.events_enabled = false
	World.rivals_enabled = false
	World.encounter = {}
	GameState.set_meta("battle_foe_nation", "ashbanner")
	GameState.set_meta("battle_map", "ch0_pass")


func _open() -> Control:
	var page: Control = (load(SCN) as PackedScene).instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	get_tree().root.add_child(page)
	return page


func _assert_strip(page: Node, where: String) -> void:
	var strip := page.find_child("BattleOrderCrest", true, false) as Control
	_ok(strip != null, "%s BattleOrderCrest" % where)
	if strip == null:
		return
	_ok(str(strip.get_meta("field_route", "")) == "battle_order", "%s field_route" % where)
	_ok(strip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s ignores taps" % where)
	var co := strip.find_child("CastleArms", true, false)
	_ok(co != null and str(co.get_meta("arms_kind", "")) == "gen2_36", "%s 团徽" % where)
	var n := int(strip.get_meta("chip_count", 0))
	_ok(n >= 1, "%s chip_count=%d" % [where, n])
	var lead := strip.find_child("OrderChip0", true, false)
	_ok(lead != null, "%s OrderChip0" % where)
	if lead == null:
		return
	_ok(str(lead.get_meta("field_route", "")) == "battle_order_chip", "%s chip field_route" % where)
	_ok(str(lead.get_meta("order_team", "")) in ["player", "ally"], "%s lead is our side" % where)
	_ok(bool(lead.get_meta("order_done", true)) == false, "%s lead has not acted" % where)
	var saw_foe := false
	var best_agi := -1
	var lead_agi := -1
	var units = page.get("units")
	var lead_idx := int(lead.get_meta("order_idx", -1))
	if typeof(units) == TYPE_ARRAY and lead_idx >= 0 and lead_idx < units.size():
		var ch = units[lead_idx].get("char")
		if ch != null and "stats" in ch:
			lead_agi = int(ch.stats.get("agi", 0))
	for i in n:
		var chip := strip.find_child("OrderChip%d" % i, true, false)
		if chip == null:
			_ok(false, "%s missing OrderChip%d" % [where, i])
			continue
		_ok(chip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s chip %d ignores taps" % [where, i])
		var kind := str(chip.get_meta("arms_kind", ""))
		var team := str(chip.get_meta("order_team", ""))
		if team == "enemy":
			saw_foe = true
			_ok(kind == "lb_rv_arms", "%s enemy chip is 敌徽" % where)
		else:
			_ok(kind in ["gen2_06", "gen2_35"], "%s our chip is person arms" % where)
			if not bool(chip.get_meta("order_done", false)) and typeof(units) == TYPE_ARRAY:
				var idx := int(chip.get_meta("order_idx", -1))
				if idx >= 0 and idx < units.size():
					var who = units[idx].get("char")
					if who != null and "stats" in who:
						best_agi = maxi(best_agi, int(who.stats.get("agi", 0)))
	_ok(saw_foe, "%s enemy 敌徽 present" % where)
	if lead_agi >= 0 and best_agi >= 0:
		_ok(lead_agi == best_agi, "%s lead agi %d is the ready max %d" % [where, lead_agi, best_agi])
	var before := str(strip.get_meta("order_sig", ""))
	if typeof(units) == TYPE_ARRAY and lead_idx >= 0 and lead_idx < units.size():
		units[lead_idx]["done"] = true
		await _settle(4)
		var after := str(strip.get_meta("order_sig", ""))
		_ok(after != before, "%s sig advances when the lead acts" % where)
		var still := false
		var ready_ahead := false
		for i in int(strip.get_meta("chip_count", 0)):
			var chip2 := strip.find_child("OrderChip%d" % i, true, false)
			if chip2 == null:
				continue
			if int(chip2.get_meta("order_idx", -2)) == lead_idx:
				still = true
				_ok(bool(chip2.get_meta("order_done", false)), "%s acted chip stays marked done" % where)
			elif not bool(chip2.get_meta("order_done", true)):
				if not still:
					ready_ahead = true
		_ok(still, "%s acted unit remains on the strip" % where)
		_ok(ready_ahead, "%s a ready ally now leads" % where)


func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	_boot()
	var page := _open()
	await _settle(12)
	await _assert_strip(page, "desk")
	page.queue_free()
	await _settle(2)


func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	_boot()
	var page := _open()
	await _settle(12)
	if page.has_method("apply_mobile_layout"):
		page.call("apply_mobile_layout")
		await _settle(8)
	await _assert_strip(page, "mob")
	page.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")


func _run_sort_probe() -> void:
	var chrome := FileAccess.get_file_as_string("res://scripts/art/heraldry_chrome.gd")
	var field_src := FileAccess.get_file_as_string("res://scripts/art/heraldry_field.gd")
	_ok(field_src.find("static func sync_battle_hud_crests") >= 0, "field owns hud sync")
	_ok(field_src.find("sync_battle_order_crests") >= 0, "hud sync mounts Field order strip")
	_ok(chrome.find("CKHeraldryField.sync_battle_hud_crests") >= 0, "chrome hud sync shim → Field")
	var train := FileAccess.get_file_as_string("res://scripts/hub/train.gd")
	_ok(train.find("sync_battle_order_crests") < 0, "train scene left alone")
	var deploy := FileAccess.get_file_as_string("res://scripts/hub/deploy.gd")
	_ok(deploy.find("sync_battle_order_crests") < 0, "deploy scene left alone")
	_ok(chrome.find("place_battle_hud_crest_strips") >= 0, "hud crest strip still placed before the order mount")
