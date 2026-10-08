class_name DeployMinimap
extends Control

var map_id: String = ""


func _draw() -> void:
	var m: Dictionary = BattleMaps.get_map(map_id)
	var grid = m.get("terrain", [])
	if typeof(grid) != TYPE_ARRAY or grid.is_empty():
		return
	var rows: int = int(grid.size())
	var cols: int = 1
	if typeof(grid[0]) == TYPE_ARRAY:
		cols = maxi(1, grid[0].size())
	var cell := minf(size.x / float(cols), size.y / float(rows))
	for y in rows:
		var row = grid[y]
		if typeof(row) != TYPE_ARRAY:
			continue
		for x in mini(cols, row.size()):
			draw_rect(Rect2(Vector2(x, y) * cell, Vector2(cell - 1.0, cell - 1.0)), _tint(str(row[x])))
	_mark_spots(m.get("player_spots", []), UIKit.OK, cell)
	_mark_spots(m.get("enemy_spots", []), UIKit.DANGER, cell)


func _mark_spots(spots, col: Color, cell: float) -> void:
	if typeof(spots) != TYPE_ARRAY:
		return
	for s in spots:
		if typeof(s) != TYPE_ARRAY or s.size() < 2:
			continue
		var p := Vector2(int(s[0]), int(s[1])) * cell
		draw_rect(Rect2(p + Vector2(2, 2), Vector2(cell - 5.0, cell - 5.0)), Color(col, 0.9))


func _tint(tid: String) -> Color:
	match tid:
		"forest":
			return Color(UIKit.OK, 0.55)
		"hill":
			return Color(UIKit.ACCENT, 0.55)
		"fort":
			return Color(UIKit.TEXT, 0.45)
		"water":
			return Color(UIKit.ACCENT, 0.28)
		"road":
			return Color(UIKit.TEXT_DIM, 0.7)
		_:
			return Color(UIKit.TEXT_FAINT, 0.28)
