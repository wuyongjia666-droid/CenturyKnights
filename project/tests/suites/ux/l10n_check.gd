extends Node
## UX-03: English shell has no CJK on the menu, settings, castle, and battle HUD.
## Missing keys fall back to zh_CN and never echo the key. The i18n ratchet drops by >= 800.

const BEFORE := 3005

var _fails: Array = []
var _scene_name := ""

func _ready() -> void:
	await get_tree().process_frame
	_fallback()
	_ratchet()
	GameState.new_game("Ash", "Ash", GameState.crest_color)
	if GameState.settings is Dictionary:
		GameState.settings["tutorial_highlight"] = false
	Locale.set_lang("en")
	await _scan("res://scenes/ui/main_menu.tscn")
	await _scan("res://scenes/ui/settings.tscn")
	await _scan("res://scenes/hub/castle_hub.tscn")
	await _scan("res://scenes/battle/battle.tscn")
	if _fails.is_empty():
		print("L10N PASS")
		get_tree().quit(0)
	else:
		for item in _fails:
			print("FAIL l10n: ", item)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)

func _fallback() -> void:
	Locale.set_lang("en")
	Locale._zh["l10n_probe"] = "仅中文"
	Locale._en["l10n_probe"] = ""
	var got := Locale.t("l10n_probe")
	_ok(got == "仅中文", "empty en returned %s" % got)
	var missing := Locale.t("l10n_missing_key_zz")
	_ok(missing != "l10n_missing_key_zz", "missing key echoed %s" % missing)
	_ok(not missing.contains("l10n_missing"), "missing key leaked %s" % missing)
	_ok(Locale.has_cjk(missing), "missing key was not zh_CN: %s" % missing)

func _ratchet() -> void:
	var output: Array = []
	var code := OS.execute("python3", ["../tools/ci/i18n_ratchet.py"], output, true)
	var text := "\n".join(output)
	_ok(code == 0 and text.contains("I18N RATCHET PASS"), "ratchet exit %s" % code)
	var literals := -1
	for line in text.split("\n"):
		var at := line.find("literals=")
		if at >= 0:
			literals = int(line.substr(at + 9).strip_edges())
	_ok(literals >= 0, "ratchet did not print literals")
	_ok(BEFORE - literals >= 800, "ratchet drop %s (now %s)" % [BEFORE - literals, literals])

func _scan(path: String) -> void:
	_scene_name = path.get_file()
	var packed := load(path) as PackedScene
	_ok(packed != null, "missing %s" % path)
	if packed == null:
		return
	var node := packed.instantiate()
	add_child(node)
	await get_tree().process_frame
	await get_tree().process_frame
	_walk(node)
	node.queue_free()
	await get_tree().process_frame

func _walk(node: Node) -> void:
	if node is OptionButton:
		var menu := node as OptionButton
		for i in menu.item_count:
			_check(str(menu.get_item_text(i)), "%s item %d" % [node.name, i])
	if node is Label or node is Button or node is RichTextLabel:
		_check(str(node.get("text")), str(node.name))
	for child in node.get_children():
		_walk(child)

func _check(text: String, where: String) -> void:
	if Locale.has_cjk(text):
		var shown := text.replace("\n", " ")
		if shown.length() > 80:
			shown = shown.substr(0, 80)
		_fails.append("%s %s [%s]" % [_scene_name, where, shown])
