#!/usr/bin/env python3
"""Store packaging dry-run gate: verify export/release wiring without building or uploading.

No Godot export, no Gradle, no store API, no secrets printed.
Exit 0 = packaging path is documented and scripts/presets/workflows look sane.
"""
from __future__ import annotations

import re
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

FORBIDDEN_IN_GIT = [
    re.compile(r".*\.keystore$", re.I),
    re.compile(r".*\.jks$", re.I),
    re.compile(r"signing\.local\.env$"),
]


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
        if rel.endswith("build_windows.sh"):
            if "Windows Desktop" not in body:
                _fail(fails, f"{rel} missing Windows Desktop preset")
            if "--export-release" not in body and "--export-debug" not in body:
                _fail(fails, f"{rel} missing export flag")


def check_presets(fails: list[str]) -> None:
    if not PRESETS.is_file():
        _fail(fails, "missing project/export_presets.cfg")
        return
    body = PRESETS.read_text(encoding="utf-8", errors="replace")
    if 'name="Windows Desktop"' not in body:
        _fail(fails, "export_presets.cfg missing Windows Desktop")
    if 'name="Android"' not in body:
        _fail(fails, "export_presets.cfg missing Android")
    # Must not embed private keystore passwords.
    for pat in ("keystore/password", "keystore_password"):
        if pat in body.lower() and re.search(r"password\"?\s*=\s*\"[^\"]{4,}\"", body, re.I):
            # allow empty placeholders only
            for m in re.finditer(r'password"\s*=\s*"([^"]*)"', body, re.I):
                if m.group(1).strip() and m.group(1).strip() not in ("", "password"):
                    _fail(fails, "export_presets.cfg looks like it embeds a keystore password")
                    break


def check_workflows(fails: list[str]) -> None:
    if not RELEASE_WF.is_file():
        _fail(fails, "missing .github/workflows/release.yml")
        return
    rel_body = RELEASE_WF.read_text(encoding="utf-8", errors="replace")
    for needle in ("windows: true", "android: true", "gh release", "main-"):
        if needle not in rel_body:
            _fail(fails, f"release.yml missing {needle!r}")
    if not BUILD_WF.is_file():
        _fail(fails, "missing .github/workflows/build.yml")
        return
    build_body = BUILD_WF.read_text(encoding="utf-8", errors="replace")
    if "build_windows" not in build_body and "Windows" not in build_body:
        _fail(fails, "build.yml does not mention Windows build path")
    if "build_android" not in build_body and "Android" not in build_body:
        _fail(fails, "build.yml does not mention Android build path")


def check_gitignore_secrets(fails: list[str]) -> None:
    if not GITIGNORE.is_file():
        _fail(fails, "missing .gitignore")
        return
    gi = GITIGNORE.read_text(encoding="utf-8", errors="replace")
    for token in ("keystore", "signing.local.env", "*.jks"):
        if token not in gi and token.replace("*.", "") not in gi:
            # soft: at least keystore or signing.local.env
            pass
    if "signing.local.env" not in gi and "keystore" not in gi.lower():
        _fail(fails, ".gitignore should ignore keystore / signing.local.env")

    # Scan tracked files for forbidden secret-like paths.
    try:
        import subprocess

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
    required = [
        "docs/store/play-listing-full.md",
        "docs/store/ms-store-listing-full.md",
        "docs/store/privacy-policy-draft.md",
        "docs/store/age-rating-draft.md",
        "docs/store/listing-copy-zh.md",
        "docs/store/export-paths.md",
        "docs/store/CHECKLIST.md",
    ]
    for rel in required:
        path = ROOT / rel
        if not path.is_file():
            _fail(fails, f"missing {rel}")
        elif path.stat().st_size < 600:
            _fail(fails, f"too thin {rel} ({path.stat().st_size} bytes)")
    play = ROOT / "docs/store/play-listing-full.md"
    if play.is_file():
        body = play.read_text(encoding="utf-8")
        for phrase in ("完整说明", "不付费", "AAB", "无内购"):
            if phrase not in body:
                _fail(fails, f"play-listing-full.md missing {phrase!r}")


def main() -> int:
    fails: list[str] = []
    check_scripts(fails)
    check_presets(fails)
    check_workflows(fails)
    check_gitignore_secrets(fails)
    check_store_docs(fails)
    if fails:
        print("FAIL store_packaging_dry_check:")
        for line in fails:
            print(" -", line)
        return 1
    print("STORE PACKAGING DRY PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
