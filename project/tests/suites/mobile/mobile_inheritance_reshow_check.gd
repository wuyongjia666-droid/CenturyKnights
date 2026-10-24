extends Node
## Y1-B inheritance edge: after answering succession on mobile, _resolve → _show must
## re-run apply_mobile_layout so AnswerScroll / FONT_FLOOR / HIT survive the done-year re-show.
## Named mobile_* → ci_godot_run.sh sets CK_FORCE_MOBILE=1.

const PHONE := Vector2i(2400, 1080)
const ROOT := Vector2(1600, 720)
const SQUASH := 0.85

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL inherit reshow: ", err)
		get_tree().quit(1)
	else:
		print("INHERIT RESHOW PASS")
		get_tree().quit(0)

func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	## Skip ambition offer so Pick_* cards show immediately.
	GameState.house_mods["dyn_amb"] = "blood_keep"
	GameState.house_mods.erase("inherit_answer_year")
	GameState.house_mods.erase("inherit_answer_zh")
	_ensure_heir()
	var page: Control = load("res://scenes/hub/inheritance.tscn").instantiate()
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
	for _j in 4:
		await get_tree().process_frame
	if page.find_child("Pick_steel", true, false) == null:
		page.queue_free()
		return "Pick_steel missing before resolve"
	## Page must re-layout itself inside _resolve → _show; do NOT call apply_mobile_layout here.
	page.call("_resolve", "steel")
	for _k in 8:
		await get_tree().process_frame
	var err := _audit_done(page)
	page.queue_free()
	return err

func _ensure_heir() -> void:
	var lead: CKCharacter = GameState.get_leader()
	if lead == null:
		return
	## Prefer a child on lineage_path age≥10; else leader fallback is fine for Pick/resolve.
	for ch in GameState.characters.values():
		if ch.alive and (ch.is_child or GameState.lineage_path.has(ch.id)) and ch.age >= 10:
			return
	var kid := CKCharacter.new()
	kid.id = "inherit_reshow_heir"
	kid.name = "嗣子·试"
	kid.gender = "m"
	kid.age = 12
	kid.is_child = true
	kid.alive = true
	kid.rank = "squire"
	if lead != null:
		kid.parent_ids = [lead.id]
	kid.ensure_genome()
	GameState.characters[kid.id] = kid
	GameState.lineage_path[kid.id] = "steel"

func _audit_done(page: Control) -> String:
	var body: Label = page.find_child("InheritText", true, false) as Label
	if body == null:
		return "InheritText missing after resolve"
	if body.text.strip_edges() == "":
		return "done-year body empty"
	var bfs := body.get_theme_font_size("font_size")
	if bfs < MobileLayout.FONT_FLOOR:
		return "body font %d < %d" % [bfs, MobileLayout.FONT_FLOOR]
	var board := page.find_child("InheritBoard", true, false) as Control
	if board == null:
		return "InheritBoard missing"
	var scroll := board.find_child("AnswerScroll", true, false) as ScrollContainer
	if scroll == null:
		return "AnswerScroll missing under InheritBoard after resolve"
	var rivals: Button = null
	for c in page.find_children("*", "Button", true, false):
		var b := c as Button
		if not b.is_visible_in_tree():
			continue
		if b.text.strip_edges() == "":
			continue
		## Done-year path: single rivals / continue button under Answers.
		rivals = b
		break
	## Prefer the card under Answers if present.
	var answers := page.find_child("Answers", true, false)
	if answers != null:
		for c in answers.find_children("*", "Button", true, false):
			var b2 := c as Button
			if b2.is_visible_in_tree() and b2.text.strip_edges() != "":
				rivals = b2
				break
	if rivals == null:
		return "rivals/done button missing after resolve"
	var hit_ok := rivals.custom_minimum_size.y + 0.01 >= MobilePage.HIT or rivals.size.y + 0.01 >= MobilePage.HIT
	if not hit_ok:
		return "rivals HIT weak min=%.1f size.y=%.1f need >= %.0f" % [rivals.custom_minimum_size.y, rivals.size.y, MobilePage.HIT]
	var squash := _squash_text(page)
	if squash != "":
		return squash
	print("inherit-reshow ok body_font=%d rivals_h=%.1f scroll=%s" % [bfs, maxf(rivals.custom_minimum_size.y, rivals.size.y), scroll.name])
	return ""

func _squash_text(n: Node) -> String:
	for c in n.find_children("*", "Control", true, false):
		if bool(c.get_meta("font_floor_exempt", false)):
			continue
		if not (c as Control).is_visible_in_tree():
			continue
		if not (c is Label or c is Button):
			continue
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
		if h + 0.5 < float(fs) * SQUASH:
			return "squash %s:%s h=%.1f font=%d" % [c.name, sample, h, fs]
	return ""

func _set_phone_window() -> void:
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = PHONE
	await get_tree().process_frame
	await get_tree().process_frame
