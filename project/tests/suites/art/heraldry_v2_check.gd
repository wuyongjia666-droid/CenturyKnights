extends Node
## Heraldry v2: tincture rule, marshalling, cadency, migrate, render smoke.

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL heraldry v2: ", err)
		get_tree().quit(1)
		return
	print("HERALDRY V2 PASS")
	get_tree().quit(0)

func _run() -> String:
	var issues: PackedStringArray = []
	if CKHeraldry.table().is_empty():
		issues.append("empty table")
	if CKHeraldry.palette().size() < 24:
		issues.append("palette")
	if CKHeraldry.tincture_ok("argent", "or"):
		issues.append("metal on metal should fail")
	if not CKHeraldry.tincture_ok("argent", "azure"):
		issues.append("metal on colour should pass")
	if CKHeraldry.tincture_ok("azure", "gules"):
		issues.append("colour on colour should fail")
	if not CKHeraldry.tincture_ok("ermine", "or"):
		issues.append("fur should exempt")

	var v1 := {
		"field": "per_pale",
		"field_a": "#" + UIKit.ACCENT.to_html(false),
		"field_b": "#" + UIKit.ACCENT_DIM.to_html(false),
		"charge": "chevron",
		"charge_color": "#" + UIKit.TEXT.to_html(false),
		"border": "dentil",
		"border_color": "#" + UIKit.ACCENT_HOVER.to_html(false),
		"emblem": "spark",
		"emblem_color": "#" + UIKit.TEXT.to_html(false),
	}
	var v2 := CKHeraldry.normalize(v1)
	if int(v2.get("schema", 0)) != 2:
		issues.append("schema")
	if str(v2.get("division", "")) != "per_pale":
		issues.append("division migrate")
	if str(v2.get("ordinary", "")) != "chevron":
		issues.append("ordinary migrate")
	var chs: Array = v2.get("charges", [])
	if chs.is_empty():
		issues.append("emblem to charge")
	if CKHeraldry.cadency_for_birth_order(1) != "label":
		issues.append("cadency1")
	if CKHeraldry.cadency_for_birth_order(3) != "mullet":
		issues.append("cadency3")
	if CKHeraldry.cadency_for_birth_order(0) != "none":
		issues.append("cadency0")
	var with_cad := CKHeraldry.apply_cadency(v2, 2, true)
	if str(with_cad.get("cadency", "")) != "crescent":
		issues.append("apply cadency")
	if not bool(with_cad.get("bastardy", false)):
		issues.append("bastardy")

	var a := CKHeraldry.from_nation("ashbanner")
	var b := CKHeraldry.from_nation("qinghe")
	var m := CKHeraldry.marshal(a, b, "impale")
	if str((m.get("marshalling", {}) as Dictionary).get("mode", "")) != "impale":
		issues.append("impale mode")
	var q := CKHeraldry.marshal(a, b, "quarter")
	if str((q.get("marshalling", {}) as Dictionary).get("mode", "")) != "quarter":
		issues.append("quarter mode")

	var nations: Dictionary = CKHeraldry.table().get("nations", {})
	if nations.size() < 10:
		issues.append("nation count")
	for nid in nations.keys():
		var spec := CKHeraldry.from_nation(str(nid), "duke")
		var img := CKHeraldryRender.compose(spec, 64, 80, 0.0, "shield")
		if img.get_width() != 64:
			issues.append("render " + str(nid))
			break
		var opaque := 0
		for y in range(img.get_height()):
			for x in range(img.get_width()):
				if img.get_pixel(x, y).a > 0.1:
					opaque += 1
		if opaque < 80:
			issues.append("empty render " + str(nid))
			break

	var royal := CKHeraldry.apply_rank(CKHeraldry.from_nation("frostcrown"), "royal")
	var arms := BannerSpec.compose_arms(royal, 90, 110)
	if arms.get_width() != 90:
		issues.append("arms size")
	var ban := BannerSpec.compose(a, 80, 110, 0.2)
	if ban.get_width() != 80:
		issues.append("banner size")
	var chk: Dictionary = CKHeraldry.tincture_ok_spec(a)
	if not bool(chk.get("ok", false)):
		issues.append("nation preset tincture " + str(chk.get("issues", [])))

	GameState.new_game("烬行", "霜旗", "#" + UIKit.ACCENT.to_html(false))
	GameState.banner_spec = m
	var data := GameState.build_save_data()
	if not data.has("banner_spec"):
		issues.append("save missing")
	else:
		var old := data.duplicate(true)
		old.erase("banner_spec")
		old["crest_color"] = "#" + "c9a227"
		if not GameState.apply_save_data(old):
			issues.append("load old")
		elif str(GameState.banner_spec.get("field_a", "")).to_lower().find("c9a227") >= 0:
			issues.append("old crest not migrated")
		elif int(GameState.banner_spec.get("schema", 0)) != 2:
			issues.append("loaded schema")
	return "" if issues.is_empty() else str(issues[0])
