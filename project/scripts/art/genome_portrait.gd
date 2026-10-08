class_name CKGenomePortrait
extends RefCounted
## v8.9: ONE full Qwen portrait per unit (no paper-doll layering).
const DIR := "res://assets/art/portraits/genome/"
const USER_DIR := "user://genome_portrait_cache/"
static var _mem: Dictionary = {}

static func genome_seed(c: Object) -> int:
	var g: Dictionary = {}
	if c.get("genome") != null and typeof(c.get("genome")) == TYPE_DICTIONARY:
		g = c.get("genome") as Dictionary
	return maxi(1, hash(JSON.stringify(g)) & 0x7fffffff)

static func cache_key(c: Object) -> String:
	if c.has_method("ensure_genome"):
		c.call("ensure_genome")
	var g: Dictionary = {}
	if typeof(c.get("genome")) == TYPE_DICTIONARY:
		g = c.get("genome") as Dictionary
	var blood: Dictionary = {}
	if typeof(c.get("blood_mix")) == TYPE_DICTIONARY:
		blood = c.get("blood_mix") as Dictionary
	var age_i: int = int(c.get("age"))
	var age_band: String = "young"
	if age_i >= 45:
		age_band = "elder"
	elif age_i >= 18:
		age_band = "adult"
	var scars: Array = []
	if typeof(c.get("scars")) == TYPE_ARRAY:
		scars = c.get("scars") as Array
	var honors: Array = []
	if typeof(c.get("honors")) == TYPE_ARRAY:
		honors = c.get("honors") as Array
	var payload: Dictionary = {
		"g": g,
		"blood": blood,
		"sex": str(c.get("gender")),
		"age_band": age_band,
		"job": str(c.get("job_id")),
		"scars": scars,
		"honors": honors,
	}
	var h: int = hash(JSON.stringify(payload)) & 0x7fffffff
	return "%08x" % h

static func texture(c: Object) -> Texture2D:
	var key: String = cache_key(c)
	if _mem.has(key):
		return _mem[key] as Texture2D
	var path: String = DIR + key + ".png"
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path) as Texture2D
		_mem[key] = tex
		return tex
	var up: String = USER_DIR + key + ".png"
	if FileAccess.file_exists(up):
		var img: Image = Image.load_from_file(up)
		if img != null:
			var tex2: ImageTexture = ImageTexture.create_from_image(img)
			_mem[key] = tex2
			return tex2
	return null

static func clear_mem() -> void:
	_mem.clear()
