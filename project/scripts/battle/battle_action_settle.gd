class_name BattleActionSettle
extends RefCounted
## Y1-A T-P15: camera settle after a move or an attack.
##
## T-P13 frames the preview pair into the play inset and, when the pair is wider
## than that inset, centres the merged bounds. That can slide the acting unit
## under the landscape info column or into the notch lip once the forecast band
## closes. After the action, the actor's own figure must stay inside the
## readable inset. The other fighter is included only when both still fit.


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
	## Cut inset so it no longer intersects block. Never inflate past the cut
	## edge (a 72px floor used to re-bleed into the info column / notch).
	var inter := inset.intersection(block)
	if inter.size.x < 1.0 or inter.size.y < 1.0:
		return inset
	if inter.size.x <= inter.size.y and block.get_center().x >= inset.get_center().x:
		var w: float = inter.position.x - inset.position.x
		if w < 8.0:
			return inset
		return Rect2(inset.position, Vector2(w, inset.size.y))
	if inter.size.x <= inter.size.y:
		var w2: float = inset.end.x - inter.end.x
		if w2 < 8.0:
			return inset
		return Rect2(Vector2(inter.end.x, inset.position.y), Vector2(w2, inset.size.y))
	if block.get_center().y < inset.get_center().y:
		var h: float = inset.end.y - inter.end.y
		if h < 8.0:
			return inset
		return Rect2(Vector2(inset.position.x, inter.end.y), Vector2(inset.size.x, h))
	var h2: float = inter.position.y - inset.position.y
	if h2 < 8.0:
		return inset
	return Rect2(inset.position, Vector2(inset.size.x, h2))


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
	var stage: Rect2 = BattlePick._stage_rect(host)
	if stage.size.x < 8.0:
		return
	var band := float(host.get_meta("m_edge_band", 0.0)) if host.has_meta("m_edge_band") else 0.0
	var blockers: Array = []
	if host.has_meta("m_info_block"):
		var block = host.get_meta("m_info_block")
		if block is Rect2:
			blockers.append(block)
	var inset := readable_inset(stage, blockers, band)
	var origin: Vector2 = host.ORIGIN
	var cell_px := float(host.CELL)
	var pan: Vector2 = host._board_pan
	var zoom := 1.0
	if host.get("_board_zoom") != null:
		zoom = float(host._board_zoom)
	var delta := settle_delta(origin, cell_px, actor, also, pan, zoom, inset)
	host.set_meta("m_action_settle", {"delta": delta, "actor": actor, "inset": inset})
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
	host.set_meta("m_action_settle", {"delta": applied, "actor": actor, "inset": inset})
	if applied.length_squared() < 0.25:
		BattlePick.cancel_focus_tween(host)
		return
	BattlePick._apply_focus_pan(host, clamped, true)
