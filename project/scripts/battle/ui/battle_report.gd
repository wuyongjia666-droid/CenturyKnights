class_name BattleReport
extends RefCounted
## Post-action report. Extracted from the battle controller in BTL-01.

static func present(host, win: bool, purse: int, sp_gain: int, exp_before: Dictionary) -> void:
	## v8.6 — Stitch 08_victory / 09_defeat post-action report: full-screen ink veil, giant 胜利/败北 headline,
	## map · round, casualty + rating KPIs, per-unit experience rows (left), spoils (right), archive note, CTAs.
	var col: Color = UIKit.ACCENT if win else UIKit.DANGER
	var layer := CanvasLayer.new()
	layer.layer = 40
	layer.name = "ResultReport"
	host.add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.size = Vector2(1280, 720)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)
	var veil := ColorRect.new()
	veil.color = Color(0.016, 0.02, 0.03, 0.975)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(veil)
	var topl := ColorRect.new()
	topl.color = Color(col, 0.7)
	topl.size = Vector2(1280, 2)
	root.add_child(topl)
	var eb := UIKit.mono("POST-ACTION REPORT // %s // CENTURY KNIGHTS" % ("STAGE CLEARED" if win else "MISSION FAILED"), 9, col, false)
	eb.position = Vector2(42, 22)
	root.add_child(eb)
	var rec := UIKit.tag_chip("ROUND %02d" % maxi(1, host._round_no), col)
	rec.position = Vector2(1238 - rec.get_minimum_size().x, 18)
	root.add_child(rec)
	var big := UIKit.title_label(Locale.t("shell_3d90ba4a") if win else Locale.t("shell_3db26845"), 72, UIKit.TEXT if win else UIKit.DANGER)
	big.position = Vector2(40, 46)
	root.add_child(big)
	var vl := ColorRect.new()
	vl.color = Color(1, 1, 1, 0.12)
	vl.position = Vector2(60 + big.get_minimum_size().x, 62)
	vl.size = Vector2(1, 74)
	root.add_child(vl)
	var hx := 84 + big.get_minimum_size().x
	var mt := UIKit.title_label(Locale.t("shell_94fb60fe") % [host.map_name, maxi(1, host._round_no)], 20, UIKit.TEXT)
	mt.position = Vector2(hx, 74)
	root.add_child(mt)
	var ms := UIKit.mono("OBJECTIVE COMPLETE // ENEMY FIELD FORCE SUPPRESSED" if win else Locale.t("shell_95473687"), 9, UIKit.TEXT_FAINT, false)
	ms.position = Vector2(hx, 108)
	root.add_child(ms)
	var lost := 0
	var tot := 0
	for u in host.units:
		if u.team == "player":
			tot += 1
			if bool(exp_before.get(u.char.id, [0, false])[1]):
				lost += 1
	_kpi_card(root, Rect2(860, 62, 180, 64), "CASUALTY STATUS", Locale.t("shell_743453d5") if lost == 0 else Locale.t("shell_02be2aed") % lost, UIKit.OK if lost == 0 else UIKit.DANGER)
	var grade := "S" if win and lost == 0 and host._round_no <= 6 else ("A" if win and lost == 0 else ("B" if win else "—"))
	_kpi_card(root, Rect2(1052, 62, 186, 64), "COMBAT RATING", "GRADE %s" % grade, col)
	var hl := UIKit.hairline(Color(1, 1, 1, 0.08))
	hl.position = Vector2(42, 156)
	hl.size = Vector2(1196, 1)
	root.add_child(hl)
	# left: unit experience
	UIKit.section_head(root, Vector2(42, 180), Locale.t("shell_894c13a1") if win else Locale.t("shell_50511c53"), "UNIT EXPERIENCE", 680, "%d ACTIVE COMBATANTS" % tot)
	var y := 210.0
	for u in host.units:
		if u.team != "player" or y > 520:
			continue
		var c = u.char
		UIKit.panel_at(root, Rect2(42, y, 680, 80), 8, y == 210.0)
		var pr := UIKit.make_portrait_rect(c, 52)
		pr.position = Vector2(58, y + 14)
		pr.size = Vector2(52, 52)
		pr.custom_minimum_size = Vector2(52, 52)
		root.add_child(pr)
		var nh := HBoxContainer.new()
		nh.position = Vector2(124, y + 14)
		nh.add_theme_constant_override("separation", 8)
		root.add_child(nh)
		nh.add_child(UIKit.title_label(c.name, 16, UIKit.TEXT))
		nh.add_child(UIKit.tag_chip(str(GameState.get_job(c.job_id).get("name", "")), UIKit.ACCENT))
		nh.add_child(UIKit.mono("LV.%02d" % c.level, 10, UIKit.TEXT_FAINT, false))
		var fell := bool(exp_before.get(c.id, [0, false])[1])
		var st := UIKit.body_label((Locale.t("shell_b883c04b") if fell else "HP %d / %d" % [c.hp, c.max_hp]) if win else Locale.t("shell_12e258e0"), UIKit.DANGER if fell else UIKit.TEXT_FAINT, 11)
		st.autowrap_mode = TextServer.AUTOWRAP_OFF
		st.position = Vector2(124, y + 38)
		root.add_child(st)
		var gain := int(c.exp) - int(exp_before.get(c.id, [c.exp, false])[0])
		var gl := UIKit.mono("EXP GAIN", 8, UIKit.TEXT_FAINT, false)
		gl.position = Vector2(700 - gl.get_minimum_size().x, y + 10)
		root.add_child(gl)
		var gv := UIKit.mono("+%d" % gain, 20, UIKit.ACCENT if gain > 0 else UIKit.TEXT_DIM, false)
		gv.position = Vector2(700 - gv.get_minimum_size().x, y + 22)
		root.add_child(gv)
		var bar := UIKit.slim_bar(float(int(c.exp) % 100), 100.0, UIKit.ACCENT if win else UIKit.TEXT_DIM, 576, 3)
		bar.position = Vector2(124, y + 64)
		root.add_child(bar)
		var bl := UIKit.mono("%d / 100 EXP" % (int(c.exp) % 100), 8, UIKit.TEXT_FAINT, false)
		bl.position = Vector2(700 - bl.get_minimum_size().x, y + 50)
		root.add_child(bl)
		y += 88
	# right: spoils
	UIKit.section_head(root, Vector2(752, 180), Locale.t("shell_34f6bccc") if win else Locale.t("shell_bda544ee"), "SPOILS OF VICTORY" if win else "AFTER ACTION", 486, "")
	UIKit.panel_at(root, Rect2(752, 210, 486, 228), 8)
	var spoils: Array = [[Locale.t("shell_946c7148"), Locale.t("shell_28034c74"), "+%d" % purse, UIKit.ACCENT, "DEPOSITED"], [Locale.t("shell_fe3695dc"), Locale.t("shell_1ae08583"), "+8", UIKit.OK, "ACQUIRED"]]
	if sp_gain > 0:
		spoils.append([Locale.t("shell_9c678de1"), Locale.t("shell_ed24d742"), "+%d" % sp_gain, UIKit.ACCENT, "UNLOCKED"])
	if not win:
		spoils = [[Locale.t("shell_acf014bf"), Locale.t("shell_141d265b"), Locale.t("shell_d046ac70"), UIKit.OK, "SAFE"], [Locale.t("shell_b894a8c9"), Locale.t("shell_ea18aad3"), "100%", UIKit.OK, "RESTORED"], [Locale.t("shell_c5134eb1"), Locale.t("shell_a5dfcb81"), Locale.t("shell_e2d53a6d"), UIKit.DANGER, "RETRY"]]
	var sy := 224.0
	for sp in spoils:
		var row := Panel.new()
		row.position = Vector2(766, sy)
		row.size = Vector2(458, 62)
		row.add_theme_stylebox_override("panel", UIKit.flat_box(Color(1, 1, 1, 0.025), Color(1, 1, 1, 0.08), 6))
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(row)
		var n := UIKit.title_label(str(sp[0]), 15, UIKit.TEXT)
		n.position = Vector2(784, sy + 10)
		root.add_child(n)
		var e := UIKit.mono(str(sp[1]), 8, UIKit.TEXT_FAINT, false)
		e.position = Vector2(784, sy + 38)
		root.add_child(e)
		var v := UIKit.mono(str(sp[2]), 20, sp[3], false)
		v.position = Vector2(1208 - v.get_minimum_size().x, sy + 8)
		root.add_child(v)
		var t := UIKit.mono(str(sp[4]), 7, sp[3], false)
		t.position = Vector2(1208 - t.get_minimum_size().x, sy + 40)
		root.add_child(t)
		sy += 70
	UIKit.panel_at(root, Rect2(752, 452, 486, 76), 8)
	var nl := UIKit.mono("STRATEGIC ARCHIVE NOTE", 8, UIKit.TEXT_FAINT, false)
	nl.position = Vector2(768, 464)
	root.add_child(nl)
	var nb := UIKit.body_label(Locale.t("shell_0872a62e") % host.map_name if win else Locale.t("shell_a5dac062"), UIKit.TEXT_DIM, 12)
	nb.position = Vector2(768, 484)
	nb.size = Vector2(456, 36)
	nb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(nb)
	var fl := UIKit.hairline(Color(1, 1, 1, 0.08))
	fl.position = Vector2(42, 600)
	fl.size = Vector2(1196, 1)
	root.add_child(fl)
	var keys := HBoxContainer.new()
	keys.position = Vector2(42, 634)
	keys.add_theme_constant_override("separation", 6)
	root.add_child(keys)
	var back_word := Locale.t("shell_7c9e016b") if host._world_enc else Locale.t("shell_1e62632d")
	for kh in ([["A", Locale.t("shell_22841003")], ["ESC", back_word]] if win else ([["A", back_word]] if host._world_enc else [["A", Locale.t("shell_55cfd979")], ["ESC", Locale.t("shell_1e62632d")]])):
		keys.add_child(UIKit.keycap(str(kh[0])))
		var kl := UIKit.body_label(str(kh[1]), UIKit.TEXT_DIM, 11)
		kl.autowrap_mode = TextServer.AUTOWRAP_OFF
		keys.add_child(kl)
		var gp := Control.new()
		gp.custom_minimum_size = Vector2(12, 0)
		keys.add_child(gp)
	var back_path := str(GameState.get_meta("battle_return", "res://scenes/story/chapter0.tscn")) if (win or host._world_enc) else "res://scenes/story/chapter0.tscn"
	host.set_meta("result_back", back_path)
	if win or host._world_enc:
		var b := UIKit.cta_button(back_word, "A", 220, 48)
		b.position = Vector2(1018, 620)
		b.pressed.connect(func(): host.get_tree().change_scene_to_file(back_path))
		root.add_child(b)
		b.call_deferred("grab_focus")
	else:
		var r := UIKit.cta_button(Locale.t("shell_55cfd979"), "A", 200, 48)
		r.position = Vector2(1038, 620)
		r.pressed.connect(func(): host.get_tree().reload_current_scene())
		root.add_child(r)
		var b2 := UIKit.ghost_button(Locale.t("shell_797d26c9"), 150, 48)
		b2.position = Vector2(874, 620)
		b2.pressed.connect(func(): host.get_tree().change_scene_to_file(back_path))
		root.add_child(b2)
		r.call_deferred("grab_focus")
	UIFX.page_enter(root)

static func _kpi_card(root: Control, r: Rect2, label: String, value: String, col: Color) -> void:
	var p := UIKit.panel_at(root, r, 6)
	p.add_theme_stylebox_override("panel", UIKit.flat_box(Color(1, 1, 1, 0.025), Color(col, 0.4), 6))
	var accent := ColorRect.new()
	accent.color = col
	accent.position = r.position
	accent.size = Vector2(2, r.size.y)
	root.add_child(accent)
	var l := UIKit.mono(label, 8, UIKit.TEXT_FAINT, false)
	l.position = r.position + Vector2(14, 12)
	root.add_child(l)
	var v := UIKit.title_label(value, 16, col)
	v.position = r.position + Vector2(14, 30)
	root.add_child(v)

