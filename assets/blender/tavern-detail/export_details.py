"""Export existing editable detail source without rebaking or changing textures."""
import bpy, json
from pathlib import Path
TABLE_PARTS=('Table apron','Padded rail','Green baize','Rail pin','Turned table pedestal','Pedestal foot','Table stretcher')
OUT=Path(__file__).resolve().parent
DEST=OUT.parents[2]/'Godot/three_d/assets'
def export_details(names=('TavernDetail','StashDetail')):
 report_path=DEST/'detail-export.json'
 reports=json.loads(report_path.read_text()) if report_path.exists() else {}
 for name in names:
  bpy.ops.object.select_all(action='DESELECT')
  objects=list(bpy.data.collections[name].objects)
  for o in objects:o.select_set(True)
  bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.convert(target='MESH')
  groups={}
  for o in bpy.data.collections[name].objects:
   key='floor' if name=='TavernDetail' and o.name.startswith('Oak floorboard') else o.data.materials[0].name
   if name=='TavernDetail' and o.name.startswith(TABLE_PARTS):key='table_'+o.data.materials[0].name
   groups.setdefault(key,[]).append(o)
  meshes=[]
  table=bpy.data.objects.new('TavernTable',None) if name=='TavernDetail' else None
  if table:bpy.data.collections[name].objects.link(table)
  for key,parts in groups.items():
   bpy.ops.object.select_all(action='DESELECT')
   for o in parts:o.select_set(True)
   bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();o=bpy.context.object
   o.name='TavernFloor' if key=='floor' else name+'_'+key
   if key.startswith('table_'):o.parent=table
   meshes.append(o)
  bpy.ops.object.select_all(action='DESELECT');triangles=0
  for o in meshes:o.select_set(True);o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles)
  if table:table.select_set(True)
  dest=DEST/('tavern-detail.glb' if name=='TavernDetail' else 'stash-room-detail.glb')
  bpy.ops.export_scene.gltf(filepath=str(dest),export_format='GLB',use_selection=True,export_cameras=False,export_lights=False,export_animations=False)
  reports[name]={'meshes':len(meshes),'triangles':triangles,'bytes':dest.stat().st_size}
 report_path.write_text(json.dumps(reports,indent=2)+'\n');print('DETAIL_EXPORT_OK',reports,flush=True)
if __name__=='__main__':
 bpy.ops.wm.open_mainfile(filepath=str(OUT/'tavern-detail.blend'))
 export_details(('TavernDetail',))
