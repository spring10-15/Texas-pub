"""Independent rooftop service corridor and stair tower; visual geometry only."""
import bpy,json
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
DEST=OUT.parents[2]/'Godot/three_d/assets/rooftop-service.glb'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.unit_settings.system='METRIC'
root=bpy.data.objects.new('RooftopService',None);bpy.context.collection.objects.link(root)
mats={}
for name,color,metal,rough in [('plaster',(.14,.15,.16),0,.85),('steel',(.032,.043,.052),.75,.42),('stone',(.065,.08,.09),0,.72),('brass',(.36,.22,.08),.8,.35)]:
 m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough;mats[name]=m
m=mats['plaster'];n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF')
for channel,socket in [('color','Base Color'),('normal','Normal'),('roughness','Roughness')]:
 im=bpy.data.images.load(str(DEST.parent/'materials'/f'plaster-{channel}.png'));im.pack()
 if channel!='color':im.colorspace_settings.name='Non-Color'
 tex=n.new('ShaderNodeTexImage');tex.image=im
 if channel=='normal':
  normal=n.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.25;l.new(tex.outputs['Color'],normal.inputs['Color']);l.new(normal.outputs['Normal'],p.inputs[socket])
 else:l.new(tex.outputs['Color'],p.inputs[socket])
def point(p):return Vector((p[0],-p[2],p[1]))
def put(o,name,mat):o.name=name;o.parent=root;o.data.materials.append(mats[mat]);return o
def box(name,p,size,mat,bevel=.003):
 bpy.ops.mesh.primitive_cube_add(size=1,location=point(p));o=put(bpy.context.object,name,mat);o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:b=o.modifiers.new('Edge finish','BEVEL');b.width=bevel;b.segments=2;o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
 return o
def rod(name,a,b,r,mat='steel',vertices=16):
 a=point(a);b=point(b);v=b-a;bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=v.length,location=(a+b)/2);o=put(bpy.context.object,name,mat);o.rotation_euler=v.to_track_quat('Z','Y').to_euler()
 for f in o.data.polygons:f.use_smooth=len(f.vertices)==4
 return o
# Keep continuous floor support; shallow slab joints do not expose the background.
for name,p,size in [('Entry floor',(0,-.006,-4.7),(1.98,.04,2.6)),('Cross floor',(0,-.006,-7),(7.98,.04,1.98)),('Prep floor',(-2.75,-.006,-8.5),(2.48,.04,1)),('Upper landing',(-2.75,1.194,-12.5),(2.48,.04,1))]:box(name,p,size,'stone')
for x in [-.98,.98]:
 box('Entry wall',(x,1.5,-4.7),(.12,3,2.6),'plaster',.004)
 box('Entry skirting',(x*.92,.10,-4.7),(.035,.17,2.6),'steel')
for x in [-2.5,2.5]:box('Cross corridor wall',(x,1.5,-6),(3,3,.12),'plaster',.004)
for x in [-4,4]:box('Cross corridor end',(x,1.5,-7),(.12,3,2),'plaster',.004)
box('Stair outer wall',(-4,2,-10.5),(.12,4,5),'plaster',.004)
box('Upper exit wall',(-2.75,2.7,-13),(2.5,3,.12),'plaster',.004)
# Steel frames articulate the service entrance and upper door without blocking openings.
for x in [-.91,.91]:box('Service portal jamb',(x,1.45,-3.43),(.08,2.9,.10),'steel')
box('Service portal lintel',(0,2.9,-3.43),(1.9,.10,.10),'steel')
for x in [-3.39,-2.11]:box('Upper door jamb',(x,2.31,-12.75),(.07,2.24,.09),'steel')
box('Upper door lintel',(-2.75,3.43,-12.75),(1.35,.08,.09),'steel')
# Twelve solid treads follow the existing ramp. Top is 14mm above the collision stair.
for i in range(12):
 y=(i+1)*.1;z=-9.125-i*.25
 box('Steel stair tread',(-2.75,y-.016,z),(2.4,.06,.25),'steel')
 box('Stair riser',(-2.75,y-.05,z+.12),(2.39,.09,.012),'steel',.002)
 # Raised anti-slip ribs leave original brass nosings readable.
 for dz in [-.04,.035]:box('Grip strip',(-2.75,y+.016,z+dz),(2.10,.004,.012),'stone',.001)
for x in [-3.82,-1.68]:
 rod('Stair stringer',(x,.025,-9),(x,1.20,-12),.055)
 for i in range(7):
  z=-9-i*.5;y=i*.2
  rod('Handrail upright',(x,y+.025,z),(x,y+.88,z),.022)
 rod('Handrail',(x,.90,-9),(x,2.10,-12),.032)
# Wall-side utility runs and clamps stay outside the clear walking lanes.
for y in [2.25,2.40]:
 rod('Entry conduit',(.86,y,-3.5),(.86,y,-6),.012)
 for z in [-3.7,-4.7,-5.7]:box('Conduit saddle',(.875,y,z),(.03,.045,.04),'brass')
rod('Stair utility pipe',(-3.88,2.2,-8.05),(-3.88,3.4,-12.7),.028)
for z,y in [(-9,2.45),(-10.5,2.84),(-12,3.22)]:box('Pipe collar',(-3.88,y,z),(.07,.07,.04),'steel')
box('Vent frame',(.90,2.02,-5.25),(.045,.42,.65),'steel',.009)
for i in range(9):box('Vent blade',(.865,1.85+i*.038,-5.25),(.035,.015,.56),'brass',.001)
# Roof tower cap provides a silhouette above the terrace, with panel seams and flashings.
box('Tower roof',(-2.75,4.32,-12.5),(2.6,.10,1.15),'steel',.005)
for x in [-4.03,-1.47]:box('Roof flashing',(x,4.38,-12.5),(.045,.06,1.17),'steel')
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'rooftop-service.blend'))
bpy.ops.object.select_all(action='SELECT');bpy.context.view_layer.objects.active=next(o for o in bpy.data.objects if o.type=='MESH');bpy.ops.object.convert(target='MESH')
triangles=sum((o.data.calc_loop_triangles() or len(o.data.loop_triangles)) for o in bpy.data.objects if o.type=='MESH')
for name in mats:
 bpy.ops.object.select_all(action='DESELECT');parts=[o for o in bpy.data.objects if o.type=='MESH' and o.data.materials[0].name==name]
 for o in parts:o.select_set(True)
 bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();bpy.context.object.name='Service_'+name;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.export_scene.gltf(filepath=str(DEST),export_format='GLB',export_animations=False,export_cameras=False,export_lights=False)
(OUT/'export-report.json').write_text(json.dumps({'triangles':triangles,'materials':4,'stair_steps':12,'floor_top':.014,'landing_top':1.214,'scope':'Corridor and upper stair tower only; storeroom, loading wing and rooftop river relationship remain unfinished.'},indent=2)+'\n');print('SERVICE_EXPORTED',triangles)
