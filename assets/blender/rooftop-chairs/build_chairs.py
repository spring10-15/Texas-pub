"""Terrace chairs fitted to existing seated roots and collision footprints."""
import bpy,json
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
DEST=OUT.parents[2]/'Godot/three_d/assets/rooftop-chairs.glb'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.unit_settings.system='METRIC'
root=bpy.data.objects.new('RooftopChairs',None);bpy.context.collection.objects.link(root)
materials={}
for name,color,metal,rough in [('steel',(.035,.045,.05),.75,.36),('brass',(.36,.22,.08),.8,.3),('rubber',(.02,.024,.025),0,.92),('leather',(.06,.025,.012),0,.58)]:
 m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough;materials[name]=m
m=materials['leather'];n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF')
for channel,socket in [('color','Base Color'),('normal','Normal'),('roughness','Roughness')]:
 image=bpy.data.images.load(str(DEST.parent/'materials'/f'leather-{channel}.png'));image.pack()
 if channel!='color':image.colorspace_settings.name='Non-Color'
 tex=n.new('ShaderNodeTexImage');tex.image=image
 if channel=='normal':
  normal=n.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.25;l.new(tex.outputs['Color'],normal.inputs['Color']);l.new(normal.outputs['Normal'],p.inputs[socket])
 else:l.new(tex.outputs['Color'],p.inputs[socket])
def point(p):return Vector((p[0],-p[2],p[1]))
def put(o,name,material):o.name=name;o.parent=root;o.data.materials.append(materials[material]);return o
def box(name,p,size,material,bevel=.006):
 bpy.ops.mesh.primitive_cube_add(size=1,location=point(p));o=put(bpy.context.object,name,material);o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:b=o.modifiers.new('Manufactured edges','BEVEL');b.width=bevel;b.segments=3;o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
 return o
def rod(name,a,b,r,material,vertices=16):
 a=point(a);b=point(b);v=b-a
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=v.length,location=(a+b)/2);o=put(bpy.context.object,name,material);o.rotation_euler=v.to_track_quat('Z','Y').to_euler()
 for face in o.data.polygons:face.use_smooth=len(face.vertices)==4
 return o
for x in [-1.1,.25]:
 z=-1.9
 # Seat top follows seated trouser bottom (~.43m), rather than old cushion's .511m.
 bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=.255,depth=.046,location=point((x,.407,z)));o=put(bpy.context.object,'Leather seat cushion','leather');b=o.modifiers.new('Soft cushion edge','BEVEL');b.width=.008;b.segments=3;o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
 for dx in [-.18,.18]:
  for dz in [-.17,.17]:
   rod('Splayed steel leg',(x+dx,.025,z+dz),(x+dx*.82,.382,z+dz*.82),.017,'steel')
   box('Rubber glider',(x+dx,.022,z+dz),(.055,.016,.055),'rubber',.006)
  rod('Side stretcher',(x+dx,.18,z-.17),(x+dx,.18,z+.17),.011,'steel')
 for dz in [-.17,.17]:rod('Cross stretcher',(x-.18,.18,z+dz),(x+.18,.18,z+dz),.011,'steel')
 for dx in [-.23,.23]:
  rod('Back upright',(x+dx,.35,z-.195),(x+dx,1.04,z-.225),.017,'steel')
  rod('Back fixing',(x+dx,.69,z-.2),(x+dx,.69,z-.218),.01,'brass',6)
  rod('Back fixing',(x+dx,.98,z-.2),(x+dx,.98,z-.218),.01,'brass',6)
 box('Upholstered back',(x,.835,z-.227),(.455,.38,.035),'leather',.014)
 rod('Top cross rail',(x-.23,1.04,z-.225),(x+.23,1.04,z-.225),.017,'steel')
 box('Underseat support',(x,.366,z),(.40,.03,.40),'steel',.012)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'rooftop-chairs.blend'))
bpy.ops.object.select_all(action='SELECT');bpy.context.view_layer.objects.active=next(o for o in bpy.data.objects if o.type=='MESH');bpy.ops.object.convert(target='MESH')
triangles=sum((o.data.calc_loop_triangles() or len(o.data.loop_triangles)) for o in bpy.data.objects if o.type=='MESH')
for name in materials:
 bpy.ops.object.select_all(action='DESELECT');parts=[o for o in bpy.data.objects if o.type=='MESH' and o.data.materials[0].name==name]
 for o in parts:o.select_set(True)
 bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();bpy.context.object.name='TerraceChairs_'+name;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.export_scene.gltf(filepath=str(DEST),export_format='GLB',export_animations=False,export_cameras=False,export_lights=False)
(OUT/'export-report.json').write_text(json.dumps({'triangles':triangles,'materials':4,'seat_top_y':.43,'back_top_y':1.057,'seat_centers':[[-1.1,-1.9],[.25,-1.9]],'scope':'Static paired chairs; collision and character roots unchanged. Final wear and character-motion fit remain separate gates.'},indent=2)+'\n');print('CHAIRS_EXPORTED',triangles)
