import bpy, sys, math, mathutils
glb, out = sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
sc=bpy.context.scene; sc.render.engine='CYCLES'; sc.cycles.samples=32; sc.cycles.device='CPU'
sc.render.resolution_x=768; sc.render.resolution_y=1024; sc.render.film_transparent=False
w=bpy.data.worlds.new("w"); sc.world=w; w.use_nodes=True; w.node_tree.nodes["Background"].inputs[0].default_value=(0.85,0.85,0.85,1); w.node_tree.nodes["Background"].inputs[1].default_value=1.0
sc.view_settings.view_transform='Standard'
l=bpy.data.objects.new("sun",bpy.data.lights.new("sun","SUN")); l.data.energy=2.5; l.rotation_euler=(math.radians(50),0,math.radians(-30)); sc.collection.objects.link(l)
cam=bpy.data.objects.new("cam",bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera=cam
def shot(name, ang, tgt, dist, lens):
    a=math.radians(ang); cam.data.lens=lens
    cam.location=mathutils.Vector((dist*math.sin(a), -dist*math.cos(a), tgt))
    cam.rotation_euler=(mathutils.Vector((0,0,tgt))-cam.location).to_track_quat('-Z','Y').to_euler()
    sc.render.filepath=out+"_"+name+".png"; bpy.ops.render.render(write_still=True)
shot("front",0,0.93,4.2,50); shot("35deg",35,0.93,4.2,50); shot("face",0,1.65,1.2,60)
