extends Node
## Y1-B inherit edge (audit #29): Pick_* show story+fx; after answer, ToRivals is
## named and re-laid out on phone (HIT / scroll) so re-show stays tappable.
## Named mobile_* → CK_FORCE_MOBILE=1.

const PHONE := Vector2i(2400, 1080)
const ROOT := Vector2(1600, 720)

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL inheritance pick: ", err)
		get_tree().quit(1)
	else:
		print("INHERITANCE PICK PASS")
		get_tree().quit(0)

func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _phone()
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var lead: CKCharacter = GameState.get_leader()
	## Skip ambition offer so the three succession answers show.
	GameState.house_mods["dyn_amb"] = "skip_offer"
	GameState.house_mods.erase("inherit_answer_year")
	GameState.house_mods.erase("inherit_answer_zh")
	GameState.silver = 80
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
	for _j in 5:
		await get_tree().process_frame
	var err := _audit_open(page)
	if err != "":
		page.queue_free()
		return err
	var pick: Button = page.find_child("Pick_steel", true, false) as Button
	if pick == null or pick.disabled:
		page.queue_free()
		return "Pick_steel missing/disabled"
	pick.pressed.emit()
	for _k in 8:
		await get_tree().process_frame
	err = _audit_done(page)
	page.queue_free()
	return err

func _audit_open(page: Control) -> String:
	for k in ["steel", "soft", "delay"]:
		var card := page.find_child("Answer_" + k, true, false) as Control
		if card == null:
			return "Answer_%s missing" % k
		var btn := page.find_child("Pick_" + k, true, false) as Button
		if btn == null:
			return "Pick_%s missing" % k
		if btn.custom_minimum_size.y + 0.01 < MobilePage.HIT:
			return "Pick_%s hit %.1f < %.1f" % [k, btn.custom_minimum_size.y, MobilePage.HIT]
		var story := Locale.t("lb_inh_%s_story" % k)
		var fx := Locale.t("lb_inh_%s_fx" % k)
		if not _has_label(card, story):
			return "Answer_%s missing story" % k
		if not _has_label(card, fx):
			return "Answer_%s missing fx" % k
	var scroll := page.find_child("AnswerScroll", true, false)
	if scroll == null:
		return "AnswerScroll missing after mobile layout"
	var fs := _smallest_pick_font(page)
	if fs < MobileLayout.FONT_FLOOR:
		return "Pick font %d < %d" % [fs, MobileLayout.FONT_FLOOR]
	print("inherit-open ok picks=3 hit>=%.0f font=%d" % [MobilePage.HIT, fs])
	return ""

func _audit_done(page: Control) -> String:
	if page.find_child("Pick_steel", true, false) != null:
		return "Pick_steel still present after resolve"
	var to_rivals: Button = page.find_child("ToRivals", true, false) as Button
	if to_rivals == null:
		return "ToRivals missing after resolve"
	if not to_rivals.visible:
		return "ToRivals not visible"
	if to_rivals.custom_minimum_size.y + 0.01 < MobilePage.HIT:
		return "ToRivals hit %.1f < %.1f" % [to_rivals.custom_minimum_size.y, MobilePage.HIT]
	var scroll := page.find_child("AnswerScroll", true, false) as Control
	if scroll == null:
		return "AnswerScroll missing after re-show"
	if not scroll.is_ancestor_of(to_rivals):
		return "ToRivals not under AnswerScroll after re-show"
	var body: Label = page.find_child("InheritText", true, false) as Label
	if body == null or str(body.text).find(str(GameState.house_mods.get("inherit_answer_zh", "___"))) < 0:
		return "done body missing answer zh"
	if int(GameState.house_mods.get("inherit_answer_year", -1)) != Calendar.year:
		return "inherit_answer_year not set"
	print("inherit-done ok ToRivals hit=%.1f under_scroll=1" % to_rivals.custom_minimum_size.y)
	return ""

func _has_label(root: Node, want: String) -> bool:
	if want == "":
		return false
	for n in root.find_children("*", "Label", true, false):
		if str((n as Label).text).find(want) >= 0:
			return true
	return false

func _smallest_pick_font(page: Control) -> int:
	var best := 999
	for k in ["steel", "soft", "delay"]:
		var btn := page.find_child("Pick_" + k, true, false) as Button
		if btn == null:
			continue
		best = mini(best, btn.get_theme_font_size("font_size"))
	return best if best < 999 else 0

func _phone() -> void:
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = PHONE
	await get_tree().process_frame
	await get_tree().process_frame
