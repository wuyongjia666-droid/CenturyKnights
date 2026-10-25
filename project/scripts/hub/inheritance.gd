extends Control
## Succession clash with Shuoying (line B, audit #29). Each answer is a card with its
## consequence written out. One answer per year: after that the page says when they return.
## Ambition offer (stele honor) still comes first when the leader has to choose one.

const _AMB := preload("res://scripts/characters/ambitions.gd")
const CHOICES := ["steel", "soft", "delay"]

var _heir: CKCharacter
var _body: Label
var _cards: BoxContainer
var _msg: Label

func _ready() -> void:
	UIKit.make_themed_bg(self, "inheritance")
	CKPageKit.shell(self, Locale.t("lb_inh_ctx"), "SUCCESSION", Locale.t("lb_inh_title"), Locale.t("lb_inh_desc"), "none")
	var board := CKPageKit.card(self, Rect2(42, CKPageKit.TOP + 8, 1196, 512), "InheritBoard")
	_body = CKPageKit.text("", UIKit.TEXT, 15, 1150)
	_body.name = "InheritText"
	_body.position = Vector2(22, 18)
	_body.size = Vector2(1150, 150)
	if DeviceProfile.is_mobile():
		_body.custom_minimum_size = Vector2(1150, 0)
		_body.size.y = 0
	board.add_child(_body)
	_cards = HBoxContainer.new()
	_cards.name = "Answers"
	_cards.position = Vector2(22, 180)
	_cards.add_theme_constant_override("separation", 14)
	board.add_child(_cards)
	_msg = CKPageKit.feedback(self)
	_pick_heir()
	_place_succession_crests()
	_show()
	CKPageKit.footer(self, [["ESC", Locale.t("btn_back")]], "SUCCESSION · FROST")
	UIFX.page_enter(self)


func _place_succession_crests() -> void:
	## 团徽 + heir on InheritBoard; company header on the shell.
	var mob := DeviceProfile.is_mobile()
	CKHeraldryChrome.place_company_header(self, Vector2(1180, 8) if not mob else Vector2(1180, 4), Vector2(44, 52) if not mob else Vector2(40, 48))
	var board := get_node_or_null("InheritBoard") as Control
	var host: Node = board if board != null else self
	var at := Vector2(980, 12) if board != null else Vector2(980, 12)
	if mob:
		at = Vector2(900, 8)
	CKHeraldryChrome.place_succession_crest_strip(host, _heir, at, Vector2(36, 44) if not mob else Vector2(32, 38))

func _pick_heir() -> void:
	_heir = null
	for ch in GameState.characters.values():
		if ch.alive and (ch.is_child or GameState.lineage_path.has(ch.id)) and ch.age >= 10:
			_heir = ch
			break
	if _heir == null:
		_heir = GameState.get_leader()

func _done_this_year() -> bool:
	return int(GameState.house_mods.get("inherit_answer_year", 0)) == Calendar.year

func _show() -> void:
	_place_succession_crests()
	CKPageKit.clear(_cards)
	var leader := GameState.get_leader()
	if leader != null and _AMB.needs_choice():
		_show_offer(leader)
		return
	var hname := _heir.name if _heir else Locale.t("lb_inh_noheir")
	var path := str(GameState.lineage_path.get(_heir.id, "")) if _heir else ""
	var pz := Locale.t("lb_path_" + path) if path != "" else Locale.t("lb_path_none")
	if _done_this_year():
		_body.text = Locale.t("lb_inh_done", [str(GameState.house_mods.get("inherit_answer_zh", "")), Calendar.year + 1])
		## Y1-B feel chain (#29↔#30): settled heir trials → here; done year → back to heir + rivals.
		var to_heir := CKPageKit.button(Locale.t("lb_inh_to_heir"), true, 260)
		to_heir.name = "ToHeirRivalry"
		to_heir.pressed.connect(func(): CKNav.go("res://scenes/hub/heir_rivalry.tscn"))
		_cards.add_child(to_heir)
		UIFX.wire_button(to_heir)
		var to_rivals := CKPageKit.button(Locale.t("lb_inh_to_rivals"), false, 260)
		to_rivals.name = "ToRivals"
		to_rivals.pressed.connect(func(): CKNav.go("res://scenes/hub/rival_houses.tscn"))
		_cards.add_child(to_rivals)
		UIFX.wire_button(to_rivals)
		UIFX.wire_tree(_cards)
		_mobile_after_show()
		return
	_body.text = Locale.t("lb_inh_envoy", [hname, pz])
	for k in CHOICES:
		var r := CKPageKit.row(UIKit.ACCENT, 300)
		var p: PanelContainer = r[0]
		p.custom_minimum_size = Vector2(372, 320 if DeviceProfile.is_mobile() else 300)
		p.name = "Answer_" + k
		var v: VBoxContainer = r[1]
		v.add_child(UIKit.title_label(Locale.t("lb_inh_%s" % k), 18))
		v.add_child(CKPageKit.text(Locale.t("lb_inh_%s_story" % k), UIKit.TEXT_DIM, 13, 340))
		v.add_child(CKPageKit.text(Locale.t("lb_inh_%s_fx" % k), UIKit.OK, 13, 340))
		var sp := Control.new()
		sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(sp)
		var b := CKPageKit.button(Locale.t("lb_inh_pick"), k == "steel", 340)
		b.name = "Pick_" + k
		if k == "soft" and GameState.silver < 20:
			CKPageKit.lock(b, Locale.t("lb_short_silver", [20 - GameState.silver]))
		b.pressed.connect(func(): _resolve(k))
		v.add_child(b)
		_cards.add_child(p)
	UIFX.wire_tree(_cards)
	_mobile_after_show()

func _show_offer(leader: CKCharacter) -> void:
	var lines: PackedStringArray = PackedStringArray()
	lines.append(Locale.t("amb_offer_body", [leader.name]))
	if int(_AMB.honor_bonus().get("stele", 0)) > 0:
		lines.append(Locale.t("amb_honor", [int(_AMB.honor_bonus().get("stele", 0))]))
	_body.text = "\n".join(lines)
	for id in _AMB.open_offer(leader):
		var sid := str(id)
		var r := CKPageKit.row(UIKit.ACCENT, 260)
		var p: PanelContainer = r[0]
		p.custom_minimum_size = Vector2(372, 280 if DeviceProfile.is_mobile() else 260)
		var v: VBoxContainer = r[1]
		v.add_child(UIKit.title_label(Locale.t("amb_" + sid + "_name"), 17))
		v.add_child(CKPageKit.text(Locale.t("amb_" + sid + "_blurb"), UIKit.TEXT_DIM, 13, 340))
		var sp := Control.new()
		sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(sp)
		var b := CKPageKit.button(Locale.t("lb_inh_amb_pick"), true, 340)
		b.name = "Ambition_" + sid
		b.pressed.connect(func(): _pick_ambition(sid))
		v.add_child(b)
		_cards.add_child(p)
	UIFX.wire_tree(_cards)
	_mobile_after_show()

func _pick_ambition(id: String) -> void:
	if not _AMB.choose(id):
		return
	CKPageKit.say(_msg, Locale.t("amb_chosen", [Locale.t("amb_" + id + "_name")]), true)
	_show()

func _resolve(k: String) -> void:
	match k:
		"steel":
			GameState.add_rep("ashland", 3)
			if GameState.get_rival_stance("shuoying") == "hostile":
				GameState.set_rival_stance("shuoying", "wary")
		"soft":
			GameState.silver -= 20
			GameState.set_rival_stance("shuoying", "neutral" if GameState.get_rival_stance("shuoying") != "hostile" else "wary")
			GameState.set_rival_stance("qinghe", "cordial")
		"delay":
			GameState.add_skill_point(1)
	GameState.add_lineage_event(Locale.t("lb_inh_log", [Locale.t("lb_inh_%s" % k), _heir.name if _heir else "?"]))
	GameState.house_mods["inherit_answer_year"] = Calendar.year
	GameState.house_mods["inherit_answer_zh"] = Locale.t("lb_inh_%s" % k)
	Sfx.lineage_chime()
	GameState.save_game()
	CKPageKit.say(_msg, Locale.t("lb_inh_%s_ok" % k), true)
	_show()

func _mobile_after_show() -> void:
	## _resolve / ambition pick rebuild Answers; full mobile layout so AnswerScroll /
	## FONT_FLOOR / HIT / phone_fill stick on the done-year re-show (not a partial restack).
	if DeviceProfile.is_mobile() and is_inside_tree():
		call_deferred("apply_mobile_layout")

func apply_mobile_layout() -> void:
	## Unlock fixed body/card heights; stack answers in a scroll so FONT_FLOOR does not squash.
	set_meta("m_center_ok", true)
	CKPageKit.phone_fill(self)
	if not DeviceProfile.is_mobile():
		return
	var board := find_child("InheritBoard", true, false) as Control
	if board == null:
		return
	board.clip_contents = false
	var foot := get_node_or_null("StitchFooter") as Control
	var bottom := (foot.position.y - 8.0) if foot != null else size.y - 48.0
	board.size.y = maxf(board.size.y, bottom - board.position.y)
	if _body != null:
		_body.size.x = maxf(280.0, board.size.x - 44.0)
		_body.custom_minimum_size = Vector2(_body.size.x, 0)
		_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.clip_text = false
	MobileLayout.ensure_min_fonts(self)
	if _body != null:
		_body.size.y = maxf(_body.get_minimum_size().y + 8.0, 80.0)
	_mobile_stack_answers(board)


func _mobile_stack_answers(board: Control) -> void:
	if _cards == null:
		return
	var body_h := _body.size.y if _body != null else 80.0
	var host := board.get_node_or_null("AnswerScroll") as ScrollContainer
	if host == null:
		host = ScrollContainer.new()
		host.name = "AnswerScroll"
		host.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		host.scroll_deadzone = 10
		board.add_child(host)
	host.position = Vector2(16, 18.0 + body_h + 12.0)
	host.size = Vector2(maxf(240.0, board.size.x - 32.0), maxf(160.0, board.size.y - host.position.y - 16.0))
	# Ensure answers live under scroll as a VBox.
	if _cards.get_parent() != host:
		_cards.reparent(host, false)
	if _cards is HBoxContainer:
		var v := VBoxContainer.new()
		v.name = "Answers"
		v.add_theme_constant_override("separation", 12)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for k in _cards.get_children():
			_cards.remove_child(k)
			v.add_child(k)
		var old := _cards
		host.remove_child(old)
		old.queue_free()
		host.add_child(v)
		_cards = v
	_cards.position = Vector2.ZERO
	var col_w := maxf(260.0, host.size.x - 24.0)
	_cards.custom_minimum_size.x = col_w
	for c in _cards.get_children():
		if not (c is Control):
			continue
		var pc := c as Control
		if pc is BaseButton:
			## Done-year ToRivals is a bare button (no Answer_* card).
			pc.custom_minimum_size = Vector2(minf(col_w, maxf(pc.custom_minimum_size.x, 200.0)), maxf(pc.custom_minimum_size.y, MobilePage.HIT))
			pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			continue
		pc.custom_minimum_size = Vector2(col_w, maxf(pc.custom_minimum_size.y, 200.0))
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for lab in pc.find_children("*", "Label", true, false):
			var l := lab as Label
			l.clip_text = false
			if l.custom_minimum_size.x > 0.0:
				l.custom_minimum_size.x = minf(l.custom_minimum_size.x, col_w - 40.0)
		for b in pc.find_children("*", "BaseButton", true, false):
			var btn := b as BaseButton
			btn.custom_minimum_size.y = maxf(btn.custom_minimum_size.y, MobilePage.HIT)
			btn.custom_minimum_size.x = minf(col_w - 40.0, maxf(btn.custom_minimum_size.x, 200.0))
