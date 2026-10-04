@tool
extends EditorScenePostImport
## Blender transmission is not mapped by this Godot importer. Persist native optics in the imported scene.
func _post_import(scene: Node) -> Object:
	for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var material = mesh.mesh.surface_get_material(surface)
			if not material is StandardMaterial3D or material.resource_name not in ["ruby", "emerald", "watch-glass"]:
				continue
			material.metallic = 0.0
			material.roughness = 0.08
			material.albedo_color.a = 0.84
			material.cull_mode = BaseMaterial3D.CULL_BACK
			material.refraction_enabled = true
			material.refraction_scale = 0.015
			if material.resource_name == "watch-glass":
				material.roughness = 0.04
				material.albedo_color = Color(0.92, 0.98, 1.0, 0.025)
				material.refraction_scale = 0.004
	return scene
