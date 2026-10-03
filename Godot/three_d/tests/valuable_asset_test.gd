extends SceneTree
var checks := 0
var failures: Array[String] = []
func verify(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures.append(message)
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var kit: Node3D = load("res://three_d/assets/valuable-props.glb").instantiate()
	root.add_child(kit)
	var expected := ["old-silver-lighter","ivory-chip","ruby-cufflink","gold-cased-watch","antique-coin","sealed-bond","pearl-necklace","emerald-brooch","obsidian-idol","vault-promissory"]
	var content: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	verify(kit.get_child_count()==expected.size(),"Exactly ten valuables, no decorative substitutes")
	for id in expected:
		verify(content.items.has(id) and kit.has_node(NodePath(id)),"Rule ID has independent model "+id)
		var prop: Node3D=kit.get_node(NodePath(id))
		verify(prop.position.is_zero_approx() and prop.scale.is_equal_approx(Vector3.ONE),"Meter-scale root at origin "+id)
		var meshes := prop.find_children("*","MeshInstance3D",true,false)
		verify(not meshes.is_empty(),"Actual render geometry "+id)
		var preview=load("res://three_d/scripts/item_preview.gd").new(id)
		root.add_child(preview)
		verify(preview.get_child(0) is SubViewport,"Owned card resolves actual valuable "+id)
		preview.queue_free()
	var metal_names: Dictionary = {}
	for mesh: MeshInstance3D in kit.find_children("*","MeshInstance3D",true,false):
		for surface in range(mesh.mesh.get_surface_count()):
			var material = mesh.mesh.surface_get_material(surface)
			if material is StandardMaterial3D and material.resource_name in ["silver","gold"]:
				metal_names[material.resource_name] = true
				verify(material.normal_enabled and material.normal_texture != null and material.roughness_texture != null,"Imported metal has normal and roughness maps: " + material.resource_name)
				verify(not mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_TEX_UV].is_empty(),"Mapped metal has UVs")
	verify(metal_names.size()==2,"Both gold and silver imported mapped materials")
	var unknown=load("res://three_d/scripts/item_preview.gd").new("unknown-item")
	verify(unknown.get_child(0) is Label,"Unknown ID retains safe symbol")
	unknown.free()
	kit.queue_free()
	await process_frame
	print("VALUABLE_ASSET ",JSON.stringify({"checks":checks,"failed":failures.size(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
