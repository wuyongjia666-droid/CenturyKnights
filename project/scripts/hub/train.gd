extends Control
## v9.2 banner school UI. Nav plaque: Locale btn_train (旗塾).
var _msg: Label
var _pupil: String = ""
func _ready() -> void:
	UIKit.make_themed_bg(self, "train")
	if not UIKit.RETIRE_CHROME and ResourceLoader.exists("res://assets/art/ui/train_banner.png"):
		var _bn := TextureRect.new()
		_bn.texture = load("res://assets/art/ui/train_banner.png")
		_bn.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_bn.stretch_mode = TextureRect.STRETCH_SCALE
		_bn.position = Vector2(0, 0)
		_bn.size = Vector2(1280, 52)
		_bn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_bn)
		UIFX.banner_shimmer(_bn, 3.8)
	UIFX.page_enter(self)
	_rebuild()
	UIFX.wire_tree(self)

func _rebuild() -> void:
	for ch in get_children():
		if str(ch.name).begins_with("Dyn"):
			ch.queue_free()
	var t = UIKit.make_label(Locale.t("ux_qi_shu_title"), true); t.name = "DynTitle"; t.position = Vector2(40, 16); add_child(t)
	var tip = UIKit.make_dim_label(Locale.t("ux_qi_shu_tip") % CKTutor.pair_cap())
	tip.name = "DynTip"; tip.position = Vector2(40, 56); tip.custom_minimum_size = Vector2(1100, 40); tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(tip)
	var vb := VBoxContainer.new(); vb.name = "DynPupils"; vb.position = Vector2(40, 100); vb.add_theme_constant_override("separation", 8); add_child(vb)
	var kids: Array = []
	for c in GameState.characters.values():
		if CKTutor.can_be_pupil(c):
			kids.append(c)
	kids.sort_custom(func(a, b): return str(a.id) < str(b.id))
	if kids.is_empty():
		vb.add_child(UIKit.make_dim_label(Locale.t("ux_qi_shu_no_kids")))
	for c in kids:
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10); vb.add_child(row)
		row.add_child(UIKit.make_portrait_rect(c, 48))
		var tid := CKTutor.tutor_of(c.id)
		var tutor: CKCharacter = GameState.characters.get(tid)
		var label := Locale.t("ux_qi_shu_age") % [c.name, c.age]
		if tutor:
			label += Locale.t("ux_qi_shu_has_tutor") % tutor.name
		else:
			label += Locale.t("ux_qi_shu_no_tutor")
		var b = UIKit.make_button(label, 320)
		var cid = c.id
		b.pressed.connect(func(): _pupil = cid; _rebuild())
		row.add_child(b)
		if _pupil == c.id and tutor:
			var teach = UIKit.make_button(Locale.t("ux_qi_shu_teach"), 120)
			teach.pressed.connect(func():
				var r = CKTutor.teach(cid)
				_msg.text = str(r.get("msg"))
				_rebuild()
			)
			row.add_child(teach)
	var tv := VBoxContainer.new(); tv.name = "DynTutors"; tv.position = Vector2(520, 100); tv.add_theme_constant_override("separation", 8); add_child(tv)
	tv.add_child(UIKit.make_label(Locale.t("ux_qi_shu_tutors")))
	if _pupil == "":
		tv.add_child(UIKit.make_dim_label(Locale.t("ux_qi_shu_pick_kid")))
	else:
		for c in GameState.roster():
			if not CKTutor.can_be_tutor(c):
				continue
			var row2 := HBoxContainer.new(); row2.add_theme_constant_override("separation", 8); tv.add_child(row2)
			var bl = UIKit.make_button(Locale.t("ux_qi_shu_bow") % c.name, 260)
			var tid2 = c.id
			bl.pressed.connect(func():
				var r = CKTutor.assign(_pupil, tid2)
				_msg.text = str(r.get("msg"))
				_rebuild()
			)
			row2.add_child(bl)
	var promo = UIKit.make_label(Locale.t("ux_qi_shu_promo")); promo.name = "DynPromo"; promo.position = Vector2(520, 420)
	promo.add_theme_color_override("font_color", UIKit.ACCENT); add_child(promo)
	var pv := VBoxContainer.new(); pv.name = "DynPromoList"; pv.position = Vector2(520, 460); pv.add_theme_constant_override("separation", 8); add_child(pv)
	var focus: CKCharacter = GameState.get_leader()
	if focus:
		for jid in CKTutor.promote_list(focus):
			var job = GameState.get_job(jid)
			var b2 = UIKit.make_button(Locale.t("ux_qi_shu_promo_to") % job.get("name", jid), 260)
			b2.pressed.connect(func():
				var r = GameState.try_promote(focus.id, jid)
				_msg.text = str(r.get("msg"))
				Sfx.confirm()
			)
			pv.add_child(b2)
	_msg = UIKit.make_label(""); _msg.name = "DynMsg"; _msg.position = Vector2(40, 520); add_child(_msg)
	var prev = CKTutor.preview(_pupil) if _pupil != "" else {}
	if bool(prev.get("ok", false)):
		_msg.text = str(prev.get("msg", ""))
	var back = UIKit.make_button(Locale.t("btn_back")); back.name = "DynBack"; back.position = Vector2(40, 600)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")); add_child(back)
