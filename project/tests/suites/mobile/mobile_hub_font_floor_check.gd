extends Node
## Y1-A hub font floor: city (priority) + market/estates/works/forge on a wide phone viewport
## keep fonts ≥ FONT_FLOOR, expose apply_mobile_layout, and keep key chrome unclipped.
## Named mobile_* → ci_godot_run.sh sets CK_FORCE_MOBILE=1.

const PHONE := Vector2i(2400, 1080)
const ROOT := Vector2(1600, 720)  # MobileLayout.fit logical size for 2400×1080 landscape
const PAGES := [
	["city", "res://scenes/hub/city.tscn"],
	["market", "res://scenes/hub/market.tscn"],
	["estates", "res://scenes/hub/estates.tscn"],
	["works", "res://scenes/hub/works.tscn"],
	["forge", "res://scenes/hub/forge.tscn"],
]

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL hub font floor: ", err)
		get_tree().quit(1)
	else:
		print("HUB FONT FLOOR PASS")
		get_tree().quit(0)

func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	if not MobileLayout.FONT_FLOOR_PENDING.is_empty():
		return "FONT_FLOOR_PENDING still has %s" % str(MobileLayout.FONT_FLOOR_PENDING)
	await _set_phone_window()
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	World.pos = "ash_capital"
	GameState.set_meta("city_id", "ash_capital")
	for entry in PAGES:
		var err := await _check_page(str(entry[0]), str(entry[1]))
		if err != "":
			return "%s: %s" % [entry[0], err]
	return ""

func _set_phone_window() -> void:
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = PHONE
	await get_tree().process_frame
	await get_tree().process_frame

func _check_page(tag: String, path: String) -> String:
	var packed: PackedScene = load(path)
	if packed == null:
		return "load failed"
	var page: Control = packed.instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = ROOT
	for _i in 5:
		await get_tree().process_frame
	if not page.has_method("apply_mobile_layout"):
		page.queue_free()
		return "no apply_mobile_layout"
	page.apply_mobile_layout()
	for _j in 4:
		await get_tree().process_frame
	MobileLayout.ensure_min_fonts(page)
	MobileLayout.ensure_hit_targets(page)
	for _k in 3:
		await get_tree().process_frame
	var report := _audit(page, tag)
	page.queue_free()
	await get_tree().process_frame
	return report

func _audit(page: Control, tag: String) -> String:
	if not MobileLayout.font_floor_applies(page):
		return "font_floor_applies false"
	var chrome_err := _audit_chrome(page, tag)
	if chrome_err != "":
		return chrome_err
	var small: Array = _smallest_text(page)
	if int(small[0]) < MobileLayout.FONT_FLOOR:
		return "text %s font %d < %d" % [small[1], int(small[0]), MobileLayout.FONT_FLOOR]
	print("hub-floor %s ok smallest=%d (%s)" % [tag, int(small[0]), small[1]])
	return ""

func _audit_chrome(page: Control, tag: String) -> String:
	if tag == "city":
		return _audit_city_chrome(page)
	var top2 := page.find_child("MobileTopBar", true, false) as Control
	if top2 == null:
		return "MobileTopBar missing"
	return _not_clipped(page, top2)

func _audit_city_chrome(page: Control) -> String:
	var tabs := page.find_child("Tabs", true, false) as Control
	var tab_host := page.find_child("TabScroll", true, false) as Control
	var body := page.find_child("MobileBody", true, false) as Control
	var top := page.find_child("MobileTopBar", true, false) as Control
	if tabs == null:
		return "Tabs missing"
	if tab_host == null:
		return "TabScroll missing"
	if body == null:
		return "MobileBody missing"
	if top == null:
		return "MobileTopBar missing"
	for ctrl in [tab_host, body, top]:
		var err := _not_clipped(page, ctrl as Control)
		if err != "":
			return err
	return _audit_city_tabs(tabs)

func _audit_city_tabs(tabs: Control) -> String:
	var hit_ok := false
	for b in tabs.get_children():
		if not (b is Button):
			continue
		var btn := b as Button
		var hy := maxf(btn.size.y, btn.custom_minimum_size.y)
		if hy + 0.5 < MobileLayout.HIT_FLOOR:
			return "tab %s hit %.1f < %.1f" % [btn.name, hy, MobileLayout.HIT_FLOOR]
		if btn.get_theme_font_size("font_size") < MobileLayout.FONT_FLOOR:
			return "tab %s font below floor" % btn.name
		hit_ok = true
	if not hit_ok:
		return "no tab buttons"
	return ""

func _not_clipped(root: Control, c: Control) -> String:
	if c == null or not c.is_visible_in_tree():
		return "%s invisible" % (c.name if c else "?")
	var rr := root.get_global_rect().grow(2.0)
	var cr := c.get_global_rect()
	if cr.size.x < 8.0 or cr.size.y < 8.0:
		return "%s degenerate size %s" % [c.name, str(cr.size)]
	if not rr.encloses(cr):
		return "%s clipped root=%s ctrl=%s" % [c.name, str(rr), str(cr)]
	return ""

func _smallest_text(n: Node) -> Array:
	var best := 999
	var who := "none"
	for c in n.find_children("*", "Control", true, false):
		if bool(c.get_meta("font_floor_exempt", false)):
			continue
		if not (c as Control).is_visible_in_tree():
			continue
		var fs := -1
		var label := ""
		if c is Label:
			fs = (c as Label).get_theme_font_size("font_size")
			label = (c as Label).text.substr(0, 12)
		elif c is Button:
			var btn := c as Button
			# Icon-only / empty chrome rows (city list rows use child Labels for text).
			if btn.text.strip_edges() == "":
				continue
			fs = btn.get_theme_font_size("font_size")
			label = btn.text.substr(0, 12)
		elif c is RichTextLabel:
			fs = (c as RichTextLabel).get_theme_font_size("normal_font_size")
			label = "rich"
		else:
			continue
		if fs < 0:
			continue
		if fs < best:
			best = fs
			who = "%s:%s" % [c.name, label]
	if best == 999:
		return [MobileLayout.FONT_FLOOR, "none"]
	return [best, who]
