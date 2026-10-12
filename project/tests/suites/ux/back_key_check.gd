extends Node
## Audit P2-7: Esc leaves sub-pages through their own _back(); castle and story open the pause menu.

func _ready() -> void:
	await get_tree().process_frame
	var err := _run()
	if err != "":
		print("FAIL back key: ", err)
		get_tree().quit(1)
	else:
		print("BACK KEY PASS")
		get_tree().quit(0)

func _run() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	for path in ["res://scenes/hub/tavern.tscn", "res://scenes/hub/lineage_view.tscn", "res://scenes/hub/marriage.tscn"]:
		var node: Node = (load(path) as PackedScene).instantiate()
		var got: String = MobileChrome.back_action(node)
		node.free()
		if got != "back":
			return "%s esc -> %s" % [path, got]
	for path in ["res://scenes/hub/castle_hub.tscn", "res://scenes/story/chapter_player.tscn"]:
		var node2: Node = (load(path) as PackedScene).instantiate()
		var got2: String = MobileChrome.back_action(node2)
		node2.free()
		if got2 != "pause":
			return "%s esc -> %s" % [path, got2]
	print("OK back key")
	return ""
