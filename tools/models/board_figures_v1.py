#!/usr/bin/env python3
"""Board-figure formal kit generator (Blender 4.2 headless).

docs/design/pawn-redesign-opus.md §3.2 / §3.7 / §5 / 附录 A.

Outputs:
  project/assets/models/board/board_figures_v1.glb
  project/assets/models/board/board_figures_v1.json  (part manifest)

Run:
  blender --background --python tools/models/board_figures_v1.py [-- --out DIR]

Hand-authored overrides: drop same-named .blend/.glb under tools/models/board_parts/
(excluding farm_inbox/). Those replace generated parts before export.

Does NOT emit farm_cast whole meshes as the formal kit (#301 / #309 temporary path).
"""
from __future__ import annotations

import json
import math
import os
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUT = ROOT / "project/assets/models/board"
PARTS_DIR = ROOT / "tools/models/board_parts"
HAIR_DIR = ROOT / "project/assets/models/modules"
R = math.radians

# Palette slot ids (R channel = id/255). Matches CKBoardFigure PALETTE_KEYS order.
SLOT = {
    "hair": 0,
    "skin": 1,
    "eye": 2,
    "coat": 3,
    "coat_dark": 4,
    "apron": 5,
    "sash": 6,
    "metal": 7,
    "blade": 8,
    "house": 9,
    "crest": 10,
    "cape": 11,
    "trousers": 12,
    "boots": 13,
    "leather": 14,
    "wood": 15,
    "accent": 16,
}

# §3.2 proportions (metres). MODEL_H = 1.85; figure height 1.837 @ 5.45 heads.
MODEL_H = 1.85
HEAD_H = 0.337
CHIN_Y = MODEL_H - HEAD_H  # ~1.513
CROWN_Y = MODEL_H  # 1.85 top of hair volume
SHOULDER_Y = 1.42
HIP_Y = 0.98
NECK_Y = 1.50

MANIFEST: dict = {"version": 1, "model_h": MODEL_H, "parts": {}, "bones": [], "slots": SLOT}


def _argv_out() -> Path:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    out = DEFAULT_OUT
    i = 0
    while i < len(argv):
        if argv[i] == "--out" and i + 1 < len(argv):
            out = Path(argv[i + 1])
            i += 2
            continue
        i += 1
    out.mkdir(parents=True, exist_ok=True)
    return out


def log(*a):
    print("[board_figures_v1]", *a, flush=True)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


# ---------------------------------------------------------------------------
# Mesh helpers
# ---------------------------------------------------------------------------
def _ensure_color(me):
    if not me.color_attributes:
        me.color_attributes.new(name="Color", type="BYTE_COLOR", domain="CORNER")
    return me.color_attributes[0]


def paint_slots(ob, slot_name: str, metal: bool = False, glow: bool = False, ao_fn=None):
    """Write vertex colours: R=slot/255, G=AO, B=flags (metal|glow)."""
    me = ob.data
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="OBJECT")
    # Apply transforms so AO height is in world/object space after apply
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    sid = SLOT[slot_name]
    flags = 0.0
    if metal:
        flags += 0.25  # bit-ish via 0.25 = metal
    if glow:
        flags += 0.50
    attr = _ensure_color(me)
    # BYTE_COLOR domain CORNER
    for poly in me.polygons:
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            co = me.vertices[vi].co
            y = float(co.z)  # Blender Z-up → height
            if ao_fn:
                ao = ao_fn(y)
            else:
                # feet 0.80 → full at 1.25m
                t = max(0.0, min(1.0, y / 1.25))
                ao = 0.80 + 0.20 * t
            attr.data[li].color = (sid / 255.0, ao, flags, 1.0)
    me.update()


def taper_box(name, w0, d0, w1, d1, h, z0, x=0.0, y=0.0, bevel=0.01, segs=2):
    bm = bmesh.new()
    vs = []
    for (w, d, z) in ((w0, d0, z0), (w1, d1, z0 + h)):
        for (sx, sy) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            vs.append(bm.verts.new((x + sx * w * 0.5, y + sy * d * 0.5, z)))
    faces = [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    for t in faces:
        bm.faces.new([vs[i] for i in t])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    if bevel > 0:
        md = ob.modifiers.new("bev", "BEVEL")
        md.width = bevel
        md.segments = segs
        md.limit_method = "ANGLE"
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.modifier_apply(modifier=md.name)
    return ob


def cyl(name, r0, r1, p0, p1, verts=10):
    p0 = Vector(p0)
    p1 = Vector(p1)
    d = p1 - p0
    length = d.length
    if length < 1e-6:
        length = 0.01
        d = Vector((0, 0, 0.01))
    bpy.ops.mesh.primitive_cone_add(
        vertices=verts, radius1=r0, radius2=r1, depth=length, location=(p0 + p1) * 0.5
    )
    ob = bpy.context.active_object
    ob.name = name
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    return ob


def sph(name, r, loc, scale=(1, 1, 1), seg=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=max(6, seg // 2), radius=r, location=loc)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return ob


def tris(ob) -> int:
    me = ob.data
    return sum(len(p.vertices) - 2 for p in me.polygons)


def join_objects(name: str, objs: list) -> bpy.types.Object:
    assert objs
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    ob = bpy.context.active_object
    ob.name = name
    return ob


def register_part(ob, category: str, tags: list | None = None):
    paint_existing = False
    # If no colour attr yet, caller should have painted; still record.
    n = tris(ob)
    MANIFEST["parts"][ob.name] = {
        "category": category,
        "tris": n,
        "tags": tags or [],
    }
    log("part", ob.name, "tris", n, category)


# ---------------------------------------------------------------------------
# Armature (§3.2 joint placement; bone names match build_standins_v86)
# ---------------------------------------------------------------------------
def build_armature():
    bones = [
        ("root", (0, 0, 0), (0, 0, 0.25), None),
        ("hips", (0, 0, HIP_Y - 0.02), (0, 0, HIP_Y + 0.10), "root"),
        ("spine", (0, 0, HIP_Y + 0.10), (0, 0, 1.22), "hips"),
        ("chest", (0, 0, 1.22), (0, 0, SHOULDER_Y), "spine"),
        ("neck", (0, 0, SHOULDER_Y), (0, 0, NECK_Y), "chest"),
        ("head", (0, 0, NECK_Y), (0, 0, CROWN_Y - 0.05), "neck"),
    ]
    for s, sx in (("L", 1), ("R", -1)):
        sh_x = sx * 0.205
        bones += [
            (f"upper_arm.{s}", (sh_x, 0, SHOULDER_Y - 0.02), (sx * 0.27, 0.02, 1.12), "chest"),
            (f"forearm.{s}", (sx * 0.27, 0.02, 1.12), (sx * 0.32, 0.04, 0.86), f"upper_arm.{s}"),
            (f"hand.{s}", (sx * 0.32, 0.04, 0.86), (sx * 0.33, 0.05, 0.78), f"forearm.{s}"),
            (f"thigh.{s}", (sx * 0.098, 0, HIP_Y), (sx * 0.10, 0.01, 0.52), "hips"),
            (f"shin.{s}", (sx * 0.10, 0.01, 0.52), (sx * 0.10, 0.03, 0.08), f"thigh.{s}"),
            (f"foot.{s}", (sx * 0.10, 0.03, 0.08), (sx * 0.10, -0.12, 0.03), f"shin.{s}"),
        ]
    arm = bpy.data.armatures.new("BoardRig")
    ob = bpy.data.objects.new("BoardRig", arm)
    bpy.context.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    for n, h, t, p in bones:
        b = arm.edit_bones.new(n)
        b.head = h
        b.tail = t
        b.roll = 0
        if p:
            b.parent = arm.edit_bones[p]
            b.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    MANIFEST["bones"] = [n for n, *_ in bones]
    return ob


def skin_rigid(ob, bone_name: str, arm_ob):
    """Parent mesh to armature with single-bone vertex group (rigid)."""
    vg = ob.vertex_groups.new(name=bone_name)
    vg.add(range(len(ob.data.vertices)), 1.0, "REPLACE")
    mod = ob.modifiers.new("arm", "ARMATURE")
    mod.object = arm_ob
    ob.parent = arm_ob


# ---------------------------------------------------------------------------
# Bodies
# ---------------------------------------------------------------------------
def build_body(gender: str, heavy: bool = False):
    """gender: 'm'|'f'; heavy widens for bulwark."""
    name = f"body_{'heavy' if heavy else gender}"
    sx = 1.08 if heavy else (0.92 if gender == "f" else 1.0)
    shoulder = 0.205 * sx * (0.90 if gender == "f" else 1.0)
    hip = 0.098 * sx * (1.07 if gender == "f" else 1.0)
    h_mul = 0.965 if gender == "f" else 1.0
    parts = []
    # Pelvis / trousers upper
    parts.append(taper_box(f"{name}_pelvis", hip * 2.4, 0.18, hip * 2.6, 0.20, 0.14, HIP_Y - 0.06, bevel=0.012))
    paint_slots(parts[-1], "trousers")
    # Undershirt / skin torso — kept slim so outfit coat wraps over without gaps
    torso_w0 = shoulder * 1.15
    torso_w1 = shoulder * 1.55
    parts.append(
        taper_box(f"{name}_torso", torso_w0, 0.14, torso_w1, 0.18, 0.38, HIP_Y + 0.04, bevel=0.016, segs=2)
    )
    paint_slots(parts[-1], "coat_dark")
    # Soft waist fill (closes hip→torso seam)
    parts.append(taper_box(f"{name}_waist", hip * 2.2, 0.16, torso_w0 * 0.95, 0.15, 0.12, HIP_Y - 0.02, bevel=0.01))
    paint_slots(parts[-1], "trousers")
    # Neck — overlaps skull chin
    parts.append(cyl(f"{name}_neck", 0.048, 0.055, (0, -0.01, SHOULDER_Y - 0.04), (0, -0.02, NECK_Y + 0.04), 10))
    paint_slots(parts[-1], "skin")
    # Arms (skin under sleeves — sleeves are outfit; keep thin skin arms for body kit)
    for s, sxv in (("L", 1), ("R", -1)):
        parts.append(
            cyl(
                f"{name}_uarm_{s}",
                0.052 * sx,
                0.048 * sx,
                (sxv * shoulder, 0, SHOULDER_Y - 0.04),
                (sxv * (shoulder + 0.06), 0.02, 1.12),
                8,
            )
        )
        paint_slots(parts[-1], "skin")
        parts.append(
            cyl(
                f"{name}_farm_{s}",
                0.044 * sx,
                0.038 * sx,
                (sxv * (shoulder + 0.06), 0.02, 1.12),
                (sxv * (shoulder + 0.10), 0.04, 0.88),
                8,
            )
        )
        paint_slots(parts[-1], "skin")
        parts.append(sph(f"{name}_hand_{s}", 0.042 * sx, (sxv * (shoulder + 0.11), 0.05, 0.82), (0.9, 1.05, 1.15), 8))
        paint_slots(parts[-1], "skin")
    # Legs
    for s, sxv in (("L", 1), ("R", -1)):
        parts.append(
            cyl(
                f"{name}_thigh_{s}",
                0.076 * sx,
                0.058 * sx,
                (sxv * hip, 0, HIP_Y - 0.02),
                (sxv * (hip + 0.01), 0.01, 0.54),
                8,
            )
        )
        paint_slots(parts[-1], "trousers")
        parts.append(
            cyl(
                f"{name}_shin_{s}",
                0.052 * sx,
                0.040 * sx,
                (sxv * (hip + 0.01), 0.01, 0.54),
                (sxv * (hip + 0.01), 0.03, 0.10),
                8,
            )
        )
        paint_slots(parts[-1], "boots")
        parts.append(
            taper_box(
                f"{name}_boot_{s}",
                0.09 * sx,
                0.20,
                0.08 * sx,
                0.14,
                0.09,
                0.0,
                x=sxv * (hip + 0.01),
                y=-0.03,
                bevel=0.008,
            )
        )
        paint_slots(parts[-1], "boots")
    # Scale female height
    ob = join_objects(name, parts)
    if h_mul != 1.0:
        ob.scale = (1.0, 1.0, h_mul)
        bpy.ops.object.transform_apply(scale=True)
    register_part(ob, "body", [gender, "heavy" if heavy else "std"])
    return ob


# ---------------------------------------------------------------------------
# Heads — blocky face readable under soft light (§3.7: brow/nose/cheek/jaw)
# ---------------------------------------------------------------------------
def build_head(gender: str):
    name = f"head_{gender}"
    # Built so chin sits on NECK_Y; skull overlaps neck cylinder.
    sx = 0.95 if gender == "f" else 1.0
    parts = []
    # Skull — lower so neck inserts into chin
    parts.append(sph(f"{name}_skull", 0.118 * sx, (0, -0.02, NECK_Y + HEAD_H * 0.42), (1.02, 0.96, 1.10), 16))
    paint_slots(parts[-1], "skin")
    # Jaw / chin block
    parts.append(
        sph(f"{name}_jaw", 0.082 * sx, (0, 0.01, NECK_Y + HEAD_H * 0.12), (1.08, 0.88, 0.72), 12)
    )
    paint_slots(parts[-1], "skin")
    # Cheek bones
    for s, sxv in (("L", 1), ("R", -1)):
        parts.append(
            sph(f"{name}_cheek_{s}", 0.035 * sx, (sxv * 0.07 * sx, -0.04, NECK_Y + HEAD_H * 0.38), (1.1, 0.8, 0.9), 8)
        )
        paint_slots(parts[-1], "skin")
    # Brow ridge
    parts.append(
        taper_box(
            f"{name}_brow",
            0.14 * sx,
            0.04,
            0.13 * sx,
            0.035,
            0.028,
            NECK_Y + HEAD_H * 0.52,
            y=-0.10,
            bevel=0.004,
            segs=1,
        )
    )
    paint_slots(parts[-1], "skin")
    # Nose
    parts.append(
        taper_box(
            f"{name}_nose",
            0.022,
            0.04,
            0.016,
            0.02,
            0.055,
            NECK_Y + HEAD_H * 0.34,
            y=-0.12,
            bevel=0.003,
            segs=1,
        )
    )
    paint_slots(parts[-1], "skin")
    # Eyes (dark blocks)
    for s, sxv in (("L", 1), ("R", -1)):
        parts.append(
            taper_box(
                f"{name}_eye_{s}",
                0.028,
                0.012,
                0.026,
                0.010,
                0.014,
                NECK_Y + HEAD_H * 0.46,
                x=sxv * 0.038,
                y=-0.112,
                bevel=0.0,
                segs=1,
            )
        )
        paint_slots(parts[-1], "eye")
    ob = join_objects(name, parts)
    register_part(ob, "head", [gender])
    return ob


# ---------------------------------------------------------------------------
# Hair LOD — procedural silhouettes matching 8 styles (≤1.2k tris each)
# Prefer decimated import from modules/hair_*.glb when present.
# ---------------------------------------------------------------------------
def _decimate_to(ob, max_tris: int):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    for _ in range(12):
        n = tris(ob)
        if n <= max_tris:
            break
        md = ob.modifiers.new("dec", "DECIMATE")
        md.decimate_type = "COLLAPSE"
        md.ratio = max(0.05, min(0.95, (max_tris * 0.92) / max(n, 1)))
        try:
            bpy.ops.object.modifier_apply(modifier=md.name)
        except Exception:
            ob.modifiers.remove(md)
            break


def _import_hair_lod(style: str) -> bpy.types.Object | None:
    src = HAIR_DIR / f"hair_{style}.glb"
    if not src.is_file():
        return None
    before = {o.name for o in bpy.data.objects}
    try:
        bpy.ops.import_scene.gltf(filepath=str(src))
    except Exception as e:
        log("hair import fail", style, e)
        return None
    new = [o for o in bpy.data.objects if o.name not in before and o.type == "MESH"]
    if not new:
        return None
    bpy.ops.object.select_all(action="DESELECT")
    for o in new:
        o.select_set(True)
    bpy.context.view_layer.objects.active = new[0]
    if len(new) > 1:
        bpy.ops.object.join()
    ob = bpy.context.active_object
    # Drop materials / textures — vertex colour only
    ob.data.materials.clear()
    # Place roughly on board head (modules are head-bone space; shift to world chin)
    # Head-bone origin ≈ neck; move so crown sits near CROWN_Y
    # Measure and fit
    co = [v.co for v in ob.data.vertices]
    if not co:
        return None
    zs = [v.z for v in co]
    zmin, zmax = min(zs), max(zs)
    # Map module chin~-0.02 / crown~0.25 → CHIN_Y / CROWN_Y-ish
    span = max(0.05, zmax - zmin)
    target_span = HEAD_H * 0.95
    scale = target_span / span
    ob.scale = (scale, scale, scale)
    bpy.ops.object.transform_apply(scale=True)
    co = [v.co for v in ob.data.vertices]
    zs = [v.z for v in co]
    zmin = min(zs)
    # Lift so base sits near mid-skull
    dz = (CHIN_Y + HEAD_H * 0.35) - zmin
    ob.location.z += dz
    bpy.ops.object.transform_apply(location=True)
    _decimate_to(ob, 1200)
    ob.name = f"hair_{style}"
    paint_slots(ob, "hair")
    return ob


def _proc_hair(style: str) -> bpy.types.Object:
    """Fallback procedural hair caps when farmed modules missing."""
    name = f"hair_{style}"
    parts = []
    base_z = CHIN_Y + HEAD_H * 0.45
    # Cap
    parts.append(sph(f"{name}_cap", 0.125, (0, -0.01, base_z + 0.08), (1.05, 1.0, 0.85), 12))
    paint_slots(parts[-1], "hair")
    if style in ("bob", "long", "messy"):
        # Volume below ears
        h = 0.22 if style == "long" else (0.14 if style == "bob" else 0.16)
        parts.append(sph(f"{name}_vol", 0.11, (0, 0.02, base_z - 0.02), (1.15, 1.05, h / 0.11), 10))
        paint_slots(parts[-1], "hair")
    if style == "pony":
        parts.append(cyl(f"{name}_tail", 0.04, 0.025, (0, 0.08, base_z + 0.05), (0, 0.22, base_z - 0.25), 8))
        paint_slots(parts[-1], "hair")
    if style == "tied":
        parts.append(sph(f"{name}_bun", 0.06, (0, 0.10, base_z + 0.12), (1.1, 1.0, 0.9), 8))
        paint_slots(parts[-1], "hair")
    if style == "crown":
        parts.append(taper_box(f"{name}_crest", 0.16, 0.06, 0.14, 0.05, 0.08, base_z + 0.14, y=0.02, bevel=0.01))
        paint_slots(parts[-1], "hair")
    if style == "swept":
        parts.append(sph(f"{name}_sweep", 0.09, (0.04, -0.06, base_z + 0.10), (1.3, 0.9, 0.7), 10))
        paint_slots(parts[-1], "hair")
    if style == "crop":
        parts.append(sph(f"{name}_side", 0.08, (0, -0.02, base_z + 0.02), (1.1, 0.95, 0.55), 10))
        paint_slots(parts[-1], "hair")
    ob = join_objects(name, parts)
    _decimate_to(ob, 1200)
    return ob


def build_hair(style: str):
    ob = _import_hair_lod(style)
    if ob is None:
        ob = _proc_hair(style)
    # Enforce name + budget
    ob.name = f"hair_{style}"
    if tris(ob) > 1200:
        _decimate_to(ob, 1200)
    register_part(ob, "hair", [style])
    return ob


# ---------------------------------------------------------------------------
# Outfits / weapons / bandit
# ---------------------------------------------------------------------------
def build_outfit_coat(name: str, hem: str = "mid", cape: bool = False, apron: bool = False, scarf: bool = False):
    """hem: short|mid|long|armor."""
    parts = []
    hem_z = {"short": 0.92, "mid": 0.74, "long": 0.48, "armor": 0.66}[hem]
    # Outer coat — wider & taller to fully wrap undershirt (no silhouette gaps)
    coat_h = (SHOULDER_Y + 0.02) - hem_z
    parts.append(taper_box(f"{name}_coat", 0.34, 0.22, 0.46, 0.28, coat_h, hem_z, bevel=0.018, segs=2))
    paint_slots(parts[-1], "coat")
    # Chest plate / front volume
    parts.append(taper_box(f"{name}_chest", 0.30, 0.10, 0.34, 0.12, 0.22, HIP_Y + 0.22, y=-0.10, bevel=0.012))
    paint_slots(parts[-1], "coat")
    # Collar / lining
    parts.append(taper_box(f"{name}_collar", 0.24, 0.18, 0.20, 0.15, 0.08, SHOULDER_Y - 0.04, bevel=0.008))
    paint_slots(parts[-1], "coat_dark")
    # Sleeves — thicker, overlap shoulders
    for s, sx in (("L", 1), ("R", -1)):
        parts.append(sph(f"{name}_shoulder_{s}", 0.08, (sx * 0.20, 0.0, SHOULDER_Y - 0.02), (1.15, 0.95, 0.75), 10))
        paint_slots(parts[-1], "coat")
        parts.append(cyl(f"{name}_sleeve_{s}", 0.065, 0.052, (sx * 0.22, 0, SHOULDER_Y - 0.04), (sx * 0.31, 0.03, 1.00), 10))
        paint_slots(parts[-1], "coat")
    if apron:
        parts.append(taper_box(f"{name}_apron", 0.28, 0.04, 0.30, 0.04, 0.36, 0.72, y=-0.12, bevel=0.008))
        paint_slots(parts[-1], "apron")
    if scarf:
        parts.append(taper_box(f"{name}_scarf", 0.20, 0.06, 0.10, 0.04, 0.22, SHOULDER_Y - 0.12, y=-0.10, bevel=0.01))
        paint_slots(parts[-1], "sash")
    if cape:
        # Simple cape drape (+Y back in Blender standins; here -Y is face so +Y back)
        bm = bmesh.new()
        rows, cols = 6, 5
        grid = []
        for i in range(rows + 1):
            t = i / rows
            z = SHOULDER_Y - 0.02 - t * 0.70
            w = 0.34 + 0.14 * t
            yb = 0.12 + 0.10 * t
            row = []
            for j in range(cols + 1):
                u = j / cols - 0.5
                row.append(bm.verts.new((u * w, yb + 0.04 * (u * 2) ** 2, z)))
            grid.append(row)
        for i in range(rows):
            for j in range(cols):
                bm.faces.new((grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]))
        me = bpy.data.meshes.new(f"{name}_cape")
        bm.to_mesh(me)
        bm.free()
        cp = bpy.data.objects.new(f"{name}_cape", me)
        bpy.context.collection.objects.link(cp)
        md = cp.modifiers.new("sol", "SOLIDIFY")
        md.thickness = 0.028
        bpy.context.view_layer.objects.active = cp
        bpy.ops.object.modifier_apply(modifier=md.name)
        paint_slots(cp, "cape")
        parts.append(cp)
    # House belt tab
    parts.append(taper_box(f"{name}_belt", 0.30, 0.06, 0.30, 0.06, 0.04, HIP_Y + 0.02, bevel=0.002, segs=1))
    paint_slots(parts[-1], "house", glow=True)
    ob = join_objects(name, parts)
    register_part(ob, "outfit", [hem])
    return ob


def build_weapon(kind: str):
    name = f"weapon_{kind}"
    parts = []
    hx, hy, hz = -0.32, -0.04, 0.86  # right hand (facing -Y)
    if kind == "sword":
        parts.append(taper_box(f"{name}_grip", 0.028, 0.028, 0.028, 0.028, 0.14, hz - 0.08, x=hx, y=hy, bevel=0.0))
        paint_slots(parts[-1], "leather")
        parts.append(taper_box(f"{name}_guard", 0.16, 0.035, 0.16, 0.035, 0.025, hz + 0.06, x=hx, y=hy, bevel=0.004))
        paint_slots(parts[-1], "metal", metal=True)
        parts.append(taper_box(f"{name}_blade", 0.048, 0.012, 0.012, 0.004, 0.86, hz + 0.09, x=hx, y=hy, bevel=0.002))
        paint_slots(parts[-1], "blade", metal=True)
    elif kind == "greatsword":
        parts.append(taper_box(f"{name}_grip", 0.032, 0.032, 0.032, 0.032, 0.22, hz - 0.12, x=hx, y=hy, bevel=0.0))
        paint_slots(parts[-1], "leather")
        parts.append(taper_box(f"{name}_guard", 0.22, 0.04, 0.22, 0.04, 0.03, hz + 0.10, x=hx, y=hy, bevel=0.004))
        paint_slots(parts[-1], "metal", metal=True)
        parts.append(taper_box(f"{name}_blade", 0.06, 0.014, 0.014, 0.004, 1.10, hz + 0.13, x=hx, y=hy, bevel=0.002))
        paint_slots(parts[-1], "blade", metal=True)
    elif kind == "axe":
        parts.append(taper_box(f"{name}_haft", 0.032, 0.032, 0.028, 0.028, 0.70, hz - 0.18, x=hx, y=hy, bevel=0.0))
        paint_slots(parts[-1], "wood")
        parts.append(taper_box(f"{name}_head", 0.04, 0.22, 0.012, 0.28, 0.18, hz + 0.38, x=hx, y=hy - 0.08, bevel=0.004))
        paint_slots(parts[-1], "blade", metal=True)
    elif kind == "bow":
        # Simplified D-bow on left side
        lx = 0.30
        bpy.ops.mesh.primitive_torus_add(major_radius=0.48, minor_radius=0.014, location=(lx, hy, hz), major_segments=24, minor_segments=8)
        bw = bpy.context.active_object
        bw.name = f"{name}_bow"
        bw.rotation_euler = (R(90), 0, R(15))
        bpy.ops.object.transform_apply(rotation=True)
        paint_slots(bw, "wood")
        parts.append(bw)
        parts.append(cyl(f"{name}_quiver", 0.045, 0.045, (0.10, 0.14, 1.05), (0.14, 0.16, 1.42), 8))
        paint_slots(parts[-1], "leather")
    elif kind == "staff":
        parts.append(cyl(f"{name}_shaft", 0.018, 0.016, (hx, hy, 0.15), (hx, hy, 1.55), 8))
        paint_slots(parts[-1], "wood")
        parts.append(sph(f"{name}_orb", 0.05, (hx, hy, 1.58), seg=10))
        paint_slots(parts[-1], "accent", glow=True)
    elif kind == "spear":
        parts.append(cyl(f"{name}_shaft", 0.016, 0.014, (hx, hy, 0.10), (hx, hy, 1.70), 8))
        paint_slots(parts[-1], "wood")
        parts.append(taper_box(f"{name}_tip", 0.05, 0.012, 0.004, 0.004, 0.22, 1.70, x=hx, y=hy, bevel=0.002))
        paint_slots(parts[-1], "blade", metal=True)
    elif kind == "club":
        parts.append(cyl(f"{name}_club", 0.035, 0.055, (hx, hy, hz - 0.15), (hx, hy, hz + 0.45), 8))
        paint_slots(parts[-1], "wood")
    elif kind == "banner":
        parts.append(cyl(f"{name}_pole", 0.016, 0.016, (hx, hy, 0.10), (hx, hy, 1.75), 8))
        paint_slots(parts[-1], "wood")
        parts.append(taper_box(f"{name}_flag", 0.02, 0.28, 0.02, 0.32, 0.36, 1.40, x=hx + 0.14, y=hy, bevel=0.0))
        paint_slots(parts[-1], "house", glow=True)
    else:
        # dagger default
        parts.append(taper_box(f"{name}_blade", 0.03, 0.01, 0.008, 0.004, 0.32, hz, x=hx, y=hy, bevel=0.002))
        paint_slots(parts[-1], "blade", metal=True)
    ob = join_objects(name, parts)
    register_part(ob, "weapon", [kind])
    return ob


def build_bandit_outfit(tier: str):
    """tier: weak|bandit|archer|chief."""
    name = f"outfit_bandit_{tier}"
    parts = []
    if tier == "weak":
        parts.append(taper_box(f"{name}_tunic", 0.34, 0.20, 0.36, 0.22, 0.40, 0.90, bevel=0.012))
        paint_slots(parts[-1], "coat")
    else:
        parts.append(taper_box(f"{name}_vest", 0.36, 0.22, 0.40, 0.24, 0.36, 0.95, bevel=0.014))
        paint_slots(parts[-1], "coat")
        parts.append(taper_box(f"{name}_lining", 0.28, 0.16, 0.30, 0.18, 0.10, 1.20, bevel=0.006))
        paint_slots(parts[-1], "coat_dark")
    if tier in ("bandit", "chief"):
        parts.append(taper_box(f"{name}_strap", 0.06, 0.04, 0.06, 0.04, 0.40, 0.95, x=0.10, y=-0.10, bevel=0.0))
        paint_slots(parts[-1], "leather")
    if tier == "archer":
        parts.append(taper_box(f"{name}_hood", 0.22, 0.18, 0.20, 0.16, 0.12, SHOULDER_Y - 0.02, y=0.04, bevel=0.01))
        paint_slots(parts[-1], "coat_dark")
    if tier == "chief":
        # Coral cape
        bm = bmesh.new()
        rows, cols = 5, 4
        grid = []
        for i in range(rows + 1):
            t = i / rows
            z = SHOULDER_Y - t * 0.75
            w = 0.36 + 0.16 * t
            yb = 0.14 + 0.12 * t
            row = [bm.verts.new(((j / cols - 0.5) * w, yb, z)) for j in range(cols + 1)]
            grid.append(row)
        for i in range(rows):
            for j in range(cols):
                bm.faces.new((grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]))
        me = bpy.data.meshes.new(f"{name}_cape")
        bm.to_mesh(me)
        bm.free()
        cp = bpy.data.objects.new(f"{name}_cape", me)
        bpy.context.collection.objects.link(cp)
        md = cp.modifiers.new("sol", "SOLIDIFY")
        md.thickness = 0.030
        bpy.context.view_layer.objects.active = cp
        bpy.ops.object.modifier_apply(modifier=md.name)
        paint_slots(cp, "cape")
        parts.append(cp)
        # Scale note: chief ×1.06 applied at assemble time
    # Crest coral tab
    parts.append(taper_box(f"{name}_crest", 0.08, 0.04, 0.08, 0.04, 0.10, 1.25, y=-0.12, bevel=0.0))
    paint_slots(parts[-1], "crest", glow=True)
    ob = join_objects(name, parts)
    register_part(ob, "outfit", ["bandit", tier])
    return ob


def build_pauldron(side: str = "both"):
    name = f"sign_pauldron_{side}"
    parts = []
    sides = [("L", 1), ("R", -1)] if side == "both" else ([("L", 1)] if side == "L" else [("R", -1)])
    for s, sx in sides:
        parts.append(sph(f"{name}_{s}", 0.09, (sx * 0.23, 0.0, SHOULDER_Y - 0.02), (1.15, 1.0, 0.7), 10))
        paint_slots(parts[-1], "metal", metal=True)
    ob = join_objects(name, parts)
    register_part(ob, "sign", ["pauldron", side])
    return ob


# ---------------------------------------------------------------------------
# Hand-authored overrides
# ---------------------------------------------------------------------------
def apply_overrides():
    if not PARTS_DIR.is_dir():
        return
    for path in sorted(PARTS_DIR.iterdir()):
        if path.name.startswith(".") or path.name == "farm_inbox" or path.name == "README.md":
            continue
        stem = path.stem
        if path.suffix.lower() not in (".glb", ".gltf", ".blend"):
            continue
        log("override import", path.name)
        before = {o.name for o in bpy.data.objects}
        if path.suffix.lower() == ".blend":
            with bpy.data.libraries.load(str(path)) as (data_from, data_to):
                data_to.objects = list(data_from.objects)
            for o in data_to.objects:
                if o:
                    bpy.context.collection.objects.link(o)
        else:
            bpy.ops.import_scene.gltf(filepath=str(path))
        new = [o for o in bpy.data.objects if o.name not in before and o.type == "MESH"]
        if not new:
            continue
        # Remove generated part with same name
        old = bpy.data.objects.get(stem)
        if old:
            bpy.data.objects.remove(old, do_unlink=True)
        bpy.ops.object.select_all(action="DESELECT")
        for o in new:
            o.select_set(True)
        bpy.context.view_layer.objects.active = new[0]
        if len(new) > 1:
            bpy.ops.object.join()
        ob = bpy.context.active_object
        ob.name = stem
        if not ob.data.color_attributes:
            paint_slots(ob, "coat")
        cat = MANIFEST["parts"].get(stem, {}).get("category", "override")
        register_part(ob, cat, ["override"])


# ---------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------
def export_glb(out_dir: Path, arm_ob):
    # Select armature + all mesh parts
    bpy.ops.object.select_all(action="DESELECT")
    arm_ob.select_set(True)
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.select_set(True)
    bpy.context.view_layer.objects.active = arm_ob
    glb = out_dir / "board_figures_v1.glb"
    bpy.ops.export_scene.gltf(
        filepath=str(glb),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_vertex_color="ACTIVE",
        export_all_vertex_colors=True,
        export_active_vertex_color_when_no_material=True,
        export_materials="NONE",
        export_texcoords=False,
        export_normals=True,
        export_animations=False,
        export_skins=True,
        export_morph=False,
    )
    log("wrote", glb, "bytes", glb.stat().st_size)
    return glb


def main() -> int:
    out_dir = _argv_out()
    reset()
    log("building formal kit →", out_dir)
    arm = build_armature()

    bodies = [build_body("m"), build_body("f"), build_body("m", heavy=True)]
    heads = [build_head("m"), build_head("f")]
    hairs = [build_hair(s) for s in ("bob", "crop", "crown", "long", "messy", "pony", "swept", "tied")]

    outfits = [
        build_outfit_coat("outfit_captain", hem="mid", cape=True, scarf=False),
        build_outfit_coat("outfit_squire", hem="short", cape=True),
        build_outfit_coat("outfit_hunter", hem="short", apron=False),
        build_outfit_coat("outfit_light_inf", hem="mid"),
        build_outfit_coat("outfit_heavy_inf", hem="armor"),
        build_outfit_coat("outfit_apprentice", hem="long"),
        build_outfit_coat("outfit_militia", hem="short"),
        build_outfit_coat("outfit_banner", hem="mid", cape=False),
        build_bandit_outfit("weak"),
        build_bandit_outfit("bandit"),
        build_bandit_outfit("archer"),
        build_bandit_outfit("chief"),
    ]
    weapons = [
        build_weapon(k)
        for k in ("sword", "greatsword", "axe", "bow", "staff", "spear", "club", "banner", "dagger")
    ]
    signs = [build_pauldron("both"), build_pauldron("L"), build_pauldron("R")]

    # Skin all meshes rigidly to nearest logical bone (simplified: hips for body/outfit, head for head/hair, hand.R for weapons)
    for ob in bodies + outfits:
        skin_rigid(ob, "hips", arm)
    for ob in heads + hairs:
        skin_rigid(ob, "head", arm)
    for ob in weapons:
        skin_rigid(ob, "hand.R", arm)
    for ob in signs:
        skin_rigid(ob, "chest", arm)

    apply_overrides()

    # Drop anonymous leftovers (e.g. unused prims).
    for o in list(bpy.data.objects):
        if o.type == "MESH" and o.name not in MANIFEST["parts"] and not o.name.startswith("Board"):
            log("remove orphan", o.name)
            bpy.data.objects.remove(o, do_unlink=True)

    # Enforce hair LOD budget and refresh tris counts after overrides / joins.
    for o in list(bpy.data.objects):
        if o.type != "MESH":
            continue
        if o.name.startswith("hair_") and tris(o) > 1200:
            _decimate_to(o, 1200)
            if tris(o) > 1200:
                # Remesh + collapse as last resort for stubborn farmed hair.
                bpy.ops.object.select_all(action="DESELECT")
                o.select_set(True)
                bpy.context.view_layer.objects.active = o
                md = o.modifiers.new("vox", "REMESH")
                md.mode = "VOXEL"
                md.voxel_size = 0.018
                bpy.ops.object.modifier_apply(modifier=md.name)
                _decimate_to(o, 1200)
                paint_slots(o, "hair")
                # Re-skin after remesh wiped groups
                arm_ob = bpy.data.objects.get("BoardRig")
                if arm_ob:
                    skin_rigid(o, "head", arm_ob)
            log("hair lod", o.name, tris(o))
        if o.name in MANIFEST["parts"]:
            MANIFEST["parts"][o.name]["tris"] = tris(o)

    glb = export_glb(out_dir, arm)
    # Trim manifest to existing objects
    alive = {o.name for o in bpy.data.objects if o.type == "MESH"}
    MANIFEST["parts"] = {k: v for k, v in MANIFEST["parts"].items() if k in alive}
    MANIFEST["glb"] = "board_figures_v1.glb"
    MANIFEST["total_tris"] = sum(int(v["tris"]) for v in MANIFEST["parts"].values())
    MANIFEST["part_count"] = len(MANIFEST["parts"])
    man_path = out_dir / "board_figures_v1.json"
    man_path.write_text(json.dumps(MANIFEST, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    log("manifest", man_path, "parts", MANIFEST["part_count"], "total_tris", MANIFEST["total_tris"])

    # Budget sanity: shared kit should be well under ~50k tris
    if MANIFEST["total_tris"] > 80000:
        log("WARN total tris high", MANIFEST["total_tris"])
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as e:
        log("FATAL", e)
        import traceback

        traceback.print_exc()
        raise SystemExit(1)
