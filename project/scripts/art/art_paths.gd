class_name CKArtPaths
extends RefCounted
## Shipping photographs are lossy WebP next to the old PNG name.
## Farm queues and tests still write PNG, so loaders try WebP first.

static func resolve(path: String) -> String:
	var webp := _webp_sibling(path)
	if webp != "" and _exists_any(webp):
		return webp
	if _exists_any(path):
		return path
	var packed := CKArtPacks.mirror(webp if webp != "" else path)
	if packed == "" and webp != "":
		packed = CKArtPacks.mirror(path)
	if packed != "":
		return packed
	return path


static func exists(path: String) -> bool:
	return _exists_any(resolve(path))


static func load_texture(path: String) -> Texture2D:
	var use := resolve(path)
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
