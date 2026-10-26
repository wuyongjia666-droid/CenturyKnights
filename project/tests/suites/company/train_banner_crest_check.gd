extends Node
## Fat heraldry E2E: banner school Field — TrainFocusStrip (团徽+瞳徽)
## + TrainRowArms on pupil/tutor/promo rows. Desktop + mobile. No marshalling.

const TRAIN_SCN := preload("res://scenes/hub/train.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	if _fails.is_empty():
		print("TRAIN BANNER CREST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL train banner crest: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 8) -> void:
	for i in n:
		await get_tree().process_frame

func _boot() -> void:
	GameState.new_game("旗学徽", "霜旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	var lead: CKCharacter = GameState.get_leader()
	# Kin pupil (not roster) so TrainFocusStrip pairs 团徽+族徽.
	var kid := CKCharacter.new()
	kid.id = "banner_pupil"
	kid.name = "旗童"
	kid.age = 9
	kid.alive = true
	kid.in_roster = false
	kid.is_child = true
	kid.family_id = lead.family_id if lead else ""
	kid.parent_ids = [lead.id] if lead else []
	kid.hp = kid.max_hp
	GameState.characters[kid.id] = kid
	# Loner tutor-eligible on roster for 旗徽 row coverage.
	var loner := CKCharacter.new()
	loner.id = "banner_tutor"
	loner.name = "客傅"
	loner.age = 32
	loner.alive = true
	loner.in_roster = true
	loner.family_id = ""
	loner.job_id = "soldier"
	loner.rank = "knight"
	loner.hp = loner.max_hp
	GameState.characters[loner.id] = loner

func _collect(n: Node, node_name: String, out: Array) -> void:
	if n.name == node_name:
		out.append(n)
	for c in n.get_children():
		_collect(c, node_name, out)

func _assert_page(page: Node, where: String) -> void:
	var strip := page.find_child("TrainFocusStrip", true, false)
	_ok(strip != null, "%s TrainFocusStrip" % where)
	if strip != null:
		var ca := strip.find_child("CastleArms", true, false)
		var fa := strip.find_child("TrainFocusArms", true, false)
		_ok(ca != null and str(ca.get_meta("arms_kind", "")) == "gen2_36", "%s strip 团徽" % where)
		_ok(fa != null and str(fa.get_meta("arms_kind", "")) in ["gen2_06", "gen2_35"], "%s TrainFocusArms" % where)
		if ca != null and fa != null:
			_ok(str(ca.get_meta("arms_core", "")) != str(fa.get_meta("arms_core", "")), "%s 团徽!=瞳徽" % where)
		_ok(bool(strip.get_meta("has_pupil", false)), "%s has_pupil" % where)
	var rows: Array = []
	_collect(page, "TrainRowArms", rows)
	_ok(rows.size() >= 2, "%s TrainRowArms>=2 (pupil+tutor)" % where)
	var kinds := {}
	for a in rows:
		var k := str(a.get_meta("arms_kind", ""))
		_ok(k in ["gen2_06", "gen2_35"], "%s TrainRowArms kind" % where)
		_ok(a.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s TrainRowArms mouse" % where)
		kinds[k] = true
	_ok(kinds.has("gen2_06") or kinds.has("gen2_35"), "%s saw person arms" % where)

func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	_boot()
	var page: Control = TRAIN_SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(14)
	_assert_page(page, "desk")
	page.queue_free()
	await _settle(2)

func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE")
	_boot()
	var page: Control = TRAIN_SCN.instantiate()
	get_tree().root.add_child(page)
	await _settle(10)
	if page.has_method("apply_mobile_layout"):
		page.apply_mobile_layout()
		await _settle(10)
	_assert_page(page, "mob")
	var strip := page.find_child("TrainFocusStrip", true, false) as Control
	if strip != null:
		_ok(strip.position.x >= 8.0, "mob strip anchored")
	page.queue_free()
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")
