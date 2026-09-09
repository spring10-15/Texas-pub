"""Editable near-field props using the existing, packed Blender material library."""
import bpy,math,json
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent;DEST=OUT.parents[2]/'Godot/three_d/assets'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'tavern-detail.blend'))
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
for c in list(bpy.data.collections):bpy.data.collections.remove(c)
scene=bpy.context.scene
ROOT=None;COL=None
M={n:bpy.data.materials[n] for n in ['walnut','leather','brass','ivory','dark','enamel','fabric','bottle']}
def xyz(p):return(p[0],-p[2],p[1])
def put(o,name,m):
 o.name=name;o.parent=ROOT
 for c in list(o.users_collection):c.objects.unlink(o)
 COL.objects.link(o);o.data.materials.append(M[m]);return o
def cube(name,p,d,m='brass',r=.004):
 bpy.ops.mesh.primitive_cube_add(size=1,location=xyz(p));o=put(bpy.context.object,name,m);o.dimensions=(d[0],d[2],d[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if r:mod=o.modifiers.new('Edge rounds','BEVEL');mod.width=r;mod.segments=3;o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
 return o
def rod(name,a,b,r,m='brass'):
 v=Vector(xyz(b))-Vector(xyz(a));bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=r,depth=v.length,location=(Vector(xyz(a))+Vector(xyz(b)))/2);o=put(bpy.context.object,name,m);o.rotation_euler=v.to_track_quat('Z','Y').to_euler();return o
def ring(name,p,r,t,m='brass',axis='Y'):
 bpy.ops.mesh.primitive_torus_add(major_segments=40,minor_segments=8,major_radius=r,minor_radius=t,location=xyz(p));o=put(bpy.context.object,name,m)
 if axis=='X':o.rotation_euler[1]=math.pi/2
 if axis=='Z':o.rotation_euler[0]=math.pi/2
 return o
def text(body,p,size,m='ivory',axis='X'):
 c=bpy.data.curves.new(body,'FONT');c.body=body;c.size=size;c.align_x='CENTER';c.align_y='CENTER';c.extrude=.0001;o=bpy.data.objects.new(body,c);COL.objects.link(o);o.parent=ROOT;o.location=xyz(p);c.materials.append(M[m])
 # Blender text faces +Z. Shelf fronts face -X; loose tokens face +Y in Godot.
 if axis=='X':o.rotation_euler=(math.pi/2,0,-math.pi/2)
 return o
def group(name):
 global ROOT,COL
 COL=bpy.data.collections.new(name);scene.collection.children.link(COL);ROOT=bpy.data.objects.new(name,None);COL.objects.link(ROOT)
group('marked-lens')
ring('Lens rim',(0,0,0),.051,.008,axis='X');rod('Smoked lens',(-.003,0,0),(.003,0,0),.044,'enamel');rod('Folded handle',(0,-.045,0),(0,-.12,0),.009,'dark');ring('Handle hinge',(0,-.055,0),.012,.003,axis='X')
group('signal-lighter')
cube('Lighter case',(0,-.015,0),(.043,.12,.083));cube('Hinged lid',(0,.058,0),(.043,.025,.083));cube('Lid seam',(-.023,.042,0),(.002,.002,.075),'dark',0);rod('Flint wheel',(-.012,.04,.017),(.012,.04,.017),.012,'dark');text('N',(-.025,-.01,0),.031,'dark')
group('sleeve-clip')
for z in [-.025,.025]:rod('Clip side',(0,-.06,z),(0,.06,z),.006)
rod('Clip bridge',(0,.06,-.025),(0,.06,.025),.006);rod('Inner tongue',(-.012,-.03,0),(-.012,.06,0),.006);ring('Spring',(0,.045,0),.018,.004,axis='X')
group('disposable-phone')
cube('Phone shell',(0,0,0),(.038,.205,.108),'dark',.014);cube('Display',(-.021,.047,0),(.003,.077,.085),'enamel',.003);text('01:49',(-.024,.05,0),.019)
for y in range(4):
 for z in range(3):cube('Key',(-.023,-.015-y*.019,-.025+z*.025),(.004,.011,.016),'ivory',.003)
rod('Antenna',(0,.09,.039),(0,.15,.039),.006,'dark')
group('player-notes')
cube('Paper block',(0,0,0),(.038,.18,.125),'ivory',.004)
for x in [-.025,.025]:cube('Leather cover',(x,0,0),(.008,.19,.135),'leather',.007)
cube('Book spine',(0,0,-.066),(.054,.19,.014),'leather',.006);text('NOTES',(-.031,.035,0),.02);text('NOIR',(-.031,-.045,0),.015)
for y in [-.081,.081]:cube('Foil rule',(-.03,y,0),(.002,.002,.11),'brass',0)
for name,label in [('kitchen-pass','KITCHEN'),('dock-passkey','DOCK')]:
 group(name);cube('Pass card',(0,0,0),(.008,.16,.105),'ivory',.006);cube('Printed band',(-.005,.045,0),(.002,.024,.095),'enamel',.002);text(label,(-.007,.006,0),.014,'dark');text('ADMIT ONE',(-.007,-.045,0),.008,'dark');ring('Eyelet',(0,.063,.035),.006,.0015,axis='X')
group('false-bottom-wallet')
for x in [-.012,.012]:cube('Leather fold',(x,0,0),(.014,.105,.15),'leather',.012)
cube('Fold seam',(0,-.047,0),(.035,.018,.15),'leather',.005)
for z in [-.065,.065]:
 for i in range(9):cube('Saddle stitch',(-.021,-.04+i*.01,z),(.001,.004,.001),'ivory',0)
text('N',(-.022,.017,0),.025,'brass')
group('steadying-drink')
rod('Bottle body',(0,-.10,0),(0,.07,0),.047,'bottle');rod('Bottle neck',(0,.07,0),(0,.15,0),.019,'bottle');rod('Cork',(0,.15,0),(0,.166,0),.02,'walnut');ring('Bottle shoulder',(0,.067,0),.032,.012,'bottle');cube('Paper label',(-.048,-.015,0),(.003,.09,.057),'ivory',.002);text('TONIC',(-.051,-.005,0),.011,'dark')
group('loose-card')
cube('Card stock',(0,0,0),(.12,.006,.18),'ivory',.0015);cube('Green reverse',(0,-.004,0),(.115,.001,.175),'enamel',.001)
text('A',(-.039,.004,-.06),.023,'dark','Y')
for x in [-.009,.009]:rod('Spade lobes',(x,.004,0),(x,.005,0),.013,'dark')
mesh=bpy.data.meshes.new('Spade point');mesh.from_pydata([xyz(p) for p in [(-.02,.005,0),(.02,.005,0),(0,.005,-.028)]],[],[(0,1,2)]);o=bpy.data.objects.new('Spade point',mesh);COL.objects.link(o);o.parent=ROOT;mesh.materials.append(M['dark'])
cube('Spade stem',(0,.005,.02),(.006,.001,.015),'dark',0)
for z in [-.06,-.03,0,.03,.06]:cube('Reverse emboss',(0,-.005,z),(.09,.001,.0015),'brass',0)
group('loose-chip')
rod('Token edge',(0,-.01,0),(0,.01,0),.064,'enamel');rod('Ivory inlay',(0,.01,0),(0,.013,0),.042,'ivory');ring('Token rim',(0,.013,0),.056,.003)
for i in range(8):
 a=i*math.pi/4;o=cube('Edge insert',(.055*math.cos(a),.014,.055*math.sin(a)),(.014,.004,.012),'ivory',.001);o.rotation_euler[2]=-a
text('25',(0,.014,0),.033,'dark','Y')
group('drawer')
cube('Drawer panel',(0,0,0),(.64,.32,.035),'walnut',.012);cube('Inset',(0,0,.023),(.53,.23,.017),'leather',.007)
for x in [-.09,.09]:rod('Handle mount',(x,0,.03),(x,0,.07),.013)
rod('Brass pull',(-.09,0,.074),(.09,0,.074),.012)
cube('Drawer bottom',(0,-.14,-.25),(.6,.025,.5),'walnut',.005)
for x in [-.29,.29]:cube('Drawer side',(x,-.055,-.25),(.023,.17,.5),'walnut',.004)
cube('Letter',(0,-.122,-.2),(.3,.008,.18),'ivory',.001)
bpy.context.preferences.filepaths.save_version=0;bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'interactive-props.blend'))
report={}
for col in list(bpy.data.collections):
 objects=[o for o in col.objects if o.type in ['MESH','FONT']]
 if not objects:continue
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.convert(target='MESH')
 # Keep a small number of material surfaces in a single mesh per movable prop.
 bpy.ops.object.join();obj=bpy.context.object;obj.name=col.name+'Mesh';obj.data.calc_loop_triangles();report[col.name]=len(obj.data.loop_triangles)
bpy.ops.export_scene.gltf(filepath=str(DEST/'interactive-props.glb'),export_format='GLB',export_animations=False,export_cameras=False,export_lights=False)
(DEST/'props-export.json').write_text(json.dumps(report,indent=2));print('PROPS_EXPORT_OK',report,flush=True)
