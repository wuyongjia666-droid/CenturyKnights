#!/usr/bin/env python3
"""Build organic formal board-figure overrides (face-safe + clean slot borders).

Fixes vs rejected round:
  - Face default = skin (never whole-face hair/eye black mask)
  - Eyes = tiny dark patches only
  - Nose / brow / cheek / jaw via vertex displace (no boolean melt)
  - Head density protected during decimate
  - Face-label paint → majority smooth → split edges at borders → POINT colours

  blender -b -P tools/models/build_organic_board_overrides.py
"""
from __future__ import annotations

import math
import sys
from collections import Counter, defaultdict
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
INBOX = ROOT / "tools/models/board_parts/farm_inbox"
FARM = ROOT / "project/assets/models/board/farm_cast"
OUT = ROOT / "tools/models/board_parts"
PREVIEW = ROOT / "docs/art/review/board_figure_p1/organic_preview"
MODEL_H = 1.85
TARGET = 5600  # compose+weapon must stay ≤7k
NECK_Z = 1.48  # fallback; prefer neck_z_of(ob) after normalize

def neck_z_of(ob) -> float:
    """Chin/neck plane after normalize — 80% of figure height (5.45 heads)."""
    zs = [v.co.z for v in ob.data.vertices]
    return min(zs) + (max(zs) - min(zs)) * 0.80


SLOT = {
    "hair": 0, "skin": 1, "eye": 2, "coat": 3, "coat_dark": 4, "apron": 5,
    "sash": 6, "metal": 7, "blade": 8, "house": 9, "crest": 10, "cape": 11,
    "trousers": 12, "boots": 13, "leather": 14, "wood": 15, "accent": 16,
}

FIGURES = [
    ("compose_captain", ["hy_leader_m.glb", "leader_m.glb"], "outfit_captain", "ally"),
    ("compose_hunter", ["hunter_m.glb"], "outfit_hunter", "ally"),
    ("compose_bandit_weak", ["bandit_weak.glb", "bandit.glb"], "outfit_bandit_weak", "enemy"),
    ("compose_bandit", ["hy_bandit.glb", "bandit.glb"], "outfit_bandit_bandit", "enemy"),
    ("compose_bandit_archer", ["hy_bandit_archer.glb", "bandit_archer.glb"], "outfit_bandit_archer", "enemy"),
    ("compose_bandit_chief", ["bandit_chief.glb", "hy_bandit.glb", "bandit.glb"], "outfit_bandit_chief", "enemy"),
]


def log(*a):
    print("[organic_overrides]", *a, flush=True)


def tris(ob) -> int:
    ob.data.calc_loop_triangles()
    return len(ob.data.loop_triangles)


def find_src(names: list[str]) -> Path | None:
    for n in names:
        for base in (INBOX, FARM):
            p = base / n
            if p.is_file() and p.stat().st_size > 1000:
                return p
    return None


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_join(src: Path):
    before = {o.name for o in bpy.data.objects}
    bpy.ops.import_scene.gltf(filepath=str(src))
    meshes = [o for o in bpy.data.objects if o.type == "MESH" and o.name not in before]
    if not meshes:
        raise RuntimeError(f"no mesh in {src}")
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return ob


def apply_mod(ob, md_name: str):
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    try:
        bpy.ops.object.modifier_apply(modifier=md_name)
    except Exception as e:
        log("mod fail", md_name, e)
        if md_name in ob.modifiers:
            ob.modifiers.remove(ob.modifiers[md_name])


def normalize_height(ob):
    coords = [ob.matrix_world @ v.co for v in ob.data.vertices]
    mn = Vector(tuple(min(c[i] for c in coords) for i in range(3)))
    mx = Vector(tuple(max(c[i] for c in coords) for i in range(3)))
    h = max(1e-6, mx.z - mn.z)
    s = MODEL_H / h
    ob.scale = (s, s, s)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    coords = [ob.matrix_world @ v.co for v in ob.data.vertices]
    mn = Vector(tuple(min(c[i] for c in coords) for i in range(3)))
    mx = Vector(tuple(max(c[i] for c in coords) for i in range(3)))
    ob.location = (-0.5 * (mn.x + mx.x), -0.5 * (mn.y + mx.y), -mn.z)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)


def _weld(ob, thr=0.0015):
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=thr)
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")


def _ensure_head_vg(ob) -> str:
    name = "ck_head"
    vg = ob.vertex_groups.get(name) or ob.vertex_groups.new(name=name)
    zs = [v.co.z for v in ob.data.vertices]
    zmax = max(zs)
    neck = neck_z_of(ob)
    for i, v in enumerate(ob.data.vertices):
        if v.co.z >= neck - 0.04:
            w = (v.co.z - (neck - 0.04)) / max(1e-4, zmax - (neck - 0.04))
            w = max(0.35, min(1.0, 0.35 + 0.65 * w))
            vg.add([i], w, "REPLACE")
        else:
            vg.add([i], 0.0, "REPLACE")
    return name


def collapse_to(ob, target: int):
    """Weld → fine voxel (keep face detail) → head-protected decimate."""
    t0 = tris(ob)
    log("start tris", t0, "verts", len(ob.data.vertices))
    _weld(ob, 0.002)
    log("after weld", tris(ob), "verts", len(ob.data.vertices))

    # Finer voxels first so nose/brow survive; stop around 18–35k then protect-head collapse.
    for vs in (0.010, 0.012, 0.014, 0.016, 0.020, 0.024):
        md = ob.modifiers.new("VR", "REMESH")
        md.mode = "VOXEL"
        md.voxel_size = vs
        md.adaptivity = 0.0
        apply_mod(ob, md.name)
        t = tris(ob)
        log(f"voxel {vs}", t, "verts", len(ob.data.vertices))
        if 12000 <= t <= 40000:
            break
        if t < 8000 and vs >= 0.016:
            break

    vg_name = _ensure_head_vg(ob)
    t = tris(ob)
    if t > target:
        md = ob.modifiers.new("D", "DECIMATE")
        md.decimate_type = "COLLAPSE"
        md.ratio = max(0.08, min(0.95, target / float(max(1, t))))
        md.use_collapse_triangulate = True
        md.vertex_group = vg_name
        md.invert_vertex_group = True  # high head weight = protected
        md.vertex_group_factor = 1.0
        apply_mod(ob, md.name)
        log("collapse(protect head)", tris(ob), "verts", len(ob.data.vertices))

    if tris(ob) > 7000:
        md = ob.modifiers.new("Dcap", "DECIMATE")
        md.decimate_type = "COLLAPSE"
        md.ratio = max(0.05, 6900 / float(tris(ob)))
        md.vertex_group = vg_name
        md.invert_vertex_group = True
        md.vertex_group_factor = 0.85
        apply_mod(ob, md.name)
        log("cap", tris(ob))

    bpy.ops.object.shade_smooth()
    md = ob.modifiers.new("Lap", "LAPLACIANSMOOTH")
    md.iterations = 2
    md.lambda_factor = 0.12
    md.use_volume_preserve = True
    apply_mod(ob, md.name)
    _weld(ob, 0.001)
    bpy.ops.object.shade_smooth()
    log("final geometry", tris(ob), "verts", len(ob.data.vertices))


def fill_holes(ob, sides: int = 200):
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    try:
        bpy.ops.mesh.fill_holes(sides=sides)
    except Exception as e:
        log("fill_holes", e)
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.shade_smooth()


def enlarge_head(ob, factor: float = 1.28):
    me = ob.data
    zs = [v.co.z for v in me.vertices]
    zmax = max(zs)
    neck = neck_z_of(ob)
    head_vs = [v for v in me.vertices if v.co.z >= neck]
    if len(head_vs) < 20:
        return
    cx = sum(v.co.x for v in head_vs) / len(head_vs)
    cy = sum(v.co.y for v in head_vs) / len(head_vs)
    cz = sum(v.co.z for v in head_vs) / len(head_vs)
    for v in me.vertices:
        if v.co.z < neck:
            continue
        w = (v.co.z - neck) / max(1e-4, zmax - neck)
        w = max(0.0, min(1.0, w))
        w = w * w * (3 - 2 * w)
        f = 1.0 + (factor - 1.0) * w
        v.co.x = cx + (v.co.x - cx) * f
        v.co.y = cy + (v.co.y - cy) * f
        v.co.z = cz + (v.co.z - cz) * f
    me.update()
    normalize_height(ob)


def sculpt_face(ob):
    """Displace verts for nose / brow / cheeks / jaw — readable volumes, no boolean."""
    me = ob.data
    neck = neck_z_of(ob)
    zs = [v.co.z for v in me.vertices]
    zmax = max(zs)
    head_h = max(0.05, zmax - neck)
    head = [v for v in me.vertices if v.co.z >= neck - 0.02]
    if len(head) < 40:
        return
    cx = sum(v.co.x for v in head) / len(head)
    cy = sum(v.co.y for v in head) / len(head)
    nose_z = neck + 0.40 * head_h
    brow_z = neck + 0.55 * head_h
    cheek_z = neck + 0.38 * head_h
    jaw_z = neck + 0.18 * head_h
    chin_z = neck + 0.06 * head_h

    for v in me.vertices:
        if v.co.z < neck - 0.02:
            continue
        dx = v.co.x - cx
        dy = v.co.y - cy
        # Front hemisphere weight
        front = max(0.0, -(v.co.y - cy))  # more positive when more forward (−Y)
        front_w = max(0.0, min(1.0, (front - 0.01) / 0.10))
        if front_w <= 0.0 and v.co.y > cy:
            # back of head — skip facial sculpt
            continue

        # Nose ridge: center front, push −Y and slight +Z toward tip
        nd = math.sqrt(dx * dx + (v.co.z - nose_z) ** 2)
        if nd < 0.055 and front_w > 0.25:
            k = (1.0 - nd / 0.055) ** 2 * front_w
            v.co.y -= 0.042 * k
            v.co.z += 0.006 * k * (1.0 if v.co.z >= nose_z - 0.02 else -0.3)

        # Brow ridge
        bd = math.sqrt((abs(dx) - 0.03) ** 2 + (v.co.z - brow_z) ** 2) if abs(dx) > 0.02 else abs(v.co.z - brow_z)
        if abs(dx) < 0.10 and abs(v.co.z - brow_z) < 0.04 and front_w > 0.15:
            k = (1.0 - abs(v.co.z - brow_z) / 0.04) * front_w
            v.co.y -= 0.018 * k
            v.co.z += 0.014 * k

        # Cheeks outward
        if 0.04 < abs(dx) < 0.10 and abs(v.co.z - cheek_z) < 0.05 and front_w > 0.15:
            k = (1.0 - abs(v.co.z - cheek_z) / 0.05) * front_w
            v.co.x += math.copysign(0.018 * k, dx)
            v.co.y -= 0.006 * k

        # Jaw widen + chin forward
        if v.co.z < NECK_Z + 0.10 and front_w > 0.1:
            k = max(0.0, 1.0 - abs(v.co.z - jaw_z) / 0.08) * front_w
            if abs(dx) > 0.02:
                v.co.x += math.copysign(0.016 * k, dx)
            if abs(dx) < 0.04 and abs(v.co.z - chin_z) < 0.045:
                v.co.y -= 0.022 * (1.0 - abs(v.co.z - chin_z) / 0.045) * front_w

        # Eye sockets: slight recess (not paint — geometry)
        for sx in (-1, 1):
            ex, ez = cx + sx * 0.038, neck + 0.45 * head_h
            ed = math.sqrt((v.co.x - ex) ** 2 + (v.co.z - ez) ** 2)
            if ed < 0.028 and front_w > 0.35:
                k = (1.0 - ed / 0.028) ** 2 * front_w
                v.co.y += 0.010 * k  # recess toward +Y (into head)

    me.update()
    log("sculpt_face", tris(ob))


def _classify_face(poly, me, kind: str, zmin: float, zmax: float, cx0: float, cy0: float, neck: float) -> str:
    """Per-face slot. Face front defaults to skin — never whole-face hair/eye."""
    idxs = list(poly.vertices)
    cz = sum(me.vertices[i].co.z for i in idxs) / len(idxs)
    cx = sum(me.vertices[i].co.x for i in idxs) / len(idxs)
    cy = sum(me.vertices[i].co.y for i in idxs) / len(idxs)
    n = poly.normal
    t = (cz - zmin) / max(1e-6, zmax - zmin)
    front = -n.y
    up = n.z
    head_h = max(0.05, zmax - neck)

    if t < 0.10:
        return "boots"
    if t < 0.38:
        return "trousers"

    # --- Head (relative to dynamic neck) ---
    if cz >= neck - 0.02:
        for sx in (-1.0, 1.0):
            ex, ez = cx0 + sx * 0.038, neck + 0.42 * head_h
            if (cx - ex) ** 2 + (cz - ez) ** 2 < (0.016 * head_h / 0.35) ** 2 and front > 0.50 and cy < cy0 + 0.02:
                return "eye"
        # Hair ONLY: top of head / rear. Front half of head is always skin (+tiny eyes).
        crown = up > 0.30 and cz > neck + 0.55 * head_h
        rear = cy >= cy0  # back half of head in Y
        side_hair = abs(cx - cx0) > 0.11 and cz > neck + 0.55 * head_h and rear
        if (crown and rear) or (rear and cz > neck + 0.25 * head_h and front < 0.20) or side_hair:
            return "hair"
        return "skin"

    # --- Torso clothing (tight bands — house must NOT flood limbs) ---
    if n.y > 0.55 and cz > neck - 0.35 and cz < neck - 0.02 and abs(cx - cx0) > 0.06:
        return "cape" if kind == "ally" else "coat_dark"
    # Collar only: back/side of neck, not jaw front
    if neck - 0.10 < cz < neck + 0.01 and front < 0.15:
        return "coat_dark"
    # Thin waist belt only
    if 0.98 < cz < 1.06 and abs(cy - cy0) < 0.10 and abs(cx - cx0) < 0.20:
        return "house" if kind == "ally" else "sash"
    if abs(cx - cx0) > 0.32 and 0.88 < cz < 1.20 and front > -0.10:
        return "skin"  # hands
    if abs(cx - cx0) > 0.24 and 1.10 < cz < 1.36 and front < 0.25:
        return "leather"
    if t > 0.58 and abs(cx - cx0) > 0.20 and cz > 1.25 and math.sqrt(n.x * n.x + n.y * n.y) > 0.85:
        return "metal"
    if up < -0.45 and t > 0.42 and cz < NECK_Z - 0.05:
        return "coat_dark"
    return "coat"


def _smooth_face_labels(labels: list[str], me, rounds: int = 3) -> list[str]:
    """Majority filter on face adjacency — kills speckles that cause jagged borders."""
    # Build face adjacency via shared edges
    edge_faces: dict[tuple[int, int], list[int]] = defaultdict(list)
    for fi, poly in enumerate(me.polygons):
        vs = list(poly.vertices)
        for a, b in zip(vs, vs[1:] + vs[:1]):
            e = (min(a, b), max(a, b))
            edge_faces[e].append(fi)
    neigh = [set() for _ in me.polygons]
    for fis in edge_faces.values():
        if len(fis) == 2:
            a, b = fis
            neigh[a].add(b)
            neigh[b].add(a)
        elif len(fis) > 2:
            for i in fis:
                for j in fis:
                    if i != j:
                        neigh[i].add(j)

    cur = list(labels)
    for _ in range(rounds):
        nxt = list(cur)
        for fi in range(len(cur)):
            # Never majority-away tiny eye islands aggressively — protect eyes
            if cur[fi] == "eye":
                eye_n = sum(1 for j in neigh[fi] if cur[j] == "eye")
                if eye_n >= 1 or len(neigh[fi]) <= 2:
                    continue
            votes = Counter(cur[j] for j in neigh[fi])
            if not votes:
                continue
            # Prefer keeping skin on head boundary vs hair bleed
            top, cnt = votes.most_common(1)[0]
            if top != cur[fi] and cnt >= max(2, (len(neigh[fi]) + 1) // 2):
                # Don't let hair flood into front skin in one step unless strong majority
                if cur[fi] == "skin" and top == "hair" and cnt < len(neigh[fi]) * 0.75:
                    continue
                nxt[fi] = top
        cur = nxt
    return cur


def bisect_bands(ob):
    """Insert clean horizontal loops at boot/trouser cuts for hard colour borders."""
    zs = [v.co.z for v in ob.data.vertices]
    zmin, zmax = min(zs), max(zs)
    h = max(1e-6, zmax - zmin)
    cuts = [zmin + 0.11 * h, zmin + 0.40 * h]
    bpy.context.view_layer.objects.active = ob
    for zc in cuts:
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.bisect(
            plane_co=(0.0, 0.0, zc),
            plane_no=(0.0, 0.0, 1.0),
            clear_inner=False,
            clear_outer=False,
            use_fill=False,
        )
        bpy.ops.object.mode_set(mode="OBJECT")
    log("bisect bands", tris(ob))


def paint_slots_clean(ob, kind: str):
    """Face labels → smooth → split borders → POINT colours (clean islands)."""
    me = ob.data
    zs = [v.co.z for v in me.vertices]
    zmin, zmax = min(zs), max(zs)
    neck = neck_z_of(ob)
    log("dynamic neck", round(neck, 3), "h", round(zmax - zmin, 3))
    head = [v for v in me.vertices if v.co.z >= neck]
    cx0 = sum(v.co.x for v in head) / max(1, len(head))
    cy0 = sum(v.co.y for v in head) / max(1, len(head)) if head else 0.0

    labels = [_classify_face(p, me, kind, zmin, zmax, cx0, cy0, neck) for p in me.polygons]
    labels = _smooth_face_labels(labels, me, rounds=4)
    hist = Counter(labels)
    log("face labels", dict(hist))

    # Store labels on faces via freestyle mark / material index — use attribute
    # Split edges between different labels
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    bm.edges.ensure_lookup_table()
    # Map face index → label (bmesh face.index matches after from_mesh)
    to_split = []
    for e in bm.edges:
        fs = e.link_faces
        if len(fs) == 2:
            if labels[fs[0].index] != labels[fs[1].index]:
                to_split.append(e)
    if to_split:
        bmesh.ops.split_edges(bm, edges=to_split)
    bm.to_mesh(me)
    bm.free()
    me.update()

    # Recompute labels after split (topology changed — reclassify is safer)
    labels = [_classify_face(p, me, kind, zmin, zmax, cx0, cy0, neck) for p in me.polygons]
    labels = _smooth_face_labels(labels, me, rounds=2)

    while me.color_attributes:
        me.color_attributes.remove(me.color_attributes[0])
    attr = me.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="POINT")

    # Accumulate per-vertex slot votes from adjacent faces
    votes = [Counter() for _ in me.vertices]
    for fi, poly in enumerate(me.polygons):
        lab = labels[fi]
        for vi in poly.vertices:
            votes[vi][lab] += 1

    # Resolve slots, then FORCE front face = skin (tiny eyes + crown hair only).
    slots = ["coat"] * len(me.vertices)
    for i, v in enumerate(me.vertices):
        if votes[i]:
            common = votes[i].most_common()
            slot = common[0][0]
            if len(common) > 1 and common[0][1] == common[1][1]:
                for cand, _ in common:
                    if cand == "skin":
                        slot = "skin"
                        break
            slots[i] = slot
        else:
            slots[i] = "coat"

    # HARD head paint (ignore votes): face plate = skin, tiny eyes, hair only upper-rear cap.
    head_h = max(0.05, zmax - neck)
    head_vs = [v for v in me.vertices if v.co.z >= neck - 0.02]
    y_front = min(v.co.y for v in head_vs) if head_vs else cy0
    y_back = max(v.co.y for v in head_vs) if head_vs else cy0
    y_span = max(0.05, y_back - y_front)
    y_mid = y_front + 0.60 * y_span
    eye_r = 0.012 * head_h / 0.35
    eye_centers = [(cx0 - 0.036, neck + 0.42 * head_h), (cx0 + 0.036, neck + 0.42 * head_h)]
    log("face Y", round(y_front, 3), "→", round(y_back, 3), "cut", round(y_mid, 3), "head_verts", len(head_vs))
    n_skin = n_hair = n_eye = 0
    for i, v in enumerate(me.vertices):
        if v.co.z < neck - 0.02:
            if slots[i] in ("hair", "eye"):
                slots[i] = "coat" if slots[i] == "hair" else "skin"
            continue
        frontish = v.co.y <= y_mid
        upper = v.co.z > neck + 0.50 * head_h
        rear = v.co.y > y_mid
        in_eye = False
        if frontish:
            for ex, ez in eye_centers:
                if (v.co.x - ex) ** 2 + (v.co.z - ez) ** 2 <= eye_r * eye_r:
                    in_eye = True
                    break
        if in_eye:
            slots[i] = "eye"; n_eye += 1
        elif rear and upper:
            slots[i] = "hair"; n_hair += 1
        else:
            slots[i] = "skin"; n_skin += 1
    log("head hard", "skin", n_skin, "hair", n_hair, "eye", n_eye)

    # HARD body bands (clean horizontal borders — kills sawtooth coat/trousers).
    h = max(1e-6, zmax - zmin)
    for i, v in enumerate(me.vertices):
        if v.co.z >= neck - 0.02:
            continue
        tz = (v.co.z - zmin) / h
        ax = abs(v.co.x - cx0)
        if tz < 0.11:
            slots[i] = "boots"
        elif tz < 0.40:
            slots[i] = "trousers"
        elif ax > 0.30 and 0.45 < tz < 0.72:
            slots[i] = "skin"  # hands/forearms
        elif neck - 0.12 < v.co.z < neck - 0.02 and v.co.y > cy0:
            slots[i] = "coat_dark"  # back collar only
        else:
            slots[i] = "coat"

    from collections import Counter as _C
    log("POINT slots", dict(_C(slots)))

    for i, v in enumerate(me.vertices):
        slot = slots[i]
        ao = 0.80 + 0.20 * max(0.0, min(1.0, v.co.z / 1.25))
        if slot in ("trousers", "boots"):
            ao *= 0.92
        flags = 0.25 if slot == "metal" else 0.0
        attr.data[i].color = (SLOT[slot] / 255.0, max(0.55, min(1.0, ao)), flags, 1.0)

    me.update()
    bpy.ops.object.shade_smooth()
    # Soft edge: one pass average AO only among same-slot neighbours (keep R hard)
    # (skip — hard R is what kills jagged paint bleed)

    # Cap tris after split
    if tris(ob) > 6500:
        vg_name = _ensure_head_vg(ob)
        md = ob.modifiers.new("Dsplit", "DECIMATE")
        md.decimate_type = "COLLAPSE"
        md.ratio = 6000 / float(tris(ob))
        md.vertex_group = vg_name
        md.invert_vertex_group = True
        apply_mod(ob, md.name)
        log("after-split cap", tris(ob))
    log("paint clean", tris(ob), "verts", len(me.vertices))


def strip_extras(ob):
    ob.data.materials.clear()
    while ob.data.uv_layers:
        ob.data.uv_layers.remove(ob.data.uv_layers[0])


def export_glb(ob, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    for o in list(bpy.context.scene.objects):
        if o != ob:
            bpy.data.objects.remove(o, do_unlink=True)
    ob.name = path.stem
    if ob.data:
        ob.data.name = path.stem
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_texcoords=False,
        export_normals=True,
        export_materials="NONE",
        export_vertex_color="ACTIVE",
        export_all_vertex_colors=True,
        export_active_vertex_color_when_no_material=True,
    )
    log("wrote", path.name, "tris", tris(ob), "bytes", path.stat().st_size)


def render_preview(ob, path: Path, title: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    mat = bpy.data.materials.new("prev")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    # Visualize slots: Attribute Color.R → hue bands
    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "Color"
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    # Map slot id/255 into distinct preview colours
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (0.15, 0.10, 0.08, 1)  # hair
    ramp.color_ramp.elements[1].position = 1.0
    ramp.color_ramp.elements[1].color = (0.55, 0.58, 0.62, 1)
    e = ramp.color_ramp.elements.new(1.0 / 255.0)
    e.color = (0.85, 0.68, 0.55, 1)  # skin
    e = ramp.color_ramp.elements.new(2.0 / 255.0)
    e.color = (0.12, 0.12, 0.14, 1)  # eye
    e = ramp.color_ramp.elements.new(3.0 / 255.0)
    e.color = (0.45, 0.50, 0.58, 1)  # coat
    e = ramp.color_ramp.elements.new(12.0 / 255.0)
    e.color = (0.20, 0.24, 0.32, 1)  # trousers
    e = ramp.color_ramp.elements.new(13.0 / 255.0)
    e.color = (0.10, 0.11, 0.13, 1)  # boots
    nt.links.new(attr.outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Red"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.5
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    ob.data.materials.clear()
    ob.data.materials.append(mat)

    cam_data = bpy.data.cameras.new("C")
    cam = bpy.data.objects.new("C", cam_data)
    bpy.context.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    zs = [v.co.z for v in ob.data.vertices]
    zc = 0.5 * (min(zs) + max(zs))
    cam.location = (1.55, -2.85, zc + 0.25)
    direction = Vector((0.0, 0.0, zc + 0.1)) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    cam_data.lens = 55
    light = bpy.data.objects.new("L", bpy.data.lights.new("L", "SUN"))
    light.data.energy = 2.8
    light.rotation_euler = (math.radians(48), 0, math.radians(-35))
    bpy.context.collection.objects.link(light)
    fill = bpy.data.objects.new("F", bpy.data.lights.new("F", "AREA"))
    fill.data.energy = 60
    fill.data.size = 2.5
    fill.location = (-1.4, 1.2, 2.2)
    bpy.context.collection.objects.link(fill)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 32
    sc.cycles.use_denoising = True
    sc.render.resolution_x = 420
    sc.render.resolution_y = 560
    sc.render.film_transparent = True
    sc.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    log("preview", title, path.name)


def build_one(compose_name: str, sources: list[str], outfit_name: str, kind: str):
    src = find_src(sources)
    if src is None:
        log("SKIP no source", compose_name, sources)
        return None
    log("===", compose_name, "from", src)
    reset()
    ob = import_join(src)
    normalize_height(ob)
    collapse_to(ob, TARGET)
    fill_holes(ob)
    normalize_height(ob)
    enlarge_head(ob, 1.28 if kind == "ally" else 1.22)
    sculpt_face(ob)
    fill_holes(ob)
    bisect_bands(ob)
    # One subdiv for denser slot borders, then head-protected collapse back ≤7k
    if tris(ob) < 9000:
        md = ob.modifiers.new("SubC", "SUBSURF")
        md.levels = 1
        apply_mod(ob, md.name)
        vg = _ensure_head_vg(ob)
        if tris(ob) > 6200:
            md = ob.modifiers.new("Dsub", "DECIMATE")
            md.decimate_type = "COLLAPSE"
            md.ratio = max(0.1, 6000 / float(tris(ob)))
            md.vertex_group = vg
            md.invert_vertex_group = True
            apply_mod(ob, md.name)
        log("border densify", tris(ob))
    paint_slots_clean(ob, kind)
    strip_extras(ob)
    compose_path = OUT / f"{compose_name}.glb"
    export_glb(ob, compose_path)
    reset()
    bpy.ops.import_scene.gltf(filepath=str(compose_path))
    ob3 = [o for o in bpy.data.objects if o.type == "MESH"][0]
    # weld after import (glTF may corner-split)
    _weld(ob3, 0.0012)
    render_preview(ob3, PREVIEW / f"{compose_name}.png", compose_name)
    return compose_path


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    PREVIEW.mkdir(parents=True, exist_ok=True)
    built = []
    for compose, sources, outfit, kind in FIGURES:
        p = build_one(compose, sources, outfit, kind)
        if p:
            built.append(p.name)
    log("DONE overrides", built)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as e:
        log("FATAL", e)
        import traceback
        traceback.print_exc()
        raise SystemExit(1)
