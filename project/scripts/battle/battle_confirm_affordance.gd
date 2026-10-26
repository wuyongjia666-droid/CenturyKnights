class_name BattleConfirmAffordance
extends RefCounted
## Y1-A T-P16: confirm / cancel affordance and a post-confirm camera that
## lands in the same readable region T-P15 settles into.
##
## The attack plate was a painted chip (often under a thumb) and was not a
## hit target. Landscape confirm/cancel chips are sized in screen pixels.
## While a move or attack preview is latched, sticky slop and unit-drag are
## off so a back-out pan is a pan. Cancel keeps the current camera.
## Post-confirm framing keeps the actor inside the readable inset. The other
## fighter is included only when the actor still fits, so the camera does not
## centre a pair into the info column or the notch lip.


const LANDSCAPE_HIT := 108.0
const TP15_PATH := "res://scripts/battle/battle_action_settle.gd"


static func screen_hit(landscape: bool) -> float:
	var floor := 48.0
	if DeviceProfile.is_mobile():
		floor = maxf(floor, DeviceProfile.hit_px())
	if landscape:
		return maxf(floor, LANDSCAPE_HIT)
	return floor


## Board-local span whose on-screen size is `screen_px` after zoom and root scale.
static func board_span(zoom: float, root_scale: float, screen_px: float) -> float:
	var denom := maxf(0.05, zoom * maxf(root_scale, 0.05))
	return screen_px / denom


## Confirm chip centred on `center`, clamped into `bounds` when the board is known.
## Cancel sits to its left, or above when the left chip would leave the board.
static func chip_pair(center: Vector2, span: float, bounds: Rect2 = Rect2()) -> Dictionary:
	var confirm := Rect2(center - Vector2(span, span) * 0.5, Vector2(span, span))
	if bounds.size.x > span + 1.0 and bounds.size.y > span + 1.0:
		var x := clampf(confirm.position.x, bounds.position.x, bounds.end.x - span)
		var y := clampf(confirm.position.y, bounds.position.y, bounds.end.y - span)
		confirm.position = Vector2(x, y)
	var gap := maxf(8.0, span * 0.12)
	var left := Rect2(confirm.position - Vector2(span + gap, 0.0), confirm.size)
	var above := Rect2(Vector2(confirm.position.x, confirm.position.y - span - gap), confirm.size)
	var cancel := left
	if bounds.size.x > 8.0 and not bounds.encloses(left) and bounds.encloses(above):
		cancel = above
	if cancel.intersects(confirm):
		cancel = above
	return {"confirm": confirm, "cancel": cancel}


static func preview_latched(host) -> bool:
	if host == null:
		return false
	var move = host.get("preview_move_cell")
	if move is Vector2i and (move as Vector2i).x >= 0:
		return true
	var atk = host.get("preview_attack_ui")
	if atk != null and int(atk) >= 0:
		return true
	return BattleSkillHealPreview.latched(host)


## Latched preview: base slop only. Sticky ×1.55 was turning a back-out drag into a tap.
static func suppress_sticky(host) -> bool:
	return preview_latched(host)


## Mobile confirm owns the readable inset. Desktop keeps the T-P13 follow path.
static func yields_post_camera(host) -> bool:
	return DeviceProfile.is_mobile()


static func is_cancel_key(event: InputEvent) -> bool:
	if event == null or event.is_echo():
		return false
	if event.is_action_pressed("ui_cancel"):
		return true
	if event is InputEventKey and (event as InputEventKey).pressed:
		return (event as InputEventKey).keycode == KEY_ESCAPE
	return false


## Same readable inset as T-P15 BattleActionSettle.readable_inset.
## Edge band and info blockers are honoured when a later slice stamped them.
static func readable_inset(stage: Rect2, blockers: Array, edge_band: float) -> Rect2:
	var inset := BattleCombatFrame.play_inset(stage, 0.0, 0.0)
	if edge_band > 1.0:
		var shrunk := Rect2(
			inset.position + Vector2(edge_band, edge_band),
			inset.size - Vector2(edge_band, edge_band) * 2.0)
		if shrunk.size.x >= 72.0 and shrunk.size.y >= 72.0:
			inset = shrunk
	for b in blockers:
		if b is Rect2 and (b as Rect2).size.x > 1.0 and (b as Rect2).intersects(inset):
			inset = _cut_blocker(inset, b)
	return inset


static func _cut_blocker(inset: Rect2, block: Rect2) -> Rect2:
	var inter := inset.intersection(block)
	if inter.size.x < 1.0 or inter.size.y < 1.0:
		return inset
	if inter.size.x <= inter.size.y and block.get_center().x >= inset.get_center().x:
		var right := inter.position.x
		return Rect2(inset.position, Vector2(maxf(72.0, right - inset.position.x), inset.size.y))
	if inter.size.x <= inter.size.y:
		var left := inter.end.x
		return Rect2(Vector2(left, inset.position.y), Vector2(maxf(72.0, inset.end.x - left), inset.size.y))
	if block.get_center().y < inset.get_center().y:
		var top := inter.end.y
		return Rect2(Vector2(inset.position.x, top), Vector2(inset.size.x, maxf(72.0, inset.end.y - top)))
	var bot := inter.position.y
	return Rect2(inset.position, Vector2(inset.size.x, maxf(72.0, bot - inset.position.y)))


## Actor stays inside `inset`. `also` is framed with the actor only when that
## still leaves the actor inside. A merged centre that shoves the actor out is rejected.
static func settle_delta(
	origin: Vector2, cell_px: float, actor: Vector2i, also: Array,
	pan: Vector2, zoom: float, inset: Rect2
) -> Vector2:
	if actor.x < 0 or cell_px < 1.0 or inset.size.x < 8.0:
		return Vector2.ZERO
	var actor_delta := BattleCombatFrame.frame_delta(origin, cell_px, [actor], pan, zoom, inset)
	var cells: Array = [actor]
	for c in also:
		if c is Vector2i and (c as Vector2i).x >= 0 and c != actor:
			cells.append(c)
	if cells.size() < 2:
		return actor_delta
	var merged := BattleCombatFrame.frame_delta(origin, cell_px, cells, pan, zoom, inset)
	var actor_fig := BattleCombatFrame.figure_rect(origin, cell_px, actor, pan + merged, zoom)
	if inset.grow(2.0).encloses(actor_fig):
		return merged
	return actor_delta


static func settle_camera(host, actor: Vector2i, also: Array) -> void:
	if actor.x < 0 or host == null:
		return
	# A settle already stamped by T-P15 owns the tween. Do not kill it or add another.
	if _settle_already_owned(host, actor):
		return
	if host.has_meta("ck_unit_drag"):
		host.remove_meta("ck_unit_drag")
	if _hand_to_tp15(host, actor, also):
		return
	_settle_readable(host, actor, also)


static func _settle_already_owned(host, actor: Vector2i) -> bool:
	if not host.has_meta("m_action_settle"):
		return false
	var info = host.get_meta("m_action_settle")
	if not (info is Dictionary):
		return false
	return (info as Dictionary).get("actor", Vector2i(-999, -999)) == actor


static func _hand_to_tp15(host, actor: Vector2i, also: Array) -> bool:
	if not ResourceLoader.exists(TP15_PATH):
		return false
	var scr := load(TP15_PATH) as GDScript
	if scr == null:
		return false
	var cb := Callable(scr, "apply")
	if not cb.is_valid():
		return false
	# T-P15 apply is mobile-only. A desktop no-op must not swallow confirm settle.
	cb.call(host, actor, also)
	if not host.has_meta("m_action_settle"):
		return false
	var info = host.get_meta("m_action_settle")
	if not (info is Dictionary):
		return false
	if (info as Dictionary).get("actor", Vector2i(-999, -999)) != actor:
		return false
	# Mirror the T-P15 stamp so confirm E2E can assert readability without a
	# second tween. Existing m_action_settle still owns the camera.
	host.set_meta("m_confirm_settle", info)
	return true


static func _settle_readable(host, actor: Vector2i, also: Array) -> void:
	var stage: Rect2 = BattlePick._stage_rect(host)
	if stage.size.x < 8.0:
		return
	var inset := readable_inset(stage, _blockers(host), _edge_band(host))
	var origin: Vector2 = host.ORIGIN
	var cell_px := float(host.CELL)
	var pan: Vector2 = host._board_pan
	var zoom := _zoom(host)
	var delta := settle_delta(origin, cell_px, actor, also, pan, zoom, inset)
	host.set_meta("m_confirm_settle", {"delta": delta, "actor": actor, "inset": inset})
	if delta.length_squared() < 0.25:
		BattlePick.cancel_focus_tween(host)
		return
	var saved: Vector2 = host._board_pan
	host._board_pan = pan + delta
	if host.has_method("_clamp_board_pan"):
		host._clamp_board_pan()
	var clamped: Vector2 = host._board_pan
	host._board_pan = saved
	var applied: Vector2 = clamped - saved
	host.set_meta("m_confirm_settle", {"delta": applied, "actor": actor, "inset": inset})
	if applied.length_squared() < 0.25:
		BattlePick.cancel_focus_tween(host)
		return
	BattlePick._apply_focus_pan(host, clamped, true)


static func _blockers(host) -> Array:
	var out: Array = []
	if host.has_meta("m_info_block"):
		var block = host.get_meta("m_info_block")
		if block is Rect2:
			out.append(block)
	return out


static func _edge_band(host) -> float:
	if host.has_meta("m_edge_band"):
		return float(host.get_meta("m_edge_band"))
	return 0.0


static func chips(host) -> Dictionary:
	if not preview_latched(host):
		return {}
	var span := board_span(_zoom(host), _root_scale(host), screen_hit(_landscape(host)))
	var bounds := Rect2()
	if host.has_meta("m_board_area"):
		var area = host.get_meta("m_board_area")
		if area is Rect2:
			bounds = area
	return chip_pair(chip_center(host), span, bounds)


static func chip_center(host) -> Vector2:
	var origin: Vector2 = host.ORIGIN
	var cell_px := float(host.CELL)
	if host.preview_move_cell.x >= 0:
		var gp := origin + Vector2(host.preview_move_cell) * cell_px
		return gp + Vector2(cell_px, cell_px) * 0.5
	var ui := int(host.preview_attack_ui)
	if ui < 0:
		ui = BattleSkillHealPreview.preview_ui(host)
	if ui < 0 or ui >= host.units.size():
		return origin
	var acenter := origin + Vector2(host.units[ui].pos) * cell_px + Vector2(cell_px, cell_px) * 0.5
	var atk := int(host.selected)
	if atk < 0 or atk >= host.units.size():
		return acenter
	var from := origin + Vector2(host.units[atk].pos) * cell_px
	from += Vector2(cell_px * 0.5, cell_px * BattlePick.FIG_FEET)
	return from.lerp(acenter, 0.55)


static func hit(host, screen: Vector2) -> String:
	var pair := chips(host)
	if pair.is_empty() or not host.has_method("_screen_to_local"):
		return ""
	var local := board_local(host, screen)
	var cancel: Rect2 = pair.get("cancel", Rect2())
	var confirm: Rect2 = pair.get("confirm", Rect2())
	if cancel.has_point(local):
		return "cancel"
	if confirm.has_point(local):
		return "confirm"
	return ""


static func consume_tap(host, screen: Vector2) -> bool:
	var which := hit(host, screen)
	if which == "cancel":
		# Layered cancel shares Esc / bar / chip path (preview → mode → select).
		var kind := BattleAttackCancelDepth.step(host)
		return kind != "noop"
	if which != "confirm":
		return false
	if host.preview_move_cell.x >= 0:
		BattleTouchConfirm.confirm_move(host)
		return true
	if int(host.preview_attack_ui) >= 0:
		BattleTouchConfirm.confirm_attack(host)
		return true
	if BattleSkillHealPreview.latched(host):
		return BattleSkillHealPreview.confirm(host)
	return false


## Drop the preview and keep the piece selected. The in-flight follow tween stops
## so cancel does not yank the camera back onto the unit.
static func back_out(host) -> bool:
	if not preview_latched(host):
		return false
	BattlePick.cancel_focus_tween(host)
	BattleTouchConfirm.clear(host, false)
	return true


static func draw(overlay, host, attack_info: Dictionary = {}) -> void:
	if overlay == null:
		return
	var pair := chips(host)
	if pair.is_empty():
		return
	var confirm: Rect2 = pair.get("confirm", Rect2())
	var cancel: Rect2 = pair.get("cancel", Rect2())
	var accent: Color = UIKit.DANGER if int(host.preview_attack_ui) >= 0 else (UIKit.OK if BattleSkillHealPreview.latched(host) else UIKit.ACCENT)
	_plate(overlay, confirm, _confirm_lines(host, attack_info), accent)
	_plate(overlay, cancel, PackedStringArray([Locale.t("shell_4d0b4688")]), Color(0.62, 0.66, 0.72))


static func grow_bar_hits(host) -> void:
	var bar = host.get("_mobile_bar")
	if bar == null or not (bar is Node):
		return
	_grow_one(bar, "ConfirmPrimary", screen_hit(_landscape(host)))
	_grow_one(bar, "ConfirmCancel", screen_hit(false))


static func _grow_one(bar: Node, node_name: String, need: float) -> void:
	var b := bar.find_child(node_name, true, false) as Control
	if b == null:
		return
	var h := maxf(b.custom_minimum_size.y, need)
	var w := maxf(b.custom_minimum_size.x, 48.0)
	b.custom_minimum_size = Vector2(w, h)
	if b.size.y + 0.5 < h:
		b.size.y = h
	if b.size.x + 0.5 < 48.0:
		b.size.x = 48.0


static func _confirm_lines(host, attack_info: Dictionary) -> PackedStringArray:
	var atk = host.get("preview_attack_ui")
	if atk != null and int(atk) >= 0:
		var lines := BattleCombatFrame.chip_lines(attack_info)
		if not lines.is_empty():
			return lines
		return PackedStringArray([Locale.t("ux_confirm_attack")])
	if host.preview_move_cell.x >= 0:
		var c: Vector2i = host.preview_move_cell
		return PackedStringArray([Locale.t("ux_confirm_move"), "%d,%d" % [c.x, c.y]])
	return PackedStringArray()


static func _plate(overlay, rect: Rect2, lines: PackedStringArray, color: Color) -> void:
	if rect.size.x < 1.0:
		return
	overlay.draw_rect(rect, Color(0.05, 0.06, 0.09, 0.88))
	overlay.draw_rect(rect, Color(color, 0.92), false, 3.0)
	if lines.is_empty():
		return
	var font := UIKit.font("bold")
	var fs := int(clampf(rect.size.y / float(maxi(lines.size(), 1)) * 0.42, 14.0, 28.0))
	var block := float(lines.size()) * (float(fs) + 4.0)
	var y := rect.position.y + maxf(4.0, (rect.size.y - block) * 0.5) + float(fs)
	for line in lines:
		overlay.draw_string(
			font, Vector2(rect.position.x + 10.0, y), line,
			HORIZONTAL_ALIGNMENT_LEFT, maxf(8.0, rect.size.x - 16.0), fs, UIKit.TEXT)
		y += float(fs) + 4.0


static func board_local(host, screen: Vector2) -> Vector2:
	var z := _zoom(host)
	return (host._screen_to_local(screen) - host._board_pan) / z


static func _landscape(host) -> bool:
	if host.has_method("_mobile_landscape"):
		return bool(host._mobile_landscape())
	return false


static func _zoom(host) -> float:
	var z = host.get("_board_zoom")
	if z == null:
		return 1.0
	return maxf(0.05, float(z))


static func _root_scale(host) -> float:
	if host is CanvasItem and (host as CanvasItem).is_inside_tree():
		return maxf(0.05, (host as CanvasItem).get_global_transform().get_scale().x)
	var s = host.get("scale")
	if s is Vector2:
		return maxf(0.05, (s as Vector2).x)
	return 1.0
