class_name CKCourtChrome
extends RefCounted
## Frost-glass presentation for v8.9 bloodlines and the v9.0 court.
## Reads CKBloodline / CKCourt. Does not roll genetics or change prices.

const LAW_GLYPH := {
	"awakened": "功", "dose": "剂", "threshold": "槛", "dominant": "显",
	"recessive": "隐", "y_linked": "父", "x_dominant": "女", "penetrance": "六",
	"complement": "合", "maternal": "母", "age_awakened": "龄", "pureblood": "纯",
}
const KIND_ZH := {"birth": "添丁", "death": "辞世", "succession": "更替", "crisis": "危机", "marriage": "配婚", "recall": "归国"}
## Contemporary monograms. Letters are a house code, not an inheritance-law glyph.
const NATION_MARK := {
	"ashbanner": {"letters": "AB", "ink": "#C5D0DC", "kind": "bars"},
	"shuoying": {"letters": "SY", "ink": "#9BB4FF", "kind": "arc"},
	"qinghe": {"letters": "QH", "ink": "#5EE0B5", "kind": "wave"},
	"lantern": {"letters": "LN", "ink": "#6ED4FF", "kind": "filament"},
	"frostcrown": {"letters": "FC", "ink": "#E8F6FF", "kind": "ring"},
	"emberold": {"letters": "EO", "ink": "#FF8A80", "kind": "notch"},
	"saltmarsh": {"letters": "SM", "ink": "#7ED6C8", "kind": "tide"},
	"irongorge": {"letters": "IG", "ink": "#B7C3D1", "kind": "chevron"},
	"starriver": {"letters": "SR", "ink": "#8FD4FF", "kind": "spark"},
	"southzephyr": {"letters": "SZ", "ink": "#9DCFB8", "kind": "leaf"},
}

static func law_glyph(law: String) -> String:
	return str(LAW_GLYPH.get(law, "·"))

static func law_chip(law: String) -> Control:
	var box := PanelContainer.new()
	box.name = "LawChip"
	box.custom_minimum_size = Vector2(36, 28)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_stylebox_override("panel", UIKit.flat_box(Color(UIKit.ACCENT, 0.10), Color(UIKit.ACCENT, 0.45), 8))
	var l := UIKit.mono(law_glyph(law), 14, UIKit.ACCENT, false)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(l)
	box.tooltip_text = str(CKBloodline.data().get("laws", {}).get(law, {}).get("name", law))
	return box

static func nation_mark(nid: String) -> Control:
	var spec: Dictionary = NATION_MARK.get(nid, {"letters": "··", "ink": "#6ED4FF", "kind": "ring"})
	var nat: Dictionary = CKBloodline.nation(nid)
	var mark := NationMark.new()
	mark.name = "NationEmblem"
	mark.ink = Color(str(spec.get("ink", "#6ED4FF")))
	mark.kind = str(spec.get("kind", "ring"))
	mark.letters = str(spec.get("letters", "··"))
	mark.custom_minimum_size = Vector2(36, 36)
	mark.size = Vector2(36, 36)
	mark.tooltip_text = "%s · %s" % [str(nat.get("name", nid)), str(nat.get("motto", ""))]
	return mark

## Unknown codex trait: frost bars stand in for the name. The law icon stays; the name does not.
static func trait_silhouette(law: String) -> Control:
	var row := HBoxContainer.new()
	row.name = "TraitSilhouette"
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(148, 44)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var law_name := str(CKBloodline.data().get("laws", {}).get(law, {}).get("name", law))
	row.tooltip_text = "尚未入册。法则：%s。见过或在祠堂验到之后，图鉴才写下名字。" % law_name
	row.add_child(law_chip(law))
	var frost := Panel.new()
	frost.custom_minimum_size = Vector2(104, 32)
	frost.size = Vector2(104, 32)
	frost.mouse_filter = Control.MOUSE_FILTER_STOP
	frost.tooltip_text = row.tooltip_text
	frost.add_theme_stylebox_override("panel", UIKit.flat_box(Color("#C9D3DE", 0.06), Color("#6ED4FF", 0.35), 8))
	row.add_child(frost)
	var widths := [68, 44, 56]
	for i in widths.size():
		var bar := ColorRect.new()
		bar.color = Color("#F4F7FB", 0.22)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.position = Vector2(12, 7 + i * 8)
		bar.size = Vector2(widths[i], 3)
		frost.add_child(bar)
	return row

static func trait_known(meta: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.name = "TraitKnown"
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, 44)
	row.add_child(law_chip(str(meta.get("law", ""))))
	var lab := UIKit.tag_chip(str(meta.get("zh", "")), UIKit.OK, true)
	lab.tooltip_text = str(meta.get("desc", ""))
	row.add_child(lab)
	return row

static func known_states() -> Dictionary:
	var known := {}
	var gs = _gs()
	if gs == null:
		return known
	for c in gs.characters.values():
		var verified := _verified(c)
		for e in CKBloodline.signatures(c, verified) + CKBloodline.expressed_traits(c, verified):
			if not _show_entry(e, verified):
				continue
			var st := str(e.get("state", ""))
			if st != "":
				known[st] = true
	return known

static func unit_sheet(c: Object) -> Dictionary:
	var empty := {"shown": [], "carried": [], "verified": false, "purity": 0, "line": "", "stage": "young_adult", "stage_zh": "", "title": ""}
	if c == null:
		return empty
	var verified := _verified(c)
	var shown: Array = []
	var carried: Array = []
	var seen := {}
	for e in CKBloodline.signatures(c, true) + CKBloodline.expressed_traits(c, true):
		var locus := str(e.get("locus", ""))
		if locus == "" or seen.has(locus):
			continue
		var tier := str(e.get("tier", "none"))
		if tier == "none":
			continue
		seen[locus] = true
		var row: Dictionary = e.duplicate(true)
		row["from"] = parent_tag(c, locus)
		row["law_zh"] = str(CKBloodline.data().get("laws", {}).get(str(e.get("law", "")), {}).get("short", ""))
		if tier == "latent" or (bool(e.get("carrier", false)) and tier not in ["royal", "noble"]):
			if verified:
				carried.append(row)
		elif _show_entry(e, verified):
			shown.append(row)
		elif verified:
			carried.append(row)
	var mix: Dictionary = c.get("blood_mix") if typeof(c.get("blood_mix")) == TYPE_DICTIONARY else {}
	var line := ""
	var best := 0.0
	if c.has_method("primary_bloodline"):
		line = str(c.call("primary_bloodline"))
		best = float(mix.get(line, 0.0))
	var age := int(c.get("age"))
	var stage := CKGenomePortrait.stage_for_age(age)
	return {
		"shown": shown, "carried": carried, "verified": verified,
		"purity": int(round(best * 100.0)),
		"line": line,
		"line_zh": str(CKBloodline.line(line).get("name", line)),
		"stage": stage,
		"stage_zh": str(CKGenomePortrait.STAGE_ZH.get(stage, stage)),
		"title": CKCourt.ladder_zh(CKCourt.current_title(c)),
		"title_id": CKCourt.current_title(c),
	}

static func parent_tag(c: Object, locus: String) -> String:
	if c == null:
		return ""
	var pids: Array = c.get("parent_ids") if typeof(c.get("parent_ids")) == TYPE_ARRAY else []
	if pids.is_empty():
		return "无父母可溯"
	var gs = _gs()
	var chars: Dictionary = gs.characters if gs != null else {}
	var bits: Array = []
	var labels := ["父", "母"]
	for i in mini(2, pids.size()):
		var p = chars.get(str(pids[i]))
		if p == null:
			bits.append(labels[i] + "不在谱")
			continue
		if _parent_has_locus(p, locus):
			bits.append("来自" + labels[i])
		elif not _verified(p):
			bits.append(labels[i] + "未验")
	if bits.is_empty():
		return "双亲未见此因"
	return " · ".join(bits)

static func state_meta(state_id: String) -> Dictionary:
	for locus_v in CKBloodline.data().get("loci", {}).keys():
		var ld: Dictionary = CKBloodline.locus_def(str(locus_v))
		var states: Dictionary = ld.get("states", {})
		for k in states.keys():
			if str(states[k]) == state_id:
				var sd := CKBloodline.signature_def(state_id)
				return {
					"locus": str(locus_v), "law": str(ld.get("law", "")),
					"zh": str(sd.get("zh", state_id)),
					"desc": str(sd.get("desc", "")),
					"visibility": str(sd.get("visibility", "overt")),
					"tier": str(sd.get("tier", "")),
				}
	var sd2 := CKBloodline.signature_def(state_id)
	return {"locus": "", "law": "", "zh": str(sd2.get("zh", state_id)), "desc": str(sd2.get("desc", "")), "visibility": str(sd2.get("visibility", "")), "tier": str(sd2.get("tier", ""))}

static func fill_punnett(host: Control, father: Object, mother: Object, limit: int = 4) -> void:
	for ch in host.get_children():
		ch.queue_free()
	host.name = "PunnettBoard"
	if father == null or mother == null:
		host.add_child(UIKit.body_label("选定双方后，这里按性状给出子嗣概率。", UIKit.TEXT_FAINT, 12))
		return
	var rows: Array = []
	for r in CKBloodline.forecast(father, mother).slice(0, 3):
		var pct := int(round(float(r.get("royal", 0.0)) * 100.0))
		var note := str(r.get("royal_zh", ""))
		if bool(r.get("needs_deed", false)):
			note += " · 携因须立功"
			pct = int(round((float(r.get("carrier", 0.0)) + float(r.get("royal", 0.0))) * 100.0))
		elif absf(float(r.get("royal_f", 0.0)) - float(r.get("royal_m", 0.0))) > 0.05:
			note += "  女%d%% · 男%d%%" % [int(round(float(r.get("royal_f", 0.0)) * 100.0)), int(round(float(r.get("royal_m", 0.0)) * 100.0))]
		rows.append({"name": note, "pct": pct, "hint": str(r.get("law_zh", ""))})
	for r2 in CKBloodline.trait_odds(father, mother).slice(0, limit):
		var shown := float(r2.get("shown", 0.0))
		var note2 := str(r2.get("zh", ""))
		if absf(float(r2.get("shown_f", 0.0)) - float(r2.get("shown_m", 0.0))) > 0.05:
			note2 += "  女%d · 男%d" % [int(round(float(r2.get("shown_f", 0.0)) * 100.0)), int(round(float(r2.get("shown_m", 0.0)) * 100.0))]
		rows.append({"name": note2, "pct": int(round(shown * 100.0)), "hint": str(r2.get("law_zh", ""))})
		if rows.size() >= limit:
			break
	if rows.is_empty():
		host.add_child(UIKit.body_label("这对父母没有可计算的冕征或特征。", UIKit.TEXT_FAINT, 12))
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.add_child(box)
	for row in rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		box.add_child(line)
		var name := UIKit.body_label(str(row["name"]), UIKit.TEXT, 12)
		name.custom_minimum_size = Vector2(168, 18)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.clip_text = true
		name.autowrap_mode = TextServer.AUTOWRAP_OFF
		line.add_child(name)
		var bar := UIKit.slim_bar(float(row["pct"]), 100.0, UIKit.OK if int(row["pct"]) >= 50 else UIKit.ACCENT, 96, 4)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(bar)
		var hint := UIKit.mono("%d%%  %s" % [int(row["pct"]), str(row["hint"])], 11, UIKit.TEXT_DIM, false)
		hint.custom_minimum_size = Vector2(108, 18)
		hint.clip_text = true
		line.add_child(hint)

static func _gs():
	return Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() else null

static func _verified(c: Object) -> bool:
	var meta: Dictionary = c.get("blood_meta") if typeof(c.get("blood_meta")) == TYPE_DICTIONARY else {}
	return bool(meta.get("verified", false))

static func _show_entry(e: Dictionary, verified: bool) -> bool:
	var tier := str(e.get("tier", "none"))
	if tier == "none" or tier == "latent":
		return false
	var vis := str(e.get("visibility", "overt"))
	if vis == "latent":
		return verified
	if vis == "subtle":
		return verified or CKBloodline.inspect_level() >= 1
	return true

static func _parent_has_locus(p: Object, locus: String) -> bool:
	var verified := _verified(p)
	for e in CKBloodline.signatures(p, verified) + CKBloodline.expressed_traits(p, verified):
		if str(e.get("locus", "")) != locus:
			continue
		if str(e.get("tier", "none")) == "none":
			continue
		if str(e.get("tier", "")) == "latent" and not verified:
			continue
		return true
	return false


class NationMark extends Control:
	var ink: Color = Color.WHITE
	var kind: String = "ring"
	var letters: String = ""

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(36, 36)
		if size.x < 4.0:
			size = Vector2(36, 36)
		var lab := UIKit.mono(letters, 9, ink, false)
		lab.name = "EmblemLetters"
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.position = Vector2(0, 20)
		lab.size = Vector2(36, 14)
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lab)
		queue_redraw()

	func _draw() -> void:
		var s := size
		if s.x < 4.0:
			s = Vector2(36, 36)
		var c := Color(ink, 0.95)
		draw_rect(Rect2(Vector2(1, 1), s - Vector2(2, 2)), Color(ink, 0.14), true)
		draw_rect(Rect2(Vector2(0.5, 0.5), s - Vector2(1, 1)), Color(ink, 0.8), false, 1.0)
		match kind:
			"bars":
				draw_rect(Rect2(8, 5, 3, 13), c, true)
				draw_rect(Rect2(14, 8, 3, 10), c, true)
			"arc":
				draw_arc(Vector2(18, 12), 7.0, 3.5, 5.9, 18, c, 1.5, true)
			"wave":
				draw_line(Vector2(7, 8), Vector2(14, 6), c, 1.4)
				draw_line(Vector2(14, 6), Vector2(28, 10), c, 1.4)
				draw_line(Vector2(7, 13), Vector2(16, 11), c, 1.4)
				draw_line(Vector2(16, 11), Vector2(28, 14), c, 1.4)
			"filament":
				draw_line(Vector2(18, 5), Vector2(18, 16), c, 1.6)
				draw_arc(Vector2(18, 7), 4.5, PI, TAU, 12, c, 1.2, true)
			"ring":
				draw_arc(Vector2(14, 11), 6.0, 0.0, TAU, 24, c, 1.5, true)
			"notch":
				draw_line(Vector2(8, 16), Vector2(8, 7), c, 1.5)
				draw_line(Vector2(8, 7), Vector2(20, 7), c, 1.5)
				draw_line(Vector2(20, 7), Vector2(26, 13), c, 1.5)
				draw_line(Vector2(26, 13), Vector2(8, 13), c, 1.5)
			"tide":
				draw_rect(Rect2(8, 6, 16, 2), c, true)
				draw_rect(Rect2(8, 11, 12, 2), c, true)
				draw_rect(Rect2(8, 16, 8, 2), c, true)
			"chevron":
				draw_line(Vector2(8, 7), Vector2(18, 15), c, 1.6)
				draw_line(Vector2(18, 15), Vector2(28, 7), c, 1.6)
			"spark":
				draw_circle(Vector2(12, 8), 1.6, c)
				draw_circle(Vector2(22, 11), 1.3, c)
				draw_circle(Vector2(15, 15), 1.2, c)
			"leaf":
				draw_colored_polygon(PackedVector2Array([
					Vector2(18, 5), Vector2(26, 12), Vector2(18, 17), Vector2(10, 12)
				]), c)
			_:
				draw_arc(Vector2(18, 12), 6.0, 0.0, TAU, 20, c, 1.4, true)
