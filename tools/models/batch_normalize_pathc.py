#!/usr/bin/env python3
"""Batch normalize Path C Hunyuan natives — NO reduce, NO Cycles re-render.

Height ~1.85m, feet z=0, face toward -Y. Same rules as
normalize_hunyuan_fullbody_board.py but skips review renders (PNGs already exist).
"""
from __future__ import annotations

import math
import os
import sys

import bpy
from mathutils import Vector

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


SRC = arg("src")
OUT = arg("out")
HEIGHT = float(arg("height", "1.85") or "1.85")
STEM = arg("stem", "figure")

if not SRC or not OUT:
    print("need --src and --out")
    sys.exit(2)

os.makedirs(os.path.dirname(OUT) or ".", exist_ok=True)


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


def export_glb(path: str, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
    )


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def main():
    reset_scene()
    bpy.ops.import_scene.gltf(filepath=SRC)
    mesh = join_meshes()
    tris_before = len(mesh.data.polygons)
    normalize_figure(mesh, HEIGHT)
    tris_after = len(mesh.data.polygons)
    if tris_after != tris_before:
        print("ABORT: triangle count changed — forbidden reduce leaked in")
        sys.exit(2)
    select_only(mesh)
    bpy.ops.object.shade_smooth()
    export_glb(OUT, [mesh])
    meta = os.path.join(os.path.dirname(OUT), f"{STEM}_META.txt")
    with open(meta, "w") as f:
        f.write("mode=normalize-only\n")
        f.write(f"stem={STEM}\n")
        f.write(f"src={SRC}\n")
        f.write(f"out={OUT}\n")
        f.write(f"tris_before={tris_before}\n")
        f.write(f"tris_after={tris_after}\n")
        f.write(f"bytes={os.path.getsize(OUT)}\n")
        f.write(f"height_target={HEIGHT}\n")
    print("DONE", STEM, "tris", tris_after, "bytes", os.path.getsize(OUT))


if __name__ == "__main__":
    main()
