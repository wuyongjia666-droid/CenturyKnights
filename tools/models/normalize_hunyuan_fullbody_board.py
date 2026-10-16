#!/usr/bin/env python3
"""Normalize Hunyuan FULL-BODY captain for board — NO mesh reduce.

Only: join meshes if needed, height ~1.85m, feet z=0, face toward -Y,
shade smooth, export GLB, render review PNGs.

ZERO COLLAPSE / DECIMATE / remesh / voxel. Triangle count must stay ≈ source.

blender --background --python tools/models/normalize_hunyuan_fullbody_board.py -- \\
  [--src PATH] [--out-board PATH] [--render-dir DIR] [--height F]
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
RENDER_DIR = arg(
    "render-dir",
    "/workspace/board_figure_p1_review/captain_v2/hunyuan_fullbody/board_ready_noreduce",
)
HEIGHT = float(arg("height", "1.85") or "1.85")
FACE_SRC_REF = arg(
    "face-src",
    "/workspace/board_figure_p1_review/captain_v2/hunyuan_fullbody/board_ready_v2/face_src.png",
)

os.makedirs(RENDER_DIR, exist_ok=True)
os.makedirs(os.path.dirname(OUT_BOARD) or ".", exist_ok=True)


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


def join_meshes():
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    if not meshes:
        raise RuntimeError("no mesh after import")
    if len(meshes) == 1:
        return meshes[0]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    return bpy.context.view_layer.objects.active


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


def render_view(path, cam, eye, target, res=(960, 1200), lens=50, samples=32):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    # Cap threads / tile to reduce peak RAM on large meshes
    scene.cycles.tile_size = 128
    cam.location = eye
    cam.data.lens = lens
    cam.rotation_euler = (target - eye).to_track_quat("-Z", "Y").to_euler()
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.filepath = path
    scene.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)
    print("RENDER", path)


def main():
    print("MODE normalize-only NO-REDUCE")
    print("SRC", SRC)
    print("OUT", OUT_BOARD)
    print("H", HEIGHT)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SRC)
    mesh = join_meshes()
    mesh.name = "Body"
    tris_before = len(mesh.data.polygons)
    print("IMPORT tris", tris_before, "uv", bool(mesh.data.uv_layers), "verts", len(mesh.data.vertices))

    normalize_figure(mesh, HEIGHT)
    tris_after = len(mesh.data.polygons)
    print("AFTER_NORMALIZE tris", tris_after)
    if abs(tris_after - tris_before) > 100:
        print("ABORT: triangle count changed — forbidden reduce leaked in")
        sys.exit(2)

    select_only(mesh)
    bpy.ops.object.shade_smooth()

    export_glb(OUT_BOARD, [mesh])
    review_board = os.path.join(RENDER_DIR, "cast_leader__board.glb")
    if os.path.abspath(review_board) != os.path.abspath(OUT_BOARD):
        shutil.copy2(OUT_BOARD, review_board)

    cam = setup_world()
    coords = world_coords(mesh)
    zmax = max(c.z for c in coords)
    target = Vector((0.0, 0.0, zmax * 0.55))
    face_z = zmax * 0.88
    front_y = min(c.y for c in coords)
    render_view(
        os.path.join(RENDER_DIR, "figure_front.png"),
        cam,
        Vector((0, -3.0, zmax * 0.55)),
        target,
        samples=28,
    )
    render_view(
        os.path.join(RENDER_DIR, "figure_35deg.png"),
        cam,
        Vector((1.7, -2.5, zmax * 0.58)),
        target,
        samples=28,
    )
    cam.rotation_euler = Euler((math.radians(90), 0, 0), "XYZ")
    cam.location = Vector((0.0, front_y - 0.55, face_z))
    cam.data.lens = 85
    scene = bpy.context.scene
    scene.render.resolution_x = scene.render.resolution_y = 1024
    scene.cycles.samples = 40
    scene.render.filepath = os.path.join(RENDER_DIR, "face_closeup.png")
    bpy.ops.render.render(write_still=True)
    print("RENDER face_closeup")

    # Also extract face_src from this full mesh (same camera) for compare
    scene.render.filepath = os.path.join(RENDER_DIR, "face_src.png")
    bpy.ops.render.render(write_still=True)
    print("RENDER face_src (same as closeup on full-tris — identical source)")

    # Side-by-side vs board_ready_v2 face_src if present
    ref = FACE_SRC_REF
    if ref and os.path.isfile(ref):
        try:
            import numpy as np
            from PIL import Image

            a = Image.open(ref).convert("RGB").resize((512, 512))
            b = Image.open(os.path.join(RENDER_DIR, "face_closeup.png")).convert("RGB").resize((512, 512))
            canvas = Image.new("RGB", (1024 + 16, 512), (40, 40, 44))
            canvas.paste(a, (0, 0))
            canvas.paste(b, (512 + 16, 0))
            outp = os.path.join(RENDER_DIR, "compare_face_src_vs_board.png")
            canvas.save(outp)
            print("COMPARE wrote", outp)
        except Exception as e:
            print("COMPARE skip:", e)
    else:
        print("COMPARE skip: no face_src ref at", ref)

    meta = os.path.join(RENDER_DIR, "META.txt")
    with open(meta, "w") as f:
        f.write(f"mode=normalize-only\n")
        f.write(f"src={SRC}\n")
        f.write(f"out={OUT_BOARD}\n")
        f.write(f"tris_before={tris_before}\n")
        f.write(f"tris_after={tris_after}\n")
        f.write(f"bytes={os.path.getsize(OUT_BOARD)}\n")
        f.write(f"height_target={HEIGHT}\n")
    print("DONE tris", tris_after, "bytes", os.path.getsize(OUT_BOARD))


if __name__ == "__main__":
    main()
