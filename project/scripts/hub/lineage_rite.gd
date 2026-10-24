extends Control
## Banner rite (line B, audit #28). Left: the family's children with age and state.
## Right: a four-step strip (choose path, name, seal, enlist), the step text, and the path
## choices as cards with their real effect. Children under 15 can pick an early path from 6.

const EARLY_MIN_AGE := 6
const PATHS := ["martial", "scholar", "merchant"]

var _list: VBoxContainer
var _steps: HBoxContainer
var _body: Label
var _actions: HBoxContainer
var _selected: CKCharacter
var _step := 0
var _path := ""
var _msg: Label

func _ready() -> void:
	UIKit.make_themed_bg(self, "rite")
	CKPageKit.shell(self, Locale.t("lb_rite_ctx"), "BANNER RITE", Locale.t("lb_rite_title"), Locale.t("lb_rite_desc", [Calendar.ADULT_AGE, EARLY_MIN_AGE]), "none")
	var left := CKPageKit.card(self, Rect2(42, CKPageKit.TOP + 8, 360, 512), "HeirList")
	CKPageKit.card_head(left, Locale.t("lb_rite_kids"), "CHILDREN")
	_list = CKPageKit.list(left, Rect2(12, 58, 336, 440), "Kids")
	var right := CKPageKit.card(self, Rect2(414, CKPageKit.TOP + 8, 824, 512), "RiteBoard")
	_steps = HBoxContainer.new()
	_steps.name = "Steps"
	_steps.position = Vector2(18, 16)
	_steps.add_theme_constant_override("separation", 8)
	right.add_child(_steps)
	_body = CKPageKit.text("", UIKit.TEXT, 15, 788)
	_body.name = "RiteText"
	_body.position = Vector2(18, 80)
	_body.size = Vector2(788, 150)
	_body.clip_text = false
	_body.max_lines_visible = -1
	right.add_child(_body)
	_actions = HBoxContainer.new()
	_actions.name = "RiteActions"
	_actions.position = Vector2(18, 250)
	_actions.size = Vector2(788, 246)
	_actions.add_theme_constant_override("separation", 12)
	right.add_child(_actions)
	_msg = CKPageKit.feedback(self)
	_refresh_list()
	CKPageKit.footer(self, [["ESC", Locale.t("btn_back")]], "BANNER RITE · FROST")
	UIFX.page_enter(self)

func _path_zh(p: String) -> String:
	return Locale.t("lb_path_" + p) if p != "" else Locale.t("lb_path_none")

func _refresh_list() -> void:
	CKPageKit.clear(_list)
	var kids: Array = GameState.characters.values().filter(func(ch): return ch.alive and ch.is_child)
	kids.sort_custom(func(a, b): return int(a.age) > int(b.age))
	for ch in kids:
		var ready: bool = ch.age >= Calendar.ADULT_AGE and not ch.in_roster
		var tag := Locale.t("lb_rite_ready") if ready else (Locale.t("lb_rite_in") if ch.in_roster else Locale.t("lb_rite_age", [ch.age]))
		var p := str(GameState.lineage_path.get(ch.id, ""))
		if p != "":
			tag += " · " + _path_zh(p)
		var b := CKPageKit.button("%s　%s" % [ch.name, tag], _selected == ch, 320, 52)
		b.toggle_mode = true
		b.button_pressed = _selected == ch
		CKPageKit.lock(b, Locale.t("lb_rite_already") if ch.in_roster else "")
		b.pressed.connect(func(): Sfx.click(); _select(ch))
		_list.add_child(b)
	if kids.is_empty():
		_list.add_child(CKPageKit.empty(Locale.t("lb_rite_none"), Locale.t("lb_rite_none_why"), Locale.t("lb_rite_none_how"), 300))
	CKPageKit.drag_through(_list)
	UIFX.wire_tree(_list)
	if _selected == null:
		_paint_steps(-1)
		_body.text = Locale.t("lin_rite_hint", [kids.size(), EARLY_MIN_AGE])
		_body.clip_text = false
		_body.max_lines_visible = -1
		CKPageKit.clear(_actions)
		if kids.is_empty():
			## Empty list already has how-text; named tap CTA (heir #30 pattern).
			var to_m := CKPageKit.button(Locale.t("lb_rite_to_marriage"), true, 260)
			to_m.name = "ToMarriage"
			to_m.pressed.connect(func(): CKNav.go("res://scenes/hub/marriage.tscn"))
			_actions.add_child(to_m)
			UIFX.wire_button(to_m)

func _paint_steps(cur: int) -> void:
	CKPageKit.clear(_steps)
	for i in 4:
		var col: Color = UIKit.ACCENT if i == cur else (UIKit.OK if i < cur else UIKit.TEXT_FAINT)
		var chip := PanelContainer.new()
		chip.custom_minimum_size = Vector2(190, 48)
		chip.add_theme_stylebox_override("panel", UIKit.flat_box(Color(col, 0.10), col, 8, 2 if i == cur else 1))
		var l := UIKit.title_label(Locale.t("lb_rite_step_%d" % i), 15, UIKit.TEXT if i <= cur else UIKit.TEXT_DIM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.add_child(l)
		_steps.add_child(chip)

func _select(c: CKCharacter) -> void:
	_selected = c
	_path = str(GameState.lineage_path.get(c.id, ""))
	_step = 0 if _path == "" else 1
	_refresh_list()
	if c.age < Calendar.ADULT_AGE:
		_show_early()
	else:
		_show_step()

func _path_cards(cb: Callable) -> void:
	for p in PATHS:
		var r := CKPageKit.row(UIKit.ACCENT if p == _path else UIKit.TEXT_FAINT, 230)
		var pc: PanelContainer = r[0]
		pc.custom_minimum_size = Vector2(254, 230)
		pc.name = "Path_" + p
		var v: VBoxContainer = r[1]
		v.add_child(UIKit.title_label(_path_zh(p), 18))
		v.add_child(CKPageKit.text(Locale.t("lb_path_%s_fx" % p), UIKit.TEXT_DIM, 13, 226))
		var sp := Control.new()
		sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(sp)
		var b := CKPageKit.button(Locale.t("lb_rite_pick"), p == _path, 226)
		b.pressed.connect(func(): cb.call(p))
		v.add_child(b)
		_actions.add_child(pc)
	UIFX.wire_tree(_actions)

func _show_early() -> void:
	CKPageKit.clear(_actions)
	_paint_steps(-1)
	if _selected.age < EARLY_MIN_AGE:
		_body.text = Locale.t("lin_too_young") % [_selected.name, _selected.age, EARLY_MIN_AGE]
		return
	_body.text = Locale.t("lb_rite_early", [_selected.name, _selected.age, _path_zh(_path)])
	_path_cards(Callable(self, "_set_early"))

func _set_early(path: String) -> void:
	_path = path
	GameState.lineage_path[_selected.id] = path
	GameState.add_lineage_event(Locale.t("lb_rite_log_early", [_selected.name, _path_zh(path)]))
	CKPageKit.say(_msg, Locale.t("lb_rite_early_ok", [_path_zh(path)]), true)
	Sfx.lineage_chime()
	GameState.save_game()
	_refresh_list()
	_show_early()

func _show_step() -> void:
	CKPageKit.clear(_actions)
	if _selected == null:
		return
	_paint_steps(_step)
	match _step:
		0:
			_body.text = Locale.t("lb_rite_s0", [_selected.name])
			_path_cards(Callable(self, "_choose_path"))
		1:
			_body.text = Locale.t("lb_rite_s1", [_selected.name, _path_zh(_path)])
			_act(Locale.t("lb_rite_s1_go"), true, func(): _step = 2; _show_step())
			_act(Locale.t("lb_rite_repick"), false, func(): _step = 0; _show_step())
		2:
			_body.text = Locale.t("lb_rite_s2", [_selected.name])
			_act(Locale.t("lb_rite_s2_go"), true, func(): _step = 3; _show_step())
		3:
			_body.text = Locale.t("lb_rite_s3", [_path_zh(_path), Locale.t("lb_path_%s_fx" % _path)])
			_act(Locale.t("lb_rite_s3_go"), true, func(): _do_enlist())
			_act(Locale.t("lb_rite_cancel"), false, func(): _selected = null; _refresh_list())

func _act(t: String, primary: bool, cb: Callable) -> void:
	var b := CKPageKit.button(t, primary, 240)
	b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(cb)
	_actions.add_child(b)
	UIFX.wire_button(b)

func _choose_path(path: String) -> void:
	_path = path
	GameState.lineage_path[_selected.id] = path
	GameState.add_lineage_event(Locale.t("lb_rite_log_path", [_selected.name, _path_zh(path)]))
	Sfx.confirm()
	_step = 1
	_show_step()

func _do_enlist() -> void:
	if _selected == null:
		return
	var r: Dictionary = Lineage.enlist_adult(_selected)
	var msg := str(r.get("msg", ""))
	if bool(r.get("ok", false)):
		var granted: Array = GameState.grant_path_skills(_selected, _path)
		if granted.size() > 0:
			var names: Array = []
			for sid in granted:
				names.append(str(GameState.get_skill(sid).get("name", sid)))
			msg += Locale.t("lb_rite_skills", [" / ".join(names)])
		match _path:
			"martial":
				GameState.add_skill_point(1)
			"scholar":
				GameState.add_rep("riverland", 3)
			"merchant":
				GameState.silver += 40
		msg += " " + Locale.t("lb_path_%s_fx" % _path)
		GameState.add_lineage_event(Locale.t("lb_rite_log_done", [_selected.name, _path_zh(_path)]))
		GameState.add_skill_point(1)
		GameState.add_rep("ashland", 2)
		Sfx.lineage_chime()
		Sfx.fanfare()
		for am in GameState.check_ambitions():
			msg += " " + str(am)
		GameState.save_game()
	CKPageKit.say(_msg, msg, bool(r.get("ok", false)))
	_selected = null
	_refresh_list()

func apply_mobile_layout() -> void:
	CKPageKit.phone_fill(self)
	if _body != null:
		_body.clip_text = false
		_body.max_lines_visible = -1
		_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.size.y = maxf(_body.size.y, 160.0)

