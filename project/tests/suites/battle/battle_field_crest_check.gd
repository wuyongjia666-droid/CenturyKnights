extends Node
## Fat heraldry E2E: battle unit card, forecast columns, post-action report.
## Player plates are 族徽|旗徽. Enemy plates are 敌徽, never company or family arms.
## Desktop + mobile. Fails when CardArms / Forecast* / ReportCrestStrip are missing.

const CARD := preload("res://scripts/ui/unit_card.gd")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run_desktop()
	await _run_mobile()
	if _fails.is_empty():
		print("BATTLE FIELD CREST PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL battle field crest: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _settle(n: int = 4) -> void:
	for i in n:
		await get_tree().process_frame

func _boot() -> void:
	GameState.new_game("战牌", "霜旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	World.events_enabled = false
	World.encounter = {}
	if GameState.has_meta("battle_foe_nation"):
		GameState.remove_meta("battle_foe_nation")

func _card(c, team: String, foe: String) -> Control:
	var card: Control = CARD.new(280.0)
	card.set_meta("foe_nation", foe)
	add_child(card)
	card.set_unit(c, team)
	return card

func _assert_card(where: String) -> void:
	var lead: CKCharacter = GameState.get_leader()
	var ban := CKHeraldry.core_key(CKHeraldryChrome.company_spec())
	var fam := CKHeraldry.core_key(GameState.arms_for_character(lead))
	var foe_core := CKHeraldry.core_key(CKHeraldryChrome.nation_spec("ashbanner"))
	var ally := _card(lead, "player", "")
	var aa := ally.find_child("CardArms", true, false)
	_ok(aa != null and str(aa.get_meta("arms_kind", "")) == "gen2_06", "%s player CardArms 族徽" % where)
	if aa != null:
		_ok(str(aa.get_meta("arms_core", "")) == fam, "%s player family core" % where)
		_ok(str(aa.get_meta("arms_core", "")) != ban, "%s player 族徽!=团徽" % where)
		_ok(aa.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s player arms ignore mouse" % where)
	var enemy := CharacterFactory.make_enemy("bandit", RandomNumberGenerator.new())
	var blank := _card(enemy, "enemy", "")
	_ok(blank.find_child("CardArms", true, false) == null, "%s enemy without nation has no player arms" % where)
	var foe := _card(enemy, "enemy", "ashbanner")
	var ea := foe.find_child("CardArms", true, false)
	_ok(ea != null and str(ea.get_meta("arms_kind", "")) == "lb_rv_arms", "%s enemy CardArms 敌徽" % where)
	if ea != null:
		_ok(str(ea.get_meta("arms_core", "")) == foe_core, "%s enemy nation core" % where)
		_ok(str(ea.get_meta("arms_core", "")) != fam, "%s enemy is not family arms" % where)
		_ok(str(ea.get_meta("arms_core", "")) != ban, "%s enemy is not 团徽" % where)
	ally.set_unit(null, "player")
	_ok(ally.find_child("CardArms", true, false) == null, "%s cleared card drops arms" % where)
	ally.queue_free()
	blank.queue_free()
	foe.queue_free()

func _forecast(where: String, foe_nation: String) -> void:
	GameState.set_meta("battle_foe_nation", foe_nation)
	var lead: CKCharacter = GameState.get_leader()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var enemy := CharacterFactory.make_enemy("bandit", rng)
	enemy.recalc_hp()
	enemy.hp = enemy.max_hp
	var host := _Host.new()
	host.units = [
		{"char": lead, "pos": Vector2i(0, 0), "team": "player", "done": false},
		{"char": enemy, "pos": Vector2i(1, 0), "team": "enemy", "done": false},
	]
	host.terrain = [["plain", "plain"], ["plain", "plain"]]
	add_child(host)
	ForecastPanel.attach(host)
	ForecastPanel.refresh(host)
	var panel := host.get_node_or_null("ForecastPanel")
	_ok(panel != null and panel.visible, "%s ForecastPanel visible" % where)
	if panel == null:
		host.queue_free()
		return
	var ours := panel.find_child("ForecastOursArms", true, false)
	var foe := panel.find_child("ForecastFoeArms", true, false)
	var fam := CKHeraldry.core_key(GameState.arms_for_character(lead))
	var ban := CKHeraldry.core_key(CKHeraldryChrome.company_spec())
	_ok(ours != null and str(ours.get_meta("arms_kind", "")) == "gen2_06", "%s ForecastOursArms 族徽" % where)
	if ours != null:
		_ok(str(ours.get_meta("arms_core", "")) == fam, "%s forecast ours family core" % where)
		_ok(str(ours.get_meta("arms_core", "")) != ban, "%s forecast ours != 团徽" % where)
	if foe_nation == "":
		_ok(foe == null, "%s no ForecastFoeArms without nation" % where)
	else:
		var want := CKHeraldry.core_key(CKHeraldryChrome.nation_spec(foe_nation))
		_ok(foe != null and str(foe.get_meta("arms_kind", "")) == "lb_rv_arms", "%s ForecastFoeArms 敌徽" % where)
		if foe != null:
			_ok(str(foe.get_meta("arms_core", "")) == want, "%s forecast foe core" % where)
			_ok(str(foe.get_meta("arms_core", "")) != fam, "%s forecast foe != family" % where)
			_ok(foe.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s forecast foe ignores mouse" % where)
	host.queue_free()

func _report(where: String) -> void:
	GameState.set_meta("battle_foe_nation", "ashbanner")
	var lead: CKCharacter = GameState.get_leader()
	var host := _ReportHost.new()
	host.units = [{"char": lead, "pos": Vector2i(0, 0), "team": "player", "done": false}]
	add_child(host)
	BattleReport.present(host, true, 12, 0, {lead.id: [lead.exp, false]})
	var layer := host.get_node_or_null("ResultReport")
	_ok(layer != null, "%s ResultReport" % where)
	if layer == null:
		host.queue_free()
		return
	var strip := layer.find_child("ReportCrestStrip", true, false)
	_ok(strip != null, "%s ReportCrestStrip" % where)
	if strip != null:
		var ca := strip.find_child("CastleArms", true, false)
		var ea := strip.find_child("FoeArms", true, false)
		var ban := CKHeraldry.core_key(CKHeraldryChrome.company_spec())
		var foe := CKHeraldry.core_key(CKHeraldryChrome.nation_spec("ashbanner"))
		_ok(ca != null and str(ca.get_meta("arms_kind", "")) == "gen2_36", "%s report 团徽" % where)
		_ok(ea != null and str(ea.get_meta("arms_kind", "")) == "lb_rv_arms", "%s report 敌徽" % where)
		if ca != null and ea != null:
			_ok(str(ca.get_meta("arms_core", "")) == ban, "%s report company core" % where)
			_ok(str(ea.get_meta("arms_core", "")) == foe, "%s report foe core" % where)
			_ok(str(ea.get_meta("arms_core", "")) != ban, "%s report 敌徽!=团徽" % where)
		_ok(strip.get_child_count() == 3, "%s report two shields + cloth banner" % where)
		var rbn := strip.find_child("ReportBanner", true, false)
		_ok(rbn != null and str(rbn.get_meta("field_route", "")) == "report_banner", "%s report_banner" % where)
		_ok(strip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s report strip ignores mouse" % where)
	var rows: Array = []
	_collect(layer, "ReportRowArms", rows)
	_ok(rows.size() >= 1, "%s ReportRowArms" % where)
	if not rows.is_empty():
		var ra: Node = rows[0]
		var fam := CKHeraldry.core_key(GameState.arms_for_character(lead))
		_ok(str(ra.get_meta("arms_kind", "")) == "gen2_06", "%s row 族徽" % where)
		_ok(str(ra.get_meta("arms_core", "")) == fam, "%s row family core" % where)
	host.queue_free()

func _collect(n: Node, node_name: String, out: Array) -> void:
	if n.name == node_name:
		out.append(n)
	for c in n.get_children():
		_collect(c, node_name, out)

func _run_desktop() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	_boot()
	_assert_card("desk")
	await _settle(2)
	_forecast("desk", "ashbanner")
	await _settle(2)
	_forecast("desk-solo", "")
	await _settle(2)
	_report("desk")
	await _settle(2)

func _run_mobile() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE flips DeviceProfile")
	_boot()
	_assert_card("mob")
	await _settle(2)
	_forecast("mob", "frostvale")
	await _settle(2)
	_report("mob")
	await _settle(2)
	OS.set_environment("CK_FORCE_MOBILE", "")
	if GameState.has_meta("battle_foe_nation"):
		GameState.remove_meta("battle_foe_nation")

class _Host:
	extends Node
	var selected := 0
	var attack_mode := true
	var preview_attack_ui := -1
	var units: Array = []
	var terrain: Array = []
	var map_id := "quest_bandit"
	var _hover_cell := Vector2i(1, 0)

	func _unit_at(_cell: Vector2i) -> int:
		return 1

	func _combat_extras(_a: int, _b: int) -> Dictionary:
		return {}

class _ReportHost:
	extends Node
	var map_name := "Drill"
	var _round_no := 2
	var _world_enc := true
	var units: Array = []
