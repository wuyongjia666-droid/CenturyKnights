extends Node
## Opening review batch 1: grey cloth, surname on the banner, empty surname greys the button,
## and the founding preview face is the captain you get in game.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL founding_b1: ", err)
		get_tree().quit(1)
		return
	print("FOUNDING B1 PASS")
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
	if page._surname.text != "":
		return "surname should start empty (B-05)"
	if not page._start_btn.disabled:
		return "raise button enabled with empty surname (B-06)"
	if page._surname.max_length != 2:
		return "surname max_length %d" % page._surname.max_length
	page._surname.text = "岑"
	page._surname.text_changed.emit("岑")
	await get_tree().process_frame
	if page._start_btn.disabled:
		return "raise button still disabled after writing a surname"
	var tag: Label = page._banner.get_node_or_null(BannerName.NODE)
	if tag == null or not tag.visible or tag.text != "岑":
		return "surname not written on the banner (B-02)"
	var spec: Dictionary = page._current_spec()
	var grey := Color(str(spec.get("field_a", "")))
	if absf(grey.r - grey.g) > 0.03 or absf(grey.g - grey.b) > 0.03:
		return "banner cloth is not grey: %s (B-09)" % spec.get("field_a")
	var face_genome := JSON.stringify(page._face.genome)
	# Same steps as _on_start without the scene change.
	var g: String = page._given.text.strip_edges()
	GameState.new_game(g, "岑", page._heart())
	var lead: CKCharacter = GameState.get_leader()
	lead.genome = page._face.genome.duplicate(true)
	if JSON.stringify(lead.genome) != face_genome:
		return "captain genome differs from preview (B-03)"
	UnitArt.clear_cache()
	CKGenomePortrait.clear_mem()
	var a: Texture2D = UnitArt.portrait(page._face, 280, CKArtPaths.TIER_MEDIUM)
	UnitArt.clear_cache()
	CKGenomePortrait.clear_mem()
	var b: Texture2D = UnitArt.portrait(lead, 280, CKArtPaths.TIER_MEDIUM)
	if a == null or b == null or a.get_image().get_data() != b.get_image().get_data():
		return "preview face != in-game captain face (B-03)"
	if GameState.crest_color != page._heart():
		return "crest colour is not the heart colour"
	return ""
