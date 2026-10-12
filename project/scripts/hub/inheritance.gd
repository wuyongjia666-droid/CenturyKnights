extends Control
## Succession clash with Shuoying (line B, audit #29). Each answer is a card with its
## consequence written out. One answer per year: after that the page says when they return.
## Ambition offer (stele honor) still comes first when the leader has to choose one.

const _Amb := preload("res://scripts/characters/ambitions.gd")
const CHOICES := ["steel", "soft", "delay"]

var _heir: CKCharacter
var _body: Label
var _cards: HBoxContainer
var _msg: Label

func _ready() -> void:
	UIKit.make_themed_bg(self, "inheritance")
	CKPageKit.shell(self, Locale.t("lb_inh_ctx"), "SUCCESSION", Locale.t("lb_inh_title"), Locale.t("lb_inh_desc"), "none")
	var board := CKPageKit.card(self, Rect2(42, CKPageKit.TOP + 8, 1196, 512), "InheritBoard")
	_body = CKPageKit.text("", UIKit.TEXT, 15, 1150)
	_body.name = "InheritText"
	_body.position = Vector2(22, 18)
	_body.size = Vector2(1150, 150)
	board.add_child(_body)
	_cards = HBoxContainer.new()
	_cards.name = "Answers"
	_cards.position = Vector2(22, 180)
	_cards.add_theme_constant_override("separation", 14)
	board.add_child(_cards)
	_msg = CKPageKit.feedback(self)
	_pick_heir()
	_show()
	CKPageKit.footer(self, [["ESC", Locale.t("btn_back")]], "SUCCESSION · FROST")
	UIFX.page_enter(self)

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
	CKPageKit.clear(_cards)
	var leader := GameState.get_leader()
	if leader != null and _Amb.needs_choice():
		_show_offer(leader)
		return
	var hname := _heir.name if _heir else Locale.t("lb_inh_noheir")
	var path := str(GameState.lineage_path.get(_heir.id, "")) if _heir else ""
	var pz := Locale.t("lb_path_" + path) if path != "" else Locale.t("lb_path_none")
	if _done_this_year():
		_body.text = Locale.t("lb_inh_done", [str(GameState.house_mods.get("inherit_answer_zh", "")), Calendar.year + 1])
		_cards.add_child(CKPageKit.button(Locale.t("lb_inh_to_rivals"), false, 260))
		(_cards.get_child(0) as Button).pressed.connect(func(): CKNav.go("res://scenes/hub/rival_houses.tscn"))
		UIFX.wire_tree(_cards)
		return
	_body.text = Locale.t("lb_inh_envoy", [hname, pz])
	for k in CHOICES:
		var r := CKPageKit.row(UIKit.ACCENT, 300)
		var p: PanelContainer = r[0]
		p.custom_minimum_size = Vector2(372, 300)
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

func _show_offer(leader: CKCharacter) -> void:
	var lines: PackedStringArray = PackedStringArray()
	lines.append(Locale.t("amb_offer_body", [leader.name]))
	if int(_Amb.honor_bonus().get("stele", 0)) > 0:
		lines.append(Locale.t("amb_honor", [int(_Amb.honor_bonus().get("stele", 0))]))
	_body.text = "\n".join(lines)
	for id in _Amb.open_offer(leader):
		var sid := str(id)
		var r := CKPageKit.row(UIKit.ACCENT, 260)
		var p: PanelContainer = r[0]
		p.custom_minimum_size = Vector2(372, 260)
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

func _pick_ambition(id: String) -> void:
	if not _Amb.choose(id):
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
