"""Export the editable still-life into a grouped, metre-scale GLB for the first playable.
Does not overwrite the source blend. Uses baked detail tiles when available.
"""
import bpy, json
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
DEST=ROOT/'Godot/three_d/assets'
DEST.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(HERE/'stash-noir.blend'))
scene=bpy.context.scene
lid=bpy.data.objects.get('LID • rotate X to open / close')
keep=[]
for o in list(scene.objects):
    group=next((c.name[:2] for c in o.users_collection if c.name[:2].isdigit()),'00')
    if group not in ['01','02','03','04','05','06','07'] or o.name.startswith(('Saddle stitch','Desk wear','Cut paper layers')):
        bpy.data.objects.remove(o,do_unlink=True)
    else:keep.append(o)
# Material conversion: preserve authored image textures; use explicit PBR constants
# for procedural color inputs so the imported first playable never has missing maps.
for m in bpy.data.materials:
    if not m.use_nodes:continue
    p=m.node_tree.nodes.get('Principled BSDF')
    if not p:continue
    for link in list(p.inputs['Base Color'].links):
        if link.from_node.type!='TEX_IMAGE':
            m.node_tree.links.remove(link);p.inputs['Base Color'].default_value=m.diffuse_color
    for link in list(p.inputs['Normal'].links):m.node_tree.links.remove(link)
# Detail pass: use baked PBR tiles, leaving the editable still-life untouched.
tiles=DEST/'materials'
for m in bpy.data.materials:
    family=next((v for k,v in {'Walnut':'walnut','Oxblood':'leather','Blue charcoal':'plaster'}.items() if m.name.startswith(k)),None)
    if not family or not (tiles/(family+'-color.png')).exists():continue
    p=m.node_tree.nodes.get('Principled BSDF')
    for channel in ['color','roughness','normal']:
        t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(tiles/(family+'-'+channel+'.png')))
        if channel!='color':t.image.colorspace_settings.name='Non-Color'
        if channel=='normal':
            normal=m.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.4;m.node_tree.links.new(t.outputs['Color'],normal.inputs['Color']);m.node_tree.links.new(normal.outputs[0],p.inputs['Normal'])
        else:m.node_tree.links.new(t.outputs['Color'],p.inputs['Base Color' if channel=='color' else 'Roughness'])
# Curves, embossed text and bevels become ordinary exportable meshes.
bpy.ops.object.select_all(action='DESELECT')
geometry=[o for o in keep if o.type in {'MESH','CURVE','FONT'}]
for o in geometry:o.select_set(True)
bpy.context.view_layer.objects.active=geometry[0]
bpy.ops.object.convert(target='MESH')
parts={}
for o in list(scene.objects):
    if o.type!='MESH':continue
    key='CaseLid' if o.parent==lid else next((c.name[:2] for c in o.users_collection if c.name[:2].isdigit()),'Other')
    parts.setdefault(key,[]).append(o)
labels={'01':'Desk','02':'CaseBody','03':'Cash','04':'Chips','05':'Valuables','06':'Cards','07':'Lamp','CaseLid':'CaseLidMesh'}
for key,objects in parts.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join();bpy.context.object.name=labels[key]
# The source was a still render: tall chip/cash stacks pierced the closed lid.
# Compress their vertical packing around the tray floor for a usable hinge range.
for name in ['Cash','Chips']:
    obj=bpy.data.objects[name]
    inverse=obj.matrix_world.inverted()
    for vertex in obj.data.vertices:
        world=obj.matrix_world @ vertex.co
        world.z=.30+(world.z-.30)*.70
        vertex.co=inverse @ world
lid.name='CaseLidPivot'
root=bpy.data.objects.new('StashAsset',None);scene.collection.objects.link(root)
for o in list(scene.objects):
    if o!=root and o.parent is None:o.parent=root
root.scale=(.26,.26,.26);root.location=(0,0,.82)
bpy.context.view_layer.update()
triangles=0
for o in scene.objects:
    if o.type=='MESH':
        o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles)
bpy.ops.export_scene.gltf(filepath=str(DEST/'stash.glb'),export_format='GLB',export_cameras=False,export_lights=False,export_animations=False)
report={'source':'stash-noir.blend','scale':.26,'tabletop_height_m':.82,'mesh_objects':sum(o.type=='MESH' for o in scene.objects),'triangles':triangles,'moving_pivot':'CaseLidPivot','material_status':'Image textures preserved; walnut, leather and plaster use baked 1024 PBR tiles','bytes':(DEST/'stash.glb').stat().st_size}
(DEST/'stash-export.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
print('EXPORT_OK',report,flush=True)
