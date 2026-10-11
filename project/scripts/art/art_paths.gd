class_name CKArtPaths
extends RefCounted
## Shipping photographs are lossy WebP next to the old PNG name.
## Farm queues and tests still write PNG, so loaders try WebP first.
## Portrait tiers are siblings built from the sharp plate: foo.small.webp,
## foo.medium.webp, and foo.webp (large, native). Lists use small, dialogue
## uses medium, detail uses large. A missing tier falls through to a larger one.

const TIER_SMALL := "small"
const TIER_MEDIUM := "medium"
const TIER_LARGE := "large"


static func tier_for_display(size: int) -> String:
	if size <= 180:
		return TIER_SMALL
	if size <= 420:
		return TIER_MEDIUM
	return TIER_LARGE


static func resolve(path: String) -> String:
	var webp := _webp_sibling(path)
	if webp != "" and _exists_any(webp):
		return webp
	return path


static func resolve_portrait(path: String, tier: String) -> String:
	for candidate in _tier_candidates(path, tier):
		if _exists_any(candidate):
			return candidate
	return resolve(path)


static func exists(path: String) -> bool:
	return _exists_any(resolve(path))


static func load_texture(path: String) -> Texture2D:
	var use := resolve(path)
	return _load_resolved(use)


static func load_portrait(path: String, tier: String) -> Texture2D:
	return _load_resolved(resolve_portrait(path, tier))


static func _load_resolved(use: String) -> Texture2D:
	var abs := use
	if use.begins_with("res://"):
		abs = ProjectSettings.globalize_path(use)
	if FileAccess.file_exists(abs):
		var img := Image.load_from_file(abs)
		if img != null:
			return ImageTexture.create_from_image(img)
	if use.begins_with("res://") and ResourceLoader.exists(use):
		var tex = load(use)
		if tex is Texture2D:
			return tex
	return null


static func _portrait_stem(path: String) -> String:
	var low := path.to_lower()
	var stem := path
	if low.ends_with(".png") or low.ends_with(".webp") or low.ends_with(".jpg") or low.ends_with(".jpeg"):
		stem = path.substr(0, path.rfind("."))
	if stem.ends_with(".small") or stem.ends_with(".medium") or stem.ends_with(".large"):
		stem = stem.substr(0, stem.rfind("."))
	return stem


static func _tier_candidates(path: String, tier: String) -> PackedStringArray:
	var stem := _portrait_stem(path)
	var order: PackedStringArray = PackedStringArray([TIER_LARGE, TIER_MEDIUM, TIER_SMALL])
	if tier == TIER_SMALL:
		order = PackedStringArray([TIER_SMALL, TIER_MEDIUM, TIER_LARGE])
	elif tier == TIER_MEDIUM:
		order = PackedStringArray([TIER_MEDIUM, TIER_LARGE, TIER_SMALL])
	var out: PackedStringArray = []
	for name in order:
		if name == TIER_LARGE:
			out.append(stem + ".webp")
			out.append(stem + ".png")
		else:
			out.append("%s.%s.webp" % [stem, name])
			out.append("%s.%s.png" % [stem, name])
	return out


static func _webp_sibling(path: String) -> String:
	var low := path.to_lower()
	if low.ends_with(".webp"):
		return path
	if low.ends_with(".png") or low.ends_with(".jpg") or low.ends_with(".jpeg"):
		var dot := path.rfind(".")
		return path.substr(0, dot) + ".webp"
	return ""


static func _exists_any(path: String) -> bool:
	if path.begins_with("res://"):
		if ResourceLoader.exists(path):
			return true
		return FileAccess.file_exists(ProjectSettings.globalize_path(path))
	return FileAccess.file_exists(path)
