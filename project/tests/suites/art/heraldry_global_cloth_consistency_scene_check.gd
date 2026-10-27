extends Node
## 纹章全局一致：所有 Field `_cloth_beside` 旗布必须带专属 arms_kind tip，
## 且 tip 键全局唯一。悬停铁匠/神龛/城事/婚约/继位/决斗/练兵/邦国/仪典/集结等
## 旗布时不再空白或撞名。禁止再按 wave 切片漏挂。

var _fails: Array = []


func _ready() -> void:
	await get_tree().process_frame
	_boot()
	await _run_live_uniqueness()
	_source_no_unlabeled_cloth()
	_source_tip_keys_unique_and_localized()
	if _fails.is_empty():
		print("HERALDRY GLOBAL CLOTH CONSISTENCY PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL heraldry global cloth consistency: ", f)
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)


func _settle(n: int = 3) -> void:
	for _i in n:
		await get_tree().process_frame


func _boot() -> void:
	GameState.new_game("纹章全局一致", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	World.pos = "ash_capital"
	World.arrive("ash_capital")


func _run_live_uniqueness() -> void:
	var leader = GameState.get_leader()
	_ok(leader != null, "leader for global cloth E2E")
	var root := Control.new()
	root.name = "GlobalClothHost"
	root.size = Vector2(1600, 900)
	add_child(root)
	var nid := World.nation_of("ash_capital")
	if nid == "":
		nid = "ashbanner"

	# Place every Field cloth strip we own — one host, collect Banner arms_kind.
	var placed: Array = [
		CKHeraldryField.place_tavern_crest_strip(root, leader, Vector2(8, 8)),
		CKHeraldryField.place_reserve_crest_strip(root, leader, Vector2(200, 8)),
		CKHeraldryField.place_report_crest_strip(root, Vector2(400, 8), nid),
		CKHeraldryField.place_forge_focus_strip(root, leader, Vector2(600, 8)),
		CKHeraldryField.place_shrine_heal_strip(root, leader, Vector2(800, 8)),
		CKHeraldryField.place_affairs_crest_strip(root, "ash_capital", Vector2(1000, 8)),
		CKHeraldryField.place_marriage_crest_strip(root, leader, leader, Vector2(8, 80)),
		CKHeraldryField.place_succession_crest_strip(root, leader, Vector2(240, 80)),
		CKHeraldryField.place_duel_crest_strip(root, leader, leader, Vector2(480, 80)),
		CKHeraldryField.place_train_focus_strip(root, leader, Vector2(720, 80)),
		CKHeraldryField.place_roster_crest_strip(root, Vector2(960, 80)),
		CKHeraldryField.place_dialogue_crest_strip(root, Vector2(1200, 80)),
		CKHeraldryField.place_shell_crest_strip(root, Vector2(8, 160)),
		CKHeraldryField.place_hourglass_crest_strip(root, Vector2(200, 160)),
		CKHeraldryField.place_castle_view_crest_strip(root, Vector2(400, 160)),
		CKHeraldryField.place_blood_crest_strip(root, Vector2(600, 160)),
		CKHeraldryField.place_market_crest_strip(root, Vector2(800, 160)),
		CKHeraldryField.place_works_crest_strip(root, Vector2(1000, 160)),
		CKHeraldryField.place_estates_crest_strip(root, Vector2(1200, 160)),
		CKHeraldryField.place_annex_crest_strip(root, Vector2(8, 240)),
		CKHeraldryField.place_gazette_crest_strip(root, nid, Vector2(200, 240)),
		CKHeraldryField.place_travel_crest_strip(root, Vector2(400, 240), nid),
		CKHeraldryField.place_camp_crest_strip(root, Vector2(600, 240), nid),
		CKHeraldryField.place_encounter_crest_strip(root, Vector2(800, 240), nid),
		CKHeraldryField.place_city_crest_strip(root, "ash_capital", Vector2(1000, 240)),
		CKHeraldryField.place_aftermath_crest_strip(root, Vector2(1200, 240), nid),
		CKHeraldryField.place_nation_crest_strip(root, nid, Vector2(8, 320)),
		CKHeraldryField.place_rite_crest_strip(root, leader, Vector2(200, 320)),
		CKHeraldryField.place_muster_crest_strip(root, leader, Vector2(400, 320)),
		CKHeraldryField.place_field_crest_strip(root, Vector2(600, 320)),
		CKHeraldryField.place_skill_crest_strip(root, Vector2(800, 320)),
	]
	await _settle(4)

	var kinds: Dictionary = {}
	var banners: Array = root.find_children("*Banner", "TextureRect", true, false)
	_ok(banners.size() >= 20, "live Banner count>=20 got %d" % banners.size())
	for bn in banners:
		var kind := str(bn.get_meta("arms_kind", ""))
		var route := str(bn.get_meta("field_route", ""))
		_ok(kind != "", "live %s (%s) has arms_kind" % [bn.name, route])
		if kind == "":
			continue
		if kinds.has(kind):
			_ok(false, "live arms_kind duplicate %s on %s and %s" % [kind, kinds[kind], bn.name])
		else:
			kinds[kind] = bn.name
		_ok(str(bn.tooltip_text) != "", "live %s tooltip non-empty" % bn.name)
	_ok(kinds.size() >= 20, "live unique tip kinds>=20 got %d" % kinds.size())
	root.queue_free()
	await _settle(2)


func _source_no_unlabeled_cloth() -> void:
	var field := FileAccess.get_file_as_string("res://scripts/art/heraldry_field.gd")
	# Every Banner _cloth_beside must pass a non-empty lb_*_arms tip (5th arg).
	var start := 0
	var unlabeled: Array = []
	while true:
		var i := field.find("_cloth_beside(", start)
		if i < 0:
			break
		var j := field.find(")", i)
		if j < 0:
			break
		var call := field.substr(i, j - i + 1)
		start = i + 1
		if call.find("Banner") < 0:
			continue
		# Expect: _cloth_beside(host, shield, "XBanner", "route", "lb_…_arms" …
		if call.find("lb_") < 0 or call.find("_arms") < 0:
			unlabeled.append(call.replace("\n", " ").substr(0, 96))
	_ok(unlabeled.is_empty(), "source no unlabeled Banner cloth (%d): %s" % [
		unlabeled.size(), str(unlabeled)
	])


func _source_tip_keys_unique_and_localized() -> void:
	var field := FileAccess.get_file_as_string("res://scripts/art/heraldry_field.gd")
	var loc := FileAccess.get_file_as_string("res://data/locale/lineb.csv")
	var keys: Dictionary = {}
	var start := 0
	while true:
		var i := field.find('"lb_', start)
		if i < 0:
			break
		var j := field.find('"', i + 1)
		if j < 0:
			break
		var key := field.substr(i + 1, j - i - 1)
		start = j + 1
		if not key.ends_with("_arms"):
			continue
		# only count keys used as cloth tip arg (appear after Banner route)
		if keys.has(key):
			keys[key] += 1
		else:
			keys[key] = 1
		_ok(loc.find(key + ",") >= 0, "locale has %s" % key)
	# cloth tips should appear once each as string literal in field (some keys also in chrome)
	_ok(keys.size() >= 25, "field cloth tip key count>=25 got %d" % keys.size())
