extends Node
## Mobile type floor: MobileLayout.ensure_min_fonts lifts text to 22px (≈12dp), hides Latin
## spaced-caps kickers, and leaves pages in FONT_FLOOR_PENDING alone.

var _fails: Array = []

func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)

func _ready() -> void:
	_ok(MobileLayout.is_decor_kicker("C E N T U R Y  K N I G H T S "), "kicker spaced caps")
	_ok(MobileLayout.is_decor_kicker("— Q U E U E"), "kicker dash")
	_ok(MobileLayout.is_decor_kicker("//"), "kicker slashes")
	_ok(not MobileLayout.is_decor_kicker("LV1"), "short code stays")
	_ok(not MobileLayout.is_decor_kicker("第 1 年"), "chinese stays")
	var root := Control.new()
	add_child(root)
	var l := Label.new()
	l.text = "银子够验"
	l.add_theme_font_size_override("font_size", 10)
	root.add_child(l)
	var k := Label.new()
	k.text = "B L O O D  A S S A Y"
	k.add_theme_font_size_override("font_size", 10)
	root.add_child(k)
	var r := RichTextLabel.new()
	r.text = "x"
	root.add_child(r)
	var big := Button.new()
	big.text = "大"
	big.add_theme_font_size_override("font_size", 30)
	root.add_child(big)
	var skip := Label.new()
	skip.text = "豁免"
	skip.set_meta("font_floor_exempt", true)
	skip.add_theme_font_size_override("font_size", 10)
	root.add_child(skip)
	MobileLayout.ensure_min_fonts(root)
	_ok(l.get_theme_font_size("font_size") == MobileLayout.FONT_FLOOR, "label floored")
	_ok(not k.visible, "kicker hidden")
	_ok(r.get_theme_font_size("normal_font_size") >= MobileLayout.FONT_FLOOR, "rich floored")
	_ok(big.get_theme_font_size("font_size") == 30, "big untouched")
	_ok(skip.get_theme_font_size("font_size") == 10, "exempt untouched")
	var pend := Control.new()
	pend.scene_file_path = "res://scenes/hub/forge.tscn"
	var pl := Label.new()
	pl.add_theme_font_size_override("font_size", 10)
	pend.add_child(pl)
	add_child(pend)
	MobileLayout.ensure_min_fonts(pend)
	_ok(pl.get_theme_font_size("font_size") == 10, "pending page untouched")
	if _fails.is_empty():
		print("FONT FLOOR PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL font_floor: ", f)
		get_tree().quit(1)
