extends Node
## After accepting a world commission: next-step hint, atlas deep-link meta, hub todo count.

const Todo := preload("res://scripts/ui/widgets/todo_center.gd")

func _ready() -> void:
	await get_tree().process_frame
	var err := await _run()
	if err != "":
		print("FAIL quest guide: ", err)
		get_tree().quit(1)
		return
	print("QUEST GUIDE PASS")
	get_tree().quit(0)

func _run() -> String:
	Todo.reset_for_tests()
	GameState.new_game("指引", "灰旗", GameState.crest_color)
	World.events_enabled = false
	World.rivals_enabled = false
	World.pos = "ash_capital"
	World.rep_city["ash_capital"] = 80
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 40
	World.active.clear()
	World.boards.erase("ash_capital")
	var err := _accept_sample()
	if err != "":
		return err
	var pick_id := str(World.active[0].id)
	var guide := World.quest_guide_node(World.quest_by_id(pick_id))
	err = _check_todo_and_ready(pick_id, guide)
	if err != "":
		return err
	err = await _check_city_cta(pick_id)
	if err != "":
		return err
	return await _check_atlas_focus(guide)

func _accept_sample() -> String:
	var offers: Array = World.board("ash_capital")
	var pick: Dictionary = {}
	for q in offers:
		if World.quest_locked_reason(q) != "":
			continue
		if str(q.get("kind", "")) == "gather":
			continue
		var probe: Dictionary = q.duplicate(true)
		probe["state"] = "active"
		if World.quest_guide_node(probe) == World.pos:
			continue
		pick = q
		break
	if pick.is_empty():
		var r := RandomNumberGenerator.new()
		r.seed = 42
		pick = World._make_quest("ash_capital", "deliver", 1, r)
		if pick.is_empty():
			return "no offer"
		World.boards["ash_capital"]["offers"].append(pick)
	var acc: Dictionary = World.accept_quest("ash_capital", str(pick.id))
	if not bool(acc.get("ok", false)):
		return "accept failed: %s" % str(acc.get("msg", ""))
	var guide := str(acc.get("guide_node", ""))
	if guide == "" or not World.nodes.has(guide):
		return "guide_node missing (%s)" % guide
	if World.quest_guide_node(World.quest_by_id(str(pick.id))) != guide:
		return "guide helper mismatch"
	var hint := str(acc.get("hint", ""))
	if hint == "" or str(acc.get("msg", "")).find(hint) < 0:
		return "hint not in accept msg"
	if Locale.t("wq_goto_atlas") == "wq_goto_atlas":
		return "missing wq_goto_atlas locale"
	if not World.quest_markers().has(guide):
		return "quest_markers missing guide %s for kind %s" % [guide, str(pick.get("kind", ""))]
	return ""

func _check_todo_and_ready(pick_id: String, guide: String) -> String:
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	var n := 0
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "quests":
			n = int(item.get("count", 0))
	if Todo.is_unlocked("quests") and n < 1:
		return "todo quests count %d after accept" % n
	var q2: Dictionary = World.quest_by_id(pick_id)
	q2.state = "ready"
	var turn := World.turn_in_city(q2)
	if World.quest_guide_node(q2) != turn:
		return "ready guide should be turn-in"
	if World.quest_next_hint(q2).find(str(World.node(turn).get("name", ""))) < 0:
		return "ready hint missing place"
	q2.state = "active"
	if guide == "":
		return "empty guide"
	return ""

func _check_city_cta(pick_id: String) -> String:
	GameState.set_meta("city_id", "ash_capital")
	var packed: PackedScene = load("res://scenes/hub/city.tscn")
	if packed == null:
		return "city scene missing"
	var page = packed.instantiate()
	add_child(page)
	await get_tree().process_frame
	page._set_tab("board")
	page._sel_quest = pick_id
	page._render_tab()
	await get_tree().process_frame
	var btn := page.find_child("GotoAtlasQuest", true, false)
	var missing := btn == null
	page.queue_free()
	if missing:
		return "GotoAtlasQuest button missing on active detail"
	return ""

func _check_atlas_focus(guide: String) -> String:
	GameState.set_meta("atlas_select", guide)
	GameState.set_meta("atlas_view", World.nation_of(guide))
	var ap: PackedScene = load("res://scenes/hub/atlas_view.tscn")
	var atlas = ap.instantiate()
	add_child(atlas)
	await get_tree().process_frame
	await get_tree().process_frame
	var got := str(atlas._sel)
	var kept := GameState.has_meta("atlas_select")
	atlas.queue_free()
	if got != guide:
		return "atlas _sel=%s want %s" % [got, guide]
	if kept:
		return "atlas_select meta not consumed"
	return ""
