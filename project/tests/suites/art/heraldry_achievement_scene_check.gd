extends Node
## 成就盔冠幔整链：API company_preset 保留 achievement → naming DIY 盔/冠/格言 →
## 预览 compose_arms + meta；CastleArms/SlotArms stamp 同源；HangCloth 不吃盔冠格言。

var _fails: Array = []


func _ready() -> void:
	await get_tree().process_frame
	_api_preset_and_helpers()
	await _run_founding_achievement()
	_assert_surface_meta()
	_source_wiring()
	if _fails.is_empty():
		print("HERALDRY ACHIEVEMENT PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL heraldry achievement: ", f)
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)


func _settle(n: int = 4) -> void:
	for _i in n:
		await get_tree().process_frame


func _boot(tag: String) -> void:
	GameState.new_game(tag, "霜旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	GameState.set_flag("hub_open", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	World.pos = "ash_capital"
	World.arrive("ash_capital")


func _open(path: String) -> Control:
	var page: Control = (load(path) as PackedScene).instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	get_tree().root.add_child(page)
	return page


func _opaque_count(img: Image) -> int:
	var n := 0
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.1:
				n += 1
	return n


func _api_preset_and_helpers() -> void:
	_ok(CKHeraldry.helm_ids().size() >= 4, "api helm_ids")
	_ok(CKHeraldry.crown_ids().size() >= 5, "api crown_ids")
	_ok(CKHeraldry.helm_ids().find("closed") >= 0, "api helm has closed")
	_ok(CKHeraldry.crown_ids().find("knight") >= 0, "api crown has knight")

	var bare := CKHeraldry.normalize({"schema": 2, "field_a": CKHeraldry.tincture_hex("ash")})
	_ok(not CKHeraldry.has_achievement_ornament(bare), "api bare has no ornament")

	var preset := CKHeraldry.company_preset_from_nation("ashbanner")
	var ach: Dictionary = preset.get("achievement", {})
	_ok(typeof(ach) == TYPE_DICTIONARY, "api preset has achievement dict")
	_ok(str(ach.get("helm", "none")) == "closed", "api preset knight helm=closed")
	_ok(str(ach.get("crown", "none")) == "knight", "api preset knight crown=knight")
	_ok(str(ach.get("motto", "")).strip_edges() == "灰旗不落", "api preset motto 灰旗不落")
	_ok(str(ach.get("mantling_a", "")) == CKHeraldry.tincture_hex("ash"), "api preset mantling_a=ash")
	_ok(CKHeraldry.has_achievement_ornament(preset), "api preset has ornament")

	var qing := CKHeraldry.company_preset_from_nation("qinghe")
	var qach: Dictionary = qing.get("achievement", {})
	_ok(str(qach.get("motto", "")).strip_edges() == "水德常清", "api qinghe motto")

	var img_a := BannerSpec.compose_arms(preset, 96, 120)
	var img_s := BannerSpec.compose_shield(preset, 96, 120)
	_ok(_opaque_count(img_a) > 80, "api achievement arms opaque")
	_ok(_opaque_count(img_s) > 60, "api shield opaque")
	var top_diff := 0
	var tw := mini(img_a.get_width(), img_s.get_width())
	var th := mini(12, mini(img_a.get_height(), img_s.get_height()))
	for y in range(th):
		for x in range(tw):
			var pa := img_a.get_pixel(x, y)
			var pb := img_s.get_pixel(x, y)
			if absf(pa.a - pb.a) + absf(pa.r - pb.r) > 0.25:
				top_diff += 1
	_ok(top_diff > 8, "api arms top differs from shield (helm/crown)")

	var tr := TextureRect.new()
	CKHeraldry.stamp_achievement_meta(tr, preset)
	_ok(str(tr.get_meta("arms_helm", "")) == "closed", "api stamp arms_helm")
	_ok(str(tr.get_meta("arms_crown", "")) == "knight", "api stamp arms_crown")
	_ok(str(tr.get_meta("arms_motto", "")) == "灰旗不落", "api stamp arms_motto")
	tr.free()


func _run_founding_achievement() -> void:
	_boot("成就盔冠开局")
	var page := _open("res://scenes/story/naming.tscn")
	await _settle(6)

	page.call("_on_apply_nation_preset", "ashbanner")
	await _settle(4)
	var spec: Dictionary = page.call("_current_spec")
	var ach: Dictionary = spec.get("achievement", {})
	_ok(str(ach.get("helm", "")) == "closed", "founding preset helm=closed")
	_ok(str(ach.get("crown", "")) == "knight", "founding preset crown=knight")
	_ok(str(ach.get("motto", "")).strip_edges() == "灰旗不落", "founding preset motto")
	_ok(str(ach.get("mantling_a", "")) == CKHeraldry.tincture_hex("ash"), "founding mantling_a=ash")

	var helm_lab: Label = page.find_child("HelmLabel", true, false)
	_ok(helm_lab != null, "founding HelmLabel")
	if helm_lab:
		_ok(str(helm_lab.text).find(Locale.t("ux_helm_closed")) >= 0 or str(helm_lab.text) != "", "founding helm label")

	var motto_le: LineEdit = page.find_child("MottoEdit", true, false)
	_ok(motto_le != null and str(motto_le.text).strip_edges() == "灰旗不落", "founding MottoEdit text")

	page.set("_helm_idx", CKHeraldry.helm_ids().find("grilled"))
	page.set("_crown_idx", CKHeraldry.crown_ids().find("baron"))
	if motto_le:
		motto_le.text = "霜下不屈"
		motto_le.text_changed.emit("霜下不屈")
	page.call("_refresh_preview_art")
	await _settle(4)
	var spec2: Dictionary = page.call("_current_spec")
	var ach2: Dictionary = spec2.get("achievement", {})
	_ok(str(ach2.get("helm", "")) == "grilled", "founding DIY helm=grilled")
	_ok(str(ach2.get("crown", "")) == "baron", "founding DIY crown=baron")
	_ok(str(ach2.get("motto", "")) == "霜下不屈", "founding DIY motto")

	var shield: TextureRect = page.get("_shield")
	_ok(shield != null, "founding preview shield")
	if shield:
		_ok(str(shield.get_meta("arms_helm", "")) == "grilled", "founding shield meta helm")
		_ok(str(shield.get_meta("arms_crown", "")) == "baron", "founding shield meta crown")
		_ok(str(shield.get_meta("arms_motto", "")) == "霜下不屈", "founding shield meta motto")
		_ok(shield.texture != null, "founding shield texture")

	GameState.banner_spec = BannerSpec.normalize(spec2)
	GameState.crest_color = str(page.call("_heart"))
	UnitArt.clear_cache()
	page.queue_free()
	await _settle(2)


func _assert_surface_meta() -> void:
	var want_helm := "grilled"
	var want_crown := "baron"
	var want_motto := "霜下不屈"
	var live: Dictionary = BannerSpec.normalize(GameState.banner_spec)
	var lach: Dictionary = live.get("achievement", {})
	_ok(str(lach.get("helm", "")) == want_helm, "live GameState helm")
	_ok(str(lach.get("crown", "")) == want_crown, "live GameState crown")

	var root := Control.new()
	root.size = Vector2(1280, 720)
	get_tree().root.add_child(root)

	var hang := CKHeraldryField.place_castle_hang_banner(root, Vector2(8, 8), Vector2(56, 78))
	_ok(hang != null, "surface hang placed")
	var cloth = hang.find_child("HangCloth", true, false) if hang else null
	_ok(cloth != null, "surface HangCloth")
	if cloth:
		_ok(str(cloth.get_meta("arms_helm", "X")) == "none", "HangCloth arms_helm=none")
		_ok(str(cloth.get_meta("arms_crown", "X")) == "none", "HangCloth arms_crown=none")
		_ok(str(cloth.get_meta("arms_motto", "X")) == "", "HangCloth arms_motto empty")
		_ok(str(cloth.get_meta("shield_shape", "")) == "cloth", "HangCloth shield_shape=cloth")

	var hdr := CKHeraldryField.place_company_header(root, Vector2(280, 8))
	_ok(hdr != null, "surface company header")
	if hdr:
		_ok(str(hdr.get_meta("arms_helm", "")) == want_helm, "CastleArms arms_helm")
		_ok(str(hdr.get_meta("arms_crown", "")) == want_crown, "CastleArms arms_crown")
		_ok(str(hdr.get_meta("arms_motto", "")) == want_motto, "CastleArms arms_motto")

	var row := HBoxContainer.new()
	root.add_child(row)
	var slot := CKHeraldryField.attach_save_row_arms(row, Vector2(36, 44), str(GameState.crest_color), GameState.banner_spec.duplicate(true))
	_ok(slot != null, "surface SlotArms")
	if slot:
		_ok(str(slot.get_meta("arms_helm", "")) == want_helm, "SlotArms arms_helm")
		_ok(str(slot.get_meta("arms_crown", "")) == want_crown, "SlotArms arms_crown")
		_ok(str(slot.get_meta("arms_motto", "")) == want_motto, "SlotArms arms_motto")

	root.queue_free()


func _source_wiring() -> void:
	var naming := FileAccess.get_file_as_string("res://scripts/story/naming.gd")
	_ok(naming.find("ux_name_helm") >= 0, "naming knows helm")
	_ok(naming.find("ux_name_crown") >= 0, "naming knows crown")
	_ok(naming.find("ux_name_motto") >= 0, "naming knows motto")
	_ok(naming.find("compose_arms") >= 0, "naming compose_arms preview")
	_ok(naming.find("stamp_achievement_meta") >= 0, "naming stamps achievement meta")
	var her := FileAccess.get_file_as_string("res://scripts/art/heraldry.gd")
	_ok(her.find("has_achievement_ornament") >= 0, "heraldry has_achievement_ornament")
	_ok(her.find("achievement") >= 0, "heraldry company_preset achievement")
	var chrome := FileAccess.get_file_as_string("res://scripts/art/heraldry_chrome.gd")
	_ok(chrome.find("achievement_arms") >= 0 and chrome.find("stamp_achievement_meta") >= 0, "chrome company arms achievement")
	var field := FileAccess.get_file_as_string("res://scripts/art/heraldry_field.gd")
	_ok(field.find("clear_achievement_meta_cloth") >= 0, "field stamps/clears arms_helm")
	var ux := FileAccess.get_file_as_string("res://data/locale/ux.csv")
	_ok(ux.find("ux_name_helm") >= 0 and ux.find("ux_helm_closed") >= 0, "locale helm keys")
	_ok(ux.find("ux_name_motto") >= 0 and ux.find("ux_crown_knight") >= 0, "locale motto/crown keys")
