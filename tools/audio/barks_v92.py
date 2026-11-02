#!/usr/bin/env python3
"""Non-verbal barks for CenturyKnights.

Sixteen cues: gender (m/f) x age band x breath/shout. A shout falls a
minor third. A breath stays on one pitch and lets the air through.
No sampled voices. Re-running with the fixed seed matches decoded PCM
fingerprints in the catalog (Ogg container bytes may differ across encoders).
"""

from __future__ import annotations

import argparse
import importlib
import json
import math
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def ensure_runtime() -> None:
    try:
        importlib.import_module("numpy")
    except ImportError:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "--user", "numpy==2.4.4"])
        import site
        site.addsitedir(site.getusersitepackages())
        importlib.invalidate_caches()
        importlib.import_module("numpy")
    if shutil.which("ffmpeg") is None:
        subprocess.check_call(["sudo", "apt-get", "update", "-qq"])
        subprocess.check_call(["sudo", "apt-get", "install", "-y", "-qq", "ffmpeg"])


ensure_runtime()

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import engine

SR = engine.SR
GENDERS = ("m", "f")
BANDS = ("child", "youth", "adult", "elder")
KINDS = ("breath", "shout")

# Fundamental Hz, formant tilt, air.
VOICE = {
    ("m", "child"): (280.0, 180.0, 0.18),
    ("f", "child"): (300.0, 220.0, 0.16),
    ("m", "youth"): (165.0, 40.0, 0.14),
    ("f", "youth"): (240.0, 140.0, 0.15),
    ("m", "adult"): (124.0, 0.0, 0.12),
    ("f", "adult"): (210.0, 90.0, 0.14),
    ("m", "elder"): (108.0, -20.0, 0.28),
    ("f", "elder"): (185.0, 60.0, 0.26),
}


def color(noise: np.ndarray) -> np.ndarray:
    kernel = np.exp(-np.arange(48, dtype=np.float64) / 7.0)
    kernel /= np.sum(kernel)
    return np.convolve(noise, kernel, mode="same")


def voiced(n: int, f0: float, tilt: float, air: float, salt: int, decay: float) -> np.ndarray:
    t = np.arange(n, dtype=np.float64) / SR
    vib = (0.012 if air > 0.22 else 0.006) * np.sin(2.0 * math.pi * 4.6 * t)
    freq = f0 * (1.0 + vib)
    phase = 2.0 * math.pi * np.cumsum(freq) / SR
    harm = (
        np.sin(phase)
        + 0.42 * np.sin(2.0 * phase)
        + 0.18 * np.sin(3.0 * phase)
        + 0.07 * np.sin(4.0 * phase)
    )
    f1 = 520.0 + tilt
    f2 = 1500.0 + tilt * 1.8
    harm = harm + 0.28 * np.sin(2.0 * math.pi * f1 * t) * np.exp(-t * 5.0)
    harm = harm + 0.12 * np.sin(2.0 * math.pi * f2 * t) * np.exp(-t * 7.0)
    env = np.exp(-t * decay)
    attack = int(0.02 * SR)
    env[:attack] *= np.linspace(0.0, 1.0, attack)
    air_sig = color(engine._hash_noise(n, salt)) * air * np.exp(-t * (2.2 + decay * 0.15))
    return harm * env + air_sig


def render(gender: str, band: str, kind: str) -> tuple:
    f0, tilt, air = VOICE[(gender, band)]
    salt = engine.track_seed("bark_%s_%s_%s" % (gender, band, kind))
    if kind == "shout":
        n = int(0.46 * SR)
        mix = engine.Mix(n)
        first = int(0.22 * SR)
        mix.add(0, voiced(first, f0, tilt, air * 0.7, salt, 3.2), -0.08 if gender == "m" else 0.08)
        f_fall = f0 * (2.0 ** (-3.0 / 12.0))
        mix.add(first, voiced(n - first, f_fall, tilt, air * 0.8, salt + 9, 4.5) * 0.85, 0.05)
        mix.add(0, engine.synth("celesta", f0 * 1.5, int(0.28 * SR)) * 0.12, 0.2)
    else:
        n = int(0.64 * SR)
        mix = engine.Mix(n)
        mix.add(0, voiced(n, f0 * 0.98, tilt, max(air, 0.34), salt, 1.6) * 0.75, 0.0)
        mix.add(int(0.05 * SR), engine.synth("flute", f0, int(0.4 * SR)) * 0.18, 0.12)
    left, right = engine.finish(mix.L, mix.R, "room")
    fade = 80
    left[-fade:] *= np.linspace(1.0, 0.0, fade)
    right[-fade:] *= np.linspace(1.0, 0.0, fade)
    return left, right


def file_id(gender: str, band: str, kind: str) -> str:
    return "bark_%s_%s_%s" % (gender, band, kind)


def planned() -> list:
    rows = []
    for gender in GENDERS:
        for band in BANDS:
            for kind in KINDS:
                rows.append(file_id(gender, band, kind))
    return rows


def write_id(out_dir: Path, ident: str) -> Path:
    gender, band, kind = ident.split("_")[1:]
    left, right = render(gender, band, kind)
    path = out_dir / ("%s.ogg" % ident)
    engine.write_ogg(path, left, right, engine.track_seed(ident), quality=1)
    return path


def file_meta(path: Path) -> dict:
    audio = engine.decode_ogg_f32(path)
    meta = engine.catalog_audio_meta(path, audio)
    print(
        "%s  rms %6.2f  samples %d  bytes %d"
        % (path.name, meta["rms_db"], meta["samples"], meta["bytes"])
    )
    return meta


def build(out_dir: Path) -> dict:
    out_dir.mkdir(parents=True, exist_ok=True)
    catalog = {"seed": engine.SEED, "sample_rate": SR, "verify": "pcm_v1", "files": {}}
    for ident in planned():
        path = write_id(out_dir, ident)
        catalog["files"][path.name] = file_meta(path)
    return catalog


def catalog_from_disk(out_dir: Path) -> dict:
    catalog = {"seed": engine.SEED, "sample_rate": SR, "verify": "pcm_v1", "files": {}}
    for ident in planned():
        path = out_dir / ("%s.ogg" % ident)
        if not path.is_file():
            raise SystemExit("missing %s" % path)
        catalog["files"][path.name] = file_meta(path)
    return catalog


def assert_fingerprint(name: str, expected: dict, actual: dict, label: str) -> None:
    if not engine.fingerprints_match(expected, actual):
        raise SystemExit(
            "%s %s samples %s/%s rms %s/%s pcm %s/%s"
            % (
                label,
                name,
                expected.get("samples"),
                actual.get("samples"),
                expected.get("rms_db"),
                actual.get("rms_db"),
                str(expected.get("pcm_sha256", ""))[:12],
                str(actual.get("pcm_sha256", ""))[:12],
            )
        )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="")
    parser.add_argument("--verify", action="store_true")
    parser.add_argument("--catalog-from-disk", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    out = Path(args.out) if args.out else root / "project" / "assets" / "sfx" / "barks"
    if args.catalog_from_disk:
        catalog = catalog_from_disk(out)
        (out / "catalog_barks.json").write_text(json.dumps(catalog, indent=2, sort_keys=True) + "\n")
        total = sum(item["bytes"] for item in catalog["files"].values())
        print("files %d bytes %d" % (len(catalog["files"]), total))
        return
    if args.verify:
        tmp = Path(tempfile.mkdtemp(prefix="bark-verify-"))
        try:
            fresh = build(tmp)
            committed = json.loads((out / "catalog_barks.json").read_text())
            for name, meta in fresh["files"].items():
                if name not in committed["files"]:
                    raise SystemExit("MISSING %s" % name)
                assert_fingerprint(name, committed["files"][name], meta, "MISMATCH")
                disk = file_meta(out / name)
                assert_fingerprint(name, committed["files"][name], disk, "DISK")
        finally:
            shutil.rmtree(tmp)
        print("BARK VERIFY PASS")
        return
    catalog = build(out)
    (out / "catalog_barks.json").write_text(json.dumps(catalog, indent=2, sort_keys=True) + "\n")
    total = sum(item["bytes"] for item in catalog["files"].values())
    print("files %d bytes %d" % (len(catalog["files"]), total))


if __name__ == "__main__":
    main()
