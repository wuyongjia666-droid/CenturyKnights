#!/usr/bin/env python3
"""Soft-reduce Hunyuan FULL-BODY captain for board (keep UV/albedo).

LOD0 ~120–200k, board ~35–50k via multi-step collapse (NOT one-shot crush).
Normalize height to ~1.85m, feet z=0, face -Y.

blender --background --python tools/models/reduce_hunyuan_fullbody_board.py -- \\
  [--src PATH] [--out-board PATH] [--out-lod0 PATH] [--render-dir DIR]
  [--lod0-tris N] [--board-tris N] [--height F] [--tex-board N]
"""
from __future__ import annotations

import math
import os
import shutil
import sys

import bpy
from mathutils import Euler, Vector

ARGV = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []


def arg(name: str, default: str | None = None) -> str | None:
    key = f"--{name}"
    if key in ARGV:
        i = ARGV.index(key)
        return ARGV[i + 1] if i + 1 < len(ARGV) else default
    for a in ARGV:
        if a.startswith(key + "="):
            return a.split("=", 1)[1]
    return default


SRC = arg(
    "src",
    "/workspace/board_figure_p1_review/captain_v2/hunyuan_fullbody/captain_farm_front_fullbody.glb",
)
OUT_BOARD = arg(
    "out-board",
    "/workspace/CenturyKnights/project/assets/models/units/cast_leader__board.glb",
)
OUT_LOD0 = arg(
    "out-lod0",
    "/workspace/board_figure_p1_review/captain_v2/hunyuan_fullbody/board_ready/cast_leader_fullbody_lod0.glb",
)
RENDER_DIR = arg(
    "render-dir",
    "/workspace/board_figure_p1_review/captain_v2/hunyuan_fullbody/board_ready",
)
LOD0_TRIS = int(arg("lod0-tris", "140000") or "140000")
BOARD_TRIS = int(arg("board-tris", "38000") or "38000")
HEIGHT = float(arg("height", "1.85") or "1.85")
TEX_BOARD = int(arg("tex-board", "2048") or "2048")

os.makedirs(RENDER_DIR, exist_ok=True)
os.makedirs(os.path.dirname(OUT_BOARD) or ".", exist_ok=True)
os.makedirs(os.path.dirname(OUT_LOD0) or ".", exist_ok=True)


def select_only(ob):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob


def apply_xf(ob):
    select_only(ob)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def world_coords(ob):
    mw = ob.matrix_world
    return [mw @ v.co for v in ob.data.vertices]


def soft_collapse(ob, target_tris: int, label: str = ""):
    n = max(1, len(ob.data.polygons))
    if n <= target_tris:
        print(f"COLLAPSE {label}: already {n} <= {target_tris}")
        return
    # Multi-step — never jump below ~40% in one hit when source is huge
    while len(ob.data.polygons) > target_tris * 1.05:
        cur = len(ob.data.polygons)
        # geometric approach toward target
        if cur > target_tris * 4:
            aim = int(cur * 0.40)
        elif cur > target_tris * 2.2:
            aim = int(cur * 0.45)
        else:
            aim = target_tris
        aim = max(target_tris, aim)
        ratio = max(0.08, aim / float(cur))
        md = ob.modifiers.new(f"dec_{label}_{cur}", "DECIMATE")
        md.decimate_type = "COLLAPSE"
        md.ratio = min(0.95, ratio)
        md.use_collapse_triangulate = False  # preserve UV better
        select_only(ob)
        bpy.ops.object.modifier_apply(modifier=md.name)
        print(f"COLLAPSE {label}: {cur} -> {len(ob.data.polygons)} (ratio={md.ratio:.3f})")
        if len(ob.data.polygons) >= cur:
            print("WARN collapse stalled")
            break


def normalize_figure(ob, target_h: float):
    apply_xf(ob)
    coords = world_coords(ob)
    zmin = min(c.z for c in coords)
    zmax = max(c.z for c in coords)
    h = zmax - zmin
    scale = target_h / max(h, 1e-6)
    cx = sum(c.x for c in coords) / len(coords)
    cy = sum(c.y for c in coords) / len(coords)
    for v in ob.data.vertices:
        v.co.x = (v.co.x - cx) * scale
        v.co.y = (v.co.y - cy) * scale
        v.co.z = (v.co.z - zmin) * scale
    ob.data.update()
    apply_xf(ob)
    # Face toward -Y: more extent in -Y for front of face (upper body)
    coords = world_coords(ob)
    z0 = max(c.z for c in coords)
    band = [c for c in coords if c.z > z0 * 0.75]
    if band:
        cy = sum(c.y for c in band) / len(band)
        y_pos = max(c.y for c in band) - cy
        y_neg = cy - min(c.y for c in band)
        print(f"face y+={y_pos:.3f} y-={y_neg:.3f}")
        if y_pos > y_neg * 1.08:
            ob.rotation_euler[2] = math.pi
            apply_xf(ob)
            print("ROTATED 180 → face -Y")
    coords = world_coords(ob)
    print(
        f"NORMALIZED h={max(c.z for c in coords)-min(c.z for c in coords):.3f} "
        f"w={max(c.x for c in coords)-min(c.x for c in coords):.3f} tris={len(ob.data.polygons)}"
    )


def resize_images(max_side: int):
    for img in bpy.data.images:
        if img.size[0] <= 0:
            continue
        w, h = img.size[0], img.size[1]
        if max(w, h) > max_side:
            s = max_side / float(max(w, h))
            nw, nh = max(1, int(w * s)), max(1, int(h * s))
            print(f"RESIZE {img.name} {w}x{h} -> {nw}x{nh}")
            img.scale(nw, nh)


def export_glb(path, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        if o:
            o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=False,
        export_image_format="AUTO",
    )
    print("WROTE", path, os.path.getsize(path))


def setup_world():
    for o in list(bpy.data.objects):
        if o.type in {"LIGHT", "CAMERA"}:
            bpy.data.objects.remove(o, do_unlink=True)

    def area(name, energy, loc, size=2.0):
        light = bpy.data.lights.new(name, "AREA")
        light.energy = energy
        light.size = size
        ob = bpy.data.objects.new(name, light)
        ob.location = loc
        bpy.context.collection.objects.link(ob)

    area("Key", 150, (1.8, -2.4, 2.6), 2.2)
    area("Fill", 50, (-2.2, -1.2, 1.8), 3.0)
    area("Rim", 70, (0.3, 2.6, 2.0), 2.0)
    world = bpy.data.worlds.new("W")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.70, 0.72, 0.74, 1)
    bg.inputs[1].default_value = 0.85
    cam_data = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cam_data)
    bpy.context.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    return cam


def render_view(path, cam, eye, target, res=(960, 1200), lens=50, samples=44):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    cam.location = eye
    cam.data.lens = lens
    cam.rotation_euler = (target - eye).to_track_quat("-Z", "Y").to_euler()
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.filepath = path
    scene.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)
    print("RENDER", path)


def duplicate_mesh(ob, name):
    dup = ob.copy()
    dup.data = ob.data.copy()
    dup.name = name
    bpy.context.collection.objects.link(dup)
    return dup


def main():
    print("SRC", SRC)
    print("LOD0", LOD0_TRIS, "BOARD", BOARD_TRIS, "H", HEIGHT)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SRC)
    mesh = next(o for o in bpy.data.objects if o.type == "MESH")
    mesh.name = "Body"
    print("IMPORT tris", len(mesh.data.polygons), "uv", bool(mesh.data.uv_layers))

    normalize_figure(mesh, HEIGHT)

    # LOD0 soft reduce
    soft_collapse(mesh, LOD0_TRIS, "lod0")
    select_only(mesh)
    bpy.ops.object.shade_smooth()
    lod0_tris = len(mesh.data.polygons)
    print("LOD0_FINAL", lod0_tris)
    if lod0_tris < 80000:
        print("WARN LOD0 unexpectedly low — face risk")

    # Export LOD0 (full res textures kept)
    export_glb(OUT_LOD0, [mesh])
    review_lod0 = os.path.join(RENDER_DIR, "cast_leader_fullbody_lod0.glb")
    if os.path.abspath(review_lod0) != os.path.abspath(OUT_LOD0):
        shutil.copy2(OUT_LOD0, review_lod0)

    # Board: duplicate then reduce further + shrink tex
    board = duplicate_mesh(mesh, "BodyBoard")
    soft_collapse(board, BOARD_TRIS, "board")
    board_tris = len(board.data.polygons)
    print("BOARD_FINAL", board_tris)
    if board_tris < 25000:
        print("ABORT: board tris too low — face may crack; not claiming pass")
        # still export for inspection but flag
    resize_images(TEX_BOARD)
    select_only(board)
    bpy.ops.object.shade_smooth()

    # Hide LOD0 for board export
    mesh.hide_set(True)
    export_glb(OUT_BOARD, [board])
    review_board = os.path.join(RENDER_DIR, "cast_leader__board.glb")
    if os.path.abspath(review_board) != os.path.abspath(OUT_BOARD):
        shutil.copy2(OUT_BOARD, review_board)

    # Renders from board mesh
    mesh.hide_set(True)
    board.hide_set(False)
    cam = setup_world()
    coords = world_coords(board)
    zmax = max(c.z for c in coords)
    target = Vector((0.0, 0.0, zmax * 0.55))
    face_z = zmax * 0.88
    front_y = min(c.y for c in coords)
    render_view(os.path.join(RENDER_DIR, "figure_front.png"), cam, Vector((0, -3.0, zmax * 0.55)), target, samples=40)
    render_view(os.path.join(RENDER_DIR, "figure_35deg.png"), cam, Vector((1.7, -2.5, zmax * 0.58)), target, samples=40)
    # face closeup
    cam.rotation_euler = Euler((math.radians(90), 0, 0), "XYZ")
    cam.location = Vector((0.0, front_y - 0.55, face_z))
    cam.data.lens = 85
    scene = bpy.context.scene
    scene.render.resolution_x = scene.render.resolution_y = 1024
    scene.cycles.samples = 56
    scene.render.filepath = os.path.join(RENDER_DIR, "face_closeup.png")
    bpy.ops.render.render(write_still=True)
    print("RENDER face_closeup")

    # Also render LOD0 face for quality compare
    board.hide_set(True)
    mesh.hide_set(False)
    coords = world_coords(mesh)
    face_z = max(c.z for c in coords) * 0.88
    front_y = min(c.y for c in coords)
    cam.location = Vector((0.0, front_y - 0.55, face_z))
    scene.render.filepath = os.path.join(RENDER_DIR, "face_closeup_lod0.png")
    bpy.ops.render.render(write_still=True)
    print("RENDER face_closeup_lod0")

    print("DONE lod0", lod0_tris, "board", board_tris)


if __name__ == "__main__":
    main()
