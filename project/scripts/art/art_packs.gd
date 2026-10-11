class_name CKArtPacks
extends RefCounted
## On-demand art. Files stay at full WebP quality in the repo. The base
## export excludes them; a shipped build finds the same relative path under
## a pack root next to the executable or in user://packs/.

const GENE_BANK := "gene-bank"
const PACKS := {
	"res://assets/art/portraits/genome/bank/": GENE_BANK,
}


static func roots(pack_id: String) -> PackedStringArray:
	var out: PackedStringArray = []
	out.append(ProjectSettings.globalize_path("user://packs/%s" % pack_id))
	var exe := OS.get_executable_path().get_base_dir()
	out.append(exe.path_join("packs").path_join(pack_id))
	return out


static func mirror(res_path: String) -> String:
	if not res_path.begins_with("res://"):
		return ""
	for prefix in PACKS.keys():
		if not res_path.begins_with(str(prefix)):
			continue
		var rel := res_path.trim_prefix("res://")
		var pack_id := str(PACKS[prefix])
		for root in roots(pack_id):
			var abs_path := root.path_join(rel)
			if FileAccess.file_exists(abs_path):
				return abs_path
	return ""


static func gene_bank_dir() -> String:
	for root in roots(GENE_BANK):
		var dir := root.path_join("assets/art/portraits/genome/bank")
		if DirAccess.dir_exists_absolute(dir):
			return dir
	return ""
