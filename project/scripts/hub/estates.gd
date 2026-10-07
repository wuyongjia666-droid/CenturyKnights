extends Control
## 属地庄园：单堡多属地 · 庄头委任 · 产出预览 · 劫掠提示（美术升档图标）

var _msg: Label
var _list: VBoxContainer
var _picker_hid: String = ""
var _picker: PanelContainer

func _ready() -> void:
	UIKit.make_themed_bg(self, "estates")
	UIFX.page_enter(self)
	UIFX.fade_in(self, 0.28)
	Music.play_castle()
	# 顶栏美术条
	var strip = TextureRect.new()
	strip.texture = load("res://assets/art/ui/hub_banner_strip.png")
	strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	strip.stretch_mode = TextureRect.STRETCH_SCALE
	strip.position = Vector2(0, 0)
	strip.size = Vector2(1280, 48)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)

	var t = UIKit.make_label("属地庄园", true)
	t.position = Vector2(40, 16)
	add_child(t)
	var tip = UIKit.make_dim_label("陆桥四野：苇原渡、石垒坡、雾谷药田、断潮渡哨。委任庄头加深月结并抗劫掠；升级加深产出。堡志「庄头遍野」与此挂钩。")
	tip.position = Vector2(40, 56)
	tip.custom_minimum_size = Vector2(1180, 40)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(tip)

	var sum = UIKit.make_label(_sum_text())
	sum.position = Vector2(40, 100)
	sum.add_theme_color_override("font_color", UIKit.ACCENT)
	sum.name = "Sum"
	add_child(sum)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(40, 140)
	scroll.custom_minimum_size = Vector2(1200, 460)
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_list)
	_rebuild()
	UIFX.stagger_children(_list, 0.05, 0.26)

	_msg = UIKit.make_label("")
	_msg.position = Vector2(40, 620)
	_msg.custom_minimum_size = Vector2(1000, 30)
	add_child(_msg)
	var back = UIKit.make_button(Locale.t("btn_back"), 120)
	back.position = Vector2(40, 660)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn"))
	add_child(back)
	var works = UIKit.make_button("去工事/堡志", 140)
	works.position = Vector2(180, 660)
	works.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/works.tscn"))
	add_child(works)
	var patrol = UIKit.make_accent_button("全堡巡防", 140)
	patrol.position = Vector2(340, 660)
	patrol.pressed.connect(_do_patrol)
	add_child(patrol)
	var picon = TextureRect.new()
	if ResourceLoader.exists("res://assets/art/ui/patrol_icon.png"):
		picon.texture = load("res://assets/art/ui/patrol_icon.png")
		picon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picon.custom_minimum_size = Vector2(36, 36)
		picon.position = Vector2(490, 662)
		picon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(picon)

func _sum_text() -> String:
	var stewards = 0
	for hid in GameState.holdings.keys():
		if str(GameState.holdings[hid].get("steward_id", "")) != "":
			stewards += 1
	var extra = ""
	if int(GameState.patrol_boost_months) > 0:
		extra += "　巡防中(%d月)" % int(GameState.patrol_boost_months)
	elif int(GameState.patrol_cooldown) > 0:
		extra += "　巡防冷却(%d)" % int(GameState.patrol_cooldown)
	if int(GameState.estate_quiet_months) > 0:
		extra += "　安静%d月" % int(GameState.estate_quiet_months)
	return "已开垦 %d / 4　总等级 %d　庄头 %d%s" % [
		GameState.unlocked_holdings_count(), GameState.total_holding_levels(), stewards, extra]

func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	for hid in GameState.HOLDING_DEFS.keys():
		var def: Dictionary = GameState.HOLDING_DEFS[hid]
		var unlocked = GameState.holding_unlocked(hid)
		var lv = GameState.holding_level(hid)
		var card = UIKit.make_panel()
		card.custom_minimum_size = Vector2(1160, 0)
		_list.add_child(card)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 14)
		card.add_child(hb)

		# 属地图标
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(72, 72)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var ip = "res://assets/art/estates/%s.png" % hid
		if ResourceLoader.exists(ip):
			icon.texture = load(ip)
		hb.add_child(icon)

		var vb := VBoxContainer.new()
		vb.custom_minimum_size = Vector2(720, 0)
		hb.add_child(vb)
		var title = UIKit.make_label("%s　%s" % [def.name, ("Lv%d / 3" % lv) if unlocked else "未开垦"])
		title.add_theme_color_override("font_color", UIKit.ACCENT if unlocked else UIKit.TEXT_DIM)
		vb.add_child(title)
		vb.add_child(UIKit.make_dim_label(str(def.desc)))

		if unlocked:
			var pv = GameState.holding_yield_preview(hid)
			var y = "预览月结：粮+%d 银+%d" % [int(pv.food), int(pv.silver)]
			if int(pv.get("herb", 0)) > 0:
				y += " 药+%d" % int(pv.herb)
			if int(pv.get("rep", 0)) > 0:
				y += " 声望"
			if bool(pv.get("steward", false)):
				y += "　[庄头加产]"
				if int(pv.get("trait_bonus", 0)) > 0:
					y += "　[能干+%d]" % int(pv.trait_bonus)
			else:
				y += "　[无庄头·易遭劫掠]"
			if GameState.holding_patrol_boost(hid) > 0:
				y += "　[路线巡防%d月]" % GameState.holding_patrol_boost(hid)
			var yrow := HBoxContainer.new()
			yrow.add_theme_constant_override("separation", 6)
			vb.add_child(yrow)
			for chip_k in ["grain", "silver"]:
				var cp = "res://assets/art/ui/month_chip_%s.png" % chip_k
				if ResourceLoader.exists(cp):
					var ctr := TextureRect.new()
					ctr.texture = load(cp)
					ctr.custom_minimum_size = Vector2(28, 28)
					ctr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					ctr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					yrow.add_child(ctr)
			yrow.add_child(UIKit.make_dim_label(y))
			var st = GameState.steward_of(hid)
			if st != null:
				vb.add_child(UIKit.make_label("庄头：%s（%s）" % [st.name, st.job_id]))
			else:
				vb.add_child(UIKit.make_dim_label("庄头：空缺 — 委任后月结+1档并抗劫"))
			if lv < 3:
				vb.add_child(UIKit.make_dim_label("升级需：%d银 / %d粮" % [40 * lv, 8 * lv]))
			var foc = GameState.holding_focus(hid)
			var foc_cn = {"grain": "粮作", "cash": "钱作", "fortify": "戍卫"}.get(foc, foc)
			var foc_row := HBoxContainer.new()
			foc_row.add_theme_constant_override("separation", 8)
			vb.add_child(foc_row)
			var ficon = TextureRect.new()
			var icon_path = "res://assets/art/ui/estate_focus_%s.png" % foc
			if ResourceLoader.exists(icon_path):
				ficon.texture = load(icon_path)
				ficon.custom_minimum_size = Vector2(28, 28)
				ficon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				ficon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				foc_row.add_child(ficon)
			foc_row.add_child(UIKit.make_dim_label("经营偏向：%s（改作10银/冷却2月）" % foc_cn))
			var fbtns := HBoxContainer.new()
			fbtns.add_theme_constant_override("separation", 6)
			vb.add_child(fbtns)
			for fk in ["grain", "cash", "fortify"]:
				var flab = {"grain": "粮作", "cash": "钱作", "fortify": "戍卫"}[fk]
				var fb = UIKit.make_button(flab, 72)
				fb.disabled = (fk == foc)
				var capt_h = hid
				var capt_f = fk
				fb.pressed.connect(func():
					UIFX.press_feedback(fb)
					var rr = GameState.set_holding_focus(capt_h, capt_f)
					_msg.text = str(rr.get("msg"))
					if rr.get("ok"):
						UIFX.confirm_burst(fb)
						Sfx.confirm()
						GameState.save_game()
						_rebuild()
						var sum2 = get_node_or_null("Sum")
						if sum2: sum2.text = _sum_text()
				)
				fbtns.add_child(fb)
		else:
			vb.add_child(UIKit.make_dim_label("完成委任「%s」首通后开垦" % str(def.get("quest", ""))))

		var bid = hid
		var btn_col := VBoxContainer.new()
		btn_col.add_theme_constant_override("separation", 6)
		hb.add_child(btn_col)
		if unlocked and lv < 3:
			var b = UIKit.make_accent_button("升级属地", 140)
			b.pressed.connect(func(): _upgrade(bid))
			btn_col.add_child(b)
		elif unlocked:
			var b2 = UIKit.make_button("满级", 100)
			b2.disabled = true
			btn_col.add_child(b2)
		else:
			var b3 = UIKit.make_button("未开垦", 100)
			b3.disabled = true
			btn_col.add_child(b3)
		if unlocked:
			var bs = UIKit.make_button("委任庄头", 140)
			bs.pressed.connect(func(): _open_picker(bid))
			btn_col.add_child(bs)
			if GameState.steward_of(bid) != null:
				var bc = UIKit.make_button("撤庄头", 100)
				bc.pressed.connect(func(): _clear_steward(bid))
				btn_col.add_child(bc)
			var pb = UIKit.make_accent_button("巡此路线", 140)
			if GameState.holding_patrol_cd(bid) > 0:
				pb.text = "冷却%d月" % GameState.holding_patrol_cd(bid)
				pb.disabled = true
			elif GameState.holding_patrol_boost(bid) > 0:
				pb.text = "巡防中%d" % GameState.holding_patrol_boost(bid)
			pb.pressed.connect(func(): _do_patrol_one(bid))
			btn_col.add_child(pb)

func _upgrade(hid: String) -> void:
	var r = GameState.upgrade_holding(hid)
	_msg.text = str(r.get("msg", ""))
	if r.get("ok"):
		Sfx.confirm()
		GameState.save_game()
		get_node("Sum").text = _sum_text()
		_rebuild()
	else:
		Sfx.miss()

func _clear_steward(hid: String) -> void:
	GameState.clear_steward(hid)
	GameState.save_game()
	_msg.text = "已撤下庄头"
	Sfx.confirm()
	get_node("Sum").text = _sum_text()
	_rebuild()

func _open_picker(hid: String) -> void:
	_picker_hid = hid
	if _picker != null and is_instance_valid(_picker):
		_picker.queue_free()
	_picker = UIKit.make_panel()
	_picker.position = Vector2(320, 120)
	_picker.custom_minimum_size = Vector2(640, 480)
	add_child(_picker)
	var title = UIKit.make_label("选择庄头 — %s" % GameState.HOLDING_DEFS[hid].name, true)
	title.position = Vector2(16, 12)
	_picker.add_child(title)
	var tip = UIKit.make_dim_label("花名册存活成员；一人仅可管一处属地。")
	tip.position = Vector2(16, 48)
	_picker.add_child(tip)
	var sc := ScrollContainer.new()
	sc.position = Vector2(16, 80)
	sc.custom_minimum_size = Vector2(600, 340)
	_picker.add_child(sc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	sc.add_child(vb)
	for c in GameState.roster():
		if c == null or not c.alive:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		vb.add_child(row)
		var tex = UnitArt.portrait(c, 48)
		var tr = TextureRect.new()
		tr.custom_minimum_size = Vector2(48, 48)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if tex != null:
			tr.texture = tex
		row.add_child(tr)
		var lab = UIKit.make_label("%s　%s　Lv%d" % [c.name, c.job_id, c.level])
		lab.custom_minimum_size = Vector2(320, 0)
		row.add_child(lab)
		var cid = c.id
		var bb = UIKit.make_accent_button("委任", 80)
		bb.pressed.connect(func(): _do_assign(cid))
		row.add_child(bb)
	var close = UIKit.make_button("关闭", 100)
	close.position = Vector2(16, 430)
	close.pressed.connect(func():
		if _picker != null and is_instance_valid(_picker):
			_picker.queue_free()
			_picker = null
	)
	_picker.add_child(close)

func _do_assign(cid: String) -> void:
	var r = GameState.assign_steward(_picker_hid, cid)
	_msg.text = str(r.get("msg", ""))
	if r.get("ok"):
		Sfx.confirm()
		GameState.save_game()
		get_node("Sum").text = _sum_text()
		if _picker != null and is_instance_valid(_picker):
			_picker.queue_free()
			_picker = null
		_rebuild()
	else:
		Sfx.miss()

func _do_patrol() -> void:
	var r = GameState.patrol_holdings()
	_msg.text = str(r.get("msg", ""))
	if r.get("ok"):
		Sfx.confirm()
		GameState.save_game()
		get_node("Sum").text = _sum_text()
		_rebuild()
		_show_patrol_vignette("")
	else:
		Sfx.miss()

func _do_patrol_one(hid: String) -> void:
	var r = GameState.patrol_holding(hid)
	_msg.text = str(r.get("msg", ""))
	if r.get("ok"):
		Sfx.confirm()
		GameState.save_game()
		get_node("Sum").text = _sum_text()
		_rebuild()
		_show_patrol_vignette(hid)
	else:
		Sfx.miss()

func _show_patrol_vignette(hid: String) -> void:
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 30
	add_child(overlay)
	var panel = UIKit.make_panel()
	panel.position = Vector2(320, 140)
	panel.custom_minimum_size = Vector2(640, 400)
	overlay.add_child(panel)
	var title = UIKit.make_label("巡防沙盘" + ((" · " + str(GameState.HOLDING_DEFS.get(hid, {}).get("name", ""))) if hid != "" else " · 四野全线"), true)
	title.position = Vector2(16, 12)
	panel.add_child(title)
	var map = TextureRect.new()
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map.position = Vector2(16, 48)
	map.custom_minimum_size = Vector2(600, 280)
	panel.add_child(map)
	var frames: Array = []
	for fi in range(12):
		var fp = "res://assets/art/ui/patrol_vignette_f%d.png" % fi
		if ResourceLoader.exists(fp):
			frames.append(load(fp))
	if frames.is_empty() and ResourceLoader.exists("res://assets/art/ui/patrol_vignette.png"):
		frames.append(load("res://assets/art/ui/patrol_vignette.png"))
	if not frames.is_empty():
		map.texture = frames[0]
		var anim_i := [0]
		var tw = get_tree().create_timer(0.12)
		# 顺序播帧
		for step in range(1, frames.size()):
			var capture_step = step
			get_tree().create_timer(0.12 * capture_step).timeout.connect(func():
				if is_instance_valid(map) and capture_step < frames.size():
					map.texture = frames[capture_step]
			)
	if hid != "" and ResourceLoader.exists("res://assets/art/ui/patrol_mark_%s.png" % hid):
		var mark = TextureRect.new()
		mark.texture = load("res://assets/art/ui/patrol_mark_%s.png" % hid)
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.custom_minimum_size = Vector2(48, 48)
		# approximate mark positions matching art
		var pos_map = {"reed_ford": Vector2(120, 200), "stone_slope": Vector2(320, 100), "fog_vale": Vector2(480, 180), "tide_bridge": Vector2(280, 260)}
		var mp: Vector2 = pos_map.get(hid, Vector2(300, 180))
		mark.position = Vector2(16, 48) + mp - Vector2(24, 24)
		panel.add_child(mark)
	var tip = UIKit.make_dim_label("旗丁已走完路线。本属地劫掠风险大降。")
	tip.position = Vector2(16, 340)
	panel.add_child(tip)
	var close = UIKit.make_accent_button("收起沙盘", 140)
	close.position = Vector2(480, 350)
	close.pressed.connect(func(): overlay.queue_free())
	panel.add_child(close)
	get_tree().create_timer(6.0).timeout.connect(func():
		if is_instance_valid(overlay):
			overlay.queue_free()
	)
