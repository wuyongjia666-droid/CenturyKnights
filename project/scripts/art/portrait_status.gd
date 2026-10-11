class_name CKPortraitStatus
extends RefCounted
## Status reads on top of an existing plate. Overlays are farmed RGBA plates
## (docs/art/status-portraits-v92.md). A missing file draws nothing.

const OVERLAY_DIR := "res://assets/art/portraits/status/"
const LASTING_IDS := ["lost_finger", "limp"]


static func active_ids(c: Object) -> PackedStringArray:
	var out: PackedStringArray = []
	if c == null:
		return out
	var traits = c.get("traits")
	if typeof(traits) == TYPE_ARRAY and traits.has("malnourished"):
		out.append("malnourished")
	var wound := _wound_id(c)
	if wound != "":
		out.append(wound)
	elif bool(c.get("injured")):
		out.append("wound_light")
	return out


static func overlay_path(status_id: String) -> String:
	return OVERLAY_DIR + status_id + ".png"


static func attach(host: Control, c: Object, cover: Vector2 = Vector2.ZERO) -> void:
	if host == null:
		return
	var stale: Array[Node] = []
	for child in host.get_children():
		if str(child.name).begins_with("status_"):
			stale.append(child)
	for child in stale:
		host.remove_child(child)
		child.free()
	if c == null:
		return
	var sz := cover
	if sz == Vector2.ZERO:
		sz = host.size
	for status_id in active_ids(c):
		var path := overlay_path(status_id)
		if not CKArtPaths.exists(path):
			continue
		var tex := CKArtPaths.load_texture(path)
		if tex == null:
			continue
		var layer := TextureRect.new()
		layer.name = "status_" + status_id
		layer.texture = tex
		layer.position = Vector2.ZERO
		layer.size = sz
		layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(layer)


static func _wound_id(c: Object) -> String:
	var meta = c.get("blood_meta")
	if typeof(meta) != TYPE_DICTIONARY:
		return ""
	var rec = meta.get("injury", {})
	if typeof(rec) != TYPE_DICTIONARY:
		return ""
	var tier := str(rec.get("tier", ""))
	var wound_id := str(rec.get("id", ""))
	if tier == "lasting" and wound_id in LASTING_IDS:
		return wound_id
	if tier == "light" or tier == "grave" or tier == "lasting":
		return "wound_" + tier
	return ""
