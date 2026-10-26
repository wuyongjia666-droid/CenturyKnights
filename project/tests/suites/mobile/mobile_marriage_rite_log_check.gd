extends Node
## Y1-B marriage edge: mobile RiteExplain must show the full rite consequence
## (no 40-char "……点开看全部" strip). Playtest audit: 22px single line looked cut.
## Named mobile_* → ci_godot_run.sh sets CK_FORCE_MOBILE=1.

const PHONE := Vector2i(2400, 1080)
const ROOT := Vector2(1600, 720)

var _cand: CKCharacter

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL marriage rite log: ", err)
		get_tree().quit(1)
	else:
		print("MARRIAGE RITE LOG PASS")
		get_tree().quit(0)

func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	var page := await _open_page()
	if page == null:
		return "open marriage failed"
	var err := _audit(page)
	if err == "" and page.has_method("show_details"):
		page.call("show_details")
		for _p in 3:
			await get_tree().process_frame
		if page.find_child("MarriageDetails", true, false) == null:
			err = "MarriageDetails sheet missing after tap"
	page.queue_free()
	return err

func _open_page() -> Control:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var lead: CKCharacter = GameState.get_leader()
	lead.gender = "m"
	lead.blood_mix = {"qh_jade": 1.0}
	lead.ensure_genome()
	## Qinghe leader + saltmarsh candidate → two rites; joined desc > 40 chars.
	_cand = CKCharacter.new()
	_cand.id = "rite_sm_cand"
	_cand.name = "潮女·试"
	_cand.gender = "f"
	_cand.age = 24
	_cand.rank = "knight"
	_cand.blood_mix = {"sm_tide": 1.0}
	_cand.in_roster = false  ## court post (factory default); else A4 bond clobbers RiteExplain
	_cand.ensure_genome()
	GameState.characters[_cand.id] = _cand
	GameState.marriage_candidates = [_cand]
	GameState.marriage_nation = "saltmarsh"
	var page: Control = load("res://scenes/hub/marriage.tscn").instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = ROOT
	for _i in 6:
		await get_tree().process_frame
	if not page.has_method("apply_mobile_layout"):
		page.queue_free()
		return null
	page.apply_mobile_layout()
	for _j in 6:
		await get_tree().process_frame
	## Pin our fixture — ensure_marriage_candidates may have replaced the list.
	GameState.marriage_candidates = [_cand]
	if page.has_method("_select"):
		page.call("_select", _cand)
	for _k in 4:
		await get_tree().process_frame
	page.apply_mobile_layout()
	for _n in 4:
		await get_tree().process_frame
	return page

func _audit(page: Control) -> String:
	var lead: CKCharacter = GameState.get_leader()
	var selected = page.get("_selected")
	if selected != _cand:
		return "selected is not fixture cand"
	var rites: Array = CKCourt.required_rites(lead, _cand)
	var ids: Array = []
	var bits: PackedStringArray = []
	for r in rites:
		ids.append(str(r.get("id", "")))
		bits.append(str(r.get("desc", "")))
	if not ids.has("register") or not ids.has("matrilocal"):
		return "fixture rites %s (need register+matrilocal)" % str(ids)
	var want := " ".join(bits)
	if want.length() <= 40:
		return "fixture full terms too short (%d)" % want.length()
	var msg: Label = page.find_child("RiteExplain", true, false) as Label
	if msg == null:
		return "RiteExplain missing"
	var ellipsis := Locale.t("wsc_mr_more")
	var shown := str(msg.text)
	if shown.find(ellipsis) >= 0:
		return "still ellipsized: %s" % shown
	var full := str(page.get("_full_terms"))
	if full.length() <= 40:
		return "_full_terms weak: %s" % full
	if shown != full:
		return "shown != full (%d vs %d)" % [shown.length(), full.length()]
	if shown.find("入牒") < 0 and shown.find("从母居") < 0:
		return "missing rite wording: %s" % shown
	var fs := msg.get_theme_font_size("font_size")
	if fs < MobilePage.FONT:
		return "RiteExplain font %d < %d" % [fs, MobilePage.FONT]
	if msg.clip_text:
		return "RiteExplain clip_text still true"
	if msg.custom_minimum_size.y < float(MobilePage.FONT):
		return "RiteExplain min height %.1f < font" % msg.custom_minimum_size.y
	print("rite-log ok full=%d font=%d min_h=%.1f" % [shown.length(), fs, msg.custom_minimum_size.y])
	return ""

func _set_phone_window() -> void:
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = PHONE
	await get_tree().process_frame
	await get_tree().process_frame
