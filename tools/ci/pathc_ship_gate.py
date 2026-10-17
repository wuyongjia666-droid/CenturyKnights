#!/usr/bin/env python3
"""Path C shipping gate (Opus #299 tightening, 2026-10-16).

Fails when:
  * any file under project/assets is > 5 MB, or any GLB there has > 100k triangles;
  * a LOOK source leaks into the export set (docs/art/review is outside project/, so a LOOK
    path inside project/ means someone copied a master in: pathc_native / hunyuan_noreduce /
    *_texture_pbr_* / any GLB whose sha256 is listed in PATHC_MASTERS_MANIFEST.json);
  * a docs/art/review GLB is tracked by git (masters live in external storage);
  * pawn §7 option A budget (user chose A on 2026-10-17, docs/design/pawn-redesign-opus.md §7.3/§7.4):
    every pathc_ship / pathc_weapons GLB <= 15k tris, <= 1.0 MB, 1 material, <= 1 texture,
    texture edge <= 512, JPG or WebP; pathc_ship + pathc_weapons total <= 45 MB.
Only git-tracked files are scanned (review P2-2); falls back to a directory walk without git.
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
WEAPONS = ASSETS / "models" / "board" / "pathc_weapons"
# §7 option A (2026-10-17): relaxed to the Path C refined look the user approved.
PIECE_TRIS_MAX = 15_000
PIECE_BYTES_MAX = 1.0 * MB
PIECE_TEXTURES_MAX = 1
TEXTURE_EDGE_MAX = 512
PAWN_TOTAL_MAX = 45 * MB
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
    if b[:4] == b"RIFF" and b[8:12] == b"WEBP":
        kind = b[12:16]
        if kind == b"VP8X":
            return 1 + int.from_bytes(b[24:27], "little"), 1 + int.from_bytes(b[27:30], "little")
        if kind == b"VP8L":
            v = int.from_bytes(b[21:25], "little")
            return 1 + (v & 0x3FFF), 1 + ((v >> 14) & 0x3FFF)
        if kind == b"VP8 ":
            w, h = struct.unpack("<HH", b[26:30])
            return w & 0x3FFF, h & 0x3FFF
        return 0, 0
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


_ASSET_FILES: list[Path] | None = None


def asset_files() -> list[Path]:
    global _ASSET_FILES
    if _ASSET_FILES is None:
        _ASSET_FILES = _list_asset_files()
    return _ASSET_FILES


def _list_asset_files() -> list[Path]:
    try:
        out = subprocess.run(["git", "ls-files", "-z", "project/assets"], cwd=ROOT, capture_output=True, check=True).stdout
        files = [ROOT / x for x in out.decode("utf-8").split("\0") if x]
        if files:
            return files
    except (OSError, subprocess.CalledProcessError):
        pass
    return list(ASSETS.rglob("*"))


def tracked_set() -> set[Path]:
    return {f.resolve() for f in asset_files()}


def pawn_glbs() -> list[Path]:
    tracked = tracked_set()
    out: list[Path] = []
    for d in (SHIP, WEAPONS):
        if d.is_dir():
            out += [f for f in sorted(d.glob("*.glb")) if f.resolve() in tracked]
    return out


def main() -> int:
    errs: list[str] = []
    look_hashes = set()
    if MANIFEST.is_file():
        look_hashes = {m["sha256"] for m in json.loads(MANIFEST.read_text(encoding="utf-8")).get("masters", [])}
    for f in asset_files():
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
    tracked = tracked_set()
    for d in (SHIP, WEAPONS):
        if d.is_dir():
            total += sum(f.stat().st_size for f in d.iterdir() if f.is_file() and f.suffix != ".import" and f.resolve() in tracked)
    for d in (SHIP, WEAPONS):
        if d.is_dir():
            for g in sorted(d.glob("*.gltf")):
                errs.append(f"{d.name}/{g.name}: ship pieces must be .glb (embedded), not .gltf")
    for f in pawn_glbs():
        sz = f.stat().st_size
        info = glb_info(f)
        name = f"{f.parent.name}/{f.name}"
        if info["tris"] > PIECE_TRIS_MAX:
            errs.append(f"{name}: {info['tris']} tris > {PIECE_TRIS_MAX}")
        if sz > PIECE_BYTES_MAX:
            errs.append(f"{name}: {sz} bytes > {int(PIECE_BYTES_MAX)}")
        if info["materials"] != 1:
            errs.append(f"{name}: {info['materials']} materials (want 1)")
        imgs = info.get("images", [])
        if len(imgs) > PIECE_TEXTURES_MAX:
            errs.append(f"{name}: {len(imgs)} textures > {PIECE_TEXTURES_MAX}")
        js, data = info.get("json", {}), info.get("data", b"")
        if data:
            n = struct.unpack_from("<I", data, 12)[0]
            bin_off = 20 + n + 8
            for im in imgs:
                if "bufferView" not in im:
                    errs.append(f"{name}: external texture uri (embed it)")
                    continue
                bv = js["bufferViews"][im["bufferView"]]
                b = data[bin_off + bv.get("byteOffset", 0): bin_off + bv.get("byteOffset", 0) + bv["byteLength"]]
                w, h = png_jpg_size(b)
                if w <= 0 or h <= 0:
                    errs.append(f"{name}: texture size unreadable ({im.get('mimeType')})")
                if max(w, h) > TEXTURE_EDGE_MAX:
                    errs.append(f"{name}: texture {w}x{h} > {TEXTURE_EDGE_MAX}")
                if im.get("mimeType") not in ("image/jpeg", "image/webp"):
                    errs.append(f"{name}: texture not compressed ({im.get('mimeType')})")
        print(f"PATHC SHIP {name} tris={info['tris']} bytes={sz} textures={len(imgs)}")
    print(f"PATHC PAWN TOTAL {total} bytes (budget {PAWN_TOTAL_MAX})")
    if total > PAWN_TOTAL_MAX:
        errs.append(f"pathc_ship + pathc_weapons total {total} > {PAWN_TOTAL_MAX}")
    for e in errs:
        print("PATHC SHIP GATE FAIL", e)
    if errs:
        return 1
    print("PATHC SHIP GATE PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
