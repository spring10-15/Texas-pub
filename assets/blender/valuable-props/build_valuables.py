"""Ten rule-defined valuables. Meter scale, editable source, independent asset kit."""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
DEST=OUT.parents[2]/'Godot/three_d/assets'
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1
materials={}
for name,color,metal,rough in [('silver',(.55,.59,.62),1,.28),('gold',(.72,.46,.13),1,.25),('ivory',(.84,.78,.60),0,.34),('paper',(.70,.64,.48),0,.75),('ink',(.035,.025,.016),0,.7),('ruby',(.34,.012,.027),.15,.13),('emerald',(.018,.24,.12),.15,.15),('pearl',(.82,.79,.70),.12,.2),('obsidian',(.016,.022,.028),.25,.18),('wax',(.28,.024,.028),0,.36)]:
 m=bpy.data.materials.new(name);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 materials[name]=m
ROOT=None
COL=None
def group(id):
 global ROOT,COL
 COL=bpy.data.collections.new(id);scene.collection.children.link(COL)
 ROOT=bpy.data.objects.new(id,None);COL.objects.link(ROOT)
def put(o,name,material):
 o.name=name;o.parent=ROOT
 for c in list(o.users_collection):c.objects.unlink(o)
 COL.objects.link(o);o.data.materials.append(materials[material]);return o
def box(name,p,d,material,bevel=.001):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=put(bpy.context.object,name,material);o.dimensions=d
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  b=o.modifiers.new('Machined edge','BEVEL');b.width=bevel;b.segments=3;o.modifiers.new('Surface normals','WEIGHTED_NORMAL')
 return o
def disk(name,p,r,depth,material):
 bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=r,depth=depth,location=p);return put(bpy.context.object,name,material)
def ring(name,p,r,t,material):
 bpy.ops.mesh.primitive_torus_add(major_segments=64,minor_segments=8,major_radius=r,minor_radius=t,location=p);return put(bpy.context.object,name,material)
def sphere(name,p,r,material):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,radius=r,location=p);o=put(bpy.context.object,name,material)
 for f in o.data.polygons:f.use_smooth=True
 return o
def text(body,p,size,material='ink'):
 curve=bpy.data.curves.new(body,'FONT');curve.body=body;curve.size=size;curve.align_x='CENTER';curve.align_y='CENTER';curve.extrude=.00008
 o=bpy.data.objects.new(body,curve);COL.objects.link(o);o.parent=ROOT;o.location=p;curve.materials.append(materials[material]);return o
def gem(name,p,r,depth,material):
 bpy.ops.mesh.primitive_cone_add(vertices=8,radius1=r,radius2=r*.55,depth=depth,location=p);return put(bpy.context.object,name,material)
# Blender Z-up exports to Godot Y-up; all movable object roots are at origin.
group('old-silver-lighter')
box('Silver body',(0,0,.018),(.038,.013,.036),'silver',.002)
box('Hinged cap',(0,0,.043),(.038,.013,.013),'silver',.002)
box('Lid seam',(0,-.0067,.036),(.034,.0005,.0006),'ink',.0001)
for x in [-.012,0,.012]:box('Front engraving',(x,-.0068,.016),(.0005,.0003,.022),'gold',.0001)
wheel=disk('Flint wheel',(.009,0,.034),.004,.009,'silver');wheel.rotation_euler.x=math.pi/2
hinge=disk('Hinge',(-.019,0,.036),.0018,.01,'silver');hinge.rotation_euler.x=math.pi/2

group('ivory-chip')
disk('Ivory core',(0,0,.0017),.020,.0034,'ivory');ring('Gold perimeter',(0,0,.0035),.0176,.0007,'gold')
for i in range(8):
 a=i*math.tau/8;o=box('Edge insert',(.019*math.cos(a),.019*math.sin(a),.0017),(.005,.002,.0035),'ink',.0003);o.rotation_euler.z=a
text('IVORY',(0,.003,.0036),.0045);text('100',(0,-.004,.0036),.0055)

group('ruby-cufflink')
disk('Gold setting',(0,0,.004),.009,.003,'gold');gem('Ruby crown',(0,0,.007),.007,.005,'ruby');ring('Bezel',(0,0,.006),.0077,.0008,'gold')
box('Stem',(0,0,-.004),(.002,.002,.013),'gold',.0006);box('Toggle',(0,0,-.011),(.018,.004,.003),'gold',.001)

group('gold-cased-watch')
disk('Case',(0,0,.004),.024,.008,'gold');disk('Dial',(0,0,.0082),.021,.0005,'ivory');ring('Bezel',(0,0,.0085),.022,.001,'gold')
for i in range(12):
 a=i*math.tau/12;o=box('Hour marker',(.018*math.sin(a),.018*math.cos(a),.0087),(.0006,.0025,.0004),'ink',.0001);o.rotation_euler.z=-a
box('Minute hand',(0,.007,.009),(.0007,.016,.0005),'ink',.0001);o=box('Hour hand',(.004,.001,.0095),(.010,.0009,.0005),'ink',.0001);o.rotation_euler.z=.25
disk('Center pivot',(0,0,.010),.001,.001,'gold');ring('Bow',(0,.030,.004),.006,.0012,'gold');text('NOIR',(0,-.008,.0088),.003)

group('antique-coin')
disk('Coin',(0,0,.0014),.019,.0028,'gold');ring('Raised rim',(0,0,.0029),.0177,.0006,'gold')
for i in range(48):
 a=i*math.tau/48;box('Reeding',(.0189*math.cos(a),.0189*math.sin(a),.0014),(.0005,.0005,.002),'silver',.0001)
text('CITY',(0,.005,.003),.005);text('1927',(0,-.005,.003),.0045)

group('sealed-bond')
box('Folded certificate',(0,0,.001),(.15,.085,.002),'paper',.0005)
for y in [-.038,.038]:box('Border',(0,y,.0021),(.139,.0005,.0002),'ink',0)
for x in [-.07,.07]:box('Border',(x,0,.0021),(.0005,.076,.0002),'ink',0)
text('BEARER BOND',(0,.016,.0022),.009);text('CITY RESERVE',(0,-.001,.0022),.005)
for y in [-.012,-.018,-.024]:box('Printed rule',(-.02,y,.0021),(.082,.00035,.0002),'ink',0)
disk('Wax seal',(.050,-.022,.003),.009,.003,'wax');text('N',(.050,-.022,.0046),.009,'gold')

group('pearl-necklace')
for i in range(30):
 a=i*math.tau/30;p=(.057*math.cos(a),.073*math.sin(a),.0045);sphere('Pearl',p,.0045,'pearl')
ring('Clasp',(0,.073,.0045),.003,.0007,'gold')

group('emerald-brooch')
ring('Brooch frame',(0,0,.003),.014,.0013,'gold');gem('Emerald',(0,0,.006),.010,.008,'emerald')
for i in range(12):
 a=i*math.tau/12;sphere('Pearl surround',(.014*math.cos(a),.014*math.sin(a),.004),.0017,'pearl')
box('Pin',(0,0,-.001),(.028,.001,.001),'silver',.0002)

group('obsidian-idol')
disk('Pedestal',(0,0,.007),.025,.014,'obsidian');box('Body',(0,0,.045),(.027,.022,.058),'obsidian',.005)
sphere('Head',(0,0,.086),.017,'obsidian')
for x in [-.006,.006]:gem('Inlaid eyes',(x,-.014,.088),.002,.0015,'gold').rotation_euler.x=math.pi/2
for x in [-.018,.018]:box('Folded arm',(x,-.002,.052),(.012,.020,.032),'obsidian',.003)
box('Inscription plate',(0,-.025,.007),(.019,.001,.007),'gold',.0004)

group('vault-promissory')
box('Promissory paper',(0,0,.0006),(.135,.066,.0012),'paper',.0004)
text('VAULT PROMISSORY',(0,.013,.0013),.0065);text('PAYABLE ON DEMAND',(0,-.001,.0013),.004)
for y in [-.027,.027]:box('Foil border',(0,y,.0013),(.125,.0005,.00015),'gold',0)
for x in [-.061,.061]:box('Foil border',(x,0,.0013),(.0005,.054,.00015),'gold',0)
text('N 0019',(-.039,-.019,.0013),.004);text('CITY VAULT',(.035,-.019,.0013),.004)

bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'valuable-props.blend'))
report={}
for col in list(bpy.data.collections):
 objects=[o for o in col.objects if o.type in {'MESH','FONT'}]
 if not objects:continue
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.convert(target='MESH');bpy.ops.object.join()
 o=bpy.context.object;o.name=col.name+'Mesh';o.data.calc_loop_triangles();report[col.name]={'triangles':len(o.data.loop_triangles)}
bpy.ops.export_scene.gltf(filepath=str(DEST/'valuable-props.glb'),export_format='GLB',export_animations=False,export_cameras=False,export_lights=False)
(OUT/'export-report.json').write_text(json.dumps(report,indent=2)+'\n')
print('VALUABLE_PROPS_EXPORTED',report,flush=True)
