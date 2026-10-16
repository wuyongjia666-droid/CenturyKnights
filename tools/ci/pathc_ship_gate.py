#!/usr/bin/env python3
"""Path C shipping gate (Opus #299 tightening, 2026-10-16).

Fails when:
  * any file under project/assets is > 5 MB, or any GLB there has > 100k triangles;
  * a LOOK source leaks into the export set (docs/art/review is outside project/, so a LOOK
    path inside project/ means someone copied a master in: pathc_native / hunyuan_noreduce /
    *_texture_pbr_* / any GLB whose sha256 is listed in PATHC_MASTERS_MANIFEST.json);
  * a docs/art/review GLB is tracked by git (masters live in external storage);
  * pathc_ship pieces break budget: key cast <= 15k tris & <= 1.0 MB, others <= 12k & <= 0.6 MB,
    1 material, albedo <= 512, dir total <= 12 MB.
"""
from __future__ import annotations
import hashlib, json, struct, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "project" / "assets"
SHIP = ASSETS / "models" / "board" / "pathc_ship"
MANIFEST = ROOT / "docs" / "art" / "review" / "PATHC_MASTERS_MANIFEST.json"
MB = 1024 * 1024
FILE_MAX = 5 * MB
TRIS_MAX = 100_000
KEY_CAST = {"cast_leader", "hunter_m", "hunter_f", "bandit_chief"}
LOOK_MARKERS = ("pathc_native", "hunyuan_noreduce", "_texture_pbr_", "docs/art/review")


def glb_info(p: Path) -> dict:
    data = p.read_bytes()
    if data[:4] != b"glTF":
        return {"tris": 0, "materials": 0, "images": []}
    n = struct.unpack_from("<I", data, 12)[0]
    js = json.loads(data[20:20 + n])
    acc = js.get("accessors", [])
    tris = 0
    for m in js.get("meshes", []):
        for pr in m.get("primitives", []):
            if pr.get("mode", 4) != 4:
                continue
            if "indices" in pr:
                tris += acc[pr["indices"]]["count"] // 3
            else:
                tris += acc[pr["attributes"]["POSITION"]]["count"] // 3
    return {"tris": tris, "materials": len(js.get("materials", [])), "images": js.get("images", []), "json": js, "data": data}


def png_jpg_size(b: bytes) -> tuple[int, int]:
    if b[:8] == b"\x89PNG\r\n\x1a\n":
        return struct.unpack(">II", b[16:24])
    i = 2
    while i < len(b):
        if b[i] != 0xFF:
            i += 1
            continue
        mk = b[i + 1]
        if mk in (0xC0, 0xC1, 0xC2):
            h, w = struct.unpack(">HH", b[i + 5:i + 9])
            return w, h
        i += 2 + struct.unpack(">H", b[i + 2:i + 4])[0]
    return 0, 0


def main() -> int:
    errs: list[str] = []
    look_hashes = set()
    if MANIFEST.is_file():
        look_hashes = {m["sha256"] for m in json.loads(MANIFEST.read_text(encoding="utf-8")).get("masters", [])}
    for f in ASSETS.rglob("*"):
        if not f.is_file() or f.suffix == ".import":
            continue
        rel = f.relative_to(ROOT).as_posix()
        if any(k in rel for k in LOOK_MARKERS):
            errs.append(f"LOOK source in export tree: {rel}")
        sz = f.stat().st_size
        if sz > FILE_MAX:
            errs.append(f"file > 5MB: {rel} ({sz})")
        if f.suffix.lower() == ".glb":
            if hashlib.sha256(f.read_bytes()).hexdigest() in look_hashes:
                errs.append(f"LOOK master copied into assets: {rel}")
            t = glb_info(f)["tris"]
            if t > TRIS_MAX:
                errs.append(f"glb > 100k tris: {rel} ({t})")
    try:
        tracked = subprocess.run(["git", "ls-files", "docs/art/review"], cwd=ROOT, capture_output=True, text=True, check=True).stdout.split()
        for t in tracked:
            if t.endswith(".glb"):
                errs.append(f"LOOK GLB tracked in git (use external store + manifest): {t}")
    except (OSError, subprocess.CalledProcessError):
        pass
    total = 0
    if SHIP.is_dir():
        for f in sorted(SHIP.glob("*.glb")):
            sz = f.stat().st_size
            total += sz
            info = glb_info(f)
            key = f.stem in KEY_CAST
            tmax, smax = (15_000, 1.0 * MB) if key else (12_000, 0.6 * MB)
            if info["tris"] > tmax:
                errs.append(f"pathc_ship {f.name}: {info['tris']} tris > {tmax}")
            if sz > smax:
                errs.append(f"pathc_ship {f.name}: {sz} bytes > {int(smax)}")
            if info["materials"] != 1:
                errs.append(f"pathc_ship {f.name}: {info['materials']} materials (want 1)")
            js, data = info["json"], info["data"]
            n = struct.unpack_from("<I", data, 12)[0]
            bin_off = 20 + n + 8
            for im in js.get("images", []):
                bv = js["bufferViews"][im["bufferView"]]
                b = data[bin_off + bv.get("byteOffset", 0): bin_off + bv.get("byteOffset", 0) + bv["byteLength"]]
                w, h = png_jpg_size(b)
                if max(w, h) > 512:
                    errs.append(f"pathc_ship {f.name}: texture {w}x{h} > 512")
                if im.get("mimeType") not in ("image/jpeg", "image/webp"):
                    errs.append(f"pathc_ship {f.name}: texture not compressed ({im.get('mimeType')})")
            print(f"PATHC SHIP {f.name} tris={info['tris']} bytes={sz}")
        if total > 12 * MB:
            errs.append(f"pathc_ship total {total} > 12MB")
    for e in errs:
        print("PATHC SHIP GATE FAIL", e)
    if errs:
        return 1
    print("PATHC SHIP GATE PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
