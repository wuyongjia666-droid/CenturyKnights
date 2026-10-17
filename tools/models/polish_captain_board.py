#!/usr/bin/env python3
"""SAFE polish for cast_leader__board after Hunyuan head attach.

ONLY:
  - Remap body albedo frost-white → cold grey (pixel remap / Principled tint)
  - Modest sword blade thicken (local thin-axis scale ~1.5–1.8x)
  - Optional tiny head sink into existing collar (transform only)

FORBIDDEN (broke v3):
  - Remesh / delete verts / raise collar verts destructively
  - Visible NeckPlug cylinder
  - Inflating sword into a plank
  - Touching head UV / topo / Hunyuan textures

blender --background --python tools/models/polish_captain_board.py -- \\
  [--src PATH] [--out PATH] [--render-dir DIR]
  [--coat-grey R,G,B] [--sword-thick F] [--head-seat F]
"""
from __future__ import annotations

import math
import os
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


SRC = arg("src", "/workspace/CenturyKnights/project/assets/models/units/cast_leader__board.glb")
OUT = arg("out", SRC)
RENDER_DIR = arg("render-dir", "/workspace/board_figure_p1_review/captain_v2/attached_v4")
COAT = arg("coat-grey", "70,74,88")
SWORD_THICK = float(arg("sword-thick", "1.65") or "1.65")  # modest
HEAD_SEAT = float(arg("head-seat", "0.012") or "0.012")  # tiny sink only
SKIP_SWORD = "--no-sword" in ARGV
SKIP_SEAT = "--no-seat" in ARGV

os.makedirs(RENDER_DIR, exist_ok=True)
coat_rgb = tuple(int(x) / 255.0 for x in COAT.split(","))


def select_only(ob):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob


def drop_ico():
    for o in list(bpy.data.objects):
        if o.type != "MESH":
            continue
        name = o.name.lower()
        if name.startswith("ico") or "plug" in name:
            print("REMOVING", o.name)
            bpy.data.objects.remove(o, do_unlink=True)


def recolor_body_albedo(body, target_rgb):
    """Pixel-remap frost whites toward cold grey. No mesh edits."""
    mat = body.data.materials[0] if body.data.materials else None
    if not mat or not mat.use_nodes:
        return
    img = None
    for n in mat.node_tree.nodes:
        if n.type == "TEX_IMAGE" and n.image:
            img = n.image
            break
    tr, tg, tb = target_rgb
    if img is None or not img.pixels:
        bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf:
            bsdf.inputs["Base Color"].default_value = (*target_rgb, 1.0)
        print("COAT: tinted Principled only (no image)")
        return
    px = list(img.pixels)
    changed = 0
    for i in range(0, len(px), 4):
        r, g, b = px[i], px[i + 1], px[i + 2]
        lum = 0.299 * r + 0.587 * g + 0.114 * b
        if lum < 0.09:
            continue
        # keep strong cyan trim, just cool slightly
        if b > r + 0.15 and b > 0.55:
            px[i] = r * 0.75 + 0.12
            px[i + 1] = g * 0.75 + 0.14
            px[i + 2] = b * 0.55 + 0.28
            changed += 1
            continue
        if lum >= 0.38:  # frost / mid coat
            t = min(0.88, 0.45 + (lum - 0.38) * 0.9)
            px[i] = r * (1 - t) + tr * t
            px[i + 1] = g * (1 - t) + tg * t
            px[i + 2] = min(1.0, b * (1 - t) + tb * t + 0.02)
            changed += 1
    img.pixels = px
    img.update()
    units = "/workspace/CenturyKnights/project/assets/models/units"
    out_tex = os.path.join(units, "cast_leader__board__albedo_coldgrey.png")
    img.filepath_raw = out_tex
    img.file_format = "PNG"
    img.save()
    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf:
        # slight cool multiply, not a flat grey wash
        bsdf.inputs["Base Color"].default_value = (0.92, 0.94, 1.0, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.70
    print(f"COAT remapped pixels={changed} -> {out_tex}")


def modest_sword_thicken(weapon, factor: float):
    """Scale only the thin local axis (Y on this asset), modest factor."""
    if factor <= 1.01:
        return
    factor = min(factor, 1.85)  # hard cap — never plank
    coords = [v.co.copy() for v in weapon.data.vertices]
    cy = sum(c.y for c in coords) / len(coords)
    yspan0 = max(c.y for c in coords) - min(c.y for c in coords)
    for v in weapon.data.vertices:
        v.co.y = cy + (v.co.y - cy) * factor
    weapon.data.update()
    coords = [v.co for v in weapon.data.vertices]
    yspan1 = max(c.y for c in coords) - min(c.y for c in coords)
    print(f"SWORD thin-axis {yspan0:.4f} -> {yspan1:.4f} (x{factor})")


def tiny_head_sink(head, seat: float):
    if seat <= 0:
        return
    seat = min(seat, 0.02)  # hard cap
    for v in head.data.vertices:
        v.co.z -= seat
    head.data.update()
    print(f"HEAD sink {seat}")


def export_glb(path, body, head, weapon, arm):
    bpy.ops.object.select_all(action="DESELECT")
    for o in (body, head, arm):
        o.select_set(True)
    if weapon:
        weapon.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_skins=True,
        export_animations=True,
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

    area("Key", 145, (1.6, -2.2, 2.4), 2.0)
    area("Fill", 48, (-2.0, -1.0, 1.8), 3.0)
    area("Rim", 65, (0.2, 2.5, 2.0), 2.0)
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


def render_view(path, cam, eye, target, res=(960, 1200), lens=50, samples=48):
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


def main():
    print("SAFE POLISH src=", SRC)
    print("coat", coat_rgb, "sword", SWORD_THICK, "seat", HEAD_SEAT)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SRC)
    drop_ico()

    body = next(o for o in bpy.data.objects if o.type == "MESH" and o.name.lower().startswith("body"))
    head = next(o for o in bpy.data.objects if o.type == "MESH" and "head" in o.name.lower())
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    weapon = next((o for o in bpy.data.objects if o.type == "MESH" and "weapon" in o.name.lower()), None)
    print("VERIFY body tris", len(body.data.polygons), "head tris", len(head.data.polygons),
          "weapon tris", len(weapon.data.polygons) if weapon else 0)

    recolor_body_albedo(body, coat_rgb)
    if weapon and not SKIP_SWORD:
        modest_sword_thicken(weapon, SWORD_THICK)
    if not SKIP_SEAT:
        tiny_head_sink(head, HEAD_SEAT)

    export_glb(OUT, body, head, weapon, arm)
    review = os.path.join(RENDER_DIR, "cast_leader_hunyuan_head__board.glb")
    if os.path.abspath(review) != os.path.abspath(OUT):
        export_glb(review, body, head, weapon, arm)

    cam = setup_world()
    hc = [head.matrix_world @ v.co for v in head.data.vertices]
    face_z = min(c.z for c in hc) + 0.45 * (max(c.z for c in hc) - min(c.z for c in hc))
    front_y = min(c.y for c in hc)
    target = Vector((0.0, -0.12, 1.15))
    render_view(os.path.join(RENDER_DIR, "figure_front.png"), cam, Vector((0, -2.7, 1.25)), target, samples=40)
    render_view(os.path.join(RENDER_DIR, "figure_35deg.png"), cam, Vector((1.55, -2.2, 1.3)), target, samples=40)
    # face
    cam.rotation_euler = Euler((math.radians(90), 0, 0), "XYZ")
    cam.location = Vector((0.0, front_y - 0.48, face_z))
    cam.data.lens = 90
    scene = bpy.context.scene
    scene.render.resolution_x = scene.render.resolution_y = 1024
    scene.cycles.samples = 56
    scene.render.filepath = os.path.join(RENDER_DIR, "face_closeup.png")
    bpy.ops.render.render(write_still=True)
    print("RENDER face_closeup")
    print("DONE SAFE POLISH")


if __name__ == "__main__":
    main()
