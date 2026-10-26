extends Node
## Fat heraldry E2E: owned atlas site SiteBanner via Field (desk + mobile) + source vow.

var _fails: Array = []


func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	_run_sources()
	if _fails.is_empty():
		print("ATLAS TERRITORY CREST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL atlas territory crest: ", f)
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)


func _settle(n: int = 6) -> void:
	for _i in n:
		await get_tree().process_frame


func _boot_owned() -> String:
	GameState.new_game("地徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	var id := "t_ash_cinderpit"
	var s := CKTerritory.site(id)
	World.pos = str(s.anchor)
	var r := CKTerritory.assault(id)
	_ok(bool(r.get("ok", false)), "assault ok")
	World.on_battle_end(true)
	_ok(CKTerritory.owned(id), "site owned after assault")
	return id


func _assert_markers(where: String, nation: String) -> void:
	var host := Control.new()
	host.name = "MarkerHost"
	host.size = Vector2(640, 400)
	add_child(host)
	var n := CKAtlasTerritory.add_markers(host, nation, host.size, false, func(_sid): pass)
	_ok(n >= 1, "%s markers n>=1 got %d" % [where, n])
	var banners: Array = []
	for b in host.find_children("SiteBanner", "", true, false):
		if str(b.get_meta("field_route", "")) == "site_banner":
			banners.append(b)
	_ok(banners.size() >= 1, "%s SiteBanner field_route count>=1 got %d" % [where, banners.size()])
	for bn in banners:
		_ok(str(bn.get_meta("arms_kind", "")) == "gen2_36", "%s SiteBanner kind" % where)
		_ok(bn.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s SiteBanner mouse" % where)
	host.queue_free()


func _run_sources() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/hub/atlas_territory.gd")
	_ok(src.find("CKHeraldryField.attach_site_company_banner") >= 0, "atlas calls Field site banner")
	_ok(src.find("CKHeraldryChrome.make_company_banner") < 0, "atlas no direct Chrome.make_company_banner")
	var dos := FileAccess.get_file_as_string("res://scripts/hub/unit_dossier.gd")
	_ok(dos.find("CKHeraldryField.attach_dossier_crest_banner") >= 0, "dossier calls Field crest banner")
	var terr := FileAccess.get_file_as_string("res://scripts/company/territory.gd")
	_ok(terr.find("CKHeraldryField.company_banner_texture") >= 0, "Territory.banner_texture via Field")
	_ok(terr.find("CKHeraldryChrome.company_banner") < 0, "Territory no direct Chrome.company_banner")
	var info := FileAccess.get_file_as_string("res://scripts/battle/ui/battle_info_panel.gd")
	_ok(info.find("CKHeraldryField.company_banner_texture") >= 0, "battle info idle portrait via Field")
	_ok(info.find("CKHeraldryChrome.company_banner") < 0, "battle info no direct Chrome.company_banner")
	var tex := CKTerritory.banner_texture(28, 38)
	_ok(tex != null, "Territory.banner_texture returns cloth")
	var tex2 := CKHeraldryField.company_banner_texture(28, 38)
	_ok(tex2 == tex, "Field cache same instance as Territory")


func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	var id := _boot_owned()
	var nation := str(CKTerritory.site(id).nation)
	_assert_markers("desk", nation)
	# Dossier crest overlay via Field.
	var lead := GameState.get_leader()
	_ok(lead != null, "desk leader")
	if lead != null:
		GameState.set_meta("dossier_id", lead.id)
		var page: Control = load("res://scenes/hub/unit_dossier.tscn").instantiate()
		get_tree().root.add_child(page)
		await _settle(12)
		if page.has_method("_show_crest"):
			page.call("_show_crest")
			await _settle(6)
		var ct := page.find_child("CrestTexture", true, false)
		_ok(ct != null and str(ct.get_meta("field_route", "")) == "dossier_crest", "desk CrestTexture field_route")
		if ct != null:
			_ok(str(ct.get_meta("arms_kind", "")) in ["gen2_06", "gen2_35"], "desk CrestTexture kind")
			_ok(str(ct.get_meta("arms_core", "")) != "", "desk CrestTexture core")
		page.queue_free()
		await _settle(2)


func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	var id := _boot_owned()
	var nation := str(CKTerritory.site(id).nation)
	_assert_markers("mob", nation)
	OS.set_environment("CK_FORCE_MOBILE", "")
