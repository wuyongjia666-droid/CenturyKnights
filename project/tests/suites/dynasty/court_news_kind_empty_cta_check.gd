extends Node
## Y1-B: court_news non-empty gazette + empty kind filter → EmptyHost + how + ToHourglass.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL news kind empty cta: ", err)
		get_tree().quit(1)
	else:
		print("NEWS KIND EMPTY CTA PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	_seed_birth_only()

	var page: Control = load("res://scenes/hub/court_news.tscn").instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	for _i in 8:
		await get_tree().process_frame

	var death_btn: Button = page.find_child("FilterDeath", true, false) as Button
	if death_btn == null:
		page.queue_free()
		return "FilterDeath missing"
	death_btn.pressed.emit()
	for _i in 6:
		await get_tree().process_frame

	var err := _audit(page)
	page.queue_free()
	return err


func _seed_birth_only() -> void:
	## One birth event so "all" is non-empty; death filter stays empty.
	if typeof(World.royal_courts) != TYPE_DICTIONARY or (World.royal_courts as Dictionary).is_empty():
		World.royal_courts = {"nations": {}}
	var nations: Dictionary = World.royal_courts.get("nations", {})
	if typeof(nations) != TYPE_DICTIONARY:
		nations = {}
	var nid := ""
	for k in nations.keys():
		nid = str(k)
		break
	if nid == "":
		nid = "lantern"
		nations[nid] = {"log": [], "crisis_name": ""}
	var house: Dictionary = nations[nid] if typeof(nations[nid]) == TYPE_DICTIONARY else {}
	house["log"] = [{
		"year": int(Calendar.year),
		"kind": "birth",
		"text": "suite seed birth",
	}]
	house["crisis_name"] = ""
	nations[nid] = house
	World.royal_courts["nations"] = nations


func _audit(page: Control) -> String:
	var rows := page.find_child("NewsRows", true, false)
	if rows == null:
		return "NewsRows missing"
	var host := rows.find_child("EmptyHost", true, false)
	if host == null:
		return "EmptyHost missing under NewsRows"
	var zh := str(CKCourtChrome.KIND_ZH.get("death", "death"))
	var title_zh := Locale.t("lb_news_kind_empty", [zh])
	var found := false
	for n in host.find_children("*", "Label", true, false):
		if str((n as Label).text).find(title_zh) >= 0:
			found = true
			break
	if not found:
		return "kind empty box missing want=%s" % title_zh
	var how_zh := Locale.t("lb_news_kind_how")
	var how_ok := false
	for n in host.find_children("*", "Label", true, false):
		if str((n as Label).text).find(how_zh) >= 0:
			how_ok = true
			break
	if not how_ok:
		return "how (lb_news_kind_how) missing"
	var acts := host.find_child("EmptyActions", true, false)
	if acts == null:
		return "EmptyActions missing"
	var cta: Button = host.find_child("ToHourglass", true, false) as Button
	if cta == null:
		return "ToHourglass missing under EmptyHost"
	if not cta.visible or not cta.is_visible_in_tree() or cta.disabled:
		return "ToHourglass not usable"
	if not acts.is_ancestor_of(cta):
		return "ToHourglass not under EmptyActions"
	var want := Locale.t("lb_news_to_hourglass")
	if cta.text != want:
		return "ToHourglass text want=%s got=%s" % [want, cta.text]
	print("news-kind-empty ok ToHourglass how=1 under_EmptyHost=1")
	return ""
