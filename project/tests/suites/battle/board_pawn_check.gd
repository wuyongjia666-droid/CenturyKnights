extends Node
## Low-fi board pawns: genome tint; opt-out via settings.board_pawns_3d.

func _ready() -> void:
	await get_tree().process_frame
	var err := _run()
	if err != "":
		print("FAIL board pawn: ", err)
		get_tree().quit(1)
		return
	print("BOARD PAWN PASS")
	get_tree().quit(0)

func _run() -> String:
	GameState.new_game("棋子", "灰旗", GameState.crest_color)
	GameState.settings.erase("board_pawns_3d")
	if not UnitArt.board_pawns_enabled():
		return "default should enable pawns"
	var a: CKCharacter = GameState.get_leader()
	var b: CKCharacter = null
	for c in GameState.roster():
		if c != a:
			b = c
			break
	if b == null:
		return "need a second roster member"
	var ta: Texture2D = UnitArt.board_pawn_texture(a, "player", 64, false)
	var te: Texture2D = UnitArt.board_pawn_texture(a, "enemy", 64, false)
	if ta == null or te == null:
		return "null texture"
	if ta.get_image().get_pixel(32, 32).a < 0.1:
		return "empty center pixel"
	var same := true
	var ia := ta.get_image()
	var ie := te.get_image()
	for y in range(16, 48, 4):
		for x in range(16, 48, 4):
			if not ia.get_pixel(x, y).is_equal_approx(ie.get_pixel(x, y)):
				same = false
				break
		if not same:
			break
	if same:
		return "player and enemy pawns look identical"
	GameState.settings["board_pawns_3d"] = false
	if UnitArt.board_pawns_enabled():
		return "opt-out failed"
	GameState.settings["board_pawns_3d"] = true
	var tok: Texture2D = UnitArt.token(a, "player", 48, false)
	if tok == null:
		return "UnitArt.token null with pawns on"
	return ""
