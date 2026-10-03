extends SceneTree
## Export current prop geometry in Godot meters for the Blender art handoff.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var kits: Array[Node3D] = [load("res://three_d/assets/interactive-props.glb").instantiate(),load("res://three_d/assets/valuable-props.glb").instantiate()]
	for asset in kits: root.add_child(asset)
	var items: Array = []
	var modeled := 0
	for id in content.items:
		var kit: Node3D=kits[0] if kits[0].has_node(NodePath(id)) else kits[1]
		var entry := {"id":id,"modeled":kit.has_node(NodePath(id))}
		if entry.modeled:
			modeled += 1
			var prop: Node3D = kit.get_node(NodePath(id))
			var bounds := AABB()
			var first := true
			var triangles := 0
			var surfaces := 0
			var meshes := prop.find_children("*","MeshInstance3D",true,false)
			if prop is MeshInstance3D: meshes.append(prop)
			for mesh_node: MeshInstance3D in meshes:
				var local: Transform3D = prop.global_transform.affine_inverse() * mesh_node.global_transform
				var box: AABB = local * mesh_node.get_aabb()
				bounds = box if first else bounds.merge(box)
				first = false
				for index in range(mesh_node.mesh.get_surface_count()):
					surfaces += 1
					if mesh_node.mesh.surface_get_primitive_type(index) != Mesh.PRIMITIVE_TRIANGLES: continue
					var arrays := mesh_node.mesh.surface_get_arrays(index)
					var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
					triangles += indices.size()/3 if not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()/3
			entry["mesh_count"] = meshes.size()
			entry["material_surfaces"] = surfaces
			entry["triangles"] = triangles
			entry["local_bounds_min_m"] = [bounds.position.x,bounds.position.y,bounds.position.z]
			entry["local_bounds_max_m"] = [bounds.end.x,bounds.end.y,bounds.end.z]
			entry["size_m"] = [bounds.size.x,bounds.size.y,bounds.size.z]
			entry["root_position_m"] = [prop.position.x,prop.position.y,prop.position.z]
			entry["root_scale"] = [prop.scale.x,prop.scale.y,prop.scale.z]
		items.append(entry)
	var report := {"scope":"Current runtime geometry for all rule items. Missing meshes are production gaps, not gameplay errors. Bounds are static local AABBs in meters, not pose contact or final art acceptance.","rule_items":items.size(),"modeled_items":modeled,"missing_items":items.size()-modeled,"items":items,"props_glb_sha256":FileAccess.get_sha256("res://three_d/assets/interactive-props.glb"),"valuables_glb_sha256":FileAccess.get_sha256("res://three_d/assets/valuable-props.glb"),"content_sha256":FileAccess.get_sha256("res://three_d/rules/content.json")}
	FileAccess.open("res://../output/3d/prop-contract.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	for asset in kits: asset.free()
	print("PROP_CONTRACT rules=",items.size()," modeled=",modeled," missing=",items.size()-modeled)
	quit(0)
