class_name CKBattleSwatch
extends Control
## 色板预览用的棋盘切片。正式战斗棋子由 battle 流改调 UIKit.faction_mark。

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var p := Frost.palette()
	draw_rect(Rect2(Vector2.ZERO, size), p["bg"])
	var cols := 8
	var rows := 4
	var pad := 18.0
	var top := 56.0
	var avail := Vector2(maxf(8.0, size.x - pad * 2.0), maxf(8.0, size.y - top - 16.0))
	var cell_size := minf(avail.x / float(cols), avail.y / float(rows))
	var grid := Rect2(Vector2((size.x - cell_size * float(cols)) * 0.5, top), Vector2(cell_size * float(cols), cell_size * float(rows)))
	var cw := cell_size
	var ch := cell_size
	for y in rows:
		for x in cols:
			var tile := Rect2(grid.position + Vector2(x * cw, y * ch), Vector2(cw, ch)).grow(-3)
			var danger := x >= 5 and y <= 2
			var fill: Color = p["panel"]
			if danger:
				fill = p["enemy"]
				fill.a = 0.22
			draw_rect(tile, fill)
			var stroke: Color = p["accent"]
			stroke.a = 0.18
			draw_rect(tile, stroke, false, 1.0)
	_piece(grid, cw, ch, 2, 2, false)
	_piece(grid, cw, ch, 6, 1, true)
	draw_rect(Rect2(16, 12, size.x - 32, 36), p["panel"])
	# title is a child label; the bar is only chrome

func _piece(grid: Rect2, cw: float, ch: float, x: int, y: int, enemy: bool) -> void:
	var origin := grid.position + Vector2((float(x) + 0.5) * cw, (float(y) + 0.5) * ch)
	var r := minf(cw, ch) * 0.28
	var col: Color = Frost.swatch("enemy" if enemy else "ally")
	if enemy:
		var pts := PackedVector2Array([
			origin + Vector2(0, -r),
			origin + Vector2(r, r * 0.8),
			origin + Vector2(-r, r * 0.8),
		])
		draw_colored_polygon(pts, col)
	else:
		draw_circle(origin, r, col)
		draw_arc(origin, r + 4.0, 0, TAU, 28, Color(1, 1, 1, 0.85), 2.0, true)
