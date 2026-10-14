#!/usr/bin/env python3
"""Board figures v1 — formal Blender modular parts (docs/design/pawn-redesign-opus.md §3.7 / §5).

Run:
  blender -b -P tools/models/board_figures_v1.py -- <out_dir>

Writes:
  board_figures_v1.glb          — all modular meshes under one scene (named parts)
  board_figures_v1.json         — part list, bone schema, tris, slot map
  board_figures_assembled.json  — optional per-archetype tris estimates

Proportions: ~5.45 heads, MODEL_H=1.85m, head ~1.35× life, sword ~1.15×.
Vertex colour: R = palette slot id / 20, G = baked AO, B = metal/glow flags.
0 textures. Target 4–6k tris per assembled unit (hard max 7k).

Farm path (Qwen concept → Hunyuan3D → this retopo/bake): when m173 is online,
drop concept refs under tools/models/board_parts/farm_inbox/ and polished
.blend overrides under tools/models/board_parts/; same names replace script meshes.
"""
from __future__ import annotations

import bpy
import bmesh
import json
import math
import os
import sys
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
OUT = argv[0] if argv else "/tmp/board_figures_build"
os.makedirs(OUT, exist_ok=True)

R = math.radians
MODEL_H = 1.85
HEADS = 5.45
HEAD_H = MODEL_H / HEADS  # ~0.339

# Palette slot ids (must match board_figure.gdshader / CKBoardFigure)
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

# 18-bone schema (shared with build_standins_v86 / anim libraries)
BONES = [
    ("root", (0, 0, 0), (0, 0, 0.25), None),
    ("hips", (0, 0, 0.95), (0, 0, 1.08), "root"),
    ("spine", (0, 0, 1.08), (0, 0, 1.24), "hips"),
    ("chest", (0, 0, 1.24), (0, 0, 1.42), "spine"),
    ("neck", (0, 0, 1.42), (0, 0, 1.50), "chest"),
    ("head", (0, 0, 1.50), (0, 0, 1.50 + HEAD_H * 0.85), "neck"),
]
for s, sx in (("L", 1), ("R", -1)):
    BONES += [
        (f"upper_arm.{s}", (sx * 0.205, 0, 1.38), (sx * 0.26, 0.02, 1.10), "chest"),
        (f"forearm.{s}", (sx * 0.26, 0.02, 1.10), (sx * 0.30, 0.04, 0.86), f"upper_arm.{s}"),
        (f"hand.{s}", (sx * 0.30, 0.04, 0.86), (sx * 0.31, 0.05, 0.78), f"forearm.{s}"),
        (f"thigh.{s}", (sx * 0.098, 0, 0.94), (sx * 0.105, 0.01, 0.52), "hips"),
        (f"shin.{s}", (sx * 0.105, 0.01, 0.52), (sx * 0.105, 0.03, 0.09), f"thigh.{s}"),
        (f"foot.{s}", (sx * 0.105, 0.03, 0.09), (sx * 0.105, -0.12, 0.03), f"shin.{s}"),
    ]

PART_META = []  # dicts written to manifest


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _apply_mods(ob):
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    for m in list(ob.modifiers):
        try:
            bpy.ops.object.modifier_apply(modifier=m.name)
        except Exception:
            pass
    ob.select_set(False)


def paint_vcol(ob, slot_name: str, ao_base: float = 1.0, metal: float = 0.0, glow: float = 0.0):
    """R=slot/20, G=AO (height-based * ao_base), B=0.5*metal + 0.5*glow."""
    me = ob.data
    if not me.vertex_colors:
        me.vertex_colors.new(name="Col")
    col = me.vertex_colors.active
    sid = SLOT.get(slot_name, 3) / 20.0
    flag = 0.5 * metal + 0.5 * glow
    # per-loop AO from world Z
    for poly in me.polygons:
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            z = me.vertices[vi].co.z
            ao = ao_base * (0.80 + 0.20 * min(1.0, max(0.0, z / 1.25)))
            col.data[li].color = (sid, ao, flag, 1.0)


def taper_box(name, w0, d0, w1, d1, h, z0, x=0.0, y=0.0, bevel=0.008, segs=2):
    bm = bmesh.new()
    vs = []
    for (w, d, z) in ((w0, d0, z0), (w1, d1, z0 + h)):
        for (sx, sy) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            vs.append(bm.verts.new((x + sx * w / 2, y + sy * d / 2, z)))
    for t in [
        (0, 1, 2, 3),
        (7, 6, 5, 4),
        (0, 4, 5, 1),
        (1, 5, 6, 2),
        (2, 6, 7, 3),
        (3, 7, 4, 0),
    ]:
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
        _apply_mods(ob)
    return ob


def cyl(name, r0, r1, p0, p1, verts=10):
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    bpy.ops.mesh.primitive_cone_add(
        vertices=verts, radius1=r0, radius2=r1, depth=max(d.length, 0.001), location=(p0 + p1) / 2
    )
    ob = bpy.context.active_object
    ob.name = name
    ob.rotation_mode = "QUATERNION"
    if d.length > 1e-6:
        ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return ob


def sph(name, r, loc, scale=(1, 1, 1), seg=12):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=seg, ring_count=max(6, seg // 2), radius=r, location=loc
    )
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return ob


def tris(ob) -> int:
    me = ob.data
    return sum(len(p.vertices) - 2 for p in me.polygons)


def register(ob, part_id: str, slot: str, bone: str, kind: str):
    paint_vcol(ob, slot, metal=1.0 if slot in ("metal", "blade") else 0.0)
    n = tris(ob)
    PART_META.append(
        {
            "id": part_id,
            "object": ob.name,
            "slot": slot,
            "bone": bone,
            "kind": kind,
            "tris": n,
        }
    )
    ob["ck_part"] = part_id
    ob["ck_slot"] = slot
    ob["ck_bone"] = bone
    return ob


def build_armature():
    arm = bpy.data.armatures.new("BoardRig")
    ob = bpy.data.objects.new("BoardRig", arm)
    bpy.context.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    for (n, h, t, p) in BONES:
        b = arm.edit_bones.new(n)
        b.head = h
        b.tail = t
        b.roll = 0
        if p:
            b.parent = arm.edit_bones[p]
            b.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


def body_parts(sex: str = "m", heavy: bool = False):
    """Body kit: pelvis, torso, legs, arms, hands — skinned conceptually to bones."""
    sx = 1.06 if heavy else (0.965 if sex == "f" else 1.0)
    sh = 0.185 if sex == "f" else 0.205
    hx = 0.105 if sex == "f" else 0.098
    tag = f"body_{'heavy' if heavy else sex}"

    # Pelvis / hips
    register(
        taper_box(f"{tag}_pelvis", 0.28 * sx, 0.18, 0.32 * sx, 0.20, 0.14, 0.90, bevel=0.01),
        f"{tag}_pelvis",
        "trousers",
        "hips",
        "body",
    )
    # Torso coat shell
    register(
        taper_box(
            f"{tag}_torso",
            0.34 * sx,
            0.20,
            0.38 * sx,
            0.22,
            0.36,
            1.04,
            bevel=0.012,
            segs=2,
        ),
        f"{tag}_torso",
        "coat",
        "chest",
        "body",
    )
    # Waist lining peek
    register(
        taper_box(f"{tag}_waist", 0.26 * sx, 0.16, 0.30 * sx, 0.18, 0.10, 0.98, bevel=0.006),
        f"{tag}_waist",
        "coat_dark",
        "spine",
        "body",
    )
    for side, sname in ((-1, "R"), (1, "L")):
        # Thigh
        register(
            cyl(
                f"{tag}_thigh_{sname}",
                0.076 * sx,
                0.068 * sx,
                (side * hx, 0.01, 0.92),
                (side * (hx + 0.01), 0.02, 0.52),
                8,
            ),
            f"{tag}_thigh_{sname}",
            "trousers",
            f"thigh.{sname}",
            "body",
        )
        # Shin / boot
        register(
            cyl(
                f"{tag}_shin_{sname}",
                0.052 * sx,
                0.040 * sx,
                (side * (hx + 0.01), 0.02, 0.52),
                (side * (hx + 0.01), 0.04, 0.10),
                8,
            ),
            f"{tag}_shin_{sname}",
            "boots",
            f"shin.{sname}",
            "body",
        )
        register(
            taper_box(
                f"{tag}_foot_{sname}",
                0.08,
                0.16,
                0.07,
                0.12,
                0.05,
                0.02,
                x=side * (hx + 0.01),
                y=-0.04,
                bevel=0.004,
            ),
            f"{tag}_foot_{sname}",
            "boots",
            f"foot.{sname}",
            "body",
        )
        # Upper arm
        register(
            cyl(
                f"{tag}_uarm_{sname}",
                0.052 * sx,
                0.048 * sx,
                (side * sh, 0.0, 1.38),
                (side * (sh + 0.05), 0.02, 1.10),
                8,
            ),
            f"{tag}_uarm_{sname}",
            "coat",
            f"upper_arm.{sname}",
            "body",
        )
        register(
            cyl(
                f"{tag}_farm_{sname}",
                0.044 * sx,
                0.037 * sx,
                (side * (sh + 0.05), 0.02, 1.10),
                (side * (sh + 0.09), 0.04, 0.86),
                8,
            ),
            f"{tag}_farm_{sname}",
            "coat",
            f"forearm.{sname}",
            "body",
        )
        register(
            sph(f"{tag}_hand_{sname}", 0.042 * sx, (side * (sh + 0.10), 0.05, 0.80), seg=10),
            f"{tag}_hand_{sname}",
            "skin",
            f"hand.{sname}",
            "body",
        )


def head_parts(sex: str = "m"):
    tag = f"head_{sex}"
    # Cranial mass — enlarged board head
    r = HEAD_H * 0.42
    skull = sph(f"{tag}_skull", r, (0, 0.02, 1.50 + HEAD_H * 0.40), scale=(1.0, 0.95, 1.05), seg=14)
    register(skull, f"{tag}_skull", "skin", "head", "head")
    jaw = sph(
        f"{tag}_jaw",
        r * 0.62,
        (0, 0.05, 1.50 + HEAD_H * 0.12),
        scale=(0.95, 0.75, 0.70),
        seg=10,
    )
    register(jaw, f"{tag}_jaw", "skin", "head", "head")
    nose = sph(f"{tag}_nose", r * 0.14, (0, 0.12, 1.50 + HEAD_H * 0.38), scale=(0.7, 1.2, 0.9), seg=8)
    register(nose, f"{tag}_nose", "skin", "head", "head")
    for side, sn in ((-1, "R"), (1, "L")):
        eye = sph(
            f"{tag}_eye_{sn}",
            r * 0.08,
            (side * r * 0.28, 0.11, 1.50 + HEAD_H * 0.42),
            seg=6,
        )
        register(eye, f"{tag}_eye_{sn}", "eye", "head", "head")


def hair_lod(style: str):
    """Board LOD hair silhouettes (replaces 10k+ shared modules at board scale)."""
    tag = f"hair_{style}"
    z0 = 1.50 + HEAD_H * 0.35
    r = HEAD_H * 0.48
    if style == "crop":
        ob = sph(tag, r * 0.95, (0, 0.0, z0 + 0.02), scale=(1.05, 1.0, 0.75), seg=12)
    elif style == "bob":
        ob = sph(tag, r, (0, 0.02, z0), scale=(1.15, 1.1, 0.95), seg=12)
        bun = taper_box(f"{tag}_ends", 0.22, 0.14, 0.20, 0.12, 0.10, z0 - 0.12, y=0.02, bevel=0.01)
        register(bun, f"{tag}_ends", "hair", "head", "hair")
    elif style == "long":
        ob = sph(tag, r, (0, 0.0, z0), scale=(1.1, 1.05, 0.9), seg=12)
        cascade = taper_box(
            f"{tag}_fall", 0.18, 0.10, 0.14, 0.08, 0.28, z0 - 0.22, y=-0.06, bevel=0.012
        )
        register(cascade, f"{tag}_fall", "hair", "head", "hair")
    elif style == "pony":
        ob = sph(tag, r * 0.9, (0, 0.0, z0), scale=(1.0, 0.95, 0.85), seg=10)
        tail = cyl(f"{tag}_tail", 0.04, 0.03, (0, -0.08, z0), (0, -0.22, z0 - 0.25), 8)
        register(tail, f"{tag}_tail", "hair", "head", "hair")
    elif style == "tied":
        ob = sph(tag, r * 0.9, (0, 0.0, z0), scale=(1.0, 0.95, 0.8), seg=10)
        bun = sph(f"{tag}_bun", 0.06, (0, -0.10, z0 + 0.02), seg=8)
        register(bun, f"{tag}_bun", "hair", "head", "hair")
    elif style == "crown":
        ob = sph(tag, r * 0.92, (0, 0.0, z0), scale=(1.05, 1.0, 0.85), seg=12)
        ring = taper_box(f"{tag}_braid", 0.26, 0.08, 0.24, 0.07, 0.06, z0 + 0.06, bevel=0.008)
        register(ring, f"{tag}_braid", "hair", "head", "hair")
    elif style == "swept":
        ob = sph(tag, r, (0.02, 0.02, z0), scale=(1.15, 1.05, 0.85), seg=12)
    else:  # messy
        ob = sph(tag, r * 1.05, (0, 0.0, z0), scale=(1.2, 1.15, 0.95), seg=12)
        tuft = sph(f"{tag}_tuft", 0.05, (0.06, -0.04, z0 + 0.08), seg=6)
        register(tuft, f"{tag}_tuft", "hair", "head", "hair")
    register(ob, tag, "hair", "head", "hair")


def gear_parts():
    # Short / mid / long hems
    register(
        taper_box("hem_short", 0.36, 0.24, 0.30, 0.18, 0.18, 0.78, bevel=0.01),
        "hem_short",
        "coat",
        "hips",
        "gear",
    )
    register(
        taper_box("hem_mid", 0.38, 0.26, 0.32, 0.20, 0.28, 0.68, bevel=0.012),
        "hem_mid",
        "coat",
        "hips",
        "gear",
    )
    register(
        taper_box("hem_long", 0.40, 0.28, 0.34, 0.22, 0.48, 0.48, bevel=0.014),
        "hem_long",
        "coat",
        "hips",
        "gear",
    )
    register(
        taper_box("apron", 0.22, 0.06, 0.20, 0.05, 0.32, 0.85, y=0.12, bevel=0.006),
        "apron",
        "apron",
        "spine",
        "gear",
    )
    register(
        taper_box("cape_short", 0.30, 0.05, 0.34, 0.04, 0.36, 1.05, y=-0.12, bevel=0.01),
        "cape_short",
        "cape",
        "chest",
        "gear",
    )
    register(
        taper_box("cape_long", 0.32, 0.05, 0.38, 0.04, 0.55, 0.90, y=-0.14, bevel=0.012),
        "cape_long",
        "cape",
        "chest",
        "gear",
    )
    register(
        taper_box("house_tab", 0.10, 0.03, 0.09, 0.03, 0.14, 0.88, y=0.14, bevel=0.004),
        "house_tab",
        "house",
        "hips",
        "gear",
    )
    register(
        taper_box("pauldron_L", 0.12, 0.10, 0.10, 0.08, 0.08, 1.34, x=0.22, bevel=0.01),
        "pauldron_L",
        "metal",
        "chest",
        "gear",
    )
    register(
        taper_box("pauldron_R", 0.12, 0.10, 0.10, 0.08, 0.08, 1.34, x=-0.22, bevel=0.01),
        "pauldron_R",
        "metal",
        "chest",
        "gear",
    )
    register(
        taper_box("scarf", 0.18, 0.06, 0.14, 0.04, 0.20, 1.20, y=0.10, bevel=0.008),
        "scarf",
        "sash",
        "neck",
        "gear",
    )
    # Bandit vest
    register(
        taper_box("bandit_vest", 0.34, 0.18, 0.36, 0.20, 0.28, 1.08, bevel=0.01),
        "bandit_vest",
        "coat",
        "chest",
        "gear",
    )


def weapon_parts():
    # Sword ~1.15 life (blade 0.86m)
    hx, hy, hz = -0.315, -0.025, 0.85
    register(
        taper_box("wpn_sword_blade", 0.055, 0.012, 0.014, 0.005, 0.86, hz + 0.10, x=hx, y=hy, bevel=0.002),
        "wpn_sword_blade",
        "blade",
        "hand.R",
        "weapon",
    )
    register(
        taper_box("wpn_sword_guard", 0.18, 0.035, 0.18, 0.035, 0.03, hz + 0.07, x=hx, y=hy, bevel=0.004),
        "wpn_sword_guard",
        "metal",
        "hand.R",
        "weapon",
    )
    register(
        taper_box("wpn_sword_grip", 0.028, 0.028, 0.028, 0.028, 0.14, hz - 0.06, x=hx, y=hy, bevel=0.0),
        "wpn_sword_grip",
        "leather",
        "hand.R",
        "weapon",
    )
    # Greatsword
    register(
        taper_box("wpn_greatsword_blade", 0.07, 0.014, 0.018, 0.006, 1.10, hz + 0.05, x=hx, y=hy, bevel=0.002),
        "wpn_greatsword_blade",
        "blade",
        "hand.R",
        "weapon",
    )
    # Axe
    register(
        taper_box("wpn_axe_haft", 0.032, 0.032, 0.028, 0.028, 0.70, hz - 0.18, x=hx, y=hy, bevel=0.0),
        "wpn_axe_haft",
        "wood",
        "hand.R",
        "weapon",
    )
    register(
        taper_box("wpn_axe_head", 0.04, 0.22, 0.014, 0.28, 0.18, hz + 0.38, x=hx, y=hy - 0.08, bevel=0.004),
        "wpn_axe_head",
        "blade",
        "hand.R",
        "weapon",
    )
    # Spear / lance
    register(
        cyl("wpn_spear_shaft", 0.016, 0.014, (hx, hy, hz - 0.55), (hx, hy, hz + 1.05), 8),
        "wpn_spear_shaft",
        "wood",
        "hand.R",
        "weapon",
    )
    register(
        taper_box("wpn_spear_tip", 0.05, 0.012, 0.004, 0.004, 0.22, hz + 1.05, x=hx, y=hy, bevel=0.002),
        "wpn_spear_tip",
        "blade",
        "hand.R",
        "weapon",
    )
    # Bow
    lx, ly, lz = 0.315, -0.025, 0.85
    register(
        cyl("wpn_bow_limb", 0.012, 0.010, (lx + 0.05, ly, lz - 0.55), (lx + 0.05, ly, lz + 0.55), 8),
        "wpn_bow_limb",
        "wood",
        "hand.L",
        "weapon",
    )
    register(
        cyl("wpn_quiver", 0.045, 0.045, (0.10, 0.14, 1.05), (0.16, 0.16, 1.42), 8),
        "wpn_quiver",
        "leather",
        "chest",
        "weapon",
    )
    # Staff
    register(
        cyl("wpn_staff", 0.018, 0.016, (hx, hy, hz - 0.40), (hx, hy, hz + 0.95), 8),
        "wpn_staff",
        "wood",
        "hand.R",
        "weapon",
    )
    register(
        sph("wpn_staff_orb", 0.05, (hx, hy, hz + 1.0), seg=8),
        "wpn_staff_orb",
        "accent",
        "hand.R",
        "weapon",
    )
    # Shield
    register(
        taper_box("wpn_shield", 0.34, 0.05, 0.28, 0.045, 0.46, lz - 0.05, x=lx + 0.04, y=ly - 0.03, bevel=0.02),
        "wpn_shield",
        "metal",
        "forearm.L",
        "weapon",
    )
    # Club / bandit stick
    register(
        cyl("wpn_club", 0.028, 0.022, (hx, hy, hz - 0.15), (hx, hy, hz + 0.45), 8),
        "wpn_club",
        "wood",
        "hand.R",
        "weapon",
    )


def skin_to_bones(arm_ob):
    """Parent all mesh parts to armature with empty vertex groups (rigid bind at export)."""
    for ob in list(bpy.data.objects):
        if ob.type != "MESH":
            continue
        bone = ob.get("ck_bone", "hips")
        if bone not in arm_ob.data.bones:
            bone = "hips"
        # Vertex group + armature modifier
        if bone not in ob.vertex_groups:
            ob.vertex_groups.new(name=bone)
        vg = ob.vertex_groups[bone]
        vg.add([v.index for v in ob.data.vertices], 1.0, "REPLACE")
        md = ob.modifiers.new("arm", "ARMATURE")
        md.object = arm_ob
        ob.parent = arm_ob


def export_glb(path: str):
    # Select armature + meshes
    bpy.ops.object.select_all(action="DESELECT")
    for ob in bpy.data.objects:
        if ob.type in ("MESH", "ARMATURE"):
            ob.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_texcoords=False,
        export_normals=True,
        export_materials="NONE",
        export_vertex_color="MATERIAL",
        export_all_vertex_colors=True,
        export_active_vertex_color_when_no_material=True,
        export_animations=False,
        export_skins=True,
        export_yup=True,
    )


def main():
    reset()
    arm = build_armature()
    body_parts("m")
    body_parts("f")
    body_parts("m", heavy=True)
    head_parts("m")
    head_parts("f")
    for st in ("bob", "crop", "crown", "long", "messy", "pony", "swept", "tied"):
        hair_lod(st)
    gear_parts()
    weapon_parts()
    skin_to_bones(arm)

    glb = os.path.join(OUT, "board_figures_v1.glb")
    export_glb(glb)

    total = sum(p["tris"] for p in PART_META)
    # Estimate assembled ally swordsman: body_m + head_m + hair_crop + hem_mid + cape + house_tab
    def est(ids):
        return sum(p["tris"] for p in PART_META if p["id"] in ids)

    estimates = {
        "ally_sword": est(
            [
                "body_m_pelvis",
                "body_m_torso",
                "body_m_waist",
                "body_m_thigh_L",
                "body_m_thigh_R",
                "body_m_shin_L",
                "body_m_shin_R",
                "body_m_foot_L",
                "body_m_foot_R",
                "body_m_uarm_L",
                "body_m_uarm_R",
                "body_m_farm_L",
                "body_m_farm_R",
                "body_m_hand_L",
                "body_m_hand_R",
                "head_m_skull",
                "head_m_jaw",
                "head_m_nose",
                "head_m_eye_L",
                "head_m_eye_R",
                "hair_crop",
                "hem_mid",
                "cape_short",
                "house_tab",
                "wpn_sword_blade",
                "wpn_sword_guard",
                "wpn_sword_grip",
            ]
        ),
        "ally_bow": est(
            [
                "body_f_pelvis",
                "body_f_torso",
                "body_f_waist",
                "body_f_thigh_L",
                "body_f_thigh_R",
                "body_f_shin_L",
                "body_f_shin_R",
                "body_f_foot_L",
                "body_f_foot_R",
                "body_f_uarm_L",
                "body_f_uarm_R",
                "body_f_farm_L",
                "body_f_farm_R",
                "body_f_hand_L",
                "body_f_hand_R",
                "head_f_skull",
                "head_f_jaw",
                "head_f_nose",
                "head_f_eye_L",
                "head_f_eye_R",
                "hair_bob",
                "hair_bob_ends",
                "hem_short",
                "wpn_bow_limb",
                "wpn_quiver",
            ]
        ),
        "enemy_bandit": est(
            [
                "body_m_pelvis",
                "body_m_torso",
                "body_m_waist",
                "body_m_thigh_L",
                "body_m_thigh_R",
                "body_m_shin_L",
                "body_m_shin_R",
                "body_m_foot_L",
                "body_m_foot_R",
                "body_m_uarm_L",
                "body_m_uarm_R",
                "body_m_farm_L",
                "body_m_farm_R",
                "body_m_hand_L",
                "body_m_hand_R",
                "head_m_skull",
                "head_m_jaw",
                "head_m_nose",
                "head_m_eye_L",
                "head_m_eye_R",
                "hair_messy",
                "hair_messy_tuft",
                "bandit_vest",
                "hem_short",
                "wpn_axe_haft",
                "wpn_axe_head",
            ]
        ),
    }

    manifest = {
        "version": 1,
        "schema": "board_figures_v1",
        "model_h": MODEL_H,
        "heads": HEADS,
        "slots": SLOT,
        "bones": [b[0] for b in BONES],
        "parts": PART_META,
        "part_count": len(PART_META),
        "total_part_tris": total,
        "assembled_estimates": estimates,
        "glb": "board_figures_v1.glb",
        "notes": (
            "Blender-authored modular kit on box. Hunyuan farm polish pending "
            "(m173 offline at authoring). Drop .blend overrides in tools/models/board_parts/."
        ),
        "budget": {"per_unit_tris_target": [4000, 6000], "per_unit_tris_max": 7000},
    }
    with open(os.path.join(OUT, "board_figures_v1.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)
    print(
        f"BOARD FIGURES V1 OK parts={len(PART_META)} total_tris={total} "
        f"est_sword={estimates['ally_sword']} est_bow={estimates['ally_bow']} "
        f"est_bandit={estimates['enemy_bandit']} -> {glb}"
    )
    for name, n in estimates.items():
        if n > 7000:
            print(f"WARN {name} tris {n} > 7000")


if __name__ == "__main__":
    main()
