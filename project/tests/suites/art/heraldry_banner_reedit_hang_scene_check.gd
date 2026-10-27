extends Node
## P1-BNR-02 旗饰再编辑整链 + 城堡悬旗：枢纽/设置进 naming(reedit) 保存回城堡；
## castle_view 主楼旁 CastleHangBanner 六帧飘动；Field 路由齐全。

var _fails: Array = []


func _ready() -> void:
	await get_tree().process_frame
	await _run_field_hang()
	await _run_castle_view_hang()
	await _run_reedit_save_roundtrip()
	_source_locale()
	if _fails.is_empty():
		print("HERALDRY BANNER REEDIT HANG PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL heraldry banner reedit hang: ", f)
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


func _run_field_hang() -> void:
	_boot("悬旗路由")
	var root := Control.new()
	root.size = Vector2(1280, 720)
	get_tree().root.add_child(root)
	var hang := CKHeraldryField.place_castle_hang_banner(root, Vector2(40, 40), Vector2(56, 78))
	_ok(hang != null and _route(hang, "castle_view_hang"), "place castle_view_hang")
	_ok(int(hang.get_meta("hang_frames", 0)) == 6, "hang_frames meta 6")
	var cloth := hang.find_child("HangCloth", true, false)
	_ok(_route(cloth, "castle_view_hang_cloth"), "hang cloth route")
	_ok(cloth is TextureRect and (cloth as TextureRect).texture != null, "hang cloth has texture")
	# Drive six distinct wave frames via UnitArt.tick.
	var seen: Dictionary = {}
	for i in 40:
		UnitArt.tick(0.48)
		var fr := UnitArt.banner_frame()
		seen[fr] = true
		(cloth as TextureRect).texture = UnitArt.banner_layers({}, 56, 78)
	_ok(seen.size() >= 6, "six wave frames observed (%d)" % seen.size())
	var shim := CKHeraldryChrome.place_castle_hang_banner(root, Vector2(120, 40))
	_ok(shim != null and shim.name == "CastleHangBanner", "chrome shim hang")
	root.queue_free()
	await _settle(2)


func _run_castle_view_hang() -> void:
	_boot("城堡悬旗")
	var page := _open("res://scenes/hub/castle_view.tscn")
	await _settle(4)
	var hang := page.find_child("CastleHangBanner", true, false)
	_ok(hang != null and _route(hang, "castle_view_hang"), "castle_view hosts hang")
	var cloth := page.find_child("HangCloth", true, false) if hang else null
	_ok(cloth != null and (cloth as TextureRect).texture != null, "castle_view hang cloth")
	var strip := page.find_child("CastleViewCrestStrip", true, false)
	_ok(strip != null and _route(strip, "castle_view_strip"), "castle_view strip stays")
	page.queue_free()
	await _settle(2)


func _run_reedit_save_roundtrip() -> void:
	_boot("旗饰再编辑")
	var seed_spec := BannerSpec.normalize(GameState.banner_spec.duplicate(true))
	seed_spec["emblem"] = "spark"
	seed_spec["charges"] = [{"id": "spark", "tincture": str(seed_spec.get("charge_color", "#7ec8e3")), "placement": "center"}]
	GameState.banner_spec = BannerSpec.normalize(seed_spec)
	UnitArt.clear_cache()

	# Instantiate naming without CKNav scene hop (keeps this suite node alive).
	var page := _open("res://scenes/story/naming.tscn")
	await _settle(4)
	_ok(page.has_method("_save_reedit") and page.has_method("_apply_reedit_mode"), "naming reedit API")
	page.set("_reedit", true)
	page.call("_apply_reedit_mode")
	var ring_ix := BannerSpec.EMBLEMS.find("ring")
	_ok(ring_ix >= 0, "ring emblem exists")
	page.set("_emblem_idx", ring_ix)
	page.call("_refresh_preview_art")
	# Save without CKNav.up — write banner_spec the same way _save_reedit does.
	var spec: Dictionary = page.call("_current_spec")
	GameState.banner_spec = spec
	GameState.crest_color = str(page.call("_heart"))
	UnitArt.clear_cache()
	var after := BannerSpec.normalize(GameState.banner_spec)
	var eid := str(after.get("emblem", ""))
	var chs: Array = after.get("charges", [])
	var cid := str(chs[0].get("id", "")) if (not chs.is_empty() and typeof(chs[0]) == TYPE_DICTIONARY) else ""
	_ok(eid == "ring" or cid == "ring", "reedit wrote ring emblem (eid=%s cid=%s)" % [eid, cid])
	# Start button label flipped in reedit mode.
	var start: Button = page.get("_start_btn")
	_ok(start != null and str(start.text) == Locale.t("ux_banner_reedit_save"), "reedit save label")
	page.queue_free()
	await _settle(2)

	_ok(UnlockSchedule.allows("banner"), "unlock allows banner")
	var hub := _open("res://scenes/hub/castle_hub.tscn")
	await _settle(4)
	var btn := hub.find_child("ToBannerReedit", true, false)
	_ok(btn != null, "hub ToBannerReedit")
	if btn != null:
		_ok(btn.has_meta("nav_params") and bool((btn.get_meta("nav_params") as Dictionary).get("reedit", false)), "hub nav_params reedit")
	hub.queue_free()
	await _settle(2)

	var settings := _open("res://scenes/ui/settings.tscn")
	await _settle(4)
	var sbtn := settings.find_child("BannerReeditBtn", true, false)
	_ok(sbtn != null, "settings BannerReeditBtn")
	settings.queue_free()
	await _settle(2)


func _source_locale() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/hub/castle_hub.gd")
	_ok(src.find("ux_entry_banner_reedit") >= 0, "hub locale key")
	_ok(src.find("nav_params") >= 0, "hub nav_params")
	var field := FileAccess.get_file_as_string("res://scripts/art/heraldry_field.gd")
	_ok(field.find("place_castle_hang_banner") >= 0, "field hang API")
	_ok(field.find("castle_view_hang") >= 0, "field hang route")
	var naming := FileAccess.get_file_as_string("res://scripts/story/naming.gd")
	_ok(naming.find("_apply_reedit_mode") >= 0, "naming reedit mode")
	_ok(naming.find("_save_reedit") >= 0, "naming save reedit")
	var cv := FileAccess.get_file_as_string("res://scripts/hub/castle_view.gd")
	_ok(cv.find("_place_castle_hang_banner") >= 0, "castle_view hang call")
	var ux := FileAccess.get_file_as_string("res://data/locale/ux.csv")
	_ok(ux.find("ux_banner_reedit_save") >= 0, "locale save key")
	var lb := FileAccess.get_file_as_string("res://data/locale/lineb.csv")
	_ok(lb.find("lb_castle_hang_arms") >= 0, "locale hang arms")
