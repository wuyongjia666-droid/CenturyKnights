extends Node
## Y1-B deep cross-chain: Lineage.marry(paced) → pregnancy echo → deliver → birth echo;
## estates/hourglass readback; child parent/heir links. Odds untouched (reseed only).

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL month echo marry-preg-birth: ", err)
		get_tree().quit(1)
	else:
		print("MONTH ECHO MARRY PREG BIRTH PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.house_mods.erase("month_echo")
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.add_rep("ashland", 80)
	GameState.silver = maxi(int(GameState.silver), 200)

	var err := _audit_marry_pregnancy()
	if err != "":
		return err
	err = await _audit_panel("pregnancy", "res://scenes/hub/estates.tscn", "MonthEchoPanel")
	if err != "":
		return err
	err = await _audit_panel("pregnancy", "res://scenes/hub/hourglass.tscn", "")
	if err != "":
		return err
	err = _audit_birth_and_heir()
	if err != "":
		return err
	err = await _audit_panel("birth", "res://scenes/hub/estates.tscn", "MonthEchoPanel")
	if err != "":
		return err
	err = await _audit_panel("birth", "res://scenes/hub/hourglass.tscn", "")
	if err != "":
		return err
	return ""


func _couple(tag: String, age: int) -> Array:
	var hus := CKCharacter.new()
	hus.id = "%s_h" % tag
	hus.name = "%s夫" % tag
	hus.gender = "m"
	hus.age = age
	hus.rank = "knight"
	hus.alive = true
	hus.in_roster = true
	hus.retired = false
	hus.is_leader = false
	hus.is_child = false
	hus.blood_mix = {"common_ash": 1.0}
	hus.stats = {"str": 8, "vit": 7, "skl": 6, "agi": 5, "per": 4, "wil": 9}
	var wife := CKCharacter.new()
	wife.id = "%s_w" % tag
	wife.name = "%s妻" % tag
	wife.gender = "f"
	wife.age = age
	wife.rank = "knight"
	wife.alive = true
	wife.in_roster = true
	wife.retired = false
	wife.is_leader = false
	wife.is_child = false
	wife.pregnant_months = -1
	wife.blood_mix = {"common_ash": 1.0}
	wife.blood_meta = {"children_born": 0}
	wife.stats = {"str": 5, "vit": 8, "skl": 6, "agi": 6, "per": 5, "wil": 8}
	GameState.characters[hus.id] = hus
	GameState.characters[wife.id] = wife
	return [hus, wife]


## Holds the married couple across audits so birth can finish the same chain.
var _father: CKCharacter
var _mother: CKCharacter


func _audit_marry_pregnancy() -> String:
	GameState.house_mods.erase("month_echo")
	var couple := _couple("chain_mp", 24)
	_father = couple[0]
	_mother = couple[1]
	## paced=true → begin_pregnancy (real PEAK odds); reseed until conceive — no rate boost.
	var wed: Dictionary = {}
	var ok := false
	for seed in range(1, 80):
		_mother.pregnant_months = -1
		_mother.blood_meta.erase("gestation_term")
		_mother.blood_meta.erase("litter")
		_mother.spouse_id = ""
		_father.spouse_id = ""
		GameState.house_mods.erase("month_echo")
		GameState.rng.seed = seed
		GameState.silver = maxi(int(GameState.silver), 200)
		wed = Lineage.marry(_father, _mother, 40, null, true)
		if not bool(wed.get("ok", false)):
			continue
		if _mother.pregnant_months >= 0:
			ok = true
			break
	if not ok:
		return "paced marry never conceived in 79 seeds (odds gate?): last=%s" % str(wed.get("msg", ""))
	if str(_father.spouse_id) != _mother.id or str(_mother.spouse_id) != _father.id:
		return "spouse link broken after marry"
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var tx := str(snap.get("pregnancy", ""))
	if tx == "":
		return "pregnancy echo empty after paced marry: %s" % str(snap)
	if tx.find(_mother.name) < 0:
		return "pregnancy echo missing mother: %s" % tx
	if tx.find("身孕") < 0 and tx.find("with child") < 0:
		return "pregnancy echo wording: %s" % tx
	print("chain marry→pregnancy ok line=%s term=%s" % [tx, str(_mother.blood_meta.get("gestation_term", "?"))])
	return ""


func _audit_birth_and_heir() -> String:
	if _mother == null or _father == null:
		return "couple missing before birth"
	GameState.house_mods.erase("month_echo")
	## Compress gestation: one advance delivers when pregnant_months hits <0.
	_mother.pregnant_months = 0
	_mother.blood_meta["litter"] = 1
	var before_kids := _mother.children_ids.size()
	Calendar.advance(1)
	if _mother.children_ids.size() <= before_kids:
		return "no birth after deliver advance"
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var tx := str(snap.get("birth", ""))
	if tx == "":
		return "birth echo empty after chain deliver: %s" % str(snap)
	if tx.find(_mother.name) < 0:
		return "birth echo missing mother: %s" % tx
	if tx.find("诞下") < 0 and tx.find("bore") < 0:
		return "birth echo wording: %s" % tx
	## Heir link: newborn is child of both parents.
	var kid_id := str(_mother.children_ids[_mother.children_ids.size() - 1])
	if not GameState.characters.has(kid_id):
		return "newborn missing from characters: %s" % kid_id
	var kid: CKCharacter = GameState.characters[kid_id]
	if not kid.is_child:
		return "newborn not marked is_child"
	var parents: Array = kid.parent_ids
	if _father.id not in parents or _mother.id not in parents:
		return "heir parent_ids missing father/mother: %s" % str(parents)
	if kid_id not in _father.children_ids:
		return "father.children_ids missing newborn"
	if kid_id not in _mother.children_ids:
		return "mother.children_ids missing newborn"
	print("chain pregnancy→birth→heir ok line=%s kid=%s" % [tx, kid.name])
	return ""


func _audit_panel(kind: String, scene_path: String, panel_name: String) -> String:
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var want := str(snap.get(kind, ""))
	if want == "":
		return "no %s in snap before %s" % [kind, scene_path]
	var page: Control = load(scene_path).instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	for _i in 8:
		await get_tree().process_frame
	var scope: Node = page
	if panel_name != "":
		var panel := page.find_child(panel_name, true, false)
		if panel == null:
			page.queue_free()
			return "%s missing on %s" % [panel_name, scene_path]
		scope = panel
	var line_name := "EchoLine_%s" % kind
	var line := page.find_child(line_name, true, false) as Label
	var bit := want.substr(0, mini(6, want.length()))
	if line == null:
		var hit := false
		for n in scope.find_children("*", "Label", true, false):
			if str((n as Label).text).find(bit) >= 0:
				hit = true
				break
		if not hit:
			page.queue_free()
			return "%s missing bit=%s on %s" % [line_name, bit, scene_path]
	elif str(line.text).find(bit) < 0:
		page.queue_free()
		return "%s text mismatch on %s" % [line_name, scene_path]
	print("month-echo %s ok on %s" % [kind, scene_path.get_file()])
	page.queue_free()
	await get_tree().process_frame
	return ""
