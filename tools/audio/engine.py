"""Deterministic stereo renderer for CenturyKnights v9.2.

Integer-free oscillators use NumPy float64 only (IEEE ops). Ogg Vorbis
bytes are made reproducible by rewriting the random Ogg serial and CRC
after libvorbis, which is the only nondeterministic field ffmpeg emits.
"""

from __future__ import annotations

import hashlib
import struct
import subprocess
from pathlib import Path

import numpy as np

SR = 44100
SEED = 9202601

_OGG_CRC = None


def track_seed(track_id: str) -> int:
    h = SEED & 0xFFFFFFFF
    for ch in track_id:
        h = ((h * 16777619) ^ ord(ch)) & 0xFFFFFFFF
    return h or 1


def midi_to_hz(midi: float) -> float:
    return 440.0 * (2.0 ** ((float(midi) - 69.0) / 12.0))


def _ogg_crc_table():
    global _OGG_CRC
    if _OGG_CRC is not None:
        return _OGG_CRC
    table = []
    for i in range(256):
        r = i << 24
        for _ in range(8):
            if r & 0x80000000:
                r = ((r << 1) ^ 0x04C11DB7) & 0xFFFFFFFF
            else:
                r = (r << 1) & 0xFFFFFFFF
        table.append(r)
    _OGG_CRC = table
    return table


def fix_ogg_serial(data: bytes, serial: int) -> bytes:
    """Force a stable Ogg stream serial and recompute page CRCs."""
    table = _ogg_crc_table()
    out = bytearray(data)
    i = 0
    serial &= 0xFFFFFFFF
    while i + 27 <= len(out):
        if out[i : i + 4] != b"OggS":
            raise ValueError("ogg sync lost at %d" % i)
        nseg = out[i + 26]
        header = 27 + nseg
        body = sum(out[i + 27 : i + header])
        end = i + header + body
        if end > len(out):
            raise ValueError("truncated ogg page")
        struct.pack_into("<I", out, i + 14, serial)
        struct.pack_into("<I", out, i + 22, 0)
        crc = 0
        for b in out[i:end]:
            crc = ((crc << 8) ^ table[((crc >> 24) ^ b) & 0xFF]) & 0xFFFFFFFF
        struct.pack_into("<I", out, i + 22, crc)
        i = end
    if i != len(out):
        raise ValueError("trailing ogg bytes")
    return bytes(out)


def probe_vorbis(data: bytes) -> dict:
    """Read channels, rate, and duration from an Ogg Vorbis file."""
    if len(data) < 64 or data[:4] != b"OggS":
        raise ValueError("not ogg")
    nseg = data[26]
    header = 27 + nseg
    body = data[header : header + sum(data[27:header])]
    if len(body) < 16 or body[0] != 1 or body[1:7] != b"vorbis":
        raise ValueError("missing vorbis id header")
    channels = body[11]
    rate = struct.unpack_from("<I", body, 12)[0]
    granule = 0
    i = 0
    while i + 27 <= len(data):
        if data[i : i + 4] != b"OggS":
            break
        nseg = data[i + 26]
        header = 27 + nseg
        body_len = sum(data[i + 27 : i + header])
        granule = struct.unpack_from("<q", data, i + 6)[0]
        i += header + body_len
    duration = float(granule) / float(rate) if rate else 0.0
    return {"channels": int(channels), "rate": int(rate), "seconds": duration}


def rms_db(interleaved_f64: np.ndarray) -> float:
    if interleaved_f64.size == 0:
        return -120.0
    power = float(np.mean(interleaved_f64.astype(np.float64) ** 2))
    if power <= 1e-20:
        return -120.0
    return 10.0 * np.log10(power)


def decode_ogg_f32(path: Path) -> np.ndarray:
    cmd = [
        "ffmpeg",
        "-v",
        "error",
        "-i",
        str(path),
        "-f",
        "f32le",
        "-ac",
        "2",
        "-ar",
        str(SR),
        "pipe:1",
    ]
    proc = subprocess.run(cmd, check=True, stdout=subprocess.PIPE)
    audio = np.frombuffer(proc.stdout, dtype="<f4").astype(np.float64)
    if audio.size % 2 != 0:
        audio = audio[:-1]
    return audio


def write_ogg(path: Path, left: np.ndarray, right: np.ndarray, serial: int, quality: int = 1) -> None:
    if left.shape != right.shape:
        raise ValueError("channel length mismatch")
    peak = max(float(np.max(np.abs(left))), float(np.max(np.abs(right))), 1e-9)
    if peak > 0.98:
        scale = 0.98 / peak
        left = left * scale
        right = right * scale
    stereo = np.empty(left.size * 2, dtype=np.float64)
    stereo[0::2] = np.clip(left, -1.0, 1.0)
    stereo[1::2] = np.clip(right, -1.0, 1.0)
    pcm = (stereo * 32767.0).astype("<i2").tobytes()
    cmd = [
        "ffmpeg",
        "-y",
        "-hide_banner",
        "-loglevel",
        "error",
        "-f",
        "s16le",
        "-ar",
        str(SR),
        "-ac",
        "2",
        "-i",
        "pipe:0",
        "-c:a",
        "libvorbis",
        "-q:a",
        str(int(quality)),
        "-ar",
        str(SR),
        "-ac",
        "2",
        str(path),
    ]
    subprocess.run(cmd, input=pcm, check=True)
    fixed = fix_ogg_serial(path.read_bytes(), serial)
    path.write_bytes(fixed)


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    h.update(path.read_bytes())
    return h.hexdigest()


class Mix:
    def __init__(self, n: int):
        self.n = int(n)
        self.L = np.zeros(self.n, dtype=np.float64)
        self.R = np.zeros(self.n, dtype=np.float64)

    def add(self, start: int, mono: np.ndarray, pan: float) -> None:
        if mono.size == 0:
            return
        i0 = int(start)
        if i0 >= self.n:
            return
        if i0 < 0:
            mono = mono[-i0:]
            i0 = 0
        i1 = min(self.n, i0 + mono.size)
        seg = mono[: i1 - i0]
        # Constant-power pan. pan -1 left, +1 right.
        angle = (float(pan) + 1.0) * (np.pi * 0.25)
        self.L[i0:i1] += seg * np.cos(angle)
        self.R[i0:i1] += seg * np.sin(angle)

    def scale(self, gain: float) -> None:
        self.L *= gain
        self.R *= gain

    def gated_rms(self) -> float:
        energy = self.L * self.L + self.R * self.R
        peak = float(energy.max()) if energy.size else 0.0
        if peak <= 1e-16:
            return 0.0
        mask = energy > peak * 0.04
        if int(mask.sum()) < 8:
            return float(np.sqrt(np.mean(energy) + 1e-18))
        return float(np.sqrt(np.mean(energy[mask]) + 1e-18))


def _fade_ends(sig: np.ndarray, fade: int = 96) -> None:
    n = sig.size
    a = min(fade, n // 2)
    if a <= 1:
        return
    sig[:a] *= np.linspace(0.0, 1.0, a)
    sig[-a:] *= np.linspace(1.0, 0.0, a)


def _adsr(n: int, a: float, d: float, s: float, r: float, sr: int = SR) -> np.ndarray:
    env = np.ones(n, dtype=np.float64)
    na = min(n, max(1, int(a * sr)))
    nd = min(n - na, max(1, int(d * sr)))
    nr = min(n, max(1, int(r * sr)))
    env[:na] = np.linspace(0.0, 1.0, na, endpoint=False)
    if nd > 0:
        env[na : na + nd] = np.linspace(1.0, s, nd, endpoint=False)
        env[na + nd :] = s
    if nr > 0:
        env[-nr:] *= np.linspace(1.0, 0.0, nr)
    return env


def synth(kind: str, freq: float, n: int, sr: int = SR) -> np.ndarray:
    if n <= 0 or freq <= 1.0:
        return np.zeros(0, dtype=np.float64)
    t = np.arange(n, dtype=np.float64) / float(sr)
    w = 2.0 * np.pi * freq
    if kind == "celesta":
        pluck = (
            np.sin(w * t) * np.exp(-t * 2.4)
            + 0.42 * np.sin(w * 2.003 * t) * np.exp(-t * 4.8)
            + 0.28 * np.sin(w * 2.76 * t) * np.exp(-t * 6.4)
            + 0.16 * np.sin(w * 5.07 * t) * np.exp(-t * 8.5)
            + 0.08 * np.sin(w * 8.15 * t) * np.exp(-t * 11.0)
        )
        body = np.sin(w * t) * _adsr(n, 0.008, 0.18, 0.42, 0.22, sr)
        sig = pluck * 0.8 + body * 0.4
    elif kind == "flute":
        vib = (0.0024 * freq / 5.2) * np.sin(2.0 * np.pi * 5.2 * t)
        phase = w * t + vib
        breath = _hash_noise(n, int(freq * 10.0) & 0xFFFF) * np.exp(-((t - 0.05) ** 2) / 0.08)
        sig = (np.sin(phase) + 0.12 * np.sin(2.0 * phase)) * _adsr(n, 0.07, 0.12, 0.78, 0.16, sr)
        sig = sig + breath * 0.018
    elif kind == "string":
        vib = (0.0032 * freq / 5.0) * np.sin(2.0 * np.pi * 5.0 * t) * np.clip(t / 0.25, 0.0, 1.0)
        phase = w * t + vib
        sig = (
            np.sin(phase)
            + 0.38 * np.sin(2.0 * phase)
            + 0.16 * np.sin(3.0 * phase)
            + 0.07 * np.sin(4.0 * phase)
        ) * _adsr(n, 0.09, 0.16, 0.72, 0.18, sr)
    elif kind == "pad":
        sig = (
            np.sin(w * t)
            + 0.55 * np.sin(w * 0.9975 * t)
            + 0.22 * np.sin(w * 2.0 * t)
            + 0.12 * np.sin(w * 1.498 * t)
        ) * _adsr(n, 0.32, 0.2, 0.85, 0.36, sr)
    elif kind == "bass":
        sig = (np.sin(w * t) + 0.28 * np.sin(2.0 * w * t) * np.exp(-t * 2.2)) * _adsr(
            n, 0.02, 0.18, 0.62, 0.12, sr
        )
    elif kind == "thump":
        f_inst = 78.0 + (freq - 78.0) * np.exp(-t * 28.0)
        phase = 2.0 * np.pi * np.cumsum(f_inst) / float(sr)
        sig = np.sin(phase) * np.exp(-t * 14.0)
        sig += 0.25 * _hash_noise(n, 19) * np.exp(-t * 40.0)
    elif kind == "tick":
        sig = np.sin(w * t) * np.exp(-t * 55.0)
        sig += 0.45 * _hash_noise(n, int(freq) & 0xFFFF) * np.exp(-t * 70.0)
    elif kind == "chime":
        sig = (
            np.sin(w * t) * np.exp(-t * 1.8)
            + 0.3 * np.sin(w * 2.76 * t) * np.exp(-t * 3.4)
        )
    else:
        sig = np.sin(w * t) * _adsr(n, 0.01, 0.1, 0.6, 0.1, sr)
    _fade_ends(sig)
    peak = float(np.max(np.abs(sig))) if sig.size else 1.0
    if peak > 1e-8:
        sig *= 0.9 / max(peak, 0.9)
    return sig


def _hash_noise(n: int, salt: int) -> np.ndarray:
    i = np.arange(n, dtype=np.uint64) + np.uint64(salt + 17)
    x = i * np.uint64(0x9E3779B97F4A7C15)
    x ^= x >> np.uint64(30)
    x *= np.uint64(0xBF58476D1CE4E5B9)
    x ^= x >> np.uint64(27)
    x ^= x >> np.uint64(31)
    # Map to [-1, 1] without signed overflow.
    return (x.astype(np.float64) / np.float64(2.0**63)) - 1.0


def early_reflections(left: np.ndarray, right: np.ndarray, taps) -> tuple:
    out_l = left.copy()
    out_r = right.copy()
    for delay_ms, gain, pan in taps:
        d = int(delay_ms * SR / 1000.0)
        if d <= 0 or d >= left.size:
            continue
        out_l[d:] += left[:-d] * gain * (1.0 - pan)
        out_r[d:] += right[:-d] * gain * (1.0 + pan) * 0.5
        out_l[d:] += right[:-d] * gain * pan * 0.35
        out_r[d:] += left[:-d] * gain * (1.0 - pan) * 0.25
    return out_l, out_r


def glue(left: np.ndarray, right: np.ndarray) -> tuple:
    # Gentle one-pole-ish FIR. Keeps celesta partials; only knocks the click edge.
    kernel = np.exp(-np.arange(7, dtype=np.float64) / 1.6)
    kernel /= np.sum(kernel)
    return np.convolve(left, kernel, mode="same"), np.convolve(right, kernel, mode="same")


SPACES = {
    "hall": [(19, 0.16, 0.2), (31, 0.11, -0.15), (53, 0.07, 0.25), (79, 0.045, -0.1)],
    "room": [(12, 0.12, 0.1), (21, 0.07, -0.12)],
    "dry": [(8, 0.05, 0.0)],
    "ice": [(23, 0.2, 0.3), (44, 0.13, -0.25), (71, 0.08, 0.2), (103, 0.04, -0.15)],
    "forge": [(9, 0.1, 0.05), (16, 0.06, -0.08), (28, 0.04, 0.1)],
}


def _normalize_pair(left: np.ndarray, right: np.ndarray, target_db: float) -> tuple:
    stereo = np.empty(left.size * 2, dtype=np.float64)
    stereo[0::2] = left
    stereo[1::2] = right
    level = rms_db(stereo)
    gain = 10.0 ** ((target_db - level) / 20.0)
    return left * gain, right * gain


def finish(left: np.ndarray, right: np.ndarray, space: str) -> tuple:
    left, right = glue(left, right)
    left, right = early_reflections(left, right, SPACES.get(space, SPACES["room"]))
    # Compress just enough that -16 dB RMS still leaves headroom for Vorbis overshoot.
    chosen_l, chosen_r = left, right
    for drive in (1.15, 1.7, 2.4, 3.2):
        shaped_l = np.tanh(left * drive) / np.tanh(drive)
        shaped_r = np.tanh(right * drive) / np.tanh(drive)
        shaped_l, shaped_r = _normalize_pair(shaped_l, shaped_r, -16.2)
        peak = max(float(np.max(np.abs(shaped_l))), float(np.max(np.abs(shaped_r))), 1e-9)
        chosen_l, chosen_r = shaped_l, shaped_r
        if peak <= 0.62:
            break
    return chosen_l, chosen_r
