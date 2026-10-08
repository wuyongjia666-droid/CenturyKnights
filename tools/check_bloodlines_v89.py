#!/usr/bin/env python3
"""v8.9 bloodline data gate (no Godot needed): every nation has royal / noble / folk lines with the required
fields, genome tables only use real CKGenome alleles, the world's nation pools point at v89 ids, every prompt
fragment passes the style-lock-v89 anti-trope list, and the Plan A fixtures are well formed. Exit 1 on any error."""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "project/data/bloodlines_v89.json"
LEGACY = ROOT / "project/data/bloodlines.json"
WORLD = ROOT / "project/data/world_v87.json"
ATLAS = ROOT / "project/data/atlas_v8.json"
SKILLS = ROOT / "project/data/skills.json"
JOBS = ROOT / "project/data/jobs.json"
GENOME = ROOT / "project/scripts/characters/genome.gd"
BLOOD_GD = ROOT / "project/scripts/characters/bloodline_v89.gd"
LOCK = ROOT / "docs/art/style-lock-v89.json"
FIXTURES = ROOT / "project/tests/fixtures/bloodline_portraits_v89.json"
STATS = ["str", "vit", "skl", "agi", "per", "wil"]
TIERS = {"royal", "noble", "folk"}
CJK = re.compile(r"[\u4e00-\u9fff]")
LINE_FIELDS = ["id", "name", "name_en", "nation", "tier", "house", "desc", "lore", "stat_min", "stat_max", "jobs",
               "skill_bias", "genome", "sig", "look", "tavern"]
NATION_FIELDS = ["id", "name", "name_en", "royal", "noble", "folk", "locus", "law", "motto", "succession", "crisis",
                 "edge", "verify", "forgery", "decline", "revival", "marriage", "regalia", "exile"]
SIG_FIELDS = ["zh", "name_en", "tier", "visibility", "nation", "desc", "prompt"]
LAW_FIELDS = ["name", "name_en", "short", "desc", "punnett"]
errors = []


def err(msg):
    errors.append(msg)


def load(p):
    return json.loads(p.read_text())


def crown_order():
    src = BLOOD_GD.read_text()
    m = re.search(r"const LOCUS_ORDER := \[([^\]]+)\]", src)
    if not m:
        return []
    return re.findall(r'"(\w+)"', m.group(1))


def genome_loci():
    src = GENOME.read_text()
    block = src.split("const LOCI := {", 1)[1].split("\n}", 1)[0]
    loci = {}
    for name, body in re.findall(r'"(\w+)":\s*\[([^\]]*)\]', block):
        loci[name] = re.findall(r'"(\w+)"', body)
    return loci


def forbidden(text, words):
    low = text.lower()
    for w in words:
        if re.search(r"\b" + re.escape(w.lower()), low):
            return w
    return ""


def main():
    d = load(DATA)
    legacy = {b["id"]: b for b in load(LEGACY)["bloodlines"]}
    world = load(WORLD)
    atlas_nations = [n["id"] for n in load(ATLAS)["nations"]]
    skills = {s["id"]: s for s in load(SKILLS)["skills"]}
    jobs = {j["id"] for j in load(JOBS)["jobs"]}
    loci = genome_loci()
    lock = load(LOCK)
    anti = lock.get("anti_trope", {})
    forbid = anti.get("forbid_in_positive", [])
    royal_forbid = anti.get("royal_genome_forbid", {})
    if not lock.get("qwen", {}).get("prefix", "").startswith("CenturyKnights style lock v8.9"):
        err("style-lock-v89 prefix must start with 'CenturyKnights style lock v8.9'")

    laws = d.get("laws", {})
    for lid, law in laws.items():
        for f in LAW_FIELDS:
            if not str(law.get(f, "")).strip():
                err(f"law {lid}: missing {f}")
    crown = crown_order()
    if crown != ["sig_ashbanner", "sig_shuoying", "jade", "sig_lantern", "sig_frostcrown", "sig_emberold", "sig_saltmarsh", "sig_irongorge", "sig_starriver", "glow"]:
        err(f"LOCUS_ORDER drifted: {crown}")
    trait_order = [str(x) for x in d.get("trait_order", [])]
    if not trait_order:
        err("trait_order missing")
    if set(crown) & set(trait_order):
        err(f"trait_order overlaps the original crown loci: {sorted(set(crown) & set(trait_order))}")
    if not str(d.get("rng_note", "")).strip():
        err("rng_note must document that trait loci append after the original ten")

    sigs = d.get("signatures", {})
    palette_hex = {str(v).upper() for v in lock.get("palette", {}).values() if isinstance(v, str) and v.startswith("#")}
    for sid, s in sigs.items():
        for f in SIG_FIELDS:
            if f == "prompt" and s.get("described_by"):
                continue
            if not str(s.get(f, "")).strip():
                err(f"signature {sid}: missing {f}")
        if s.get("tier") not in TIERS:
            err(f"signature {sid}: tier must be royal/noble/folk")
        if s.get("visibility") not in d.get("visibility", {}):
            err(f"signature {sid}: unknown visibility {s.get('visibility')}")
        if not CJK.search(str(s.get("zh", ""))) or not CJK.search(str(s.get("desc", ""))):
            err(f"signature {sid}: zh/desc must be Chinese")
        for field in ("prompt", "prompt_young", "prompt_elder"):
            bad = forbidden(str(s.get(field, "")), forbid)
            if bad:
                err(f"signature {sid}: {field} uses forbidden trope '{bad}'")
        if s.get("generated") == "trait-set-v89":
            if not str(s.get("prompt_young", "")).strip() or not str(s.get("prompt_elder", "")).strip():
                err(f"signature {sid}: trait prompts need youth and elder wording")
            for m in s.get("modules", []):
                if not re.fullmatch(r"regalia_[a-z0-9_]+", str(m)):
                    err(f"signature {sid}: module id {m} must look like regalia_*")
            pal = s.get("palette", {})
            if pal:
                if not isinstance(pal, dict):
                    err(f"signature {sid}: palette must be an object of hexes")
                else:
                    for pk, pv in pal.items():
                        if str(pv).upper() not in palette_hex:
                            err(f"signature {sid}: palette {pk} {pv} is outside the style-lock palette")

    used_laws = set()
    scope_royal = {}
    for locus, ld in d.get("loci", {}).items():
        if ld.get("law") not in laws:
            err(f"locus {locus}: unknown law {ld.get('law')}")
        used_laws.add(ld.get("law"))
        for k, st in ld.get("states", {}).items():
            if st not in sigs:
                err(f"locus {locus}: state {st} has no signature definition")
            elif str(ld.get("display_tier", "")) and k == "royal" and sigs[st].get("tier") != ld.get("display_tier"):
                err(f"locus {locus}: display_tier {ld.get('display_tier')} but {st} is tier {sigs[st].get('tier')}")
        if ld.get("scope") == "royal":
            scope_royal.setdefault(ld.get("nation"), []).append(locus)
        if locus in trait_order and locus in crown:
            err(f"locus {locus} is both a crown locus and a trait locus")
    crown_laws = []
    for locus in crown:
        ld = d.get("loci", {}).get(locus)
        if ld is None:
            err(f"crown locus {locus} missing from data")
            continue
        crown_laws.append(ld.get("law"))
        if ld.get("generated") == "trait-set-v89":
            err(f"crown locus {locus} must stay the original political sign, not a generated trait")
    if len(crown_laws) != 10 or len(set(crown_laws)) != 10:
        err(f"the original ten crown loci must keep ten distinct laws, got {crown_laws}")
    extra = set(laws) - set(crown_laws)
    if extra != {"age_awakened", "pureblood"}:
        err(f"trait-only laws must be age_awakened and pureblood, got {sorted(extra)}")
    if used_laws != set(laws):
        err(f"unused laws: {sorted(set(laws) - used_laws)}")
    for nid, ids in scope_royal.items():
        if len(ids) != 7:
            err(f"nation {nid}: expected 7 royal-scope trait loci, got {len(ids)}")
    if len(trait_order) != len(set(trait_order)):
        err("trait_order has duplicate loci")
    for locus in trait_order:
        ld = d.get("loci", {}).get(locus)
        if ld is None or ld.get("generated") != "trait-set-v89":
            err(f"trait_order {locus} is not a generated trait locus")

    lines = {}
    for l in d.get("lines", []):
        lid = l.get("id", "?")
        if lid in lines:
            err(f"duplicate line id {lid}")
        lines[lid] = l
        for f in LINE_FIELDS:
            if f not in l or l[f] in ("", None):
                err(f"line {lid}: missing {f}")
        if l.get("tier") not in TIERS:
            err(f"line {lid}: bad tier {l.get('tier')}")
        for f in ("name", "desc", "lore", "house"):
            if not CJK.search(str(l.get(f, ""))):
                err(f"line {lid}: {f} must be Chinese (player-facing)")
        for k in STATS:
            lo, hi = l.get("stat_min", {}).get(k), l.get("stat_max", {}).get(k)
            if not isinstance(lo, int) or not isinstance(hi, int) or not (1 <= lo <= hi <= 20):
                err(f"line {lid}: stat {k} range {lo}..{hi}")
        for j in l.get("jobs", []):
            if j not in jobs:
                err(f"line {lid}: unknown job {j}")
        g = l.get("genome", {})
        for locus in ("hair", "eyes", "brow", "ears", "mark"):
            for allele in g.get(locus, {}):
                if allele not in loci.get(locus, []):
                    err(f"line {lid}: genome {locus}.{allele} is not a CKGenome allele")
        for k in g.get("face", {}):
            if k not in ("width", "jaw", "cheek", "nose", "eye_tilt", "eye_size", "brow_height"):
                err(f"line {lid}: unknown face key {k}")
        for k in g.get("body", {}):
            if k not in ("height", "build"):
                err(f"line {lid}: unknown body key {k}")
        if not re.fullmatch(r"#[0-9A-Fa-f]{6}", str(g.get("skin", ""))):
            err(f"line {lid}: skin must be #RRGGBB")
        if l.get("tier") == "royal":
            for locus, banned in royal_forbid.items():
                for allele in banned:
                    if float(g.get(locus, {}).get(allele, 0)) > 0:
                        err(f"royal line {lid}: {locus}.{allele} is a reference-game royal trope")
            rs = l.get("skill_bias", {}).get("royal_skill", "")
            if rs not in skills or skills[rs].get("blood_sig") != l.get("nation") or skills[rs].get("jobs"):
                err(f"royal line {lid}: royal_skill {rs} missing, mis-tagged or job-learnable")
            if l.get("signature") not in sigs or sigs[l["signature"]].get("tier") != "royal":
                err(f"royal line {lid}: signature must name a royal signature")
        tset = l.get("trait_set", [])
        if not isinstance(tset, list):
            err(f"line {lid}: trait_set must be a list")
        else:
            need = {"royal": (6, 8), "noble": (3, 5), "folk": (2, 3)}.get(l.get("tier"), (0, 99))
            if not (need[0] <= len(tset) <= need[1]):
                err(f"line {lid}: trait_set length {len(tset)} outside {need[0]}-{need[1]}")
            if l.get("tier") == "royal" and l.get("signature") not in tset:
                err(f"line {lid}: trait_set must include the crown signature")
            laws_here = set()
            for sid in tset:
                sd = sigs.get(sid)
                if sd is None or sd.get("nation") != l.get("nation"):
                    err(f"line {lid}: trait {sid} missing or from another nation")
                    continue
                loc = d["loci"].get(str(sd.get("locus", "")), {})
                if sid == l.get("signature"):
                    loc = d["loci"].get(str(d["nations"].get(l.get("nation"), {}).get("locus", "")), loc)
                if loc:
                    laws_here.add(loc.get("law"))
            if l.get("tier") == "royal" and len(laws_here) < 4:
                err(f"line {lid}: royal trait set should mix laws, got {sorted(laws_here)}")
        for e in l.get("sig", []):
            ld = d["loci"].get(e.get("locus", ""))
            if ld is None:
                err(f"line {lid}: sig locus {e.get('locus')} unknown")
                continue
            if ld["nation"] != l.get("nation"):
                err(f"line {lid}: sig locus {e['locus']} belongs to {ld['nation']}")
            alleles = set(ld.get("alleles", [])) | {"none"}
            tables = [e.get("genotypes")] if "genotypes" in e else [e.get("f"), e.get("m")]
            if "value" in e:
                mean, sd = e["value"]
                if not (0 <= mean <= 1 and 0 < sd < 0.5):
                    err(f"line {lid}: value {e['value']} out of range")
                continue
            for t in tables:
                if t is None:
                    err(f"line {lid}: sig {e['locus']} missing genotype table")
                    continue
                for gt, w in t.items():
                    if w <= 0 or any(a not in alleles for a in gt.split("|")):
                        err(f"line {lid}: sig {e['locus']} genotype {gt}")
        for f in ("look",):
            bad = forbidden(str(l.get(f, "")), forbid)
            if bad:
                err(f"line {lid}: {f} uses forbidden trope '{bad}'")
        if not isinstance(l.get("tavern", {}).get("premium"), int) or not CJK.search(str(l.get("tavern", {}).get("rarity", ""))):
            err(f"line {lid}: tavern needs an int premium and a Chinese rarity")

    for lid in ("common_ash", "river_ward", "ember_noble", "frost_crown"):
        if lid not in lines:
            err(f"legacy id {lid} missing")
        elif lines[lid]["stat_min"] != legacy[lid]["stat_min"] or lines[lid]["stat_max"] != legacy[lid]["stat_max"]:
            err(f"legacy id {lid}: stat ranges drifted from bloodlines.json")

    nations = d.get("nations", {})
    if sorted(nations) != sorted(atlas_nations):
        err(f"nations {sorted(nations)} != atlas_v8 {sorted(atlas_nations)}")
    diaspora = {x["id"]: x for x in d.get("diaspora", [])}
    for nid, n in nations.items():
        for f in NATION_FIELDS:
            if f not in n or n[f] in ("", None, [], {}):
                err(f"nation {nid}: missing {f}")
        if n.get("name") != world["nations"].get(nid, {}).get("name"):
            err(f"nation {nid}: name {n.get('name')} != world {world['nations'].get(nid, {}).get('name')}")
        checks = [("royal", n.get("royal"))] + [("noble", x) for x in n.get("noble", [])] + [("folk", n.get("folk"))]
        for tier, lid in checks:
            l = lines.get(lid)
            if l is None or l.get("tier") != tier or l.get("nation") != nid:
                err(f"nation {nid}: {tier} line {lid} invalid")
        if d["loci"].get(n.get("locus", ""), {}).get("nation") != nid:
            err(f"nation {nid}: locus {n.get('locus')} not owned")
        for blk, keys in (("succession", ["name", "desc"]), ("edge", ["name", "desc"]), ("verify", ["name", "desc"]),
                          ("forgery", ["name", "prompt", "tell"]), ("marriage", ["desc"])):
            for k in keys:
                if not str(n.get(blk, {}).get(k, "")).strip():
                    err(f"nation {nid}: {blk}.{k} missing")
        if n.get("edge", {}).get("stigma") not in (0, 1, 2):
            err(f"nation {nid}: edge.stigma must be 0/1/2")
        if not any(k.endswith("_desc") for k in n.get("crisis", {})):
            err(f"nation {nid}: crisis needs named crises with descriptions")
        for ex in n.get("exile", []):
            if ex not in diaspora:
                err(f"nation {nid}: exile {ex} not in diaspora")
            elif lines.get(diaspora[ex]["line"], {}).get("nation") != nid:
                err(f"nation {nid}: exile {ex} line belongs elsewhere")
        for f in ("regalia",):
            bad = forbidden(str(n.get(f, "")), forbid)
            if bad:
                err(f"nation {nid}: {f} uses forbidden trope '{bad}'")
        bad = forbidden(str(n.get("forgery", {}).get("prompt", "")), forbid)
        if bad:
            err(f"nation {nid}: forgery prompt uses forbidden trope '{bad}'")
        catches = n.get("catch_traits", [])
        if not isinstance(catches, list) or len(catches) < 2:
            err(f"nation {nid}: need at least 2 catch_traits")
        else:
            for cid in catches:
                cs = sigs.get(cid, {})
                if cs.get("visibility") != "subtle" or cs.get("nation") != nid:
                    err(f"nation {nid}: catch {cid} must be a subtle sign of this house")
                clocus = d.get("loci", {}).get(str(cs.get("locus", "")), {})
                if not clocus.get("catch"):
                    err(f"nation {nid}: catch {cid} locus is not marked catch")
        wb = world["nations"].get(nid, {}).get("blood", [])
        if not wb:
            err(f"world nation {nid}: empty blood pool")
        for b in wb:
            if b not in lines or lines[b]["nation"] != nid or lines[b]["tier"] == "royal":
                err(f"world nation {nid}: blood {b} must be one of its own folk/noble v89 lines")
        if n.get("folk") not in wb or any(x not in wb for x in n.get("noble", [])):
            err(f"world nation {nid}: blood pool must list its folk and noble lines")
    for rid, r in d.get("regions", {}).items():
        if r.get("royal"):
            err(f"region {rid} must not have a royal line")
        for b in world["nations"].get(rid, {}).get("blood", []):
            if b not in lines:
                err(f"world region {rid}: unknown blood {b}")
    for did, x in diaspora.items():
        if x.get("line") not in lines or x.get("sex") not in ("", "m", "f") or not (0 < float(x.get("mix", 0)) <= 1):
            err(f"diaspora {did}: bad line/sex/mix")
        for nid in x.get("nations", []):
            if nid not in world["nations"]:
                err(f"diaspora {did}: unknown host {nid}")
        if not CJK.search(str(x.get("name", ""))) or not CJK.search(str(x.get("desc", ""))):
            err(f"diaspora {did}: name/desc must be Chinese")
    for sid in d.get("royal_skills", []):
        s = skills.get(sid)
        if s is None or not CJK.search(str(s.get("name", ""))) or not CJK.search(str(s.get("desc", ""))):
            err(f"royal skill {sid}: missing or not Chinese")

    # Readability: any two royal houses differ in at least five prime-age prompts.
    packs = {}
    for nid, n in nations.items():
        royal = lines.get(n.get("royal"), {})
        bag = {}
        for sid in royal.get("trait_set", []):
            pr = str(sigs.get(sid, {}).get("prompt", "")).strip()
            if pr:
                bag[pr] = sid
        if len(bag) < 6:
            err(f"nation {nid}: royal trait set has only {len(bag)} distinct prime prompts")
        packs[nid] = bag
    nids = sorted(packs)
    for i, a in enumerate(nids):
        for b in nids[i + 1:]:
            diff = sum(1 for k in packs[a] if k not in packs[b])
            if diff < 5:
                err(f"{a} vs {b} share too many traits (only {diff} differ)")

    # Plan A fixtures
    fx = load(FIXTURES) if FIXTURES.exists() else {}
    rows = fx.get("rows", [])
    if len(rows) < 18:
        err(f"fixtures: expected >= 18 rows, got {len(rows)}")
    prefix = lock["qwen"]["prefix"]
    seen_states = set()
    for r in rows:
        for f in ("case", "unit_id", "line", "signatures", "clause", "seed", "positive", "negative", "out_path", "notes_zh"):
            if f not in r:
                err(f"fixture {r.get('case')}: missing {f}")
        if not str(r.get("positive", "")).startswith(prefix):
            err(f"fixture {r.get('case')}: positive does not start with the v8.9 lock prefix")
        if r.get("negative") != lock["qwen"]["negative"]:
            err(f"fixture {r.get('case')}: negative is not the v8.9 lock negative")
        if r.get("clause") and r["clause"] not in r.get("positive", ""):
            err(f"fixture {r.get('case')}: clause not inside positive")
        bad = forbidden(str(r.get("clause", "")), forbid)
        if bad:
            err(f"fixture {r.get('case')}: clause uses forbidden trope '{bad}'")
        if re.search(r"pointed ear|frost-crystal birthmark", str(r.get("positive", ""))):
            err(f"fixture {r.get('case')}: base prompt still uses a retired trope descriptor")
        seen_states.update(r.get("signatures", []))
    for nid, n in nations.items():
        royal_state = lines.get(n.get("royal"), {}).get("signature")
        if royal_state not in seen_states:
            err(f"fixtures: no example shows {nid}'s royal sign {royal_state}")

    if errors:
        for e in errors:
            print("FAIL bloodlines_v89:", e)
        print(f"BLOODLINES V89 DATA FAIL ({len(errors)} errors)")
        return 1
    print(f"BLOODLINES V89 DATA PASS lines={len(lines)} nations={len(nations)} laws={len(laws)} signatures={len(sigs)} fixtures={len(rows)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
