class_name CKBloodFusion
extends RefCounted
## Fusion crowns and congenital limits. Reads a genome CKBloodline already rolled.
## Does not draw, mutate loci, or reorder LOCUS_ORDER.


static func rows() -> Array:
	var raw = CKBloodline.data().get("fusions", [])
	return raw if typeof(raw) == TYPE_ARRAY else []


static func limits() -> Array:
	var raw = CKBloodline.data().get("congenital", [])
	return raw if typeof(raw) == TYPE_ARRAY else []


static func active(c: Object) -> Array:
	if c == null:
		return []
	var out: Array = []
	for row in rows():
		if _fusion_ok(c, row):
			out.append(row)
	return out


static func is_sterile(c: Object) -> bool:
	return not _matching(c, "sterile").is_empty()


static func is_frail(c: Object) -> bool:
	return not _matching(c, "frail").is_empty()


## Only writes when the frail pattern is actually present.
static func apply_birth(child: Object) -> void:
	if child == null or not is_frail(child):
		return
	var cap := maxi(1, int(child.apt_max.get("vit", int(child.stats.get("vit", 8)))) - 2)
	child.apt_max["vit"] = cap
	if int(child.apt_min.get("vit", 1)) > cap:
		child.apt_min["vit"] = cap
	child.stats["vit"] = mini(int(child.stats.get("vit", cap)), cap)


static func _fusion_ok(c: Object, row: Dictionary) -> bool:
	var shown: Array = CKBloodline.royal_nations(c)
	var need := int(row.get("min_copies", 2))
	var purity := float(row.get("min_purity", 0.35))
	var nations: Array = row.get("nations", [])
	if nations.size() < 2:
		return false
	for nid_v in nations:
		var nid := str(nid_v)
		if not (nid in shown):
			return false
		if CKBloodPayoff._purity(c, nid) + 0.0001 < purity:
			return false
		if CKBloodPayoff._copies(c, nid) < need:
			return false
	return true


static func _matching(c: Object, kind: String) -> Array:
	if c == null:
		return []
	var out: Array = []
	for row in limits():
		if str(row.get("kind", "")) != kind:
			continue
		var fusion_id := str(row.get("fusion", ""))
		if fusion_id != "":
			var hit := false
			for f in active(c):
				if str(f.get("id", "")) == fusion_id:
					hit = true
			if not hit:
				continue
		var loci: Array = []
		if str(row.get("locus", "")) != "":
			loci.append(str(row.get("locus", "")))
		for loc in row.get("loci", []):
			loci.append(str(loc))
		var zyg := str(row.get("zygosity", "homozygous"))
		var ok := true
		for loc in loci:
			if zyg == "homozygous" and not _homozygous(c, loc):
				ok = false
				break
		if ok:
			out.append(row)
	return out


static func _homozygous(c: Object, locus: String) -> bool:
	if c.has_method("ensure_genome"):
		c.call("ensure_genome")
	var allele := str(CKBloodline.locus_def(locus).get("royal", ""))
	if allele == "":
		return false
	var g = c.get("genome")
	if typeof(g) != TYPE_DICTIONARY:
		return false
	var dip: Array = CKBloodline._dip(g, locus)
	return dip.size() >= 2 and str(dip[0]) == allele and str(dip[1]) == allele
