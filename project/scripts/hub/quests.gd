extends Control
## WS-C #40 — Frost 委托榜：每张卡写清地点、星级、奖励、剩余月。
## 上半「在途委托」= 舆图各城接下的 World.active（在哪交、还剩几月）；下半「本堡委托」= 灰旗堡木板上的 GameState.quests。

const DANGER_COL := [Color(0.55, 0.8, 0.6), Color(0.85, 0.8, 0.45), Color(0.95, 0.6, 0.35), Color(0.95, 0.4, 0.4)]

var _msg: Label
var _list: VBoxContainer
var _busy := false


func _ready() -> void:
	UIKit.void_bg(self)
	UIKit.top_bar(
		self,
		Locale.t("wsc_q_77d6cc16"),
		[[Locale.t("wsc_q_cac5dd12"), str(GameState.silver), UIKit.ACCENT], [Locale.t("wsc_q_ab9ac691"), "%d" % World.active.size(), UIKit.TEXT]],
		Locale.t("wsc_q_5f411223"),
		_back
	)
	var tip := UIKit.make_dim_label(Locale.t("wsc_q_b35bb92a"))
	tip.position = Vector2(32, 64)
	add_child(tip)
	var scroll := ScrollContainer.new()
	scroll.name = "QuestScroll"
	scroll.position = Vector2(32, 94)
	scroll.size = Vector2(1216, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(1200, 0)
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
	_msg = UIKit.make_label("")
	_msg.position = Vector2(32, 664)
	_msg.size = Vector2(1216, 40)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_msg)
	_render()
	UIFX.page_enter(self)


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()


func _back() -> void:
	var ret := StoryCatalog.take_story_return("")
	if ret != "":
		CKNav.replace(ret)
	else:
		CKNav.up()


static func months_left(q: Dictionary) -> int:
	var dpm := maxi(1, int(World.rules.get("days_per_month", 30)))
	var left := int(q.get("deadline", World.days_total)) - World.days_total
	return maxi(0, int(ceil(float(left) / dpm)))


static func castle_place(q: Dictionary) -> String:
	var nm := str(q.get("name", ""))
	var i := nm.find("·")
	return nm.substr(i + 1) if i >= 0 else Locale.t("wsc_q_259e5d9b")


func _section(text: String) -> void:
	var l := UIKit.make_label(text)
	l.add_theme_color_override("font_color", UIKit.ACCENT)
	_list.add_child(l)


func _card(
	title: String, stars: int, place: String, reward: String, left: String, desc: String, btn_text: String, cb: Callable, btn_enabled: bool = true
) -> PanelContainer:
	var card := UIKit.make_glass(10, 0.72)
	card.custom_minimum_size = Vector2(1200, 96)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	card.add_child(hb)
	var star := Label.new()
	star.text = "★".repeat(clampi(stars, 1, 4)) + "☆".repeat(4 - clampi(stars, 1, 4))
	star.custom_minimum_size = Vector2(92, 0)
	star.add_theme_font_size_override("font_size", 20)
	star.add_theme_color_override("font_color", DANGER_COL[clampi(stars, 1, 4) - 1])
	star.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(star)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 4)
	hb.add_child(vb)
	vb.add_child(UIKit.make_label(title))
	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 10)
	meta.add_child(UIKit.tag_chip("@ " + place, UIKit.TEXT))
	meta.add_child(UIKit.tag_chip(reward, UIKit.ACCENT))
	meta.add_child(UIKit.tag_chip(left, UIKit.OK))
	vb.add_child(meta)
	var d := UIKit.make_dim_label(desc)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(d)
	var b := UIKit.make_accent_button(btn_text, 150) if btn_enabled else UIKit.make_button(btn_text, 150)
	b.custom_minimum_size = Vector2(150, 56)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = not btn_enabled
	if cb.is_valid():
		b.pressed.connect(cb)
	hb.add_child(b)
	_list.add_child(card)
	return card


func _render() -> void:
	for ch in _list.get_children():
		_list.remove_child(ch)
		ch.queue_free()
	_section(Locale.t("wsc_q_237f513f"))
	if World.active.is_empty():
		_list.add_child(UIKit.empty_state(Locale.t("wsc_q_6af2d7f3")))
	for q in World.active:
		var turn := str(World.node(World.turn_in_city(q)).get("name", "?"))
		var ml := months_left(q)
		var ready := str(q.get("state", "")) == "ready"
		var rw := Locale.t("wsc_q_698e1de6") % [int(q.get("reward_silver", 0)), int(q.get("reward_rep", 0))]
		var lt := Locale.t("wsc_q_ea883343") if ready else (Locale.t("wsc_q_8a110754") if ml <= 1 else Locale.t("wsc_q_2a74a2d2") % ml)
		var qid_w := str(q.get("id", ""))
		_card(
			str(q.get("title", Locale.t("wsc_q_f6b0bbbb"))),
			int(q.get("danger", 1)),
			Locale.t("wsc_q_733a33e4") % turn,
			rw,
			lt,
			str(q.get("desc", "")),
			Locale.t("wsc_q_40f0ff09"),
			func(): _goto_atlas_for(World.quest_by_id(qid_w))
		)
	_section(Locale.t("wsc_q_657f636f"))
	if GameState.quests.is_empty():
		_list.add_child(UIKit.empty_state(Locale.t("wsc_q_928374db")))
	for q in GameState.quests:
		var done := bool(GameState.quest_done.get(q.id, false))
		var rw2 := Locale.t("wsc_q_59f56eb6") % [int(q.silver), int(q.rep), "" if done else Locale.t("wsc_q_6072033e")]
		var kind := Locale.t("wsc_q_d9de6252") if q.get("battle") else Locale.t("wsc_q_f91ef435")
		var qid := str(q.id)
		_card(
			str(q.name),
			int(q.stars),
			castle_place(q),
			rw2,
			Locale.t("wsc_q_7ec42c54") % int(q.months),
			"%s。%s" % [kind, str(q.desc)],
			Locale.t("wsc_q_145290c3") if done else Locale.t("wsc_q_5a9e3347"),
			func(): _accept(qid)
		)


func _goto_atlas() -> void:
	CKNav.go("res://scenes/hub/atlas_view.tscn")


func _goto_atlas_for(q: Dictionary) -> void:
	var guide := World.quest_guide_node(q)
	if guide != "" and World.nodes.has(guide):
		GameState.set_meta("atlas_select", guide)
		var nv := World.nation_of(guide)
		if nv != "":
			GameState.set_meta("atlas_view", nv)
	CKNav.go("res://scenes/hub/atlas_view.tscn")


func _accept(qid: String) -> void:
	if _busy:
		return
	_busy = true
	var r = GameState.accept_quest(qid)
	if not bool(r.get("ok", false)):
		_busy = false
		_say(Locale.t("wsc_q_ac8fdce0") % str(r.get("msg", Locale.t("wsc_q_416876df"))), false)
		return
	if r.get("battle"):
		GameState.set_meta("battle_return", "res://scenes/hub/quests.tscn")
		var mid = str(r.quest.get("map", GameState.get_meta("battle_map", "quest_bandit")))
		GameState.set_meta("battle_map", mid)
		CKNav.replace("res://scenes/battle/battle.tscn")
		return
	var extra = str(r.get("first_clear", ""))
	_say(Locale.t("wsc_q_04480f1a") % [r.quest.name, extra], true)
	GameState.save_game()
	_busy = false
	_render()


func _say(t: String, ok: bool) -> void:
	_msg.text = t
	_msg.add_theme_color_override("font_color", UIKit.OK if ok else UIKit.DANGER)
