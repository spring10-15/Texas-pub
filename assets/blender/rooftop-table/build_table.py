"""Independent terrace poker table; keep existing play surface and anchor dimensions."""
import bpy,bmesh,math,json
from pathlib import Path
OUT=Path(__file__).resolve().parent
DEST=OUT.parents[2]/'Godot/three_d/assets/rooftop-table.glb'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.unit_settings.system='METRIC'
root=bpy.data.objects.new('RooftopTable',None);bpy.context.collection.objects.link(root)
materials={}
for name,color,metal,rough in [('steel',(.035,.045,.05),.75,.36),('brass',(.36,.22,.08),.8,.3),('stitch',(.36,.28,.18),0,.88),('rubber',(.02,.024,.025),0,.92),('leather',(.06,.025,.012),0,.58),('fabric',(.018,.07,.04),0,.9)]:
 m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough;materials[name]=m
for name in ['leather','fabric']:
 m=materials[name];n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF')
 for channel,socket in [('color','Base Color'),('normal','Normal'),('roughness','Roughness')]:
  image=bpy.data.images.load(str(DEST.parent/'materials'/f'{name}-{channel}.png'));image.pack()
  if channel!='color':image.colorspace_settings.name='Non-Color'
  tex=n.new('ShaderNodeTexImage');tex.image=image
  if channel=='normal':
   normal=n.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.25;l.new(tex.outputs['Color'],normal.inputs['Color']);l.new(normal.outputs['Normal'],p.inputs[socket])
  else:l.new(tex.outputs['Color'],p.inputs[socket])
def point(p):return (p[0]-.45,-p[2]+.8,p[1])
def put(o,name,material):o.name=name;o.parent=root;o.data.materials.append(materials[material]);return o
def box(name,p,size,material,bevel=.006):
 bpy.ops.mesh.primitive_cube_add(size=1,location=point(p));o=put(bpy.context.object,name,material);o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:b=o.modifiers.new('Manufactured edges','BEVEL');b.width=bevel;b.segments=3;o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
 return o
def rod(name,a,b,r,material,vertices=12):
 from mathutils import Vector
 a=Vector(point(a));b=Vector(point(b));v=b-a
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=v.length,location=(a+b)/2);o=put(bpy.context.object,name,material);o.rotation_euler=v.to_track_quat('Z','Y').to_euler();return o
def contour(width,depth,radius):
 result=[]
 for cx,cz,start in [(width/2-radius,depth/2-radius,0),(-width/2+radius,depth/2-radius,90),(-width/2+radius,-depth/2+radius,180),(width/2-radius,-depth/2+radius,270)]:
  for i in range(17):
   a=math.radians(start+i*90/16);result.append((cx+radius*math.cos(a),cz+radius*math.sin(a)))
 return result
outer=contour(2.05,1.4,.14);inner=contour(1.79,1.14,.1);count=len(outer)
verts=[point((x,y,z)) for y in [.788,.852] for loop in [outer,inner] for x,z in loop];faces=[]
for i in range(count):
 j=(i+1)%count
 faces.extend([(i,j,count+j,count+i),(2*count+i,3*count+i,3*count+j,2*count+j),(i,2*count+i,2*count+j,j),(count+i,count+j,3*count+j,3*count+i)])
mesh=bpy.data.meshes.new('Padded perimeter');mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new('Stitched padded rail',mesh);bpy.context.collection.objects.link(o);put(o,o.name,'leather')
bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.cube_project(cube_size=1);bpy.ops.object.mode_set(mode='OBJECT')
b=o.modifiers.new('Soft leather seam','BEVEL');b.width=.008;b.segments=3;o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
panel=contour(1.79,1.14,.1);n=len(panel)
verts=[point((x,y,z)) for y in [.845,.857] for x,z in panel]
faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
mesh=bpy.data.meshes.new('Rounded baize');mesh.from_pydata(verts,[],faces);mesh.update()
o=bpy.data.objects.new('Baize playing surface',mesh);bpy.context.collection.objects.link(o);put(o,o.name,'fabric')
bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
uv=mesh.uv_layers.new()
for poly in mesh.polygons:
 for li in poly.loop_indices:
  vertex=mesh.vertices[mesh.loops[li].vertex_index].co;uv.data[li].uv=((vertex.x+.45)/1.79+.5,(-vertex.y+.8)/1.14+.5)
# Paired steel pedestals preserve legacy leg/foot positions and knee clearance.
for x in [-.62,.62]:
 box('Pedestal foot',(x,.07,0),(.18,.10,.86),'steel',.025)
 for z in [-.34,.34]:box('Rubber foot',(x,.024,z),(.16,.018,.14),'rubber',.004)
 box('Steel upright',(x,.40,0),(.10,.61,.10),'steel',.009)
 box('Top mounting plate',(x,.705,0),(.36,.035,.64),'steel',.008)
 for z in [-.23,.23]:
  for dx in [-.12,.12]:rod('Mounting bolt',(x+dx,.724,z),(x+dx,.735,z),.011,'brass',6)
rod('Cross brace',(-.62,.30,0),(.62,.30,0),.027,'steel',20)
for z in [-.54,.54]:box('Recessed apron',(0,.715,z),(1.94,.16,.045),'steel',.008)
for x in [-.91,.91]:box('Apron end',(x,.715,0),(.045,.16,1.12),'steel',.008)
# Small tangible stitches follow the rounded rail, entirely below live card bottoms.
stitches=contour(1.98,1.33,.13)
for i,(x,z) in enumerate(stitches):
 nx,nz=stitches[(i+1)%len(stitches)];length=math.hypot(nx-x,nz-z);segments=max(1,round(length/.025))
 for j in range(segments):
  t=(j+.3)/segments;u=(j+.7)/segments
  rod('Rail stitch',(x+(nx-x)*t,.852,z+(nz-z)*t),(x+(nx-x)*u,.852,z+(nz-z)*u),.0007,'stitch',8)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'rooftop-table.blend'))
bpy.ops.object.select_all(action='SELECT');bpy.context.view_layer.objects.active=next(o for o in bpy.data.objects if o.type=='MESH');bpy.ops.object.convert(target='MESH')
triangles=sum((o.data.calc_loop_triangles() or len(o.data.loop_triangles)) for o in bpy.data.objects if o.type=='MESH')
for name in materials:
 bpy.ops.object.select_all(action='DESELECT');parts=[o for o in bpy.data.objects if o.type=='MESH' and o.data.materials[0].name==name]
 for o in parts:o.select_set(True)
 bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();bpy.context.object.name='TerraceTable_'+name
bpy.ops.export_scene.gltf(filepath=str(DEST),export_format='GLB',export_animations=False,export_cameras=False,export_lights=False)
(OUT/'export-report.json').write_text(json.dumps({'triangles':triangles,'materials':len(materials),'felt_top_y':.857,'rail_top_y':.852,'width':2.05,'depth':1.4,'scope':'Independent static table. Existing chairs, bar and interactions retained; final bespoke wear not finished.'},indent=2)+'\n');print('TABLE_EXPORTED',triangles)
