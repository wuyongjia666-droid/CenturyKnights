extends Node
## Fat knife #6: 联姻血脉可读钩子 —
## marry→preg→birth readable on genealogy + hourglass/hub; direct-kin likeness chip;
## BannerHandoff board with flag/name + deploy/roster entry; heirs company-only; litter odds.
## Deepens existing genome/genealogy/handoff; no EmptyHost-only, no paper-doll.

const LINEAGE_SCN := "res://scenes/hub/lineage_view.tscn"
const HOURGLASS_SCN := "res://scenes/hub/hourglass.tscn"
const CASTLE_SCN := "res://scenes/hub/castle_hub.tscn"
const MARKER := "MARRIAGE BLOODLINE READABLE HOOK FAT PASS"
const SHOT_DIR := "user://marriage_bloodline_hook_shots"
const DESK := Vector2i(1600, 900)
const LITTER_ROLLS := 200000

var _shot_n := 0
var _father: CKCharacter
var _mother: CKCharacter
var _child: CKCharacter


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL marriage bloodline readable hook fat: ", err)
		get_tree().quit(1)
		return
	print(MARKER)
	get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	var err := _algebra()
	if err != "":
		return err
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	DisplayServer.window_set_size(DESK)
	await _settle(2)
	err = _rules_company_heir_and_litter()
	if err != "":
		return err
	err = await _chain_marry_preg_birth_readable()
	if err != "":
		return err
	err = await _chain_likeness_and_portraits()
	if err != "":
		return err
	err = await _chain_banner_handoff_board()
	if err != "":
		return err
	return ""


func _algebra() -> String:
	var lin := FileAccess.get_file_as_string("res://autoload/lineage.gd")
	if lin.find("func attach_blood_kin_hook") < 0:
		return "lineage missing attach_blood_kin_hook"
	if lin.find("BloodKinHookPanel") < 0:
		return "lineage missing BloodKinHookPanel"
	if lin.find("HandoffHeirName") < 0:
		return "handoff missing HandoffHeirName"
	if lin.find("\"ToDeploy\"") < 0 and lin.find("ToDeploy") < 0:
		return "handoff missing ToDeploy entry"
	if lin.find("ToRoster") < 0:
		return "handoff missing ToRoster entry"
	var info := FileAccess.get_file_as_string("res://scripts/hub/lineage_info.gd")
	if info.find("BloodLikenessChip") < 0:
		return "lineage_info missing BloodLikenessChip"
	if info.find("func kin_likeness_of") < 0:
		return "lineage_info missing kin_likeness_of"
	var view := FileAccess.get_file_as_string("res://scripts/hub/lineage_view.gd")
	if view.find("BloodKinHookHost") < 0:
		return "lineage_view missing BloodKinHookHost"
	var castle := FileAccess.get_file_as_string("res://scripts/hub/castle_hub.gd")
	if castle.find("BloodKinHookHost") < 0:
		return "castle_hub missing BloodKinHookHost"
	var empty_only := FileAccess.get_file_as_string("res://scripts/hub/marriage.gd")
	## Ban: this fat knife must not be EmptyHost-only marriage empty-state polish.
	if empty_only.find("BloodKinHook") >= 0:
		return "marriage.gd must not own BloodKinHook (ban EmptyHost-only path)"
	return ""


func _settle(n: int = 6) -> void:
	for _i in n:
		await get_tree().process_frame


func _shot(tag: String) -> void:
	_shot_n += 1
	var path := "%s/%02d_%s.png" % [SHOT_DIR, _shot_n, tag]
	var img: Image = get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(ProjectSettings.globalize_path(path))
		print("SHOT ", path)


func _boot(tag: String) -> void:
	GameState.new_game(tag, "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.house_mods.erase("month_echo")
	GameState.house_mods.erase("banner_handoff")
	GameState.house_mods["dyn_amb"] = "skip_offer"
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = maxi(int(GameState.silver), 400)
	GameState.add_rep("ashland", 80)


func _rules_company_heir_and_litter() -> String:
	_boot("承旗规则")
	var lead: CKCharacter = GameState.get_leader()
	lead.age = 40
	## External adult (not in roster, not descendant) must never win pick_roster_heir.
	var outsider := CKCharacter.new()
	outsider.id = "out_court_1"
	outsider.name = "外廷客"
	outsider.age = 30
	outsider.gender = "m"
	outsider.alive = true
	outsider.in_roster = false
	outsider.rank = "baron"
	outsider.is_leader = false
	outsider.stats = {"str": 18, "vit": 18, "skl": 18, "agi": 18, "per": 18, "wil": 18}
	GameState.characters[outsider.id] = outsider
	var roster_heir := Lineage.pick_roster_heir(lead)
	if roster_heir != null and str(roster_heir.id) == outsider.id:
		return "pick_roster_heir picked external non-roster"
	if roster_heir != null and not bool(roster_heir.in_roster):
		return "pick_roster_heir returned non-roster %s" % roster_heir.id
	## Multi-birth: twins ~1/85, no fertility bonus on litter.
	var rng := RandomNumberGenerator.new()
	rng.seed = 60606
	var n := {1: 0, 2: 0, 3: 0, 4: 0}
	for _i in LITTER_ROLLS:
		var k := CKFamilyState.roll_litter(rng)
		n[k] = int(n.get(k, 0)) + 1
	var twins := float(n[2]) / float(LITTER_ROLLS)
	if absf(twins - 1.0 / 85.0) > 0.0015:
		return "twin rate %.4f drifted from 1/85" % twins
	print("rules company-heir+litter ok twins=%.4f" % twins)
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
	wife.pregnant_months = -1
	wife.blood_mix = {"common_ash": 1.0}
	wife.blood_meta = {"children_born": 0}
	wife.stats = {"str": 5, "vit": 8, "skl": 6, "agi": 6, "per": 5, "wil": 8}
	GameState.characters[hus.id] = hus
	GameState.characters[wife.id] = wife
	return [hus, wife]


func _chain_marry_preg_birth_readable() -> String:
	var err := _seed_paced_pregnancy()
	if err != "":
		return err
	err = await _readback_kin(["pregnancy"], "preg")
	if err != "":
		return err
	err = _deliver_birth()
	if err != "":
		return err
	err = await _readback_kin(["birth"], "birth")
	if err != "":
		return err
	print("chain marry→preg→birth readable on genealogy+hub+hourglass")
	return ""


func _seed_paced_pregnancy() -> String:
	_boot("联姻可读")
	var couple := _couple("hook_mp", 24)
	_father = couple[0]
	_mother = couple[1]
	var ok := false
	var wed: Dictionary = {}
	for seed in range(1, 100):
		_mother.pregnant_months = -1
		_mother.blood_meta.erase("gestation_term")
		_mother.blood_meta.erase("litter")
		_mother.spouse_id = ""
		_father.spouse_id = ""
		GameState.house_mods.erase("month_echo")
		GameState.rng.seed = seed
		GameState.silver = maxi(int(GameState.silver), 200)
		CKFamilyState.note_company_bond(_father, _mother, CKFamilyState.INTERNAL_BOND_NEED)
		wed = Lineage.marry(_father, _mother, 40, null, true)
		if bool(wed.get("ok", false)) and _mother.pregnant_months >= 0:
			ok = true
			break
	if not ok:
		return "paced marry never conceived: %s" % str(wed.get("msg", ""))
	if not Lineage.is_blood_kin_pending():
		return "blood kin hook not pending after pregnancy"
	return ""


func _deliver_birth() -> String:
	GameState.house_mods.erase("month_echo")
	_mother.pregnant_months = 0
	_mother.blood_meta["litter"] = 1
	var before := _mother.children_ids.size()
	Calendar.advance(1)
	if _mother.children_ids.size() <= before:
		return "no birth after deliver"
	var kid_id := str(_mother.children_ids[_mother.children_ids.size() - 1])
	_child = GameState.characters.get(kid_id)
	if _child == null:
		return "newborn missing"
	var snap := CKEconomyState.month_echo_snapshot()
	if str(snap.get("birth", "")) == "":
		return "birth echo empty"
	if not Lineage.is_blood_kin_pending():
		return "blood kin hook not pending after birth"
	return ""


func _readback_kin(kinds: Array, tag: String) -> String:
	var err := await _assert_hook_on(LINEAGE_SCN, "genealogy_%s" % tag, kinds)
	if err != "":
		return err
	err = await _assert_hook_on(CASTLE_SCN, "hub_%s" % tag, kinds)
	if err != "":
		return err
	return await _assert_hourglass_echo(kinds)


func _assert_hook_on(path: String, tag: String, kinds: Array) -> String:
	var page: Control = (load(path) as PackedScene).instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1600, 900)
	get_tree().root.add_child(page)
	await _settle(12)
	var panel := page.find_child("BloodKinHookPanel", true, false)
	if panel == null:
		page.queue_free()
		return "%s missing BloodKinHookPanel" % tag
	for k in kinds:
		var line := page.find_child("BloodKinLine_%s" % str(k), true, false)
		if line == null:
			page.queue_free()
			return "%s missing BloodKinLine_%s" % [tag, str(k)]
	_shot("hook_%s" % tag)
	page.queue_free()
	await _settle(2)
	return ""


func _assert_hourglass_echo(kinds: Array) -> String:
	var page: Control = (load(HOURGLASS_SCN) as PackedScene).instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1600, 900)
	get_tree().root.add_child(page)
	await _settle(12)
	for k in kinds:
		var line := page.find_child("EchoLine_%s" % str(k), true, false)
		if line == null:
			page.queue_free()
			return "hourglass missing EchoLine_%s" % str(k)
	_shot("hourglass_%s" % str(kinds[0]))
	page.queue_free()
	await _settle(2)
	return ""


func _chain_likeness_and_portraits() -> String:
	if _child == null or _father == null or _mother == null:
		return "likeness chain missing family"
	_father.ensure_genome()
	_mother.ensure_genome()
	_child.ensure_genome()
	var report: Dictionary = CKLineageInfo.kin_likeness_of(_child)
	if report.is_empty():
		return "kin_likeness_of empty for newborn"
	var frac := float(report.get("fraction", 0.0))
	if frac < 0.34:
		return "newborn likeness fraction %.3f < 0.34" % frac
	var shared: Array = report.get("shared", [])
	if shared.is_empty():
		return "newborn shared heritable empty"
	## Select child on genealogy wall → BloodLikenessChip visible.
	var page: Control = (load(LINEAGE_SCN) as PackedScene).instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1600, 900)
	get_tree().root.add_child(page)
	await _settle(14)
	## Prefer selecting the child tile if the overview exposes a click path; else force info render.
	var info_host := page.find_child("InfoHost", true, false) as Control
	if info_host != null:
		CKLineageInfo.render(info_host, _child, Locale.t("gen2_34"), Callable(), Locale.t("gen2_29"), Callable())
		await _settle(4)
	var chip := page.find_child("BloodLikenessChip", true, false)
	if chip == null:
		page.queue_free()
		return "BloodLikenessChip missing on genealogy info"
	## Portrait plates resolve for parent + child (seed mechanism).
	var _pt_c: Texture2D = UnitArt.portrait(_child, 128)
	var _pt_f: Texture2D = UnitArt.portrait(_father, 128)
	var _pt_m: Texture2D = UnitArt.portrait(_mother, 128)
	if _pt_c == null or _pt_f == null or _pt_m == null:
		page.queue_free()
		return "portrait null for kin"
	_shot("genealogy_likeness")
	page.queue_free()
	await _settle(2)
	print("likeness ok frac=%.3f shared=%d" % [frac, shared.size()])
	return ""


func _chain_banner_handoff_board() -> String:
	var err := _seed_banner_handoff()
	if err != "":
		return err
	var page: Control = (load(CASTLE_SCN) as PackedScene).instantiate()
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1600, 900)
	get_tree().root.add_child(page)
	await _settle(14)
	err = _assert_handoff_board(page)
	if err != "":
		page.queue_free()
		return err
	err = _assert_handoff_entries(page)
	if err != "":
		page.queue_free()
		return err
	_shot("banner_handoff_board")
	err = await _assert_handoff_dismiss(page)
	if err != "":
		return err
	print("banner handoff board ok name+crest+ToDeploy/ToRoster wired")
	return ""


func _seed_banner_handoff() -> String:
	_boot("承旗板")
	var lead: CKCharacter = GameState.get_leader()
	lead.age = 50
	var heir := CKCharacter.new()
	heir.id = "hook_heir"
	heir.name = "承旗嗣甲"
	heir.age = 20
	heir.gender = "m"
	heir.alive = true
	heir.in_roster = true
	heir.is_child = false
	heir.rank = "knight"
	heir.family_id = str(lead.family_id)
	heir.parent_ids = [str(lead.id)]
	heir.stats = {"str": 10, "vit": 10, "skl": 10, "agi": 10, "per": 10, "wil": 10}
	GameState.characters[heir.id] = heir
	GameState.lineage_path[heir.id] = "martial"
	if not heir.id in lead.children_ids:
		lead.children_ids.append(heir.id)
	var rr: Dictionary = Lineage.transfer_banner("abdicate")
	if not bool(rr.get("ok", false)):
		return "transfer_banner failed: %s" % str(rr.get("msg", ""))
	if not Lineage.is_banner_handoff_pending():
		return "banner_handoff not pending"
	return ""


func _assert_handoff_board(page: Control) -> String:
	if page.find_child("BannerHandoffPanel", true, false) == null:
		return "castle BannerHandoffPanel missing"
	if page.find_child("BannerHandoffCrestStrip", true, false) == null:
		return "castle BannerHandoffCrestStrip missing"
	var heir_lab := page.find_child("HandoffHeirName", true, false)
	if heir_lab == null:
		return "HandoffHeirName missing"
	var heir_tx := ""
	if heir_lab is Label:
		heir_tx = str((heir_lab as Label).text)
	elif heir_lab.get("text") != null:
		heir_tx = str(heir_lab.get("text"))
	if heir_tx.find("承旗嗣甲") < 0:
		return "HandoffHeirName missing heir name: %s" % heir_tx
	return ""


func _assert_handoff_entries(page: Control) -> String:
	var to_d := page.find_child("ToDeploy", true, false) as BaseButton
	if to_d == null:
		return "ToDeploy missing on handoff board"
	var to_r := page.find_child("ToRoster", true, false) as BaseButton
	if to_r == null:
		return "ToRoster missing on handoff board"
	if to_d.get_signal_connection_list("pressed").is_empty():
		return "ToDeploy pressed not wired"
	if to_r.get_signal_connection_list("pressed").is_empty():
		return "ToRoster pressed not wired"
	var src := FileAccess.get_file_as_string("res://autoload/lineage.gd")
	if src.find("res://scenes/hub/deploy.tscn") < 0:
		return "ToDeploy missing deploy.tscn target"
	if src.find("res://scenes/hub/roster.tscn") < 0:
		return "ToRoster missing roster.tscn target"
	return ""


func _assert_handoff_dismiss(page: Control) -> String:
	var dismiss := page.find_child("DismissHandoff", true, false) as BaseButton
	if dismiss == null:
		page.queue_free()
		return "DismissHandoff missing"
	dismiss.emit_signal("pressed")
	await _settle(4)
	if Lineage.is_banner_handoff_pending():
		page.queue_free()
		return "banner_handoff not cleared on dismiss"
	page.queue_free()
	await _settle(2)
	return ""
