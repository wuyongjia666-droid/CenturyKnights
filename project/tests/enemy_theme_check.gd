extends Node
## Enemy factions reuse shipped GLBs. The cutscene resolver must pick theme, role, and palette.

const TEMPLATES := [
	"bandit_weak", "bandit", "bandit_archer", "bandit_chief",
	"escort_thief", "escort_raider", "escort_sniper", "escort_boss",
	"fisher_thug", "fisher_archer", "fisher_boss",
	"paper_thief", "paper_archer", "paper_boss",
	"copper_thug", "copper_archer", "copper_boss",
	"lamp_thug", "lamp_archer", "lamp_boss",
	"grain_thug", "grain_archer", "grain_boss",
	"snow_thug", "snow_archer", "snow_boss",
	"bamboo_thug", "bamboo_archer", "bamboo_boss",
	"relay_thug", "relay_archer", "relay_boss",
	"bell_thug", "bell_archer", "bell_boss",
	"rain_thug", "rain_archer", "rain_boss",
	"ink_thug", "ink_archer", "ink_boss",
	"hive_thug", "hive_archer", "hive_boss",
	"flute_thug", "flute_archer", "flute_boss",
	"shadow_thug", "shadow_archer", "shadow_boss",
	"salt_thug", "salt_archer", "salt_boss",
	"dye_thug", "dye_archer", "dye_boss",
	"drum_thug", "drum_archer", "drum_boss",
	"incense_thug", "incense_archer", "incense_boss",
	"tide_thug", "tide_archer", "tide_boss",
	"porcelain_thug", "porcelain_archer", "porcelain_boss",
]

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL enemy theme: ", err)
		get_tree().quit(1)
	else:
		get_tree().quit(0)

func _foe() -> CKCharacter:
	var c := CKCharacter.new()
	c.id = "theme_foe"
	c.name = "theme"
	c.gender = "m"
	c.age = 30
	c.job_id = "light_inf"
	c.faction = "enemy"
	c.blood_mix = {"common_ash": 1.0}
	c.appearance = {"hair": "ink_black", "eyes": "slate", "brow": "straight", "scar": "none"}
	return c

func _run() -> String:
	var c := _foe()
	var themes: Dictionary = UnitModel.enemy_themes().get("themes", {})
	if themes.size() < 20:
		return "theme table %d" % themes.size()
	var expect := {
		"bandit_archer": ["bandit", "ranged", "enemy_bandit_archer.glb"],
		"bandit_chief": ["bandit", "elite", "enemy_bandit_chief.glb"],
		"bandit_weak": ["bandit", "light", "enemy_bandit_weak.glb"],
		"bandit": ["bandit", "melee", "enemy_bandit.glb"],
		"snow_archer": ["snow", "ranged", ""],
		"snow_boss": ["snow", "elite", ""],
		"tide_thug": ["tide", "melee", ""],
		"ink_boss": ["ink", "elite", ""],
		"dye_archer": ["dye", "ranged", ""],
	}
	for tmpl in expect.keys():
		var spec: Dictionary = UnitModel.resolve(c, "enemy", tmpl)
		var want: Array = expect[tmpl]
		if str(spec.get("theme", "")) != str(want[0]) or str(spec.get("role", "")) != str(want[1]):
			return "%s resolved %s/%s" % [tmpl, spec.get("theme"), spec.get("role")]
		var path := str(spec.get("path", ""))
		if path == "" or not ResourceLoader.exists(path):
			return "%s missing glb %s" % [tmpl, path]
		if str(want[2]) != "" and not path.ends_with(str(want[2])):
			return "%s path %s" % [tmpl, path]
	var snow: Dictionary = UnitModel.resolve(c, "enemy", "snow_archer")
	var dye: Dictionary = UnitModel.resolve(c, "enemy", "dye_archer")
	if str(snow.get("path")) == str(dye.get("path")) and (snow["trim"] as Color).is_equal_approx(dye["trim"]):
		return "snow and dye collapsed"
	if (snow["trim"] as Color).is_equal_approx(dye["trim"]):
		return "snow/dye trim"
	var melee := {}
	var weapons := {}
	for theme in themes.keys():
		var spec: Dictionary = UnitModel.resolve(c, "enemy", "%s_thug" % str(theme))
		if str(spec.get("theme")) != str(theme) or str(spec.get("role")) != "melee":
			return "thug parse %s -> %s/%s" % [theme, spec.get("theme"), spec.get("role")]
		var path := str(spec.get("path", ""))
		if not ResourceLoader.exists(path):
			return "thug glb %s %s" % [theme, path]
		var sig := "%s|%s" % [path.get_file(), (spec["trim"] as Color).to_html(false)]
		if melee.has(sig):
			return "melee collision %s and %s (%s)" % [melee[sig], theme, sig]
		melee[sig] = str(theme)
		weapons[path.get_file()] = true
		for role_tmpl in ["_archer", "_boss"]:
			var rs: Dictionary = UnitModel.resolve(c, "enemy", str(theme) + role_tmpl)
			if str(rs.get("path", "")) == "" or not ResourceLoader.exists(str(rs.get("path"))):
				return "role glb %s%s" % [theme, role_tmpl]
	if weapons.size() < 4:
		return "weapon variety %d" % weapons.size()
	for tmpl in TEMPLATES:
		var spec: Dictionary = UnitModel.resolve(c, "enemy", tmpl)
		var pref: String = str(tmpl)
		var cut: int = str(tmpl).rfind("_")
		if cut > 0 and UnitModel.enemy_themes().get("roles", {}).has(tmpl.substr(cut + 1)):
			pref = tmpl.substr(0, cut)
		if str(spec.get("theme")) != pref:
			return "template theme %s -> %s" % [tmpl, spec.get("theme")]
		if not ResourceLoader.exists(str(spec.get("path", ""))):
			return "template glb %s" % tmpl
	c.gender = "f"
	var ink: Dictionary = UnitModel.resolve(c, "enemy", "ink_thug")
	if not str(ink.get("path", "")).ends_with("outfit_apprentice_t1_f.glb"):
		return "gender outfit %s" % str(ink.get("path"))
	c.gender = "m"
	c.faction = "player"
	c.job_id = "hunter"
	var ally := UnitModel.model_path(c, "player", "")
	if not ally.ends_with("outfit_hunter_t1_m.glb"):
		return "ally path %s" % ally
	# Cutscene calls instantiate(), which uses this same resolve(). Headless has no mesh
	# server, so the kit check stays on the resolved path instead of instantiating the GLB.
	var picked: Dictionary = UnitModel.resolve(c, "enemy", "snow_archer")
	if str(picked.get("theme", "")) != "snow" or str(picked.get("role", "")) != "ranged":
		return "cutscene spec"
	if not str(picked.get("path", "")).ends_with("bandit_bow.glb"):
		return "cutscene model %s" % str(picked.get("path", ""))
	var cut := FileAccess.get_file_as_string("res://scripts/battle/combat_cutscene.gd")
	if not cut.contains("UnitModel.resolve(") or not cut.contains("UnitModel.instantiate("):
		return "cutscene does not resolve theme models"
	print("ENEMY THEME PASS themes=%d weapons=%d" % [themes.size(), weapons.size()])
	return ""
