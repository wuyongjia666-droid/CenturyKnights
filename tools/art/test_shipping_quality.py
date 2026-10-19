#!/usr/bin/env python3
"""Lock the shipping encode: quality 92, native pixels, gene bank in the base export."""
from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _load():
    path = ROOT / "tools" / "art" / "compress_shipping_webp.py"
    spec = importlib.util.spec_from_file_location("compress_shipping_webp", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("compress module")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class ShippingQualityTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.mod = _load()

    def test_photo_quality_floor(self) -> None:
        mod = self.mod
        self.assertGreaterEqual(mod.PHOTO_QUALITY, 0.92)
        for parts in (("portraits",), ("portraits", "genome"), ("scenes",), ("atlas",), ("ui",), ("battle",), ("castle",), ("estates",)):
            self.assertEqual(mod.shipping_quality(parts), mod.PHOTO_QUALITY)
        self.assertIsNone(mod.shipping_quality(("doll",)))

    def test_never_shrinks(self) -> None:
        self.assertEqual(self.mod.shipping_size(1920, 1088, ("battle",)), (1920, 1088))
        self.assertEqual(self.mod.shipping_size(768, 1024, ("portraits", "genome")), (768, 1024))
        text = (ROOT / "tools" / "art" / "compress_shipping_webp.py").read_text(encoding="utf-8")
        self.assertNotIn("0.78", text)
        self.assertNotIn("0.74", text)
        self.assertNotIn("downscale", text)

    def test_gene_bank_ships_in_base_export(self) -> None:
        presets = (ROOT / "project" / "export_presets.cfg").read_text(encoding="utf-8")
        # Windows keeps the full bank (large+medium+small). Android drops large masters
        # (#316) and small siblings (export-cap-400): medium only, with tier fallback.
        self.assertEqual(
            presets.count('exclude_filter="tests/*,*.md,*farm_inbox/*,*stitch_exports/*,*_src_*/*"'),
            1,
        )
        self.assertIn("genome/bank/*_????????????????.webp", presets)
        self.assertIn("genome/bank/*.small.webp", presets)
        self.assertNotIn("gene-bank", presets)
        self.assertFalse((ROOT / "project" / "scripts" / "art" / "art_packs.gd").exists())


if __name__ == "__main__":
    unittest.main()
