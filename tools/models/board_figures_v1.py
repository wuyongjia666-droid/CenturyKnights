#!/usr/bin/env python3
"""Board-figure formal kit generator (Blender 4.2 headless) — organic compose overrides (farm_cast retopo + face enhance).

docs/design/pawn-redesign-opus.md §3.2 / §3.7 / §5 / 附录 A.

Formal kit must BEAT the Godot-primitive prototype (ball hands, featureless oval
head, flat coat boxes). This rewrite builds:
  - head: cranium + face plane + brow / nose / jaw / chin / cheek / recessed eyes
  - hands: palm + finger mass + thumb (mitten), not spheres
  - body: lathed waist pinch, tapered limbs, shoulder→neck transition
  - outfits: solidified coat shells with collar / lapel / hem / fold volumes
  - hair: scalp-hugging LOD caps (import farmed modules when present)

Outputs:
  project/assets/models/board/board_figures_v1.glb
  project/assets/models/board/board_figures_v1.json

Run:
  blender --background --python tools/models/board_figures_v1.py [-- --out DIR]
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUT = ROOT / "project/assets/models/board"
PARTS_DIR = ROOT / "tools/models/board_parts"
HAIR_DIR = ROOT / "project/assets/models/modules"
R = math.radians

SLOT = {
    "hair": 0, "skin": 1, "eye": 2, "coat": 3, "coat_dark": 4, "apron": 5,
    "sash": 6, "metal": 7, "blade": 8, "house": 9, "crest": 10, "cape": 11,
    "trousers": 12, "boots": 13, "leather": 14, "wood": 15, "accent": 16,
}

# §3.2 proportions (metres). MODEL_H = 1.85; figure height 1.837 @ 5.45 heads.
MODEL_H = 1.85
HEAD_H = 0.337
CHIN_Y = MODEL_H - HEAD_H  # ~1.513
CROWN_Y = MODEL_H
SHOULDER_Y = 1.42
HIP_Y = 0.98
NECK_Y = 1.50
# Face looks down −Y in Blender; glTF exporter maps that to Godot +Z.
FACE_Y = -1.0

MANIFEST: dict = {"version": 2, "model_h": MODEL_H, "parts": {}, "bones": [], "slots": SLOT,
                  "quality": "organic_compose_v3"}


def _argv_out() -> Path:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = DEFAULT_OUT
    i = 0
    while i < len(argv):
        if argv[i] == "--out" and i + 1 < len(argv):
            out = Path(argv[i + 1]); i += 2; continue
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
    me = ob.data
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    sid = SLOT[slot_name]
    flags = (0.25 if metal else 0.0) + (0.50 if glow else 0.0)
    attr = _ensure_color(me)
    for poly in me.polygons:
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            y = float(me.vertices[vi].co.z)
            if ao_fn:
                ao = ao_fn(y)
            else:
                t = max(0.0, min(1.0, y / 1.25))
                ao = 0.78 + 0.22 * t
            attr.data[li].color = (sid / 255.0, ao, flags, 1.0)
    me.update()


def tris(ob) -> int:
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


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
    if ob.data:
        ob.data.name = name
    return ob


def _obj_from_bmesh(name: str, bm) -> bpy.types.Object:
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    return ob


def _apply_mods(ob):
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    for md in list(ob.modifiers):
        try:
            bpy.ops.object.modifier_apply(modifier=md.name)
        except Exception:
            ob.modifiers.remove(md)


def bevel(ob, width=0.008, segs=2, angle=30.0):
    md = ob.modifiers.new("bev", "BEVEL")
    md.width = width
    md.segments = segs
    md.limit_method = "ANGLE"
    md.angle_limit = R(angle)
    _apply_mods(ob)
    return ob


def solidify(ob, thickness=0.024):
    md = ob.modifiers.new("sol", "SOLIDIFY")
    md.thickness = thickness
    md.offset = 1.0
    md.use_even_offset = True
    _apply_mods(ob)
    return ob


def taper_box(name, w0, d0, w1, d1, h, z0, x=0.0, y=0.0, bevel_w=0.008, segs=2):
    """Axis-aligned tapered box; depth is along Blender Y (face −Y)."""
    bm = bmesh.new()
    vs = []
    for (w, d, z) in ((w0, d0, z0), (w1, d1, z0 + h)):
        for (sx, sy) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            vs.append(bm.verts.new((x + sx * w * 0.5, y + sy * d * 0.5, z)))
    for t in ((0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
        bm.faces.new([vs[i] for i in t])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    ob = _obj_from_bmesh(name, bm)
    if bevel_w > 0:
        bevel(ob, bevel_w, segs)
    return ob


def cyl(name, r0, r1, p0, p1, verts=12):
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    length = max(d.length, 1e-4)
    bpy.ops.mesh.primitive_cone_add(
        vertices=verts, radius1=r0, radius2=r1, depth=length, location=(p0 + p1) * 0.5
    )
    ob = bpy.context.active_object
    ob.name = name
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    bpy.ops.object.transform_apply(rotation=True, scale=True)
    return ob


def sph(name, r, loc, scale=(1, 1, 1), seg=14):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=seg, ring_count=max(8, seg // 2), radius=r, location=loc
    )
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return ob


def lathe(name, rings, segs=14, y_squash=1.0):
    """rings: list of (radius, z). Body of revolution about Z, slight Y squash for depth."""
    bm = bmesh.new()
    rows = []
    for r, z in rings:
        row = []
        for i in range(segs):
            a = (i / segs) * math.tau
            row.append(bm.verts.new((r * math.cos(a), r * math.sin(a) * y_squash, z)))
        rows.append(row)
    for i in range(len(rows) - 1):
        for j in range(segs):
            j2 = (j + 1) % segs
            try:
                bm.faces.new((rows[i][j], rows[i][j2], rows[i + 1][j2], rows[i + 1][j]))
            except ValueError:
                pass
    # Closed end-caps only when radius is meaningful
    if rings[0][0] > 1e-3:
        c0 = bm.verts.new((0, 0, rings[0][1]))
        for j in range(segs):
            try:
                bm.faces.new((c0, rows[0][(j + 1) % segs], rows[0][j]))
            except ValueError:
                pass
    if rings[-1][0] > 1e-3:
        c1 = bm.verts.new((0, 0, rings[-1][1]))
        for j in range(segs):
            try:
                bm.faces.new((c1, rows[-1][j], rows[-1][(j + 1) % segs]))
            except ValueError:
                pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return _obj_from_bmesh(name, bm)


def wedge(name, w, d, h, loc, tip_scale=0.35):
    """Pyramid-ish wedge pointing −Y (nose / fold)."""
    bm = bmesh.new()
    x, y, z = loc
    # back quad (toward +Y / skull) and tip toward −Y
    b0 = bm.verts.new((x - w * 0.5, y, z - h * 0.5))
    b1 = bm.verts.new((x + w * 0.5, y, z - h * 0.5))
    b2 = bm.verts.new((x + w * 0.5, y, z + h * 0.5))
    b3 = bm.verts.new((x - w * 0.5, y, z + h * 0.5))
    tip = bm.verts.new((x, y - d, z - h * 0.15 * tip_scale))
    bm.faces.new((b0, b1, b2, b3))
    bm.faces.new((b0, tip, b1))
    bm.faces.new((b1, tip, b2))
    bm.faces.new((b2, tip, b3))
    bm.faces.new((b3, tip, b0))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return _obj_from_bmesh(name, bm)


def register_part(ob, category: str, tags: list | None = None):
    n = tris(ob)
    MANIFEST["parts"][ob.name] = {"category": category, "tris": n, "tags": tags or []}
    log("part", ob.name, "tris", n, category)


# ---------------------------------------------------------------------------
# Armature
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
        b.head = h; b.tail = t; b.roll = 0
        if p:
            b.parent = arm.edit_bones[p]
            b.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    MANIFEST["bones"] = [n for n, *_ in bones]
    return ob


def skin_rigid(ob, bone_name: str, arm_ob):
    vg = ob.vertex_groups.new(name=bone_name)
    vg.add(range(len(ob.data.vertices)), 1.0, "REPLACE")
    mod = ob.modifiers.new("arm", "ARMATURE")
    mod.object = arm_ob
    ob.parent = arm_ob


# ---------------------------------------------------------------------------
# Hands — palm + finger mass + thumb (NOT spheres)
# ---------------------------------------------------------------------------
def build_hand(name: str, side: int, sx_body: float, wrist):
    """side: +1=L / −1=R. wrist = (x,y,z) at wrist joint."""
    wx, wy, wz = wrist
    # Palm block (flattened)
    palm_w, palm_d, palm_h = 0.072 * sx_body, 0.038 * sx_body, 0.090 * sx_body
    palm = taper_box(
        f"{name}_palm", palm_w, palm_d, palm_w * 0.95, palm_d * 0.9,
        palm_h, wz - palm_h * 0.55,
        x=wx, y=wy - 0.012, bevel_w=0.007, segs=2,
    )
    # Finger mass (four fingers as one mitten — readable paddle, not a ball)
    fing = taper_box(
        f"{name}_fing", palm_w * 0.95, palm_d * 0.9, palm_w * 0.72, palm_d * 0.55,
        0.070 * sx_body, wz - palm_h * 0.55 - 0.065 * sx_body,
        x=wx, y=wy - 0.022, bevel_w=0.006, segs=1,
    )
    # Thumb stub on outer side — clear mitten silhouette
    th_x = wx + side * palm_w * 0.58
    thumb = taper_box(
        f"{name}_thumb", 0.028 * sx_body, 0.032 * sx_body, 0.020 * sx_body, 0.022 * sx_body,
        0.050 * sx_body, wz - 0.015,
        x=th_x, y=wy - 0.035, bevel_w=0.004, segs=1,
    )
    return [palm, fing, thumb]


# ---------------------------------------------------------------------------
# Bodies — lathed waist, tapered limbs
# ---------------------------------------------------------------------------
def build_body(gender: str, heavy: bool = False):
    name = f"body_{'heavy' if heavy else gender}"
    sx = 1.10 if heavy else (0.92 if gender == "f" else 1.0)
    shoulder = 0.205 * sx * (0.90 if gender == "f" else 1.0)
    hip = 0.098 * sx * (1.08 if gender == "f" else 1.0)
    h_mul = 0.965 if gender == "f" else 1.0
    waist_r = 0.125 * sx * (0.95 if gender == "f" else 1.0)
    chest_r = 0.17 * sx * (0.92 if gender == "f" else 1.0)
    hip_r = 0.16 * sx * (1.05 if gender == "f" else 1.0)
    parts = []

    # Hip / pelvis volume — wide block so lower silhouette is not stick-legs
    hips = taper_box(
        f"{name}_hips", hip_r * 2.3, 0.20 * sx, hip_r * 2.45, 0.22 * sx,
        0.22, HIP_Y - 0.12, bevel_w=0.014, segs=2,
    )
    paint_slots(hips, "trousers"); parts.append(hips)
    # Shorts volume down the thighs (reads as trousers without a flat lathe flake)
    shorts = taper_box(
        f"{name}_shorts", hip_r * 2.1, 0.18 * sx, hip_r * 1.7, 0.16 * sx,
        0.28, HIP_Y - 0.38, bevel_w=0.012, segs=2,
    )
    paint_slots(shorts, "trousers"); parts.append(shorts)

    # Undershirt torso — waist pinch, chest flare, shoulder shelf (coat wraps over)
    torso = lathe(
        f"{name}_torso",
        [
            (waist_r * 0.92, HIP_Y + 0.12),
            (waist_r, HIP_Y + 0.22),
            (chest_r * 0.85, 1.15),
            (chest_r, 1.28),
            (chest_r * 1.05, SHOULDER_Y - 0.06),
            (shoulder * 0.55, SHOULDER_Y - 0.02),
            (0.06, SHOULDER_Y + 0.02),
            (0.048, NECK_Y - 0.02),
        ],
        segs=14, y_squash=0.78,
    )
    bevel(torso, 0.008, 2)
    paint_slots(torso, "coat_dark")
    parts.append(torso)

    # Neck cylinder overlapping chin
    neck = cyl(f"{name}_neck", 0.046, 0.052, (0, -0.01, SHOULDER_Y), (0, -0.025, NECK_Y + 0.10), 12)
    paint_slots(neck, "skin")
    parts.append(neck)

    # Arms — 3-segment taper + mitten hands
    for s, sxv in (("L", 1), ("R", -1)):
        u0 = (sxv * shoulder, 0.0, SHOULDER_Y - 0.03)
        u1 = (sxv * (shoulder + 0.055), 0.02, 1.14)
        f1 = (sxv * (shoulder + 0.095), 0.04, 0.90)
        # deltoid cap
        delt = sph(f"{name}_delt_{s}", 0.068 * sx, (sxv * shoulder, 0.0, SHOULDER_Y - 0.02),
                   (1.2, 1.0, 0.9), 10)
        paint_slots(delt, "skin"); parts.append(delt)
        ua = cyl(f"{name}_uarm_{s}", 0.062 * sx, 0.052 * sx, u0, u1, 10)
        paint_slots(ua, "skin"); parts.append(ua)
        # elbow knuckle
        el = sph(f"{name}_elb_{s}", 0.042 * sx, u1, (1.0, 1.0, 0.9), 8)
        paint_slots(el, "skin"); parts.append(el)
        fa = cyl(f"{name}_farm_{s}", 0.052 * sx, 0.042 * sx, u1, f1, 10)
        paint_slots(fa, "skin"); parts.append(fa)
        for hpart in build_hand(f"{name}_hand_{s}", sxv, sx, f1):
            paint_slots(hpart, "skin")
            parts.append(hpart)

    # Legs — thigh / knee / shin taper + boot
    for s, sxv in (("L", 1), ("R", -1)):
        hx = sxv * hip
        th0 = (hx, 0.0, HIP_Y - 0.04)
        th1 = (hx + sxv * 0.008, 0.015, 0.55)
        sh1 = (hx + sxv * 0.008, 0.035, 0.10)
        thigh = cyl(f"{name}_thigh_{s}", 0.105 * sx, 0.075 * sx, th0, th1, 12)
        paint_slots(thigh, "trousers"); parts.append(thigh)
        knee = sph(f"{name}_knee_{s}", 0.068 * sx, th1, (1.15, 1.05, 1.0), 10)
        paint_slots(knee, "trousers"); parts.append(knee)
        shin = cyl(f"{name}_shin_{s}", 0.070 * sx, 0.052 * sx, th1, sh1, 12)
        paint_slots(shin, "boots"); parts.append(shin)
        boot = taper_box(
            f"{name}_boot_{s}", 0.110 * sx, 0.24, 0.095 * sx, 0.17, 0.12, 0.0,
            x=hx + sxv * 0.008, y=-0.04, bevel_w=0.008, segs=2,
        )
        paint_slots(boot, "boots"); parts.append(boot)

    ob = join_objects(name, parts)
    if h_mul != 1.0:
        ob.scale = (1.0, 1.0, h_mul)
        bpy.ops.object.transform_apply(scale=True)
    register_part(ob, "body", [gender, "heavy" if heavy else "std"])
    return ob


# ---------------------------------------------------------------------------
# Heads — face plane OUTSIDE cranium so light can draw the form
# ---------------------------------------------------------------------------
def build_head(gender: str):
    """Hard-surface face planes — brow / nose / jaw / chin read under wrap light.

    Built as explicit blocks (not a deformed sphere) so board-cam (38°) still
    sees a chin silhouette and a nose ledge instead of a light-ball.
    """
    name = f"head_{gender}"
    sx = 0.95 if gender == "f" else 1.0
    chin_z = NECK_Y + 0.015
    parts = []

    # Cranium (back + top) — elongated, sits BEHIND the face plane
    skull = sph(
        f"{name}_skull", 0.125 * sx,
        (0.0, 0.04, chin_z + HEAD_H * 0.55),
        (0.95, 0.88, 1.05), 16,
    )
    paint_slots(skull, "skin"); parts.append(skull)

    # Face plate — large flat front so it is the thing the camera sees
    face = taper_box(
        f"{name}_face", 0.18 * sx, 0.070, 0.16 * sx, 0.055,
        HEAD_H * 0.62, chin_z + HEAD_H * 0.12,
        y=-0.08, bevel_w=0.014, segs=2,
    )
    paint_slots(face, "skin"); parts.append(face)

    # Forehead shelf above brow
    forehead = taper_box(
        f"{name}_fore", 0.16 * sx, 0.06, 0.15 * sx, 0.05,
        HEAD_H * 0.18, chin_z + HEAD_H * 0.62,
        y=-0.06, bevel_w=0.01, segs=1,
    )
    paint_slots(forehead, "skin"); parts.append(forehead)

    # Brow ridge — hard ledge casting shadow on eyes (oversized for 20px head)
    brow = taper_box(
        f"{name}_brow", 0.17 * sx, 0.06, 0.16 * sx, 0.05,
        0.045, chin_z + HEAD_H * 0.55,
        y=-0.12, bevel_w=0.004, segs=1,
    )
    paint_slots(brow, "skin"); parts.append(brow)

    # Nose — big pyramid (≥ 0.06m protrusion)
    nose = wedge(
        f"{name}_nose", 0.040 * sx, 0.075, 0.095,
        (0.0, -0.11, chin_z + HEAD_H * 0.40), tip_scale=0.3,
    )
    paint_slots(nose, "skin"); parts.append(nose)

    # Cheeks
    for s, sxv in (("L", 1), ("R", -1)):
        cheek = sph(
            f"{name}_cheek_{s}", 0.048 * sx,
            (sxv * 0.085 * sx, -0.09, chin_z + HEAD_H * 0.40),
            (1.15, 0.75, 1.0), 10,
        )
        paint_slots(cheek, "skin"); parts.append(cheek)

    # Jaw + chin (lower third silhouette)
    jaw = taper_box(
        f"{name}_jaw", 0.15 * sx, 0.09, 0.09 * sx, 0.06,
        HEAD_H * 0.26, chin_z - 0.01,
        y=-0.07, bevel_w=0.012, segs=2,
    )
    paint_slots(jaw, "skin"); parts.append(jaw)
    chin = taper_box(
        f"{name}_chin", 0.07 * sx, 0.055, 0.045 * sx, 0.035,
        0.048, chin_z - 0.02,
        y=-0.12, bevel_w=0.006, segs=1,
    )
    paint_slots(chin, "skin"); parts.append(chin)

    # Eyes — large dark blocks under brow
    for s, sxv in (("L", 1), ("R", -1)):
        eye = taper_box(
            f"{name}_eye_{s}", 0.042, 0.024, 0.040, 0.018,
            0.026, chin_z + HEAD_H * 0.48,
            x=sxv * 0.048 * sx, y=-0.145, bevel_w=0.0, segs=1,
        )
        paint_slots(eye, "eye"); parts.append(eye)

    mouth = taper_box(
        f"{name}_mouth", 0.055, 0.014, 0.048, 0.010,
        0.012, chin_z + HEAD_H * 0.20,
        y=-0.135, bevel_w=0.0, segs=1,
    )
    paint_slots(mouth, "eye"); parts.append(mouth)

    for s, sxv in (("L", 1), ("R", -1)):
        ear = taper_box(
            f"{name}_ear_{s}", 0.024, 0.016, 0.020, 0.012,
            0.055, chin_z + HEAD_H * 0.42,
            x=sxv * 0.125 * sx, y=0.02, bevel_w=0.004, segs=1,
        )
        paint_slots(ear, "skin"); parts.append(ear)

    out = join_objects(name, parts)
    register_part(out, "head", [gender, "planes"])
    return out


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


def _import_hair_lod(style: str):
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
    ob.data.materials.clear()
    co = [v.co for v in ob.data.vertices]
    if not co:
        return None
    zs = [v.z for v in co]
    zmin, zmax = min(zs), max(zs)
    span = max(0.05, zmax - zmin)
    scale = (HEAD_H * 0.95) / span
    ob.scale = (scale, scale, scale)
    bpy.ops.object.transform_apply(scale=True)
    zs = [v.co.z for v in ob.data.vertices]
    zmin = min(zs)
    # Sit on mid-skull / face plane so hair hugs scalp, not floating
    dz = (CHIN_Y + HEAD_H * 0.38) - zmin
    ob.location.z += dz
    bpy.ops.object.transform_apply(location=True)
    # Pull hair slightly toward −Y so fringe reads on face
    for v in ob.data.vertices:
        v.co.y -= 0.01
    ob.data.update()
    _decimate_to(ob, 1200)
    ob.name = f"hair_{style}"
    paint_slots(ob, "hair")
    return ob


def _proc_hair(style: str):
    name = f"hair_{style}"
    parts = []
    base_z = CHIN_Y + HEAD_H * 0.48
    # Scalp-hugging cap (slightly larger than skull, biased −Y for fringe)
    cap = sph(f"{name}_cap", 0.125, (0, 0.05, base_z + 0.10), (1.06, 0.92, 0.80), 14)
    paint_slots(cap, "hair"); parts.append(cap)
    # Sideburns / temple fill
    for s, sxv in (("L", 1), ("R", -1)):
        side = sph(f"{name}_side_{s}", 0.048, (sxv * 0.095, 0.02, base_z + 0.02),
                   (0.65, 0.85, 1.0), 8)
        paint_slots(side, "hair"); parts.append(side)

    if style in ("bob", "long", "messy"):
        h = 0.26 if style == "long" else (0.14 if style == "bob" else 0.18)
        vol = sph(f"{name}_vol", 0.12, (0, 0.02, base_z - 0.04), (1.2, 1.1, h / 0.12), 12)
        paint_slots(vol, "hair"); parts.append(vol)
        if style == "messy":
            for i, (ox, oy, oz) in enumerate(((-0.06, 0.04, 0.12), (0.05, 0.06, 0.14), (0.0, 0.10, 0.10))):
                spike = sph(f"{name}_spk{i}", 0.045, (ox, oy, base_z + oz), (1.2, 0.8, 1.4), 8)
                paint_slots(spike, "hair"); parts.append(spike)
    if style == "pony":
        parts.append(cyl(f"{name}_tail", 0.042, 0.022, (0, 0.10, base_z + 0.04),
                         (0, 0.26, base_z - 0.28), 10))
        paint_slots(parts[-1], "hair")
        parts.append(sph(f"{name}_tie", 0.035, (0, 0.10, base_z + 0.04), seg=8))
        paint_slots(parts[-1], "hair")
    if style == "tied":
        parts.append(sph(f"{name}_bun", 0.065, (0, 0.12, base_z + 0.10), (1.15, 1.0, 0.95), 10))
        paint_slots(parts[-1], "hair")
    if style == "crown":
        parts.append(taper_box(f"{name}_crest", 0.17, 0.07, 0.14, 0.05, 0.09,
                               base_z + 0.12, y=0.0, bevel_w=0.01))
        paint_slots(parts[-1], "hair")
    if style == "swept":
        parts.append(sph(f"{name}_sweep", 0.095, (0.05, -0.08, base_z + 0.10),
                         (1.4, 0.85, 0.75), 12))
        paint_slots(parts[-1], "hair")
        parts.append(sph(f"{name}_fringe", 0.05, (-0.02, -0.06, base_z + 0.06),
                         (1.2, 0.55, 0.6), 8))
        paint_slots(parts[-1], "hair")
    if style == "crop":
        parts.append(sph(f"{name}_crop", 0.09, (0, -0.04, base_z + 0.02),
                         (1.15, 1.0, 0.55), 12))
        paint_slots(parts[-1], "hair")

    ob = join_objects(name, parts)
    _decimate_to(ob, 1200)
    return ob


def _mesh_is_ok(ob) -> bool:
    me = ob.data
    if len(me.vertices) < 8 or len(me.polygons) < 4:
        return False
    # Reject non-finite coords
    for v in me.vertices:
        if not (abs(v.co.x) < 50 and abs(v.co.y) < 50 and abs(v.co.z) < 50):
            return False
    return True


def build_hair(style: str):
    # Board LOD: procedural sculptural caps. Farmed hair_* modules are performance /
    # stage assets — too dense and often non-manifold after decimate for this kit.
    ob = _proc_hair(style)
    ob.name = f"hair_{style}"
    if tris(ob) > 1200:
        _decimate_to(ob, 1200)
    if not _mesh_is_ok(ob):
        log("hair rebuild", style)
        bpy.data.objects.remove(ob, do_unlink=True)
        ob = _proc_hair(style)
        ob.name = f"hair_{style}"
    if ob.data:
        ob.data.name = ob.name
    register_part(ob, "hair", [style, "proc"])
    return ob


# ---------------------------------------------------------------------------
# Outfits — solidified shells, collar, lapels, hem, fold volumes
# ---------------------------------------------------------------------------
def _coat_shell(name, hem_z, shoulder_w, waist_w, chest_w, y_squash=0.82):
    """Lathed coat exterior from hem to collar base — single solid volume."""
    coat = lathe(
        name,
        [
            (waist_w * 1.05, hem_z),
            (waist_w * 1.15, hem_z + (SHOULDER_Y - hem_z) * 0.15),
            (waist_w, HIP_Y + 0.08),
            (waist_w * 0.95, 1.12),
            (chest_w, 1.28),
            (shoulder_w, SHOULDER_Y - 0.04),
            (shoulder_w * 0.55, SHOULDER_Y + 0.01),
            (0.08, SHOULDER_Y + 0.04),
        ],
        segs=16, y_squash=y_squash,
    )
    bevel(coat, 0.010, 2)
    return coat


def build_outfit_coat(name: str, hem: str = "mid", cape: bool = False,
                      apron: bool = False, scarf: bool = False):
    parts = []
    hem_z = {"short": 0.88, "mid": 0.62, "long": 0.40, "armor": 0.58}[hem]
    shoulder_w, waist_w, chest_w = 0.26, 0.19, 0.23

    coat = _coat_shell(f"{name}_coat", hem_z, shoulder_w, waist_w, chest_w)
    paint_slots(coat, "coat"); parts.append(coat)

    # Hem flare ring (reads as skirt / coat bottom thickness)
    flare = lathe(
        f"{name}_hem",
        [
            (waist_w * 1.05, hem_z - 0.01),
            (waist_w * 1.22, hem_z + 0.02),
            (waist_w * 1.18, hem_z + 0.08),
            (waist_w * 1.02, hem_z + 0.14),
        ],
        segs=14, y_squash=0.88,
    )
    paint_slots(flare, "coat"); parts.append(flare)

    # Inner lining / open chest (coat_dark) — front slab so body isn't a flat box
    lining = taper_box(
        f"{name}_lining", 0.14, 0.06, 0.12, 0.05,
        0.28, HIP_Y + 0.20, y=-0.12, bevel_w=0.008, segs=1,
    )
    paint_slots(lining, "coat_dark"); parts.append(lining)

    # Lapels — two angled plates meeting at chest
    for s, sxv in (("L", 1), ("R", -1)):
        lap = taper_box(
            f"{name}_lapel_{s}", 0.055, 0.035, 0.045, 0.028,
            0.22, HIP_Y + 0.28,
            x=sxv * 0.055, y=-0.15, bevel_w=0.005, segs=1,
        )
        paint_slots(lap, "coat"); parts.append(lap)

    # Standing collar
    collar = taper_box(
        f"{name}_collar", 0.18, 0.12, 0.16, 0.10,
        0.07, SHOULDER_Y - 0.02, y=-0.02, bevel_w=0.008, segs=2,
    )
    paint_slots(collar, "coat_dark"); parts.append(collar)

    # Shoulder caps + sleeves (thick, overlapping body arms)
    for s, sxv in (("L", 1), ("R", -1)):
        sh = sph(f"{name}_sh_{s}", 0.095, (sxv * 0.20, 0.0, SHOULDER_Y - 0.02),
                 (1.25, 1.05, 0.85), 12)
        paint_slots(sh, "coat"); parts.append(sh)
        sl = cyl(f"{name}_sl_{s}", 0.078, 0.058,
                 (sxv * 0.22, 0.0, SHOULDER_Y - 0.04),
                 (sxv * 0.32, 0.03, 0.98), 12)
        paint_slots(sl, "coat"); parts.append(sl)
        # cuff
        cu = cyl(f"{name}_cu_{s}", 0.055, 0.050,
                 (sxv * 0.31, 0.03, 1.02),
                 (sxv * 0.325, 0.035, 0.94), 10)
        paint_slots(cu, "coat_dark"); parts.append(cu)

    # Fold volumes on torso (cloth read without textures)
    for i, (ox, oz) in enumerate(((-0.06, 1.20), (0.07, 1.10), (-0.04, 1.00))):
        fold = wedge(f"{name}_fold{i}", 0.04, 0.028, 0.10, (ox, -0.16, oz))
        paint_slots(fold, "coat"); parts.append(fold)

    if apron:
        ap = taper_box(f"{name}_apron", 0.26, 0.04, 0.28, 0.04, 0.38, 0.70,
                       y=-0.14, bevel_w=0.008)
        paint_slots(ap, "apron"); parts.append(ap)

    if scarf:
        sc = taper_box(f"{name}_scarf", 0.18, 0.06, 0.08, 0.04, 0.24,
                       SHOULDER_Y - 0.14, y=-0.12, bevel_w=0.01)
        paint_slots(sc, "sash"); parts.append(sc)
        # scarf wrap around neck
        sw = cyl(f"{name}_scarf_w", 0.08, 0.075,
                 (0, -0.02, SHOULDER_Y - 0.02), (0, -0.04, SHOULDER_Y + 0.05), 12)
        paint_slots(sw, "sash"); parts.append(sw)

    if cape:
        bm = bmesh.new()
        rows, cols = 8, 7
        grid = []
        for i in range(rows + 1):
            tt = i / rows
            z = SHOULDER_Y - 0.02 - tt * 0.85
            w = 0.42 + 0.22 * tt
            yb = 0.10 + 0.16 * tt
            row = []
            for j in range(cols + 1):
                u = j / cols - 0.5
                # Wrap toward sides (±X) and keep behind (+Y)
                x = u * w
                y = yb + 0.08 * (u * 2) ** 2
                # Pull side edges slightly forward so cape reads as volume, not a billboard
                if abs(u) > 0.35:
                    y -= 0.06 * (abs(u) - 0.35) / 0.15
                row.append(bm.verts.new((x, y, z)))
            grid.append(row)
        for i in range(rows):
            for j in range(cols):
                bm.faces.new((grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        cp = _obj_from_bmesh(f"{name}_cape", bm)
        solidify(cp, 0.036)
        bevel(cp, 0.006, 1)
        paint_slots(cp, "cape"); parts.append(cp)

    # Belt / house tab (glow) — thin, on surface, not a giant transparent slab
    belt = taper_box(f"{name}_belt", 0.32, 0.08, 0.32, 0.08, 0.035,
                     HIP_Y + 0.04, y=-0.02, bevel_w=0.003, segs=1)
    paint_slots(belt, "house", glow=True); parts.append(belt)

    # Armor hem extras
    if hem == "armor":
        for s, sxv in (("L", 1), ("R", -1)):
            pl = sph(f"{name}_pl_{s}", 0.09, (sxv * 0.22, 0.0, SHOULDER_Y - 0.02),
                     (1.2, 1.0, 0.7), 10)
            paint_slots(pl, "metal", metal=True); parts.append(pl)

    ob = join_objects(name, parts)
    register_part(ob, "outfit", [hem])
    return ob


def build_bandit_outfit(tier: str):
    name = f"outfit_bandit_{tier}"
    parts = []
    hem_z = 0.88 if tier == "weak" else 0.80
    coat = _coat_shell(f"{name}_body", hem_z, 0.22, 0.16, 0.19, y_squash=0.80)
    paint_slots(coat, "coat"); parts.append(coat)

    lining = taper_box(f"{name}_lining", 0.12, 0.05, 0.10, 0.04, 0.22,
                       HIP_Y + 0.22, y=-0.12, bevel_w=0.006)
    paint_slots(lining, "coat_dark"); parts.append(lining)

    for s, sxv in (("L", 1), ("R", -1)):
        sh = sph(f"{name}_sh_{s}", 0.075, (sxv * 0.19, 0.0, SHOULDER_Y - 0.02),
                 (1.15, 0.95, 0.75), 10)
        paint_slots(sh, "coat"); parts.append(sh)
        sl = cyl(f"{name}_sl_{s}", 0.062, 0.048,
                 (sxv * 0.20, 0, SHOULDER_Y - 0.04), (sxv * 0.30, 0.03, 1.00), 10)
        paint_slots(sl, "coat"); parts.append(sl)

    if tier in ("bandit", "chief"):
        strap = taper_box(f"{name}_strap", 0.055, 0.035, 0.055, 0.035, 0.42,
                          0.95, x=0.10, y=-0.12, bevel_w=0.0)
        paint_slots(strap, "leather"); parts.append(strap)

    if tier == "archer":
        hood = taper_box(f"{name}_hood", 0.22, 0.20, 0.18, 0.16, 0.14,
                         SHOULDER_Y - 0.04, y=0.04, bevel_w=0.01)
        paint_slots(hood, "coat_dark"); parts.append(hood)

    if tier == "chief":
        bm = bmesh.new()
        rows, cols = 6, 5
        grid = []
        for i in range(rows + 1):
            t = i / rows
            z = SHOULDER_Y - t * 0.80
            w = 0.38 + 0.18 * t
            yb = 0.14 + 0.14 * t
            row = [bm.verts.new(((j / cols - 0.5) * w, yb, z)) for j in range(cols + 1)]
            grid.append(row)
        for i in range(rows):
            for j in range(cols):
                bm.faces.new((grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        cp = _obj_from_bmesh(f"{name}_cape", bm)
        solidify(cp, 0.032)
        paint_slots(cp, "cape"); parts.append(cp)

    crest = taper_box(f"{name}_crest", 0.07, 0.035, 0.07, 0.035, 0.09,
                      1.22, y=-0.14, bevel_w=0.0)
    paint_slots(crest, "crest", glow=True); parts.append(crest)

    belt = taper_box(f"{name}_belt", 0.30, 0.07, 0.30, 0.07, 0.03,
                     HIP_Y + 0.04, bevel_w=0.002, segs=1)
    paint_slots(belt, "leather"); parts.append(belt)

    ob = join_objects(name, parts)
    register_part(ob, "outfit", ["bandit", tier])
    return ob


def build_weapon(kind: str):
    name = f"weapon_{kind}"
    parts = []
    hx, hy, hz = -0.33, -0.05, 0.84
    if kind == "sword":
        parts.append(taper_box(f"{name}_grip", 0.028, 0.028, 0.028, 0.028, 0.14,
                               hz - 0.08, x=hx, y=hy, bevel_w=0.0))
        paint_slots(parts[-1], "leather")
        parts.append(taper_box(f"{name}_guard", 0.17, 0.038, 0.17, 0.038, 0.028,
                               hz + 0.06, x=hx, y=hy, bevel_w=0.004))
        paint_slots(parts[-1], "metal", metal=True)
        parts.append(taper_box(f"{name}_blade", 0.050, 0.014, 0.010, 0.004, 0.86,
                               hz + 0.09, x=hx, y=hy, bevel_w=0.002))
        paint_slots(parts[-1], "blade", metal=True)
        parts.append(sph(f"{name}_pommel", 0.028, (hx, hy, hz - 0.10), seg=8))
        paint_slots(parts[-1], "metal", metal=True)
    elif kind == "greatsword":
        parts.append(taper_box(f"{name}_grip", 0.034, 0.034, 0.034, 0.034, 0.24,
                               hz - 0.14, x=hx, y=hy, bevel_w=0.0))
        paint_slots(parts[-1], "leather")
        parts.append(taper_box(f"{name}_guard", 0.24, 0.045, 0.24, 0.045, 0.032,
                               hz + 0.10, x=hx, y=hy, bevel_w=0.004))
        paint_slots(parts[-1], "metal", metal=True)
        parts.append(taper_box(f"{name}_blade", 0.065, 0.016, 0.014, 0.004, 1.10,
                               hz + 0.13, x=hx, y=hy, bevel_w=0.002))
        paint_slots(parts[-1], "blade", metal=True)
    elif kind == "axe":
        parts.append(taper_box(f"{name}_haft", 0.032, 0.032, 0.028, 0.028, 0.72,
                               hz - 0.18, x=hx, y=hy, bevel_w=0.0))
        paint_slots(parts[-1], "wood")
        parts.append(taper_box(f"{name}_head", 0.045, 0.24, 0.014, 0.30, 0.20,
                               hz + 0.40, x=hx, y=hy - 0.08, bevel_w=0.005))
        paint_slots(parts[-1], "blade", metal=True)
    elif kind == "bow":
        # D-bow held at left side — arc in XZ, offset so it does not skewer the torso
        lx, ly = 0.38, -0.08
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.42, minor_radius=0.018, location=(lx, ly, 1.05),
            major_segments=28, minor_segments=8,
        )
        bw = bpy.context.active_object
        bw.name = f"{name}_bow"
        # Torus lies in XY by default; stand it in XZ (bow face toward camera/-Y)
        bw.rotation_euler = (R(90), 0, R(8))
        bw.scale = (0.55, 1.0, 1.15)  # flatten to a D-ish tall bow
        bpy.ops.object.transform_apply(rotation=True, scale=True)
        paint_slots(bw, "wood"); parts.append(bw)
        # string
        parts.append(cyl(f"{name}_string", 0.004, 0.004, (lx - 0.02, ly - 0.02, 0.62),
                         (lx - 0.02, ly - 0.02, 1.48), 6))
        paint_slots(parts[-1], "leather")
        parts.append(cyl(f"{name}_quiver", 0.048, 0.048, (0.12, 0.14, 1.00),
                         (0.16, 0.16, 1.40), 8))
        paint_slots(parts[-1], "leather")
    elif kind == "staff":
        parts.append(cyl(f"{name}_shaft", 0.018, 0.016, (hx, hy, 0.15), (hx, hy, 1.55), 8))
        paint_slots(parts[-1], "wood")
        parts.append(sph(f"{name}_orb", 0.055, (hx, hy, 1.58), seg=10))
        paint_slots(parts[-1], "accent", glow=True)
    elif kind == "spear":
        parts.append(cyl(f"{name}_shaft", 0.016, 0.014, (hx, hy, 0.10), (hx, hy, 1.70), 8))
        paint_slots(parts[-1], "wood")
        parts.append(taper_box(f"{name}_tip", 0.055, 0.014, 0.004, 0.004, 0.24,
                               1.70, x=hx, y=hy, bevel_w=0.002))
        paint_slots(parts[-1], "blade", metal=True)
    elif kind == "club":
        parts.append(cyl(f"{name}_club", 0.038, 0.060, (hx, hy, hz - 0.15),
                         (hx, hy, hz + 0.48), 10))
        paint_slots(parts[-1], "wood")
    elif kind == "banner":
        parts.append(cyl(f"{name}_pole", 0.016, 0.016, (hx, hy, 0.10), (hx, hy, 1.75), 8))
        paint_slots(parts[-1], "wood")
        parts.append(taper_box(f"{name}_flag", 0.02, 0.30, 0.02, 0.34, 0.38,
                               1.38, x=hx + 0.15, y=hy, bevel_w=0.0))
        paint_slots(parts[-1], "house", glow=True)
    else:
        parts.append(taper_box(f"{name}_blade", 0.032, 0.012, 0.008, 0.004, 0.34,
                               hz, x=hx, y=hy, bevel_w=0.002))
        paint_slots(parts[-1], "blade", metal=True)
        parts.append(taper_box(f"{name}_grip", 0.024, 0.024, 0.024, 0.024, 0.10,
                               hz - 0.10, x=hx, y=hy, bevel_w=0.0))
        paint_slots(parts[-1], "leather")
    ob = join_objects(name, parts)
    register_part(ob, "weapon", [kind])
    return ob


def build_pauldron(side: str = "both"):
    name = f"sign_pauldron_{side}"
    parts = []
    sides = [("L", 1), ("R", -1)] if side == "both" else ([("L", 1)] if side == "L" else [("R", -1)])
    for s, sx in sides:
        parts.append(sph(f"{name}_{s}", 0.095, (sx * 0.23, 0.0, SHOULDER_Y - 0.02),
                         (1.2, 1.05, 0.72), 12))
        paint_slots(parts[-1], "metal", metal=True)
    ob = join_objects(name, parts)
    register_part(ob, "sign", ["pauldron", side])
    return ob


# ---------------------------------------------------------------------------
# Overrides / export / main
# ---------------------------------------------------------------------------
def apply_overrides():
    if not PARTS_DIR.is_dir():
        return
    for path in sorted(PARTS_DIR.iterdir()):
        if path.name.startswith(".") or path.name in ("farm_inbox", "README.md"):
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
        # Only replace a *pre-existing* scripted part; never delete the just-imported mesh
        # (compose_*.glb stems match the object name on import).
        preexisting = bpy.data.objects.get(stem) if stem in before else None
        if preexisting is not None and preexisting not in new:
            bpy.data.objects.remove(preexisting, do_unlink=True)
        bpy.ops.object.select_all(action="DESELECT")
        alive = [o for o in new if o.name in bpy.data.objects]
        for o in alive:
            o.select_set(True)
        bpy.context.view_layer.objects.active = alive[0]
        if len(alive) > 1:
            bpy.ops.object.join()
        ob = bpy.context.active_object
        ob.name = stem
        if ob.data:
            ob.data.name = stem
        if not ob.data.color_attributes:
            paint_slots(ob, "coat")
        # Re-weld after glTF (corner colours / exporters can explode shared verts).
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.remove_doubles(threshold=0.0012)
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.object.mode_set(mode="OBJECT")
        bpy.ops.object.shade_smooth()
        if stem.startswith("compose_"):
            cat = "compose"
        else:
            cat = MANIFEST["parts"].get(stem, {}).get("category", "override")
        register_part(ob, cat, ["override", "organic"])
        arm_ob = bpy.data.objects.get("BoardRig")
        if arm_ob and cat in ("compose", "body", "outfit"):
            skin_rigid(ob, "hips", arm_ob)
        elif arm_ob and cat in ("head", "hair"):
            skin_rigid(ob, "head", arm_ob)


def export_glb(out_dir: Path, arm_ob):
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
    log("building sculptural formal kit →", out_dir)
    arm = build_armature()

    bodies = [build_body("m"), build_body("f"), build_body("m", heavy=True)]
    heads = [build_head("m"), build_head("f")]
    hairs = [build_hair(s) for s in ("bob", "crop", "crown", "long", "messy", "pony", "swept", "tied")]

    outfits = [
        build_outfit_coat("outfit_captain", hem="mid", cape=True, scarf=True),
        build_outfit_coat("outfit_squire", hem="short", cape=True),
        build_outfit_coat("outfit_hunter", hem="short"),
        build_outfit_coat("outfit_light_inf", hem="mid"),
        build_outfit_coat("outfit_heavy_inf", hem="armor"),
        build_outfit_coat("outfit_apprentice", hem="long"),
        build_outfit_coat("outfit_militia", hem="short"),
        build_outfit_coat("outfit_banner", hem="mid"),
        build_bandit_outfit("weak"),
        build_bandit_outfit("bandit"),
        build_bandit_outfit("archer"),
        build_bandit_outfit("chief"),
    ]
    weapons = [build_weapon(k) for k in
               ("sword", "greatsword", "axe", "bow", "staff", "spear", "club", "banner", "dagger")]
    signs = [build_pauldron("both"), build_pauldron("L"), build_pauldron("R")]

    for ob in bodies + outfits:
        skin_rigid(ob, "hips", arm)
    for ob in heads + hairs:
        skin_rigid(ob, "head", arm)
    for ob in weapons:
        skin_rigid(ob, "hand.R", arm)
    for ob in signs:
        skin_rigid(ob, "chest", arm)

    apply_overrides()

    # Ensure every mesh datablock shares its object name (avoids Mesh_0 export warnings).
    for o in list(bpy.data.objects):
        if o.type == "MESH" and o.data and o.data.name != o.name:
            o.data.name = o.name

    for o in list(bpy.data.objects):
        if o.type == "MESH" and o.name not in MANIFEST["parts"] and not o.name.startswith("Board"):
            log("remove orphan", o.name)
            bpy.data.objects.remove(o, do_unlink=True)
    # Drop leftover primitive datablocks that glTF would still emit as empty nodes
    for o in list(bpy.data.objects):
        if o.type == "MESH" and (
            o.name.startswith("Icosphere") or o.name.startswith("Sphere")
            or o.name.startswith("Cube") or o.name.startswith("Cone")
            or o.name.startswith("Torus") or o.name.startswith("Cylinder")
            or o.name.startswith("Mesh")
        ) and o.name not in MANIFEST["parts"]:
            log("remove prim leftover", o.name)
            bpy.data.objects.remove(o, do_unlink=True)

    for o in list(bpy.data.objects):
        if o.type != "MESH":
            continue
        if o.name.startswith("hair_") and tris(o) > 1200:
            _decimate_to(o, 1200)
            if tris(o) > 1200:
                bpy.ops.object.select_all(action="DESELECT")
                o.select_set(True)
                bpy.context.view_layer.objects.active = o
                md = o.modifiers.new("vox", "REMESH")
                md.mode = "VOXEL"
                md.voxel_size = 0.018
                bpy.ops.object.modifier_apply(modifier=md.name)
                _decimate_to(o, 1200)
                paint_slots(o, "hair")
                arm_ob = bpy.data.objects.get("BoardRig")
                if arm_ob:
                    skin_rigid(o, "head", arm_ob)
            log("hair lod", o.name, tris(o))
        if o.name in MANIFEST["parts"]:
            MANIFEST["parts"][o.name]["tris"] = tris(o)

    glb = export_glb(out_dir, arm)
    alive = {o.name for o in bpy.data.objects if o.type == "MESH"}
    MANIFEST["parts"] = {k: v for k, v in MANIFEST["parts"].items() if k in alive}
    MANIFEST["glb"] = "board_figures_v1.glb"
    MANIFEST["total_tris"] = sum(int(v["tris"]) for v in MANIFEST["parts"].values())
    MANIFEST["part_count"] = len(MANIFEST["parts"])
    man_path = out_dir / "board_figures_v1.json"
    man_path.write_text(json.dumps(MANIFEST, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    log("manifest", man_path, "parts", MANIFEST["part_count"], "total_tris", MANIFEST["total_tris"])
    if MANIFEST["total_tris"] > 100000:
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
