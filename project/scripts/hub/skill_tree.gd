extends Control
## Battle skill tree (line B, audit #20). No pan/zoom canvas: one column per path, tiers top
## to bottom, each node a 52px card that cannot overlap. Tap a node to read it; unlocking is
## a separate button with the reason when it is not possible.

var _sel: CKCharacter
var _sid := ""
var _people: VBoxContainer
var _cols: HBoxContainer
var _detail: VBoxContainer
var _unlock: Button
var _pts: Label
var _msg: Label

func _ready() -> void:
	UIKit.make_themed_bg(self, "skill")
	CKPageKit.shell(self, Locale.t("lb_sk_ctx"), "SKILL TREE", Locale.t("lb_sk_title"), Locale.t("lb_sk_desc"), "none")
	_place_skill_crests()
	_pts = UIKit.title_label("", 16, UIKit.ACCENT)
	_pts.name = "SkillPoints"
	_pts.position = Vector2(938, 96)
	_pts.size = Vector2(300, 24)
	_pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_pts)
	var left := CKPageKit.card(self, Rect2(42, CKPageKit.TOP + 8, 220, 512), "PeopleCard")
	CKPageKit.card_head(left, Locale.t("lb_sk_people"), "ROSTER")
	_people = CKPageKit.list(left, Rect2(12, 58, 196, 440), "People")
	var mid := CKPageKit.card(self, Rect2(274, CKPageKit.TOP + 8, 640, 512), "TreeCard")
	var s := ScrollContainer.new()
	s.name = "TreeScroll"
	s.position = Vector2(12, 12)
	s.size = Vector2(616, 488)
	s.scroll_deadzone = 10
	mid.add_child(s)
	_cols = HBoxContainer.new()
	_cols.name = "Columns"
	_cols.add_theme_constant_override("separation", 10)
	s.add_child(_cols)
	var right := CKPageKit.card(self, Rect2(926, CKPageKit.TOP + 8, 312, 512), "DetailCard")
	_detail = VBoxContainer.new()
	_detail.name = "Detail"
	_detail.position = Vector2(16, 14)
	_detail.size = Vector2(280, 400)
	_detail.add_theme_constant_override("separation", 8)
	right.add_child(_detail)
	_unlock = CKPageKit.button(Locale.t("lb_sk_unlock"), true, 280)
	_unlock.name = "UnlockButton"
	_unlock.position = Vector2(16, 448)
	_unlock.pressed.connect(_do_unlock)
	right.add_child(_unlock)
	if DeviceProfile.is_mobile():
		_mobile_detail_chrome(right)
	_msg = CKPageKit.feedback(self)
	var roster: Array = GameState.roster()
	if not roster.is_empty():
		_sel = roster[0]
	_refresh()
	CKPageKit.footer(self, [["ESC", Locale.t("btn_back")]], "SKILL TREE · FROST")
	UIFX.page_enter(self)


## Phone: stretch the three kit cards, then park points + unlock inside the detail card so the
## 22px floor cannot land the points line on the page description.

func _place_skill_crests(mobile: bool = false) -> void:
	## Fat skill-tree chrome: 团徽 header + 旗徽 strip + SkillCrestStrip/PersonArms.
	for n in ["CastleArms", "CastleBannerStrip", "SkillCrestStrip"]:
		var oldn := get_node_or_null(n)
		if oldn:
			oldn.name = "_%sDying" % n
			oldn.queue_free()
	var mob := mobile or DeviceProfile.is_mobile()
	var hdr := Vector2(52, 60) if mob else Vector2(44, 52)
	var ban := Vector2(28, 38)
	var w := size.x if size.x > 400.0 else 1280.0
	var at_y := 6.0 if mob else 8.0
	var arms_x := (w - 64.0) if mob else 1180.0
	var strip_x := (w - 140.0) if mob else 1100.0
	CKHeraldryField.place_company_header(self, Vector2(arms_x, at_y), hdr)
	CKHeraldryChrome.place_castle_banner_strip(self, Vector2(strip_x, at_y), hdr, ban)
	var sat := Vector2(1020, at_y) if not mob else Vector2(maxf(20.0, w - 240.0), at_y)
	CKHeraldryChrome.place_skill_crest_strip(self, sat, Vector2(36, 44) if not mob else Vector2(32, 40), Vector2(24, 34))
	if _sel != null and _detail != null:
		CKHeraldryChrome.attach_skill_person_arms(_detail, _sel, Vector2(28, 34) if not mob else Vector2(26, 32))

func apply_mobile_layout() -> void:
	if not MobilePage.active(self):
		return
	CKPageKit.phone_fill(self)
	_place_skill_crests(true)
	var right := find_child("DetailCard", true, false) as Control
	if right != null:
		_mobile_detail_chrome(right)

func _mobile_detail_chrome(right: Control) -> void:
	if _pts == null or right == null:
		return
	if _pts.get_parent() != right:
		if _pts.get_parent():
			_pts.get_parent().remove_child(_pts)
		right.add_child(_pts)
	_pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_pts.position = Vector2(16, 12)
	_pts.size = Vector2(maxf(200.0, right.size.x - 32.0), 34)
	_pts.add_theme_font_size_override("font_size", MobilePage.FONT)
	if _detail:
		_detail.position = Vector2(16, 52)
		_detail.size = Vector2(maxf(200.0, right.size.x - 32.0), maxf(120.0, right.size.y - 52.0 - MobilePage.HIT - 28.0))
	if _unlock:
		_unlock.position = Vector2(16, right.size.y - 16.0 - MobilePage.HIT)
		_unlock.size = Vector2(maxf(160.0, right.size.x - 32.0), MobilePage.HIT)
		_unlock.custom_minimum_size = Vector2(160, MobilePage.HIT)
		_unlock.add_theme_font_size_override("font_size", MobilePage.FONT)

func _refresh() -> void:
	_pts.text = Locale.t("lb_sk_points", [GameState.skill_points])
	CKPageKit.clear(_people)
	for ch in GameState.roster():
		var b := CKPageKit.button(ch.name, ch == _sel, 190, 52)
		b.toggle_mode = true
		b.button_pressed = ch == _sel
		b.pressed.connect(func(): _sel = ch; _sid = ""; Sfx.click(); _refresh())
		_people.add_child(b)
	if _people.get_child_count() == 0:
		## Y1-B: empty roster → EmptyHost why/how + ToTavern.
		var host := VBoxContainer.new()
		host.name = "EmptyHost"
		host.add_theme_constant_override("separation", 12)
		host.add_child(CKPageKit.empty(
			Locale.t("lb_sk_nobody"),
			Locale.t("lb_sk_nobody_why"),
			Locale.t("lb_sk_nobody_how"),
			170
		))
		var acts := HBoxContainer.new()
		acts.name = "EmptyActions"
		acts.add_theme_constant_override("separation", 12)
		var to_t := CKPageKit.button(Locale.t("lb_sk_to_tavern"), true, 170)
		to_t.name = "ToTavern"
		to_t.pressed.connect(func(): CKNav.go("res://scenes/hub/tavern.tscn"))
		acts.add_child(to_t)
		UIFX.wire_button(to_t)
		host.add_child(acts)
		_people.add_child(host)
	CKPageKit.drag_through(_people)
	_fill_columns()
	_fill_detail()
	_place_skill_crests()
	UIFX.wire_tree(self)

func _fill_columns() -> void:
	CKPageKit.clear(_cols)
	if _sel == null:
		return
	var by_tree := {}
	for sk in GameState.data_skills.get("skills", []):
		if _sel.job_id in sk.get("jobs", []):
			var tid := str(sk.get("tree", "melee"))
			if not by_tree.has(tid):
				by_tree[tid] = []
			by_tree[tid].append(sk)
	for tree in GameState.data_skills.get("trees", []):
		var tid := str(tree.get("id"))
		var skills: Array = by_tree.get(tid, [])
		if skills.is_empty():
			continue
		skills.sort_custom(func(x, y): return int(x.get("tier", 1)) < int(y.get("tier", 1)))
		var col := VBoxContainer.new()
		col.name = "Tree_%s" % tid
		col.custom_minimum_size = Vector2(196, 0)
		col.add_theme_constant_override("separation", 8)
		_cols.add_child(col)
		var head := UIKit.title_label(str(tree.get("name", tid)), 16, UIKit.ACCENT)
		head.name = "TreeTitle_%s" % tid
		col.add_child(head)
		for sk in skills:
			col.add_child(_node(sk))
	if _cols.get_child_count() == 0:
		## Y1-B: no skills for job → EmptyHost why/how + ToTitlePromote.
		var host := VBoxContainer.new()
		host.name = "EmptyHost"
		host.add_theme_constant_override("separation", 12)
		host.add_child(CKPageKit.empty(
			Locale.t("lb_sk_no_tree"),
			Locale.t("lb_sk_no_tree_why"),
			Locale.t("lb_sk_no_tree_how"),
			560
		))
		var acts := HBoxContainer.new()
		acts.name = "EmptyActions"
		acts.add_theme_constant_override("separation", 12)
		var to_tp := CKPageKit.button(Locale.t("lb_sk_to_title_promote"), true, 280)
		to_tp.name = "ToTitlePromote"
		to_tp.pressed.connect(func(): CKNav.go("res://scenes/hub/title_promote.tscn"))
		acts.add_child(to_tp)
		UIFX.wire_button(to_tp)
		host.add_child(acts)
		_cols.add_child(host)
	CKPageKit.drag_through(_cols)

func _node(sk: Dictionary) -> Button:
	var sid := str(sk.get("id"))
	var owned := sid in _sel.skills or sid in _sel.unlocked_skills
	var ok := bool(GameState.can_unlock_skill(_sel, sid).get("ok", false))
	var b := Button.new()
	b.name = "Node_%s" % sid
	b.custom_minimum_size = Vector2(196, 52)
	b.toggle_mode = true
	b.button_pressed = sid == _sid
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var state := Locale.t("lb_sk_owned") if owned else (Locale.t("lb_sk_ready") if ok else Locale.t("lb_sk_locked"))
	b.text = "T%d  %s · %s" % [int(sk.get("tier", 1)), str(sk.get("name", sid)), state]
	b.add_theme_font_size_override("font_size", 13)
	if DeviceProfile.is_mobile():
		# Phone (22px type): name on line one, state on line two, so names are never cut.
		b.text = "T%d %s\n%s" % [int(sk.get("tier", 1)), str(sk.get("name", sid)), state]
		b.clip_text = false
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		b.custom_minimum_size = Vector2(196, 84)
		b.add_theme_font_size_override("font_size", MobileLayout.FONT_FLOOR)
	var col: Color = UIKit.OK if owned else (UIKit.ACCENT if ok else UIKit.TEXT_FAINT)
	b.add_theme_stylebox_override("normal", UIKit.flat_box(Color(col, 0.10), Color(col, 0.55), 8))
	b.add_theme_color_override("font_color", UIKit.TEXT if owned or ok else UIKit.TEXT_DIM)
	b.pressed.connect(func(): _sid = sid; Sfx.click(); _fill_columns(); _fill_detail(); _place_skill_crests(); UIFX.wire_tree(self))
	return b

func _fill_detail() -> void:
	CKPageKit.clear(_detail)
	if _sel == null:
		_unlock.visible = false
		return
	var job_name := str(GameState.get_job(_sel.job_id).get("name", ""))
	if _sid == "":
		_detail.add_child(UIKit.title_label(_sel.name, 18))
		_detail.add_child(CKPageKit.text(Locale.t("lb_sk_who", [job_name, _sel.skills.size()]), UIKit.TEXT_DIM, 14, 280))
		_detail.add_child(CKPageKit.text(BattleRules.class_path_text(_sel.job_id), UIKit.ACCENT, 13, 280))
		_detail.add_child(CKPageKit.text(Locale.t("lb_sk_hint"), UIKit.TEXT_DIM, 13, 280))
		_unlock.visible = false
		return
	var sk: Dictionary = GameState.get_skill(_sid)
	_detail.add_child(UIKit.title_label(str(sk.get("name", _sid)), 18))
	_detail.add_child(CKPageKit.text(Locale.t("lb_sk_meta", [int(sk.get("tier", 1)), int(sk.get("cooldown", 1)), int(sk.get("uses", 1))]), UIKit.TEXT_DIM, 13, 280))
	_detail.add_child(CKPageKit.text(str(sk.get("desc", "")), UIKit.TEXT, 14, 280))
	var req := str(sk.get("req_skill", ""))
	if req != "":
		_detail.add_child(CKPageKit.text(Locale.t("lb_sk_req", [str(GameState.get_skill(req).get("name", req))]), UIKit.TEXT_DIM, 13, 280))
	var owned := _sid in _sel.skills or _sid in _sel.unlocked_skills
	var check: Dictionary = GameState.can_unlock_skill(_sel, _sid)
	_unlock.visible = not owned
	if owned:
		_detail.add_child(CKPageKit.text(Locale.t("lb_sk_owned_long"), UIKit.OK, 14, 280))
	elif bool(check.get("ok", false)) and GameState.skill_points <= 0:
		CKPageKit.lock(_unlock, Locale.t("lb_sk_no_points"))
	else:
		CKPageKit.lock(_unlock, "" if bool(check.get("ok", false)) else str(check.get("msg", "")))

func _do_unlock() -> void:
	if _sel == null or _sid == "":
		return
	var res: Dictionary = GameState.unlock_skill(_sel, _sid)
	CKPageKit.say(_msg, str(res.get("msg", "")), bool(res.get("ok", false)))
	if bool(res.get("ok", false)):
		Sfx.fanfare()
		UIFX.confirm(_unlock)
	_refresh()
