extends Node
## Fat heraldry E2E: court gazette — CastleArms + CastleBannerStrip + GazetteCrestStrip
## + GazetteNationArms on seeded news rows. Desktop + mobile.

const SCN := preload("res://scenes/hub/court_news.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	if _fails.is_empty():
		print("COURT NEWS CREST CHROME PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL court news crest chrome: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 6) -> void:
	for i in n:
		await get_tree().process_frame

func _seed_news() -> void:
	var nid := World.nation_of(str(World.pos))
	if nid == "":
		nid = "ashbanner"
	if typeof(World.get("royal_courts")) != TYPE_DICTIONARY:
		World.royal_courts = {"nations": {}}
	var nations: Dictionary = World.royal_courts.get("nations", {})
	if typeof(nations) != TYPE_DICTIONARY:
		nations = {}
	var house: Dictionary = nations.get(nid, {})
	if typeof(house) != TYPE_DICTIONARY:
		house = {}
	var log: Array = house.get("log", [])
	if typeof(log) != TYPE_ARRAY:
		log = []
	log.append({
		"year": int(Calendar.year),
		"kind": "birth",
		"text": "suite seed birth under %s" % nid,
	})
	house["log"] = log
	nations[nid] = house
	World.royal_courts["nations"] = nations

func _boot() -> void:
	GameState.new_game("朝报徽", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 8000
	_seed_news()

func _assert_page(page: Node, where: String) -> void:
	_ok(page.find_child("CastleArms", true, false) != null, "%s CastleArms" % where)
	_ok(page.find_child("CastleBannerStrip", true, false) != null, "%s CastleBannerStrip" % where)
	var gaz := page.find_child("GazetteCrestStrip", true, false)
	_ok(gaz != null, "%s GazetteCrestStrip" % where)
	if gaz != null:
		_ok(str(gaz.get_meta("field_route", "")) == "gazette_strip", "%s strip field_route" % where)
		var gco = gaz.find_child("CastleArms", true, false)
		_ok(gco != null and str(gco.get_meta("field_route", "")) == "strip_company", "%s strip_company" % where)
		var gnat = gaz.find_child("GazetteNationArms", true, false)
		_ok(gnat != null, "%s strip GazetteNationArms" % where)
		if gnat != null:
			_ok(str(gnat.get_meta("field_route", "")) == "gazette_nation", "%s gazette_nation" % where)
		_ok(str(gaz.get_meta("nation_id", "")) != "", "%s strip nation_id" % where)
		var gbn := gaz.find_child("GazetteBanner", true, false)
		_ok(gbn != null and str(gbn.get_meta("field_route", "")) == "gazette_banner", "%s gazette_banner" % where)
	var src := FileAccess.get_file_as_string("res://scripts/hub/court_news.gd")
	_ok(src.find("CKHeraldryField.place_gazette_crest_strip") >= 0, "%s hub calls Field strip" % where)
	_ok(src.find("CKHeraldryField.attach_news_row_arms") >= 0, "%s hub calls Field row" % where)
	## Seeded news row also carries GazetteNationArms under the list.
	var list := page.find_child("NewsRows", true, false)
	if list != null:
		var row_arms := list.find_child("GazetteNationArms", true, false)
		_ok(row_arms != null, "%s news-row GazetteNationArms" % where)
		if row_arms != null:
			_ok(str(row_arms.get_meta("field_route", "")) == "news_row", "%s news_row field_route" % where)

func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	_boot()
	var page: Control = SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(14)
	_assert_page(page, "desk")
	page.queue_free()
	await _settle(2)

func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	_boot()
	var page: Control = SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(14)
	if page.has_method("apply_mobile_layout"):
		page.call("apply_mobile_layout")
		await _settle(8)
	_assert_page(page, "mob")
	page.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")
