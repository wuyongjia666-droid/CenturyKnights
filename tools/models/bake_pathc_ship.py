import bpy, bmesh, json, sys
import sys
A=sys.argv[sys.argv.index("--")+1:]
SRC,OUT,TARGET=A[0],A[1],int(A[2]); VOX=1.85/400; RES=1024; STEM=OUT.split("/")[-1][:-4]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
hi=[o for o in bpy.data.objects if o.type=='MESH'][0]; hi.name="HI"
lo=hi.copy(); lo.data=hi.data.copy(); lo.name=STEM; bpy.context.collection.objects.link(lo)
lo.data.materials.clear()
for uv in list(lo.data.uv_layers): lo.data.uv_layers.remove(uv)
bpy.context.view_layer.objects.active=lo
m=lo.modifiers.new("vox","REMESH"); m.mode='VOXEL'; m.voxel_size=VOX; m.adaptivity=0
bpy.ops.object.select_all(action='DESELECT'); lo.select_set(True)
bpy.ops.object.modifier_apply(modifier="vox")
tris0=sum(len(p.vertices)-2 for p in lo.data.polygons); print("VOXTRIS",tris0)
d=lo.modifiers.new("dec","DECIMATE"); d.ratio=TARGET/tris0; d.use_collapse_triangulate=True
bpy.ops.object.modifier_apply(modifier="dec")
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.quads_convert_to_tris()
bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.003, scale_to_bounds=False)
bpy.ops.object.mode_set(mode='OBJECT')
# texel priority: head/face islands x2.2 (board readability lives in the face)
import bmesh
bm=bmesh.new(); bm.from_mesh(lo.data); uvl=bm.loops.layers.uv.active
mw=lo.matrix_world; HEAD=1.85*0.80
from collections import defaultdict
# island flood by shared UV
faces=list(bm.faces); seen=set()
for f in faces:
    if f.index in seen: continue
    stack=[f]; isl=[]; seen.add(f.index)
    while stack:
        g=stack.pop(); isl.append(g)
        for e in g.edges:
            if e.seam: continue
            for h in e.link_faces:
                if h.index in seen: continue
                # same island if uv continuous on this edge
                ok=True
                for v in e.verts:
                    a=[l[uvl].uv for l in g.loops if l.vert==v][0]; b=[l[uvl].uv for l in h.loops if l.vert==v][0]
                    if (a-b).length>1e-5: ok=False
                if ok: seen.add(h.index); stack.append(h)
    zc=sum((mw@f.calc_center_median()).z for f in isl)/len(isl)
    if zc>HEAD:
        cen=sum((l[uvl].uv for g in isl for l in g.loops), __import__('mathutils').Vector((0,0)))/sum(len(g.loops) for g in isl)
        for g in isl:
            for l in g.loops: l[uvl].uv=cen+(l[uvl].uv-cen)*2.2
bm.to_mesh(lo.data); bm.free()
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.select_all(action='SELECT')
bpy.ops.uv.pack_islands(rotate=True, margin=0.004)
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.shade_smooth()
tris=len(lo.data.polygons); print("TRIS",tris)
img=bpy.data.images.new(STEM+"_albedo",RES,RES)
mat=bpy.data.materials.new(STEM+"_pathc_ship"); mat.use_nodes=True
nt=mat.node_tree; tex=nt.nodes.new("ShaderNodeTexImage"); tex.image=img
nt.links.new(tex.outputs[0], nt.nodes["Principled BSDF"].inputs["Base Color"])
nt.nodes["Principled BSDF"].inputs["Roughness"].default_value=0.8
nt.nodes.active=tex; lo.data.materials.append(mat)
sc=bpy.context.scene; sc.render.engine='CYCLES'; sc.cycles.samples=4; sc.cycles.device='CPU'
bk=sc.render.bake; bk.use_selected_to_active=True; bk.use_cage=False; bk.cage_extrusion=0.02; bk.max_ray_distance=0.05; bk.margin=16
bk.use_pass_direct=False; bk.use_pass_indirect=False; bk.use_pass_color=True
bpy.ops.object.select_all(action='DESELECT'); hi.select_set(True); lo.select_set(True); bpy.context.view_layer.objects.active=lo
import numpy as np
def F(name):
    im=bpy.data.images.new(name,RES,RES,float_buffer=True); im.colorspace_settings.name="Non-Color"; return im
lo.visible_diffuse=False; lo.visible_glossy=False; lo.visible_shadow=False; lo.visible_transmission=False
# 1) albedo (diffuse color)
dimg=F("dif"); tex.image=dimg
bpy.ops.object.bake(type='DIFFUSE', pass_filter={'COLOR'})
dif=np.array(dimg.pixels[:]).reshape(RES,RES,4)
# 2) perceived look under uniform white sky (metal reads as metal)
w=bpy.data.worlds.new("w"); sc.world=w; w.use_nodes=True
w.node_tree.nodes["Background"].inputs[0].default_value=(1,1,1,1); w.node_tree.nodes["Background"].inputs[1].default_value=1.0
sc.cycles.samples=64; bk.use_pass_direct=True; bk.use_pass_indirect=True
cimg=F("comb"); tex.image=cimg
bpy.ops.object.bake(type='COMBINED')
comb=np.array(cimg.pixels[:]).reshape(RES,RES,4)
# 3) metallic mask
mimg=F("met"); tex.image=mimg
for m in hi.data.materials:
    t=m.node_tree; P=[n for n in t.nodes if n.type=='BSDF_PRINCIPLED'][0]; out=[n for n in t.nodes if n.type=='OUTPUT_MATERIAL'][0]
    em=t.nodes.new('ShaderNodeEmission')
    if P.inputs['Metallic'].links: t.links.new(P.inputs['Metallic'].links[0].from_socket, em.inputs[0])
    else: em.inputs[0].default_value=(0,0,0,1)
    t.links.new(em.outputs[0], out.inputs[0])
sc.cycles.samples=1
bpy.ops.object.bake(type='EMIT')
met=np.array(mimg.pixels[:]).reshape(RES,RES,4)[...,0]
k=2; pad=np.pad(met,k,mode='edge'); cs=pad.cumsum(0).cumsum(1); cs=np.pad(cs,((1,0),(1,0))); n=2*k+1
bl=(cs[n:,n:]-cs[:-n,n:]-cs[n:,:-n]+cs[:-n,:-n])/(n*n)
wm=np.clip((bl-0.5)/0.3,0,1); wm=(wm*wm*(3-2*wm))[...,None]
import copy
bpy.data.objects.remove(hi)
for SV in (0.0,0.5,1.0):
    outp=np.clip(dif[...,:3]*(1-wm*SV)+np.clip(comb[...,:3],0,1)*wm*SV,0,1)
    srgb=np.where(outp<=0.0031308,outp*12.92,1.055*np.power(outp,1/2.4)-0.055)
    img.scale(RES,RES)
    img.pixels[:]=np.concatenate([srgb,np.ones((RES,RES,1))],-1).ravel(); tex.image=img
    img.scale(512,512)
    bpy.ops.export_scene.gltf(filepath=OUT[:-4]+"__s%d.glb"%int(SV*10), export_format='GLB', export_image_format='JPEG', export_jpeg_quality=88, export_apply=True, export_materials='EXPORT', export_yup=True)
json.dump({"voxel_size":VOX,"vox_tris":tris0,"tris":tris},open(OUT[:-4]+"_stats.json","w"))
