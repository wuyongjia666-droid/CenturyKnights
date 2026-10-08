extends Node
## UX-01：灯引洞矩形、安全区、tutorial_highlight 开关、存档往返只触发一次。

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	CKTips.reset_for_tests()
	CKHelpCodex.reset_for_tests()
	await _hole_and_safe()
	await _multi_step()
	_highlight_off()
	_codex_opens()
	await _save_roundtrip()
	if _fails.is_empty():
		print("COACH PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL coach: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)

func _hole_and_safe() -> void:
	var host := Control.new()
	host.name = "TallHost"
	host.position = Vector2.ZERO
	host.size = CKCoach.TALL_VIEWPORT
	host.custom_minimum_size = CKCoach.TALL_VIEWPORT
	add_child(host)
	var btn := Button.new()
	btn.name = "Deploy"
	btn.text = "出战编队"
	btn.position = Vector2(120, 220)
	btn.size = Vector2(240, 56)
	btn.custom_minimum_size = Vector2(240, 56)
	host.add_child(btn)
	await get_tree().process_frame
	await get_tree().process_frame
	var safe := CKCoach.safe_rect(CKCoach.TALL_VIEWPORT, CKCoach.TALL_INSETS)
	var coach := CKCoach.attach(host)
	coach.present_target(btn, "先编排出战的人，再离开城堡。", safe)
	await get_tree().process_frame
	await get_tree().process_frame
	var target := btn.get_global_rect()
	var hole := coach.hole
	_ok(absf(hole.position.x - target.position.x) <= 2.0, "hole x %s vs %s" % [hole, target])
	_ok(absf(hole.position.y - target.position.y) <= 2.0, "hole y %s vs %s" % [hole, target])
	_ok(absf(hole.size.x - target.size.x) <= 2.0, "hole w %s vs %s" % [hole, target])
	_ok(absf(hole.size.y - target.size.y) <= 2.0, "hole h %s vs %s" % [hole, target])
	_ok(safe.encloses(hole.grow(-0.5)) or _rect_inside(hole, safe, 2.0), "hole inside tall safe %s safe %s" % [hole, safe])
	var callout := coach.callout_rect()
	_ok(_rect_inside(callout, safe, 2.0), "callout inside tall safe %s safe %s" % [callout, safe])
	coach.queue_free()
	host.queue_free()
	await get_tree().process_frame

func _rect_inside(inner: Rect2, outer: Rect2, slack: float) -> bool:
	var grown := outer.grow(slack)
	return grown.encloses(Rect2(inner.position, Vector2(0.5, 0.5))) and grown.encloses(Rect2(inner.end - Vector2(0.5, 0.5), Vector2(0.5, 0.5)))

func _multi_step() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	add_child(host)
	var a := Button.new()
	a.position = Vector2(80, 80)
	a.size = Vector2(180, 48)
	host.add_child(a)
	var b := Button.new()
	b.position = Vector2(400, 200)
	b.size = Vector2(180, 48)
	host.add_child(b)
	await get_tree().process_frame
	var coach := CKCoach.attach(host)
	var done := {"ok": false}
	coach.finished.connect(func(): done["ok"] = true)
	coach.play_steps([
		{"target": a, "text": "第一步"},
		{"target": b, "text": "第二步"},
	])
	await get_tree().process_frame
	_ok(coach.hole.position.distance_to(a.get_global_rect().position) <= 2.0, "step1 hole")
	coach.advance()
	_ok(is_instance_valid(coach) and coach.hole.position.distance_to(b.get_global_rect().position) <= 2.0, "step2 hole")
	coach.advance()
	_ok(bool(done["ok"]), "sequence finished")
	host.queue_free()
	await get_tree().process_frame

func _highlight_off() -> void:
	var prev = GameState.settings.get("tutorial_highlight", true)
	GameState.settings["tutorial_highlight"] = false
	CKTips.register({"id": "should_not_fire", "scene_name": "OffHost", "text": "不应出现"})
	var host := Control.new()
	host.name = "OffHost"
	add_child(host)
	var btn := Button.new()
	btn.size = Vector2(80, 44)
	host.add_child(btn)
	_ok(CKTips.maybe_present(host) == false, "highlight off still presented")
	_ok(host.find_child("LampCoach", true, false) == null, "highlight off spawned coach")
	_ok(CKTips.pending_for(host).is_empty(), "highlight off pending")
	GameState.settings["tutorial_highlight"] = prev
	host.queue_free()

func _codex_opens() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	add_child(host)
	var panel := CKHelpCodex.open(host)
	_ok(panel != null and panel.name == "HelpCodex", "codex open")
	_ok(CKHelpCodex.entry_count() >= 6, "codex entries %d" % CKHelpCodex.entry_count())
	_ok(panel.find_child("CodexList", true, false) != null, "codex list")
	_ok(panel.find_child("CodexEntry_board", true, false) != null, "board entry")
	CKHelpCodex.register_entry({"id": "extra_api", "title_text": "叙事接口", "body_text": "叙事流可以追加条目。"})
	_ok(CKHelpCodex.entry_count() >= 7, "narrative api")
	host.queue_free()

func _save_roundtrip() -> void:
	var path := GameState.SAVE_PATH
	var backup := ""
	var had := FileAccess.file_exists(path)
	if had:
		backup = FileAccess.get_file_as_string(path)
	GameState.new_game("灯引", "霜旗", GameState.crest_color)
	GameState.settings["tutorial_highlight"] = true
	CKTips.clear_seen()
	CKTips.register({"id": "round_once", "scene_name": "RoundHost", "text": "只此一次"})
	var host := Control.new()
	host.name = "RoundHost"
	host.size = Vector2(400, 300)
	add_child(host)
	var btn := Button.new()
	btn.position = Vector2(24, 24)
	btn.size = Vector2(160, 48)
	host.add_child(btn)
	await get_tree().process_frame
	_ok(CKTips.maybe_present(host), "first present")
	_ok(CKTips.is_seen("round_once"), "marked seen")
	_ok(GameState.save_game(), "save_game")
	CKTips.clear_seen()
	_ok(not CKTips.is_seen("round_once"), "cleared in memory")
	_ok(GameState.load_game(), "load_game")
	_ok(CKTips.is_seen("round_once"), "seen restored")
	var again := Control.new()
	again.name = "RoundHost"
	add_child(again)
	var btn2 := Button.new()
	btn2.size = Vector2(80, 44)
	again.add_child(btn2)
	_ok(CKTips.maybe_present(again) == false, "presented again after load")
	if had:
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string(backup)
			f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	host.queue_free()
	again.queue_free()
