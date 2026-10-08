#!/usr/bin/env python3
"""CenturyKnights v9.2 procedural score.

One lamp motif (tonic, third, fifth, fourth, second, tonic) runs through
every cue. Each cue has its own key, progression, and sectional plan.
Re-running with the fixed seed rewrites bit-identical Ogg files.

Usage:
  python3 tools/audio/compose_v92.py
  python3 tools/audio/compose_v92.py --only mus_title
  python3 tools/audio/compose_v92.py --verify
"""

from __future__ import annotations

import argparse
import importlib
import json
import random
import shutil
import subprocess
import sys
from pathlib import Path


def ensure_runtime() -> None:
    """GitHub runners do not ship NumPy or ffmpeg. Pin the versions this score was encoded with."""
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
ROOT = Path(__file__).resolve().parents[2]
MUSIC = ROOT / "project" / "assets" / "music"
QUALITY = 1  # libvorbis q=1, about 80 kbps stereo

SCALES = {
    "dorian": [0, 2, 3, 5, 7, 9, 10],
    "minor": [0, 2, 3, 5, 7, 8, 10],
    "major": [0, 2, 4, 5, 7, 9, 11],
    "mixolydian": [0, 2, 4, 5, 7, 9, 10],
    "lydian": [0, 2, 4, 6, 7, 9, 11],
    "phrygian": [0, 1, 3, 5, 7, 8, 10],
}

PHRASES = {
    "motif": [(0, 1.0), (2, 0.5), (4, 1.0), (3, 0.5), (1, 1.0), (0, 2.0)],
    "motif_head": [(0, 1.0), (2, 0.5), (4, 1.5)],
    "answer": [(4, 1.0), (5, 0.5), (4, 1.0), (3, 0.5), (2, 1.0), (1, 2.0)],
    "arch": [(0, 0.5), (1, 0.5), (2, 0.5), (4, 1.0), (5, 1.0), (4, 0.5), (2, 0.5), (1, 1.5)],
    "rise": [(0, 0.5), (1, 0.5), (2, 0.5), (4, 0.5), (5, 1.0), (6, 1.0), (4, 2.0)],
    "lament": [(4, 1.5), (3, 0.5), (2, 1.0), (1, 1.0), (0, 2.0)],
    "cadence": [(4, 1.0), (3, 1.0), (2, 1.0), (0, 3.0)],
    "narrow": [(0, 1.0), (1, 0.5), (3, 1.0), (2, 0.5), (1, 1.0), (0, 2.0)],
    "sway": [(0, 1.5), (2, 0.5), (4, 1.5), (3, 0.5), (2, 1.0), (0, 1.0)],
}

PLANS = {
    "fragment": (["motif_head"], [0]),
    "statement": (["motif", "answer", "motif"], [0, 0, 0]),
    "sequence": (["arch", "arch", "rise"], [0, 2, 3]),
    "lament": (["lament", "motif", "lament"], [0, 0, -2]),
    "cadence": (["motif", "cadence"], [0, 0]),
    "narrow": (["narrow", "lament", "narrow"], [0, 0, 0]),
    "sway": (["sway", "motif", "answer"], [0, 0, 2]),
    "hero": (["motif", "rise", "arch", "motif"], [0, 0, 2, 0]),
}

PULSE = {
    "none": [],
    "soft": [(1.0, "tick", 0.055, 1760), (3.0, "tick", 0.04, 1560)],
    "travel": [(0.0, "thump", 0.09, 96), (2.0, "thump", 0.07, 88), (3.5, "tick", 0.045, 1680)],
    "battle": [
        (0.0, "thump", 0.11, 90),
        (1.0, "tick", 0.05, 1480),
        (1.5, "tick", 0.035, 1320),
        (2.0, "thump", 0.085, 84),
        (3.0, "thump", 0.1, 92),
        (3.5, "tick", 0.04, 1720),
    ],
    "spark": [(0.5, "tick", 0.04, 2100), (1.5, "tick", 0.055, 1860), (2.5, "tick", 0.04, 1980), (3.5, "chime", 0.05, 0)],
    "bell": [(0.0, "chime", 0.06, 0), (2.0, "chime", 0.035, 0)],
    "metal": [(0.0, "thump", 0.08, 110), (1.0, "tick", 0.07, 2400), (2.0, "tick", 0.05, 2200), (3.0, "thump", 0.09, 100)],
}


def midi_of(root: int, scale: list, degree: int, octave: int) -> int:
    di = int(degree)
    octs = int(octave)
    while di < 0:
        di += 7
        octs -= 1
    while di >= 7:
        di -= 7
        octs += 1
    return int(root + scale[di] + 12 * octs)


def phrase_beats(name: str) -> float:
    return float(sum(b for _, b in PHRASES[name]))


def seconds_of(bpm: float, bars: int) -> float:
    return bars * 4.0 * 60.0 / bpm


def _nation(nid, name, root, scale, pulse, b_melody, lead, space, city_extra, atlas_extra):
    return {
        "id": nid,
        "name": name,
        "root": root,
        "scale": scale,
        "pulse": pulse,
        "b_melody": b_melody,
        "lead": lead,
        "space": space,
        "city": city_extra,
        "atlas": atlas_extra,
    }


NATIONS = [
    _nation("ashbanner", "灰烬邦", 62, "dorian", "soft", "sequence", "celesta", "hall", {}, {"pulse": "travel"}),
    _nation("shuoying", "朔影国", 59, "phrygian", "soft", "narrow", "flute", "ice", {"grace": True, "gap": 2.4}, {"grace": True}),
    _nation("qinghe", "清河国", 64, "dorian", "travel", "sway", "flute", "hall", {"gap": 1.6}, {}),
    _nation("lantern", "灯市联", 69, "mixolydian", "spark", "sequence", "celesta", "room", {"echo": True}, {"echo": True, "pulse": "spark"}),
    _nation("frostcrown", "霜冕廷", 62, "minor", "bell", "lament", "celesta", "ice", {"gap": 2.6, "rhythm": 1.15}, {"pulse": "bell", "rhythm": 1.1}),
    _nation("emberold", "余烬旧邦", 54, "minor", "soft", "lament", "string", "room", {"double": True}, {"double": True}),
    _nation("saltmarsh", "盐泽盟", 60, "dorian", "soft", "sway", "flute", "hall", {"gap": 2.2}, {"pulse": "travel"}),
    _nation("irongorge", "铁峡领", 64, "minor", "metal", "hero", "string", "forge", {"ostinato": True}, {"ostinato": True, "pulse": "metal"}),
    _nation("starriver", "星津邦", 71, "dorian", "spark", "sequence", "celesta", "ice", {"echo": True, "open": True}, {"echo": True}),
    _nation("southzephyr", "南泽邦", 67, "dorian", "soft", "sway", "flute", "hall", {"gap": 1.8}, {"pulse": "travel"}),
]


def lyric_sections(flavor: dict) -> list:
    return [
        {"name": "intro", "bars": 4, "plan": "fragment", "lead": 0.42, "pulse": flavor.get("pulse_intro", "soft"), "ostinato": False},
        {"name": "a", "bars": 8, "plan": flavor.get("a_plan", "statement"), "lead": 1.0, "pulse": flavor["pulse"], "ostinato": flavor.get("ostinato", False)},
        {"name": "b", "bars": 8, "plan": flavor.get("b_melody", "sequence"), "lead": 1.06, "pulse": flavor["pulse"], "ostinato": flavor.get("ostinato", False), "canon": flavor.get("canon", False), "thirds": flavor.get("thirds", False)},
        {"name": "recap", "bars": 4, "plan": "cadence", "lead": 0.9, "pulse": flavor.get("pulse_recap", "soft"), "ostinato": False},
    ]


def battle_sections(flavor: dict) -> list:
    return [
        {"name": "intro", "bars": 4, "plan": "fragment", "lead": 0.55, "pulse": flavor.get("pulse_intro", "travel"), "ostinato": False},
        {"name": "a", "bars": 8, "plan": "statement", "lead": 1.0, "pulse": flavor["pulse"], "ostinato": flavor.get("ostinato", False)},
        {"name": "a2", "bars": 8, "plan": "hero", "lead": 1.02, "pulse": flavor["pulse"], "ostinato": True, "canon": flavor.get("canon", False)},
        {"name": "b", "bars": 8, "plan": flavor.get("b_melody", "sequence"), "lead": 1.08, "pulse": flavor["pulse"], "ostinato": True, "canon": flavor.get("canon", False)},
        {"name": "recap", "bars": 4, "plan": "cadence", "lead": 0.95, "pulse": flavor["pulse"], "ostinato": False},
    ]


def track_list() -> list:
    tracks = []

    def add(**kwargs):
        tracks.append(kwargs)

    add(
        id="mus_title",
        purpose="主菜单 / 标题。霜灯动机的完整陈述。",
        bpm=76,
        root=62,
        scale="dorian",
        lead="celesta",
        space="hall",
        pulse="soft",
        pulse_intro="bell",
        b_melody="sequence",
        echo=True,
        gap=2.0,
        chords={
            "intro": [0, 6],
            "a": [0, 6, 3, 4],
            "b": [2, 3, 0, 6],
            "recap": [0, 3],
        },
        form="lyric",
    )
    seasons = [
        ("spring", "春生", 67, "mixolydian", "spark", "sequence", "flute", "hall", {"echo": True, "gap": 1.7}),
        ("summer", "夏澄", 69, "dorian", "travel", "sway", "flute", "room", {"thirds": True, "gap": 1.5}),
        ("autumn", "秋落", 64, "minor", "soft", "lament", "string", "hall", {"double": True, "gap": 2.1}),
        ("winter", "冬静", 62, "minor", "bell", "lament", "celesta", "ice", {"echo": True, "rhythm": 1.2, "gap": 2.5, "pulse_intro": "none"}),
    ]
    for sid, label, root, scale, pulse, bmel, lead, space, extra in seasons:
        chords = {
            "spring": {"intro": [0, 4], "a": [0, 5, 3, 4], "b": [3, 4, 0, 6], "recap": [0, 4]},
            "summer": {"intro": [0, 6], "a": [0, 6, 3, 4], "b": [2, 3, 0, 6], "recap": [0, 3]},
            "autumn": {"intro": [0, 5], "a": [0, 5, 3, 4], "b": [5, 3, 0, 4], "recap": [0, 5]},
            "winter": {"intro": [0, 3], "a": [0, 5, 3, 0], "b": [5, 3, 4, 0], "recap": [0, 4]},
        }[sid]
        spec = dict(
            id="mus_castle_%s" % sid,
            purpose="城堡·%s。内殿与工坊，按季节换调。" % label,
            bpm=80,
            root=root,
            scale=scale,
            lead=lead,
            space=space,
            pulse=pulse,
            b_melody=bmel,
            chords=chords,
            form="lyric",
            gap=1.8,
        )
        spec.update(extra)
        add(**spec)

    add(
        id="mus_atlas",
        purpose="舆图。陆桥上路的进行，霜灯动机作路标。",
        bpm=92,
        root=65,
        scale="dorian",
        lead="flute",
        space="hall",
        pulse="travel",
        b_melody="sequence",
        chords={"intro": [0, 6], "a": [0, 6, 3, 4], "b": [2, 6, 3, 4], "recap": [0, 4]},
        form="lyric",
        gap=1.2,
        ostinato=True,
    )
    for nat in NATIONS:
        extra = dict(nat["atlas"])
        add(
            id="mus_atlas_%s" % nat["id"],
            purpose="舆图·%s。同路不同国境的变奏。" % nat["name"],
            bpm=92,
            root=nat["root"],
            scale=nat["scale"],
            lead=nat["lead"],
            space=nat["space"],
            pulse=extra.get("pulse", "travel"),
            b_melody="sequence",
            chords={"intro": [0, 6], "a": [0, 6, 3, 4], "b": [2, 3, 0, 4], "recap": [0, 6]},
            form="lyric",
            gap=extra.get("gap", 1.2),
            grace=extra.get("grace", False),
            echo=extra.get("echo", False),
            double=extra.get("double", False),
            ostinato=extra.get("ostinato", True),
            rhythm=extra.get("rhythm", 1.0),
        )

    eras = [
        (1, "灯起", 104, "dorian", "travel", False, False, "statement"),
        (2, "霜盟", 112, "minor", "battle", True, False, "sequence"),
        (3, "裂桥", 118, "minor", "battle", True, False, "hero"),
        (4, "冕战", 120, "minor", "battle", True, True, "sequence"),
        (5, "百年", 120, "dorian", "battle", True, True, "hero"),
    ]
    for era, label, bpm, scale, pulse, ost, canon, bmel in eras:
        add(
            id="mus_battle_era%d" % era,
            purpose="纪元%s·%s。玩家回合，动机逐渐加密。" % ("一二三四五"[era - 1], label),
            bpm=bpm,
            root=62,
            scale=scale,
            lead="string" if era >= 3 else "celesta",
            space="dry" if era < 4 else "room",
            pulse=pulse,
            pulse_intro="travel",
            b_melody=bmel,
            chords={"intro": [0, 6], "a": [0, 6, 3, 4], "a2": [2, 3, 0, 6], "b": [4, 3, 5, 6], "recap": [0, 4]},
            form="battle",
            gap=1.0 if era < 4 else 0.8,
            ostinato=ost,
            canon=canon,
            double=era == 5,
            echo=era == 1,
            a_plan="statement",
        )
    add(
        id="mus_battle_enemy",
        purpose="敌方回合。动机倒影，仍守 D 音踏板以便叠紧张层。",
        bpm=108,
        root=62,
        scale="phrygian",
        lead="flute",
        space="dry",
        pulse="battle",
        b_melody="narrow",
        a_plan="narrow",
        chords={"intro": [0, 6], "a": [0, 1, 3, 0], "a2": [0, 3, 4, 0], "b": [1, 0, 3, 6], "recap": [0, 1]},
        form="battle",
        gap=1.3,
        grace=True,
        invert=True,
    )
    add(
        id="mus_battle_boss",
        purpose="首领。动机拉宽，低弦加倍，踏板不让路。",
        bpm=96,
        root=62,
        scale="minor",
        lead="string",
        space="forge",
        pulse="battle",
        b_melody="lament",
        chords={"intro": [0, 0], "a": [0, 5, 3, 4], "a2": [0, 6, 3, 4], "b": [5, 3, 0, 4], "recap": [0, 0]},
        form="battle",
        gap=1.4,
        rhythm=1.25,
        double=True,
        canon=True,
        pedal=True,
    )
    add(
        id="mus_tension",
        purpose="紧张。可单独播放的段落：悬置、抬升、回落，不是一条垫底循环。",
        bpm=80,
        root=62,
        scale="minor",
        lead="celesta",
        space="ice",
        pulse="soft",
        pulse_intro="none",
        b_melody="lament",
        a_plan="fragment",
        chords={"intro": [0, 0], "a": [0, 5, 3, 0], "b": [3, 4, 5, 6], "recap": [0, 4]},
        form="lyric",
        gap=2.8,
        rhythm=1.35,
        pedal=True,
        echo=True,
    )
    add(
        id="mus_tension_layer",
        purpose="紧张层。D 踏板与四度进行，叠在战斗曲下，不另起满音量旋律。",
        bpm=84,
        root=62,
        scale="dorian",
        lead="celesta",
        space="dry",
        pulse="battle",
        b_melody="fragment",
        a_plan="fragment",
        chords={"intro": [0, 4], "a": [0, 4, 0, 3], "b": [0, 4, 3, 4], "recap": [0, 0]},
        form="lyric",
        gap=3.0,
        rhythm=1.5,
        pedal=True,
        layer=True,
        lead_gain=0.35,
    )
    add(
        id="mus_victory",
        purpose="胜利。动机转入大调，玻璃质感的上升，不作成套铜管号角。",
        bpm=90,
        root=62,
        scale="major",
        lead="celesta",
        space="hall",
        pulse="spark",
        b_melody="hero",
        chords={"intro": [0, 4], "a": [0, 4, 5, 3], "b": [3, 4, 0, 5], "recap": [0, 4]},
        form="lyric",
        gap=1.2,
        echo=True,
        thirds=True,
    )
    add(
        id="mus_defeat",
        purpose="失败。动机拆成下行碎片，停在空五度。",
        bpm=72,
        root=57,
        scale="minor",
        lead="flute",
        space="room",
        pulse="none",
        pulse_recap="none",
        pulse_intro="none",
        b_melody="lament",
        a_plan="lament",
        chords={"intro": [0, 5], "a": [0, 5, 3, 4], "b": [5, 3, 0, 4], "recap": [0, 0]},
        form="lyric",
        gap=2.6,
        rhythm=1.25,
        open=True,
    )
    add(
        id="mus_marriage",
        purpose="联姻。动机以平行三度成对出现。",
        bpm=84,
        root=65,
        scale="lydian",
        lead="flute",
        space="hall",
        pulse="soft",
        b_melody="sway",
        chords={"intro": [0, 3], "a": [0, 3, 1, 4], "b": [3, 4, 0, 1], "recap": [0, 4]},
        form="lyric",
        gap=1.6,
        thirds=True,
        echo=True,
    )
    add(
        id="mus_funeral",
        purpose="葬礼 / 先祖。动机拉成宽音，高玻璃铃回应低弦。",
        bpm=60,
        root=64,
        scale="minor",
        lead="string",
        space="ice",
        pulse="bell",
        pulse_intro="none",
        b_melody="lament",
        chords={"intro": [0, 5], "a": [0, 5, 3, 0], "b": [5, 3, 4, 0], "recap": [0, 5]},
        form="lyric",
        gap=2.2,
        rhythm=1.55,
        double=True,
        echo=True,
        bars_override=16,
        sections_override=[
            {"name": "intro", "bars": 4, "plan": "fragment", "lead": 0.5, "pulse": "none", "ostinato": False},
            {"name": "a", "bars": 8, "plan": "lament", "lead": 1.0, "pulse": "bell", "ostinato": False},
            {"name": "recap", "bars": 4, "plan": "cadence", "lead": 0.85, "pulse": "bell", "ostinato": False},
        ],
        chords_override={"intro": [0, 5], "a": [0, 5, 3, 0], "recap": [0, 5]},
    )
    add(
        id="mus_birth",
        purpose="初啼。高音区的摇篮式动机，春令的颜色。",
        bpm=76,
        root=67,
        scale="major",
        lead="celesta",
        space="room",
        pulse="soft",
        b_melody="sway",
        chords={"intro": [0, 5], "a": [0, 5, 3, 4], "b": [3, 4, 0, 5], "recap": [0, 4]},
        form="lyric",
        gap=1.8,
        echo=True,
        thirds=True,
    )
    add(
        id="mus_inheritance",
        purpose="继承。动机先在低音陈述，再交到高音。",
        bpm=72,
        root=69,
        scale="dorian",
        lead="string",
        space="hall",
        pulse="bell",
        b_melody="sequence",
        chords={"intro": [0, 6], "a": [0, 3, 4, 6], "b": [2, 3, 0, 4], "recap": [0, 3]},
        form="lyric",
        gap=2.0,
        double=True,
        echo=True,
        rhythm=1.1,
    )
    for nat in NATIONS:
        extra = dict(nat["city"])
        add(
            id="mus_city_%s" % nat["id"],
            purpose="城市·%s。十国城市变奏，城内比路上更稳。" % nat["name"],
            bpm=78,
            root=nat["root"],
            scale=nat["scale"],
            lead=nat["lead"],
            space=nat["space"],
            pulse=nat["pulse"],
            b_melody=nat["b_melody"],
            chords={"intro": [0, 3], "a": [0, 6, 3, 4], "b": [2, 5, 3, 4], "recap": [0, 4]},
            form="lyric",
            gap=extra.get("gap", 1.9),
            grace=extra.get("grace", False),
            echo=extra.get("echo", False),
            double=extra.get("double", False),
            ostinato=extra.get("ostinato", False),
            rhythm=extra.get("rhythm", 1.0),
            open=extra.get("open", False),
            a_plan="narrow" if nat["scale"] == "phrygian" else "statement",
        )
    return tracks


def _chords_for(spec: dict, section_name: str) -> list:
    if spec.get("chords_override"):
        return list(spec["chords_override"].get(section_name, [0]))
    return list(spec["chords"].get(section_name, [0, 4]))


def _sections_for(spec: dict) -> list:
    if spec.get("sections_override"):
        return spec["sections_override"]
    flavor = spec
    if spec.get("form") == "battle":
        return battle_sections(flavor)
    return lyric_sections(flavor)


class Score:
    def __init__(self, spec: dict):
        self.spec = spec
        self.bpm = float(spec["bpm"])
        self.beat = 60.0 / self.bpm
        self.scale = SCALES[spec["scale"]]
        self.root = int(spec["root"])
        self.rng = random.Random(engine.track_seed(spec["id"]))
        self.lead = engine.Mix(8)
        self.harm = engine.Mix(8)
        self.rhythm = engine.Mix(8)
        self._built = False

    def _ensure(self, n: int) -> None:
        if self.lead.n != n:
            self.lead = engine.Mix(n)
            self.harm = engine.Mix(n)
            self.rhythm = engine.Mix(n)

    def _sample(self, beats: float) -> int:
        return int(round(beats * self.beat * SR))

    def _tone(self, bus: engine.Mix, beats: float, dur_beats: float, midi: float, amp: float, kind: str, pan: float) -> None:
        if amp <= 0.0 or dur_beats <= 0.02:
            return
        jitter = self.rng.uniform(-0.004, 0.004)
        vel = amp * self.rng.uniform(0.94, 1.0)
        start = self._sample(max(0.0, beats + jitter / self.beat))
        n = max(8, self._sample(dur_beats) )
        sig = engine.synth(kind, engine.midi_to_hz(midi), n)
        bus.add(start, sig * vel, pan)

    def _degree_midi(self, degree: int, octave: int) -> int:
        return midi_of(self.root, self.scale, degree, octave)

    def emit_phrase(self, bus_amp: float, start_beat: float, phrase: str, transpose: int, rhythm: float, kind: str, pan: float, octave: int) -> float:
        t = start_beat
        spec = self.spec
        for deg, beats in PHRASES[phrase]:
            d = beats * rhythm
            degree = deg + transpose
            if spec.get("invert"):
                degree = -deg + transpose
            midi = self._degree_midi(degree, octave)
            if spec.get("grace") and deg == 0:
                self._tone(self.lead, t - 0.12 * rhythm, 0.1 * rhythm, midi - 1, bus_amp * 0.45, kind, pan)
            self._tone(self.lead, t, d * 0.92, midi, bus_amp, kind, pan)
            if spec.get("open") and deg in (2, 5):
                pass
            t += d
        return t - start_beat

    def schedule_melody(self, start: float, end: float, section: dict) -> None:
        spec = self.spec
        plan_name = section["plan"]
        names, trans = PLANS[plan_name]
        rhythm = float(spec.get("rhythm", 1.0))
        gap = float(spec.get("gap", 1.6))
        kind = spec.get("lead", "celesta")
        base_amp = 0.22 * float(section.get("lead", 1.0)) * float(spec.get("lead_gain", 1.0))
        if spec.get("layer"):
            base_amp *= 0.45
        t = start
        i = 0
        while t < end - 1.2 and i < 10:
            name = names[i % len(names)]
            transp = trans[i % len(trans)]
            length = phrase_beats(name) * rhythm
            if t + min(length, 4.0) > end + 0.2:
                break
            self.emit_phrase(base_amp, t, name, transp, rhythm, kind, 0.02, 0)
            if section.get("thirds") or spec.get("thirds"):
                self.emit_phrase(base_amp * 0.58, t + 0.03, name, transp + 2, rhythm, kind, 0.18, 0)
            if section.get("canon") or (spec.get("canon") and section["name"] in ("b", "a2")):
                self.emit_phrase(base_amp * 0.48, t + 2.0, name, transp, rhythm, kind, -0.16, 0)
            if spec.get("double"):
                self.emit_phrase(base_amp * 0.4, t, name, transp, rhythm, "string", -0.08, -1)
            if spec.get("echo"):
                self.emit_phrase(base_amp * 0.33, t + 0.5, name, transp, rhythm, "celesta", 0.22, 1)
            t += length + gap
            i += 1

    def schedule_harmony(self, start: float, dur: float, degree: int, section: dict) -> None:
        spec = self.spec
        if dur < 0.4:
            return
        scale = self.scale
        targets = (55, 62, 69) if not spec.get("layer") else (50, 57, 64)
        chosen = []
        tones = (degree, degree + 4) if spec.get("open") else (degree, degree + 2, degree + 4)
        if spec.get("layer"):
            tones = (0, degree + 4)  # pedal fifths / fourths, avoid clashing thirds
        for target in targets:
            best = None
            best_dist = 99
            for octs in range(-4, 3):
                for tone in tones:
                    midi = midi_of(self.root, scale, tone if not spec.get("pedal") or tone == tones[0] else tone, octs)
                    if spec.get("pedal") and tone == tones[0]:
                        midi = midi_of(self.root, scale, 0, octs)
                    if midi in chosen:
                        continue
                    dist = abs(midi - target)
                    if dist < best_dist:
                        best, best_dist = midi, dist
            if best is not None:
                chosen.append(best)
        shape = {"intro": 0.58, "a": 1.0, "a2": 1.05, "b": 1.16, "recap": 0.66}.get(section["name"], 1.0)
        pad_amp = 0.05 * shape
        if spec.get("layer"):
            pad_amp = 0.075 * shape
        pans = (-0.35, 0.0, 0.35)
        for i, midi in enumerate(chosen):
            self._tone(self.harm, start, dur + 0.15, midi, pad_amp, "pad", pans[i % 3])
        bass_oct = -2
        bass_midi = midi_of(self.root, scale, 0 if spec.get("pedal") else degree, bass_oct)
        while bass_midi > 50:
            bass_midi -= 12
        while bass_midi < 36:
            bass_midi += 12
        shape = {"intro": 0.58, "a": 1.0, "a2": 1.05, "b": 1.16, "recap": 0.66}.get(section["name"], 1.0)
        bass_amp = 0.15 * shape
        if spec.get("layer"):
            bass_amp = 0.13 * shape
        self._tone(self.harm, start, min(dur, dur * 0.92), bass_midi, bass_amp, "bass", 0.0)
        if not spec.get("pedal") and dur >= 3.0:
            fifth = midi_of(self.root, scale, degree + 4, bass_oct)
            while fifth > 58:
                fifth -= 12
            self._tone(self.harm, start + dur * 0.5, dur * 0.4, fifth, bass_amp * 0.45, "bass", 0.0)

    def schedule_pulse_pitched(self, start: float, dur: float, pattern: str) -> None:
        steps = PULSE.get(pattern, [])
        t = start
        end = start + dur
        while t < end - 0.05:
            for pos, kind, amp, freq in steps:
                when = t + pos
                if when >= end:
                    continue
                if kind == "chime":
                    midi = self._degree_midi(4, 1)
                    self._tone(self.rhythm, when, 0.85, midi, amp * 1.4, "chime", 0.12)
                elif kind == "thump":
                    n = max(8, int(0.16 * SR))
                    sig = engine.synth("thump", float(freq), n)
                    self.rhythm.add(self._sample(when), sig * amp * 1.8, 0.0)
                else:
                    n = max(8, int(0.05 * SR))
                    sig = engine.synth("tick", float(freq if freq else 1600), n)
                    pan = 0.25 if int(pos * 2) % 2 == 0 else -0.25
                    self.rhythm.add(self._sample(when), sig * amp * 1.3, pan)
            t += 4.0

    def schedule_ostinato(self, start: float, dur: float, degree: int, amp: float) -> None:
        step = 0.5
        tones = (degree, degree + 2, degree + 4, degree + 2)
        i = 0
        t = start
        end = start + dur
        while t < end - 0.1:
            tone = tones[i % 4]
            midi = midi_of(self.root, self.scale, tone, -1)
            while midi < 52:
                midi += 12
            while midi > 70:
                midi -= 12
            self._tone(self.harm, t, 0.22, midi, amp, "string", -0.12 if i % 2 == 0 else 0.12)
            t += step
            i += 1

    def render(self) -> tuple:
        sections = _sections_for(self.spec)
        bars = sum(s["bars"] for s in sections)
        if self.spec.get("bars_override"):
            bars = int(self.spec["bars_override"])
        total_beats = bars * 4.0
        n = int(round(seconds_of(self.bpm, bars) * SR))
        self._ensure(n)
        beat_cursor = 0.0
        for section in sections:
            sec_beats = section["bars"] * 4.0
            chords = _chords_for(self.spec, section["name"])
            slot = sec_beats / float(len(chords))
            self.schedule_melody(beat_cursor, beat_cursor + sec_beats, section)
            for i, degree in enumerate(chords):
                c0 = beat_cursor + i * slot
                self.schedule_harmony(c0, slot, int(degree), section)
                pattern = section.get("pulse") or "none"
                self.schedule_pulse_pitched(c0, slot, pattern)
                if section.get("ostinato"):
                    self.schedule_ostinato(c0, slot, int(degree), 0.04 if section["name"] != "intro" else 0.0)
            beat_cursor += sec_beats
        lead_r = self.lead.gated_rms()
        harm_r = self.harm.gated_rms()
        if harm_r > 1e-6 and lead_r > 1e-6:
            self.lead.scale((1.08 * harm_r) / lead_r)
        rhy_r = self.rhythm.gated_rms()
        if rhy_r > 1e-6 and harm_r > 1e-6:
            self.rhythm.scale(min(1.4, (0.42 * harm_r) / rhy_r))
        left = self.lead.L + self.harm.L + self.rhythm.L
        right = self.lead.R + self.harm.R + self.rhythm.R
        # Section contrast guard: compare first quarter to the loudest quarter.
        q = n // 4
        energies = []
        for i in range(4):
            sl = left[i * q : (i + 1) * q]
            energies.append(float(np.sqrt(np.mean(sl * sl) + 1e-18)))
        contrast = max(energies) / max(min(energies), 1e-8)
        left, right = engine.finish(left, right, self.spec.get("space", "room"))
        meta = {
            "bars": bars,
            "seconds": n / float(SR),
            "contrast": round(contrast, 3),
        }
        return left, right, meta


def render_track(spec: dict) -> tuple:
    score = Score(spec)
    return score.render()


def write_track(spec: dict, out_dir: Path) -> dict:
    left, right, meta = render_track(spec)
    serial = engine.track_seed(spec["id"]) & 0xFFFFFFFF
    path = out_dir / ("%s.ogg" % spec["id"])
    engine.write_ogg(path, left, right, serial, QUALITY)
    info = engine.probe_vorbis(path.read_bytes())
    decoded = engine.decode_ogg_f32(path)
    level = engine.rms_db(decoded)
    row = {
        "id": spec["id"],
        "file": path.name,
        "purpose": spec["purpose"],
        "bpm": spec["bpm"],
        "scale": spec["scale"],
        "root_midi": spec["root"],
        "lead": spec.get("lead", "celesta"),
        "bars": meta["bars"],
        "seconds": round(info["seconds"], 3),
        "channels": info["channels"],
        "rate": info["rate"],
        "bytes": path.stat().st_size,
        "sha256": engine.sha256_file(path),
        "rms_db": round(level, 2),
        "contrast": meta["contrast"],
        "seed": engine.SEED,
        "quality": QUALITY,
        "generator": "tools/audio/compose_v92.py",
    }
    if info["channels"] != 2 or info["rate"] != SR or info["seconds"] < 60.0:
        raise SystemExit("bad metadata for %s: %s" % (spec["id"], info))
    if not (-18.0 <= level <= -14.0):
        raise SystemExit("loudness %s rms %s outside -16±2" % (spec["id"], level))
    if meta["contrast"] < 1.12 and not spec.get("layer"):
        raise SystemExit("flat arrangement %s contrast %s" % (spec["id"], meta["contrast"]))
    return row


def write_sidecar(rows: list, out_dir: Path) -> None:
    catalog = {
        "seed": engine.SEED,
        "generator": "tools/audio/compose_v92.py",
        "quality": QUALITY,
        "motif": "scale degrees 0-2-4-3-1-0 (tonic, third, fifth, fourth, second, tonic)",
        "tracks": rows,
    }
    (out_dir / "catalog.json").write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    lines = [
        "# 百年骑士曲库许可",
        "",
        "全部曲目由仓库内 `tools/audio/compose_v92.py` 以固定种子 `%d` 程序化合成。" % engine.SEED,
        "没有第三方采样、录音或曲库。编码为双声道 44.1 kHz Ogg Vorbis（libvorbis quality %d）。" % QUALITY,
        "重跑该脚本必须得到逐字节相同的文件。Ogg 页序列号在合成后被改写为曲目种子，以去掉 ffmpeg 的随机序列号。",
        "",
        "| 文件 | 用途 | 时长 | sha256 |",
        "|---|---|---|---|",
    ]
    for row in rows:
        lines.append(
            "| `%s` | %s | %.1f s | `%s` |"
            % (row["file"], row["purpose"], row["seconds"], row["sha256"])
        )
    lines.append("")
    lines.append("汇总体积：%d 字节（%.2f MiB）。" % (sum(r["bytes"] for r in rows), sum(r["bytes"] for r in rows) / (1024 * 1024)))
    lines.append("")
    (out_dir / "LICENSES.md").write_text("\n".join(lines), encoding="utf-8")

    locale = ROOT / "project" / "data" / "locale" / "audio.csv"
    locale.parent.mkdir(parents=True, exist_ok=True)
    csv_lines = ["keys,zh_CN,en"]
    for row in rows:
        key = "audio_%s" % row["id"]
        zh = row["purpose"].replace(",", "，")
        csv_lines.append("%s,%s," % (key, zh))
    # Only rewrite locale when generating into the repo music dir, so --verify
    # temp dirs do not depend on it. The caller decides.
    return csv_lines


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", default="")
    parser.add_argument("--verify", action="store_true")
    parser.add_argument("--out", default="")
    args = parser.parse_args()
    specs = track_list()
    if args.only:
        specs = [s for s in specs if s["id"] == args.only]
        if not specs:
            print("unknown track", args.only, file=sys.stderr)
            return 1
    out_dir = Path(args.out) if args.out else MUSIC
    if args.verify:
        import tempfile

        tmp = Path(tempfile.mkdtemp(prefix="ck_audio_"))
        rows = []
        for spec in track_list():
            rows.append(write_track(spec, tmp))
        write_sidecar(rows, tmp)
        for name in [r["file"] for r in rows] + ["catalog.json", "LICENSES.md"]:
            a = (MUSIC / name).read_bytes()
            b = (tmp / name).read_bytes()
            if a != b:
                print("MISMATCH", name, len(a), len(b))
                return 1
        print("COMPOSE VERIFY PASS")
        print("tracks", len(rows), "bytes", sum(r["bytes"] for r in rows))
        return 0
    out_dir.mkdir(parents=True, exist_ok=True)
    rows = []
    for spec in specs:
        row = write_track(spec, out_dir)
        rows.append(row)
        print(
            "%s  %.1fs  %d KB  rms %.1f  contrast %.2f"
            % (row["id"], row["seconds"], row["bytes"] // 1024, row["rms_db"], row["contrast"])
        )
    if not args.only and out_dir == MUSIC:
        csv_lines = write_sidecar(rows, out_dir)
        locale = ROOT / "project" / "data" / "locale" / "audio.csv"
        locale.write_text("\n".join(csv_lines) + "\n", encoding="utf-8")
        total = sum(r["bytes"] for r in rows)
        print("TOTAL %d bytes (%.2f MiB) across %d tracks" % (total, total / (1024 * 1024), len(rows)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
