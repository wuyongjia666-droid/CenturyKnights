class_name BattleActionSettle
extends RefCounted
## Y1-A T-P15 + BoardInset fat: camera settle after a move or an attack.
##
## T-P13 frames the preview pair into the play inset and, when the pair is wider
## than that inset, centres the merged bounds. That can slide the acting unit
## under the landscape info column or into the notch lip once the forecast band
## closes. After the action, the actor's own figure must stay inside the shared
## BoardInset (notch + info + edge) — same rect as range keep / confirm settle.
## Pure `readable_inset(stage, …)` stays for algebra suites without a host —
## delegates to BoardInset.from_parts (same no-rebleed cut as live for_host).


static func readable_inset(stage: Rect2, blockers: Array, edge_band: float) -> Rect2:
	return BattleBoardInset.from_parts(stage, 0.0, blockers, edge_band)


## Minimum pan that keeps `actor` readable. `also` is framed with the actor only
## when the actor's figure is still inside afterwards.
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


static func apply(host, actor: Vector2i, also: Array) -> void:
	if not DeviceProfile.is_mobile():
		return
	if host.has_meta("ck_unit_drag"):
		return
	if actor.x < 0:
		return
	# Refresh live info column so BoardInset cuts the same chrome as
	# confirm settle / range keep (T-P15 used to rebuild blockers here and
	# skip the notch lip — banners and action settle then framed into a
	# different rect than confirm chips).
	var col := host.get_node_or_null("MobileSideCol") as Control
	if col == null:
		col = host.find_child("MobileSideCol", true, false) as Control
	if col == null:
		col = host.get_node_or_null("SideCol") as Control
	var block := Rect2()
	if col != null and col.size.x > 1.0 and col.size.y > 1.0:
		block = Rect2(col.position, col.size)
		host.set_meta("m_info_block", block)
	var inset := BattleBoardInset.for_host(host, 0.0)
	if inset.size.x < 8.0:
		return
	var origin: Vector2 = host.ORIGIN
	var cell_px := float(host.CELL)
	var pan: Vector2 = host._board_pan
	var zoom := 1.0
	if host.get("_board_zoom") != null:
		zoom = float(host._board_zoom)
	var delta := settle_delta(origin, cell_px, actor, also, pan, zoom, inset)
	host.set_meta("m_action_settle", {"delta": delta, "actor": actor, "inset": inset, "block": block})
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
	host.set_meta("m_action_settle", {"delta": applied, "actor": actor, "inset": inset, "block": block})
	if applied.length_squared() < 0.25:
		BattlePick.cancel_focus_tween(host)
		return
	BattlePick._apply_focus_pan(host, clamped, true)
