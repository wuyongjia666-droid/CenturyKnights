class_name BattleEdgePick
extends RefCounted
## Y1-A T-P15: notch / gesture-lip body hit.
##
## fit() already shifts the battle root into the display safe rect. Insetting the
## board by that safe rect again would double-shift taps (the T-P1-2 bug). What
## is left is the lip where the board meets the cutout: the OS back-gesture band
## and the chrome strip under a landscape notch. A thumb lands on the first
## pixels it can actually touch. That point sits just outside the figure contour
## (the crown above FIG_TOP, or a sliver beside the torso) even though it is the
## visible body. SOFT_R is measured from the cell centre, so the crown — more
## than 0.90 cells up — still misses. Interior taps must not widen.


const EDGE_BAND_PX := 48.0
## Board edge "faces" the notch when it sits this close to the safe rect.
const FACE_PAD := 96.0
## Extra reach past the contour, in cells. Stays short of the next cell's centre.
const EDGE_EXTRA_CELLS := 0.42


static func facing_lips(safe: Rect2, board: Rect2) -> Dictionary:
	return {
		"left": board.position.x <= safe.position.x + FACE_PAD,
		"right": safe.end.x - board.end.x <= FACE_PAD,
		"top": board.position.y <= safe.position.y + FACE_PAD,
		"bottom": safe.end.y - board.end.y <= FACE_PAD,
	}


## Control-local point in the notch lip of the playfield. Interior of the board
## is not a lip, so a crown tap in the middle of the map still misses.
static func in_edge_band(local: Vector2, safe: Rect2, board: Rect2, band: float) -> bool:
	if band <= 0.0 or safe.size.x < 8.0 or board.size.x < 8.0:
		return false
	if not board.grow(band).has_point(local):
		return false
	if not safe.has_point(local) and safe.grow(band).has_point(local):
		return true
	var lips: Dictionary = facing_lips(safe, board)
	if bool(lips.left) and local.x <= maxf(safe.position.x, board.position.x) + band:
		return true
	if bool(lips.right) and local.x >= minf(safe.end.x, board.end.x) - band:
		return true
	if bool(lips.top) and local.y <= maxf(safe.position.y, board.position.y) + band:
		return true
	if bool(lips.bottom) and local.y >= minf(safe.end.y, board.end.y) - band:
		return true
	return false


static func _sides(local: Vector2, safe: Rect2, board: Rect2, band: float) -> Dictionary:
	var lips: Dictionary = facing_lips(safe, board)
	return {
		"left": bool(lips.left) and local.x <= maxf(safe.position.x, board.position.x) + band,
		"right": bool(lips.right) and local.x >= minf(safe.end.x, board.end.x) - band,
		"top": bool(lips.top) and local.y <= maxf(safe.position.y, board.position.y) + band,
		"bottom": bool(lips.bottom) and local.y >= minf(safe.end.y, board.end.y) - band,
	}


## `local_board` is unscaled board space. `local_ctrl` is control-local so the
## lip stays a physical thumb width after pan/zoom. Returns invalid off the lip.
static func edge_body_pos(
	origin: Vector2, cell_px: float, units: Array,
	local_board: Vector2, local_ctrl: Vector2,
	safe_ctrl: Rect2, board_ctrl: Rect2, band: float, zoom: float, half_w: float
) -> Vector2i:
	if not DeviceProfile.is_mobile():
		return Vector2i(-1, -1)
	if cell_px < 1.0 or not in_edge_band(local_ctrl, safe_ctrl, board_ctrl, band):
		return Vector2i(-1, -1)
	var z := zoom if zoom > 0.001 else 1.0
	var extra := minf(EDGE_EXTRA_CELLS, (band / z) / cell_px)
	var sides: Dictionary = _sides(local_ctrl, safe_ctrl, board_ctrl, band)
	var lx := (local_board.x - origin.x) / cell_px
	var ly := (local_board.y - origin.y) / cell_px
	var best := Vector2i(-1, -1)
	var best_d := 1.0e12
	for u in units:
		if int(u.char.hp) <= 0:
			continue
		var col := float(u.pos.x)
		var row := float(u.pos.y)
		var fig_left := col + 0.5 - half_w
		var fig_right := col + 0.5 + half_w
		var fig_top := row + BattlePick.FIG_TOP
		var fig_bot := row + BattlePick.FIG_FEET
		var hit := false
		if bool(sides.left) and lx >= fig_left - extra and lx < fig_left:
			hit = ly >= fig_top and ly <= fig_bot
		elif bool(sides.right) and lx <= fig_right + extra and lx > fig_right:
			hit = ly >= fig_top and ly <= fig_bot
		elif bool(sides.top) and ly >= fig_top - extra and ly < fig_top:
			hit = lx >= fig_left and lx <= fig_right
		elif bool(sides.bottom) and ly <= fig_bot + extra and ly > fig_bot:
			hit = lx >= fig_left and lx <= fig_right
		if not hit:
			continue
		var feet := Vector2(col + 0.5, fig_bot)
		var d := feet.distance_squared_to(Vector2(lx, ly))
		if d < best_d:
			best_d = d
			best = u.pos
	return best


static func note_layout(host) -> void:
	var sz: Vector2 = host.size if host.size.x > 8.0 else Vector2(1280.0, 720.0)
	host.set_meta("m_touch_safe", Rect2(Vector2.ZERO, sz))
	host.set_meta("m_edge_band", EDGE_BAND_PX)
	var stage: Rect2 = BattlePick._stage_rect(host)
	var col := host.get_node_or_null("MobileSideCol") as Control
	if col != null and stage.size.x > 8.0 and col.position.x < stage.end.x - 1.0:
		var gap := 6.0
		var room := sz.x - stage.end.x - gap
		col.position.x = stage.end.x + gap
		if room > 120.0:
			col.size.x = minf(col.size.x, room)
	var block := Rect2()
	if col != null:
		block = Rect2(col.position, col.size)
	host.set_meta("m_info_block", block)
	_open_card(host)
	if col != null:
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE


static func _open_card(host) -> void:
	var card = host.get("_unit_card")
	if card != null and card.has_method("landscape_readable"):
		card.landscape_readable()
	var info = host.get("info_label")
	if info is RichTextLabel:
		var rtl := info as RichTextLabel
		rtl.fit_content = true
		rtl.scroll_active = false
		rtl.clip_contents = false
		rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var h := rtl.get_content_height()
		if h > 8.0:
			rtl.custom_minimum_size.y = maxf(rtl.custom_minimum_size.y, h)
	var log = host.get("log_label")
	if log is Label and host.get_node_or_null("MobileSideCol") != null:
		var lab := log as Label
		lab.clip_text = false
		lab.max_lines_visible = -1
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pass_board_taps(host.get_node_or_null("MobileSideCol"))


## Non-button chrome must not eat a tap meant for the board. Skill buttons stay STOP.
## T-P24: ScrollContainer itself was left STOP and stole board taps wherever the
## portrait/info column overlapped the stage — IGNORE the column, keep button children.
static func _pass_board_taps(n: Node) -> void:
	if n == null:
		return
	if n is BaseButton:
		return
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in n.get_children():
		_pass_board_taps(ch)


static func press_in_band(host, screen_pos: Vector2) -> bool:
	if not DeviceProfile.is_mobile() or not host.has_meta("m_touch_safe"):
		return false
	var safe: Rect2 = host.get_meta("m_touch_safe")
	var board: Rect2 = BattlePick._stage_rect(host)
	if board.size.x < 8.0:
		return false
	var ctrl: Vector2 = host._screen_to_local(screen_pos)
	var band := float(host.get_meta("m_edge_band", EDGE_BAND_PX))
	return in_edge_band(ctrl, safe, board, band)


static func from_host(host, screen_pos: Vector2, local_board: Vector2) -> Vector2i:
	if not DeviceProfile.is_mobile() or not host.has_meta("m_touch_safe"):
		return Vector2i(-1, -1)
	var safe: Rect2 = host.get_meta("m_touch_safe")
	var board: Rect2 = BattlePick._stage_rect(host)
	if board.size.x < 8.0 or not host.has_method("_screen_to_local"):
		return Vector2i(-1, -1)
	var ctrl: Vector2 = host._screen_to_local(screen_pos)
	var band := float(host.get_meta("m_edge_band", EDGE_BAND_PX))
	var zoom := 1.0
	if host.get("_board_zoom") != null:
		zoom = float(host._board_zoom)
	return edge_body_pos(
		host.ORIGIN, float(host.CELL), host.units,
		local_board, ctrl, safe, board, band, zoom, BattlePick.contour_half_w())
