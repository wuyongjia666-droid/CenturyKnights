class_name BattleDualLedger
extends RefCounted
## Y1-A T-P10 + T-P14: in-battle dual ledger — injured / lamp / ready.
## T-P14 deepen: ready count on player turn + injured foot marks on map.
## Read-only chrome under ObjectiveHud. Never steals InputRouter taps.

const NAME := "BattleDualLedger"
const DESK_AT := Vector2(904, 58)
const DESK_SIZE := Vector2(420, 36)
const INJURED_FOOT_R := 0.18
const INJURED_FOOT_A := 0.42


static func count_injured(units) -> int:
	var n := 0
	if units == null:
		return 0
	for u in units:
		if u == null:
			continue
		var team := str(u.get("team") if typeof(u) == TYPE_DICTIONARY else u.team)
		if team != "player":
			continue
		var alive := true
		if typeof(u) == TYPE_DICTIONARY:
			alive = bool(u.get("alive", true))
		elif "alive" in u:
			alive = bool(u.alive)
		if not alive:
			continue
		var ch = u.get("char") if typeof(u) == TYPE_DICTIONARY else u.char
		if ch == null:
			continue
		var injured := false
		if typeof(ch) == TYPE_DICTIONARY:
			injured = bool(ch.get("injured", false))
		elif "injured" in ch:
			injured = bool(ch.injured)
		if injured:
			n += 1
	return n


## Living undoned player indices (编队待动). Same readiness as formation cycle.
static func count_ready(units) -> int:
	return ready_indices(units).size()


static func ready_indices(units) -> Array[int]:
	var out: Array[int] = []
	if units == null:
		return out
	for i in range(units.size()):
		var u = units[i]
		if typeof(u) != TYPE_DICTIONARY:
			continue
		if str(u.get("team", "")) != "player":
			continue
		if bool(u.get("done", false)):
			continue
		var ch = u.get("char", null)
		var hp := 0
		if typeof(ch) == TYPE_DICTIONARY:
			hp = int(ch.get("hp", 0))
		elif ch != null and "hp" in ch:
			hp = int(ch.hp)
		if hp <= 0:
			continue
		out.append(i)
	return out


## Map cells of living injured players (for foot marks).
static func injured_cells(units) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if units == null:
		return out
	for u in units:
		if u == null:
			continue
		var team := str(u.get("team") if typeof(u) == TYPE_DICTIONARY else u.team)
		if team != "player":
			continue
		var alive := true
		if typeof(u) == TYPE_DICTIONARY:
			alive = bool(u.get("alive", true))
		elif "alive" in u:
			alive = bool(u.alive)
		if not alive:
			continue
		var ch = u.get("char") if typeof(u) == TYPE_DICTIONARY else u.char
		if ch == null:
			continue
		var injured := false
		if typeof(ch) == TYPE_DICTIONARY:
			injured = bool(ch.get("injured", false))
		elif "injured" in ch:
			injured = bool(ch.injured)
		if not injured:
			continue
		var pos = u.get("pos") if typeof(u) == TYPE_DICTIONARY else (u.pos if "pos" in u else null)
		if typeof(pos) == TYPE_VECTOR2I:
			out.append(pos)
		elif typeof(pos) == TYPE_VECTOR2:
			out.append(Vector2i(int(pos.x), int(pos.y)))
	return out


static func lamp_pair(host) -> Vector2i:
	if host == null:
		return Vector2i(0, 0)
	var cur := int(host.get("_lamp_charges")) if host.get("_lamp_charges") != null else 0
	var mx := int(host.get("_lamp_max")) if host.get("_lamp_max") != null else 0
	if mx < 0:
		mx = 0
	if cur < 0:
		cur = 0
	if cur > mx and mx > 0:
		cur = mx
	return Vector2i(cur, mx)


static func line_text(injured: int, charges: int, lamp_max: int) -> String:
	return BattleObjectives.text("dual_ledger_line") % [injured, charges, lamp_max]


static func attach(host: Node) -> void:
	if host.get_node_or_null(NAME) != null:
		refresh(host)
		return
	var panel := Panel.new()
	panel.name = NAME
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.clip_contents = true
	var style := UIKit.glass(10, 0.88)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.shadow_size = 0
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.position = Vector2(10, 6)
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var eye := UIKit.eyebrow(BattleObjectives.text("dual_ledger_eyebrow"), UIKit.ACCENT)
	eye.name = "Eye"
	eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(eye)
	var injured := Label.new()
	injured.name = "Injured"
	injured.mouse_filter = Control.MOUSE_FILTER_IGNORE
	injured.add_theme_font_size_override("font_size", 13)
	injured.add_theme_color_override("font_color", UIKit.DANGER)
	row.add_child(injured)
	var ready := Label.new()
	ready.name = "Ready"
	ready.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ready.add_theme_font_size_override("font_size", 13)
	ready.add_theme_color_override("font_color", UIKit.ACCENT)
	row.add_child(ready)
	var lamp := Label.new()
	lamp.name = "Lamp"
	lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lamp.add_theme_font_size_override("font_size", 13)
	lamp.add_theme_color_override("font_color", UIKit.ACCENT)
	lamp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lamp)
	host.add_child(panel)
	place(host)
	refresh(host)


static func place(host: Node) -> void:
	var hud := host.get_node_or_null(NAME) as Control
	if hud == null:
		return
	if hud.get_parent() != host:
		return
	var insets := _insets(host)
	var top := float(insets.get("top", 0.0))
	var left := float(insets.get("left", 0.0))
	var root := host as Control
	var consumed := true
	if root != null:
		consumed = root.position.y + 0.5 >= top and root.position.x + 0.5 >= left
	if DeviceProfile.is_mobile() and not consumed:
		hud.position = Vector2(left + 12.0, top + 54.0)
		hud.size = Vector2(400, 36)
	else:
		hud.position = DESK_AT
		hud.size = DESK_SIZE
	hud.custom_minimum_size = hud.size
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE


static func refresh(host: Node) -> void:
	var hud := host.get_node_or_null(NAME)
	if hud == null:
		return
	place(host)
	var units = host.units
	var injured_n := count_injured(units)
	var ready_n := count_ready(units)
	var pair := lamp_pair(host)
	var turn := str(host.turn_team) if "turn_team" in host else "player"
	var inj := hud.get_node_or_null("Row/Injured") as Label
	var ready := hud.get_node_or_null("Row/Ready") as Label
	var lamp := hud.get_node_or_null("Row/Lamp") as Label
	if inj:
		inj.text = BattleObjectives.text("dual_ledger_injured") % injured_n
		inj.add_theme_color_override("font_color", UIKit.DANGER if injured_n > 0 else UIKit.TEXT)
	if ready:
		if turn == "player":
			ready.visible = true
			ready.text = BattleObjectives.text("dual_ledger_ready") % ready_n
			ready.add_theme_color_override("font_color", UIKit.ACCENT if ready_n > 0 else UIKit.TEXT)
		else:
			ready.visible = false
	if lamp:
		lamp.text = BattleObjectives.text("dual_ledger_lamp") % [pair.x, pair.y]
	hud.set_meta("injured_n", injured_n)
	hud.set_meta("ready_n", ready_n)
	hud.set_meta("lamp_cur", pair.x)
	hud.set_meta("lamp_max", pair.y)


## Foot discs under living injured players — map-readable dual-ledger deepen.
static func draw_injured_marks(host, overlay: CanvasItem) -> void:
	if host == null or overlay == null:
		return
	var units = host.units
	var cells: Array[Vector2i] = injured_cells(units)
	if cells.is_empty():
		return
	var origin: Vector2 = host.ORIGIN
	var cell_px := float(host.CELL)
	var pan: Vector2 = host._board_pan if "_board_pan" in host else Vector2.ZERO
	var zoom := float(host._board_zoom) if "_board_zoom" in host else 1.0
	if zoom < 0.001:
		zoom = 1.0
	var cpx := cell_px * zoom
	var tone := Color(UIKit.DANGER.r, UIKit.DANGER.g, UIKit.DANGER.b, INJURED_FOOT_A)
	for cell in cells:
		var top_left := origin * zoom + Vector2(cell) * cpx + pan
		var foot := top_left + Vector2(cpx * 0.5, cpx * BattlePick.FIG_FEET)
		var r := cpx * INJURED_FOOT_R
		overlay.draw_circle(foot, r, tone)
		overlay.draw_arc(foot, r, 0.0, TAU, 28, Color(UIKit.DANGER.r, UIKit.DANGER.g, UIKit.DANGER.b, 0.85), 1.5)


static func _insets(host: Node) -> Dictionary:
	if host.has_meta("mobile_insets"):
		var own = host.get_meta("mobile_insets")
		if typeof(own) == TYPE_DICTIONARY:
			return own
	var tree := host.get_tree()
	if tree != null and tree.current_scene != null and tree.current_scene.has_meta("mobile_insets"):
		var shared = tree.current_scene.get_meta("mobile_insets")
		if typeof(shared) == TYPE_DICTIONARY:
			return shared
	return {}
