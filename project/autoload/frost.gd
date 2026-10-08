extends Node
## Frost theme plus the accessibility palette (UX-02).
## Headless CI does not spawn lamp tips; a windowed session does, once per id.

const MODES := ["none", "deuteranopia", "protanopia", "tritanopia"]

const _DEUTAN := [
	[0.367322, 0.860646, -0.227968],
	[0.280085, 0.672501, 0.047413],
	[-0.011820, 0.042940, 0.968881],
]
const _PROTAN := [
	[0.152286, 1.052583, -0.204868],
	[0.114503, 0.786281, 0.099216],
	[-0.003882, -0.048116, 1.051998],
]
const _TRITAN := [
	[1.255528, -0.076749, -0.178779],
	[-0.078411, 0.930809, 0.147602],
	[0.004733, 0.691367, 0.303900],
]

func _ready() -> void:
	get_tree().root.theme = UIKit.frost_theme()
	get_tree().node_added.connect(_on_node_added)
	apply_accessibility()

func _on_node_added(node: Node) -> void:
	if node != get_tree().current_scene:
		return
	call_deferred("_on_scene")

func _on_scene() -> void:
	apply_accessibility()
	if DisplayServer.get_name() == "headless":
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	CKTips.maybe_present(scene)

func mode() -> String:
	var m := str(GameState.settings.get("colorblind", "none"))
	if not MODES.has(m):
		return "none"
	return m

func high_contrast() -> bool:
	return bool(GameState.settings.get("high_contrast", false))

func ui_scale() -> float:
	return clampf(float(GameState.settings.get("ui_scale", 1.0)), 0.9, 1.4)

func shake_gain() -> float:
	return clampf(float(GameState.settings.get("screen_shake", 100.0)), 0.0, 100.0) / 100.0

func haptics_enabled() -> bool:
	return bool(GameState.settings.get("haptics", true))

func palette() -> Dictionary:
	return resolved(mode(), high_contrast())

func swatch(key: String) -> Color:
	return palette()[key]

func resolved(which: String, high: bool) -> Dictionary:
	var ally := Color("#5EE0B5")
	var enemy := Color("#FF7A70")
	var ally_ink := Color("#041018")
	var enemy_ink := Color("#1A0A0C")
	if which == "deuteranopia":
		ally = Color("#2E7BFF")
		enemy = Color("#F0E56A")
		ally_ink = Color("#041018")
		enemy_ink = Color("#1A1604")
	elif which == "protanopia":
		ally = Color("#3AA0FF")
		enemy = Color("#F0E56A")
		ally_ink = Color("#041018")
		enemy_ink = Color("#1A1604")
	elif which == "tritanopia":
		ally = Color("#5EE0B5")
		enemy = Color("#FF7A70")
	var bg := Color("#07080C")
	var panel := Color("#161B24")
	var text := Color("#F4F7FB")
	var text_dim := Color("#9AA6B8")
	var accent := Color("#6ED4FF")
	var on_accent := Color("#041018")
	if high:
		bg = Color("#000000")
		panel = Color("#0A0E14")
		text = Color("#FFFFFF")
		text_dim = Color("#E7EDF5")
		accent = Color("#9BE4FF")
		on_accent = Color("#000000")
	return {
		"bg": bg,
		"panel": panel,
		"text": text,
		"text_dim": text_dim,
		"accent": accent,
		"on_accent": on_accent,
		"ally": ally,
		"enemy": enemy,
		"ally_ink": ally_ink,
		"enemy_ink": enemy_ink,
	}

func text_pairs(p: Dictionary) -> Array:
	return [
		[p["text"], p["bg"]],
		[p["text"], p["panel"]],
		[p["text_dim"], p["bg"]],
		[p["text_dim"], p["panel"]],
		[p["on_accent"], p["accent"]],
		[p["ally_ink"], p["ally"]],
		[p["enemy_ink"], p["enemy"]],
	]

func apply_accessibility() -> void:
	var scene := get_tree().current_scene
	if scene is Control:
		var ctl := scene as Control
		var s := ui_scale()
		ctl.scale = Vector2(s, s)
		ctl.pivot_offset = Vector2.ZERO
	var p := palette()
	var theme := get_tree().root.theme
	if theme == null:
		theme = UIKit.frost_theme()
		get_tree().root.theme = theme
	theme.set_color("font_color", "Label", p["text"])
	theme.set_color("font_color", "Button", p["text"])
	theme.set_color("default_color", "RichTextLabel", p["text"])

func contrast_ratio(fg: Color, bg: Color) -> float:
	var l1 := _rel_lum(fg)
	var l2 := _rel_lum(bg)
	if l1 < l2:
		var swap := l1
		l1 = l2
		l2 = swap
	return (l1 + 0.05) / (l2 + 0.05)

func simulate_cvd(color: Color, which: String) -> Color:
	var matrix: Array = []
	if which == "deuteranopia":
		matrix = _DEUTAN
	elif which == "protanopia":
		matrix = _PROTAN
	elif which == "tritanopia":
		matrix = _TRITAN
	else:
		return color
	var lin := [_lin(color.r), _lin(color.g), _lin(color.b)]
	var out := []
	for i in 3:
		var row: Array = matrix[i]
		out.append(row[0] * lin[0] + row[1] * lin[1] + row[2] * lin[2])
	return Color(_from_lin(out[0]), _from_lin(out[1]), _from_lin(out[2]), color.a)

func delta_e2000(a: Color, b: Color) -> float:
	var lab1 := _lab(a)
	var lab2 := _lab(b)
	var L1: float = lab1.x
	var a1: float = lab1.y
	var b1: float = lab1.z
	var L2: float = lab2.x
	var a2: float = lab2.y
	var b2: float = lab2.z
	var avg_L := (L1 + L2) / 2.0
	var C1 := sqrt(a1 * a1 + b1 * b1)
	var C2 := sqrt(a2 * a2 + b2 * b2)
	var avg_C := (C1 + C2) / 2.0
	var g_pow := pow(avg_C, 7.0)
	var G := 0.5 * (1.0 - sqrt(g_pow / (g_pow + pow(25.0, 7.0))))
	var a1p := (1.0 + G) * a1
	var a2p := (1.0 + G) * a2
	var C1p := sqrt(a1p * a1p + b1 * b1)
	var C2p := sqrt(a2p * a2p + b2 * b2)
	var avg_Cp := (C1p + C2p) / 2.0
	var h1p := _hue(a1p, b1)
	var h2p := _hue(a2p, b2)
	var dh := 0.0
	var avg_h := h1p + h2p
	if C1p >= 0.000001 and C2p >= 0.000001:
		dh = h2p - h1p
		if dh > 180.0:
			dh -= 360.0
		elif dh < -180.0:
			dh += 360.0
		if absf(h1p - h2p) > 180.0:
			avg_h = (h1p + h2p + 360.0) / 2.0
		else:
			avg_h = (h1p + h2p) / 2.0
	var dLp := L2 - L1
	var dCp := C2p - C1p
	var dHp := 2.0 * sqrt(maxf(C1p * C2p, 0.0)) * sin(deg_to_rad(dh) / 2.0)
	var SL := 1.0 + (0.015 * pow(avg_L - 50.0, 2.0)) / sqrt(20.0 + pow(avg_L - 50.0, 2.0))
	var SC := 1.0 + 0.045 * avg_Cp
	var T := 1.0 - 0.17 * cos(deg_to_rad(avg_h - 30.0)) + 0.24 * cos(deg_to_rad(2.0 * avg_h)) + 0.32 * cos(deg_to_rad(3.0 * avg_h + 6.0)) - 0.20 * cos(deg_to_rad(4.0 * avg_h - 63.0))
	var SH := 1.0 + 0.015 * avg_Cp * T
	var dtheta := 30.0 * exp(-pow((avg_h - 275.0) / 25.0, 2.0))
	var cp_pow := pow(avg_Cp, 7.0)
	var RC := 2.0 * sqrt(cp_pow / (cp_pow + pow(25.0, 7.0)))
	var RT := -RC * sin(deg_to_rad(2.0 * dtheta))
	return sqrt(pow(dLp / SL, 2.0) + pow(dCp / SC, 2.0) + pow(dHp / SH, 2.0) + RT * (dCp / SC) * (dHp / SH))

func _hue(a: float, b: float) -> float:
	if absf(a) < 0.0000001 and absf(b) < 0.0000001:
		return 0.0
	var ang := rad_to_deg(atan2(b, a))
	return ang + 360.0 if ang < 0.0 else ang

func _lin(channel: float) -> float:
	var c := channel
	if c <= 0.04045:
		return c / 12.92
	return pow((c + 0.055) / 1.055, 2.4)

func _from_lin(channel: float) -> float:
	var c := clampf(channel, 0.0, 1.0)
	if c <= 0.0031308:
		return 12.92 * c
	return 1.055 * pow(c, 1.0 / 2.4) - 0.055

func _rel_lum(color: Color) -> float:
	return 0.2126 * _lin(color.r) + 0.7152 * _lin(color.g) + 0.0722 * _lin(color.b)

func _lab(color: Color) -> Vector3:
	var r := _lin(color.r)
	var g := _lin(color.g)
	var b := _lin(color.b)
	var X := 0.4124564 * r + 0.3575761 * g + 0.1804375 * b
	var Y := 0.2126729 * r + 0.7151522 * g + 0.0721750 * b
	var Z := 0.0193339 * r + 0.1191920 * g + 0.9503041 * b
	var Xn := 0.95047
	var Yn := 1.0
	var Zn := 1.08883
	var fx := _lab_f(X / Xn)
	var fy := _lab_f(Y / Yn)
	var fz := _lab_f(Z / Zn)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))

func _lab_f(t: float) -> float:
	var d := 6.0 / 29.0
	if t > d * d * d:
		return pow(t, 1.0 / 3.0)
	return t / (3.0 * d * d) + 4.0 / 29.0
