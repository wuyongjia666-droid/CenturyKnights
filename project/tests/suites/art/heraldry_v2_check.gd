extends Node
## Heraldry v2 (castle arms): tincture rule, rank tiers, legacy-field migrate, render smoke.

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
	# Castle arms: legacy per-person / marriage fields are dropped on normalize (save migration).
	var legacy := v1.duplicate(true)
	legacy["marshalling"] = {"mode": "impale", "partner": CKHeraldry.from_nation("qinghe")}
	legacy["cadency"] = "crescent"
	legacy["bastardy"] = true
	var migrated := CKHeraldry.normalize(legacy)
	for legacy_key in ["marshalling", "cadency", "bastardy"]:
		if migrated.has(legacy_key):
			issues.append("legacy key kept " + legacy_key)
	var a := CKHeraldry.from_nation("ashbanner")
	# Rank tiers: castle/company title drives helm + crown.
	var knight_ach: Dictionary = CKHeraldry.apply_rank(a, "knight").get("achievement", {})
	var royal_ach: Dictionary = CKHeraldry.apply_rank(a, "royal").get("achievement", {})
	if str(knight_ach.get("crown", "")) == str(royal_ach.get("crown", "")):
		issues.append("crown tier by rank")

	# Genealogy title badges: one distinct badge per noble tier.
	var badge_sigs: Dictionary = {}
	for rk in ["knight", "baron", "viscount", "count", "duke", "royal"]:
		var bt := CKHeraldryRender.rank_badge(rk, 32)
		if bt == null or bt.get_width() != 32:
			issues.append("rank badge " + rk)
			break
		badge_sigs[Marshalls.raw_to_base64(bt.get_image().get_data()).md5_text()] = rk
	if badge_sigs.size() != 6:
		issues.append("rank badges not distinct")

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
	GameState.banner_spec = migrated
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
	issues.append_array(_family_issues())
	return "" if issues.is_empty() else str(issues[0])

func _family_issues() -> PackedStringArray:
	## Company banner (团徽) vs family arms (族徽): uniqueness, canton, tier, fallback, save, live rank.
	var issues: PackedStringArray = []
	GameState.new_game("烬行", "霜旗", "#" + UIKit.ACCENT.to_html(false))
	var leader = GameState.get_leader()
	if str(leader.family_id) == "":
		issues.append("leader family not founded")
	var nids: Array = (CKHeraldry.table().get("nations", {}) as Dictionary).keys()
	for i in range(40):
		GameState.found_family("族%d" % i, str(nids[i % nids.size()]), [])
	var reg := GameState.arms_registry()
	if reg.size() != 1 + GameState.families.size():
		issues.append("arms not unique %d vs %d" % [reg.size(), 1 + GameState.families.size()])
	# Company banner set at founding that copies a family core → the family re-rolls.
	var fid0: String = str(leader.family_id)
	GameState.banner_spec = (GameState.families[fid0] as Dictionary)["core"].duplicate(true)
	GameState.ensure_unique_arms()
	if CKHeraldry.core_key(GameState.families[fid0]["core"]) == CKHeraldry.core_key(GameState.banner_spec):
		issues.append("castle/family collision not resolved")
	if str(GameState.arms_for_character(leader).get("castle_mark", {}).get("field", "")) != str(GameState.banner_spec.get("field_a", "")):
		issues.append("family canton should echo company banner")
	# Tier ornament + live rank signal.
	var got := []
	leader.rank_changed.connect(func(r: String) -> void: got.append(r))
	leader.rank = "knight"
	var t_common := str(GameState.arms_for_character(leader).get("family_tier", ""))
	leader.rank = "duke"
	var royal_arms := GameState.arms_for_character(leader)
	if t_common != "commoner" or str(royal_arms.get("family_tier", "")) != "royal":
		issues.append("tier ornament %s/%s" % [t_common, royal_arms.get("family_tier", "")])
	if (royal_arms.get("charges", []) as Array).size() < 2 or str(royal_arms.get("border", "none")) == "none":
		issues.append("royal arms not richer")
	if got != ["duke"]:
		issues.append("rank_changed not live " + str(got))
	# No family → castle banner.
	var loner := CKCharacter.new()
	if CKHeraldry.core_key(GameState.arms_for_character(loner)) != CKHeraldry.core_key(GameState.banner_spec):
		issues.append("familyless should show castle banner")
	# Save round-trip + legacy migration (no families key → leader family founded, legacy keys dropped).
	var data := GameState.build_save_data()
	var n_fam := GameState.families.size()
	GameState.apply_save_data(data.duplicate(true))
	if GameState.families.size() != n_fam or str(GameState.get_leader().family_id) != fid0:
		issues.append("families save round-trip")
	var old := data.duplicate(true)
	old.erase("families")
	for cid in old.get("characters", {}).keys():
		old["characters"][cid].erase("family_id")
	GameState.apply_save_data(old)
	if GameState.families.size() != 1 or str(GameState.get_leader().family_id) == "":
		issues.append("legacy save family migration")
	return issues
