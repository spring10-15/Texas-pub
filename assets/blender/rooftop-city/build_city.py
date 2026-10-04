"""Deterministic nocturnal city backdrop, meter scale, no gameplay collisions."""
import bpy, math, json, random
from pathlib import Path
OUT=Path(__file__).resolve().parent
DEST=OUT.parents[2]/'Godot/three_d/assets/rooftop-city.glb'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.unit_settings.system='METRIC'
root=bpy.data.objects.new('CityBackdrop',None);bpy.context.collection.objects.link(root)
materials={}
for name,color,rough,emission in [('near-facade',(.055,.069,.078),.88,0),('far-facade',(.026,.042,.061),.92,0),('roof-metal',(.039,.044,.048),.48,0),('street',(.027,.034,.04),.95,0),('warm-window',(.48,.25,.085),.5,1.8),('cool-window',(.105,.22,.32),.5,.8)]:
 m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough
 if emission:p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emission
 materials[name]=m
counts={'buildings':0,'windows':0}
def box(name,pos,size,material):
 x,y,z=pos;dx,dy,dz=size
 bpy.ops.mesh.primitive_cube_add(size=1,location=(x,-z,y));o=bpy.context.object;o.name=name;o.parent=root;o.dimensions=(dx,dz,dy);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(materials[material]);return o
rng=random.Random(4104)
box('City street plane',(0,-18.2,0),(180,.2,180),'street')
# Three depth bands. Nearest architecture is outside every playable room footprint.
for row,(distance,spacing) in enumerate([(22,7),(43,10),(68,13)]):
 for i in range(-5,6):
  for side in ['front','west']:
   width=rng.uniform(4,6);depth=rng.uniform(4,6);height=rng.uniform(10,22) if row==0 else rng.uniform(16,31)
   x,z=(i*spacing,distance) if side=='front' else (-distance,i*spacing)
   if side=='west' and z < -8: continue
   counts['buildings']+=1
   material='near-facade' if row==0 else 'far-facade'
   box('Building shell',(x,-18+height/2,z),(width,height,depth),material)
   box('Roof cornice',(x,-18+height,z),(width+.15,.18,depth+.15),'roof-metal')
   box('Roof plant housing',(x+.35,-18+height+.42,z),(width*.32,.7,depth*.28),'roof-metal')
   if row==0:
    box('Vent riser',(x-width*.25,-18+height+.6,z+depth*.2),(.22,1.2,.22),'roof-metal')
   floors=int(height/2.4);columns=max(2,int(width/1.25))
   for floor in range(floors):
    for col in range(columns):
     if rng.random()>.32:continue
     y=-16.8+floor*2.4;offset=(col-(columns-1)/2)*1.2
     window_material='warm-window' if rng.random()<.8 else 'cool-window'
     if side=='front':pos,size=(x+offset,y,z-depth/2-.012),(.48,.85,.018)
     else:pos,size=(x+width/2+.012,y,z+offset),(.018,.85,.48)
     box('Lit recessed window',pos,size,window_material);counts['windows']+=1
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'rooftop-city.blend'))
for material in materials:
 bpy.ops.object.select_all(action='DESELECT');meshes=[o for o in bpy.data.objects if o.type=='MESH' and o.data.materials[0].name==material]
 if not meshes:continue
 for o in meshes:o.select_set(True)
 bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.join();bpy.context.object.name=material
triangles=sum((o.data.calc_loop_triangles() or len(o.data.loop_triangles)) for o in bpy.data.objects if o.type=='MESH')
bpy.ops.export_scene.gltf(filepath=str(DEST),export_format='GLB',export_animations=False,export_cameras=False,export_lights=False)
counts.update(triangles=triangles,materials=len(materials),seed=4104,scope='Background skyline only; no collision, independent traversable city or final facade textures.')
(OUT/'export-report.json').write_text(json.dumps(counts,indent=2)+'\n');print('CITY_EXPORTED',counts)
