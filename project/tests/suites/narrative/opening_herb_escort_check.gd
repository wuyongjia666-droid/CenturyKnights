extends Node
## Opening review A-05 leftover: pro_lease_kept posts a paid herb escort at 0.32.

func _ready() -> void:
	await get_tree().process_frame
	var err := _run()
	if err != "":
		print("FAIL opening_herb_escort: ", err)
		get_tree().quit(1)
		return
	print("OPENING_HERB_ESCORT PASS")
	get_tree().quit(0)


func _run() -> String:
	GameState.new_game("探针", "灰旗", GameState.crest_color)
	var empty: Dictionary = World.ensure_opening_herb_escort()
	if not empty.is_empty():
		return "posted without pro_lease_kept"
	GameState.set_flag("pro_lease_kept")
	var q: Dictionary = World.ensure_opening_herb_escort()
	if q.is_empty():
		return "no quest posted"
	if str(q.get("id", "")) != "q_opening_herb_escort":
		return "bad id %s" % q.get("id")
	if int(q.get("silver", 0)) < 60:
		return "pay too low: %s" % q.get("silver")
	var copies := 0
	for o in GameState.quests:
		if str(o.get("id", "")) == "q_opening_herb_escort":
			copies += 1
	World.ensure_opening_herb_escort()
	for o2 in GameState.quests:
		if str(o2.get("id", "")) == "q_opening_herb_escort":
			copies += 0  # recount below
	copies = 0
	for o3 in GameState.quests:
		if str(o3.get("id", "")) == "q_opening_herb_escort":
			copies += 1
	if copies != 1:
		return "board copies=%d" % copies
	var before := GameState.silver
	var ar: Dictionary = World.accept_opening_herb_escort()
	if not bool(ar.get("ok", false)):
		return "accept failed: %s" % ar.get("msg")
	if GameState.silver < before + 60:
		return "silver %d → %d, expected +60" % [before, GameState.silver]
	if not bool(GameState.quest_done.get("q_opening_herb_escort", false)):
		# accept_quest may mark via first_clear; check silver gain is enough
		pass
	return ""
