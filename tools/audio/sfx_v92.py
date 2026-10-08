#!/usr/bin/env python3
"""Procedural weapon hits, footsteps, UI glass, and biome beds.

The lamp motif (scale degrees 0, 2, 4, 3, 1, 0) is the same one used by
compose_v92.py. Biome beds state it, answer it, then cadence. One-shots
are short glass or metal gestures, not noise loops.

Re-running with the fixed engine seed rewrites bit-identical files.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib
import json
import math
import shutil
import subprocess
import sys
import wave
from pathlib import Path


def ensure_runtime() -> None:
    """GitHub runners do not ship NumPy or ffmpeg. Pin the versions the score was encoded with."""
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
SEED = engine.SEED

SCALES = {
    "dorian": [0, 2, 3, 5, 7, 9, 10],
    "minor": [0, 2, 3, 5, 7, 8, 10],
    "major": [0, 2, 4, 5, 7, 9, 11],
    "mixolydian": [0, 2, 4, 5, 7, 9, 10],
    "lydian": [0, 2, 4, 6, 7, 9, 11],
    "phrygian": [0, 1, 3, 5, 7, 8, 10],
}
MOTIF = [0, 2, 4, 3, 1, 0]
MOTIF_RHYTHM = [1.0, 0.5, 1.0, 0.5, 1.0, 2.0]

WEAPONS = ["sword", "lance", "axe", "bow", "spell"]
TERRAINS = ["plain", "forest", "hill", "water", "bridge", "fort"]
UI_IDS = ["ui_hover", "ui_back", "ui_deny", "ui_open", "ui_close"]
BIOMES = [
    # id, root midi, scale, lead, space, bed color
    ("fort", 62, "dorian", "celesta", "room", "stone"),
    ("urban", 65, "mixolydian", "celesta", "room", "clock"),
    ("ford", 69, "minor", "flute", "hall", "water"),
    ("hill", 67, "mixolydian", "flute", "ice", "wind"),
    ("fog", 62, "minor", "flute", "hall", "mist"),
    ("nightcamp", 65, "major", "celesta", "room", "ember"),
    ("snow", 74, "dorian", "celesta", "ice", "air"),
    ("pass", 64, "minor", "flute", "ice", "wind"),
    ("harbor", 69, "dorian", "celesta", "hall", "tide"),
    ("plain", 67, "major", "flute", "dry", "field"),
    ("archive", 62, "dorian", "celesta", "room", "page"),
    ("forge", 62, "phrygian", "chime", "forge", "metal"),
    ("shrine", 65, "lydian", "chime", "hall", "bell"),
    ("marsh", 57, "phrygian", "flute", "room", "mire"),
]


def degree_midi(root: int, scale: str, degree: int, octave: int = 0) -> int:
    while degree < 0:
        degree += 7
        octave -= 1
    while degree > 6:
        degree -= 7
        octave += 1
    return int(root) + SCALES[scale][degree] + octave * 12


def fade_edges(sig: np.ndarray, fade: int) -> None:
    n = min(fade, sig.size // 2)
    if n <= 1:
        return
    sig[:n] *= np.linspace(0.0, 1.0, n)
    sig[-n:] *= np.linspace(1.0, 0.0, n)


def color_noise(n: int, salt: int, tone: str) -> np.ndarray:
    raw = engine._hash_noise(n, salt)
    if tone in ("water", "tide", "mire"):
        kernel = np.exp(-np.arange(180, dtype=np.float64) / 28.0)
    elif tone in ("wind", "air", "mist"):
        kernel = np.exp(-np.arange(40, dtype=np.float64) / 6.0)
    elif tone in ("metal", "stone", "clock"):
        kernel = np.exp(-np.arange(24, dtype=np.float64) / 3.0)
    else:
        kernel = np.exp(-np.arange(70, dtype=np.float64) / 12.0)
    kernel /= np.sum(kernel)
    return np.convolve(raw, kernel, mode="same")


def finish_oneshot(left: np.ndarray, right: np.ndarray, space: str) -> tuple:
    left, right = engine.finish(left, right, space)
    fade_edges(left, 64)
    fade_edges(right, 64)
    return left, right


def loop_finish(left: np.ndarray, right: np.ndarray, space: str) -> tuple:
    """Reverb the loop against itself so the join stays continuous."""
    n = left.size
    doubled_l = np.concatenate([left, left])
    doubled_r = np.concatenate([right, right])
    out_l, out_r = engine.finish(doubled_l, doubled_r, space)
    return out_l[n : n * 2].copy(), out_r[n : n * 2].copy()


def seal_loop(left: np.ndarray, right: np.ndarray, extra_l: np.ndarray, extra_r: np.ndarray) -> tuple:
    fade = extra_l.size
    ramp = np.linspace(0.0, math.pi / 2.0, fade)
    left = left.copy()
    right = right.copy()
    left[:fade] = extra_l * np.cos(ramp) + left[:fade] * np.sin(ramp)
    right[:fade] = extra_r * np.cos(ramp) + right[:fade] * np.sin(ramp)
    return left, right


def write_wav(path: Path, left: np.ndarray, right: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    interleaved = np.empty(left.size * 2, dtype=np.float64)
    interleaved[0::2] = np.clip(left, -1.0, 1.0)
    interleaved[1::2] = np.clip(right, -1.0, 1.0)
    pcm = np.round(interleaved * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(2)
        handle.setframerate(SR)
        handle.writeframes(pcm.tobytes())


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    digest.update(path.read_bytes())
    return digest.hexdigest()


def add_note(mix: engine.Mix, start: int, kind: str, midi: float, seconds: float, vel: float, pan: float) -> None:
    n = int(seconds * SR)
    if n < 8:
        return
    sig = engine.synth(kind, engine.midi_to_hz(midi), n) * vel
    mix.add(start, sig, pan)


def render_weapon(weapon: str, variant: int) -> tuple:
    length = {"sword": 0.42, "lance": 0.34, "axe": 0.48, "bow": 0.36, "spell": 0.70}[weapon]
    n = int(length * SR)
    mix = engine.Mix(n)
    salt = engine.track_seed("hit_%s_%d" % (weapon, variant))
    brightness = [1.15, 0.85, 0.62][variant]
    body = [0.35, 0.55, 0.8][variant]
    t = np.arange(n, dtype=np.float64) / SR
    if weapon == "sword":
        freq = 698.0 * (1.0 + 0.015 * variant)
        partials = ((1.0, 1.0, 7.0), (2.76, 0.42 * brightness, 11.0), (5.04, 0.18 * brightness, 16.0))
    elif weapon == "lance":
        freq = 988.0 * (1.0 - 0.02 * variant)
        partials = ((1.0, 0.9, 10.0), (3.0, 0.28 * brightness, 14.0), (6.2, 0.1 * brightness, 20.0))
    elif weapon == "axe":
        freq = 146.0 + 8.0 * variant
        partials = ((1.0, 1.0, 8.0), (2.02, 0.35, 12.0), (3.4, 0.12 * brightness, 18.0))
    elif weapon == "bow":
        freq = 523.0 + 18.0 * variant
        partials = ((1.0, 0.55, 9.0), (2.0, 0.16, 14.0))
    else:
        freq = engine.midi_to_hz(74 + [0, 3, 7][variant])
        partials = ((1.0, 0.7, 3.2), (2.76, 0.35, 5.5), (4.1, 0.16, 7.0))
    sig = np.zeros(n, dtype=np.float64)
    for ratio, gain, decay in partials:
        sig += gain * np.sin(2.0 * math.pi * freq * ratio * t) * np.exp(-t * decay)
    if weapon == "axe":
        sig += body * np.sin(2.0 * math.pi * (70.0 + variant * 6.0) * t) * np.exp(-t * 14.0)
    if weapon == "bow":
        sig += 0.55 * engine._hash_noise(n, salt) * np.exp(-t * 55.0)
    elif weapon == "spell":
        sig += 0.22 * engine.synth("celesta", engine.midi_to_hz(81 + variant), n) * np.exp(-t * 3.0)
    else:
        sig += (0.22 + 0.08 * body) * engine._hash_noise(n, salt) * np.exp(-t * (48.0 + 10.0 * brightness))
    mix.add(0, sig, -0.08 + 0.08 * variant)
    if weapon == "spell":
        add_note(mix, int(0.16 * SR), "celesta", 74 + [2, 4, 7][variant], 0.42, 0.55, 0.2)
    space = "ice" if weapon == "spell" else "forge" if weapon == "axe" else "dry"
    return finish_oneshot(mix.L, mix.R, space)


def render_step(terrain: str, variant: int) -> tuple:
    length = 0.26 if terrain != "water" else 0.34
    n = int(length * SR)
    mix = engine.Mix(n)
    salt = engine.track_seed("step_%s_%d" % (terrain, variant))
    t = np.arange(n, dtype=np.float64) / SR
    if terrain == "plain":
        sig = np.sin(2 * math.pi * (180 + 30 * variant) * t) * np.exp(-t * 28)
        sig += 0.35 * color_noise(n, salt, "field") * np.exp(-t * 40)
    elif terrain == "forest":
        sig = 0.7 * color_noise(n, salt, "field") * np.exp(-t * 18)
        sig += 0.25 * np.sin(2 * math.pi * (420 + 40 * variant) * t) * np.exp(-t * 22)
    elif terrain == "hill":
        sig = np.sin(2 * math.pi * (140 + 16 * variant) * t) * np.exp(-t * 20)
        sig += 0.45 * color_noise(n, salt, "stone") * np.exp(-t * 26)
    elif terrain == "water":
        sig = color_noise(n, salt, "water") * np.exp(-t * 8)
        sig += 0.2 * np.sin(2 * math.pi * (520 + 60 * variant) * t) * np.exp(-t * 16)
    elif terrain == "bridge":
        sig = np.sin(2 * math.pi * (240 + 28 * variant) * t) * np.exp(-t * 18)
        sig += 0.3 * np.sin(2 * math.pi * (480 + 20 * variant) * t) * np.exp(-t * 30)
    else:
        sig = np.sin(2 * math.pi * (96 + 8 * variant) * t) * np.exp(-t * 16)
        sig += 0.4 * color_noise(n, salt, "stone") * np.exp(-t * 34)
    mix.add(0, sig, -0.12 if variant == 0 else 0.12)
    return finish_oneshot(mix.L, mix.R, "dry")


def render_ui(ui_id: str) -> tuple:
    plans = {
        "ui_hover": [(0.0, 91, 0.09, 0.7)],
        "ui_back": [(0.0, 79, 0.12, 0.8), (0.10, 74, 0.16, 0.65)],
        "ui_deny": [(0.0, 64, 0.16, 0.75), (0.08, 63, 0.14, 0.4)],
        "ui_open": [(0.0, 74, 0.12, 0.7), (0.11, 81, 0.20, 0.85)],
        "ui_close": [(0.0, 81, 0.12, 0.75), (0.11, 74, 0.18, 0.6)],
    }
    events = plans[ui_id]
    end = max(start + dur for start, _midi, dur, _vel in events) + 0.08
    mix = engine.Mix(int(end * SR))
    for start, midi, dur, vel in events:
        add_note(mix, int(start * SR), "celesta", midi, dur, vel, 0.05)
    return finish_oneshot(mix.L, mix.R, "ice")


def render_biome(spec: tuple) -> tuple:
    biome, root, scale, lead, space, tone = spec
    bpm = 75.0
    beat = 60.0 / bpm
    period = 20.0 * beat  # 16.0 s
    tail = 0.45
    total = period + tail
    n = int(total * SR)
    mix = engine.Mix(n)
    salt = engine.track_seed("amb_" + biome)

    noise = color_noise(n, salt, tone)
    env = np.zeros(n, dtype=np.float64)
    # Match bed_envelope cuts on the full buffer (tail keeps the cadence level).
    cuts = [0.0, 4 * beat, 10 * beat, 16 * beat, total]
    gains = [0.22, 0.12, 0.18, 0.10]
    for i, gain in enumerate(gains):
        a = int(cuts[i] * SR)
        b = min(n, int(cuts[i + 1] * SR))
        env[a:b] = gain
    mix.add(0, noise * env, 0.0)

    def chord(at_beat: float, degree: int, beats: float, vel: float, third: bool) -> None:
        start = int(at_beat * beat * SR)
        dur = beats * beat * 0.96
        add_note(mix, start, "pad", degree_midi(root, scale, degree, 0), dur, vel * 0.55, -0.05)
        add_note(mix, start, "pad", degree_midi(root, scale, degree + 4, 0), dur, vel * 0.38, 0.08)
        if third:
            add_note(mix, start, "string", degree_midi(root, scale, degree + 2, 0), dur, vel * 0.22, 0.0)
        add_note(mix, start, "bass", degree_midi(root, scale, degree, -1), dur, vel * 0.4, 0.0)

    # Intro open fifth, motif i then IV, answer V then vi, cadence V-I.
    chord(0, 0, 4, 0.7, False)
    chord(4, 0, 3, 0.85, False)
    chord(7, 3, 3, 0.9, True)
    chord(10, 4, 3, 1.0, True)
    chord(13, 5, 3, 0.95, True)
    chord(16, 4, 2, 0.75, False)
    chord(18, 0, 2, 0.8, False)

    def phrase(start_beat: float, degrees: list, shift: int, vel: float) -> None:
        at = start_beat
        for degree, dur in zip(degrees, MOTIF_RHYTHM):
            add_note(
                mix,
                int(at * beat * SR),
                lead,
                degree_midi(root, scale, degree + shift, 1),
                dur * beat * 0.92,
                vel,
                0.18,
            )
            at += dur

    phrase(4.0, MOTIF, 0, 0.85)
    answer = [2, 4, 6, 5, 3, 2]
    phrase(10.0, answer, 0, 1.0)
    add_note(mix, int(16.0 * beat * SR), lead, degree_midi(root, scale, 4, 1), 1.6 * beat, 0.7, 0.12)
    add_note(mix, int(18.0 * beat * SR), lead, degree_midi(root, scale, 0, 1), 1.8 * beat, 0.8, 0.12)

    if tone == "bell":
        for at in (0.0, 8.0, 16.0):
            add_note(mix, int(at * beat * SR), "chime", degree_midi(root, scale, 0, 2), 1.4, 0.45, -0.2)
    elif tone == "clock":
        for at in range(0, 20, 4):
            add_note(mix, int(at * beat * SR), "tick", root + 24, 0.05, 0.35, 0.3)
    elif tone == "ember":
        for at in (2.5, 6.5, 12.5, 17.5):
            add_note(mix, int(at * beat * SR), "tick", 90, 0.04, 0.25, -0.3)
    elif tone == "metal":
        for at in (11.0, 13.0, 15.0):
            add_note(mix, int(at * beat * SR), "tick", 174, 0.07, 0.4, 0.25)
    elif tone == "page":
        for at in (5.0, 9.0, 14.0):
            add_note(mix, int(at * beat * SR), "tick", 1400, 0.02, 0.2, -0.15)

    period_n = int(period * SR)
    fade_n = n - period_n
    body_l, body_r = seal_loop(mix.L[:period_n], mix.R[:period_n], mix.L[period_n:], mix.R[period_n:])
    # fade_n is unused beyond the slice; keep the variable so the tail length stays obvious.
    _ = fade_n
    return loop_finish(body_l, body_r, space)


def planned_files() -> list:
    rows = []
    for weapon in WEAPONS:
        for variant in range(3):
            rows.append(("wav", "hit_%s_%d" % (weapon, variant)))
    for terrain in TERRAINS:
        for variant in range(2):
            rows.append(("wav", "step_%s_%d" % (terrain, variant)))
    for ui_id in UI_IDS:
        rows.append(("wav", ui_id))
    for spec in BIOMES:
        rows.append(("ogg", "amb_" + spec[0]))
    return rows


def render_id(file_id: str) -> tuple:
    if file_id.startswith("hit_"):
        weapon, variant = file_id[4:].rsplit("_", 1)
        return render_weapon(weapon, int(variant))
    if file_id.startswith("step_"):
        terrain, variant = file_id[5:].rsplit("_", 1)
        return render_step(terrain, int(variant))
    if file_id.startswith("ui_"):
        return render_ui(file_id)
    if file_id.startswith("amb_"):
        biome = file_id[4:]
        for spec in BIOMES:
            if spec[0] == biome:
                return render_biome(spec)
    raise KeyError(file_id)


def write_id(out_dir: Path, kind: str, file_id: str) -> Path:
    left, right = render_id(file_id)
    if kind == "wav":
        path = out_dir / ("%s.wav" % file_id)
        write_wav(path, left, right)
    else:
        path = out_dir / ("%s.ogg" % file_id)
        engine.write_ogg(path, left, right, engine.track_seed(file_id), quality=1)
    return path


def report(path: Path) -> None:
    if path.suffix == ".ogg":
        audio = engine.decode_ogg_f32(path)
        seconds = audio.size / 2 / SR
    else:
        with wave.open(str(path), "rb") as handle:
            frames = handle.getnframes()
            raw = handle.readframes(frames)
            seconds = frames / handle.getframerate()
        pcm = np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32767.0
        audio = pcm
    level = engine.rms_db(audio)
    peak = float(np.max(np.abs(audio))) if audio.size else 0.0
    # Quarter-second energy contrast for beds.
    channels = 2
    frame = int(0.25 * SR) * channels
    if audio.size > frame * 4:
        chunks = audio[: audio.size - (audio.size % frame)].reshape(-1, frame)
        energy = np.sqrt(np.mean(chunks ** 2, axis=1) + 1e-18)
        contrast = float(energy.max() / max(float(energy.min()), 1e-8))
    else:
        contrast = 1.0
    print("%s  %.2fs  rms %6.2f  peak %.2f  contrast %.2f" % (path.name, seconds, level, peak, contrast))


def build(out_dir: Path, only: str) -> dict:
    catalog = {"seed": SEED, "sample_rate": SR, "files": {}}
    for kind, file_id in planned_files():
        if only and file_id != only and not file_id.startswith(only):
            continue
        path = write_id(out_dir, kind, file_id)
        catalog["files"][path.name] = {"sha256": sha256_file(path), "bytes": path.stat().st_size}
        report(path)
    return catalog


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="")
    parser.add_argument("--only", default="")
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    out = Path(args.out) if args.out else root / "project" / "assets" / "sfx"
    if args.verify:
        import tempfile

        tmp = Path(tempfile.mkdtemp(prefix="sfx-verify-"))
        try:
            fresh = build(tmp, args.only)
            catalog_path = out / "catalog_v92.json"
            committed = json.loads(catalog_path.read_text())
            for name, meta in fresh["files"].items():
                old = committed["files"][name]["sha256"]
                if old != meta["sha256"]:
                    raise SystemExit("MISMATCH %s" % name)
                disk = sha256_file(out / name)
                if disk != old:
                    raise SystemExit("DISK %s" % name)
        finally:
            shutil.rmtree(tmp)
        print("SFX VERIFY PASS")
        return
    catalog = build(out, args.only)
    if not args.only:
        (out / "catalog_v92.json").write_text(json.dumps(catalog, indent=2, sort_keys=True) + "\n")
        total = sum(item["bytes"] for item in catalog["files"].values())
        print("files %d bytes %d" % (len(catalog["files"]), total))


if __name__ == "__main__":
    main()
