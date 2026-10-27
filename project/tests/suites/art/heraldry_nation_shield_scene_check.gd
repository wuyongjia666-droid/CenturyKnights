extends Node
## 国别盾形盾面整链：十国推荐盾形 → naming DIY 可微调 →
## naming 预览盾 / SlotArms / shell CastleArms / 顶栏 CastleArms 同源真形；
## HangCloth 仍为矩形旗布（meta=cloth，不吃国别盾形）。

var _fails: Array = []

const TEN_NATIONS := ["ashbanner", "shuoying", "qinghe", "lantern", "frostcrown", "emberold", "saltmarsh", "irongorge", "starriver", "southzephyr"]
const SHAPES := ["heater", "kite", "round", "lozenge", "banner"]


func _ready() -> void:
	await get_tree().process_frame
	_api_nation_shapes()
	await _run_founding_shapes_surfaces()
	await _run_shape_fine_tune()
	await _run_save_meta_slot_shape()
	_source_wiring()
	if _fails.is_empty():
		print("HERALDRY NATION SHIELD PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL heraldry nation shield: ", f)
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


func _expect_shape(nid: String) -> String:
	return str(CKHeraldry.nation_style(nid).get("shield", "heater"))


func _api_nation_shapes() -> void:
	var seen: Dictionary = {}
	for nid in TEN_NATIONS:
		var p := CKHeraldry.company_preset_from_nation(nid)
		var want := _expect_shape(nid)
		_ok(str(p.get("shield_shape", "")) == want, "api %s shield_shape=%s" % [nid, want])
		_ok(want in SHAPES, "api %s shape in table (%s)" % [nid, want])
		seen[want] = true
	# Table must expose at least 4 distinct silhouettes across ten nations.
	_ok(seen.size() >= 4, "api ≥4 distinct nation shapes (%d)" % seen.size())


func _assert_shield_surfaces(want_shape: String, want_core: String, where: String) -> void:
	var root := Control.new()
	root.size = Vector2(1280, 720)
	get_tree().root.add_child(root)
	var hang := CKHeraldryField.place_castle_hang_banner(root, Vector2(8, 8), Vector2(56, 78))
	_ok(hang != null, "%s hang placed" % where)
	var cloth = hang.find_child("HangCloth", true, false) if hang else null
	_ok(cloth != null and str(cloth.get_meta("arms_core", "")) == want_core, "%s HangCloth arms_core" % where)
	_ok(cloth != null and str(cloth.get_meta("shield_shape", "")) == "cloth", "%s HangCloth is cloth not nation silhouette" % where)
	var shell := CKHeraldryField.place_shell_crest_strip(root, Vector2(100, 8))
	_ok(shell != null, "%s shell strip" % where)
	var arms = root.find_child("CastleArms", true, false)
	_ok(arms != null, "%s CastleArms present" % where)
	if arms != null:
		_ok(str(arms.get_meta("arms_core", "")) == want_core, "%s CastleArms core" % where)
		_ok(str(arms.get_meta("shield_shape", "")) == want_shape, "%s CastleArms shape=%s" % [where, want_shape])
	var hdr := CKHeraldryField.place_company_header(root, Vector2(280, 8))
	_ok(hdr != null, "%s company header" % where)
	if hdr != null:
		_ok(str(hdr.get_meta("shield_shape", "")) == want_shape, "%s header shape=%s" % [where, want_shape])
		_ok(str(hdr.get_meta("arms_core", "")) == want_core, "%s header core" % where)
	var row := HBoxContainer.new()
	root.add_child(row)
	var slot := CKHeraldryField.attach_save_row_arms(row, Vector2(36, 44), str(GameState.crest_color), GameState.banner_spec.duplicate(true))
	_ok(slot != null and str(slot.get_meta("arms_core", "")) == want_core, "%s SlotArms core" % where)
	_ok(slot != null and str(slot.get_meta("shield_shape", "")) == want_shape, "%s SlotArms shape=%s" % [where, want_shape])
	# Silhouette lock: kite/round/lozenge/banner must not paint identical alpha masks to heater.
	if want_shape != "heater":
		var heater_spec := BannerSpec.normalize(GameState.banner_spec.duplicate(true))
		heater_spec["shield_shape"] = "heater"
		var a := BannerSpec.compose_shield(BannerSpec.normalize(GameState.banner_spec), 64, 74)
		var b := BannerSpec.compose_shield(heater_spec, 64, 74)
		_ok(_alpha_mask_differs(a, b), "%s silhouette %s ≠ heater" % [where, want_shape])
	root.queue_free()


func _alpha_mask_differs(a: Image, b: Image) -> bool:
	if a == null or b == null:
		return false
	if a.get_width() != b.get_width() or a.get_height() != b.get_height():
		return true
	var diffs := 0
	for y in range(a.get_height()):
		for x in range(a.get_width()):
			var aa := a.get_pixel(x, y).a > 0.04
			var bb := b.get_pixel(x, y).a > 0.04
			if aa != bb:
				diffs += 1
	return diffs > 24


func _run_founding_shapes_surfaces() -> void:
	_boot("国别盾形开局")
	var page := _open("res://scenes/story/naming.tscn")
	await _settle(6)
	_ok(page.find_child("ShieldShapeLabel", true, false) != null, "founding ShieldShapeLabel")
	# Probe nations with non-heater defaults + one heater control.
	var nations := ["ashbanner", "shuoying", "qinghe", "lantern", "starriver"]
	for nid in nations:
		page.call("_on_apply_nation_preset", nid)
		await _settle(3)
		var spec: Dictionary = page.call("_current_spec")
		var want := _expect_shape(nid)
		_ok(str(spec.get("shield_shape", "")) == want, "founding %s _current_spec shape=%s" % [nid, want])
		var sh = page.get("_shield")
		_ok(sh != null and str(sh.get_meta("shield_shape", "")) == want, "founding %s preview shield meta" % nid)
		GameState.banner_spec = BannerSpec.normalize(spec)
		GameState.crest_color = str(page.call("_heart"))
		UnitArt.clear_cache()
		_assert_shield_surfaces(want, CKHeraldry.core_key(spec), "founding/%s" % nid)
	page.queue_free()
	await _settle(2)


func _run_shape_fine_tune() -> void:
	_boot("盾形微调")
	var page := _open("res://scenes/story/naming.tscn")
	await _settle(6)
	page.call("_on_apply_nation_preset", "shuoying")  # kite
	await _settle(2)
	_ok(str(page.call("_current_spec").get("shield_shape", "")) == "kite", "tune start kite")
	# Flip DIY shape to lozenge without changing nation.
	page.call("_shift_enum", "shape", 1)  # may land on next in table order
	# Force lozenge explicitly via repeated shift until match (table order fixed).
	var guard := 0
	while str(page.call("_current_spec").get("shield_shape", "")) != "lozenge" and guard < 8:
		page.call("_shift_enum", "shape", 1)
		guard += 1
	await _settle(2)
	var spec: Dictionary = page.call("_current_spec")
	_ok(str(spec.get("nation", "")) == "shuoying", "tune keeps nation shuoying")
	_ok(str(spec.get("shield_shape", "")) == "lozenge", "tune shape → lozenge")
	var sh = page.get("_shield")
	_ok(sh != null and str(sh.get_meta("shield_shape", "")) == "lozenge", "tune preview meta lozenge")
	GameState.banner_spec = BannerSpec.normalize(spec)
	GameState.crest_color = str(page.call("_heart"))
	UnitArt.clear_cache()
	_assert_shield_surfaces("lozenge", CKHeraldry.core_key(spec), "tune/lozenge")
	# Reedit path: load + keep tuned shape.
	page.set("_reedit", true)
	page.call("_apply_reedit_mode")
	await _settle(2)
	page.call("_load_from_banner_spec", GameState.banner_spec)
	await _settle(2)
	_ok(str(page.call("_current_spec").get("shield_shape", "")) == "lozenge", "reedit keeps tuned lozenge")
	page.queue_free()
	await _settle(2)


func _run_save_meta_slot_shape() -> void:
	_boot("存档条盾形")
	var preset := CKHeraldry.company_preset_from_nation("starriver")  # lozenge
	GameState.banner_spec = preset
	GameState.crest_color = str(preset.get("ordinary_tincture", GameState.crest_color))
	UnitArt.clear_cache()
	var slot := "manual_0"
	_ok(GameState.save_to_slot(slot), "save_to_slot")
	var meta := CKSaveService.read_meta(slot)
	var meta_spec: Dictionary = meta.get("banner_spec", {})
	_ok(str(meta_spec.get("shield_shape", "")) == "lozenge", "meta banner_spec shield_shape=lozenge")
	# Flip live so live-only attach would diverge.
	GameState.banner_spec = CKHeraldry.company_preset_from_nation("ashbanner")
	UnitArt.clear_cache()
	var page := _open("res://scenes/ui/save_slots.tscn")
	await _settle(10)
	var row = page.find_child("SlotRow_%s" % slot, true, false)
	_ok(row != null, "meta SlotRow")
	if row != null:
		var arms = row.find_child("SlotArms", true, false)
		_ok(arms != null, "meta SlotArms")
		if arms != null:
			_ok(str(arms.get_meta("shield_shape", "")) == "lozenge", "SlotArms shape from meta not live")
			_ok(str(arms.get_meta("arms_core", "")) == CKHeraldry.core_key(BannerSpec.normalize(meta_spec)), "SlotArms core from meta")
	page.queue_free()
	await _settle(2)


func _source_wiring() -> void:
	var naming := FileAccess.get_file_as_string("res://scripts/story/naming.gd")
	_ok(naming.find("ShieldShapeLabel") >= 0, "naming hosts ShieldShapeLabel")
	_ok(naming.find("_shape_idx") >= 0, "naming shape idx")
	_ok(naming.find("_sync_shape_from_nation") >= 0, "naming sync shape from nation")
	_ok(naming.find("ux_name_shield_shape") >= 0, "naming locale key wired")
	var chrome := FileAccess.get_file_as_string("res://scripts/art/heraldry_chrome.gd")
	_ok(chrome.find('set_meta("shield_shape"') >= 0, "chrome stamps shield_shape")
	var field := FileAccess.get_file_as_string("res://scripts/art/heraldry_field.gd")
	_ok(field.find('set_meta("shield_shape"') >= 0, "field stamps shield_shape")
	_ok(field.find('set_meta("shield_shape", "cloth")') >= 0, "hang cloth marked cloth")
	var render := FileAccess.get_file_as_string("res://scripts/art/heraldry_render.gd")
	_ok(render.find('cloth_spec["shield_shape"] = "heater"') >= 0, "render cloth still forces heater")
	var ux := FileAccess.get_file_as_string("res://data/locale/ux.csv")
	for k in ["ux_name_shield_shape", "ux_shield_heater", "ux_shield_kite", "ux_shield_round", "ux_shield_lozenge", "ux_shield_banner"]:
		_ok(ux.find(k) >= 0, "locale %s" % k)
