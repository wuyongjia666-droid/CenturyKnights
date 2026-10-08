extends Node
## CUT-04: ten royal signatures, projectile meshes, no GPU particles on the low tier.

func _ready() -> void:
	var err: String = _run()
	if err != "":
		print("FAIL vfx: ", err)
		get_tree().quit(1)
	else:
		print("VFX PASS")
		get_tree().quit(0)

func _run() -> String:
	var table := CutsceneTimeline.royal_table()
	if table.size() != 10:
		return "royal count %d" % table.size()
	var seen := {}
	for id in table.keys():
		var spec := CutsceneSignature.signature_for(str(id), "")
		if spec.is_empty():
			return "missing %s" % str(id)
		if str(spec.get("id", "")) != str(id):
			return "id mismatch %s" % str(id)
		var by_name := CutsceneSignature.signature_for("", str(table[id].get("name", "")))
		if str(by_name.get("id", "")) != str(id):
			return "name mismatch %s" % str(id)
		if not (spec.get("tint") is Color):
			return "tint %s" % str(id)
		var tint: Color = spec.get("tint")
		if tint.r > 0.95 and tint.g < 0.7 and tint.b < 0.4:
			return "warm fill %s" % str(id)
		seen[str(id)] = true
		if bool(spec.get("sparks", false)) and str(id) != "kiln_reforge":
			return "sparks on %s" % str(id)
	if seen.size() != 10:
		return "seen %d" % seen.size()
	if not bool(CutsceneSignature.signature_for("kiln_reforge", "").get("sparks", false)):
		return "kiln sparks"
	var host := Node3D.new()
	add_child(host)
	for id in CutsceneSignature.royal_ids():
		CutsceneSignature.spawn_signature(host, Vector3.ZERO, str(id), "", 0.0)
	CutsceneSignature.spawn_projectile(host, Vector3(-1, 1, 0), Vector3(1, 1, 0), "arrow", CutsceneSignature.FROST, 0.0)
	CutsceneSignature.spawn_projectile(host, Vector3(-1, 1, 0), Vector3(1, 1, 0), "bolt", CutsceneSignature.MINT, 0.0)
	if _count_class(host, "GPUParticles3D") != 0:
		return "gpu particles on low"
	if _count_class(host, "CPUParticles3D") != 0:
		return "cpu particles spawned at scale 0"
	var arrow_meshes := _meshes_of(host, "arrow")
	if arrow_meshes < 4:
		return "arrow meshes %d" % arrow_meshes
	var bolt_meshes := _meshes_of(host, "bolt")
	if bolt_meshes < 3:
		return "bolt meshes %d" % bolt_meshes
	return ""

func _count_class(n: Node, want: String) -> int:
	var nfound := 0
	if n.is_class(want):
		nfound += 1
	for ch in n.get_children():
		nfound += _count_class(ch, want)
	return nfound

func _meshes_of(host: Node, kind: String) -> int:
	for ch in host.get_children():
		if ch.has_meta("vfx_kind") and str(ch.get_meta("vfx_kind")) == kind:
			return _count_class(ch, "MeshInstance3D")
	return 0
