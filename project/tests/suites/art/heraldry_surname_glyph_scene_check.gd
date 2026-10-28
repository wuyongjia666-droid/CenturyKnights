extends Node
## 姓氏几何单字整链：API glyph/core → naming DIY 选姓氏 emblem →
## hang / shell / company header / SlotArms / 族徽展示多表面 arms_core 一致；
## 霜/灰/兰 三姓 cores 互异；真 compose 笔画非空。

var _fails: Array = []


func _ready() -> void:
	await get_tree().process_frame
	_api_surname()
	await _run_founding_surname_surfaces()
	await _run_family_display_core()
	_source_wiring()
	if _fails.is_empty():
		print("HERALDRY SURNAME GLYPH PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL heraldry surname glyph: ", f)
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


func _center_differs(a: Image, b: Image) -> bool:
	## Compare center crop — surname strokes must change the charge region vs ring.
	var w := mini(a.get_width(), b.get_width())
	var h := mini(a.get_height(), b.get_height())
	var x0 := int(w * 0.35)
	var x1 := int(w * 0.65)
	var y0 := int(h * 0.35)
	var y1 := int(h * 0.65)
	var diff := 0
	for y in range(y0, y1):
		for x in range(x0, x1):
			var pa := a.get_pixel(x, y)
			var pb := b.get_pixel(x, y)
			if absf(pa.r - pb.r) + absf(pa.g - pb.g) + absf(pa.b - pb.b) + absf(pa.a - pb.a) > 0.35:
				diff += 1
	return diff > 12


func _api_surname() -> void:
	_ok(CKHeraldry.surname_char("霜旗") == "霜", "api surname_char 霜旗→霜")
	_ok(CKHeraldry.surname_char("灰") == "灰", "api surname_char 灰")
	_ok(CKHeraldry.surname_char("") == "", "api surname_char empty")
	_ok("surname" in BannerSpec.EMBLEMS, "api surname in EMBLEMS")
	_ok(CKHeraldry.company_emblem_id("surname") == "surname", "api company_emblem_id passes surname")

	var base := CKHeraldry.company_preset_from_nation("ashbanner")
	var frost := CKHeraldry.with_surname_emblem(base, "霜")
	var ash := CKHeraldry.with_surname_emblem(base, "灰")
	var lan := CKHeraldry.with_surname_emblem(base, "兰")
	_ok(str(frost.get("emblem", "")) == "surname", "api frost emblem=surname")
	_ok(str(frost.get("glyph_char", "")) == "霜", "api frost glyph_char")
	_ok(str(ash.get("glyph_char", "")) == "灰", "api ash glyph_char")
	_ok(str(lan.get("glyph_char", "")) == "兰", "api lan glyph_char")
	var ck_f := CKHeraldry.core_key(frost)
	var ck_a := CKHeraldry.core_key(ash)
	var ck_l := CKHeraldry.core_key(lan)
	_ok(ck_f != ck_a, "api 霜 != 灰 core")
	_ok(ck_a != ck_l, "api 灰 != 兰 core")
	_ok(ck_f != ck_l, "api 霜 != 兰 core")
	_ok(ck_f.find("霜") >= 0 or str(frost.get("glyph_char", "")) == "霜", "api core carries glyph identity")

	# Normalize round-trip keeps glyph.
	var again := CKHeraldry.normalize(frost)
	_ok(str(again.get("glyph_char", "")) == "霜", "api normalize keeps glyph_char")
	_ok(CKHeraldry.core_key(again) == ck_f, "api normalize core stable")

	# Compose smoke: surname vs ring look different; surname not empty.
	var ring := base.duplicate(true)
	ring["emblem"] = "ring"
	ring["charges"] = [{"id": "ring", "tincture": str(ring.get("emblem_color", "")), "placement": "center"}]
	ring = CKHeraldry.normalize(ring)
	var img_s := CKHeraldryRender.compose(frost, 96, 120, 0.0, "shield")
	var img_r := CKHeraldryRender.compose(ring, 96, 120, 0.0, "shield")
	_ok(_opaque_count(img_s) > 80, "api surname shield opaque")
	_ok(_center_differs(img_s, img_r), "api surname charge differs from ring")
	var img_ban := BannerSpec.compose(frost, 80, 110, 0.0)
	_ok(_opaque_count(img_ban) > 60, "api surname banner opaque")

	# Stroke segments deterministic + hit at least the frame.
	var segs := CKHeraldry.surname_stroke_segments("霜")
	_ok(segs.size() >= 4, "api stroke segments frame")
	_ok(CKHeraldry.surname_stroke_hit(0.0, -0.88, "霜"), "api stroke hit top frame")


func _assert_surfaces(want: String, where: String) -> void:
	var root := Control.new()
	root.size = Vector2(1280, 720)
	get_tree().root.add_child(root)
	var hang := CKHeraldryField.place_castle_hang_banner(root, Vector2(8, 8), Vector2(56, 78))
	_ok(hang != null, "%s hang placed" % where)
	var cloth = hang.find_child("HangCloth", true, false) if hang else null
	_ok(cloth != null and str(cloth.get_meta("arms_core", "")) == want, "%s HangCloth arms_core" % where)
	var shell := CKHeraldryField.place_shell_crest_strip(root, Vector2(100, 8))
	_ok(shell != null, "%s shell strip" % where)
	var hdr := CKHeraldryField.place_company_header(root, Vector2(280, 8))
	_ok(hdr != null, "%s company header" % where)
	var live := CKHeraldry.core_key(BannerSpec.normalize(GameState.banner_spec))
	_ok(live == want, "%s live GameState core" % where)
	var bn = root.find_child("ShellBanner", true, false)
	if bn != null and str(bn.get_meta("arms_core", "")) != "":
		_ok(str(bn.get_meta("arms_core", "")) == want, "%s ShellBanner core" % where)
	var arms = root.find_child("CastleArms", true, false)
	if arms != null and str(arms.get_meta("arms_core", "")) != "":
		_ok(str(arms.get_meta("arms_core", "")) == want, "%s CastleArms core" % where)
	var row := HBoxContainer.new()
	root.add_child(row)
	var slot := CKHeraldryField.attach_save_row_arms(row, Vector2(36, 44), str(GameState.crest_color), GameState.banner_spec.duplicate(true))
	_ok(slot != null and str(slot.get_meta("arms_core", "")) == want, "%s SlotArms core" % where)
	root.queue_free()


func _run_founding_surname_surfaces() -> void:
	_boot("姓氏单字开局")
	var page := _open("res://scenes/story/naming.tscn")
	await _settle(6)
	var surname_ix := BannerSpec.EMBLEMS.find("surname")
	_ok(surname_ix >= 0, "founding surname emblem index")
	page.set("_emblem_idx", surname_ix)
	var le: LineEdit = page.get("_surname")
	_ok(le != null, "founding surname LineEdit")
	if le:
		le.text = "霜"
		le.text_changed.emit("霜")
	await _settle(4)
	page.call("_refresh_preview_art")
	await _settle(4)
	var spec: Dictionary = page.call("_current_spec")
	_ok(str(spec.get("emblem", "")) == "surname", "founding emblem=surname")
	_ok(str(spec.get("glyph_char", "")) == "霜", "founding glyph_char=霜")
	var lab: Label = page.get("_emblem_label")
	if lab:
		_ok(str(lab.text).find("霜") >= 0 or str(lab.text).find(Locale.t("ux_emblem_surname")) >= 0, "founding emblem label shows surname")
	GameState.banner_spec = BannerSpec.normalize(spec)
	GameState.surname = "霜"
	GameState.crest_color = str(page.call("_heart"))
	UnitArt.clear_cache()
	var want := CKHeraldry.core_key(spec)
	_assert_surfaces(want, "founding/surname-霜")

	# Switch glyph via typing → core changes, surfaces follow.
	if le:
		le.text = "兰"
		le.text_changed.emit("兰")
	await _settle(4)
	page.call("_refresh_preview_art")
	await _settle(4)
	var spec2: Dictionary = page.call("_current_spec")
	_ok(str(spec2.get("glyph_char", "")) == "兰", "founding retarget glyph=兰")
	_ok(CKHeraldry.core_key(spec2) != want, "founding 兰 core != 霜 core")
	GameState.banner_spec = BannerSpec.normalize(spec2)
	GameState.surname = "兰"
	UnitArt.clear_cache()
	_assert_surfaces(CKHeraldry.core_key(spec2), "founding/surname-兰")
	page.queue_free()
	await _settle(2)


func _run_family_display_core() -> void:
	_boot("姓氏单字族徽")
	var company := CKHeraldry.with_surname_emblem(CKHeraldry.company_preset_from_nation("qinghe"), "霜")
	GameState.banner_spec = company
	UnitArt.clear_cache()
	var core := CKHeraldry.randomize_for_nation("qinghe")
	core = CKHeraldry.with_surname_emblem(core, "霜")
	var display := CKHeraldry.family_display_arms(core, company, "noble")
	_ok(str(display.get("glyph_char", "")) == "霜", "family display keeps glyph_char")
	# family_display_arms may append tier ornaments; surname glyph charge must remain.
	var has_surname := false
	for c in display.get("charges", []):
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var cd: Dictionary = c
		if str(cd.get("id", "")) == "surname":
			has_surname = true
			_ok(str(cd.get("glyph", "")) == "霜", "family surname charge glyph")
	_ok(has_surname, "family keeps surname charge")
	var img := CKHeraldryRender.compose(display, 96, 120, 0.0, "arms")
	_ok(_opaque_count(img) > 80, "family surname arms opaque")


func _source_wiring() -> void:
	var naming := FileAccess.get_file_as_string("res://scripts/story/naming.gd")
	_ok(naming.find("ux_emblem_surname") >= 0 or naming.find("\"surname\"") >= 0, "naming knows surname emblem")
	_ok(naming.find("glyph_char") >= 0, "naming writes glyph_char")
	_ok(naming.find("surname_char") >= 0, "naming uses surname_char")
	var her := FileAccess.get_file_as_string("res://scripts/art/heraldry.gd")
	_ok(her.find("with_surname_emblem") >= 0, "heraldry with_surname_emblem")
	_ok(her.find("surname_stroke_segments") >= 0, "heraldry stroke segments")
	var vec := FileAccess.get_file_as_string("res://scripts/art/heraldry_vector.gd")
	_ok(vec.find("_surname_frag") >= 0, "vector _surname_frag")
	var ren := FileAccess.get_file_as_string("res://scripts/art/heraldry_render.gd")
	_ok(ren.find("surname_stroke_hit") >= 0, "render surname_stroke_hit")
	var ux := FileAccess.get_file_as_string("res://data/locale/ux.csv")
	_ok(ux.find("ux_emblem_surname") >= 0, "locale ux_emblem_surname")
	var bs := FileAccess.get_file_as_string("res://scripts/art/banner_spec.gd")
	_ok(bs.find("\"surname\"") >= 0, "BannerSpec.EMBLEMS has surname")
