"""Authored noir character foundations. Metres, articulated seated/standing rest poses.
Reference: existing tavern and poker scene plates. No generated reference imagery.
"""
import bpy, math, json
from mathutils import Vector
from pathlib import Path
OUT=Path(__file__).resolve().parent
DEST=OUT.parents[2]/'Godot/three_d/assets/characters';DEST.mkdir(parents=True,exist_ok=True)
CAST=[('dock-braggart',(.13,.085,.045),(.035,.023,.015),True,False),('ledger-clerk',(.045,.055,.065),(.08,.065,.045),False,False),('river-shark',(.055,.06,.053),(.25,.24,.20),True,False),('velvet-rook',(.09,.025,.038),(.022,.013,.01),False,False),('calm-widow',(.035,.03,.055),(.04,.02,.012),False,True),('smiling-knife',(.09,.095,.095),(.04,.025,.014),True,False),('house-viper',(.024,.065,.052),(.022,.02,.015),False,False),('ash-smuggler',(.115,.09,.075),(.14,.13,.12),True,False),('bartender',(.045,.042,.034),(.19,.18,.16),False,False)]
def xyz(p):return Vector((p[0],-p[2],p[1]))
def mat(name,color,metal=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=.68;p.inputs['Metallic'].default_value=metal;return m
def ell(name,p,r,m,bone):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=16,location=xyz(p));o=bpy.context.object;o.name=name;o.scale=(r[0],r[2],r[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(M[m]);g=o.vertex_groups.new(name=bone);g.add(list(range(len(o.data.vertices))),1,'REPLACE');PARTS.append(o)
 for f in o.data.polygons:f.use_smooth=True
 return o
def tube(name,points,radii,m,bones):
 vs=[];fs=[];n=16
 for j,p in enumerate(points):
  tangent=xyz(points[min(j+1,len(points)-1)])-xyz(points[max(0,j-1)]);q=tangent.to_track_quat('Z','Y')
  for i in range(n):
   a=i*2*math.pi/n;v=xyz(p)+q@Vector((radii[j]*math.cos(a),radii[j]*math.sin(a),0));vs.append(v)
 for j in range(len(points)-1):
  for i in range(n):fs.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
 fs.extend([tuple(reversed(range(n))),tuple(range((len(points)-1)*n,len(points)*n))]);mesh=bpy.data.meshes.new(name);mesh.from_pydata(vs,[],fs);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);mesh.materials.append(M[m]);PARTS.append(o)
 for j,b in enumerate(bones):
  g=o.vertex_groups.get(b) or o.vertex_groups.new(name=b);g.add(list(range(j*n,(j+1)*n)),1,'REPLACE')
 for f in mesh.polygons:f.use_smooth=True
 return o
def patch(name,points,m,bone):
 mesh=bpy.data.meshes.new(name);mesh.from_pydata([xyz(p) for p in points],[],[tuple(range(len(points)))]);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);mesh.materials.append(M[m]);g=o.vertex_groups.new(name=bone);g.add(list(range(len(points))),1,'REPLACE');PARTS.append(o)
summary={}
for idx,(name,suit,hair,hat,female) in enumerate(CAST):
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
 PARTS=[];standing=name=='bartender';lift=.35 if standing else 0
 M={'suit':mat('Wool',suit),'shirt':mat('Ivory cotton',(.58,.54,.43)),'skin':mat('Skin',(.38+idx*.008,.23+idx*.005,.15+idx*.004)),'hair':mat('Hair',hair),'shoe':mat('Polished leather',(.02,.018,.016)),'eye':mat('Eye white',(.65,.62,.53)),'iris':mat('Iris',(.06,.055,.037)),'lip':mat('Lips',(.23,.105,.08)),'metal':mat('Brass',(.43,.30,.12),.65)}
 # Bind skeleton matches seated anatomy. Root faces Godot +Z.
 J={'pelvis':((0,.54+lift,0),(0,.73+lift,0),None),'spine':((0,.73+lift,0),(0,1.03+lift,0),'pelvis'),'neck':((0,1.03+lift,0),(0,1.16+lift,0),'spine'),'head':((0,1.16+lift,0),(0,1.43+lift,0),'neck')}
 for side,sgn in [('L',-1),('R',1)]:
  shoulder=(sgn*.20,1.01+lift,0);elbow=(sgn*.25,.84+lift,.14);wrist=(sgn*.15,.90+lift,.38)
  J['upper_arm.'+side]=(shoulder,elbow,'spine');J['forearm.'+side]=(elbow,wrist,'upper_arm.'+side);J['hand.'+side]=(wrist,(sgn*.15,.89+lift,.48),'forearm.'+side)
  hip=(sgn*.105,.55+lift,0);knee=(sgn*.105,.46,.39 if not standing else .02);ankle=(sgn*.105,.10,.4 if not standing else .02)
  J['thigh.'+side]=(hip,knee,'pelvis');J['shin.'+side]=(knee,ankle,'thigh.'+side)
 arm=bpy.data.armatures.new('NoirSkeleton');rig=bpy.data.objects.new('CharacterRig',arm);bpy.context.collection.objects.link(rig);bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
 for b,(a,z,parent) in J.items():
  bone=arm.edit_bones.new(b);bone.head=xyz(a);bone.tail=xyz(z)
  if parent:bone.parent=arm.edit_bones[parent]
 bpy.ops.object.mode_set(mode='OBJECT');rig.select_set(False)
 ell('Jacket',(0,.82+lift,0),(.215 if not female else .18,.29,.125),'suit','spine');ell('Trousers',(0,.55+lift,0),(.17,.12,.135),'suit','pelvis')
 patch('Shirt front',[(-.09,1.05+lift,.105),(.09,1.05+lift,.105),(.055,.75+lift,.133),(-.055,.75+lift,.133)],'shirt','spine')
 for s in [-1,1]:patch('Notched lapel',[(s*.065,1.055+lift,.11),(s*.17,.99+lift,.10),(s*.095,.88+lift,.144),(s*.026,.79+lift,.145)],'suit','spine')
 patch('Tie',[(-.023,1.015+lift,.13),(.023,1.015+lift,.13),(.031,.83+lift,.145),(0,.79+lift,.15),(-.031,.83+lift,.145)],'hair','spine')
 for y in [.73,.80,.87]:ell('Vest button',(0,y+lift,.132),(.009,.009,.004),'metal','spine')
 tube('Neck',[(0,1.02+lift,0),(0,1.19+lift,0)],[.052,.06],'skin',['neck','head'])
 ell('Cranium',(0,1.30+lift,0),(.10 if female else .112,.145,.10),'skin','head');ell('Jaw',(0,1.205+lift,.025),(.074 if female else .09,.062,.077),'skin','head')
 ell('Nose bridge',(0,1.30+lift,.09),(.018,.048,.022),'skin','head');ell('Nose tip',(0,1.274+lift,.116),(.025,.018,.019),'skin','head')
 for s in [-1,1]:
  ell('Ear',(s*.11,1.29+lift,0),(.018,.036,.021),'skin','head');ell('Cheek',(s*.058,1.265+lift,.072),(.033,.026,.017),'skin','head');ell('Eye',(s*.044,1.327+lift,.086),(.025,.013,.014),'eye','head');ell('Iris',(s*.044,1.327+lift,.099),(.009,.01,.003),'iris','head')
  tube('Brow',[(s*.022,1.35+lift,.098),(s*.047,1.358+lift,.098),(s*.07,1.348+lift,.086)],[.005,.006,.003],'hair',['head']*3)
  tube('Lower eyelid',[(s*.022,1.317+lift,.095),(s*.047,1.311+lift,.098),(s*.068,1.319+lift,.09)],[.003,.003,.002],'skin',['head']*3)
 tube('Mouth',[(-.035,1.235+lift,.087),(0,1.231+lift,.099),(.035,1.235+lift,.087)],[.003,.004,.003],'lip',['head']*3)
 ell('Hair cap',(0,1.391+lift,-.014),(.108,.063,.098),'hair','head')
 if female:ell('Pinned hair',(0,1.31+lift,-.088),(.08,.10,.06),'hair','head')
 if hat:
  ell('Felt hat brim',(0,1.417+lift,0),(.17,.012,.15),'hair','head');ell('Hat crown',(0,1.46+lift,-.01),(.11,.062,.094),'suit','head')
 for side,sgn in [('L',-1),('R',1)]:
  upper='upper_arm.'+side;fore='forearm.'+side;hand='hand.'+side
  a,b,_=J[upper];c=J[fore][1]
  tube('Sleeve '+side,[a,tuple((a[i]+b[i])/2 for i in range(3)),b,tuple((b[i]+c[i])/2 for i in range(3)),c],[.08,.073,.062,.051,.038],'shirt' if standing else 'suit',[upper,upper,fore,fore,fore])
  ell('Cuff',(c[0],c[1],c[2]),(.044,.034,.035),'shirt',hand);ell('Palm',(c[0],c[1]-.006,c[2]+.043),(.041,.022,.059),'skin',hand)
  for finger in range(4):
   x=c[0]+(finger-1.5)*.018;length=[.063,.079,.074,.053][finger]
   tube('Finger '+str(finger),[(x,c[1]-.005,c[2]+.073),(x,c[1]-.01,c[2]+.10),(x,c[1]-.02,c[2]+.073+length)],[.009,.008,.006],'skin',[hand]*3)
  tube('Thumb',[(c[0]-sgn*.033,c[1],c[2]+.015),(c[0]-sgn*.052,c[1]-.008,c[2]+.047)],[.013,.009],'skin',[hand]*2)
  hip,knee,_=J['thigh.'+side];ankle=J['shin.'+side][1]
  tube('Trouser leg',[hip,knee,ankle],[.09,.075,.048],'suit',['thigh.'+side,'shin.'+side,'shin.'+side]);ell('Shoe',(ankle[0],.06,ankle[2]+.055),(.065,.055,.13),'shoe','shin.'+side)
 # Weld face volumes before export; ears/nose/chin remain part of a continuous surface.
 face=[o for o in PARTS if any(o.name.startswith(n) for n in ['Cranium','Jaw','Nose','Ear','Cheek'])]
 bpy.ops.object.select_all(action='DESELECT')
 for o in face:o.select_set(True)
 bpy.context.view_layer.objects.active=face[0];bpy.ops.object.join();head=face[0]
 PARTS=[o for o in PARTS if o not in face]+[head]
 rem=head.modifiers.new('Continuous facial volume','REMESH');rem.mode='VOXEL';rem.voxel_size=.003;rem.use_smooth_shade=True;bpy.ops.object.modifier_apply(modifier=rem.name)
 sm=head.modifiers.new('Surface relaxation','SMOOTH');sm.factor=.6;sm.iterations=5;bpy.ops.object.modifier_apply(modifier=sm.name)
 head.vertex_groups.clear();g=head.vertex_groups.new(name='head');g.add(list(range(len(head.data.vertices))),1,'REPLACE')
 # Project shirt panel onto the curved torso, avoiding intersections with jacket cloth.
 shirt=next(o for o in PARTS if o.name=='Shirt front');PARTS.remove(shirt);bpy.data.objects.remove(shirt,do_unlink=True)
 vs=[];fs=[]
 for j in range(9):
  y=.83+j*.025
  for i in range(5):
   x=(i-2)*.027;z=.125*math.sqrt(max(.01,1-(x/(.18 if female else .215))**2-((y-.82)/.29)**2))+.004
   vs.append(xyz((x,y+lift,z)))
 for j in range(8):
  for i in range(4):a=j*5+i;fs.append((a,a+1,a+6,a+5))
 mesh=bpy.data.meshes.new('Fitted shirt');mesh.from_pydata(vs,[],fs);mesh.update();o=bpy.data.objects.new('Fitted shirt',mesh);bpy.context.collection.objects.link(o);mesh.materials.append(M['shirt']);g=o.vertex_groups.new(name='spine');g.add(list(range(len(vs))),1,'REPLACE');PARTS.append(o)
 # One skinned mesh, with editable vertex groups; no hidden placeholder bodies.
 bpy.ops.object.select_all(action='DESELECT')
 for o in PARTS:o.select_set(True)
 bpy.context.view_layer.objects.active=PARTS[0];bpy.ops.object.join();body=bpy.context.object;body.name='TailoredCharacter';mod=body.modifiers.new('Skin deformation','ARMATURE');mod.object=rig;body.parent=rig
 bpy.context.view_layer.objects.active=rig
 for clip,frames in [('idle',[1,31,61]),('bet',[1,12,25]),('win',[1,15,31]),('fold',[1,15,31])]:
  rig.animation_data_create();rig.animation_data.action=None
  for frame in frames:
   t=0 if frame in [frames[0],frames[-1]] else 1
   for b in rig.pose.bones:
    b.rotation_mode='XYZ';b.rotation_euler=(0,0,0)
   rig.pose.bones['head'].rotation_euler.x=(.025 if clip=='idle' else (-.09 if clip=='win' else .12 if clip=='fold' else .035))*t
   if clip=='bet':rig.pose.bones['forearm.R'].rotation_euler.x=-.25*t
   if clip=='win':rig.pose.bones['spine'].rotation_euler.x=-.04*t
   for b in rig.pose.bones:b.keyframe_insert(data_path='rotation_euler',frame=frame)
  action=rig.animation_data.action;action.name=clip
  track=rig.animation_data.nla_tracks.new();track.name=clip;strip=track.strips.new(clip,1,action);strip.action_frame_start=1;strip.action_frame_end=frames[-1]
 rig.animation_data.action=None
 for tr in rig.animation_data.nla_tracks:tr.mute=True
 bpy.context.scene.frame_set(1);bpy.context.scene.render.fps=30
 bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(name+'.blend')))
 for tr in rig.animation_data.nla_tracks:tr.mute=False
 bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);body.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(DEST/(name+'.glb')),export_format='GLB',use_selection=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True)
 summary[name]={'bones':len(J),'vertices':len(body.data.vertices),'faces':len(body.data.polygons),'clips':['idle','bet','win','fold']}
(DEST/'manifest.json').write_text(json.dumps(summary,indent=2)+'\n')
print('CHARACTERS_COMPLETE',json.dumps(summary))
