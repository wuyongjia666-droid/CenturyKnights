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
	_auto_personality(fails)
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


func _auto_personality(fails: Array) -> void:
	## Bold scarred kid prefers riskier side; careful scholar prefers care; seed stable.
	GameState.new_game("灰", "旗", "frost")
	CKSuiKe.ensure()
	GameState.house_mods["sui_inbox"] = []
	GameState.house_mods["sui_pending"] = []
	var bold := CKCharacter.new()
	bold.id = "kid_bold"
	bold.name = "莽"
	bold.alive = true
	bold.is_child = true
	bold.age = 8
	bold.birthday_month = Calendar.month
	bold.traits = ["brave", "scarred"]
	bold.apt_max = {"str": 20, "vit": 20, "skl": 20, "agi": 20, "per": 20, "wil": 20}
	bold.stats = {"str": 14, "vit": 12, "skl": 6, "agi": 12, "per": 5, "wil": 5}
	bold.blood_meta = {}
	bold.parent_ids = [GameState.get_leader().id]
	var care := CKCharacter.new()
	care.id = "kid_care"
	care.name = "稳"
	care.alive = true
	care.is_child = true
	care.age = 8
	care.birthday_month = Calendar.month
	care.traits = ["scholar", "keen_eye"]
	care.apt_max = {"str": 20, "vit": 20, "skl": 20, "agi": 20, "per": 20, "wil": 20}
	care.stats = {"str": 5, "vit": 6, "skl": 12, "agi": 5, "per": 14, "wil": 14}
	care.blood_meta = {}
	care.parent_ids = [GameState.get_leader().id]
	GameState.characters[bold.id] = bold
	GameState.characters[care.id] = care
	GameState.lineage_path[bold.id] = "martial"
	GameState.lineage_path[care.id] = "scholar"
	# Synthetic catalog card: left = care/watch, right = scar risk
	var card_l := {
		"cid": bold.id, "band": "ill", "id": "ill_auto_test",
		"title": "试咳", "body": "试。", "speaker": "旁白",
		"options": [
			{"id": "left", "label": "灶边养着", "trait": "", "mark": "watch", "stat": "per", "gain": 1, "care": true},
			{"id": "right", "label": "硬扛", "trait": "scarred", "mark": "", "stat": "str", "gain": 1},
		],
	}
	# Bold should pick right (scar already present — trait add may no-op, still ok)
	var pick_b := CKSuiKe.pick_option_id(bold, card_l, 3)
	if pick_b != "right":
		fails.append("bold pick %s bias=%s" % [pick_b, CKSuiKe.personality_bias(bold)])
	var pick_b2 := CKSuiKe.pick_option_id(bold, card_l, 3)
	if pick_b2 != pick_b:
		fails.append("bold pick unstable")
	var card_c := card_l.duplicate(true)
	card_c["cid"] = care.id
	var pick_c := CKSuiKe.pick_option_id(care, card_c, 3)
	if pick_c != "left":
		fails.append("care pick %s bias=%s" % [pick_c, CKSuiKe.personality_bias(care)])
	# Put a roster adult same node so care:true can resolve
	var leader := GameState.get_leader()
	leader.in_roster = true
	leader.age = 30
	# Fire bold card → inbox, no pending
	GameState.house_mods["sui_inbox"] = []
	GameState.house_mods["sui_pending"] = []
	var row := CKSuiKe.fire_and_resolve_card(card_l, 3)
	if row.is_empty():
		fails.append("fire empty bold")
	elif str(row.get("side", "")) != "right" and str(row.get("option_id", "")) != "right":
		fails.append("fire side %s" % str(row.get("side", "")))
	if not (GameState.house_mods.get("sui_pending", []) as Array).is_empty():
		fails.append("pending after fire")
	if CKSuiKe.inbox().is_empty():
		fails.append("inbox empty after fire")
	# Ack clears
	CKSuiKe.ack(bold.id, "ill_auto_test")
	if not CKSuiKe.inbox().is_empty():
		fails.append("inbox after ack")
	# Legacy pending drain
	var legacy := {
		"cid": care.id, "band": "ill", "id": "ill_legacy",
		"title": "旧卡", "body": "旧。",
		"options": [
			{"id": "left", "label": "养", "mark": "watch", "stat": "per", "gain": 1, "care": true},
			{"id": "right", "label": "扛", "trait": "scarred"},
		],
	}
	GameState.house_mods["sui_pending"] = [legacy]
	GameState.house_mods["sui_inbox"] = []
	CKSuiKe._drain_legacy_pending()
	if not (GameState.house_mods.get("sui_pending", []) as Array).is_empty():
		fails.append("legacy pending stuck")
	if CKSuiKe.inbox().is_empty():
		fails.append("legacy no inbox")
	# Yao still kills when auto-picked
	var yao_kid := CKCharacter.new()
	yao_kid.id = "kid_yao2"
	yao_kid.name = "夭"
	yao_kid.alive = true
	yao_kid.is_child = true
	yao_kid.age = 2
	yao_kid.apt_max = {"str": 20, "vit": 20, "skl": 20, "agi": 20, "per": 20, "wil": 20}
	yao_kid.stats = {"str": 8, "vit": 8, "skl": 8, "agi": 8, "per": 8, "wil": 8}
	yao_kid.blood_meta = {"purse": 0}
	GameState.characters[yao_kid.id] = yao_kid
	var yao_card := {
		"cid": yao_kid.id, "band": "yao", "id": "yao_auto",
		"title": "没到天亮", "body": "没了。",
		"options": [
			{"id": "epitaph_a", "label": "碑甲", "kill": true, "morale": -3, "epitaph": "甲"},
			{"id": "epitaph_b", "label": "碑乙", "kill": true, "morale": -2, "epitaph": "乙", "halt_march": true},
		],
	}
	GameState.house_mods["sui_pending"] = []
	GameState.house_mods["sui_inbox"] = []
	var yrow := CKSuiKe.fire_and_resolve_card(yao_card, 1)
	if not bool(yrow.get("dead", false)) or yao_kid.alive:
		fails.append("yao auto did not kill")

