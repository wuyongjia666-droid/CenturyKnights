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
	GameState.new_game("探针", "灰旗", "#6ED4FF")
	# Without the lease-kept flag, nothing is posted.
	var empty: Dictionary = World.ensure_opening_herb_escort()
	if not empty.is_empty():
		return "posted without pro_lease_kept"
	GameState.set_flag("pro_lease_kept")
	var q: Dictionary = World.ensure_opening_herb_escort()
	if q.is_empty():
		return "no quest posted"
	if str(q.get("id", "")) != "q_opening_herb_escort":
		return "bad id %s" % q.get("id")
	if str(q.get("kind", "")) != "escort":
		return "not escort"
	if str(q.get("issuer", "")) != "hq" or str(q.get("target", "")) != "lb_mid":
		return "bad route %s→%s" % [q.get("issuer"), q.get("target")]
	if int(q.get("reward_silver", 0)) < 60:
		return "pay too low: %s" % q.get("reward_silver")
	# Idempotent.
	var q2: Dictionary = World.ensure_opening_herb_escort()
	if str(q2.get("id", "")) != "q_opening_herb_escort":
		return "second ensure lost quest"
	var on_board := 0
	for o in World.board("hq"):
		if str(o.get("id", "")) == "q_opening_herb_escort":
			on_board += 1
	if on_board != 1:
		return "board copies=%d" % on_board
	# Accept from story helper (may teleport pos briefly).
	World.pos = "hq"
	var ar: Dictionary = World.accept_opening_herb_escort()
	if not bool(ar.get("ok", false)):
		return "accept failed: %s" % ar.get("msg")
	var active: Dictionary = World.quest_by_id("q_opening_herb_escort")
	if active.is_empty() or str(active.get("state", "")) != "active":
		return "not active after accept"
	# Travel to target → ready → turn in for 60 silver.
	var before := GameState.silver
	World.pos = "lb_mid"
	# Simulate arrival hook used by travel.
	for aq in World.active:
		if str(aq.get("id", "")) == "q_opening_herb_escort":
			aq.state = "ready"
	var tr: Dictionary = World.turn_in("q_opening_herb_escort")
	if not bool(tr.get("ok", false)):
		return "turn_in failed: %s" % tr.get("msg", tr)
	if GameState.silver < before + 60:
		return "silver %d → %d, expected +60" % [before, GameState.silver]
	return ""
