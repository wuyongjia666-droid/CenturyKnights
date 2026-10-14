extends Node
## Improve #3: first smith visit reveals a signature arm once.

func _ready() -> void:
	await get_tree().process_frame
	var err: String = await _run()
	if err != "":
		print("FAIL smith reveal: ", err)
		get_tree().quit(1)
		return
	print("SMITH REVEAL PASS")
	get_tree().quit(0)

func _run() -> String:
	GameState.new_game("铁匠", "灰旗", GameState.crest_color)
	GameState.settings.erase("smith_revealed")
	World.pos = "ash_capital"
	var err := _logic()
	if err != "":
		return err
	return await _ui()

func _logic() -> String:
	var first: Dictionary = World.next_smith_reveal("ash_capital")
	if first.is_empty():
		return "ash_capital has no signature to reveal"
	var iid := str(first.id)
	if World.is_smith_revealed(iid):
		return "already revealed before mark"
	World.mark_smith_revealed(iid)
	if not World.is_smith_revealed(iid):
		return "mark failed"
	var again: Dictionary = World.next_smith_reveal("ash_capital")
	if not again.is_empty() and str(again.id) == iid:
		return "same signature offered again"
	return ""

func _ui() -> String:
	GameState.settings.erase("smith_revealed")
	var city_sc = load("res://scenes/hub/city.tscn")
	var c = city_sc.instantiate()
	add_child(c)
	await get_tree().process_frame
	c.call("_set_tab", "smith")
	await get_tree().process_frame
	await get_tree().process_frame
	var overlay = c.find_child("SmithReveal", true, false)
	if overlay == null:
		c.queue_free()
		return "no SmithReveal overlay on first smith tab"
	var skip = c.find_child("SmithRevealSkip", true, false) as Button
	if skip == null:
		c.queue_free()
		return "no skip button"
	skip.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	if World.smith_revealed().is_empty():
		c.queue_free()
		return "UI skip did not mark revealed"
	for e in World.smith_stock("ash_capital"):
		if int(e.get("signature", 0)) >= 1:
			World.mark_smith_revealed(str(e.item.id))
	c.call("_set_tab", "overview")
	await get_tree().process_frame
	c.call("_set_tab", "smith")
	await get_tree().process_frame
	await get_tree().process_frame
	var still = c.find_child("SmithReveal", true, false)
	c.queue_free()
	if still != null:
		return "reveal still shown after all signatures marked"
	return ""
