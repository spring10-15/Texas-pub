"""Terrace bar fitted to legacy counter, shop display and bartender handoff anchors."""
import bpy,json
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
DEST=OUT.parents[2]/'Godot/three_d/assets/rooftop-bar.glb'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.unit_settings.system='METRIC'
root=bpy.data.objects.new('RooftopBar',None);bpy.context.collection.objects.link(root)
materials={}
for name,color,metal,rough in [('steel',(.035,.045,.05),.75,.36),('brass',(.36,.22,.08),.8,.3),('stone',(.09,.105,.11),0,.45),('walnut',(.16,.075,.03),0,.6),('leather',(.06,.025,.012),0,.58)]:
 m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough;materials[name]=m
m=materials['walnut'];n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF')
for channel,socket in [('color','Base Color'),('normal','Normal'),('roughness','Roughness')]:
 image=bpy.data.images.load(str(DEST.parent/'materials'/f'walnut-{channel}.png'));image.pack()
 if channel!='color':image.colorspace_settings.name='Non-Color'
 tex=n.new('ShaderNodeTexImage');tex.image=image
 if channel=='normal':
  normal=n.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.25;l.new(tex.outputs['Color'],normal.inputs['Color']);l.new(normal.outputs['Normal'],p.inputs[socket])
 else:l.new(tex.outputs['Color'],p.inputs[socket])
def point(p):return Vector((p[0],-p[2],p[1]))
def put(o,name,material):o.name=name;o.parent=root;o.data.materials.append(materials[material]);return o
def box(name,p,size,material,bevel=.006):
 bpy.ops.mesh.primitive_cube_add(size=1,location=point(p));o=put(bpy.context.object,name,material);o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:b=o.modifiers.new('Crafted edge','BEVEL');b.width=bevel;b.segments=3;o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
 return o
def rod(name,a,b,r,material,vertices=20):
 a=point(a);b=point(b);v=b-a
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=v.length,location=(a+b)/2);o=put(bpy.context.object,name,material);o.rotation_euler=v.to_track_quat('Z','Y').to_euler()
 for face in o.data.polygons:face.use_smooth=len(face.vertices)==4
 return o
box('Stone service counter',(2,1.16,-1.25),(.86,.10,3),'stone',.022)
box('Walnut cabinet',(2,.57,-1.25),(.65,1.12,2.8),'walnut',.018)
for z in [-2.32,-1.62,-.92,-.22]:
 box('Recessed front panel',(1.663,.60,z),(.025,.68,.59),'walnut',.006)
 for dz in [-.315,.315]:box('Steel panel stile',(1.644,.6,z+dz),(.04,.84,.035),'steel',.003)
for y in [.16,1.02]:box('Panel frame',(1.644,y,-1.25),(.04,.035,2.84),'steel',.003)
rod('Brass foot rail',(1.45,.24,-2.6),(1.45,.24,.12),.027,'brass',32)
for z in [-2.3,-1.2,-.1]:rod('Foot rail bracket',(1.45,.24,z),(1.66,.24,z),.012,'steel')
# Stock models bottom at y=1.70 and center at x=2.55; shelf now supports them.
for y in [1.66,2.26]:box('Display shelf',(2.67,y,-1.2),(.42,.08,2.7),'walnut',.01)
for z in [-2.6,.2]:
 box('Shelf steel upright',(2.85,2.02,z),(.055,.93,.055),'steel',.005)
 for y in [1.62,2.22]:rod('Shelf bracket',(2.48,y,z),(2.85,y,z),.01,'steel')
# Keep display zones empty; actual stock, prices and hit targets come from BarDisplay.
for z in [-2.2,-1.2,-.2]:
 for dx in [-.13,.13]:
  for dz in [-.13,.13]:rod('Stool steel leg',(1.2+dx,.025,z+dz),(1.2+dx*.8,.71,z+dz*.8),.016,'steel')
 bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=.23,depth=.06,location=point((1.2,.725,z)));o=put(bpy.context.object,'Stool cushion','leather');b=o.modifiers.new('Soft seat edge','BEVEL');b.width=.01;b.segments=3;o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
 bpy.ops.mesh.primitive_torus_add(major_segments=48,minor_segments=8,major_radius=.18,minor_radius=.012,location=point((1.2,.25,z)));put(bpy.context.object,'Stool foot ring','brass')
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'rooftop-bar.blend'))
bpy.ops.object.select_all(action='SELECT');bpy.context.view_layer.objects.active=next(o for o in bpy.data.objects if o.type=='MESH');bpy.ops.object.convert(target='MESH')
triangles=sum((o.data.calc_loop_triangles() or len(o.data.loop_triangles)) for o in bpy.data.objects if o.type=='MESH')
for name in materials:
 bpy.ops.object.select_all(action='DESELECT');parts=[o for o in bpy.data.objects if o.type=='MESH' and o.data.materials[0].name==name]
 for o in parts:o.select_set(True)
 bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();bpy.context.object.name='TerraceBar_'+name;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.export_scene.gltf(filepath=str(DEST),export_format='GLB',export_animations=False,export_cameras=False,export_lights=False)
(OUT/'export-report.json').write_text(json.dumps({'triangles':triangles,'materials':5,'counter_top_y':1.21,'stock_shelf_top_y':1.70,'shelf_x_range':[2.46,2.88],'scope':'Static independent bar; stock, interaction, delivery animation and collisions remain owned by existing Godot systems. Final wear not finished.'},indent=2)+'\n');print('BAR_EXPORTED',triangles)
