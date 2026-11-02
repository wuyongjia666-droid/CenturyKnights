#!/usr/bin/env python3
"""Store on-demand scaffold gate (no PAD/CDN, no paid submission).

Validates docs/store/ondemand-assets.json against project/export_presets.cfg,
the Android medium_only bank contract, and critical always-packed paths so
deferred larges cannot silently drop plates. Also requires Android source CAP
UNDER from export_size_report (APK measured separately; H/I still user-only).
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "docs" / "store" / "ondemand-assets.json"
PRESETS = ROOT / "project" / "export_presets.cfg"
PROJECT = ROOT / "project"
EXPORT_SIZE = ROOT / "tools" / "ci" / "export_size_report.py"
ONDEMAND_GD = ROOT / "project" / "scripts" / "art" / "ondemand_art.gd"
ART_PATHS = ROOT / "project" / "scripts" / "art" / "art_paths.gd"
CAP_BYTES = 400 * 1024 * 1024


def _fail(fails: list[str], msg: str) -> None:
    fails.append(msg)


def _glob_to_re(pattern: str) -> re.Pattern[str]:
    out: list[str] = []
    for ch in pattern:
        if ch == "*":
            out.append(".*")
        elif ch == "?":
            out.append(".")
        else:
            out.append(re.escape(ch))
    return re.compile("^" + "".join(out) + "$")


def _android_excludes() -> list[str]:
    text = PRESETS.read_text(encoding="utf-8")
    blocks = re.split(r"(?=^\[preset\.\d+\]\s*$)", text, flags=re.M)
    for block in blocks:
        if not re.search(r'^platform="Android"', block, re.M):
            continue
        m_ex = re.search(r'^exclude_filter="([^"]*)"', block, re.M)
        if not m_ex:
            raise SystemExit("Android preset missing exclude_filter")
        return [p.strip() for p in m_ex.group(1).split(",") if p.strip()]
    raise SystemExit("Android preset not found in export_presets.cfg")


def _matches(rel: str, patterns: list[str]) -> bool:
    compiled = [_glob_to_re(p) for p in patterns]
    return any(cre.match(rel) for cre in compiled)


def check_manifest_shape(data: dict, fails: list[str]) -> None:
    if data.get("version", "").find("ondemand-") < 0:
        _fail(fails, "ondemand-assets.json version must start with ondemand-")
    cap = data.get("cap") or {}
    if not isinstance(cap, dict):
        _fail(fails, "cap must be an object")
        return
    if cap.get("hard_bytes") != CAP_BYTES:
        _fail(fails, f"cap.hard_bytes must be {CAP_BYTES}")
    if cap.get("source_status") != "UNDER":
        _fail(fails, "cap.source_status must be UNDER (source estimate closeout)")
    if cap.get("h_i_user_only") is not True:
        _fail(fails, "cap.h_i_user_only must be true")
    if cap.get("forbid_quality_cut_to_pass") is not True:
        _fail(fails, "cap.forbid_quality_cut_to_pass must be true")
    fb = data.get("fallback_policy") or {}
    if fb.get("missing_large_or_master") != "medium":
        _fail(fails, "fallback_policy.missing_large_or_master must be medium")
    if fb.get("unit_tier") != "medium":
        _fail(fails, "fallback_policy.unit_tier must be medium")
    deferred = data.get("deferred_classes") or []
    if len(deferred) < 5:
        _fail(fails, f"deferred_classes too thin ({len(deferred)})")
    critical = data.get("always_packed_critical") or []
    if len(critical) < 4:
        _fail(fails, f"always_packed_critical too thin ({len(critical)})")
    y2 = data.get("year2_not_in_scope") or []
    joined = " ".join(str(x) for x in y2).lower()
    if "play asset delivery" not in joined and "cdn" not in joined:
        _fail(fails, "year2_not_in_scope must mention PAD/CDN out of scope")


def check_deferred_vs_presets(data: dict, android_ex: list[str], fails: list[str]) -> None:
    missing: list[str] = []
    for cls in data.get("deferred_classes") or []:
        for glob in cls.get("exclude_globs") or []:
            if glob not in android_ex:
                missing.append(f"{cls.get('id')}:{glob}")
    if missing:
        _fail(
            fails,
            "Android exclude_filter missing deferred globs from manifest:\n  - "
            + "\n  - ".join(missing[:20]),
        )
    # medium_only bank hard needles
    for needle in (
        "assets/art/portraits/genome/bank/*.small.webp",
        "assets/art/portraits/genome/bank/*_????????????????.webp",
    ):
        if needle not in android_ex:
            _fail(fails, f"Android exclude missing medium_only needle {needle!r}")


def check_critical_not_excluded(data: dict, android_ex: list[str], fails: list[str]) -> None:
    for cls in data.get("always_packed_critical") or []:
        if not cls.get("must_not_match_android_exclude", True):
            continue
        for rel in cls.get("paths") or []:
            path = PROJECT / rel
            if not path.is_file():
                _fail(fails, f"critical path missing on disk: {rel}")
                continue
            if _matches(rel, android_ex):
                _fail(fails, f"critical path excluded on Android: {rel}")
        for glob in cls.get("globs") or []:
            # Probe live files under the directory that owns the glob.
            prefix = glob.split("*", 1)[0]
            if prefix.endswith("/") or (PROJECT / prefix.rstrip("/")).is_dir():
                parent = PROJECT / prefix.rstrip("/")
            else:
                parent = PROJECT / Path(prefix).parent
            if not parent.is_dir():
                _fail(fails, f"critical glob parent missing: {glob} -> {parent}")
                continue
            cre = _glob_to_re(glob)
            hits = 0
            excluded_hits = 0
            for path in parent.iterdir():
                if not path.is_file():
                    continue
                rel = path.relative_to(PROJECT).as_posix()
                if not cre.match(rel):
                    continue
                hits += 1
                if _matches(rel, android_ex):
                    excluded_hits += 1
                    if excluded_hits <= 3:
                        _fail(fails, f"critical glob file excluded: {rel} ({cls.get('id')})")
            if hits == 0:
                _fail(fails, f"critical glob matched zero files: {glob}")


def check_runtime_helpers(fails: list[str]) -> None:
    if not ONDEMAND_GD.is_file():
        _fail(fails, "missing project/scripts/art/ondemand_art.gd")
        return
    body = ONDEMAND_GD.read_text(encoding="utf-8")
    for needle in (
        "class_name CKOnDemandArt",
        "resolve_pack_safe",
        "load_pack_safe",
        "FALLBACK_TIER",
        "ondemand-assets.json",
        "TIER_MEDIUM",
    ):
        if needle not in body:
            _fail(fails, f"ondemand_art.gd missing {needle!r}")
    if not ART_PATHS.is_file():
        _fail(fails, "missing art_paths.gd")
        return
    ap = ART_PATHS.read_text(encoding="utf-8")
    for needle in ("_tier_candidates", "UNIT_TIER", "TIER_MEDIUM", "pack_excluded"):
        if needle not in ap:
            _fail(fails, f"art_paths.gd missing on-demand seam {needle!r}")


def check_export_cap_under(fails: list[str]) -> dict[str, str]:
    """Re-run size report; require PASS + Android UNDER + medium_only."""
    markers: dict[str, str] = {}
    if not EXPORT_SIZE.is_file():
        _fail(fails, "missing export_size_report.py")
        return markers
    try:
        proc = subprocess.run(
            [sys.executable, str(EXPORT_SIZE)],
            cwd=str(ROOT),
            capture_output=True,
            text=True,
            timeout=180,
        )
    except Exception as exc:  # noqa: BLE001
        _fail(fails, f"export_size_report failed: {exc}")
        return markers
    out = (proc.stdout or "") + (proc.stderr or "")
    if "EXPORT SIZE PASS" not in out:
        _fail(fails, "export_size_report did not PASS:\n" + out[-500:])
    if "EXPORT ANDROID_BANK_CONTRACT medium_only=1" not in out:
        _fail(fails, "medium_only=1 contract missing from export_size_report")
    m = re.search(r"EXPORT CAP_STATUS Android (UNDER|OVER) (\d+)", out)
    if not m:
        _fail(fails, "missing EXPORT CAP_STATUS Android line")
        return markers
    markers["status"] = m.group(1)
    markers["bytes"] = m.group(2)
    if m.group(1) != "UNDER":
        _fail(
            fails,
            f"Android source CAP must be UNDER for on-demand closeout "
            f"(got OVER {m.group(2)}); do not use H/I quality cuts to pass",
        )
    return markers


def check_manifest_bytes_align(data: dict, markers: dict[str, str], fails: list[str]) -> None:
    if not markers:
        return
    cap = data.get("cap") or {}
    want = cap.get("source_bytes_android")
    if want is None:
        return
    if str(want) != markers.get("bytes"):
        _fail(
            fails,
            f"manifest cap.source_bytes_android={want} != live report {markers.get('bytes')}",
        )


def check_docs_mention(fails: list[str]) -> None:
    budget = ROOT / "docs/store/package-budget.md"
    if not budget.is_file():
        _fail(fails, "missing package-budget.md")
        return
    body = budget.read_text(encoding="utf-8")
    for needle in (
        "ondemand-assets.json",
        "store_ondemand_check",
        "CAP_STATUS",
        "UNDER",
        "禁 H/I",
    ):
        if needle not in body:
            _fail(fails, f"package-budget.md missing {needle!r}")
    record = ROOT / "docs/store/export-paths-verification-record.md"
    if record.is_file():
        rb = record.read_text(encoding="utf-8")
        if "CAP_STATUS Android UNDER" not in rb and "EXPORT CAP_STATUS Android UNDER" not in rb:
            _fail(fails, "export-paths-verification-record.md must record Android UNDER")
        if "Android OVER" in rb and "Android UNDER" not in rb:
            _fail(fails, "verification record still claims Android OVER without UNDER")


def main() -> int:
    fails: list[str] = []
    if not MANIFEST.is_file():
        print("FAIL store_ondemand_check: missing docs/store/ondemand-assets.json")
        return 1
    if MANIFEST.stat().st_size < 1500:
        _fail(fails, f"ondemand-assets.json too thin ({MANIFEST.stat().st_size})")
    try:
        data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"FAIL store_ondemand_check: bad JSON: {exc}")
        return 1
    android_ex = _android_excludes()
    check_manifest_shape(data, fails)
    check_deferred_vs_presets(data, android_ex, fails)
    check_critical_not_excluded(data, android_ex, fails)
    check_runtime_helpers(fails)
    markers = check_export_cap_under(fails)
    check_manifest_bytes_align(data, markers, fails)
    check_docs_mention(fails)
    if fails:
        print("FAIL store_ondemand_check:")
        for line in fails:
            print(" -", line)
        return 1
    print("STORE ONDEMAND PASS")
    if markers:
        print(
            f"STORE ONDEMAND CAP Android {markers['status']} {markers['bytes']} "
            f"(source estimate; APK measured separately; H/I user-only)"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
