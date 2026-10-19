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
	var n_mats := _count_shader_mats(root)
	if n_mats < 1:
		return "no ShaderMaterial on figure (got %d)" % n_mats
	CKBoardFigure.apply_feedback(root, true, 0.0)
	var dim_hit := _count_param(root, "dim_amt", 1.0)
	if dim_hit < n_mats:
		return "dim_amt set on %d/%d ShaderMaterials" % [dim_hit, n_mats]
	CKBoardFigure.apply_feedback(root, false, 1.0)
	var flash_hit := _count_param(root, "flash_amt", 1.0)
	if flash_hit < n_mats:
		return "flash_amt set on %d/%d ShaderMaterials" % [flash_hit, n_mats]
	CKBoardFigure.apply_feedback(root, false, 0.0)
	if _count_param(root, "dim_amt", 1.0) > 0:
		return "dim not cleared"
	if _count_param(root, "flash_amt", 1.0) > 0:
		return "flash not cleared"
	var ship := FileAccess.get_file_as_string("res://shaders/board_figure_ship.gdshader")
	if "0.60 * dim_amt" not in ship:
		return "ship shader missing desat dim"
	if "flash_amt" not in ship:
		return "ship shader missing flash_amt"
	var kit := FileAccess.get_file_as_string("res://shaders/board_figure.gdshader")
	if "flash_amt" not in kit:
		return "kit shader missing flash_amt"
	# .res uniqueness (Qwen #1)
	var seen := {}
	for arch in UnitModel.ANIM_ARCHETYPES:
		var path := "res://assets/models/anim/%s.res" % arch
		var bytes := FileAccess.get_file_as_bytes(path)
		if bytes.is_empty():
			return "missing " + arch
		var h := bytes.get_string_from_utf8()  # not a hash; use size+first bytes via sha
		var key := str(bytes.size()) + ":" + str(bytes[0]) + ":" + str(bytes[bytes.size()-1]) + ":" + str(bytes[min(100, bytes.size()-1)])
		# Better: use hash
		var hh := 0
		for i in range(0, bytes.size(), 17):
			hh = (hh * 131 + int(bytes[i])) & 0x7fffffff
		if seen.has(hh):
			return "anim res hash collide %s vs %s" % [arch, seen[hh]]
		seen[hh] = arch
	return ""

func _count_shader_mats(n: Node) -> int:
	var c := 0
	if n is GeometryInstance3D:
		var gi := n as GeometryInstance3D
		if gi.material_override is ShaderMaterial:
			c += 1
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh != null:
			var mi := gi as MeshInstance3D
			for si in mi.mesh.get_surface_count():
				if mi.get_surface_override_material(si) is ShaderMaterial:
					c += 1
	for ch in n.get_children():
		c += _count_shader_mats(ch)
	return c

func _count_param(n: Node, key: String, want: float) -> int:
	var c := 0
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
				c += 1
	for ch in n.get_children():
		c += _count_param(ch, key, want)
	return c
