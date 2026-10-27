extends Node
## 承旗整链旗面：传旗落定 → 城堡/沙漏/属地挂 BannerHandoff 旗条；
## 王朝终结卡挂 DynastyEnd 旗条；继位答卡挂 AnswerHeirArms；誓约卡三徽。
## 一整块深刀，禁止再 wave 切片。

var _fails: Array = []


func _ready() -> void:
	await get_tree().process_frame
	await _run_field_routes()
	await _run_handoff_hubs()
	await _run_dynasty_end_crest()
	await _run_succession_answers()
	await _run_vow_strip()
	_source_locale()
	if _fails.is_empty():
		print("HERALDRY BANNER HANDOFF CHAIN PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL heraldry banner handoff chain: ", f)
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)


func _settle(n: int = 3) -> void:
	for _i in n:
		await get_tree().process_frame


func _route(n: Node, want: String) -> bool:
	return n != null and str(n.get_meta("field_route", "")) == want


func _boot(tag: String) -> void:
	GameState.new_game(tag, "霜旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	World.pos = "ash_capital"
	World.arrive("ash_capital")


func _make_adult_heir(lead: CKCharacter) -> CKCharacter:
	var kid := CKCharacter.new()
	kid.id = "handoff_heir_1"
	kid.name = "承旗嗣"
	kid.age = 18
	kid.gender = "m"
	kid.family_id = str(lead.family_id) if lead != null else ""
	kid.parent_ids = [str(lead.id)] if lead != null else []
	kid.is_child = false
	kid.alive = true
	kid.in_roster = true
	kid.rank = "knight"
	kid.is_leader = false
	GameState.characters[kid.id] = kid
	GameState.lineage_path[kid.id] = "martial"
	return kid


func _open(path: String) -> Control:
	var page: Control = (load(path) as PackedScene).instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	get_tree().root.add_child(page)
	return page


func _run_field_routes() -> void:
	_boot("承旗旗面路由")
	var lead: CKCharacter = GameState.get_leader()
	var heir := _make_adult_heir(lead)
	var root := Control.new()
	root.name = "HandoffRouteHost"
	root.size = Vector2(1600, 900)
	add_child(root)
	var de := CKHeraldryField.place_dynasty_end_crest_strip(root, lead, heir, Vector2(8, 8))
	_ok(_route(de, "dynasty_end_strip"), "field dynasty_end_strip")
	_ok(de != null and str(de.find_child("DynastyEndBanner", true, false).get_meta("arms_kind", "")) == "lb_dynasty_end_arms", "field DynastyEndBanner kind")
	var ho := CKHeraldryField.place_banner_handoff_crest_strip(root, lead, heir, Vector2(200, 8))
	_ok(_route(ho, "banner_handoff_strip"), "field banner_handoff_strip")
	_ok(ho != null and str(ho.find_child("HandoffBanner", true, false).get_meta("arms_kind", "")) == "lb_handoff_arms", "field HandoffBanner kind")
	var vs := CKHeraldryField.place_vow_crest_strip(root, lead, heir, Vector2(400, 8))
	_ok(_route(vs, "vow_strip"), "field vow_strip")
	_ok(vs != null and str(vs.find_child("VowBanner", true, false).get_meta("arms_kind", "")) == "lb_vow_arms", "field VowBanner kind")
	var ans := CKHeraldryField.attach_succession_answer_arms(root, heir)
	_ok(_route(ans, "succession_answer"), "field succession_answer")
	root.queue_free()
	await _settle(2)


func _run_handoff_hubs() -> void:
	_boot("承旗旗面传旗")
	var lead: CKCharacter = GameState.get_leader()
	_ok(lead != null, "handoff leader")
	var heir := _make_adult_heir(lead)
	var rr: Dictionary = Lineage.transfer_banner("abdicate")
	_ok(bool(rr.get("ok", false)), "transfer_banner ok")
	_ok(Lineage.is_banner_handoff_pending(), "banner_handoff pending after transfer")
	var snap := Lineage.banner_handoff_snapshot()
	_ok(str(snap.get("heir_id", "")) == str(heir.id), "handoff snap heir_id")

	for path_tag in [
		["res://scenes/hub/castle_hub.tscn", "castle"],
		["res://scenes/hub/hourglass.tscn", "hourglass"],
		["res://scenes/hub/estates.tscn", "estates"],
	]:
		var page := _open(str(path_tag[0]))
		await _settle(12)
		var tag: String = str(path_tag[1])
		var panel := page.find_child("BannerHandoffPanel", true, false)
		_ok(panel != null, "%s BannerHandoffPanel" % tag)
		var strip := page.find_child("BannerHandoffCrestStrip", true, false)
		_ok(_route(strip, "banner_handoff_strip"), "%s banner_handoff_strip" % tag)
		var bn := page.find_child("HandoffBanner", true, false)
		_ok(bn != null and str(bn.get_meta("arms_kind", "")) == "lb_handoff_arms", "%s HandoffBanner kind" % tag)
		var out_a := page.find_child("OutgoingArms", true, false)
		var in_a := page.find_child("IncomingArms", true, false)
		_ok(_route(out_a, "banner_handoff_out"), "%s OutgoingArms" % tag)
		_ok(_route(in_a, "banner_handoff_in"), "%s IncomingArms" % tag)
		page.queue_free()
		await _settle(2)

	# Dismiss clears tip
	var page2 := _open("res://scenes/hub/castle_hub.tscn")
	await _settle(10)
	var btn := page2.find_child("DismissHandoff", true, false) as BaseButton
	_ok(btn != null, "DismissHandoff button")
	if btn != null:
		btn.emit_signal("pressed")
		await _settle(4)
	_ok(not Lineage.is_banner_handoff_pending(), "banner_handoff cleared on dismiss")
	page2.queue_free()
	await _settle(2)


func _run_dynasty_end_crest() -> void:
	_boot("承旗旗面终结")
	var lead: CKCharacter = GameState.get_leader()
	Lineage.note_dynasty_end("no_heir", "无嗣可承", str(lead.id) if lead else "", "")
	_ok(Lineage.is_dynasty_ended(), "dynasty ended")
	_ok(not Lineage.is_banner_handoff_pending(), "handoff cleared by dynasty end")
	for path_tag in [
		["res://scenes/hub/castle_hub.tscn", "castle"],
		["res://scenes/hub/hourglass.tscn", "hourglass"],
		["res://scenes/hub/estates.tscn", "estates"],
	]:
		var page := _open(str(path_tag[0]))
		await _settle(12)
		var tag: String = str(path_tag[1])
		var panel := page.find_child("DynastyEndPanel", true, false)
		_ok(panel != null, "%s DynastyEndPanel" % tag)
		var strip := page.find_child("DynastyEndCrestStrip", true, false)
		_ok(_route(strip, "dynasty_end_strip"), "%s dynasty_end_strip" % tag)
		var bn := page.find_child("DynastyEndBanner", true, false)
		_ok(bn != null and str(bn.get_meta("arms_kind", "")) == "lb_dynasty_end_arms", "%s DynastyEndBanner kind" % tag)
		page.queue_free()
		await _settle(2)


func _run_succession_answers() -> void:
	_boot("承旗旗面答卡")
	var lead: CKCharacter = GameState.get_leader()
	if lead != null:
		lead.rank = "baron"
	_make_adult_heir(lead)
	# Clear ambition gate so Answer_* cards show
	GameState.house_mods["dyn_amb"] = "skip_offer"
	GameState.house_mods.erase("inherit_answer_year")
	var page := _open("res://scenes/hub/inheritance.tscn")
	await _settle(14)
	var answers := 0
	for k in ["steel", "soft", "delay"]:
		var card := page.find_child("Answer_" + k, true, false)
		if card == null:
			continue
		answers += 1
		var arms := card.find_child("AnswerHeirArms", true, false)
		_ok(_route(arms, "succession_answer"), "Answer_%s succession_answer" % k)
	_ok(answers >= 1, "Answer cards present got %d" % answers)
	page.queue_free()
	await _settle(2)


func _run_vow_strip() -> void:
	_boot("承旗旗面誓约")
	var lead: CKCharacter = GameState.get_leader()
	if lead != null:
		lead.rank = "baron"
		lead.gender = "m"
	GameState.silver = 9000
	GameState.refresh_marriage_candidates("", lead)
	var page := _open("res://scenes/hub/marriage.tscn")
	await _settle(14)
	var strip := page.find_child("VowCrestStrip", true, false)
	_ok(_route(strip, "vow_strip"), "marriage VowCrestStrip")
	var vow := page.find_child("VowCompanyArms", true, false)
	_ok(_route(vow, "marriage_vow"), "marriage VowCompanyArms under strip")
	var bn := page.find_child("VowBanner", true, false)
	_ok(bn != null and str(bn.get_meta("arms_kind", "")) == "lb_vow_arms", "marriage VowBanner kind")
	page.queue_free()
	await _settle(2)


func _source_locale() -> void:
	var loc := FileAccess.get_file_as_string("res://data/locale/lineb.csv")
	for key in ["lb_dynasty_end_arms", "lb_handoff_arms", "lb_vow_arms", "lb_handoff_head", "lb_handoff_dismiss"]:
		_ok(loc.find(key + ",") >= 0, "locale has %s" % key)
	var field := FileAccess.get_file_as_string("res://scripts/art/heraldry_field.gd")
	_ok(field.find("place_dynasty_end_crest_strip") >= 0, "field has dynasty_end strip")
	_ok(field.find("place_banner_handoff_crest_strip") >= 0, "field has banner_handoff strip")
	_ok(field.find("place_vow_crest_strip") >= 0, "field has vow strip")
	_ok(field.find("attach_succession_answer_arms") >= 0, "field has succession_answer")
