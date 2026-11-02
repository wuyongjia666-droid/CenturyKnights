class_name CKOnDemandArt
extends RefCounted
## Store on-demand scaffold (Android base pack).
## Large / master / small genome plates and speaker/expression larges are deferred
## via export_presets exclude_filter; this helper always resolves through the
## medium fallback chain in CKArtPaths so UI never silently goes blank.
## Contract JSON (repo root, CI-owned): docs/store/ondemand-assets.json
## Year2 PAD/CDN download is intentionally out of scope here.

const FALLBACK_TIER := CKArtPaths.TIER_MEDIUM
const MANIFEST_REL := "docs/store/ondemand-assets.json"

## Bank master + small patterns deferred on Android (must match exclude_filter).
const ANDROID_DEFERRED_BANK := [
	"assets/art/portraits/genome/bank/*_????????????????.webp",
	"assets/art/portraits/genome/bank/*.small.webp",
]


static func resolve_pack_safe(path: String, preferred_tier: String = "") -> String:
	var tier := preferred_tier
	if tier == "":
		tier = FALLBACK_TIER
	# Prefer the ask, then CKArtPaths medium/large/small fallthrough.
	return CKArtPaths.resolve_portrait(path, tier)


static func load_pack_safe(path: String, preferred_tier: String = "") -> Texture2D:
	var tier := preferred_tier
	if tier == "":
		tier = FALLBACK_TIER
	return CKArtPaths.load_portrait(path, tier)


static func unit_plate(path: String) -> String:
	## Unit UI always ships medium on both platforms.
	return CKArtPaths.resolve_unit_plate(path)


static func manifest_path() -> String:
	var path := ProjectSettings.globalize_path("res://").path_join("../" + MANIFEST_REL)
	if FileAccess.file_exists(path):
		return path
	# Editor sometimes globalizes res:// without trailing slash semantics.
	var alt := ProjectSettings.globalize_path("res://../" + MANIFEST_REL)
	return alt if FileAccess.file_exists(alt) else path


static func manifest_exists() -> bool:
	return FileAccess.file_exists(manifest_path())


static func load_manifest() -> Dictionary:
	var path := manifest_path()
	if not FileAccess.file_exists(path):
		return {}
	var raw := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed as Dictionary


static func asserts_android_deferred_bank_in(joined_excludes: String) -> String:
	for needle in ANDROID_DEFERRED_BANK:
		if not joined_excludes.contains(str(needle)):
			return "missing deferred bank exclude: " + str(needle)
	return ""
