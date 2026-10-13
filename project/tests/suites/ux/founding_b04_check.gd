extends Node
## Opening review B-04 / B-08 leftovers: gender + face pick, nation label split.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL founding_b04: ", err)
		get_tree().quit(1)
		return
	print("FOUNDING B04 PASS")
	get_tree().quit(0)


func _run() -> String:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	add_child(host)
	var page = load("res://scenes/story/naming.tscn").instantiate()
	host.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in 4:
		await get_tree().process_frame
	if page._gender != "m":
		return "default gender should be m"
	if page._faces.size() != 4:
		return "expected 4 face presets, got %d" % page._faces.size()
	if page._face == null or page._face.gender != "m":
		return "preview face gender is not m"
	var male_sig := JSON.stringify(page._face.genome)
	page._set_gender("f")
	for i in 4:
		await get_tree().process_frame
	if page._gender != "f":
		return "gender did not switch to f"
	if page._face == null or page._face.gender != "f":
		return "preview face gender is not f after switch"
	if page._faces.size() != 4:
		return "female face presets missing"
	var female_sig := JSON.stringify(page._face.genome)
	if female_sig == male_sig:
		return "female genome identical to male preset (faces not rebuilt)"
	# Pick face 2 and raise grey flag into a new game (no scene change).
	page._pick_face(2)
	await get_tree().process_frame
	page._surname.text = "岑"
	page._surname.text_changed.emit("岑")
	await get_tree().process_frame
	var g: String = page._given.text.strip_edges()
	GameState.new_game(g, "岑", page._heart())
	var lead: CKCharacter = GameState.get_leader()
	lead.gender = page._gender
	lead.genome = page._face.genome.duplicate(true)
	lead.appearance = page._face.appearance.duplicate(true)
	if lead.gender != "f":
		return "captain gender not persisted as f"
	if JSON.stringify(lead.genome) != JSON.stringify(page._face.genome):
		return "captain genome differs from selected face"
	# B-08: nation style row title must not equal the randomize button key text.
	var style_t := Locale.t("ux_name_nation_style")
	var rand_t := Locale.t("ux_name_nation_rand_btn")
	if style_t == "" or rand_t == "" or style_t == rand_t:
		return "nation style / randomize labels not split (B-08)"
	if Locale.t("ux_ord_chief") != "旗头横带":
		return "chief label not 旗头横带"
	if Locale.t("ux_charge_none") != "无图记":
		return "ordinary none not 无图记"
	return ""
