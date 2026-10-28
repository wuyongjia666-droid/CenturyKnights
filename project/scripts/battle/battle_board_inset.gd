class_name BattleBoardInset
extends RefCounted
## Y1-A fat knife: one playable/readable inset for select → range →
## confirm/cancel → camera → phase/end banners → action settle → select
## focus / CombatFrame follow → attack ForecastPanel park → skill buff/heal
## follow. Range keep and confirm settle used to disagree — range clipped the
## notch lip, confirm chips/settle did not. Action settle / phase banners then
## rebuilt a third inset without the notch. Select focus_cell / focus_follow
## and CombatFrame.follow_cells used the raw stage play inset and could slide
## the figure under the info column or into the notch lip. ForecastPanel._place
## parked against the raw stage and could cover the notch lip or info column.
## Skill buff/heal soft-confirm follow used to reserve the forecast band even
## though no ForecastPanel is shown, shrinking the shared BoardInset for free.
## Land/ghost strike follow used to call follow_cells on a stale
## m_info_block (pre-layout side col), so figures could sit under the
## info column; now refreshes the live MobileSideCol block first.
## Danger focus settle (BattleDangerFeel.after_set) had the same stale
## m_info_block follow; now refreshes before follow_cells too.
## Skill buff/heal soft-confirm arm/_aim had the same stale m_info_block
## follow; now refreshes before follow_cells too.
## AttackAim after_enter / AttackCycle _aim had the same stale m_info_block
## follow; now refreshes before follow_cells too (keeps forecast_band).
## for_host itself now live-refreshes m_info_block from MobileSideCol
## before cutting blockers, so select focus / follow_selected / wait
## handoff / confirm chips cannot pass a stale side-col either.
## Land/ghost/danger/skill/attack callers now share refresh_info_block
## (no private _refresh_info_block copies left).
## Blocker cut used to inflate a 72px floor past the info/notch edge (re-bleed);
## now matches ActionSettle's no-rebleed cut. Pure algebra suites call
## from_parts (same edge+blocker cuts, no host/notch) so ConfirmAffordance /
## ActionSettle.readable_inset share one source.


## Rewrite host.m_info_block from the live MobileSideCol / SideCol rect.
## No-op when host is null or no sized side col is present (algebra hosts).
static func refresh_info_block(host) -> void:
	if host == null:
		return
	var col: Control = null
	if host is Node:
		col = host.get_node_or_null("MobileSideCol") as Control
		if col == null:
			col = host.find_child("MobileSideCol", true, false) as Control
		if col == null:
			col = host.get_node_or_null("SideCol") as Control
	elif host.has_method("get_node_or_null"):
		col = host.get_node_or_null("MobileSideCol") as Control
		if col == null:
			col = host.get_node_or_null("SideCol") as Control
	if col != null and col.size.x > 1.0 and col.size.y > 1.0:
		host.set_meta("m_info_block", Rect2(col.position, col.size))


static func for_host(host, reserve_top: float = -1.0) -> Rect2:
	if host == null:
		return Rect2()
	var stage: Rect2 = BattlePick._stage_rect(host)
	if stage.size.x < 8.0:
		return Rect2()
	refresh_info_block(host)
	var top := reserve_top
	if top < 0.0:
		top = 0.0
		if int(host.get("preview_attack_ui")) >= 0 or bool(host.get("attack_mode")):
			top = BattleCombatFrame.forecast_band(DeviceProfile.is_mobile())
	var inset := from_parts(stage, top, _blockers(host), _edge_band(host))
	return BattleRangePreview.clip_notch(host, inset)


## Pure algebra / no-host path: play inset + edge band + info blockers.
## Same cuts as for_host before clip_notch — ConfirmAffordance / ActionSettle
## readable_inset delegate here so a 72px floor cannot re-bleed past a block.
static func from_parts(
	stage: Rect2, reserve_top: float, blockers: Array, edge_band: float
) -> Rect2:
	if stage.size.x < 8.0:
		return Rect2()
	var inset := BattleCombatFrame.play_inset(stage, maxf(0.0, reserve_top), 0.0)
	inset = _cut_edge(inset, edge_band)
	for b in blockers:
		if b is Rect2 and (b as Rect2).size.x > 1.0 and (b as Rect2).intersects(inset):
			inset = _cut_blocker(inset, b)
	return inset


static func _edge_band(host) -> float:
	if host != null and host.has_meta("m_edge_band"):
		return float(host.get_meta("m_edge_band"))
	return 0.0


static func _blockers(host) -> Array:
	var out: Array = []
	if host != null and host.has_meta("m_info_block"):
		var block = host.get_meta("m_info_block")
		if block is Rect2:
			out.append(block)
	return out


static func _cut_edge(inset: Rect2, edge_band: float) -> Rect2:
	if edge_band <= 1.0:
		return inset
	var shrunk := Rect2(
		inset.position + Vector2(edge_band, edge_band),
		inset.size - Vector2(edge_band, edge_band) * 2.0
	)
	if shrunk.size.x >= 72.0 and shrunk.size.y >= 72.0:
		return shrunk
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
