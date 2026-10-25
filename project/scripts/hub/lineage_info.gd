class_name CKLineageInfo
extends RefCounted
## Genealogy v2 right-hand info panel (docs/design/genealogy-v2.md).
## Portrait, name, age, family arms, rank badge, job, traits, and one action button.

const YeartraceUi := preload("res://scripts/hub/sui_yeartrace_ui.gd")
const RECT := Rect2(862, 72, 394, 600)

static func family_of(chars: Dictionary, leader) -> Array:
	## leader + everyone linked to the family by spouse / parent / child ids (alive or dead)
	var fam: Dictionary = {}
	if leader != null:
		fam[leader.id] = leader
	var changed := true
	while changed:
		changed = false
		for ch in chars.values():
			if fam.has(ch.id):
				continue
			var linked := str(ch.spouse_id) != "" and fam.has(str(ch.spouse_id))
			for pid in ch.parent_ids:
				if fam.has(str(pid)):
					linked = true
			for cid in ch.children_ids:
				if fam.has(str(cid)):
					linked = true
			if not linked:
				for other in fam.values():
					if str(other.spouse_id) == str(ch.id) or ch.id in other.parent_ids:
						linked = true
						break
			if linked:
				fam[ch.id] = ch
				changed = true
	var out: Array = fam.values()
	var memo := {}
	out.sort_custom(func(a, b):
		if a.is_leader != b.is_leader:
			return a.is_leader
		var ga := gen_of(chars, a, memo)
		var gb := gen_of(chars, b, memo)
		if ga != gb:
			return ga < gb
		if a.age != b.age:
			return a.age > b.age
		return str(a.id) < str(b.id))
	return out

static func gen_of(chars: Dictionary, c, memo: Dictionary) -> int:
	if memo.has(c.id):
		return memo[c.id]
	memo[c.id] = 0
	var g := 0
	for pid in c.parent_ids:
		var p = chars.get(str(pid))
		if p != null:
			g = maxi(g, gen_of(chars, p, memo) + 1)
	memo[c.id] = g
	return g

static func spouses_of(chars: Dictionary, c) -> Array:
	var out: Array = []
	if str(c.spouse_id) != "" and chars.has(str(c.spouse_id)):
		out.append(chars[str(c.spouse_id)])
	for o in chars.values():
		if str(o.spouse_id) == str(c.id) and not out.has(o):
			out.append(o)
	# co-parents count as partners too (widowed / remarried lines)
	for k in children_of(chars, c):
		for pid in k.parent_ids:
			var p = chars.get(str(pid))
			if p != null and p != c and not out.has(p):
				out.append(p)
	return out

static func children_of(chars: Dictionary, c) -> Array:
	var out: Array = []
	for cid in c.children_ids:
		var k = chars.get(str(cid))
		if k != null and not out.has(k):
			out.append(k)
	for o in chars.values():
		if c.id in o.parent_ids and not out.has(o):
			out.append(o)
	out.sort_custom(func(a, b): return a.age > b.age if a.age != b.age else str(a.id) < str(b.id))
	return out

static func parents_of(chars: Dictionary, c) -> Array:
	var out: Array = []
	for pid in c.parent_ids:
		var p = chars.get(str(pid))
		if p != null and not out.has(p):
			out.append(p)
	return out

static func stage_text(c) -> String:
	return str(CKGenomePortrait.STAGE_ZH.get(CKGenomePortrait.stage_for_age(c.age), ""))

static func job_text(c) -> String:
	if c.age < Calendar.ADULT_AGE:
		return Locale.t("lin_minor")
	return str(GameState.get_job(c.job_id).get("name", c.job_id))

static func portrait_rect(c, sz: Vector2) -> Control:
	var box := Control.new()
	box.name = "Portrait"
	box.size = sz
	box.custom_minimum_size = sz
	box.clip_contents = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pt = UnitArt.unit_portrait(c) if c != null else null
	if pt:
		var tr := TextureRect.new()
		tr.texture = pt
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.size = sz
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tr)
	if c != null and not c.alive:
		box.modulate = Color(0.55, 0.55, 0.55, 1.0)
	return box

## Builds the panel into `host` (cleared first). `action_text` "" hides the action button.
static func render(host: Control, c, action_text: String, action_cb: Callable) -> Panel:
	for n in host.get_children():
		host.remove_child(n)
		n.queue_free()
	var p := UIKit.panel_at(host, RECT, 12)
	p.name = "InfoPanel"
	var h1 := UIKit.title_label(Locale.t("gen2_01"), 16)
	h1.add_theme_font_override("font", UIKit.font("bold"))
	h1.position = Vector2(20, 16)
	p.add_child(h1)
	if c == null:
		var none := UIKit.body_label(Locale.t("gen2_02"), UIKit.TEXT_FAINT, 13)
		none.name = "InfoEmpty"
		none.position = Vector2(20, 60)
		none.size = Vector2(354, 60)
		p.add_child(none)
		return p
	var por := portrait_rect(c, Vector2(120, 150))
	por.position = Vector2(20, 52)
	p.add_child(por)
	var nm := UIKit.title_label(c.name, 20)
	nm.name = "InfoName"
	nm.add_theme_font_override("font", UIKit.font("bold"))
	nm.position = Vector2(156, 52)
	nm.size = Vector2(218, 28)
	nm.clip_text = true
	p.add_child(nm)
	var life := (Locale.t("gen2_03") % [c.age, stage_text(c)]) if c.alive else (Locale.t("gen2_04") % c.age)
	var ag := UIKit.body_label(life, UIKit.OK if c.alive else UIKit.TEXT_FAINT, 13)
	ag.name = "InfoAge"
	ag.autowrap_mode = TextServer.AUTOWRAP_OFF
	ag.position = Vector2(156, 86)
	p.add_child(ag)
	var jb := UIKit.body_label(Locale.t("gen2_05") % job_text(c), UIKit.TEXT, 13)
	jb.name = "InfoJob"
	jb.autowrap_mode = TextServer.AUTOWRAP_OFF
	jb.clip_text = true
	jb.size = Vector2(218, 20)
	jb.position = Vector2(156, 110)
	p.add_child(jb)
	var arms := CKHeraldryChrome.make_person_arms(c, Vector2(48, 58))
	arms.position = Vector2(156, 132)
	p.add_child(arms)
	var kind := UIKit.body_label(CKHeraldryChrome.arms_kind_label(c), UIKit.TEXT_DIM, 11)
	kind.name = "ArmsKind"
	kind.autowrap_mode = TextServer.AUTOWRAP_OFF
	kind.position = Vector2(156, 192)
	p.add_child(kind)
	var badge := CKHeraldryChrome.make_rank_badge(str(c.rank), 32)
	badge.position = Vector2(214, 140)
	p.add_child(badge)
	var rk := UIKit.body_label(c.rank_name(), UIKit.ACCENT, 13)
	rk.name = "InfoRank"
	rk.autowrap_mode = TextServer.AUTOWRAP_OFF
	rk.position = Vector2(254, 148)
	p.add_child(rk)
	UIKit.section_head(p, Vector2(20, 220), Locale.t("gen2_07"), "TRAITS", 354, Locale.t("gen2_08") % c.traits.size())
	var y := 246.0
	var shown := 0
	for tr in c.traits:
		if shown >= 3:
			break
		var td: Dictionary = GameState.get_trait(str(tr))
		var ic := UIKit.trait_icon_rect(str(tr), 22.0)
		ic.position = Vector2(20, y + 2)
		p.add_child(ic)
		var tn := UIKit.body_label(str(td.get("name", tr)), UIKit.TEXT, 13)
		tn.autowrap_mode = TextServer.AUTOWRAP_OFF
		tn.position = Vector2(50, y + 3)
		p.add_child(tn)
		y += 30
		shown += 1
	if c.traits.is_empty():
		var nt := UIKit.body_label(Locale.t("gen2_09"), UIKit.TEXT_FAINT, 12)
		nt.position = Vector2(20, y)
		p.add_child(nt)
	var yt_y := mini(y + 10.0, 360.0)
	var yt_host := Control.new()
	yt_host.name = "YeartraceHost"
	yt_host.position = Vector2(20, yt_y)
	yt_host.size = Vector2(354, 110)
	yt_host.clip_contents = true
	p.add_child(yt_host)
	GameState.set_meta("yeartrace_back", "res://scenes/hub/lineage_view.tscn")
	YeartraceUi.mount_for(yt_host, c, 354.0, 3)
	var pb := str(c.primary_bloodline())
	var bl := UIKit.body_label(Locale.t("gen2_10") % [GameState.get_bloodline(pb).get("name", pb), int(round(float(c.blood_mix.get(pb, 1.0)) * 100))], UIKit.TEXT_DIM, 12)
	bl.autowrap_mode = TextServer.AUTOWRAP_OFF
	bl.position = Vector2(20, yt_y + 114.0)
	p.add_child(bl)
	if action_text != "":
		var btn := UIKit.cta_button(action_text, "" if DeviceProfile.is_mobile() else "A", 354, 52)
		btn.name = "InfoAction"
		btn.position = Vector2(20, 530)
		btn.pressed.connect(action_cb)
		p.add_child(btn)
	return p


## Phone landscape: same content in containers, 22px text, 76px action.
static func render_mobile(host: Control, c, action_text: String, action_cb: Callable, rect: Rect2) -> Control:
	for n in host.get_children():
		host.remove_child(n)
		n.queue_free()
	var v := MobilePage.panel(host, rect, 18)
	(v.get_parent() as Control).name = "InfoPanel"
	var h1 := MobilePage.label(Locale.t("gen2_01"), UIKit.TEXT, 24, false)
	v.add_child(h1)
	if c == null:
		var none := MobilePage.label(Locale.t("gen2_02"), UIKit.TEXT_FAINT)
		none.name = "InfoEmpty"
		v.add_child(none)
		return v
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	v.add_child(top)
	top.add_child(portrait_rect(c, Vector2(132, 166)))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	top.add_child(col)
	var nm := MobilePage.label(c.name, UIKit.TEXT, 28)
	nm.name = "InfoName"
	col.add_child(nm)
	var life := (Locale.t("gen2_03") % [c.age, stage_text(c)]) if c.alive else (Locale.t("gen2_04") % c.age)
	col.add_child(MobilePage.label(life, UIKit.OK if c.alive else UIKit.TEXT_FAINT))
	col.add_child(MobilePage.label(Locale.t("gen2_05") % job_text(c), UIKit.TEXT))
	var rr := HBoxContainer.new()
	rr.add_theme_constant_override("separation", 8)
	col.add_child(rr)
	var arms := CKHeraldryChrome.make_person_arms(c, Vector2(48, 58))
	rr.add_child(arms)
	var badge := CKHeraldryChrome.make_rank_badge(str(c.rank), 36)
	badge.custom_minimum_size = Vector2(36, 48)
	rr.add_child(badge)
	var kind := MobilePage.label(CKHeraldryChrome.arms_kind_label(c), UIKit.TEXT_DIM, MobilePage.FONT, false)
	kind.name = "ArmsKind"
	kind.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rr.add_child(kind)
	var rk := MobilePage.label(c.rank_name(), UIKit.ACCENT)
	rk.name = "InfoRank"
	rk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rr.add_child(rk)
	var head := Locale.t("gen2_07") + "  " + Locale.t("gen2_08") % c.traits.size()
	v.add_child(MobilePage.label(head, UIKit.ACCENT))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 18)
	flow.add_theme_constant_override("v_separation", 6)
	v.add_child(flow)
	var shown := 0
	for tr in c.traits:
		if shown >= 3:
			break
		var td: Dictionary = GameState.get_trait(str(tr))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(UIKit.trait_icon_rect(str(tr), 28.0))
		row.add_child(MobilePage.label(str(td.get("name", tr)), UIKit.TEXT, MobilePage.FONT, false))
		flow.add_child(row)
		shown += 1
	if c.traits.is_empty():
		v.add_child(MobilePage.label(Locale.t("gen2_09"), UIKit.TEXT_FAINT))
	var pb := str(c.primary_bloodline())
	var mix := int(round(float(c.blood_mix.get(pb, 1.0)) * 100))
	v.add_child(MobilePage.label(Locale.t("gen2_10") % [GameState.get_bloodline(pb).get("name", pb), mix], UIKit.TEXT_DIM))
	GameState.set_meta("yeartrace_back", "res://scenes/hub/lineage_view.tscn")
	YeartraceUi.mount_for(v, c, 420.0, 4)
	MobilePage.spacer(v)
	if action_text != "":
		var btn := MobilePage.button(action_text, true, func(): action_cb.call())
		btn.name = "InfoAction"
		v.add_child(btn)
	return v
