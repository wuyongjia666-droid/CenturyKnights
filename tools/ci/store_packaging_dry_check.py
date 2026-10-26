#!/usr/bin/env python3
"""Store packaging dry-run gate: verify export/release wiring without building or uploading.

No Godot export, no Gradle, no store API, no secrets printed.
Exit 0 = packaging path is documented and scripts/presets/workflows look sane.
Also asserts Android medium-only bank excludes, CI lint wiring, and artifact path
alignment across build scripts / presets / export-paths.md / release.yml.
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

BUILD_SCRIPTS = [
    "scripts/build_android.sh",
    "scripts/build_windows.sh",
]
PRESETS = ROOT / "project" / "export_presets.cfg"
RELEASE_WF = ROOT / ".github" / "workflows" / "release.yml"
BUILD_WF = ROOT / ".github" / "workflows" / "build.yml"
GITIGNORE = ROOT / ".gitignore"
RUN_CI = ROOT / "scripts" / "run_ci.sh"
EXPORT_PATHS = ROOT / "docs" / "store" / "export-paths.md"

FORBIDDEN_IN_GIT = [
    re.compile(r".*\.keystore$", re.I),
    re.compile(r".*\.jks$", re.I),
    re.compile(r"signing\.local\.env$"),
]

WIN_OUT = "exports/CenturyKnights.exe"
AND_OUT = "exports/android/CenturyKnights-debug.apk"


def _fail(fails: list[str], msg: str) -> None:
    fails.append(msg)


def check_scripts(fails: list[str]) -> None:
    for rel in BUILD_SCRIPTS:
        path = ROOT / rel
        if not path.is_file():
            _fail(fails, f"missing {rel}")
            continue
        body = path.read_text(encoding="utf-8", errors="replace")
        if path.stat().st_size < 400:
            _fail(fails, f"too thin {rel}")
        if "godot" not in body.lower() and "GODOT" not in body:
            _fail(fails, f"{rel} does not reference Godot")
        if rel.endswith("build_android.sh"):
            if "--export-debug" not in body and "--export-release" not in body:
                _fail(fails, f"{rel} missing export flag")
            if "Android" not in body:
                _fail(fails, f"{rel} missing Android preset name")
            if "keystore" not in body.lower():
                _fail(fails, f"{rel} should document/handle keystore via env (not commit)")
            if AND_OUT not in body.replace("\\", "/"):
                # OUT=.../exports/android/CenturyKnights-debug.apk
                if "CenturyKnights-debug.apk" not in body:
                    _fail(fails, f"{rel} missing CenturyKnights-debug.apk out path")
        if rel.endswith("build_windows.sh"):
            if "Windows Desktop" not in body:
                _fail(fails, f"{rel} missing Windows Desktop preset")
            if "--export-release" not in body and "--export-debug" not in body:
                _fail(fails, f"{rel} missing export flag")
            if "CenturyKnights.exe" not in body:
                _fail(fails, f"{rel} missing CenturyKnights.exe out path")


def check_presets(fails: list[str]) -> None:
    if not PRESETS.is_file():
        _fail(fails, "missing project/export_presets.cfg")
        return
    body = PRESETS.read_text(encoding="utf-8", errors="replace")
    if 'name="Windows Desktop"' not in body:
        _fail(fails, "export_presets.cfg missing Windows Desktop")
    if 'name="Android"' not in body:
        _fail(fails, "export_presets.cfg missing Android")
    if f'export_path="../{WIN_OUT}"' not in body and 'export_path="../exports/CenturyKnights.exe"' not in body:
        _fail(fails, "export_presets.cfg Windows export_path mismatch")
    if 'export_path="../exports/android/CenturyKnights-debug.apk"' not in body:
        _fail(fails, "export_presets.cfg Android export_path mismatch")
    # Must not embed private keystore passwords.
    for m in re.finditer(r'password"\s*=\s*"([^"]*)"', body, re.I):
        val = m.group(1).strip()
        if val and val not in ("", "password"):
            _fail(fails, "export_presets.cfg looks like it embeds a keystore password")
            break
    # Android medium-only bank excludes (engineering contract).
    blocks = re.split(r"(?=^\[preset\.\d+\]\s*$)", body, flags=re.M)
    android_ex = ""
    for block in blocks:
        if re.search(r'^platform="Android"', block, re.M):
            m_ex = re.search(r'^exclude_filter="([^"]*)"', block, re.M)
            if m_ex:
                android_ex = m_ex.group(1)
            break
    if not android_ex:
        _fail(fails, "Android preset missing exclude_filter")
    else:
        need = [
            "assets/art/portraits/genome/bank/*.small.webp",
            "assets/art/portraits/genome/bank/*_????????????????.webp",
        ]
        for needle in need:
            if needle not in android_ex:
                _fail(fails, f"Android exclude_filter missing medium-only rule {needle!r}")


def check_workflows(fails: list[str]) -> None:
    if not RELEASE_WF.is_file():
        _fail(fails, "missing .github/workflows/release.yml")
        return
    rel_body = RELEASE_WF.read_text(encoding="utf-8", errors="replace")
    for needle in ("windows: true", "android: true", "gh release", "main-"):
        if needle not in rel_body:
            _fail(fails, f"release.yml missing {needle!r}")
    for needle in ("CenturyKnights-android-", "SHA256-", "*.zip", "*.apk"):
        if needle not in rel_body:
            _fail(fails, f"release.yml missing artifact marker {needle!r}")
    if not BUILD_WF.is_file():
        _fail(fails, "missing .github/workflows/build.yml")
        return
    build_body = BUILD_WF.read_text(encoding="utf-8", errors="replace")
    if "build_windows" not in build_body and "Windows" not in build_body:
        _fail(fails, "build.yml does not mention Windows build path")
    if "build_android" not in build_body and "Android" not in build_body:
        _fail(fails, "build.yml does not mention Android build path")
    if "CenturyKnights-debug.apk" not in build_body:
        _fail(fails, "build.yml missing CenturyKnights-debug.apk artifact path")
    if "CenturyKnights-windows-" not in build_body and "windows-zip" not in build_body:
        _fail(fails, "build.yml missing Windows zip naming")


def check_gitignore_secrets(fails: list[str]) -> None:
    if not GITIGNORE.is_file():
        _fail(fails, "missing .gitignore")
        return
    gi = GITIGNORE.read_text(encoding="utf-8", errors="replace")
    if "signing.local.env" not in gi and "keystore" not in gi.lower():
        _fail(fails, ".gitignore should ignore keystore / signing.local.env")

    try:
        tracked = subprocess.check_output(
            ["git", "-C", str(ROOT), "ls-files"],
            text=True,
            timeout=60,
        ).splitlines()
    except Exception as exc:  # noqa: BLE001
        _fail(fails, f"git ls-files failed: {exc}")
        return
    for rel in tracked:
        for cre in FORBIDDEN_IN_GIT:
            if cre.search(rel):
                _fail(fails, f"secret-like path tracked: {rel}")


def check_store_docs(fails: list[str]) -> None:
    # 商店页实质门槛（字节）；主 listing 更高，工程对照页次之——禁止用「降门槛」偷工
    floors = {
        "docs/store/play-listing-full.md": 4500,
        "docs/store/ms-store-listing-full.md": 3500,
        "docs/store/privacy-policy-draft.md": 2800,
        "docs/store/listing-copy-zh.md": 2800,
        "docs/store/age-rating-draft.md": 1600,
        "docs/store/export-paths.md": 1400,
        "docs/store/CHECKLIST.md": 1200,
        "docs/store/screenshots-checklist.md": 1400,
        "docs/store/data-safety-draft.md": 1400,
        "docs/store/README.md": 1400,
        "docs/store/crash-perf-gates.md": 1400,
        "docs/store/package-budget.md": 1200,
        "docs/store/support-contact-draft.md": 1200,
        "docs/store/listing-copy-en.md": 1400,
        "docs/store/privacy-verification-record.md": 1600,
        "docs/store/age-rating-verification-record.md": 1400,
        "docs/store/export-paths-verification-record.md": 1600,
        "docs/store/data-safety-verification-record.md": 1600,
        "docs/store/support-contact-verification-record.md": 1600,
    }
    for rel, floor in floors.items():
        path = ROOT / rel
        if not path.is_file():
            _fail(fails, f"missing {rel}")
        elif path.stat().st_size < floor:
            _fail(fails, f"too thin {rel} ({path.stat().st_size} bytes < {floor})")
    play = ROOT / "docs/store/play-listing-full.md"
    if play.is_file():
        body = play.read_text(encoding="utf-8")
        for phrase in ("完整说明", "不付费", "AAB", "无内购"):
            if phrase not in body:
                _fail(fails, f"play-listing-full.md missing {phrase!r}")
    if EXPORT_PATHS.is_file():
        ep = EXPORT_PATHS.read_text(encoding="utf-8")
        for needle in (WIN_OUT, AND_OUT, "build_android.sh", "build_windows.sh", "release.yml"):
            if needle not in ep:
                _fail(fails, f"export-paths.md missing {needle!r}")


def check_ci_wiring(fails: list[str]) -> None:
    if not RUN_CI.is_file():
        _fail(fails, "missing scripts/run_ci.sh")
        return
    body = RUN_CI.read_text(encoding="utf-8", errors="replace")
    for needle in (
        "export_size_report.py",
        "store_prep_check.py",
        "store_verify_records_check.py",
        "store_packaging_dry_check.py",
    ):
        if needle not in body:
            _fail(fails, f"run_ci.sh lint path missing {needle}")


def check_export_size_contract(fails: list[str]) -> None:
    """Re-run size report; require PASS marker + Android medium_only contract line."""
    report = ROOT / "tools/ci/export_size_report.py"
    if not report.is_file():
        _fail(fails, "missing tools/ci/export_size_report.py")
        return
    try:
        proc = subprocess.run(
            [sys.executable, str(report)],
            cwd=str(ROOT),
            capture_output=True,
            text=True,
            timeout=180,
        )
    except Exception as exc:  # noqa: BLE001
        _fail(fails, f"export_size_report failed: {exc}")
        return
    out = (proc.stdout or "") + (proc.stderr or "")
    if "EXPORT SIZE PASS" not in out:
        _fail(
            fails,
            "export_size_report did not print EXPORT SIZE PASS:\n" + out[-600:],
        )
    if "EXPORT ANDROID_BANK_CONTRACT medium_only=1" not in out:
        _fail(fails, "export_size_report missing Android medium_only=1 contract")
    if "EXPORT CAP_STATUS Android" not in out:
        _fail(fails, "export_size_report missing EXPORT CAP_STATUS Android line")


def main() -> int:
    fails: list[str] = []
    check_scripts(fails)
    check_presets(fails)
    check_workflows(fails)
    check_gitignore_secrets(fails)
    check_store_docs(fails)
    check_ci_wiring(fails)
    check_export_size_contract(fails)
    if fails:
        print("FAIL store_packaging_dry_check:")
        for line in fails:
            print(" -", line)
        return 1
    print("STORE PACKAGING DRY PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
