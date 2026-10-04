"""Rooftop architectural sample. Godot meters, existing 6x7 room and exit anchors."""
import bpy, math, json
from pathlib import Path
OUT=Path(__file__).resolve().parent
DEST=OUT.parents[2]/'Godot/three_d/assets/rooftop-terrace.glb'
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene;scene.unit_settings.system='METRIC'
root=bpy.data.objects.new('RooftopTerrace',None);scene.collection.objects.link(root)
materials={}
for name,color,metal,rough in [('deck',(.18,.10,.048),0,.72),('steel',(.026,.035,.044),.8,.35),('stone',(.19,.22,.23),0,.87),('bulb',(.9,.55,.19),0,.3)]:
 m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 if name=='bulb':p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=2
 materials[name]=m
# Existing authored walnut maps; no image generation or external reference textures.
p=materials['deck'].node_tree.nodes.get('Principled BSDF');nodes=materials['deck'].node_tree.nodes;links=materials['deck'].node_tree.links
for channel,socket in [('color','Base Color'),('roughness','Roughness'),('normal','Normal')]:
 image=bpy.data.images.load(str(DEST.parent/'materials'/('walnut-'+channel+'.png')));image.pack()
 if channel!='color':image.colorspace_settings.name='Non-Color'
 tex=nodes.new('ShaderNodeTexImage');tex.image=image
 if channel=='normal':
  n=nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=.3;links.new(tex.outputs['Color'],n.inputs['Color']);links.new(n.outputs['Normal'],p.inputs[socket])
 else:links.new(tex.outputs['Color'],p.inputs[socket])
def box(name,pos,size,material,bevel=.005):
 # Author in Godot Y-up coordinates, convert to Blender Z-up before standard export.
 x,y,z=pos;dx,dy,dz=size
 bpy.ops.mesh.primitive_cube_add(size=1,location=(x,-z,y));o=bpy.context.object;o.name=name;o.parent=root;o.dimensions=(dx,dz,dy);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(materials[material])
 if bevel:b=o.modifiers.new('Rounded joinery','BEVEL');b.width=bevel;b.segments=2;o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
 return o
# Top of deck is exactly the existing y=0 walk plane, not a new collision floor.
for row in range(35):
 for segment in range(3):
  box('Deck plank',(-2+segment*2,-.009,-3.4+row*.2),(1.985,.018,.19),'deck',.002)
box('Front parapet footing',(0,.10,3.46),(6,.2,.16),'stone')
for x in [-2.95,-1.95,-.95,.05,1.05,2.05,2.95]:
 box('Front baluster',(x,.61,3.46),(.045,1.02,.045),'steel',.004)
for y in [.42,.76,1.12]:box('Front rail',(0,y,3.46),(5.94,.035,.035),'steel',.004)
# Clear the existing left door at z=1.65, width 1.05; keep exit-notice region readable.
for start,end in [(-3.45,1.05),(2.25,3.45)]:
 for y in [.42,.76,1.12]:box('Left rail',(-2.96,y,(start+end)/2),(.035,.035,end-start),'steel',.004)
 steps=math.ceil((end-start)/.75)
 for i in range(steps+1):box('Left baluster',(-2.96,.61,start+(end-start)*i/steps),(.045,1.02,.045),'steel',.004)
for z in [-1.3,2.55]:box('Fixture support',(-2.95,.95,z),(.07,1.9,.07),'steel',.008)
for x in [-2.85,2.85]:
 for z in [-3.25,3.25]:
  box('Lighting mast',(x,1.45,z),(.085,2.9,.085),'steel',.012)
  box('Mast foot',(x,.075,z),(.19,.15,.19),'stone',.01)
for z in [-3.25,3.25]:box('Open pergola beam',(0,2.88,z),(5.78,.09,.085),'steel',.008)
for i in range(13):
 x=-2.6+i*.43;y=2.74-.2*(1-(x/2.8)**2)
 box('Bulb cable segment',(x,y,3.25),(.44,.008,.008),'steel',0)
 bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=.035,location=(x,-3.25,y-.055));o=bpy.context.object;o.name='String bulb';o.parent=root;o.data.materials.append(materials['bulb'])
 for f in o.data.polygons:f.use_smooth=True
for x in [-1.9,1.9]:box('Rear stone trim',(x,.12,-3.4),(2,.24,.12),'stone',.008)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'rooftop-terrace.blend'))
bpy.ops.object.select_all(action='SELECT');bpy.context.view_layer.objects.active=next(o for o in bpy.data.objects if o.type=='MESH')
bpy.ops.object.convert(target='MESH')
triangles=sum((o.data.calc_loop_triangles() or len(o.data.loop_triangles)) for o in bpy.data.objects if o.type=='MESH')
for deck in [True,False]:
 bpy.ops.object.select_all(action='DESELECT')
 meshes=[o for o in bpy.data.objects if o.type=='MESH' and (o.data.materials[0].name=='deck')==deck]
 for o in meshes:o.select_set(True)
 bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.join();bpy.context.object.name='RooftopDeck' if deck else 'TerraceArchitecture'
bpy.ops.export_scene.gltf(filepath=str(DEST),export_format='GLB',export_animations=False,export_cameras=False,export_lights=False)
(OUT/'export-report.json').write_text(json.dumps({'triangles':triangles,'scope':'Architectural sample only. Existing rear/service walls and collisions retained at integration. No independent city backdrop yet.'},indent=2)+'\n')
print('ROOFTOP_EXPORTED',triangles)
