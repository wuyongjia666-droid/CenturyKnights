extends Node
func _ready():
	for path in ["res://assets/models/board/pathc_weapons/sword.glb","res://assets/models/board/pathc_weapons/bow.glb","res://assets/models/board/pathc_weapons/axe.glb","res://assets/models/board/pathc_weapons/spear.glb"]:
		print("=== ", path, " exists=", ResourceLoader.exists(path))
		var ps = load(path)
		if ps == null:
			print("LOAD FAIL")
			continue
		var n = ps.instantiate()
		_walk(n, 0)
	get_tree().quit(0)
func _walk(n, d):
	if n == null: return
	var ind = " ".repeat(d)
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		print(ind, "MI ", mi.name, " surfs=", mi.mesh.get_surface_count() if mi.mesh else -1)
		if mi.mesh:
			print(ind, " aabb=", mi.mesh.get_aabb())
		for i in range(mi.mesh.get_surface_count() if mi.mesh else 0):
			var m = mi.get_active_material(i)
			print(ind, " mat", i, " ", m)
			if m is BaseMaterial3D:
				var bm := m as BaseMaterial3D
				print(ind, "  albedo ", bm.albedo_color, " tex=", bm.albedo_texture, " metal=", bm.metallic)
	for c in n.get_children():
		_walk(c, d+1)
