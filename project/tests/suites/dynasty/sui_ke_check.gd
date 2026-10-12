extends Node
## v9.2 P0：岁课争档祖辈席、习痕上限、不免死、出战钳制常量旁路。

func _ready() -> void:
	await get_tree().process_frame
	var fails: Array = []
	_marks(fails)
	_grandparents(fails)
	_yao_no_immunity(fails)
	_yan_zhan(fails)
	_deploy_cap(fails)
	if fails.is_empty():
		print("SUI KE PASS")
		get_tree().quit(0)
		return
	for f in fails:
		print("FAIL sui_ke: ", f)
	get_tree().quit(1)


func _marks(fails: Array) -> void:
	GameState.new_game("灰", "旗", "frost")
	var c := CKCharacter.new()
	c.id = "kid_marks"
	c.alive = true
	c.is_child = true
	c.age = 5
	c.apt_max = {"str": 20, "vit": 20, "skl": 20, "agi": 20, "per": 20, "wil": 20}
	c.stats = {"str": 8, "vit": 8, "skl": 8, "agi": 8, "per": 8, "wil": 8}
	c.blood_meta = {}
	# fill 9 birth marks by force
	var order := ["bridge", "lamp", "tide", "frost", "slip", "seize", "lie_age", "furnace", "copy"]
	for mid in order:
		var r := CKLifeMarks.add(c, mid, "birth")
		if not bool(r.get("ok", false)):
			fails.append("birth add %s" % mid)
	if CKLifeMarks.ids(c).size() != 9:
		fails.append("cap fill %d" % CKLifeMarks.ids(c).size())
	# add tutor mark: all birth → evict oldest birth
	var r2 := CKLifeMarks.add(c, "watch", "tutor")
	if not bool(r2.get("ok", false)):
		fails.append("tutor add")
	if str(r2.get("evicted", "")) != "bridge":
		fails.append("evict birth %s" % str(r2.get("evicted", "")))
	# mix: birth remain, evict oldest non-birth
	var r3 := CKLifeMarks.add(c, "ledger", "sui")
	if str(r3.get("evicted", "")) != "watch":
		fails.append("evict non-birth %s" % str(r3.get("evicted", "")))


func _grandparents(fails: Array) -> void:
	GameState.new_game("灰", "旗", "frost")
	CKSuiKe.ensure()
	var leader := GameState.get_leader()
	# father / mother
	var father := CKCharacter.new()
	father.id = "fa"; father.name = "父"; father.alive = true; father.gender = "m"
	father.parent_ids = ["gf", "gm"]
	var mother := CKCharacter.new()
	mother.id = "mo"; mother.name = "母"; mother.alive = true; mother.gender = "f"
	mother.parent_ids = ["gfa", "gma"]
	var gf := CKCharacter.new()
	gf.id = "gf"; gf.name = "爷爷"; gf.alive = true; gf.in_roster = true; gf.age = 60; gf.weapon_id = "ash_blade"
	var gm := CKCharacter.new()
	gm.id = "gm"; gm.name = "奶奶"; gm.alive = false  # dead — must not seat
	var gfa := CKCharacter.new()
	gfa.id = "gfa"; gfa.name = "外公"; gfa.alive = true; gfa.age = 58
	# not in characters → 外婆不开
	var kid := CKCharacter.new()
	kid.id = "kid_g"; kid.name = "孙"; kid.alive = true; kid.is_child = true; kid.age = 8
	kid.parent_ids = ["fa", "mo"]; kid.birthday_month = Calendar.month
	kid.apt_max = {"str": 20, "vit": 20, "skl": 20, "agi": 20, "per": 20, "wil": 20}
	kid.stats = {"str": 8, "vit": 8, "skl": 8, "agi": 8, "per": 8, "wil": 8}
	kid.blood_meta = {}
	for c in [father, mother, gf, gm, gfa, kid]:
		GameState.characters[c.id] = c
	var role := CKSuiKe.grandparent_role(kid, gf, GameState.characters)
	if role != "爷爷":
		fails.append("role gf %s" % role)
	if CKSuiKe.grandparent_role(kid, gm, GameState.characters) != "":
		fails.append("dead grandma seated")
	if CKSuiKe.grandparent_role(kid, gfa, GameState.characters) != "外公":
		fails.append("role gfa")
	var seats := CKSuiKe.open_seats(kid)
	if not seats.has("grand"):
		fails.append("grand seat closed %s" % str(seats.keys()))
	else:
		var ids: Array = seats["grand"]
		if "gm" in ids:
			fails.append("dead in seat")
		if "gf" not in ids or "gfa" not in ids:
			fails.append("living grands missing %s" % str(ids))
	# draw rival should be able to pick grand card
	var card := CKSuiKe._draw_grand(kid, gf, RandomNumberGenerator.new())
	if str(card.get("seat", "")) != "grand" and str(card.get("band", "")) != "daily":
		fails.append("grand draw %s" % str(card.get("id", "")))
	if bool(card.get("death_immune", false)):
		fails.append("grand immune")


func _yao_no_immunity(fails: Array) -> void:
	GameState.new_game("灰", "旗", "frost")
	var c := CKCharacter.new()
	c.id = "kid_yao"; c.name = "初啼"; c.alive = true; c.is_child = true; c.age = 2
	c.apt_max = {"str": 20, "vit": 20, "skl": 20, "agi": 20, "per": 20, "wil": 20}
	c.stats = {"str": 8, "vit": 8, "skl": 8, "agi": 8, "per": 8, "wil": 8}
	c.blood_meta = {"purse": 0}
	GameState.characters[c.id] = c
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	var card := CKSuiKe._draw_yao(c, rng)
	if bool(card.get("death_immune", true)):
		fails.append("yao immune flag")
	# force end card resolve
	card = {
		"cid": c.id, "band": "yao", "id": "yao_dawn", "death_immune": false,
		"options": [{"id": "epitaph_a", "label": "碑", "kill": true, "morale": -3, "epitaph": "没哭完"}],
	}
	GameState.house_mods["sui_pending"] = [card]
	var r := CKSuiKe.resolve(c.id, "yao_dawn", "epitaph_a")
	if not bool(r.get("dead", false)) or c.alive:
		fails.append("yao did not kill")
	if str(c.blood_meta.get("stele_cause", "")) != "yao":
		fails.append("stele cause")


func _yan_zhan(fails: Array) -> void:
	var mook := CKCharacter.new()
	mook.blood_mix = {"common_ash": 1.0}
	mook.blood_meta = {}
	if CKYanZhan.hit_bonus(mook) != CKYanZhan.BLOODLESS_HIT:
		fails.append("bloodless %s" % CKYanZhan.hit_bonus(mook))
	var fake := CKCharacter.new()
	fake.blood_mix = {"ashbanner": 1.0}
	fake.blood_meta = {"pretend": {"claimed": "ashbanner", "true": "common_ash"}}
	if CKYanZhan.hit_bonus(fake) != CKYanZhan.FORGED_HIT:
		fails.append("forged %s" % CKYanZhan.hit_bonus(fake))


func _deploy_cap(fails: Array) -> void:
	GameState.new_game("灰", "旗", "frost")
	GameState.buildings["hall"] = 1
	if GameState.max_deploy() != 4:
		fails.append("h1")
	GameState.buildings["hall"] = 2
	if GameState.max_deploy() != 5:
		fails.append("h2")
	GameState.buildings["hall"] = 3
	if GameState.max_deploy() != 6:
		fails.append("h3")
	GameState.buildings["hall"] = 5
	if GameState.max_deploy() != 6:
		fails.append("h5")
