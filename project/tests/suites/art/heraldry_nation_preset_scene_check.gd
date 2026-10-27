extends Node
## 国别套装整链：十国一键套装 → naming 预览/_current_spec → 存档 meta 全旗 →
## hang / shell / company header / SlotArms 多表面 arms_core 一致；再编辑路径同测。

var _fails: Array = []

const TEN_NATIONS := ["ashbanner", "shuoying", "qinghe", "lantern", "frostcrown", "emberold", "saltmarsh", "irongorge", "starriver", "southzephyr"]


func _ready() -> void:
	await get_tree().process_frame
	_api_preset_ash()
	await _run_founding_apply_surfaces()
	await _run_reedit_apply_surfaces()
	await _run_save_meta_slot_arms()
	_source_wiring()
	if _fails.is_empty():
		print("HERALDRY NATION PRESET PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL heraldry nation preset: ", f)
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


func _api_preset_ash() -> void:
	var ash := CKHeraldry.tincture_hex("ash").to_lower()
	var deep := CKHeraldry.tincture_hex("ash_deep").to_lower()
	var cores: Dictionary = {}
	for nid in TEN_NATIONS:
		var p := CKHeraldry.company_preset_from_nation(nid)
		_ok(str(p.get("nation", "")) == nid, "api nation=%s" % nid)
		_ok(str(p.get("field_a", "")).to_lower() == ash, "api %s ash field" % nid)
		_ok(str(p.get("field_b", "")).to_lower() == deep, "api %s ash_deep pair" % nid)
		var eid := str(p.get("emblem", ""))
		_ok(eid in BannerSpec.EMBLEMS, "api %s emblem in DIY slots (%s)" % [nid, eid])
		var shape := str(p.get("shield_shape", ""))
		_ok(shape != "", "api %s shield_shape set" % nid)
		var a := CKHeraldry.company_preset_from_nation(nid)
		var b := CKHeraldry.company_preset_from_nation(nid)
		_ok(CKHeraldry.core_key(a) == CKHeraldry.core_key(b), "api %s deterministic" % nid)
		cores[nid] = CKHeraldry.core_key(a)
	# Neighbors in the list must not collapse (ten-nation visual lock).
	for i in range(TEN_NATIONS.size() - 1):
		var left := str(TEN_NATIONS[i])
		var right := str(TEN_NATIONS[i + 1])
		_ok(str(cores[left]) != str(cores[right]), "api %s != %s core" % [left, right])


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
	# ShellBanner / company arms meta when present.
	var bn = root.find_child("ShellBanner", true, false)
	if bn != null and str(bn.get_meta("arms_core", "")) != "":
		_ok(str(bn.get_meta("arms_core", "")) == want, "%s ShellBanner core" % where)
	var arms = root.find_child("CastleArms", true, false)
	if arms != null and str(arms.get_meta("arms_core", "")) != "":
		_ok(str(arms.get_meta("arms_core", "")) == want, "%s CastleArms core" % where)
	# SlotArms from meta banner_spec (not live).
	var row := HBoxContainer.new()
	root.add_child(row)
	var slot := CKHeraldryField.attach_save_row_arms(row, Vector2(36, 44), str(GameState.crest_color), GameState.banner_spec.duplicate(true))
	_ok(slot != null and str(slot.get_meta("arms_core", "")) == want, "%s SlotArms core from banner_spec" % where)
	root.queue_free()


func _run_founding_apply_surfaces() -> void:
	_boot("国别套装开局")
	var page := _open("res://scenes/story/naming.tscn")
	await _settle(6)
	_ok(page.find_child("NationPresetStrip", true, false) != null, "founding NationPresetStrip")
	_ok(page.find_child("NationPresetBtn", true, false) != null, "founding NationPresetBtn")
	for nid in TEN_NATIONS:
		_ok(page.find_child("NationPreset_%s" % nid, true, false) != null, "founding chip %s" % nid)
	var nations := ["ashbanner", "qinghe", "starriver", "emberold", "southzephyr"]
	var cores: Dictionary = {}
	for nid in nations:
		_ok(page.has_method("_on_apply_nation_preset"), "founding apply API")
		page.call("_on_apply_nation_preset", nid)
		await _settle(3)
		var spec: Dictionary = page.call("_current_spec")
		_ok(str(spec.get("nation", "")) == nid, "founding _current_spec nation=%s" % nid)
		_ok(str(spec.get("field_a", "")).to_lower() == CKHeraldry.tincture_hex("ash").to_lower(), "founding %s ash cloth" % nid)
		var core := CKHeraldry.core_key(spec)
		cores[nid] = core
		GameState.banner_spec = BannerSpec.normalize(spec)
		GameState.crest_color = str(page.call("_heart"))
		UnitArt.clear_cache()
		_assert_surfaces(core, "founding/%s" % nid)
	# Applied nations must not collapse (style lock still distinct).
	_ok(cores["ashbanner"] != cores["qinghe"], "ashbanner != qinghe core")
	_ok(cores["qinghe"] != cores["starriver"], "qinghe != starriver core")
	_ok(cores["starriver"] != cores["emberold"], "starriver != emberold core")
	_ok(cores["emberold"] != cores["southzephyr"], "emberold != southzephyr core")
	page.queue_free()
	await _settle(2)


func _run_reedit_apply_surfaces() -> void:
	_boot("国别套装再编")
	var page := _open("res://scenes/story/naming.tscn")
	await _settle(4)
	page.set("_reedit", true)
	page.call("_apply_reedit_mode")
	await _settle(2)
	page.call("_on_apply_nation_preset", "shuoying")
	await _settle(3)
	var spec: Dictionary = page.call("_current_spec")
	_ok(str(spec.get("nation", "")) == "shuoying", "reedit applied shuoying")
	GameState.banner_spec = BannerSpec.normalize(spec)
	GameState.crest_color = str(page.call("_heart"))
	UnitArt.clear_cache()
	var want := CKHeraldry.core_key(spec)
	_assert_surfaces(want, "reedit/shuoying")
	# Save button stays reedit-labeled.
	var start: Button = page.get("_start_btn")
	_ok(start != null and str(start.text) == Locale.t("ux_banner_reedit_save"), "reedit save label kept")
	page.queue_free()
	await _settle(2)


func _run_save_meta_slot_arms() -> void:
	_boot("存档条全旗")
	var preset := CKHeraldry.company_preset_from_nation("irongorge")
	GameState.banner_spec = preset
	GameState.crest_color = str(preset.get("ordinary_tincture", GameState.crest_color))
	UnitArt.clear_cache()
	var slot := "manual_0"
	_ok(GameState.save_to_slot(slot), "save_to_slot")
	var meta := CKSaveService.read_meta(slot)
	_ok(typeof(meta.get("banner_spec", null)) == TYPE_DICTIONARY, "meta has banner_spec")
	var meta_spec: Dictionary = meta.get("banner_spec", {})
	_ok(not meta_spec.is_empty(), "meta banner_spec non-empty")
	var want := CKHeraldry.core_key(BannerSpec.normalize(meta_spec))
	_ok(want == CKHeraldry.core_key(preset), "meta core matches preset")
	# Flip live so a live-only attach would diverge.
	GameState.banner_spec = CKHeraldry.company_preset_from_nation("lantern")
	GameState.crest_color = CKHeraldry.tincture_hex("azure")
	UnitArt.clear_cache()
	var page := _open("res://scenes/ui/save_slots.tscn")
	await _settle(10)
	var row = page.find_child("SlotRow_%s" % slot, true, false)
	_ok(row != null, "meta SlotRow")
	if row != null:
		var arms = row.find_child("SlotArms", true, false)
		_ok(arms != null, "meta SlotArms")
		if arms != null:
			_ok(str(arms.get_meta("arms_core", "")) == want, "SlotArms core from meta banner_spec not live")
	page.queue_free()
	await _settle(2)


func _source_wiring() -> void:
	var naming := FileAccess.get_file_as_string("res://scripts/story/naming.gd")
	_ok(naming.find("NationPresetStrip") >= 0, "naming hosts NationPresetStrip")
	_ok(naming.find("_on_apply_nation_preset") >= 0, "naming apply preset")
	_ok(naming.find("company_preset_from_nation") >= 0, "naming uses company_preset")
	var field := FileAccess.get_file_as_string("res://scripts/art/heraldry_field.gd")
	_ok(field.find("banner_spec: Dictionary") >= 0, "Field attach accepts banner_spec")
	var chrome := FileAccess.get_file_as_string("res://scripts/art/heraldry_chrome.gd")
	_ok(chrome.find("banner_spec: Dictionary = {}") >= 0, "Chrome shim forwards banner_spec")
	var slots := FileAccess.get_file_as_string("res://scripts/core/save_slots.gd")
	_ok(slots.find("banner_spec") >= 0, "save_slots passes banner_spec")
	var gs := FileAccess.get_file_as_string("res://autoload/game_state.gd")
	_ok(gs.find('"banner_spec": banner_spec.duplicate') >= 0, "save_meta writes banner_spec")
	var ux := FileAccess.get_file_as_string("res://data/locale/ux.csv")
	_ok(ux.find("ux_name_nation_preset_btn") >= 0, "locale preset btn")
	_ok(ux.find("ux_name_nation_preset_strip") >= 0, "locale preset strip")
	_ok(ux.find("ux_nation_preset_tip") >= 0, "locale preset tip")
