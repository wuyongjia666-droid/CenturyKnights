class_name CKUnitSilhouette
extends RefCounted
## P3 (route C): read-at-a-glance silhouette parts for board figures + dossier.
## Side:  enemies — rust head wrap (P0 fill already dyes cloth by faction).
## Class: tank — steel helm · cavalry/squire — helm + plume in house colour ·
##        ranger — quiver with fletching · mage — cloth hood · skirmisher — bare head.
## Parts hang on the shared rig bones (root hips spine chest neck head hand.L hand.R …).


static var _to_sk: Transform3D  # model space -> skeleton space for the rig being dressed
static var _sk: Skeleton3D

## Positions/rotations below are MODEL space (metres, +Y up, +Z = facing, rig ≈ 1.85 m),
## converted through the bone's rest pose so parts sit right whatever the bone axes are.
static func apply(n: Node3D, c, team: String) -> void:
	var sk := UnitModel._find_skeleton(n)
	if sk == null or c == null:
		return
	_sk = sk
	_to_sk = _rel(n, sk).affine_inverse()
	var enemy := team == "enemy"
	var role := BattleRules.job_role(str(c.job_id))
	var crest: Color = UnitArt.house_color()
	var side_col := Color.from_hsv(crest.h, 0.55, 0.42) if not enemy else Color(0.42, 0.14, 0.10)
	var head := _att(sk, "head")
	if head and enemy:
		_torus(head, 0.105, 0.125, Vector3(0, 1.74, 0.12), Color(0.55, 0.16, 0.12))
	match role:
		"tank":
			if head:
				_helm(head, Color(0.50, 0.53, 0.58))
		"cavalry":
			if head:
				_helm(head, Color(0.55, 0.57, 0.62))
				_cone(head, 0.05, 0.26, Vector3(0, 1.86, 0.08), Vector3(-25, 0, 0), side_col.lightened(0.25) if not enemy else Color(0.75, 0.2, 0.15))
		"ranger":
			var sp := _att(sk, "spine")
			if sp:
				_cyl(sp, 0.07, 0.50, Vector3(0.10, 1.25, -0.06), Vector3(0, 0, -22), Color(0.40, 0.26, 0.14))
				for i in 3:
					_cyl(sp, 0.010, 0.22, Vector3(0.20 + 0.025 * i, 1.52, -0.06), Vector3(0, 0, -22), Color(0.9, 0.88, 0.8))
		"mage":
			if head:
				_hood(head, side_col.darkened(0.1) if not enemy else Color(0.30, 0.12, 0.30))

static func _rel(root: Node3D, node: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = node
	while cur != null and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t

static func _att(sk: Skeleton3D, bone: String) -> BoneAttachment3D:
	if sk.find_bone(bone) < 0:
		return null
	var nm := "Sil_" + bone.replace(".", "_")
	var ex := sk.get_node_or_null(nm)
	if ex:
		return ex
	var a := BoneAttachment3D.new()
	a.name = nm
	a.bone_name = bone
	sk.add_child(a)
	return a

static func _mat(col: Color, metal: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = 0.75 if metal else 0.0
	m.roughness = 0.35 if metal else 0.85
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.next_pass = UnitModel._outline_mat()
	return m

static func _put(parent: Node3D, mesh: Mesh, pos: Vector3, rot: Vector3, col: Color, metal: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(col, metal)
	var desired := Transform3D(Basis.from_euler(rot * PI / 180.0), pos)
	var rest := Transform3D.IDENTITY
	if parent is BoneAttachment3D and _sk:
		rest = _sk.get_bone_global_rest(_sk.find_bone((parent as BoneAttachment3D).bone_name))
	mi.transform = rest.affine_inverse() * _to_sk * desired
	parent.add_child(mi)
	return mi

static func _box(p: Node3D, sz: Vector3, pos: Vector3, rot: Vector3, col: Color, metal: bool) -> void:
	var b := BoxMesh.new()
	b.size = sz
	_put(p, b, pos, rot, col, metal)

static func _cyl(p: Node3D, r: float, h: float, pos: Vector3, rot: Vector3, col: Color) -> void:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 10
	_put(p, c, pos, rot, col, false)

static func _cone(p: Node3D, r: float, h: float, pos: Vector3, rot: Vector3, col: Color) -> void:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 12
	_put(p, c, pos, rot, col, false)

static func _torus(p: Node3D, ri: float, ro: float, pos: Vector3, col: Color) -> void:
	var t := TorusMesh.new()
	t.inner_radius = ri
	t.outer_radius = ro
	_put(p, t, pos, Vector3.ZERO, col, false)

static func _helm(p: Node3D, col: Color) -> void:
	var s := SphereMesh.new()
	s.radius = 0.118
	s.height = 0.13
	s.is_hemisphere = true
	_put(p, s, Vector3(0, 1.70, 0.12), Vector3.ZERO, col, true)

static func _hood(p: Node3D, col: Color) -> void:
	var s := SphereMesh.new()
	s.radius = 0.135
	s.height = 0.19
	s.is_hemisphere = true
	_put(p, s, Vector3(0, 1.66, 0.10), Vector3(-12, 0, 0), col, false)
