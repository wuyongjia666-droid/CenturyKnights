extends Node
## Fat atlas: road merc hire → last_march_muster + MarchMusterModal + party/ration refresh.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_setup()
	_api_mark_and_take()
	_api_choose_recruit_sets_muster()
	await _ui_muster_modal_and_party_row()
	if _fails.is_empty():
		print("ATLAS ROAD MERC MUSTER PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL atlas road merc muster: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _setup() -> void:
	GameState.new_game("MercMuster", "AshBanner", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.food = 100
	GameState.silver = 500
	GameState.morale = 70
	World.pos = "ash_capital"
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.last_march_muster = {}
	World.last_aftermath = {}
	_pad_party(3)

func _pad_party(n: int) -> void:
	var have := World.party_size()
	var i := 0
	while have < n:
		i += 1
		var cid := "muster_pad_%d" % i
		if GameState.characters.has(cid):
			have = World.party_size()
			continue
		var c := CKCharacter.new()
		c.id = cid
		c.name = "Pad%d" % i
		c.alive = true
		c.is_child = false
		c.in_roster = true
		c.age = 22
		c.stats = {"str": 10, "agi": 10, "vit": 10, "wil": 10, "per": 10, "skl": 10}
		GameState.characters[cid] = c
		have = World.party_size()
	_ok(World.party_size() >= n, "party padded to %d (got %d)" % [n, World.party_size()])

func _api_mark_and_take() -> void:
	World.last_march_muster = {}
	var stub := CKCharacter.new()
	stub.id = "muster_stub"
	stub.name = "StubMerc"
	stub.alive = true
	stub.in_roster = true
	GameState.characters[stub.id] = stub
	var p0 := World.party_size() - 1
	var r0 := maxi(1, World.food_per_day() - 1)
	World._mark_march_muster(stub, 40, p0, r0)
	_ok(not World.last_march_muster.is_empty(), "last_march_muster set")
	_ok(str(World.last_march_muster.get("name", "")) == "StubMerc", "muster name")
	_ok(int(World.last_march_muster.get("cost", 0)) == 40, "muster cost")
	_ok(int(World.last_march_muster.get("party_after", 0)) == World.party_size(), "party_after")
	var taken := World.take_march_muster()
	_ok(not taken.is_empty(), "take_march_muster")
	_ok(World.last_march_muster.is_empty(), "cleared after take")
	World.dismiss_march_muster()

func _api_choose_recruit_sets_muster() -> void:
	_setup()
	GameState.silver = 500
	var p_before := World.party_size()
	var r_before := World.food_per_day()
	World.make_event("merc", "ash_capital", "stone_slope")
	_ok(not World.pending_event.is_empty(), "merc pending_event")
	_ok(str(World.pending_event.get("id", "")) == "merc", "event id merc")
	var hire := int(World.pending_event.get("ctx", {}).get("hire", 0))
	_ok(hire > 0, "hire cost > 0 (%d)" % hire)
	var r: Dictionary = World.choose_event(0)
	_ok(bool(r.get("ok", false)), "choose_event ok")
	_ok(not World.last_march_muster.is_empty() or r.has("march_muster"), "muster payload after recruit")
	var mm: Dictionary = World.last_march_muster if not World.last_march_muster.is_empty() else r.get("march_muster", {})
	_ok(int(mm.get("party_before", -1)) == p_before, "party_before matches")
	_ok(int(mm.get("party_after", -1)) == World.party_size(), "party_after matches live")
	_ok(World.party_size() == p_before + 1, "party grew by 1")
	_ok(int(mm.get("ration_before", -1)) == r_before, "ration_before matches")
	_ok(int(mm.get("ration_after", -1)) == World.food_per_day(), "ration_after matches live")
	_ok(World.food_per_day() >= r_before, "rations not down after hire")
	_ok(str(mm.get("name", "")) != "", "hired name set")
	# Decline path: no silver → no muster
	_setup()
	GameState.silver = 0
	World.last_march_muster = {}
	World.make_event("merc", "ash_capital", "stone_slope")
	var r2: Dictionary = World.choose_event(0)
	_ok(bool(r2.get("ok", false)), "choose decline-path ok")
	_ok(World.last_march_muster.is_empty(), "no muster when broke")

func _ui_muster_modal_and_party_row() -> void:
	_setup()
	GameState.silver = 500
	World.make_event("merc", "ash_capital", "stone_slope")
	var p_before := World.party_size()
	var page: Node = ATLAS_SCN.instantiate()
	add_child(page)
	for _i in 16:
		await get_tree().process_frame
	var ev: Node = page.find_child("EventModal", true, false)
	_ok(ev != null, "EventModal on resume")
	var opt: Button = page.find_child("EventOpt0", true, false) as Button
	_ok(opt != null, "EventOpt0 hire")
	if opt != null:
		opt.pressed.emit()
	# Aftermath then muster
	var saw_muster := false
	for _i in 90:
		await get_tree().process_frame
		var af_cont: Button = page.find_child("AftermathContinue", true, false) as Button
		if af_cont != null:
			af_cont.pressed.emit()
			continue
		var modal: Node = page.find_child("MarchMusterModal", true, false)
		if modal != null:
			saw_muster = true
			var body: Node = modal.find_child("MarchMusterBody", true, false)
			_ok(body != null, "MarchMusterBody")
			_ok(modal.find_child("MarchMusterCost", true, false) != null, "MarchMusterCost")
			_ok(modal.find_child("MarchMusterRation", true, false) != null, "MarchMusterRation")
			var ok_btn: Button = modal.find_child("MarchMusterOk", true, false) as Button
			_ok(ok_btn != null, "MarchMusterOk")
			if ok_btn != null:
				ok_btn.pressed.emit()
				for _j in 10:
					await get_tree().process_frame
			break
	_ok(saw_muster, "MarchMusterModal present")
	_ok(page.find_child("MarchMusterModal", true, false) == null, "modal closed after ok")
	if page.has_method("_render_left"):
		page.call("_render_left")
		for _i in 6:
			await get_tree().process_frame
	var row: Node = page.find_child("PartyMusterRow", true, false)
	_ok(row != null, "PartyMusterRow after render")
	var ration_row: Node = page.find_child("MarchRationRow", true, false)
	_ok(ration_row != null, "MarchRationRow after muster")
	_ok(World.party_size() == p_before + 1, "ui party grew")
	page.queue_free()
