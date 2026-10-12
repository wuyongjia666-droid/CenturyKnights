class_name BannerSpec
extends RefCounted
## Compatibility facade over CKHeraldry / CKHeraldryRender.
## Old saves (field/charge/border/emblem) migrate to schema 2 automatically.

const FIELDS := ["solid", "per_fess", "per_pale"]
const CHARGES := ["none", "fess", "pale", "bend", "chevron", "pale_thin"]
const BORDERS := ["none", "line", "double", "dentil"]
const EMBLEMS := ["ring", "arc", "wave", "leaf", "chevron", "spark", "filament", "tide", "notch", "bars", "bend", "hollow"]
const DATA_PATH := "res://assets/art/banner_diy_v93.json"
const HERALDRY_PATH := "res://assets/art/heraldry_v2.json"

static var _data: Dictionary = {}
static var _ready := false

static func _table() -> Dictionary:
	if _ready:
		return _data
	_ready = true
	# Prefer heraldry_v2 (superset); fall back to banner_diy_v93.
	for path in [HERALDRY_PATH, DATA_PATH]:
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				_data = parsed
				break
	return _data

static func palette() -> Array:
	return CKHeraldry.palette() if not CKHeraldry.palette().is_empty() else _table().get("palette", [])

static func color_names() -> Array:
	return CKHeraldry.color_names() if not CKHeraldry.color_names().is_empty() else _table().get("color_names", [])

static var _migration: Dictionary = {}
static var _migration_ready := false

static func _migrate_hex(raw: String) -> String:
	if not _migration_ready:
		_migration_ready = true
		var f := FileAccess.open("res://assets/art/crest_palette_v92.json", FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				_migration = (parsed as Dictionary).get("migration", {})
	var c := str(raw).trim_prefix("#").to_lower()
	return str(_migration.get(c, c))

static func default_spec(field_hex: String = "") -> Dictionary:
	return CKHeraldry.from_crest(field_hex)

static func from_crest(color: String) -> Dictionary:
	return CKHeraldry.from_crest(color)

static func normalize(raw) -> Dictionary:
	return CKHeraldry.normalize(raw)

static func cache_key(spec: Dictionary) -> String:
	return CKHeraldry.cache_key(spec)

static func contrast_ok(spec: Dictionary) -> bool:
	return CKHeraldry.contrast_ok(spec)

static func tincture_ok(spec: Dictionary) -> bool:
	return bool(CKHeraldry.tincture_ok_spec(spec).get("ok", true))

static func compose(spec: Dictionary, w: int = 160, h: int = 220, wave: float = 0.0) -> Image:
	return CKHeraldryRender.compose(spec, w, h, wave, "banner")

static func compose_texture(spec: Dictionary, w: int = 160, h: int = 220, wave: float = 0.0) -> Texture2D:
	return CKHeraldryRender.compose_texture(spec, w, h, wave, "banner")

static func compose_shield(spec: Dictionary, w: int = 128, h: int = 148) -> Image:
	return CKHeraldryRender.compose(spec, w, h, 0.0, "shield")

static func compose_arms(spec: Dictionary, w: int = 180, h: int = 220) -> Image:
	return CKHeraldryRender.compose(spec, w, h, 0.0, "arms")
