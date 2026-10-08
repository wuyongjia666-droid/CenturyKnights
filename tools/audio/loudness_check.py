#!/usr/bin/env python3
"""Full-file stereo RMS gate. Target -16 dB ±2, the same meter the score uses.

LUFS is not computed here. Integrated RMS is the stand-in from §7.9.
Legacy 22.05 kHz one-shots are outside this gate; they predate the meter.
"""

from __future__ import annotations

import json
import sys
import wave
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import sfx_v92  # noqa: F401  (installs numpy / ffmpeg on bare runners)
import engine

import numpy as np

TARGET = -16.0
TOLERANCE = 2.0


def measure(path: Path) -> float:
    if path.suffix == ".ogg":
        audio = engine.decode_ogg_f32(path)
        return engine.rms_db(audio)
    with wave.open(str(path), "rb") as handle:
        frames = handle.getnframes()
        channels = handle.getnchannels()
        width = handle.getsampwidth()
        raw = handle.readframes(frames)
    if width != 2:
        raise SystemExit("unsupported wav %s" % path.name)
    pcm = np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32767.0
    if channels == 1:
        stereo = np.empty(pcm.size * 2, dtype=np.float64)
        stereo[0::2] = pcm
        stereo[1::2] = pcm
        pcm = stereo
    return engine.rms_db(pcm)


def collect(root: Path) -> list:
    sfx = root / "project" / "assets" / "sfx"
    catalog = json.loads((sfx / "catalog_v92.json").read_text())
    paths = [sfx / name for name in sorted(catalog["files"])]
    paths.extend(sorted((root / "project" / "assets" / "music").glob("*.ogg")))
    return paths


def main() -> None:
    root = Path(__file__).resolve().parents[2]
    low = TARGET - TOLERANCE
    high = TARGET + TOLERANCE
    failed = False
    count = 0
    for path in collect(root):
        count += 1
        level = measure(path)
        if level < low or level > high:
            failed = True
            print("LOUDNESS FAIL %s %.2f" % (path.name, level))
    if failed:
        raise SystemExit(1)
    print("LOUDNESS PASS files=%d" % count)


if __name__ == "__main__":
    main()
