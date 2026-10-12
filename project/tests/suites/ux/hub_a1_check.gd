extends Node
## Audit #6/#7: title needs a confirm, no fake pad hints, new entries get a dot once.

const HUB := preload("res://scenes/hub/castle_hub.tscn")

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL hub a1: ", err)
		get_tree().quit(1)
	else:
		print("HUB A1 PASS")
		get_tree().quit(0)

func _hub() -> Node:
	var h := HUB.instantiate()
	add_child(h)
	await get_tree().process_frame
	return h

func _dots(h: Node) -> Array:
	return h.find_children("*", "Button", true, false).filter(func(b): return b.has_meta("new_entry"))

func _run() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.settings.erase("hub_seen")
	GameState.settings.erase("hub_told")
	var h = await _hub()
	if not _dots(h).is_empty():
		return "first visit should seed, not dot everything"
	for l in h.find_children("*", "Label", true, false):
		if l.text in ["GAMEPAD", "● READY", "B", "Y", "LB/RB"]:
			return "fake pad hint %s" % l.text
	var seen: Array = GameState.settings.hub_seen
	if seen.is_empty():
		return "nothing seeded"
	var gone := str(seen[0])
	seen.erase(gone)
	h.queue_free()
	h = await _hub()
	var d := _dots(h)
	if d.size() != 1 or str(d[0].get_meta("hub_entry")) != gone:
		return "new entry dot %s" % str(d.map(func(b): return b.get_meta("hub_entry")))
	if h._hint.text.find(Locale.t("a1_hub_new").split("%")[0]) < 0:
		return "no one-time line: %s" % h._hint.text
	h.mark_seen(str(d[0].get_meta("hub_entry")))
	if not GameState.settings.hub_seen.has(gone):
		return "tap did not mark seen"
	await get_tree().process_frame
	await get_tree().process_frame
	h = HUB.instantiate()
	add_child(h)
	await get_tree().process_frame
	if not _dots(h).is_empty():
		return "dot stayed after tap"
	h.confirm_title()
	var sheet: Node = h.get_node_or_null("TitleConfirm")
	if sheet == null or not CKNav.overlays.has(sheet):
		return "no confirm sheet"
	h.confirm_title()
	if h.find_children("TitleConfirm", "", true, false).size() != 1:
		return "repeat tap stacked sheets"
	(sheet.find_child("TitleStay", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	if is_instance_valid(sheet) and not sheet.is_queued_for_deletion():
		return "stay did not close"
	return ""
