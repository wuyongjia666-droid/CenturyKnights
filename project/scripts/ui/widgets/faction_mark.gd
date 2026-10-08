class_name CKFactionMark
extends Control
## 友军圆、敌军三角。颜色走当前色板，形状不依赖颜色。

var team: String = "player"

func _ready() -> void:
	custom_minimum_size = Vector2(44, 44)
	mouse_filter = MOUSE_FILTER_IGNORE

func _draw() -> void:
	var enemy := team == "enemy"
	var col: Color = Frost.swatch("enemy" if enemy else "ally")
	var ink: Color = Frost.swatch("enemy_ink" if enemy else "ally_ink")
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.34
	if enemy:
		var pts := PackedVector2Array([
			c + Vector2(0, -r),
			c + Vector2(r * 0.92, r * 0.78),
			c + Vector2(-r * 0.92, r * 0.78),
		])
		draw_colored_polygon(pts, col)
	else:
		draw_circle(c, r, col)
		draw_arc(c, r + 3.5, 0, TAU, 28, ink, 2.0, true)
