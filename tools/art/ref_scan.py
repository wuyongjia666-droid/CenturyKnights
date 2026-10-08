#!/usr/bin/env python3
"""Find project/assets files with no runtime reference.

Scans .gd, .tscn, .tres and .json (the retired-asset report itself is excluded).
A file counts as referenced when a res:// path, a path suffix, a bare basename
(outside farm_inbox, where inbox copies share names with ingested plates), a
printf pattern with a literal filename prefix, or a JSON/script stem matches it.

Doll parts and other names built at runtime stay on a keep-list so they are not
retired. farm_inbox duplicates are not kept merely because an ingested copy
shares the basename.

  python3 tools/art/ref_scan.py
  python3 tools/art/ref_scan.py --write docs/art/retired-assets-v92.json
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ASSET_ROOT = ROOT / "project" / "assets"
EXTS = {".gd", ".tscn", ".tres", ".json"}
FILE_EXT = r"(?:png|jpg|jpeg|webp|ogg|wav|glb|tres|otf|ttf|svg)"
QUOTED = re.compile(r'"([^"\n]{1,240})"')
CONST = re.compile(r'const\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?::=\s*|\s*=\s*)"([^"\n]*)"')
THEME_RE = re.compile(r'make_themed_bg\([^)]*"([a-z_]+)"\)')
DOLL_PART = re.compile(
    r"^(base|infant|youth|young_adult|middle|elder|young|ears_crest|iris_mask|"
    r"brow_[a-z0-9_]+|mark_[a-z0-9_]+|scar_[a-z0-9_]+|hair_[a-z0-9_]+)\.png$"
)
# Plates unit_art.gd builds without a quoted filename. Existence changes portrait_kind.
LIVE_V8 = {
    "v8_hero_leader_f",
    "v8_hero_leader_m",
    "v8_bust_f_hunter",
    "v8_bust_m_hunter",
    "v8_bust_f_spear",
    "v8_bust_m_spear",
    "v8_bust_f_guard",
    "v8_bust_m_guard",
    "v8_hero_heir_f",
    "v8_bust_f_medic",
}
BACKDROP_THEMES = {"castle", "hub", "menu", "battle"}


def _sources() -> list[Path]:
    # tools/ and docs/ hold shot lists and style notes. Those name plates that the
    # game never loads. Runtime references live in project/ (.gd/.tscn/.tres/.json).
    skip = {".git", ".godot", "tools", "docs"}
    out = []
    for p in ROOT.rglob("*"):
        if not p.is_file() or p.suffix not in EXTS:
            continue
        rel = p.relative_to(ROOT).as_posix()
        if any(rel.startswith(s) or f"/{s}/" in f"/{rel}" for s in skip):
            continue
        if rel == "docs/art/retired-assets-v92.json":
            continue
        out.append(p)
    return out


def _inline_consts(text: str) -> str:
    consts = dict(CONST.findall(text))
    for name, val in consts.items():
        text = text.replace(f'{name} + "', val)
        text = text.replace(f"{name} + '", val)
    return text


def _filename_literal(fmt: str) -> str:
    return fmt.split("/")[-1]


def _is_specific_pattern(fmt: str) -> bool:
    """Open stems like dir/%s.png do not pin every file in that directory."""
    leaf = _filename_literal(fmt)
    head = leaf.split("%", 1)[0]
    return len(head) >= 3


def _pattern_to_re(fmt: str) -> re.Pattern | None:
    if "%" not in fmt or not re.search(FILE_EXT, fmt, re.I):
        return None
    if not _is_specific_pattern(fmt):
        return None
    i = 0
    parts = []
    while i < len(fmt):
        if fmt.startswith("%s", i) or fmt.startswith("%d", i):
            parts.append(r"[^/\"']+")
            i += 2
        elif fmt.startswith("%%", i):
            parts.append("%")
            i += 2
        elif fmt[i] == "%" and i + 1 < len(fmt) and fmt[i + 1].isdigit():
            j = i + 1
            while j < len(fmt) and fmt[j].isdigit():
                j += 1
            if j < len(fmt) and fmt[j] in "doxX":
                parts.append(r"\d+")
                i = j + 1
                continue
            parts.append(re.escape(fmt[i]))
            i += 1
        else:
            parts.append(re.escape(fmt[i]))
            i += 1
    try:
        return re.compile("".join(parts) + r"$")
    except re.error:
        return None


def _collect(paths: list[Path]) -> tuple[set[str], list[re.Pattern], set[str], set[str]]:
    names: set[str] = set()
    patterns: list[re.Pattern] = []
    stems: set[str] = set()
    themes: set[str] = set(BACKDROP_THEMES)
    seen_fmt: set[str] = set()
    for p in paths:
        text = _inline_consts(p.read_text(errors="ignore"))
        themes.update(THEME_RE.findall(text))
        for m in QUOTED.finditer(text):
            s = m.group(1).strip()
            if " " in s:
                continue
            if "%" in s and re.search(rf"\.{FILE_EXT}\b", s, re.I):
                if s not in seen_fmt:
                    cre = _pattern_to_re(s)
                    if cre is not None:
                        patterns.append(cre)
                        seen_fmt.add(s)
                continue
            if re.search(rf"\.{FILE_EXT}\b", s, re.I):
                names.add(s.split("/")[-1])
                names.add(s)
                continue
            leaf = s.split("/")[-1]
            if re.fullmatch(r"[A-Za-z0-9_.-]{4,80}", leaf):
                stems.add(leaf)
    return names, patterns, stems, themes


def _is_doll_live(rel: str) -> bool:
    if not rel.startswith("art/doll/"):
        return False
    name = rel.split("/")[-1]
    if "/outfit/" in rel or "/honor/" in rel:
        return name.endswith(".png")
    return DOLL_PART.match(name) is not None


def _dynamic_keep(rel: str) -> bool:
    """Names assembled at runtime. The scanner cannot see the finished filename."""
    if rel.startswith((
        "art/fx/",
        "art/tiles/",
        "art/terrain_v86/",
        "art/portraits/v84_geno_",
        "art/portraits/genome/",
        "art/atlas/cities/v87_city_",
        "art/atlas/smiths/v87_smith_",
        "art/scenes/v8_scene_",
        "art/battle/v8_battle_biome_",
        "art/banners/banner_",
    )):
        return True
    if rel.startswith("art/tokens/") and "/_src" not in "/" + rel:
        return True
    name = rel.split("/")[-1]
    stem = name.rsplit(".", 1)[0]
    if rel.startswith("art/portraits/") and stem in LIVE_V8:
        return True
    if rel.startswith("art/portraits/") and (
        name.endswith("_boss.png") or name.endswith("_face_plate.png")
    ):
        return True
    return False


def _referenced(rel: str, res_path: str, names: set[str], patterns: list[re.Pattern], stems: set[str], themes: set[str]) -> bool:
    base = rel.split("/")[-1]
    stem = base.rsplit(".", 1)[0]
    inbox = rel.startswith("art/farm_inbox/")
    if res_path in names or rel in names or ("project/assets/" + rel) in names:
        return True
    for n in names:
        if "/" in n and (res_path.endswith(n) or n.endswith("/" + rel) or n.endswith(rel)):
            return True
    # Bare basename collisions: ingested plates and their farm_inbox copies share a name.
    # Shot-list stems name the plate, not the inbox copy.
    if inbox:
        pass
    elif base in names:
        return True
    elif len(stem) >= 8 and stem in stems:
        return True
    if rel.startswith("art/ui/") and stem.endswith("_backdrop"):
        theme = stem[: -len("_backdrop")]
        if theme in themes:
            return True
    for cre in patterns:
        if cre.search(res_path) or cre.search("/" + rel):
            return True
    return False


def scan() -> dict:
    sources = _sources()
    names, patterns, stems, themes = _collect(sources)
    zero = []
    kept = []
    doll_live = []
    dynamic = []
    zero_bytes = 0
    by_dir = defaultdict(lambda: [0, 0])
    for p in ASSET_ROOT.rglob("*"):
        if not p.is_file() or p.suffix == ".import":
            continue
        rel = p.relative_to(ASSET_ROOT).as_posix()
        res_path = "res://assets/" + rel
        size = p.stat().st_size
        if rel.endswith(".gitkeep") or not rel.startswith("art/"):
            kept.append(rel)
            continue
        if _is_doll_live(rel) or _dynamic_keep(rel):
            doll_live.append(rel) if _is_doll_live(rel) else dynamic.append(rel)
            continue
        if _referenced(rel, res_path, names, patterns, stems, themes):
            kept.append(rel)
            continue
        zero.append({"path": "project/assets/" + rel, "bytes": size})
        zero_bytes += size
        bits = rel.split("/")
        top = "/".join(bits[:2]) if bits[0] == "art" and len(bits) > 1 else bits[0]
        by_dir[top][0] += 1
        by_dir[top][1] += size
    zero.sort(key=lambda r: r["path"])
    return {
        "source_files": len(sources),
        "literal_names": len(names),
        "patterns": len(patterns),
        "stems": len(stems),
        "zero_ref_files": len(zero),
        "zero_ref_bytes": zero_bytes,
        "by_dir": {k: {"files": v[0], "bytes": v[1]} for k, v in sorted(by_dir.items(), key=lambda kv: -kv[1][1])},
        "doll_live_files": len(doll_live),
        "dynamic_keep_files": len(dynamic),
        "referenced_files": len(kept),
        "files": zero,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", type=Path, default=None)
    args = ap.parse_args()
    report = scan()
    summary = {k: report[k] for k in report if k != "files"}
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    if args.write:
        payload = {
            "version": "v92",
            "owner": "S10-art",
            "note": "零运行时引用（.gd/.tscn/.tres/.json 的路径、带字面前缀的 printf、JSON 词干）。纸娃娃动态零件与运行时拼名的图另列保留。farm_inbox 不因与成品同名而算被引用。",
            "handoff_inf02": {
                "export_presets": "不改 project/export_presets.cfg，导出过滤归 INF-02。",
                "exclude_dirs": [
                    "res://assets/art/farm_inbox/",
                    "res://assets/art/stitch_exports/",
                ],
                "do_not_exclude_yet": [
                    "res://assets/art/doll/ 仍被 portrait_doll.gd 与 trio_doll_v88 加载",
                    "res://assets/art/portraits/hireface_* 仍被 unit_art.gd 指纹融合加载",
                    "res://assets/art/portraits/hireuniq_* 仍是雇佣立绘底图",
                    "res://assets/art/farm_inbox/qwen_v830/v83_elite_*.png 仍是敌军精英回退",
                ],
                "archive": "tools/archive/art-retired-v92/ 保留相对路径。不改写 git 历史，历史体积不会下降。",
            },
            "zero_ref_bytes": report["zero_ref_bytes"],
            "zero_ref_files": report["zero_ref_files"],
            "by_dir": report["by_dir"],
            "doll_live_kept": report["doll_live_files"],
            "dynamic_keep": report["dynamic_keep_files"],
            "files": [row["path"] for row in report["files"]],
        }
        args.write.parent.mkdir(parents=True, exist_ok=True)
        args.write.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n")
        print(f"wrote {args.write}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
