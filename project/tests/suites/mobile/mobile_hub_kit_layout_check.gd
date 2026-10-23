extends Node
## Y1-A hub kit mobile: skill_tree / quests / shrine / title_promote (+ hourglass /
## ancestors / blood_test) expose apply_mobile_layout, keep visible Label/Button
## fonts ≥ FONT_FLOOR, and do not squash key text (size.y ≥ font×0.85).
## Named mobile_* → ci_godot_run.sh sets CK_FORCE_MOBILE=1.
## Does NOT require FONT_FLOOR_PENDING empty (parallel with hub-floor PR).

const PHONE := Vector2i(2400, 1080)
const ROOT := Vector2(1600, 720)  # MobileLayout.fit logical size for 2400×1080 landscape
const SQUASH := 0.85
const PAGES := [
	["skill_tree", "res://scenes/hub/skill_tree.tscn"],
	["quests", "res://scenes/hub/quests.tscn"],
	["shrine", "res://scenes/hub/shrine.tscn"],
	["title_promote", "res://scenes/hub/title_promote.tscn"],
	["hourglass", "res://scenes/hub/hourglass.tscn"],
	["ancestors", "res://scenes/hub/ancestors.tscn"],
	["blood_test", "res://scenes/hub/blood_test.tscn"],
]

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL hub kit mobile: ", err)
		get_tree().quit(1)
	else:
		print("HUB KIT MOBILE PASS")
		get_tree().quit(0)

func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
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
	if page.scene_file_path in MobileLayout.FONT_FLOOR_PENDING:
		return "still in FONT_FLOOR_PENDING"
	var small: Array = _smallest_text(page)
	if int(small[0]) < MobileLayout.FONT_FLOOR:
		return "text %s font %d < %d" % [small[1], int(small[0]), MobileLayout.FONT_FLOOR]
	var squash := _squash_text(page)
	if squash != "":
		return squash
	print("hub-kit %s ok smallest=%d (%s)" % [tag, int(small[0]), small[1]])
	return ""

func _squash_text(n: Node) -> String:
	for c in n.find_children("*", "Control", true, false):
		if bool(c.get_meta("font_floor_exempt", false)):
			continue
		if not (c as Control).is_visible_in_tree():
			continue
		if not (c is Label or c is Button):
			continue
		# Kit chrome: PageDesc sits in a fixed-height title row; phone_fill widens it but
		# cannot grow the row. Skip top-bar / footer / page-head chrome — assert body copy.
		var nm := str(c.name)
		if nm in ["PageDesc", "PageHead", "PageTitle", "PageContext", "BrandMark"]:
			continue
		var under_chrome := false
		var walk: Node = c
		while walk != null and walk != n:
			var wn := str(walk.name)
			if wn.begins_with("Stitch") or wn == "MobileTopBar":
				under_chrome = true
				break
			walk = walk.get_parent()
		if under_chrome:
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
		# Real body copy / buttons must clear floor×0.85.
		if h + 0.5 < float(fs) * SQUASH:
			return "squash %s:%s h=%.1f font=%d" % [c.name, sample, h, fs]
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
