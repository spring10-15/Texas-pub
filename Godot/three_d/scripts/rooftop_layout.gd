extends RefCounted
## Visual terrace overlay; existing room collisions and interaction anchors stay in place.
const SERVICE = preload("res://three_d/assets/rooftop-service.glb")
const SERVICE_ROLES = ["ServiceHall", "CrossHall", "KitchenFloor", "UpperLanding", "HallWall", "CrossWall", "HallEnd", "KitchenWall", "UpperExitWall", "StairTread", "UpperCeiling", "StoreFloor", "LiftWall", "WingDivider", "Crate", "LiftGate", "GateBar"]
const BAR = preload("res://three_d/assets/rooftop-bar.glb")
const CHAIRS = preload("res://three_d/assets/rooftop-chairs.glb")
const TABLE = preload("res://three_d/assets/rooftop-table.glb")
const CITY = preload("res://three_d/assets/rooftop-city.glb")
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
			var city := CITY.instantiate()
			city.name = "CityBackdrop"
			architecture.add_child(city)
			var table := TABLE.instantiate()
			table.name = "RooftopTable"
			architecture.add_child(table)
			var chairs := CHAIRS.instantiate()
			chairs.name = "RooftopChairs"
			architecture.add_child(chairs)
			var bar := BAR.instantiate()
			bar.name = "RooftopBar"
			architecture.add_child(bar)
			var service := SERVICE.instantiate()
			service.name = "RooftopService"
			service.visible = room.name == "Tavern"
			architecture.add_child(service)
		if architecture != null: architecture.visible = rooftop
		room.get_node("BlenderDetail").find_child("TavernFloor", true, false).visible = not rooftop
		room.get_node("BlenderDetail").find_child("TavernTable", true, false).visible = not rooftop
		room.get_node("BlenderDetail").find_child("TavernChairs", true, false).visible = not rooftop
		room.get_node("BlenderDetail").find_child("TavernBar", true, false).visible = not rooftop
		if room.name == "Tavern":
			room.get_node("RouteDetail").find_child("StoreDetails", true, false).visible = not rooftop
		for body in room.get_children():
			var role: String = body.get_meta("visual_role", "")
			if not (role in SERVICE_ROLES or role.begins_with("Ceiling") or role == "FrontWall" or (role == "SideWall" and body.position.x < 0)): continue
			for mesh in body.get_children():
				if mesh is MeshInstance3D:
					if not mesh.has_meta("indoor_visible"): mesh.set_meta("indoor_visible", mesh.visible)
					mesh.visible = false if rooftop else mesh.get_meta("indoor_visible")
