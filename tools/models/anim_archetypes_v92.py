#!/usr/bin/env python3
"""CUT-02 weapon-archetype actions.

Procedural keyframes for six weapon prototypes. Times are seconds.
attack / skill / crit impact times match CutsceneTimeline.ACTION_IMPACT
(0.458 / 0.792 / 0.5). Writes archetypes_v92.json for the Godot library builder.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ACTIONS = ["idle", "advance", "attack", "skill", "hit", "dodge", "crit", "death"]
IMPACT = {"attack": 0.458, "skill": 0.792, "crit": 0.5}

READY = {
    "upper_arm.R": (20, 0, -8),
    "forearm.R": (45, 0, 0),
    "upper_arm.L": (12, 0, 8),
    "forearm.L": (30, 0, 0),
    "chest": (4, 0, 0),
}

# Per-archetype rest pose, then attack / skill / crit triples: wind, hit, follow.
ARCH = {
    "sword": {
        "ready": {"upper_arm.R": (22, 0, -12), "forearm.R": (40, 0, 0)},
        "attack": ((150, 0, -28), (58, 0, 18), (24, 0, 32)),
        "skill": ((170, 0, -8), (64, 0, -6), (30, 0, 10)),
        "crit": ((120, 0, -50), (48, 0, 36), (18, 0, 20)),
    },
    "spear": {
        "ready": {"upper_arm.R": (36, 0, -14), "forearm.R": (70, 0, 0), "upper_arm.L": (42, 0, 18), "forearm.L": (55, 0, 0)},
        "attack": ((12, 0, -22), (92, 0, 4), (78, 0, 2)),
        "skill": ((8, 0, -30), (100, 0, 8), (70, 0, 0)),
        "crit": ((20, 0, -40), (110, 0, 12), (80, 0, 6)),
    },
    "bow": {
        "ready": {"upper_arm.L": (78, 0, 12), "forearm.L": (8, 0, 0), "upper_arm.R": (48, 0, -16), "forearm.R": (90, 0, 0)},
        "attack": ((86, 0, -36), (68, 0, -62), (46, 0, -28)),
        "skill": ((96, 0, -20), (74, 0, -70), (40, 0, -18)),
        "crit": ((100, 0, -48), (60, 0, -80), (36, 0, -24)),
    },
    "staff": {
        "ready": {"upper_arm.R": (30, 0, -6), "forearm.R": (20, 0, 0), "upper_arm.L": (28, 0, 10), "forearm.L": (18, 0, 0)},
        "attack": ((168, 0, -4), (146, 0, 6), (90, 0, 0)),
        "skill": ((175, 0, 0), (158, 0, 10), (80, 0, -8)),
        "crit": ((160, 0, -20), (132, 0, 22), (70, 0, 8)),
    },
    "shield": {
        "ready": {"upper_arm.L": (18, 0, 28), "forearm.L": (50, 0, 0), "upper_arm.R": (16, 0, -10)},
        "attack": ((40, 0, -18), (36, 0, 24), (14, 0, 8)),
        "skill": ((55, 0, -24), (42, 0, 30), (12, 0, 6)),
        "crit": ((70, 0, -36), (28, 0, 40), (10, 0, 12)),
    },
    "heavy": {
        "ready": {"upper_arm.R": (28, 0, -20), "forearm.R": (55, 0, 0), "upper_arm.L": (24, 0, 16), "chest": (8, 0, 0)},
        "attack": ((165, 0, -40), (22, 0, 28), (10, 0, 16)),
        "skill": ((172, 0, -16), (18, 0, -8), (8, 0, 4)),
        "crit": ((150, 0, -55), (12, 0, 44), (6, 0, 18)),
    },
}


def _pose(arch: str, **over: tuple) -> dict:
    pose = dict(READY)
    pose.update(ARCH[arch]["ready"])
    pose.update(over)
    return {bone: [round(v, 3) for v in ang] for bone, ang in pose.items()}


def _arm(arch: str, kind: str, which: int, **extra: tuple) -> dict:
    x, y, z = ARCH[arch][kind][which]
    over = {"upper_arm.R": (x, y, z)}
    over.update(extra)
    return _pose(arch, **over)


def _clip(length: float, keys: list, loop: bool = False, impact: float | None = None) -> dict:
    clip = {"length": length, "loop": loop, "keys": keys}
    if impact is not None:
        clip["impact"] = impact
    return clip


def build_archetype(name: str) -> dict:
    attack_hit = IMPACT["attack"]
    skill_hit = IMPACT["skill"]
    crit_hit = IMPACT["crit"]
    idle_len = 1.6
    advance_len = 0.52
    return {
        "idle": _clip(idle_len, [
            {"t": 0.0, "bones": _pose(name)},
            {"t": idle_len * 0.5, "bones": _pose(name, chest=(7, 0, 0))},
            {"t": idle_len, "bones": _pose(name)},
        ], loop=True),
        "advance": _clip(advance_len, [
            {"t": 0.0, "bones": _pose(name, chest=(12, 0, 4), **{"upper_arm.R": (28, 0, -16)})},
            {"t": advance_len * 0.5, "bones": _pose(name, chest=(12, 0, -4), **{"upper_arm.R": (16, 0, -4)})},
            {"t": advance_len, "bones": _pose(name, chest=(12, 0, 4), **{"upper_arm.R": (28, 0, -16)})},
        ], loop=True),
        "attack": _clip(0.92, [
            {"t": 0.0, "bones": _pose(name)},
            {"t": round(attack_hit * 0.55, 4), "bones": _arm(name, "attack", 0, chest=(-6, 0, 18))},
            {"t": attack_hit, "bones": _arm(name, "attack", 1, chest=(16, 0, -22))},
            {"t": round(attack_hit + 0.2, 4), "bones": _arm(name, "attack", 2, chest=(12, 0, -16))},
            {"t": 0.92, "bones": _pose(name)},
        ], impact=attack_hit),
        "skill": _clip(1.36, [
            {"t": 0.0, "bones": _pose(name)},
            {"t": round(skill_hit * 0.62, 4), "bones": _arm(name, "skill", 0, chest=(-12, 0, 0))},
            {"t": skill_hit, "bones": _arm(name, "skill", 1, chest=(24, 0, 0))},
            {"t": round(skill_hit + 0.24, 4), "bones": _arm(name, "skill", 2, chest=(14, 0, 0))},
            {"t": 1.36, "bones": _pose(name)},
        ], impact=skill_hit),
        "hit": _clip(0.56, [
            {"t": 0.0, "bones": _pose(name)},
            {"t": 0.12, "bones": _pose(name, chest=(-20, 0, 8), **{"upper_arm.R": (-8, 0, -22)})},
            {"t": 0.56, "bones": _pose(name)},
        ]),
        "dodge": _clip(0.72, [
            {"t": 0.0, "bones": _pose(name)},
            {"t": 0.22, "bones": _pose(name, chest=(-8, -14, 0), **{"upper_arm.R": (8, 0, -30)})},
            {"t": 0.4, "bones": _pose(name, chest=(-8, -14, 0))},
            {"t": 0.72, "bones": _pose(name)},
        ]),
        "crit": _clip(1.08, [
            {"t": 0.0, "bones": _pose(name)},
            {"t": round(crit_hit * 0.55, 4), "bones": _arm(name, "crit", 0, chest=(0, 0, 40))},
            {"t": crit_hit, "bones": _arm(name, "crit", 1, chest=(22, 0, -30))},
            {"t": round(crit_hit + 0.28, 4), "bones": _arm(name, "crit", 2)},
            {"t": 1.08, "bones": _pose(name)},
        ], impact=crit_hit),
        "death": _clip(1.4, [
            {"t": 0.0, "bones": _pose(name), "root": [0, 0, 0]},
            {"t": 0.42, "bones": _pose(name, chest=(22, 0, 0), **{"upper_arm.R": (-6, 0, -18)}), "root": [0, 0, -0.28]},
            {"t": 0.9, "bones": _pose(name, chest=(40, 0, 0)), "root": [0, 0, -0.55]},
            {"t": 1.4, "bones": _pose(name, chest=(40, 0, 0)), "root": [0, 0, -0.55]},
        ]),
    }


def payload() -> dict:
    return {
        "actions": ACTIONS,
        "impact": IMPACT,
        "track_root": "Rig/Skeleton3D",
        "archetypes": {name: build_archetype(name) for name in ARCH},
    }


def main() -> None:
    root = Path(__file__).resolve().parent
    out = root / "archetypes_v92.json"
    if len(sys.argv) > 1:
        out = Path(sys.argv[1])
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload(), indent=2) + "\n", encoding="utf-8")
    print("WROTE", out)


if __name__ == "__main__":
    main()
