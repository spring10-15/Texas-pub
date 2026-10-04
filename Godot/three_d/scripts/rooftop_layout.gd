extends RefCounted
## Visual terrace overlay; existing room collisions and interaction anchors stay in place.
const TERRACE = preload("res://three_d/assets/rooftop-terrace.glb")
var world: Node3D
var original_sky: Sky
var original_background: int
var terrace_sky := Sky.new()

func _init(owner: Node3D) -> void:
	world = owner
	original_sky = world.scene_environment.sky
	original_background = world.scene_environment.background_mode
	var material := ProceduralSkyMaterial.new()
	material.sky_top_color = Color("081321")
	material.sky_horizon_color = Color("263e59")
	material.ground_horizon_color = Color("1e2c44")
	material.ground_bottom_color = Color("0a111b")
	terrace_sky.sky_material = material

func apply(profile_id: String) -> void:
	var rooftop := profile_id == "rooftop-club"
	world.scene_environment.sky = terrace_sky if rooftop else original_sky
	world.scene_environment.background_mode = Environment.BG_SKY if rooftop else original_background
	for setup in world.ROOMS.values():
		var room: Node3D = world.get_node(setup.node)
		room.visible = not rooftop or setup.node == world.ROOMS[world.current_room].node
		var architecture := room.get_node_or_null("RooftopArchitecture")
		if rooftop and architecture == null:
			architecture = TERRACE.instantiate()
			architecture.name = "RooftopArchitecture"
			room.add_child(architecture)
			# The shared legacy floor is merged with furniture; avoid overlapping floors.
			architecture.find_child("RooftopDeck", true, false).hide()
		if architecture != null: architecture.visible = rooftop
		for body in room.get_children():
			var role: String = body.get_meta("visual_role", "")
			if not (role.begins_with("Ceiling") or role == "FrontWall" or (role == "SideWall" and body.position.x < 0)): continue
			for mesh in body.get_children():
				if mesh is MeshInstance3D:
					if not mesh.has_meta("indoor_visible"): mesh.set_meta("indoor_visible", mesh.visible)
					mesh.visible = false if rooftop else mesh.get_meta("indoor_visible")
