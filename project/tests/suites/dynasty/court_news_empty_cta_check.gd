extends Node
## Y1-B: court_news empty gazette exposes named ToHourglass under NewsRows
## (empty box already has how-text; this knife adds the tap CTA).

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL news empty cta: ", err)
		get_tree().quit(1)
	else:
		print("NEWS EMPTY CTA PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	_scrub_court_logs()

	var page: Control = load("res://scenes/hub/court_news.tscn").instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	for _i in 8:
		await get_tree().process_frame

	var err := _audit(page)
	page.queue_free()
	return err


func _scrub_court_logs() -> void:
	## Force first-gazette empty path regardless of World seed.
	if typeof(World.royal_courts) != TYPE_DICTIONARY:
		World.royal_courts = {"nations": {}}
		return
	var nations: Dictionary = World.royal_courts.get("nations", {})
	if typeof(nations) != TYPE_DICTIONARY:
		World.royal_courts["nations"] = {}
		return
	for nid in nations.keys():
		var house = nations[nid]
		if typeof(house) == TYPE_DICTIONARY:
			house["log"] = []
			nations[nid] = house


func _audit(page: Control) -> String:
	var rows := page.find_child("NewsRows", true, false)
	if rows == null:
		return "NewsRows missing"
	var title_zh := Locale.t("lb_news_empty_title")
	var found_empty := false
	for n in rows.find_children("*", "Label", true, false):
		if str((n as Label).text).find(title_zh) >= 0:
			found_empty = true
			break
	if not found_empty:
		return "empty box (lb_news_empty_title) missing"

	var cta: Button = page.find_child("ToHourglass", true, false) as Button
	if cta == null:
		return "ToHourglass missing"
	if not cta.visible or not cta.is_visible_in_tree():
		return "ToHourglass not visible"
	if cta.disabled:
		return "ToHourglass disabled"
	var want := Locale.t("lb_news_to_hourglass")
	if cta.text != want:
		return "ToHourglass text want=%s got=%s" % [want, cta.text]
	if not rows.is_ancestor_of(cta):
		return "ToHourglass not under NewsRows"
	cta.pressed.emit()
	print("news-empty ok ToHourglass under_rows=1")
	return ""
