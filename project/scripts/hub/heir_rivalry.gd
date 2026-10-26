extends Control
## Heir trials (line B, audit #30). Two heir cards face each other; the moves are cards with
## cost and effect. No heirs / one heir each get a real explanation with the way forward.
## A settled quarrel stays settled for the year (supporting an heir used to farm skill points).

const LifeEvents := preload("res://scripts/characters/life_events.gd")

var _a: CKCharacter
var _b: CKCharacter
var _life: Dictionary = {}
var _duel: HBoxContainer
var _body: Label
var _moves: HBoxContainer
var _msg: Label

func _ready() -> void:
	UIKit.make_themed_bg(self, "heir")
	CKPageKit.shell(self, Locale.t("lb_heir_ctx"), "HEIR TRIALS", Locale.t("lb_heir_title"), Locale.t("lb_heir_desc"), "none")
	var board := CKPageKit.card(self, Rect2(42, CKPageKit.TOP + 8, 1196, 512), "HeirBoard")
	_duel = HBoxContainer.new()
	_duel.name = "Duel"
	_duel.position = Vector2(20, 18)
	_duel.add_theme_constant_override("separation", 16)
	board.add_child(_duel)
	_body = CKPageKit.text("", UIKit.TEXT, 15, 1150)
	_body.name = "HeirText"
	_body.position = Vector2(20, 156)
	_body.size = Vector2(1150, 80)
	board.add_child(_body)
	_moves = HBoxContainer.new()
	_moves.name = "Moves"
	_moves.position = Vector2(20, 246)
	_moves.add_theme_constant_override("separation", 12)
	board.add_child(_moves)
	_msg = CKPageKit.feedback(self)
	_pick()
	if GameState.flag("ch_heir_clash_done"):
		CKPageKit.say(_msg, Locale.t("lb_heir_back_from_battle"), true)
		GameState.set_flag("ch_heir_clash_done", false)
	_place_duel_crests()
	_show()
	CKPageKit.footer(self, [["ESC", Locale.t("btn_back")]], "HEIR TRIALS · FROST")
	UIFX.page_enter(self)


func _place_duel_crests() -> void:
	## 团徽 + two heir shields on HeirBoard. EmptyHost path untouched — strip still shows 团徽.
	var mob := DeviceProfile.is_mobile()
	CKHeraldryField.place_company_header(self, Vector2(1180, 8) if not mob else Vector2(1180, 4), Vector2(44, 52) if not mob else Vector2(40, 48))
	var board := get_node_or_null("HeirBoard") as Control
	var host: Node = board if board != null else self
	var at := Vector2(980, 12) if board != null else Vector2(980, 12)
	if mob:
		at = Vector2(900, 8)
	CKHeraldryField.place_duel_crest_strip(host, _a, _b, at, Vector2(36, 44) if not mob else Vector2(32, 38))

func _path_zh(c: CKCharacter) -> String:
	var p := str(GameState.lineage_path.get(c.id, "")) if c else ""
	return Locale.t("lb_path_" + p) if p != "" else Locale.t("lb_path_none")

func _pick() -> void:
	var heirs: Array = GameState.characters.values().filter(func(ch): return ch.alive and (ch.is_child or GameState.lineage_path.has(ch.id)) and ch.age >= 8)
	heirs.sort_custom(func(x, y): return x.age > y.age)
	_a = heirs[0] if heirs.size() > 0 else null
	_b = heirs[1] if heirs.size() > 1 else null

func _settled() -> bool:
	return int(GameState.house_mods.get("heir_rivalry_year", 0)) == Calendar.year

func _heir_card(c: CKCharacter, tag: String) -> Control:
	var r := CKPageKit.row(UIKit.ACCENT, 120)
	var p: PanelContainer = r[0]
	p.custom_minimum_size = Vector2(500, 124)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	(r[1] as VBoxContainer).add_child(h)
	var pr := UIKit.make_portrait_rect(c, 96)
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(pr)
	var v := VBoxContainer.new()
	h.add_child(v)
	v.add_child(UIKit.tag_chip(tag, UIKit.ACCENT))
	v.add_child(UIKit.title_label(c.name, 20))
	v.add_child(CKPageKit.text(Locale.t("lb_heir_meta", [c.age, _path_zh(c)]), UIKit.TEXT_DIM, 13, 340))
	return p

func _show() -> void:
	_place_duel_crests()
	CKPageKit.clear(_duel)
	CKPageKit.clear(_moves)
	if not _life.is_empty():
		_show_life()
		return
	if _a == null:
		## Audit #30 empty: why/how + named forward CTAs (marriage / tavern), not a bare dismiss.
		_body.text = ""
		var host := VBoxContainer.new()
		host.name = "EmptyHost"
		host.add_theme_constant_override("separation", 12)
		host.add_child(CKPageKit.empty(Locale.t("lb_heir_none"), Locale.t("lb_heir_none_why"), Locale.t("lb_heir_none_how"), 1100))
		var acts := HBoxContainer.new()
		acts.name = "EmptyActions"
		acts.add_theme_constant_override("separation", 12)
		var to_m := CKPageKit.button(Locale.t("lb_heir_to_marriage"), true, 260)
		to_m.name = "ToMarriage"
		to_m.pressed.connect(func(): CKNav.go("res://scenes/hub/marriage.tscn"))
		acts.add_child(to_m)
		UIFX.wire_button(to_m)
		var to_t := CKPageKit.button(Locale.t("lb_heir_to_tavern"), false, 260)
		to_t.name = "ToTavern"
		to_t.pressed.connect(func(): CKNav.go("res://scenes/hub/tavern.tscn"))
		acts.add_child(to_t)
		UIFX.wire_button(to_t)
		host.add_child(acts)
		_duel.add_child(host)
		return
	_duel.add_child(_heir_card(_a, Locale.t("lb_heir_elder")))
	if _b == null:
		_body.text = Locale.t("lb_heir_one", [_a.name])
		_move_btn(Locale.t("lb_heir_to_rite"), true, func(): CKNav.go("res://scenes/hub/lineage_rite.tscn"), "ToRite")
		return
	var vs := UIKit.title_label(Locale.t("lb_heir_vs"), 28, UIKit.ACCENT)
	vs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_duel.add_child(vs)
	_duel.add_child(_heir_card(_b, Locale.t("lb_heir_younger")))
	if _settled():
		_body.text = Locale.t("lb_heir_settled", [str(GameState.house_mods.get("heir_rivalry_zh", "")), Calendar.year + 1])
		## Clear next step: succession clash with Shuoying (pair page to this trial).
		_move_btn(Locale.t("lb_heir_to_inheritance"), true, func(): CKNav.go("res://scenes/hub/inheritance.tscn"), "ToInheritance")
		return
	_body.text = Locale.t("lb_heir_quarrel", [_a.name, _b.name])
	var s := GameState.silver
	_move("lb_heir_m_mediate", "15", func(): _mediate(), Locale.t("lb_short_silver", [15 - s]) if s < 15 else "")
	_move("lb_heir_m_a", "", func(): _support(_a, _b), "", [_a.name])
	_move("lb_heir_m_b", "", func(): _support(_b, _a), "", [_b.name])
	_move("lb_heir_m_duel", "", func(): _battle(), "")
	var card := _succession_card()
	if not card.is_empty():
		_move_btn(Locale.t("life_succession_btn"), false, func(): _life = card; _show())

func _move(key: String, cost: String, cb: Callable, why: String, args: Array = []) -> void:
	var r := CKPageKit.row(UIKit.ACCENT, 250)
	var p: PanelContainer = r[0]
	p.custom_minimum_size = Vector2(280, 250)
	p.name = "Move_" + key.trim_prefix("lb_heir_m_")
	var v: VBoxContainer = r[1]
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	top.add_child(UIKit.title_label(Locale.t(key, args), 16))
	top.add_child(UIKit.tag_chip(Locale.t("lb_rv_cost", [cost]) if cost != "" else Locale.t("lb_rv_free"), UIKit.ACCENT if cost != "" else UIKit.OK))
	v.add_child(CKPageKit.text(Locale.t(key + "_fx"), UIKit.TEXT_DIM, 13, 250))
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	var b := CKPageKit.button(Locale.t("lb_rv_do"), why == "", 250)
	CKPageKit.lock(b, why)
	b.pressed.connect(cb)
	v.add_child(b)
	_moves.add_child(p)
	UIFX.wire_tree(p)

func _move_btn(t: String, primary: bool, cb: Callable, node_name: String = "") -> void:
	var b := CKPageKit.button(t, primary, 260)
	if node_name != "":
		b.name = node_name
	b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(cb)
	_moves.add_child(b)
	UIFX.wire_button(b)

func _succession_card() -> Dictionary:
	for who in [_a, _b]:
		if who == null:
			continue
		var card: Dictionary = LifeEvents.pending_band(who.id, "succession")
		if not card.is_empty():
			card["cid"] = who.id
			return card
	return {}

func _show_life() -> void:
	## Auto-resolved life card: title / body / outcome only. No A/B buttons.
	var title := LifeEvents.card_title(_life)
	var body := LifeEvents.card_body(_life)
	var outcome := str(_life.get("outcome", ""))
	if outcome == "":
		var side := str(_life.get("side", ""))
		if side != "":
			outcome = LifeEvents.choice_label({
				"act": str(_life.get(side, {}).get("act", "")),
				"hint": str(_life.get(side, {}).get("hint", "")),
			})
	var head := ("%s\n\n%s" % [title, body]) if title != "" else body
	if outcome != "":
		_body.text = "%s\n\n%s" % [head, Locale.t("life_outcome_prefix", [outcome])]
	else:
		_body.text = head
	var cid := str(_life.get("cid", ""))
	var eid := str(_life.get("id", ""))
	_move_btn(Locale.t("life_ack"), true, func(): _ack_life(cid, eid))
	_move_btn(Locale.t("btn_back"), false, func(): _life = {}; _show())

func _ack_life(cid: String, event_id: String) -> void:
	LifeEvents.ack(cid, event_id)
	_life = {}
	CKPageKit.say(_msg, Locale.t("life_inbox_ok"), true)
	_show()

func _settle(zh: String) -> void:
	GameState.house_mods["heir_rivalry_year"] = Calendar.year
	GameState.house_mods["heir_rivalry_zh"] = zh
	GameState.save_game()

func _mediate() -> void:
	GameState.silver -= 15
	GameState.add_lineage_event(Locale.t("lb_heir_log_mediate", [_a.name, _b.name]))
	GameState.add_rep("ashland", 1)
	Sfx.lineage_chime()
	_settle(Locale.t("lb_heir_zh_mediate"))
	CKPageKit.say(_msg, Locale.t("lb_heir_mediate_ok"), true)
	_show()

func _support(win: CKCharacter, lose: CKCharacter) -> void:
	GameState.add_lineage_event(Locale.t("lb_heir_log_support", [win.name, lose.name]))
	GameState.add_skill_point(1)
	var path := str(GameState.lineage_path.get(win.id, ""))
	var n := 0
	if path != "":
		n = GameState.grant_path_skills(win, path).size()
	Sfx.fanfare()
	_settle(Locale.t("lb_heir_zh_support", [win.name]))
	CKPageKit.say(_msg, Locale.t("lb_heir_support_ok", [win.name, n]), true)
	_show()

func _battle() -> void:
	GameState.add_lineage_event(Locale.t("lb_heir_log_duel", [_a.name, _b.name]))
	GameState.set_meta("battle_return", "res://scenes/hub/heir_rivalry.tscn")
	GameState.set_meta("battle_map", "ch_heir_clash")
	GameState.set_meta("heir_clash_a", _a.id)
	GameState.set_meta("heir_clash_b", _b.id)
	_a.hp = _a.max_hp
	_b.hp = _b.max_hp
	_settle(Locale.t("lb_heir_zh_duel"))
	get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")

func apply_mobile_layout() -> void:
	CKPageKit.phone_fill(self)

