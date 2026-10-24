extends Node
## Y1-B: heir_rivalry settled-year path exposes a named forward CTA (ToInheritance).
## Empty (#30) already has ToMarriage — this knife only covers the settled dead-end.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL heir settled cta: ", err)
		get_tree().quit(1)
	else:
		print("HEIR SETTLED CTA PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	var lead: CKCharacter = GameState.get_leader()
	if lead == null:
		return "no leader"
	_seed_heir("heir_a", "长嗣甲", 12, lead.id)
	_seed_heir("heir_b", "次嗣乙", 10, lead.id)
	GameState.house_mods["heir_rivalry_year"] = Calendar.year
	GameState.house_mods["heir_rivalry_zh"] = Locale.t("lb_heir_zh_mediate")

	var page: Control = load("res://scenes/hub/heir_rivalry.tscn").instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	for _i in 8:
		await get_tree().process_frame

	var err := _audit(page)
	page.queue_free()
	return err


func _seed_heir(id: String, nm: String, age: int, parent_id: String) -> void:
	var kid := CKCharacter.new()
	kid.id = id
	kid.name = nm
	kid.alive = true
	kid.is_child = true
	kid.age = age
	kid.parent_ids = [parent_id]
	kid.in_roster = false
	kid.traits = ["martial"]
	kid.apt_max = {"str": 20, "vit": 20, "skl": 20, "agi": 20, "per": 20, "wil": 20}
	kid.stats = {"str": 8, "vit": 8, "skl": 8, "agi": 8, "per": 8, "wil": 8}
	kid.blood_meta = {"purse": 0}
	GameState.characters[kid.id] = kid
	GameState.lineage_path[kid.id] = "martial"


func _audit(page: Control) -> String:
	var body: Label = page.find_child("HeirText", true, false) as Label
	if body == null:
		return "HeirText missing"
	var zh := str(GameState.house_mods.get("heir_rivalry_zh", ""))
	if body.text.find(zh) < 0:
		return "HeirText missing settled zh (%s)" % zh

	var cta: Button = page.find_child("ToInheritance", true, false) as Button
	if cta == null:
		return "ToInheritance missing"
	if not cta.visible:
		return "ToInheritance not visible"
	var want := Locale.t("lb_heir_to_inheritance")
	if cta.text != want:
		return "ToInheritance text want=%s got=%s" % [want, cta.text]

	## Quarrel moves must stay off in settled year.
	for k in ["mediate", "a", "b", "duel"]:
		if page.find_child("Move_" + k, true, false) != null:
			return "Move_%s present in settled year" % k

	var moves := page.find_child("Moves", true, false) as Node
	if moves != null and not moves.is_ancestor_of(cta):
		return "ToInheritance not under Moves"

	print("heir-settled ok ToInheritance under_moves=1")
	return ""
