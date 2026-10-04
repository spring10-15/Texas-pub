"""Re-export the editable route kit with detachable storeroom/lift decorations."""
import bpy,json
from pathlib import Path
HERE=Path(__file__).resolve().parent
DEST=HERE.parents[2]/'Godot/three_d/assets/tavern-routes.glb'
STORE_PARTS=('Lift guide rail','Lift gate','Lift stone jamb','Lift cable','Lift call','Crate slat','Crate nail')
def export_routes():
 collection=bpy.data.collections['TavernRouteDetail']
 objects=[o for o in collection.objects if o.type=='MESH']
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.convert(target='MESH')
 triangles=sum((o.data.calc_loop_triangles() or len(o.data.loop_triangles)) for o in objects)
 groups={}
 for o in objects:
  key=('store_' if o.name.startswith(STORE_PARTS) else '')+o.data.materials[0].name
  groups.setdefault(key,[]).append(o)
 store=bpy.data.objects.new('StoreDetails',None);collection.objects.link(store)
 for key,parts in groups.items():
  bpy.ops.object.select_all(action='DESELECT')
  for o in parts:o.select_set(True)
  bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();o=bpy.context.object;o.name='Route_'+key
  if key.startswith('store_'):o.parent=store
  bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 bpy.ops.object.select_all(action='DESELECT')
 for o in collection.objects:o.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(DEST),export_format='GLB',use_selection=True,export_cameras=False,export_lights=False,export_animations=False)
 DEST.with_suffix('.json').write_text(json.dumps({'asset':DEST.name,'source':'assets/blender/tavern-routes/tavern-routes.blend','decorative_only':True,'godot_local_meters':{'hall':[-4,4,-3.4,-14],'upper_kitchen_y':1.2,'quay_y':-1.3},'materials':sorted({o.data.materials[0].name for o in collection.objects if o.type=='MESH'}),'meshes':len(groups),'triangles':triangles,'bytes':DEST.stat().st_size},ensure_ascii=False,indent=2)+'\n');print('ROUTES_EXPORTED',triangles,len(groups))
if __name__=='__main__':
 bpy.ops.wm.open_mainfile(filepath=str(HERE/'tavern-routes.blend'))
 export_routes()
