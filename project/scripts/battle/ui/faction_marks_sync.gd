extends RefCounted
## Keeps faction corner marks in sync without redrawing when nothing moved.

static func sync(host, units: Array, origin: Vector2, cell: float, prev_sig: String) -> String:
	var sig := "%d|" % units.size()
	for u in units:
		sig += "%s:%d,%d:%d|" % [str(u.team), int(u.pos.x), int(u.pos.y), int(u.char.hp)]
	if sig == prev_sig:
		return prev_sig
	var layer := host.get_node_or_null("FactionMarks") as Control
	if layer == null:
		layer = Control.new()
		layer.name = "FactionMarks"
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		host.add_child(layer)
	while layer.get_child_count() < units.size():
		layer.add_child(UIKit.faction_mark("player"))
	for i in layer.get_child_count():
		var mark := layer.get_child(i) as Control
		if i >= units.size() or units[i].char.hp <= 0:
			mark.visible = false
			continue
		var u = units[i]
		mark.visible = true
		mark.team = "enemy" if str(u.team) == "enemy" else "player"
		mark.queue_redraw()
		var center := origin + Vector2(u.pos) * cell + Vector2(cell * 0.5, cell * 0.5)
		var side := 12.0  # colour-blind shape badge in the cell corner
		mark.custom_minimum_size = Vector2(side, side)
		mark.size = Vector2(side, side)
		mark.position = center + Vector2(cell * 0.5 - side - 3.0, cell * 0.5 - side - 3.0)
	return sig
