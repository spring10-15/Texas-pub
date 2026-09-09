"""Self-authored Blender detail kit and baked PBR tiles; no generated reference images.
Run Blender --background --python this_file. Godot units remain metres.
"""
import bpy, math, json, random, shutil
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[2]
DEST=ROOT/'Godot/three_d/assets'
TEX=OUT/'textures'
random.seed(91)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=8
scene.render.bake.margin=8
specs={
 'walnut':((.06,.024,.009),(.20,.095,.037),(3,75,2),.46,.025),
 'leather':((.035,.012,.008),(.13,.045,.023),(180,180,180),.58,.008),
 'fabric':((.013,.048,.03),(.035,.12,.065),(230,230,230),.92,.003),
 'plaster':((.025,.032,.029),(.08,.095,.084),(8,8,8),.95,.022)}
materials={}
for name,(a,b,scale,rough,bump) in specs.items():
 m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*b,1)
 n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF')
 uv=n.new('ShaderNodeTexCoord');v=n.new('ShaderNodeVectorMath');v.operation='MULTIPLY';v.inputs[1].default_value=scale;l.new(uv.outputs['UV'],v.inputs[0])
 noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=1;noise.inputs['Detail'].default_value=4;l.new(v.outputs[0],noise.inputs['Vector'])
 ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].color=(*a,1);ramp.color_ramp.elements[1].color=(*b,1);l.new(noise.outputs['Fac'],ramp.inputs[0]);l.new(ramp.outputs[0],p.inputs['Base Color'])
 p.inputs['Roughness'].default_value=rough
 bumpnode=n.new('ShaderNodeBump');bumpnode.inputs['Distance'].default_value=bump;bumpnode.inputs['Strength'].default_value=.4;l.new(noise.outputs['Fac'],bumpnode.inputs['Height']);l.new(bumpnode.outputs[0],p.inputs['Normal'])
 bpy.ops.mesh.primitive_plane_add(size=2);plane=bpy.context.object;plane.data.materials.append(m)
 for channel,kind in [('color','DIFFUSE'),('normal','NORMAL'),('roughness','ROUGHNESS')]:
  img=bpy.data.images.new(f'{name}-{channel}',1024,1024,alpha=False)
  if channel!='color':img.colorspace_settings.name='Non-Color'
  target=n.new('ShaderNodeTexImage');target.image=img;n.active=target
  if kind=='DIFFUSE':scene.render.bake.use_pass_direct=False;scene.render.bake.use_pass_indirect=False;scene.render.bake.use_pass_color=True
  bpy.ops.object.bake(type=kind)
  img.filepath_raw=str(TEX/f'{name}-{channel}.png');img.file_format='PNG';img.save()
  n.remove(target)
 bpy.data.objects.remove(plane,do_unlink=True)
 # Runtime material contains only image maps and standard glTF PBR nodes.
 n.clear();p=n.new('ShaderNodeBsdfPrincipled');p.inputs['Roughness'].default_value=1;output=n.new('ShaderNodeOutputMaterial');l.new(p.outputs[0],output.inputs['Surface'])
 for channel in ['color','normal','roughness']:
  t=n.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(TEX/f'{name}-{channel}.png'))
  if channel!='color':t.image.colorspace_settings.name='Non-Color'
  if channel=='normal':
   normal=n.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.3;l.new(t.outputs['Color'],normal.inputs['Color']);l.new(normal.outputs[0],p.inputs['Normal'])
  else:l.new(t.outputs['Color'],p.inputs['Base Color' if channel=='color' else 'Roughness'])
 materials[name]=m
 print('BAKED',name,flush=True)
def mat(name,color,metal=0,rough=.5):
 m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*color,1);p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough;materials[name]=m;return m
mat('brass',(.38,.24,.08),.8,.28);mat('enamel',(.018,.085,.035),.3,.24);mat('ivory',(.68,.59,.4),0,.58);mat('dark',(.016,.019,.018),.5,.36);mat('bottle',(.02,.055,.025),.15,.2)
COL=None
# Coordinates below follow Godot (Y up, forward -Z); conversion happens once here.
def xyz(p):return (p[0],-p[2],p[1])
def put(o,name,material):
 o.name=name
 for c in list(o.users_collection):c.objects.unlink(o)
 COL.objects.link(o);o.data.materials.append(materials[material]);return o
def cube(name,p,d,m='walnut',bevel=.008):
 bpy.ops.mesh.primitive_cube_add(size=1,location=xyz(p));o=put(bpy.context.object,name,m);o.dimensions=(d[0],d[2],d[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  mod=o.modifiers.new('Crafted edges','BEVEL');mod.width=bevel;mod.segments=3;o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
 return o
def lathe(name,p,profile,m,segments=32):
 verts=[];faces=[]
 for y,r in profile:
  for i in range(segments):
   angle=i*2*math.pi/segments;verts.append((r*math.cos(angle),r*math.sin(angle),y))
 for j in range(len(profile)-1):
  for i in range(segments):a=j*segments+i;b=j*segments+(i+1)%segments;faces.append((a,b,b+segments,a+segments))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);COL.objects.link(o);o.location=xyz(p);mesh.materials.append(materials[m]);mesh.uv_layers.new()
 for poly in mesh.polygons:
  poly.use_smooth=True
  for li,vi in zip(poly.loop_indices,poly.vertices):mesh.uv_layers[0].data[li].uv=(vi%segments/segments,vi//segments/(len(profile)-1))
 return o
def rod(name,a,b,r,m='brass'):
 v=Vector(xyz(b))-Vector(xyz(a));bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=r,depth=v.length,location=(Vector(xyz(a))+Vector(xyz(b)))/2);o=put(bpy.context.object,name,m);o.rotation_euler=v.to_track_quat('Z','Y').to_euler();return o
def floor_and_trim(stash=False):
 for row in range(25):
  x=-2.87+row*.239
  start=-3.49-(.695 if row%2 else 0)
  while start<3.49:
   a=max(-3.49,start);b=min(3.49,start+1.39)
   cube('Oak floorboard',(x,.007,(a+b)/2),(.234,.014,b-a-.008),bevel=.002)
   start+=1.39
 # Wall panels follow existing door/window openings, never across an interaction point.
 for side in [-1,1]:
  for j in range(14):
   z=-3.25+j*.48
   if .95<z<2.3:continue
   if stash and side==1 and -2.45<z<-.4:continue
   cube('Wainscot field',(side*2.885,.5,z),(.035,.84,.43),bevel=.004)
   for yy in [.10,.93]:cube('Panel moulding',(side*2.852,yy,z),(.055,.04,.45),bevel=.006)
   cube('Panel stile',(side*2.847,.5,z-.205),(.05,.86,.028),bevel=.004)
  for z,length in [(-1.55,3.4),(2.95,.75)]:
   if stash and side==1:continue
   cube('Dado rail',(side*2.84,1.0,z),(.09,.075,length),bevel=.014)
 for z in [-3.38,3.38]:
  for i in range(11):
   x=-2.65+i*.53
   if not stash and z<0 and abs(x)<1.0:continue
   cube('End panelling',(x,.48,z),(.50,.82,.035),bevel=.005)
   cube('End stile',(x-.24,.48,z+(.035 if z<0 else -.035)),(.025,.86,.045),bevel=.003)
   cube('End cap',(x,.94,z),(.52,.06,.085),bevel=.008)
 for x in [-2.83,2.83]:cube('Cornice',(x,2.89,0),(.13,.16,6.9),bevel=.015)
def table():
 cube('Table apron',(-.45,.715,-.8),(2.03,.19,1.39),bevel=.1)
 cube('Padded rail',(-.45,.82,-.8),(2.05,.064,1.4),'leather',.14)
 cube('Green baize',(-.45,.851,-.8),(1.77,.012,1.11),'fabric',.12)
 for x in [-1.35,.45]:
  for z in [-1.36,-.24]:lathe('Rail pin',(x,.855,z),[(0,.007),(.005,.007),(.007,0)],'brass',12)
 for x in [-1.07,.17]:
  lathe('Turned table pedestal',(x,.05,-.8),[(0,.18),(.05,.18),(.08,.11),(.2,.065),(.35,.09),(.42,.06),(.55,.08),(.64,.12)],'walnut')
  cube('Pedestal foot',(x,.07,-.8),(.18,.1,.86),bevel=.045)
 rod('Table stretcher',(-1.07,.29,-.8),(.17,.29,-.8),.025,'walnut')
def chair(x,z):
 lathe('Leather seat',(x,.43,z),[(0,0),(.0,.26),(.06,.26),(.08,.23),(.081,0)],'leather')
 for dx in [-.18,.18]:
  for dz in [-.17,.17]:rod('Chair leg',(x+dx,.03,z+dz),(x+dx*.9,.45,z+dz*.9),.023,'walnut')
 for dx in [-.23,.23]:rod('Chair back post',(x+dx,.42,z-.19),(x+dx,1.02,z-.23),.026,'walnut')
 cube('Carved chair crest',(x,1.01,z-.23),(.51,.10,.09),bevel=.045)
 for dx in [-.14,0,.14]:rod('Chair spindle',(x+dx,.49,z-.21),(x+dx,.99,z-.23),.012,'walnut')
def bar():
 cube('Polished counter',(2,1.16,-1.25),(.86,.1,3),'walnut',.038)
 cube('Paneled bar cabinet',(2,.57,-1.25),(.65,1.12,2.8),'walnut',.022)
 for z in [-2.32,-1.62,-.92,-.22]:
  cube('Bar inset',(1.658,.6,z),(.025,.67,.59),'leather',.018)
  for dz in [-.31,.31]:cube('Bar frame',(1.63,.6,z+dz),(.07,.84,.052),bevel=.008)
 for y in [.16,1.0]:cube('Bar rail',(1.625,y,-1.25),(.08,.07,2.84),bevel=.012)
 rod('Brass foot rail',(1.45,.24,-2.6),(1.45,.24,.12),.027)
 for z in [-2.2,-1.2,-.2]:
  for dx in [-.13,.13]:
   for dz in [-.13,.13]:rod('Stool leg',(1.2+dx,.02,z+dz),(1.2+dx*.8,.68,z+dz*.8),.019,'walnut')
  lathe('Stool cushion',(1.2,.68,z),[(0,0),(0,.23),(.06,.23),(.075,.21),(.075,0)],'leather')
  lathe('Stool foot ring',(1.2,.25,z),[(0,.18),(.026,.18),(.026,.16),(0,.16),(0,.18)],'brass')
 for y in [1.65,2.25]:
  cube('Display shelf',(2.77,y,-1.2),(.28,.08,2.7),bevel=.012)
  for i in range(8):
   z=-2.3+i*.3;h=.25+random.random()*.07
   lathe('Vintage bottle',(2.75,y+.045,z),[(0,0),(0,.052),(.015,.056),(h*.68,.056),(h*.80,.025),(h,.023),(h+.01,0)],'bottle',24)
   cube('Bottle label',(2.691,y+.15,z),(.002,.09,.072),'ivory',.0)
 for z in [-2.62,.25]:cube('Shelf pilaster',(2.68,1.99,z),(.27,.84,.085),bevel=.012)
 lathe('Whiskey tumbler',(1.9,1.215,-.15),[(0,0),(0,.043),(.11,.05),(.11,.041),(.02,.035),(.02,0)],'brass',24)
def pendant():
 lathe('Green pendant',(-.45,2.46,-.8),[(0,.28),(.025,.28),(.045,.25),(.16,.12),(.20,.06),(.25,.055)],'enamel',48)
 lathe('Ivory inner shade',(-.45,2.465,-.8),[(0,.265),(.035,.23),(.145,.11),(.18,.05)],'ivory',48)
 rod('Pendant stem',(-.45,2.69,-.8),(-.45,2.98,-.8),.012,'dark')
 lathe('Ceiling rose',(-.45,2.97,-.8),[(0,.08),(.035,.08),(.04,0)],'brass')
def group(name):
 global COL
 COL=bpy.data.collections.new(name);scene.collection.children.link(COL)
group('TavernDetail');floor_and_trim();table();bar();pendant();chair(-1.1,-1.9);chair(.25,-1.9)
group('StashDetail');floor_and_trim(True)
# Preserve editable separate objects in the source. Runtime meshes are joined by material.
bpy.context.preferences.filepaths.save_version=0
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'tavern-detail.blend'))
(DEST/'materials').mkdir(exist_ok=True)
for path in TEX.glob('*.png'):shutil.copy2(path,DEST/'materials'/path.name)
reports={}
for name in ['TavernDetail','StashDetail']:
 bpy.ops.object.select_all(action='DESELECT')
 objects=list(bpy.data.collections[name].objects)
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.convert(target='MESH')
 bymat={}
 for o in bpy.data.collections[name].objects:bymat.setdefault(o.data.materials[0].name,[]).append(o)
 meshes=[]
 for material,parts in bymat.items():
  bpy.ops.object.select_all(action='DESELECT')
  for o in parts:o.select_set(True)
  bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();o=bpy.context.object;o.name=name+'_'+material;meshes.append(o)
 bpy.ops.object.select_all(action='DESELECT')
 triangles=0
 for o in meshes:o.select_set(True);o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles)
 dest=DEST/('tavern-detail.glb' if name=='TavernDetail' else 'stash-room-detail.glb')
 bpy.ops.export_scene.gltf(filepath=str(dest),export_format='GLB',use_selection=True,export_cameras=False,export_lights=False,export_animations=False)
 reports[name]={'meshes':len(meshes),'triangles':triangles,'bytes':dest.stat().st_size}
(DEST/'detail-export.json').write_text(json.dumps(reports,indent=2))
print('DETAIL_EXPORT_OK',reports,flush=True)
