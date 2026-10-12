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
			var tr := TextureRect.new()
			tr.texture = CKTerritory.banner_texture(int(FLAG.x), int(FLAG.y))
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.position = Vector2(4, 4)
			tr.size = FLAG
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(tr)
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

## Fills a modal panel (500 wide) with every site hung on the anchor. act(kind, site_id) runs an action.
static func fill_modal(p: Panel, anchor: String, act: Callable) -> void:
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
		y += 122.0
	var close := UIKit.ghost_button(Locale.t("terr_ui_close"), 140, 36)
	close.name = "TerrClose"
	close.position = Vector2(336, p.size.y - 52)
	close.pressed.connect(func(): act.call("close", ""))
	p.add_child(close)
	close.call_deferred("grab_focus")

static func modal_height(anchor: String) -> float:
	return 150.0 + 122.0 * CKTerritory.sites_at(anchor).size()

static func _actions(id: String) -> Array:
	var out: Array = []
	if CKTerritory.owned(id):
		var st := CKTerritory.state(id)
		var why := ""
		if int(st.garrison) >= CKTerritory.garrison_max(id):
			why = Locale.t("terr_ui_full")
		elif GameState.silver < CKTerritory.garrison_cost(id):
			why = Locale.t("terr_ui_silver") % CKTerritory.garrison_cost(id)
		out.append({"kind": "reinforce", "label": Locale.t("terr_ui_reinforce") % CKTerritory.garrison_cost(id), "why": why})
		var swhy := ""
		if bool(st.stockade):
			swhy = Locale.t("terr_st_have")
		elif GameState.silver < CKTerritory.stockade_cost():
			swhy = Locale.t("terr_ui_silver") % CKTerritory.stockade_cost()
		out.append({"kind": "stockade", "label": Locale.t("terr_st_up") % CKTerritory.stockade_cost(), "why": swhy})
		if not (st.threat as Dictionary).is_empty():
			var dwhy := "" if World.pos == str(CKTerritory.site(id).anchor) else Locale.t("terr_ui_go")
			out.append({"kind": "defend", "label": Locale.t("terr_ui_defend"), "why": dwhy})
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
	return {"ok": false, "msg": ""}
