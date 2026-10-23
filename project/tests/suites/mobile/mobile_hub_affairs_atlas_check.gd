extends Node
## Y1-A hub mobile: city 本城之事 overlay + atlas_view apply_mobile_layout.
## city_affairs.gd / atlas_territory.gd are RefCounted helpers — assert caller chrome.
## Named mobile_* → ci_godot_run.sh sets CK_FORCE_MOBILE=1.

const PHONE := Vector2i(2400, 1080)
const ROOT := Vector2(1600, 720)
const SQUASH := 0.85

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL hub affairs/atlas mobile: ", err)
		get_tree().quit(1)
	else:
		print("HUB AFFAIRS/ATLAS MOBILE PASS")
		get_tree().quit(0)

func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	World.pos = "ash_capital"
	GameState.set_meta("city_id", "ash_capital")
	var city_err := await _check_city_affairs()
	if city_err != "":
		return "city: %s" % city_err
	var atlas_err := await _check_atlas()
	if atlas_err != "":
		return "atlas: %s" % atlas_err
	return ""

func _set_phone_window() -> void:
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = PHONE
	await get_tree().process_frame
	await get_tree().process_frame

func _check_city_affairs() -> String:
	var packed: PackedScene = load("res://scenes/hub/city.tscn")
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
	if not page.has_method("open_affairs"):
		page.queue_free()
		return "no open_affairs"
	page.open_affairs()
	for _k in 4:
		await get_tree().process_frame
	MobileLayout.ensure_min_fonts(page)
	MobileLayout.ensure_hit_targets(page)
	for _n in 3:
		await get_tree().process_frame
	var overlay := page.find_child("AffairOverlay", true, false) as Control
	if overlay == null:
		page.queue_free()
		return "AffairOverlay missing"
	var do_btn := overlay.find_child("AffairDo", true, false) as Button
	if do_btn == null:
		page.queue_free()
		return "AffairDo missing"
	if do_btn.get_theme_font_size("font_size") < MobileLayout.FONT_FLOOR:
		page.queue_free()
		return "AffairDo font %d < %d" % [do_btn.get_theme_font_size("font_size"), MobileLayout.FONT_FLOOR]
	if do_btn.size.y + 0.5 < MobilePage.HIT * 0.9 and do_btn.custom_minimum_size.y + 0.5 < MobilePage.HIT * 0.9:
		page.queue_free()
		return "AffairDo hit %.1f < %.1f" % [maxf(do_btn.size.y, do_btn.custom_minimum_size.y), MobilePage.HIT]
	var squash := _squash_under(overlay)
	if squash != "":
		page.queue_free()
		return squash
	var small: Array = _smallest_under(overlay)
	if int(small[0]) < MobileLayout.FONT_FLOOR:
		page.queue_free()
		return "affair text %s font %d < %d" % [small[1], int(small[0]), MobileLayout.FONT_FLOOR]
	print("hub-affairs city ok smallest=%d (%s)" % [int(small[0]), small[1]])
	page.queue_free()
	await get_tree().process_frame
	return ""

func _check_atlas() -> String:
	var packed: PackedScene = load("res://scenes/hub/atlas_view.tscn")
	if packed == null:
		return "load failed"
	var page: Control = packed.instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = ROOT
	for _i in 6:
		await get_tree().process_frame
	if not page.has_method("apply_mobile_layout"):
		page.queue_free()
		return "no apply_mobile_layout"
	page.apply_mobile_layout()
	for _j in 5:
		await get_tree().process_frame
	MobileLayout.ensure_min_fonts(page)
	MobileLayout.ensure_hit_targets(page)
	for _k in 3:
		await get_tree().process_frame
	var sheet := page.find_child("MobileSheet", true, false) as Control
	if sheet == null:
		page.queue_free()
		return "MobileSheet missing after apply_mobile_layout"
	# Sheet body (not map — map is font_floor_exempt): labels/buttons ≥ floor, not squashed.
	var squash := _squash_under(sheet)
	if squash != "":
		page.queue_free()
		return squash
	var small: Array = _smallest_under(sheet)
	if int(small[0]) < MobileLayout.FONT_FLOOR:
		page.queue_free()
		return "sheet text %s font %d < %d" % [small[1], int(small[0]), MobileLayout.FONT_FLOOR]
	# Territory modal: open first site if any nation has markers.
	var terr_err := await _open_territory_sample(page)
	if terr_err != "":
		page.queue_free()
		return terr_err
	print("hub-affairs atlas ok sheet_smallest=%d (%s)" % [int(small[0]), small[1]])
	page.queue_free()
	await get_tree().process_frame
	return ""

func _open_territory_sample(page: Control) -> String:
	if not page.has_method("_open_territory"):
		return ""
	var anchor := ""
	for nid in World.nation_ids():
		for sid in CKTerritory.sites_in(str(nid)):
			anchor = str(CKTerritory.site(str(sid)).get("anchor", ""))
			if anchor != "":
				break
		if anchor != "":
			break
	if anchor == "":
		print("hub-affairs atlas: no territory site — skip modal")
		return ""
	page.call("_open_territory", anchor)
	for _i in 4:
		await get_tree().process_frame
	MobileLayout.ensure_min_fonts(page)
	MobileLayout.ensure_hit_targets(page)
	for _j in 3:
		await get_tree().process_frame
	var modal := page.find_child("TerritoryModal", true, false) as Control
	if modal == null:
		return "TerritoryModal missing"
	var close := modal.find_child("TerrClose", true, false) as Button
	if close == null:
		return "TerrClose missing"
	if close.get_theme_font_size("font_size") < MobileLayout.FONT_FLOOR:
		return "TerrClose font %d < %d" % [close.get_theme_font_size("font_size"), MobileLayout.FONT_FLOOR]
	if maxf(close.size.y, close.custom_minimum_size.y) + 0.5 < MobilePage.HIT * 0.9:
		return "TerrClose hit %.1f < %.1f" % [maxf(close.size.y, close.custom_minimum_size.y), MobilePage.HIT]
	var squash := _squash_under(modal)
	if squash != "":
		return "territory %s" % squash
	print("hub-affairs atlas territory modal ok anchor=%s" % anchor)
	return ""

func _squash_under(n: Node) -> String:
	for c in n.find_children("*", "Control", true, false):
		if bool(c.get_meta("font_floor_exempt", false)):
			continue
		if not (c as Control).is_visible_in_tree():
			continue
		if not (c is Label or c is Button):
			continue
		var fs := -1
		var sample := ""
		if c is Label:
			var lab := c as Label
			if lab.text.strip_edges() == "":
				continue
			fs = lab.get_theme_font_size("font_size")
			sample = lab.text.substr(0, 16)
		elif c is Button:
			var btn := c as Button
			if btn.text.strip_edges() == "":
				continue
			fs = btn.get_theme_font_size("font_size")
			sample = btn.text.substr(0, 16)
		if fs < MobileLayout.FONT_FLOOR:
			continue
		var h := (c as Control).size.y
		if h < 2.0:
			continue
		if h + 0.5 < float(fs) * SQUASH:
			return "squash %s:%s h=%.1f font=%d" % [c.name, sample, h, fs]
	return ""

func _smallest_under(n: Node) -> Array:
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
			if (c as Label).text.strip_edges() == "":
				continue
			fs = (c as Label).get_theme_font_size("font_size")
			label = (c as Label).text.substr(0, 12)
		elif c is Button:
			var btn := c as Button
			if btn.text.strip_edges() == "":
				continue
			fs = btn.get_theme_font_size("font_size")
			label = btn.text.substr(0, 12)
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
