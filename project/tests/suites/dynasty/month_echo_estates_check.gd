extends Node
## Y1-B month-loop deepen: estates MonthEchoPanel — empty → EmptyHost how + ToHourglass;
## after Calendar.advance with holdings → EchoLine_holdings re-read.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL month echo: ", err)
		get_tree().quit(1)
	else:
		print("MONTH ECHO ESTATES PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.house_mods.erase("month_echo")
	GameState.holdings = {}

	var err := await _audit_empty()
	if err != "":
		return err
	err = await _audit_filled()
	if err != "":
		return err
	return ""


func _open_estates() -> Control:
	var page: Control = load("res://scenes/hub/estates.tscn").instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	return page


func _audit_empty() -> String:
	var page := _open_estates()
	for _i in 8:
		await get_tree().process_frame
	var panel := page.find_child("MonthEchoPanel", true, false)
	if panel == null:
		page.queue_free()
		return "MonthEchoPanel missing (empty)"
	var host := panel.find_child("EmptyHost", true, false)
	if host == null:
		page.queue_free()
		return "EmptyHost missing under MonthEchoPanel"
	var empty_zh := Locale.t("lb_est_echo_empty")
	var found := false
	for n in host.find_children("*", "Label", true, false):
		if str((n as Label).text).find(empty_zh) >= 0:
			found = true
			break
	if not found:
		page.queue_free()
		return "empty copy missing"
	var how_zh := Locale.t("lb_est_echo_empty_how")
	var how_ok := false
	for n in host.find_children("*", "Label", true, false):
		if str((n as Label).text).find(how_zh) >= 0:
			how_ok = true
			break
	if not how_ok:
		page.queue_free()
		return "how (lb_est_echo_empty_how) missing"
	var acts := host.find_child("EmptyActions", true, false)
	if acts == null:
		page.queue_free()
		return "EmptyActions missing"
	var cta: Button = host.find_child("ToHourglass", true, false) as Button
	if cta == null:
		page.queue_free()
		return "ToHourglass missing under EmptyHost"
	if not acts.is_ancestor_of(cta):
		page.queue_free()
		return "ToHourglass not under EmptyActions"
	var want := Locale.t("lb_est_to_hourglass")
	if cta.text != want:
		page.queue_free()
		return "ToHourglass text want=%s got=%s" % [want, cta.text]
	if not cta.visible or cta.disabled:
		page.queue_free()
		return "ToHourglass not actionable"
	print("month-echo empty ok ToHourglass how=1 under_EmptyHost=1")
	page.queue_free()
	await get_tree().process_frame
	return ""


func _audit_filled() -> String:
	## Estates open grants first holding; advance one month to settle yield.
	if GameState.holdings.is_empty():
		var hid: String = str(GameState.HOLDING_DEFS.keys()[0])
		GameState.unlock_holding(hid)
	var before_silver := int(GameState.silver)
	var before_food := int(GameState.food)
	Calendar.advance(1)
	await get_tree().process_frame
	if not CKEconomyState.month_echo_has_any():
		return "month_echo empty after advance (holdings=%s)" % str(GameState.holdings.keys())
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	if str(snap.get("holdings", "")) == "":
		return "holdings line missing in month_echo: %s" % str(snap)
	var page := _open_estates()
	for _i in 8:
		await get_tree().process_frame
	var panel := page.find_child("MonthEchoPanel", true, false)
	if panel == null:
		page.queue_free()
		return "MonthEchoPanel missing (filled)"
	var line := page.find_child("EchoLine_holdings", true, false) as Label
	if line == null:
		## CKPageKit.text may wrap Label differently — search text
		var want_bit := str(snap.get("holdings", "")).substr(0, mini(8, str(snap.get("holdings", "")).length()))
		var hit := false
		for n in panel.find_children("*", "Label", true, false):
			if str((n as Label).text).find(want_bit) >= 0:
				hit = true
				break
		if not hit:
			page.queue_free()
			return "EchoLine_holdings missing and text not found bit=%s" % want_bit
	else:
		if str(line.text).find(str(snap.get("holdings", "")).substr(0, 4)) < 0:
			page.queue_free()
			return "EchoLine text mismatch"
	var cta := page.find_child("ToHourglass", true, false)
	if cta != null and panel.is_ancestor_of(cta):
		page.queue_free()
		return "ToHourglass still under panel after echo"
	print(
		"month-echo filled ok holdings label=%s silver=%d→%d food=%d→%d"
		% [str(snap.get("label", "")), before_silver, int(GameState.silver), before_food, int(GameState.food)]
	)
	page.queue_free()
	await get_tree().process_frame
	return ""
