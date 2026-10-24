extends Control
## Banner school (line B, audit #19). Three cards, left to right:
## pupils (who can learn, tutor, lessons used this year) -> tutors for the picked pupil with
## the expected gain -> class change for any roster member with each requirement shown.

var _pupil := ""
var _promo_id := ""
var _kids: VBoxContainer
var _tutors: VBoxContainer
var _promo: VBoxContainer
var _plan: Label
var _teach: Button
var _msg: Label

func _ready() -> void:
	UIKit.make_themed_bg(self, "train")
	CKPageKit.shell(self, Locale.t("ux_qi_shu_title"), "BANNER SCHOOL", Locale.t("ux_qi_shu_title"), Locale.t("lb_train_desc", [CKTutor.pair_cap(), CKTutor.year_limit()]), "none")
	var a := CKPageKit.card(self, Rect2(42, CKPageKit.TOP + 8, 380, 512), "PupilCard")
	CKPageKit.card_head(a, Locale.t("lb_train_pupils"), "PUPILS · 1-15")
	_kids = CKPageKit.list(a, Rect2(14, 58, 352, 440), "DynPupils")
	var b := CKPageKit.card(self, Rect2(434, CKPageKit.TOP + 8, 400, 512), "TutorCard")
	CKPageKit.card_head(b, Locale.t("ux_qi_shu_tutors"), "TUTORS")
	_tutors = CKPageKit.list(b, Rect2(14, 58, 372, 300), "DynTutors")
	_plan = CKPageKit.text("", UIKit.TEXT, 14, 372)
	_plan.name = "LessonPlan"
	_plan.position = Vector2(14, 366)
	_plan.size = Vector2(372, 74)
	b.add_child(_plan)
	_teach = CKPageKit.button(Locale.t("lb_train_teach"), true, 372)
	_teach.name = "TeachButton"
	_teach.position = Vector2(14, 448)
	_teach.pressed.connect(_do_teach)
	b.add_child(_teach)
	var c := CKPageKit.card(self, Rect2(846, CKPageKit.TOP + 8, 392, 512), "PromoCard")
	CKPageKit.card_head(c, Locale.t("lb_train_promo"), "CLASS CHANGE")
	_promo = CKPageKit.list(c, Rect2(14, 58, 364, 440), "DynPromoList")
	_msg = CKPageKit.feedback(self)
	_msg.name = "DynMsg"
	_rebuild()
	CKPageKit.footer(self, [["ESC", Locale.t("btn_back")]], "BANNER SCHOOL · FROST")
	UIFX.page_enter(self)
	UIFX.wire_tree(self)

func _rebuild() -> void:
	_fill_kids()
	_fill_tutors()
	_fill_promo()
	UIFX.wire_tree(self)

func _fill_kids() -> void:
	CKPageKit.clear(_kids)
	var kids: Array = GameState.characters.values().filter(func(ch): return CKTutor.can_be_pupil(ch))
	kids.sort_custom(func(x, y): return str(x.id) < str(y.id))
	if kids.is_empty():
		_kids.add_child(CKPageKit.empty(Locale.t("lb_train_no_kids"), Locale.t("lb_train_no_kids_why"), Locale.t("lb_train_no_kids_how"), 300))
		## Empty list already has how-text; named tap CTA (rite/heir #30 pattern).
		var to_m := CKPageKit.button(Locale.t("lb_train_to_marriage"), true, 300)
		to_m.name = "ToMarriage"
		to_m.pressed.connect(func(): CKNav.go("res://scenes/hub/marriage.tscn"))
		_kids.add_child(to_m)
		UIFX.wire_button(to_m)
		return
	if _pupil == "" or not kids.any(func(ch): return ch.id == _pupil):
		_pupil = str(kids[0].id)
	for ch in kids:
		var tid := CKTutor.tutor_of(ch.id)
		var tutor: CKCharacter = GameState.characters.get(tid)
		var line := Locale.t("ux_qi_shu_age") % [ch.name, ch.age]
		var sub := Locale.t("lb_train_has_tutor", [tutor.name, CKTutor.year_used(ch.id, tid), CKTutor.year_limit()]) if tutor else Locale.t("lb_train_no_tutor")
		_kids.add_child(_pick_row(ch, line, sub, ch.id == _pupil, func(): _pupil = ch.id; Sfx.click(); _rebuild()))
	CKPageKit.drag_through(_kids)

func _fill_tutors() -> void:
	CKPageKit.clear(_tutors)
	_teach.visible = _pupil != ""
	if _pupil == "":
		_plan.text = ""
		_tutors.add_child(CKPageKit.empty(Locale.t("lb_train_tutor_none"), Locale.t("lb_train_tutor_wait"), "", 320))
		return
	var cur := CKTutor.tutor_of(_pupil)
	var any := false
	for t in GameState.roster():
		if not CKTutor.can_be_tutor(t):
			continue
		any = true
		var stat := Locale.t("stat_" + CKTutor.peak_stat(t))
		var cap := CKTutor.tutor_pupil_cap(t)
		var sub := Locale.t("lb_train_tutor_line", [stat, CKTutor.pupils_of(t.id).size(), cap])
		var tid := str(t.id)
		_tutors.add_child(_pick_row(t, Locale.t("ux_qi_shu_bow") % t.name, sub, tid == cur, func(): _assign(tid)))
	if not any:
		_tutors.add_child(CKPageKit.empty(Locale.t("lb_train_no_tutor_title"), Locale.t("lb_train_no_tutor_why"), "", 320))
		## Empty tutors already says need 16+ unhurt roster; named tap CTA.
		var to_t := CKPageKit.button(Locale.t("lb_train_to_tavern"), true, 320)
		to_t.name = "ToTavern"
		to_t.pressed.connect(func(): CKNav.go("res://scenes/hub/tavern.tscn"))
		_tutors.add_child(to_t)
		UIFX.wire_button(to_t)
	CKPageKit.drag_through(_tutors)
	var prev: Dictionary = CKTutor.preview(_pupil)
	_plan.text = str(prev.get("msg", ""))
	_plan.add_theme_color_override("font_color", UIKit.TEXT if bool(prev.get("ok", false)) else UIKit.TEXT_DIM)
	CKPageKit.lock(_teach, "" if bool(prev.get("ok", false)) else str(prev.get("msg", "")))

func _fill_promo() -> void:
	CKPageKit.clear(_promo)
	var people: Array = GameState.roster().filter(func(ch): return not CKTutor.promote_list(ch).is_empty())
	if people.is_empty():
		_promo.add_child(CKPageKit.empty(Locale.t("lb_train_promo_none"), Locale.t("lb_train_promo_none_why"), "", 320))
		## Empty promo already says reclass elsewhere; named tap CTA.
		var to_tp := CKPageKit.button(Locale.t("lb_train_to_title_promote"), true, 320)
		to_tp.name = "ToTitlePromote"
		to_tp.pressed.connect(func(): CKNav.go("res://scenes/hub/title_promote.tscn"))
		_promo.add_child(to_tp)
		UIFX.wire_button(to_tp)
		return
	if _promo_id == "" or not people.any(func(ch): return ch.id == _promo_id):
		_promo_id = str(people[0].id)
	for ch in people:
		var job_name := str(GameState.get_job(ch.job_id).get("name", ch.job_id))
		_promo.add_child(_pick_row(ch, ch.name, job_name, ch.id == _promo_id, func(): _promo_id = ch.id; Sfx.click(); _fill_promo(); UIFX.wire_tree(self)))
		if ch.id != _promo_id:
			continue
		for jid in CKTutor.promote_list(ch):
			_promo.add_child(_promo_option(ch, str(jid)))
	CKPageKit.drag_through(_promo)

func _promo_option(ch: CKCharacter, jid: String) -> Control:
	var job: Dictionary = GameState.get_job(jid)
	var r := CKPageKit.row(UIKit.ACCENT, 60)
	var v: VBoxContainer = r[1]
	var missing := _missing(ch, job.get("req", {}))
	v.add_child(UIKit.title_label(Locale.t("ux_qi_shu_promo_to") % job.get("name", jid), 15))
	v.add_child(CKPageKit.text(_req_text(ch, job.get("req", {})), UIKit.DANGER if missing != "" else UIKit.OK, 13, 320))
	var go := CKPageKit.button(Locale.t("lb_train_promo_go"), missing == "", 320)
	go.name = "Promote_%s" % jid
	CKPageKit.lock(go, missing)
	go.pressed.connect(func():
		var res: Dictionary = GameState.try_promote(ch.id, jid)
		CKPageKit.say(_msg, str(res.get("msg", "")), bool(res.get("ok", false)))
		if bool(res.get("ok", false)):
			UIFX.confirm(go)
		_fill_promo()
		UIFX.wire_tree(self))
	v.add_child(go)
	return r[0]

func _req_text(ch: CKCharacter, req: Dictionary) -> String:
	if req.is_empty():
		return Locale.t("lb_train_req_none")
	var parts: Array = []
	for k in req.keys():
		var have := int(ch.stats.get(k, 0)) if k in CKCharacter.STAT_KEYS else (GameState.iron if k == "iron" else GameState.herb)
		var nm := Locale.t("stat_" + k) if k in CKCharacter.STAT_KEYS else Locale.t("lb_res_" + k)
		parts.append(Locale.t("lb_train_req_item", [nm, have, int(req[k])]))
	return "　".join(parts)

func _missing(ch: CKCharacter, req: Dictionary) -> String:
	for k in req.keys():
		var have := int(ch.stats.get(k, 0)) if k in CKCharacter.STAT_KEYS else (GameState.iron if k == "iron" else GameState.herb)
		if have < int(req[k]):
			var nm := Locale.t("stat_" + k) if k in CKCharacter.STAT_KEYS else Locale.t("lb_res_" + k)
			return Locale.t("lb_train_req_short", [nm, int(req[k]) - have])
	return ""

func _pick_row(ch: CKCharacter, title: String, sub: String, on: bool, cb: Callable) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 60)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.toggle_mode = true
	b.button_pressed = on
	b.pressed.connect(cb)
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var pr := UIKit.make_portrait_rect(ch, 44)
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(pr)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(v)
	var t := UIKit.title_label(title, 15, UIKit.ACCENT if on else UIKit.TEXT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	var s := UIKit.body_label(sub, UIKit.TEXT_DIM, 12)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(s)
	return b

func _assign(tid: String) -> void:
	var res: Dictionary = CKTutor.assign(_pupil, tid)
	CKPageKit.say(_msg, str(res.get("msg", "")), bool(res.get("ok", false)))
	_rebuild()

func _do_teach() -> void:
	var res: Dictionary = CKTutor.teach(_pupil)
	CKPageKit.say(_msg, str(res.get("msg", "")), bool(res.get("ok", false)))
	if bool(res.get("ok", false)):
		UIFX.confirm(_teach)
	_rebuild()

func apply_mobile_layout() -> void:
	CKPageKit.phone_fill(self)

