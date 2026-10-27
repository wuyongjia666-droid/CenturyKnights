class_name CKAtlasTerritory
extends RefCounted
## v9.3 territory layer for the atlas: site flags on the nation plate and the site modal.
## Logic stays in CKTerritory; this file only draws and routes presses.

const FLAG := Vector2(26, 36)

## Adds one flag per site of the nation to the node layer. on_press(site_id) opens the modal.
static func add_markers(layer: Control, nation: String, map_size: Vector2, busy: bool, on_press: Callable) -> int:
	var n := 0
	for mk in CKTerritory.map_markers(nation):
		var p := Vector2(float(mk.pos[0]) * map_size.x, float(mk.pos[1]) * map_size.y)
		var b := Button.new()
		b.name = "Site_" + str(mk.id)
		b.flat = true
		b.focus_mode = Control.FOCUS_ALL
		b.disabled = busy
		b.custom_minimum_size = FLAG + Vector2(8, 8)
		b.size = b.custom_minimum_size
		b.position = p - b.size * 0.5
		b.tooltip_text = CKTerritory.summary(str(mk.id))
		var own := str(mk.owner)
		if own == CKTerritory.OWN:
			CKHeraldryField.attach_site_company_banner(b, Vector2(4, 4), FLAG)
		else:
			var col: Color = UIKit.DANGER if own.begins_with("rival:") else UIKit.TEXT_DIM
			var gl := UIKit.title_label(Locale.t("terr_ui_flag"), 15, col)
			gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			gl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			gl.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
			gl.add_theme_constant_override("outline_size", 4)
			gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(gl)
		if bool(mk.threat):
			var ring := ColorRect.new()
			ring.color = Color(UIKit.DANGER, 0.35)
			ring.size = b.size
			ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(ring)
			b.move_child(ring, 0)
			UIFX.breathe(ring, 0.25, 0.9)
		elif bool(mk.get("contest", false)):
			var cring := ColorRect.new()
			cring.name = "ContestRing"
			cring.color = Color(UIKit.EMBER, 0.4)
			cring.size = b.size
			cring.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(cring)
			b.move_child(cring, 0)
			UIFX.breathe(cring, 0.3, 0.85)
		_owner_chip(b, own, int(mk.get("garrison", 0)))
		var sid := str(mk.id)
		b.pressed.connect(func(): on_press.call(sid))
		layer.add_child(b)
		n += 1
	return n

## WS-C #45: owner colour + garrison under each flag, so the plate reads without opening the modal.
static func owner_color(own: String) -> Color:
	if own == CKTerritory.OWN:
		return UIKit.OK
	if own.begins_with("rival:"):
		return UIKit.DANGER
	return UIKit.TEXT_DIM

static func owner_text(own: String, garrison: int) -> String:
	if own == CKTerritory.OWN:
		return Locale.t("wsc_t_own") % garrison
	if own.begins_with("rival:"):
		return Locale.t("wsc_t_rival")
	return Locale.t("wsc_t_free")

static func _owner_chip(b: Button, own: String, garrison: int) -> void:
	var l := UIKit.body_label(owner_text(own, garrison), owner_color(own), 9)
	l.name = "OwnerChip"
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = Vector2(-6, FLAG.y + 6)
	b.add_child(l)

## Owned-site count for the world-view region chip ("" when none).
static func region_badge(nation: String) -> String:
	var k := 0
	for id in CKTerritory.sites_in(nation):
		if CKTerritory.owned(id):
			k += 1
	return "" if k == 0 else " · " + Locale.t("terr_ui_flag") + "%d" % k

## Fills a modal panel with every site hung on the anchor. act(kind, site_id) runs an action.
## Desktop keeps the absolute 500-wide layout; phone uses a Scroll+VBox so FONT_FLOOR cannot crush rows.
static func fill_modal(p: Panel, anchor: String, act: Callable) -> void:
	if DeviceProfile.is_mobile():
		_fill_modal_mobile(p, anchor, act)
		return
	var el := UIKit.mono("TERRITORY // %s" % str(World.node(anchor).get("name", anchor)), 9, UIKit.ACCENT)
	el.position = Vector2(24, 18)
	p.add_child(el)
	var t := UIKit.title_label(Locale.t("terr_ui_title"), 22)
	t.position = Vector2(24, 36)
	p.add_child(t)
	var y := 78.0
	for id in CKTerritory.sites_at(anchor):
		var s := CKTerritory.site(id)
		var lab := UIKit.body_label(CKTerritory.summary(id), UIKit.TEXT, 12)
		lab.position = Vector2(24, y)
		lab.size = Vector2(452, 52)
		p.add_child(lab)
		var lore := UIKit.body_label(str(s.get("lore", "")), UIKit.TEXT_DIM, 10)
		lore.position = Vector2(24, y + 50)
		lore.size = Vector2(452, 28)
		lore.clip_text = true
		p.add_child(lore)
		var row := HBoxContainer.new()
		row.position = Vector2(24, y + 80)
		row.add_theme_constant_override("separation", 6)
		p.add_child(row)
		for spec in _actions(id):
			var b := UIKit.ghost_button(str(spec.label), 108, 30)
			b.name = "Terr_%s_%s" % [spec.kind, id]
			b.disabled = str(spec.why) != ""
			b.tooltip_text = str(spec.why)
			var k := str(spec.kind)
			b.pressed.connect(func(): act.call(k, id))
			row.add_child(b)
		y += 150.0
	_echo_strip(p, Vector2(24, p.size.y - 78), 300.0)
	var close := UIKit.ghost_button(Locale.t("terr_ui_close"), 140, 36)
	close.name = "TerrClose"
	close.position = Vector2(336, p.size.y - 52)
	close.pressed.connect(func(): act.call("close", ""))
	p.add_child(close)
	close.call_deferred("grab_focus")


static func _fill_modal_mobile(p: Panel, anchor: String, act: Callable) -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	p.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	root.add_child(MobilePage.label("TERRITORY // %s" % str(World.node(anchor).get("name", anchor)), UIKit.ACCENT, MobilePage.FONT, false))
	root.add_child(MobilePage.label(Locale.t("terr_ui_title"), UIKit.TEXT, MobilePage.FONT + 6, false))
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	sc.add_child(list)
	for id in CKTerritory.sites_at(anchor):
		var s := CKTerritory.site(id)
		var lab := MobilePage.label(CKTerritory.summary(id), UIKit.TEXT, MobilePage.FONT, true)
		lab.name = "TerrSummary_%s" % id
		list.add_child(lab)
		var lore := MobilePage.label(str(s.get("lore", "")), UIKit.TEXT_DIM, MobilePage.FONT, true)
		list.add_child(lore)
		for spec in _actions(id):
			var b := MobilePage.button(str(spec.label), false, func(): act.call(str(spec.kind), id))
			b.name = "Terr_%s_%s" % [spec.kind, id]
			b.disabled = str(spec.why) != ""
			b.tooltip_text = str(spec.why)
			list.add_child(b)
	_echo_strip(root, Vector2.ZERO, 0.0)
	var close := MobilePage.button(Locale.t("terr_ui_close"), true, func(): act.call("close", ""))
	close.name = "TerrClose"
	root.add_child(close)
	close.call_deferred("grab_focus")


static func modal_height(anchor: String) -> float:
	if DeviceProfile.is_mobile():
		# Phone modal is sized by atlas _modal_panel; give enough room for scroll + close + echo.
		return 560.0 + 40.0 * float(CKTerritory.sites_at(anchor).size())
	# Desktop: site rows + garrison/stockade month-echo strip.
	return 200.0 + 150.0 * CKTerritory.sites_at(anchor).size()

static func _actions(id: String) -> Array:
	var out: Array = []
	if CKTerritory.owned(id):
		var st := CKTerritory.state(id)
		var rprev: Dictionary = CKTerritory.reinforce_preview(id)
		var why := ""
		if bool(rprev.get("full", false)):
			why = Locale.t("terr_ui_full")
		elif bool(rprev.get("short", false)):
			why = Locale.t("terr_ui_silver") % int(rprev.get("cost", 0))
		out.append({"kind": "reinforce", "label": Locale.t("terr_ui_reinforce") % int(rprev.get("cost", CKTerritory.garrison_cost(id))), "why": why})
		var sprev: Dictionary = CKTerritory.stockade_preview(id)
		var swhy := ""
		if bool(sprev.get("have", false)):
			swhy = Locale.t("terr_st_have")
		elif bool(sprev.get("short", false)):
			swhy = Locale.t("terr_ui_silver") % int(sprev.get("cost", 0))
		out.append({"kind": "stockade", "label": Locale.t("terr_st_up") % int(sprev.get("cost", CKTerritory.stockade_cost())), "why": swhy})
		if not (st.threat as Dictionary).is_empty():
			var dwhy := "" if World.pos == str(CKTerritory.site(id).anchor) else Locale.t("terr_ui_go")
			out.append({"kind": "defend", "label": Locale.t("terr_ui_defend"), "why": dwhy})
			out.append({"kind": "intercept", "label": Locale.t("terr_ui_intercept"), "why": dwhy})
			var bwhy := ""
			if bool(st.threat.get("bribed", false)):
				bwhy = Locale.t("terr_55")
			elif GameState.silver < CKTerritory.bribe_cost(id):
				bwhy = Locale.t("terr_ui_silver") % CKTerritory.bribe_cost(id)
			out.append({"kind": "bribe", "label": Locale.t("terr_ui_bribe") % CKTerritory.bribe_cost(id), "why": bwhy})
			var scwhy := ""
			if bool(st.threat.get("scouted", false)):
				scwhy = Locale.t("terr_ui_scouted")
			elif GameState.silver < CKTerritory.scout_cost(id):
				scwhy = Locale.t("terr_ui_silver") % CKTerritory.scout_cost(id)
			out.append({"kind": "scout", "label": Locale.t("terr_ui_scout") % CKTerritory.scout_cost(id), "why": scwhy})
		return out
	var block := CKTerritory.capture_block(id)
	out.append({"kind": "assault", "label": Locale.t("terr_ui_assault"), "why": block})
	out.append({"kind": "chain", "label": Locale.t("terr_ui_chain"), "why": block})
	return out

## Runs an action. Returns {"msg", "ok", "encounter"?}.
static func run(kind: String, id: String) -> Dictionary:
	match kind:
		"assault":
			return CKTerritory.assault(id)
		"chain":
			return CKTerritory.post_chain(id)
		"reinforce":
			return CKTerritory.reinforce(id)
		"stockade":
			return CKTerritory.build_stockade(id)
		"defend":
			return CKTerritory.defend(id)
		"intercept":
			return CKTerritory.intercept(id)
		"bribe":
			return CKTerritory.bribe_threat(id)
		"scout":
			return CKTerritory.scout_threat(id)
	return {"ok": false, "msg": ""}

## Territory fat: month echo strip for garrison/stockade/sister/muster/convoy/contest/reclaim/defend/assault/chain/bribe/scout E2E (EchoLine_*).
static func _echo_strip(parent: Node, pos: Vector2, width: float) -> void:
	var rows := CKEconomyState.month_echo_lines()
	var terr_rows: Array = []
	for row in rows:
		var k := str(row.get("kind", ""))
		if k == "garrison" or k == "stockade" or k == "sister" or k == "muster" or k == "convoy" or k == "contest" or k == "reclaim" or k == "defend" or k == "assault" or k == "chain" or k == "bribe" or k == "scout":
			terr_rows.append(row)
	if terr_rows.is_empty():
		return
	var stacked := parent is BoxContainer or parent is ScrollContainer
	var y := pos.y
	var head := UIKit.mono(Locale.t("terr_echo_head"), 9, UIKit.ACCENT, false)
	if not stacked:
		head.position = pos
	parent.add_child(head)
	y += 16.0
	for row in terr_rows:
		var line := UIKit.body_label(str(row.get("text", "")), UIKit.OK, 12)
		line.name = "EchoLine_%s" % str(row.get("kind", "x"))
		if not stacked:
			line.position = Vector2(pos.x, y)
			line.size = Vector2(width, 20)
		parent.add_child(line)
		y += 18.0

