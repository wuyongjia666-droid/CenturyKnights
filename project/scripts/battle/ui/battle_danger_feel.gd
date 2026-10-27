class_name BattleDangerFeel
extends RefCounted
## Y1-A T-P19 — danger focus feel: settle the board pan on the focused foe and
## the player cells they threaten; paint stands softer than strike so the
## wash reads like a threat ring rather than a flat blob.
## BoardInset: refresh m_info_block from MobileSideCol before follow_cells
## so danger settle shares notch+info+edge (same as ActionSettle / land/ghost).

const SETTLE_PAD := 1
const STRIKE_A := 0.38
const STAND_A := 0.18


## After danger_on / danger_focus flips — frame focused foe + threatened allies.
static func after_set(host) -> void:
	if not bool(host.danger_on):
		return
	var focus := int(host.danger_focus)
	if focus < 0 or focus >= host.units.size():
		return
	var foe = host.units[focus]
	if str(foe.team) != "enemy" or foe.char.hp <= 0:
		return
	var layers: Dictionary = DangerZone.layers_for_unit(host, foe)
	var cells: Array = [foe.pos]
	for i in host.units.size():
		var u = host.units[i]
		if str(u.team) != "player" or u.char.hp <= 0:
			continue
		if layers.strike.has(u.pos) or layers.stands.has(u.pos):
			cells.append(u.pos)
	if cells.size() == 1:
		for d in [Vector2i(SETTLE_PAD, 0), Vector2i(-SETTLE_PAD, 0), Vector2i(0, SETTLE_PAD), Vector2i(0, -SETTLE_PAD)]:
			cells.append(foe.pos + d)
	# Refresh live info column so BoardInset cuts the same chrome as
	# ActionSettle / land-ghost follow (stale m_info_block left figures under the side col).
	BattleBoardInset.refresh_info_block(host)
	BattleCombatFrame.follow_cells(host, cells, 0.0)


## Layered wash: stands faint, strike brighter. Colorblind keeps the hatch.
static func draw(host, overlay) -> void:
	if not bool(host.danger_on) or overlay == null:
		return
	var layers: Dictionary = DangerZone.collect_layers(host)
	var stands: Dictionary = layers.stands
	var strike: Dictionary = layers.strike
	var hatch := bool(GameState.settings.get("colorblind", false))
	var focus := int(host.danger_focus)
	var base := UIKit.DANGER
	if focus >= 0:
		base = Color(base.r, clampf(base.g * 0.7, 0.0, 1.0), clampf(base.b * 1.15, 0.0, 1.0))
	for cell in stands.keys():
		_paint_cell(host, overlay, cell, Color(base, STAND_A), hatch)
	for cell in strike.keys():
		if stands.has(cell):
			continue
		_paint_cell(host, overlay, cell, Color(base, STRIKE_A), hatch)


static func _paint_cell(host, overlay, cell: Vector2i, fill: Color, hatch: bool) -> void:
	var r := Rect2(host.ORIGIN + Vector2(cell) * host.CELL, Vector2(host.CELL - 2, host.CELL - 2))
	overlay.draw_rect(r, fill)
	if hatch:
		overlay.draw_line(r.position, r.position + r.size, Color(UIKit.DANGER, 0.9), 1.5)
		overlay.draw_line(r.position + Vector2(0, r.size.y), r.position + Vector2(r.size.x, 0), Color(UIKit.DANGER, 0.9), 1.5)
