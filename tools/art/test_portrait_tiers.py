#!/usr/bin/env python3
"""Portrait tiers: half and two-thirds grids, gene bank stays in the base export."""
from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _load():
    path = ROOT / "tools" / "art" / "build_portrait_tiers.py"
    spec = importlib.util.spec_from_file_location("build_portrait_tiers", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("tier module")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class PortraitTierTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.mod = _load()

    def test_scales_stay_even(self) -> None:
        mod = self.mod
        self.assertEqual(mod.even_size(768, 1024, 0.5), (384, 512))
        self.assertEqual(mod.even_size(768, 1024, 2.0 / 3.0), (512, 682))
        self.assertEqual(mod.QUALITY, 92)
        self.assertGreaterEqual(mod.MIN_LONG_SIDE, 640)

    def test_sample_plate_has_siblings(self) -> None:
        large = ROOT / "project/assets/art/portraits/genome/bank/elder_0133cd4f080bf504.webp"
        small = large.with_name(large.stem + ".small.webp")
        medium = large.with_name(large.stem + ".medium.webp")
        self.assertTrue(large.is_file(), "large plate missing")
        self.assertTrue(small.is_file(), "small tier missing")
        self.assertTrue(medium.is_file(), "medium tier missing")
        self.assertIn("compress/lossy_quality=0.92", Path(str(small) + ".import").read_text(encoding="utf-8"))
        from PIL import Image

        with Image.open(large) as im:
            self.assertEqual(im.size, (768, 1024))
        with Image.open(small) as im:
            self.assertEqual(im.size, (384, 512))
        with Image.open(medium) as im:
            self.assertEqual(im.size, (512, 682))


if __name__ == "__main__":
    unittest.main()
