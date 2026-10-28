extends Node
## 成就面多表面收口：扶盾 DIY + 国别对真兽 + hub/挂旗/壳/顶栏/slot/存档条同源 stamp；
## 挂布/壳布强制 bare；真打开 naming / castle_view / save_slots / main_menu。

var _fails: Array = []


func _ready() -> void:
	await get_tree().process_frame
	_api_supporters_and_rank()
	await _run_founding_diy_supporters()
	await _run_field_surfaces_meta()
	await _run_castle_view_hang_bare()
	await _run_save_slots_and_menu_e2e()
	_source_wiring()
	if _fails.is_empty():
		print("HERALDRY ACHIEVEMENT SURFACES PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL heraldry achievement surfaces: ", f)
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


func _api_supporters_and_rank() -> void:
	var ids := CKHeraldry.supporter_ids()
	_ok(ids.size() >= 7, "api supporter_ids >=7")
	_ok(ids.find("none") == 0, "api supporter none first")
	for want in ["stag", "wolf", "crane", "eagle", "bear", "seadrake"]:
		_ok(ids.find(want) >= 0, "api has %s" % want)

	var ash_pair: Array = CKHeraldry.nation_supporter_pair("ashbanner")
	_ok(str(ash_pair[0]) == "wolf" and str(ash_pair[1]) == "wolf", "api ashbanner pair wolf/wolf")
	var qing_pair: Array = CKHeraldry.nation_supporter_pair("qinghe")
	_ok(str(qing_pair[0]) == "crane" and str(qing_pair[1]) == "crane", "api qinghe pair crane/crane")

	var bare := CKHeraldry.normalize({"schema": 2, "field_a": CKHeraldry.tincture_hex("ash")})
	_ok(not CKHeraldry.has_achievement_ornament(bare), "api bare no ornament")

	var with_sup := bare.duplicate(true)
	with_sup["achievement"] = {
		"helm": "none", "crown": "none", "motto": "",
		"mantling_a": "", "mantling_b": "",
		"supporters": ["wolf", "eagle"],
	}
	with_sup = CKHeraldry.normalize(with_sup)
	_ok(CKHeraldry.has_achievement_ornament(with_sup), "api supporters count as ornament")

	var img_a := BannerSpec.compose_arms(with_sup, 96, 120)
	var img_s := BannerSpec.compose_shield(with_sup, 96, 120)
	_ok(_opaque_count(img_a) > 80, "api arms with supporters opaque")
	# Supporters sit left/right of the shield — side columns must diverge from bare shield.
	var side_diff := 0
	var th := mini(img_a.get_height(), img_s.get_height())
	var tw := mini(img_a.get_width(), img_s.get_width())
	var band := mini(10, tw / 4)
	for y in range(th):
		for x in range(band):
			var pa := img_a.get_pixel(x, y)
			var pb := img_s.get_pixel(x, y)
			if absf(pa.a - pb.a) + absf(pa.r - pb.r) > 0.25:
				side_diff += 1
			pa = img_a.get_pixel(tw - 1 - x, y)
			pb = img_s.get_pixel(tw - 1 - x, y)
			if absf(pa.a - pb.a) + absf(pa.r - pb.r) > 0.25:
				side_diff += 1
	_ok(side_diff > 8, "api arms side bands differ from shield (supporters)")

	var ranked := CKHeraldry.apply_rank(CKHeraldry.from_nation("ashbanner", "knight"), "duke")
	var rach: Dictionary = ranked.get("achievement", {})
	var rsup: Array = rach.get("supporters", [])
	_ok(str(rsup[0]) == "wolf" and str(rsup[1]) == "wolf", "api apply_rank duke → ashbanner wolf pair")
	_ok(str(rsup[0]) != "frost_beast", "api no frost_beast sentinel")

	var royal := CKHeraldry.from_nation("saltmarsh", "royal")
	var roach: Dictionary = royal.get("achievement", {})
	var rsup2: Array = roach.get("supporters", [])
	_ok(str(rsup2[0]) == "seadrake" and str(rsup2[1]) == "seadrake", "api from_nation royal saltmarsh seadrake")

	# Legacy frost_beast migrates to nation pair on normalize.
	var legacy := CKHeraldry.normalize({
		"schema": 2,
		"nation": "emberold",
		"field_a": CKHeraldry.tincture_hex("ash"),
		"achievement": {
			"helm": "royal", "crown": "duke", "motto": "旧档",
			"supporters": ["frost_beast", "frost_beast"],
		},
	})
	var lach: Dictionary = legacy.get("achievement", {})
	var lsup: Array = lach.get("supporters", [])
	_ok(str(lsup[0]) == "bear" and str(lsup[1]) == "wolf", "api frost_beast → emberold bear/wolf")

	var tr := TextureRect.new()
	CKHeraldry.stamp_achievement_meta(tr, with_sup)
	_ok(str(tr.get_meta("arms_supporter_l", "")) == "wolf", "api stamp supporter_l")
	_ok(str(tr.get_meta("arms_supporter_r", "")) == "eagle", "api stamp supporter_r")
	CKHeraldry.clear_achievement_meta_cloth(tr)
	_ok(str(tr.get_meta("arms_supporter_l", "X")) == "none", "api cloth clear supporter_l")
	_ok(str(tr.get_meta("arms_supporter_r", "X")) == "none", "api cloth clear supporter_r")
	_ok(str(tr.get_meta("arms_helm", "X")) == "none", "api cloth clear helm")
	tr.free()


func _run_founding_diy_supporters() -> void:
	_boot("成就扶盾开局")
	var page := _open("res://scenes/story/naming.tscn")
	await _settle(6)

	_ok(page.find_child("SupporterLLabel", true, false) != null, "founding SupporterLLabel")
	_ok(page.find_child("SupporterRLabel", true, false) != null, "founding SupporterRLabel")

	page.call("_on_apply_nation_preset", "ashbanner")
	await _settle(4)
	var spec0: Dictionary = page.call("_current_spec")
	var ach0: Dictionary = spec0.get("achievement", {})
	var s0: Array = ach0.get("supporters", [])
	_ok(str(s0[0]) == "none" and str(s0[1]) == "none", "founding knight preset supporters none")

	page.set("_supporter_l_idx", CKHeraldry.supporter_ids().find("wolf"))
	page.set("_supporter_r_idx", CKHeraldry.supporter_ids().find("eagle"))
	page.set("_helm_idx", CKHeraldry.helm_ids().find("grilled"))
	page.set("_crown_idx", CKHeraldry.crown_ids().find("baron"))
	var motto_le: LineEdit = page.find_child("MottoEdit", true, false)
	if motto_le:
		motto_le.text = "扶盾同辉"
		motto_le.text_changed.emit("扶盾同辉")
	page.call("_refresh_preview_art")
	await _settle(4)

	var spec: Dictionary = page.call("_current_spec")
	var ach: Dictionary = spec.get("achievement", {})
	var sups: Array = ach.get("supporters", [])
	_ok(str(sups[0]) == "wolf", "founding DIY supporter_l=wolf")
	_ok(str(sups[1]) == "eagle", "founding DIY supporter_r=eagle")
	_ok(str(ach.get("helm", "")) == "grilled", "founding DIY helm kept")
	_ok(str(ach.get("motto", "")) == "扶盾同辉", "founding DIY motto")

	var shield: TextureRect = page.get("_shield")
	_ok(shield != null, "founding preview shield")
	if shield:
		_ok(str(shield.get_meta("arms_supporter_l", "")) == "wolf", "founding shield meta L")
		_ok(str(shield.get_meta("arms_supporter_r", "")) == "eagle", "founding shield meta R")
		_ok(str(shield.get_meta("arms_helm", "")) == "grilled", "founding shield meta helm")
		_ok(shield.texture != null, "founding shield texture")

	GameState.banner_spec = BannerSpec.normalize(spec)
	GameState.crest_color = str(page.call("_heart"))
	UnitArt.clear_cache()
	page.queue_free()
	await _settle(2)


func _run_field_surfaces_meta() -> void:
	var want_l := "wolf"
	var want_r := "eagle"
	var want_helm := "grilled"
	var want_motto := "扶盾同辉"
	var live: Dictionary = BannerSpec.normalize(GameState.banner_spec)
	var lach: Dictionary = live.get("achievement", {})
	var lsup: Array = lach.get("supporters", [])
	_ok(str(lsup[0]) == want_l and str(lsup[1]) == want_r, "live GameState supporters")

	var root := Control.new()
	root.size = Vector2(1280, 720)
	get_tree().root.add_child(root)

	var hang := CKHeraldryField.place_castle_hang_banner(root, Vector2(8, 8), Vector2(56, 78))
	_ok(hang != null, "surface hang placed")
	var cloth = hang.find_child("HangCloth", true, false) if hang else null
	_ok(cloth != null, "surface HangCloth")
	if cloth:
		_ok(str(cloth.get_meta("arms_supporter_l", "X")) == "none", "HangCloth supporter_l=none")
		_ok(str(cloth.get_meta("arms_supporter_r", "X")) == "none", "HangCloth supporter_r=none")
		_ok(str(cloth.get_meta("arms_helm", "X")) == "none", "HangCloth helm=none")
		_ok(str(cloth.get_meta("shield_shape", "")) == "cloth", "HangCloth shield_shape=cloth")

	var shell := CKHeraldryField.place_shell_crest_strip(root, Vector2(100, 8))
	_ok(shell != null, "surface shell strip")
	var bn = root.find_child("ShellBanner", true, false)
	_ok(bn != null, "surface ShellBanner")
	if bn:
		_ok(str(bn.get_meta("arms_supporter_l", "X")) == "none", "ShellBanner supporter_l=none")
		_ok(str(bn.get_meta("arms_supporter_r", "X")) == "none", "ShellBanner supporter_r=none")
		_ok(str(bn.get_meta("shield_shape", "")) == "cloth", "ShellBanner shield_shape=cloth")

	var hdr := CKHeraldryField.place_company_header(root, Vector2(280, 8))
	_ok(hdr != null, "surface company header")
	if hdr:
		_ok(str(hdr.get_meta("arms_supporter_l", "")) == want_l, "CastleArms supporter_l")
		_ok(str(hdr.get_meta("arms_supporter_r", "")) == want_r, "CastleArms supporter_r")
		_ok(str(hdr.get_meta("arms_helm", "")) == want_helm, "CastleArms helm")
		_ok(str(hdr.get_meta("arms_motto", "")) == want_motto, "CastleArms motto")

	var row := HBoxContainer.new()
	root.add_child(row)
	var slot := CKHeraldryField.attach_save_row_arms(row, Vector2(36, 44), str(GameState.crest_color), GameState.banner_spec.duplicate(true))
	_ok(slot != null, "surface SlotArms")
	if slot:
		_ok(str(slot.get_meta("arms_supporter_l", "")) == want_l, "SlotArms supporter_l")
		_ok(str(slot.get_meta("arms_supporter_r", "")) == want_r, "SlotArms supporter_r")
		_ok(str(slot.get_meta("arms_helm", "")) == want_helm, "SlotArms helm")

	root.queue_free()


func _run_castle_view_hang_bare() -> void:
	_boot("城堡挂旗bare")
	# Keep DIY supporters on live company so hang must still clear.
	var live := BannerSpec.normalize(GameState.banner_spec)
	var ach: Dictionary = (live.get("achievement", {}) as Dictionary).duplicate(true)
	ach["supporters"] = ["bear", "stag"]
	ach["helm"] = "royal"
	ach["crown"] = "duke"
	ach["motto"] = "挂布不吃"
	live["achievement"] = ach
	GameState.banner_spec = live
	UnitArt.clear_cache()

	var page := _open("res://scenes/hub/castle_view.tscn")
	await _settle(10)
	var hang = page.find_child("CastleHangBanner", true, false)
	_ok(hang != null, "castle_view HangBanner")
	var cloth = hang.find_child("HangCloth", true, false) if hang else null
	_ok(cloth != null, "castle_view HangCloth")
	if cloth:
		_ok(str(cloth.get_meta("arms_supporter_l", "X")) == "none", "castle HangCloth L bare")
		_ok(str(cloth.get_meta("arms_supporter_r", "X")) == "none", "castle HangCloth R bare")
		_ok(str(cloth.get_meta("arms_helm", "X")) == "none", "castle HangCloth helm bare")
		_ok(str(cloth.get_meta("arms_motto", "X")) == "", "castle HangCloth motto bare")
	page.queue_free()
	await _settle(2)


func _run_save_slots_and_menu_e2e() -> void:
	_boot("存档条成就面")
	var preset := CKHeraldry.company_preset_from_nation("irongorge")
	var ach: Dictionary = (preset.get("achievement", {}) as Dictionary).duplicate(true)
	ach["supporters"] = ["bear", "bear"]
	ach["helm"] = "grilled"
	ach["crown"] = "count"
	ach["motto"] = "铁峡同辉"
	preset["achievement"] = ach
	preset = BannerSpec.normalize(preset)
	GameState.banner_spec = preset
	GameState.crest_color = str(preset.get("ordinary_tincture", GameState.crest_color))
	UnitArt.clear_cache()
	var slot := "manual_0"
	_ok(GameState.save_to_slot(slot), "save_to_slot")
	var meta := CKSaveService.read_meta(slot)
	var meta_spec: Dictionary = meta.get("banner_spec", {})
	_ok(typeof(meta_spec) == TYPE_DICTIONARY and not meta_spec.is_empty(), "meta banner_spec")
	var mach: Dictionary = meta_spec.get("achievement", {})
	var msup: Array = mach.get("supporters", [])
	_ok(str(msup[0]) == "bear" and str(msup[1]) == "bear", "meta supporters bear/bear")

	# Flip live so SlotArms must read meta, not live.
	GameState.banner_spec = CKHeraldry.company_preset_from_nation("lantern")
	GameState.crest_color = CKHeraldry.tincture_hex("azure")
	UnitArt.clear_cache()

	var page := _open("res://scenes/ui/save_slots.tscn")
	await _settle(10)
	var row = page.find_child("SlotRow_%s" % slot, true, false)
	_ok(row != null, "e2e SlotRow")
	if row != null:
		var arms = row.find_child("SlotArms", true, false)
		_ok(arms != null, "e2e SlotArms")
		if arms != null:
			_ok(str(arms.get_meta("arms_supporter_l", "")) == "bear", "e2e SlotArms L from meta")
			_ok(str(arms.get_meta("arms_supporter_r", "")) == "bear", "e2e SlotArms R from meta")
			_ok(str(arms.get_meta("arms_helm", "")) == "grilled", "e2e SlotArms helm from meta")
			_ok(str(arms.get_meta("arms_motto", "")) == "铁峡同辉", "e2e SlotArms motto from meta")

	# Shell on save_slots uses LIVE company (lantern) — still stamps CastleArms from live.
	var shell_arms = page.find_child("CastleArms", true, false)
	_ok(shell_arms != null, "e2e save_slots CastleArms")
	var shell_bn = page.find_child("ShellBanner", true, false)
	if shell_bn:
		_ok(str(shell_bn.get_meta("arms_supporter_l", "X")) == "none", "e2e ShellBanner L bare")
		_ok(str(shell_bn.get_meta("arms_supporter_r", "X")) == "none", "e2e ShellBanner R bare")
	page.queue_free()
	await _settle(2)

	# Restore live with supporters and open main_menu shell strip.
	GameState.banner_spec = preset
	GameState.crest_color = str(preset.get("ordinary_tincture", GameState.crest_color))
	UnitArt.clear_cache()
	var menu := _open("res://scenes/ui/main_menu.tscn")
	await _settle(8)
	var menu_arms = menu.find_child("CastleArms", true, false)
	_ok(menu_arms != null, "e2e main_menu CastleArms")
	if menu_arms:
		_ok(str(menu_arms.get_meta("arms_supporter_l", "")) == "bear", "e2e menu CastleArms L")
		_ok(str(menu_arms.get_meta("arms_supporter_r", "")) == "bear", "e2e menu CastleArms R")
		_ok(str(menu_arms.get_meta("arms_motto", "")) == "铁峡同辉", "e2e menu CastleArms motto")
	var menu_bn = menu.find_child("ShellBanner", true, false)
	if menu_bn:
		_ok(str(menu_bn.get_meta("arms_supporter_l", "X")) == "none", "e2e menu ShellBanner bare")
	menu.queue_free()
	await _settle(2)


func _source_wiring() -> void:
	var naming := FileAccess.get_file_as_string("res://scripts/story/naming.gd")
	_ok(naming.find("ux_name_supporter_l") >= 0, "naming knows supporter_l")
	_ok(naming.find("ux_name_supporter_r") >= 0, "naming knows supporter_r")
	_ok(naming.find("SupporterLLabel") >= 0, "naming SupporterLLabel")
	_ok(naming.find("supporter_ids") >= 0, "naming uses supporter_ids")
	var her := FileAccess.get_file_as_string("res://scripts/art/heraldry.gd")
	_ok(her.find("nation_supporter_pair") >= 0, "heraldry nation_supporter_pair")
	_ok(her.find("arms_supporter_l") >= 0, "heraldry stamps arms_supporter_l")
	_ok(her.find("clear_achievement_meta_cloth") >= 0, "heraldry clear cloth helper")
	_ok(her.find("frost_beast") < 0 or her.find("nation_supporter_pair") >= 0, "heraldry prefers nation pair")
	# No frost_beast left as assigned sentinel in apply/achievement paths after rewrite.
	_ok(her.find('["frost_beast", "frost_beast"]') < 0, "heraldry dropped frost_beast array literal")
	var chrome := FileAccess.get_file_as_string("res://scripts/art/heraldry_chrome.gd")
	_ok(chrome.find("clear_achievement_meta_cloth") >= 0, "chrome cloth bare stamp")
	var field := FileAccess.get_file_as_string("res://scripts/art/heraldry_field.gd")
	_ok(field.find("clear_achievement_meta_cloth") >= 0, "field HangCloth uses clear helper")
	var ux := FileAccess.get_file_as_string("res://data/locale/ux.csv")
	_ok(ux.find("ux_supporter_wolf") >= 0 and ux.find("ux_name_supporter_l") >= 0, "locale supporter keys")
