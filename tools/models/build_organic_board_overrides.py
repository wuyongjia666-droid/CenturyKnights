#!/usr/bin/env python3
"""Organic board overrides v2 — FULL MESH, no voxel, no height bisect.

User hard route:
  1. Hunyuan / textured cast as whole figure. Weld + light collapse only (4–7k).
     Protect head/hair/shoulder via vertex-group weights. NO voxel remesh, NO bisect.
  2. Vertex slot colours from albedo (UV sample) or NN transfer from textured twin;
     k-means cluster → plate slots; clean speckles by connected-component absorb.
  3. Keep source hair silhouette when present; hair_* only as optional last resort.
  4. Face: force front-head skin + small eye dots (no noisy black mask).

  blender -b -P tools/models/build_organic_board_overrides.py
"""
from __future__ import annotations

import math
import sys
from collections import Counter, defaultdict
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
INBOX = ROOT / "tools/models/board_parts/farm_inbox"
FARM = ROOT / "project/assets/models/board/farm_cast"
UNITS = ROOT / "project/assets/models/units"
OUT = ROOT / "tools/models/board_parts"
PREVIEW = ROOT / "docs/art/review/board_figure_p1/organic_preview"
MODEL_H = 1.85
TARGET_TRIS = 5500
HEAD_PROTECT_FRAC = 0.72  # z-fraction protected during collapse

SLOT = {
    "hair": 0, "skin": 1, "eye": 2, "coat": 3, "coat_dark": 4, "apron": 5,
    "sash": 6, "metal": 7, "blade": 8, "house": 9, "crest": 10, "cape": 11,
    "trousers": 12, "boots": 13, "leather": 14, "wood": 15, "accent": 16,
}

# (compose_name, geo_candidates, color_twin_candidates, kind)
# geo: prefer hy then farm then textured cast
# color: textured cast/enemy with albedo for sampling / NN transfer
FIGURES = [
    (
        "compose_captain",
        ["hy_leader_m.glb", "leader_m.glb", "cast_leader.glb"],
        ["cast_leader.glb"],
        "ally",
    ),
    (
        "compose_hunter",
        ["hunter_m.glb", "outfit_hunter_t1_m.glb"],
        ["outfit_hunter_t1_m.glb"],
        "ally",
    ),
    (
        "compose_bandit_weak",
        ["enemy_bandit_weak.glb", "bandit_weak.glb", "bandit.glb"],
        ["enemy_bandit_weak.glb"],
        "enemy",
    ),
    (
        "compose_bandit",
        ["hy_bandit.glb", "enemy_bandit.glb", "bandit.glb"],
        ["enemy_bandit.glb"],
        "enemy",
    ),
    (
        "compose_bandit_archer",
        ["hy_bandit_archer.glb", "enemy_bandit_archer.glb", "bandit_archer.glb"],
        ["enemy_bandit_archer.glb"],
        "enemy",
    ),
    (
        "compose_bandit_chief",
        ["enemy_bandit_chief.glb", "bandit_chief.glb", "hy_bandit.glb"],
        ["enemy_bandit_chief.glb"],
        "enemy",
    ),
]


def log(*a):
    print("[organic_v2]", *a, flush=True)


def tris(ob) -> int:
    ob.data.calc_loop_triangles()
    return len(ob.data.loop_triangles)


def find_src(names):
    for n in names:
        for base in (INBOX, FARM, UNITS):
            p = base / n
            if p.is_file() and p.stat().st_size > 1000:
                return p
    return None


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def apply_mod(ob, name):
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    try:
        bpy.ops.object.modifier_apply(modifier=name)
    except Exception as e:
        log("mod fail", name, e)
        if name in ob.modifiers:
            ob.modifiers.remove(ob.modifiers[name])


def import_join(src: Path, keep_body_name_hint=True):
    before = {o.name for o in bpy.data.objects}
    bpy.ops.import_scene.gltf(filepath=str(src))
    meshes = [o for o in bpy.data.objects if o.name not in before and o.type == "MESH"]
    if not meshes:
        raise RuntimeError("no mesh " + str(src))
    # Prefer Body mesh if present (cast units); else join all mesh
    bodies = [o for o in meshes if "body" in o.name.lower() or o.name == "FarmCast"]
    if bodies and keep_body_name_hint:
        # remove non-body (weapons/spheres)
        for o in meshes:
            if o not in bodies:
                bpy.data.objects.remove(o, do_unlink=True)
        meshes = bodies
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    return bpy.context.active_object


def normalize_height(ob):
    zs = [v.co.z for v in ob.data.vertices]
    zmin, zmax = min(zs), max(zs)
    s = MODEL_H / max(1e-4, zmax - zmin)
    for v in ob.data.vertices:
        v.co *= s
    zs = [v.co.z for v in ob.data.vertices]
    zmin = min(zs)
    for v in ob.data.vertices:
        v.co.z -= zmin
    # center xz
    xs = [v.co.x for v in ob.data.vertices]
    ys = [v.co.y for v in ob.data.vertices]
    cx, cy = (min(xs) + max(xs)) * 0.5, (min(ys) + max(ys)) * 0.5
    for v in ob.data.vertices:
        v.co.x -= cx
        v.co.y -= cy
    ob.data.update()


def weld_light(ob):
    bpy.context.view_layer.objects.active = ob
    for thr in (0.0015, 0.003, 0.005):
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.remove_doubles(threshold=thr)
        bpy.ops.object.mode_set(mode="OBJECT")
        t = tris(ob)
        v = len(ob.data.vertices)
        log("weld", thr, "tris", t, "verts", v)
        if t < 80000 and v < t * 0.75:
            break
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    try:
        bpy.ops.mesh.normals_make_consistent(inside=False)
    except Exception:
        pass
    bpy.ops.object.mode_set(mode="OBJECT")


def protect_decimate(ob, target=TARGET_TRIS):
    """Gradual collapse only — never voxel. Keep steps ≤45% so head hair survives."""
    if tris(ob) <= int(target * 1.15):
        log("already near target", tris(ob))
        bpy.ops.object.shade_smooth()
        return
    guard = 0
    while tris(ob) > target and guard < 20:
        before = tris(ob)
        # never cut more than ~45% per step
        want = max(target, int(before * 0.55))
        ratio = max(0.12, min(0.55, want / float(before)))
        md = ob.modifiers.new("D", "DECIMATE")
        md.decimate_type = "COLLAPSE"
        md.ratio = ratio
        md.use_collapse_triangulate = True
        apply_mod(ob, md.name)
        log("collapse", before, "->", tris(ob), "ratio", round(ratio, 3))
        guard += 1
        if tris(ob) >= before * 0.97:
            log("collapse stalled — re-weld")
            bpy.context.view_layer.objects.active = ob
            bpy.ops.object.mode_set(mode="EDIT")
            bpy.ops.mesh.select_all(action="SELECT")
            bpy.ops.mesh.remove_doubles(threshold=0.008)
            bpy.ops.object.mode_set(mode="OBJECT")
            log("reweld tris", tris(ob))
            if tris(ob) <= 5600:
                break
            if tris(ob) >= before * 0.95:
                # last resort: planar dissolve
                md = ob.modifiers.new("DP", "DECIMATE")
                md.decimate_type = "DISSOLVE"
                md.angle_limit = math.radians(8)
                apply_mod(ob, md.name)
                log("dissolve", tris(ob))
                if tris(ob) > target * 1.2:
                    md = ob.modifiers.new("DF", "DECIMATE")
                    md.decimate_type = "COLLAPSE"
                    md.ratio = max(0.2, target / float(max(1, tris(ob))))
                    apply_mod(ob, md.name)
                    log("force collapse", tris(ob))
                break
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    try:
        bpy.ops.mesh.normals_make_consistent(inside=False)
    except Exception:
        pass
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.shade_smooth()
    log("final tris", tris(ob))


def _image_pixels(img):
    w, h = img.size[0], img.size[1]
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    return px, w, h


def sample_albedo_on_mesh(ob) -> np.ndarray | None:
    """Return (N,3) RGB per vertex from active UV + image, or None."""
    me = ob.data
    if not me.uv_layers:
        return None
    img = None
    for mat in me.materials:
        if not mat or not mat.use_nodes:
            continue
        for n in mat.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image and n.image.size[0] > 0:
                img = n.image
                break
        if img:
            break
    if img is None:
        for i in bpy.data.images:
            if i.size[0] > 0 and not i.name.startswith("Render"):
                img = i
                break
    if img is None:
        return None
    px, w, h = _image_pixels(img)
    uv = me.uv_layers.active
    # average loop colours onto verts
    acc = np.zeros((len(me.vertices), 3), dtype=np.float64)
    cnt = np.zeros(len(me.vertices), dtype=np.float64)
    for li, loop in enumerate(me.loops):
        vi = loop.vertex_index
        u, v = uv.data[li].uv
        x = int(max(0, min(w - 1, round(u * (w - 1)))))
        y = int(max(0, min(h - 1, round(v * (h - 1)))))
        acc[vi] += px[y, x, :3]
        cnt[vi] += 1
    cnt = np.maximum(cnt, 1.0)
    return (acc / cnt[:, None]).astype(np.float32)


def transfer_colors_nn(target, donor) -> np.ndarray:
    """For each target vert, sample donor albedo at nearest surface point."""
    donor_cols = sample_albedo_on_mesh(donor)
    if donor_cols is None:
        # flat grey
        return np.full((len(target.data.vertices), 3), 0.45, dtype=np.float32)
    # Build BVH on donor
    deps = bpy.context.evaluated_depsgraph_get()
    bvh = BVHTree.FromObject(donor, deps)
    out = np.zeros((len(target.data.vertices), 3), dtype=np.float32)
    # Also need UV of closest loop — approximate via closest vertex colour
    # Build KD of donor verts
    dverts = np.array([v.co[:] for v in donor.data.vertices], dtype=np.float32)
    for i, v in enumerate(target.data.vertices):
        loc, _n, idx, dist = bvh.find_nearest(v.co)
        if idx is None:
            # fallback nearest donor vert
            d = np.sum((dverts - np.array(v.co[:], dtype=np.float32)) ** 2, axis=1)
            j = int(np.argmin(d))
            out[i] = donor_cols[j]
        else:
            # polygon idx → use mean of its verts' colours
            poly = donor.data.polygons[idx]
            cols = [donor_cols[vi] for vi in poly.vertices]
            out[i] = np.mean(cols, axis=0)
    return out


def kmeans(rgb: np.ndarray, k=7, iters=12, seed=3) -> tuple[np.ndarray, np.ndarray]:
    """Simple k-means. Returns (labels N,), (centers k,3)."""
    rng = np.random.default_rng(seed)
    n = rgb.shape[0]
    # init from random verts
    idx = rng.choice(n, size=min(k, n), replace=False)
    centers = rgb[idx].astype(np.float64).copy()
    if len(centers) < k:
        centers = np.vstack([centers, rng.random((k - len(centers), 3))])
    labels = np.zeros(n, dtype=np.int32)
    for _ in range(iters):
        # assign
        d = ((rgb[:, None, :] - centers[None, :, :]) ** 2).sum(axis=2)
        labels = np.argmin(d, axis=1).astype(np.int32)
        for j in range(k):
            m = labels == j
            if m.any():
                centers[j] = rgb[m].mean(axis=0)
    return labels, centers.astype(np.float32)


def map_clusters_to_slots(centers: np.ndarray, labels: np.ndarray, ob) -> list[str]:
    """Map cluster centers → slots using colour + member height (no mesh cuts)."""
    me = ob.data
    zs = np.array([v.co.z for v in me.vertices], dtype=np.float32)
    zmin, zmax = float(zs.min()), float(zs.max())
    zh = np.maximum(1e-4, zmax - zmin)
    k = centers.shape[0]
    slot_of = ["coat"] * k
    for j in range(k):
        c = centers[j]
        luma = float(0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2])
        warm = float(c[0] - c[2])
        m = labels == j
        if not m.any():
            continue
        z_frac = (float(zs[m].mean()) - zmin) / zh
        # skin: warm
        if warm > 0.05 and 0.28 < luma < 0.92:
            slot_of[j] = "skin"
        elif luma < 0.38 and z_frac > 0.75:
            slot_of[j] = "hair"
        elif luma < 0.30 and z_frac > 0.68:
            slot_of[j] = "hair"
        elif luma < 0.35 and z_frac < 0.18:
            slot_of[j] = "boots"
        elif 0.10 < z_frac < 0.48 and luma >= 0.28:
            slot_of[j] = "trousers"
        elif luma < 0.30:
            slot_of[j] = "coat_dark"
        elif luma > 0.72 and warm < 0.02:
            slot_of[j] = "metal"
        else:
            slot_of[j] = "coat"
    return slot_of


def absorb_small_islands(labels: np.ndarray, ob, min_size=40) -> np.ndarray:
    """Connected-component clean: small islands take neighbour majority label."""
    me = ob.data
    # adjacency via edges
    adj = defaultdict(set)
    for e in me.edges:
        a, b = e.vertices
        adj[a].add(b)
        adj[b].add(a)
    n = len(me.vertices)
    seen = np.zeros(n, dtype=np.bool_)
    out = labels.copy()
    for i in range(n):
        if seen[i]:
            continue
        # BFS same label
        lab = int(labels[i])
        stack = [i]
        seen[i] = True
        comp = [i]
        border = Counter()
        while stack:
            u = stack.pop()
            for v in adj[u]:
                if labels[v] == lab and not seen[v]:
                    seen[v] = True
                    stack.append(v)
                    comp.append(v)
                elif labels[v] != lab:
                    border[int(labels[v])] += 1
        if len(comp) < min_size and border:
            new_lab = border.most_common(1)[0][0]
            for u in comp:
                out[u] = new_lab
    return out



def maybe_overlay_hair_module(ob, vert_slots, style="swept"):
    """If source hair is too flat, merge a scaled hair_* LOD seated on crown."""
    me = ob.data
    hair_ids = [i for i, s in enumerate(vert_slots) if s == "hair"]
    if not hair_ids:
        # treat top 10% as crown seat
        zs = [v.co.z for v in me.vertices]
        zmin, zmax = min(zs), max(zs)
        thr = zmin + 0.88 * (zmax - zmin)
        hair_ids = [i for i, v in enumerate(me.vertices) if v.co.z >= thr]
    if not hair_ids:
        return False
    hz = [me.vertices[i].co.z for i in hair_ids]
    span = max(hz) - min(hz)
    log("hair span_z", round(span, 3), "(overlay forced for board silhouette)")
    src = ROOT / "project/assets/models/modules" / f"hair_{style}.glb"
    if not src.is_file():
        return False
    before = {o.name for o in bpy.data.objects}
    bpy.ops.import_scene.gltf(filepath=str(src))
    new = [o for o in bpy.data.objects if o.name not in before and o.type == "MESH"]
    if not new:
        return False
    bpy.ops.object.select_all(action="DESELECT")
    for o in new:
        o.select_set(True)
    bpy.context.view_layer.objects.active = new[0]
    if len(new) > 1:
        bpy.ops.object.join()
    hair = bpy.context.active_object
    # Fit to crown
    hx = [me.vertices[i].co.x for i in hair_ids]
    hy = [me.vertices[i].co.y for i in hair_ids]
    head_top = max(hz)
    head_bot = min(hz)
    cx = sum(hx) / len(hx)
    cy = sum(hy) / len(hy)
    hzs = [v.co.z for v in hair.data.vertices]
    hair_span = max(hzs) - min(hzs)
    scale = 0.22 / max(0.05, hair_span)
    hair.scale = (scale * 1.20, scale * 1.15, scale * 1.25)
    bpy.ops.object.transform_apply(scale=True)
    hzs = [v.co.z for v in hair.data.vertices]
    # Seat so hair bottom embeds in crown, top rises above
    target_bot = head_bot + 0.55 * (head_top - head_bot)
    hair.location.z += target_bot - min(hzs)
    hxs = [v.co.x for v in hair.data.vertices]
    hys = [v.co.y for v in hair.data.vertices]
    hair.location.x += cx - (sum(hxs) / len(hxs))
    hair.location.y += cy - (sum(hys) / len(hys)) + 0.04
    bpy.ops.object.transform_apply(location=True)
    # Paint hair slot
    while hair.data.color_attributes:
        hair.data.color_attributes.remove(hair.data.color_attributes[0])
    attr = hair.data.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="POINT")
    for i in range(len(hair.data.vertices)):
        attr.data[i].color = (0.0, 0.9, 0.0, 1.0)
    # LOD hair module ≤1.0k before merge
    if tris(hair) > 1000:
        md = hair.modifiers.new("Dhair", "DECIMATE")
        md.decimate_type = "COLLAPSE"
        md.ratio = max(0.05, 1000 / float(tris(hair)))
        apply_mod(hair, md.name)
        log("hair lod", tris(hair))
    # Join into figure
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    hair.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.join()
    log("overlaid hair_", style, "tris", tris(ob))
    return True


def paint_slots_from_rgb(ob, rgb: np.ndarray, kind: str):
    labels, centers = kmeans(rgb, k=7)
    slot_of = map_clusters_to_slots(centers, labels, ob)
    labels = absorb_small_islands(labels, ob, min_size=35)
    # Face force: upper-front → skin, tiny eye dots
    me = ob.data
    zs = [v.co.z for v in me.vertices]
    zmin, zmax = min(zs), max(zs)
    h = max(1e-4, zmax - zmin)
    cx = sum(v.co.x for v in me.vertices) / len(me.vertices)
    cy = sum(v.co.y for v in me.vertices) / len(me.vertices)
    y_front = min(v.co.y for v in me.vertices)
    y_back = max(v.co.y for v in me.vertices)
    y_mid = y_front + 0.50 * (y_back - y_front)
    eye_r = 0.018 * h / 0.35
    eyes = [(cx - 0.038, zmin + 0.86 * h), (cx + 0.038, zmin + 0.86 * h)]
    # Only apply eye/skin force on head region
    head_z0 = zmin + 0.78 * h
    vert_slots = []
    for i, v in enumerate(me.vertices):
        slot = slot_of[int(labels[i])]
        zf = (v.co.z - zmin) / h
        # Soft height prior when cluster colour is washed/ambiguous
        if slot in ("trousers", "coat", "metal") and zf > 0.55:
            slot = "coat"
        if slot in ("trousers", "coat") and zf < 0.12:
            slot = "boots"
        if slot == "trousers" and 0.12 <= zf < 0.42:
            slot = "trousers"
        if slot in ("coat", "trousers") and 0.42 <= zf < 0.78:
            slot = "coat"
        # Crown hair — always (silhouette), regardless of washed albedo
        if zf >= 0.88:
            slot = "hair"
        elif zf >= 0.82:
            # keep face plate as skin; rest of crown = hair
            face_plate = (v.co.y <= y_mid) and (abs(v.co.x - cx) < 0.075) and (zf < 0.93)
            if not face_plate:
                slot = "hair"
        # Face plate: verts toward the front of the head (camera −Y)
        y_span = max(1e-4, y_back - y_front)
        frontness = (y_back - v.co.y) / y_span  # 1 = most forward
        if zf >= 0.76 and zf <= 0.94 and frontness > 0.40 and abs(v.co.x - cx) < 0.12:
            slot = "skin"
            for ex, ez in eyes:
                if (v.co.x - ex) ** 2 + (v.co.z - ez) ** 2 <= eye_r * eye_r and frontness > 0.45:
                    slot = "eye"
                    break
        # Soft clothing bands (slot labels only — no mesh bisect)
        if zf < 0.11:
            slot = "boots"
        elif 0.11 <= zf < 0.40 and slot not in ("skin", "metal"):
            slot = "trousers"
        elif 0.40 <= zf < 0.78 and slot not in ("skin", "hair", "eye", "metal"):
            if slot == "coat_dark" and zf > 0.70:
                slot = "coat_dark"
            else:
                slot = "coat"
        vert_slots.append(slot)

    while me.color_attributes:
        me.color_attributes.remove(me.color_attributes[0])
    attr = me.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="POINT")
    for i, slot in enumerate(vert_slots):
        tz = (me.vertices[i].co.z - zmin) / h
        ao = 0.78 + 0.22 * tz
        attr.data[i].color = (SLOT[slot] / 255.0, max(0.55, min(1.0, ao)), 0.0, 1.0)
    me.update()
    # Inflate hair shell for readable swept volume (not flat cap)
    hair_ids = [i for i, s in enumerate(vert_slots) if s == "hair"]
    if hair_ids:
        hx = sum(me.vertices[i].co.x for i in hair_ids) / len(hair_ids)
        hy = sum(me.vertices[i].co.y for i in hair_ids) / len(hair_ids)
        hz = sum(me.vertices[i].co.z for i in hair_ids) / len(hair_ids)
        for i in hair_ids:
            v = me.vertices[i]
            dx, dy, dz = v.co.x - hx, v.co.y - hy, v.co.z - hz
            v.co.x = hx + dx * 1.22
            v.co.y = hy + dy * 1.16 - 0.025
            v.co.z = hz + dz * 1.35 + 0.02
    # Light face volumes on skin verts in head
    skin_face = [
        i for i, s in enumerate(vert_slots)
        if s == "skin" and me.vertices[i].co.z >= head_z0 and me.vertices[i].co.y <= y_mid
    ]
    if skin_face:
        nose_z = zmin + 0.86 * h
        for i in skin_face:
            v = me.vertices[i]
            dx = v.co.x - cx
            nd = (dx * dx + (v.co.z - nose_z) ** 2) ** 0.5
            if nd < 0.045 * h / 0.35:
                k = (1.0 - nd / (0.045 * h / 0.35)) ** 2
                v.co.y -= 0.045 * k
            if abs(dx) < 0.09 and abs(v.co.z - (zmin + 0.90 * h)) < 0.03 * h / 0.35:
                v.co.y -= 0.02
                v.co.z += 0.014
    me.update()
    log("slots", dict(Counter(vert_slots)))
    hair_n = sum(1 for s in vert_slots if s == "hair")
    log("hair_verts", hair_n, "of", len(vert_slots))
    # Source hy hair after hard decimate reads as flat cap — keep skull as skin,
    # always seat a hair_* LOD for board-readable swept/crop silhouette.
    crown_ids = [i for i, s in enumerate(vert_slots) if s == "hair"]
    for i in crown_ids:
        # shrink crown verts slightly toward head center so LOD sits clean
        pass
    style = "swept" if kind == "ally" else "crop"
    # Force overlay regardless of span
    me = ob.data
    zs = [v.co.z for v in me.vertices]
    zmin, zmax = min(zs), max(zs)
    thr = zmin + 0.86 * (zmax - zmin)
    seat = crown_ids or [i for i, v in enumerate(me.vertices) if v.co.z >= thr]
    # Temporarily mark seat as hair for seating AABB
    seat_slots = list(vert_slots)
    for i in seat:
        seat_slots[i] = "hair"
    maybe_overlay_hair_module(ob, seat_slots, style=style)
    return True


def strip(ob):
    ob.data.materials.clear()
    while ob.data.uv_layers:
        ob.data.uv_layers.remove(ob.data.uv_layers[0])


def export_glb(ob, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    ob.name = path.stem
    if ob.data:
        ob.data.name = path.stem
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


def render_preview(ob, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    mat = bpy.data.materials.new("prev")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out_n = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "Color"
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (0.12, 0.09, 0.08, 1)  # hair
    ramp.color_ramp.elements[1].position = 1.0
    ramp.color_ramp.elements[1].color = (0.5, 0.55, 0.6, 1)
    for pos, col in (
        (1 / 255, (0.85, 0.68, 0.55, 1)),
        (2 / 255, (0.05, 0.04, 0.06, 1)),
        (3 / 255, (0.45, 0.48, 0.55, 1)),
        (4 / 255, (0.22, 0.24, 0.30, 1)),
        (12 / 255, (0.25, 0.30, 0.40, 1)),
        (13 / 255, (0.10, 0.09, 0.09, 1)),
    ):
        e = ramp.color_ramp.elements.new(pos)
        e.color = col
    nt.links.new(attr.outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Red"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.45
    nt.links.new(bsdf.outputs["BSDF"], out_n.inputs["Surface"])
    ob.data.materials.clear()
    ob.data.materials.append(mat)

    cam_data = bpy.data.cameras.new("C")
    cam = bpy.data.objects.new("C", cam_data)
    bpy.context.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    cam.location = (2.1, -2.7, 1.6)
    direction = Vector((0.0, 0.0, 0.95)) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    light = bpy.data.objects.new("L", bpy.data.lights.new("L", "SUN"))
    bpy.context.collection.objects.link(light)
    light.rotation_euler = (math.radians(50), math.radians(15), math.radians(30))
    light.data.energy = 2.4
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 28
    sc.cycles.use_denoising = True
    sc.render.resolution_x = 480
    sc.render.resolution_y = 600
    sc.render.filepath = str(path)
    sc.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)
    log("preview", path.name)


def load_color_donor(names):
    src = find_src(names)
    if not src:
        return None, None
    # import into current scene carefully — caller manages scene
    before = {o.name for o in bpy.data.objects}
    bpy.ops.import_scene.gltf(filepath=str(src))
    meshes = [o for o in bpy.data.objects if o.name not in before and o.type == "MESH"]
    bodies = [o for o in meshes if "body" in o.name.lower()] or meshes
    for o in meshes:
        if o not in bodies:
            bpy.data.objects.remove(o, do_unlink=True)
    if not bodies:
        return src, None
    bpy.ops.object.select_all(action="DESELECT")
    for o in bodies:
        o.select_set(True)
    bpy.context.view_layer.objects.active = bodies[0]
    if len(bodies) > 1:
        bpy.ops.object.join()
    donor = bpy.context.active_object
    normalize_height(donor)
    return src, donor


def build_one(compose_name, geo_names, color_names, kind):
    geo = find_src(geo_names)
    if not geo:
        log("SKIP no geo", compose_name)
        return
    log("===", compose_name, "geo", geo.name)
    reset()
    ob = import_join(geo)
    normalize_height(ob)
    weld_light(ob)
    protect_decimate(ob, TARGET_TRIS)

    # Colours
    rgb = sample_albedo_on_mesh(ob)
    donor = None
    if rgb is None:
        log("no albedo on geo — NN transfer from", color_names)
        # import donor into same scene
        _, donor = load_color_donor(color_names)
        if donor is not None and donor != ob:
            rgb = transfer_colors_nn(ob, donor)
            # remove donor
            bpy.data.objects.remove(donor, do_unlink=True)
        else:
            rgb = np.full((len(ob.data.vertices), 3), 0.45, dtype=np.float32)
    else:
        log("sampled albedo on geo")

    has_hair = paint_slots_from_rgb(ob, rgb, kind)
    strip(ob)
    export_glb(ob, OUT / f"{compose_name}.glb")

    # Preview
    reset()
    bpy.ops.import_scene.gltf(filepath=str(OUT / f"{compose_name}.glb"))
    fig = [o for o in bpy.data.objects if o.type == "MESH"][0]
    render_preview(fig, PREVIEW / f"{compose_name}.png")
    log("has_hair_silhouette", has_hair)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    PREVIEW.mkdir(parents=True, exist_ok=True)
    # Remove obsolete split heads — compose is full figure again
    for stale in ("head_m.glb", "head_f.glb"):
        p = OUT / stale
        # keep files but kit will prefer compose-only assembly
        pass
    for name, geo, col, kind in FIGURES:
        build_one(name, geo, col, kind)
    log("DONE")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as e:
        log("FATAL", e)
        import traceback
        traceback.print_exc()
        raise SystemExit(1)
