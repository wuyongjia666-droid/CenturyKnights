extends Node
## P2 §3.9: dim (acted) + flash (hit) shader params on board figures.

func _ready() -> void:
	await get_tree().process_frame
	var err := _run()
	if err != "":
		print("FAIL board feedback: ", err)
		get_tree().quit(1)
		return
	print("BOARD FEEDBACK PASS")
	get_tree().quit(0)

func _run() -> String:
	GameState.new_game("棋子", "霜旗", UIKit.ACCENT.to_html(false))
	var leader = GameState.get_leader()
	var root := CKBoardFigure.build(leader, "player")
	if root == null:
		return "build null"
	add_child(root)
	CKBoardFigure.apply_feedback(root, true, 0.0)
	if not _any_param(root, "dim_amt", 1.0):
		return "dim_amt not set on materials"
	CKBoardFigure.apply_feedback(root, false, 1.0)
	if not _any_param(root, "flash_amt", 1.0):
		return "flash_amt not set"
	CKBoardFigure.apply_feedback(root, false, 0.0)
	if _any_param(root, "dim_amt", 1.0):
		return "dim not cleared"
	if _any_param(root, "flash_amt", 1.0):
		return "flash not cleared"
	var ship := FileAccess.get_file_as_string("res://shaders/board_figure_ship.gdshader")
	if "0.60 * dim_amt" not in ship:
		return "ship shader missing desat dim"
	if "flash_amt" not in ship:
		return "ship shader missing flash_amt"
	return ""

func _any_param(n: Node, key: String, want: float) -> bool:
	if n is GeometryInstance3D:
		var gi := n as GeometryInstance3D
		var mats: Array = []
		if gi.material_override is ShaderMaterial:
			mats.append(gi.material_override)
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh != null:
			var mi := gi as MeshInstance3D
			for si in mi.mesh.get_surface_count():
				var m = mi.get_surface_override_material(si)
				if m is ShaderMaterial:
					mats.append(m)
		for m2 in mats:
			var v = (m2 as ShaderMaterial).get_shader_parameter(key)
			if v != null and is_equal_approx(float(v), want):
				return true
	for ch in n.get_children():
		if _any_param(ch, key, want):
			return true
	return false
