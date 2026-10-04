extends SceneTree
var checks := 0
var failures: Array[String] = []
func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void: call_deferred("run")
func collision_snapshot(world) -> Array:
	var result := []
	for shape in world.find_children("*", "CollisionShape3D", true, false):
		if not shape.get_parent() is StaticBody3D: continue
		result.append([str(shape.get_path()), shape.global_transform, shape.shape, shape.disabled, shape.get_parent().collision_layer, shape.get_parent().collision_mask])
	return result
func run() -> void:
	var world = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	var before := collision_snapshot(world)
	verify(world.run_game.start(world.run_game.revision, "rooftop-club", 41), "Start rooftop fixture")
	var run_before: Dictionary = world.RunCheckpoint.capture(world.run_game)
	var instances := []
	for room_id in world.ROOMS:
		world.travel(room_id)
		var room = world.get_node(world.ROOMS[room_id].node)
		var architecture = room.get_node("RooftopArchitecture")
		var deck: MeshInstance3D = architecture.find_child("RooftopDeck",true,false)
		var original_floor: MeshInstance3D = room.get_node("BlenderDetail").find_child("TavernFloor",true,false)
		verify(abs((deck.global_transform * deck.get_aabb()).end.y - 0.014) < 0.00001, "Deck visible top matches existing floor height")
		verify(abs((original_floor.global_transform * original_floor.get_aabb()).end.y - 0.014) < 0.00001, "Indoor floor geometry preserves height")
		var city = architecture.get_node("CityBackdrop")
		verify(city.find_children("*", "CollisionShape3D", true, false).is_empty(), "City backdrop has no gameplay collision")
		verify(city.find_children("*", "MeshInstance3D", true, false).size() == 6, "Six merged city material meshes loaded")
		instances.append(architecture.get_instance_id())
		for setup in world.ROOMS.values(): verify(world.get_node(setup.node).visible == (setup.node == room.name), "Only current terrace is rendered")
		verify(architecture.visible and architecture.find_child("RooftopDeck",true,false).visible and not room.get_node("BlenderDetail").find_child("TavernFloor",true,false).visible, "Independent deck visible without legacy floor: " + room_id)
		for body in room.get_children():
			var role: String = body.get_meta("visual_role", "")
			if role.begins_with("Ceiling") or role == "FrontWall" or (role == "SideWall" and body.position.x < 0):
				for mesh in body.get_children():
					if mesh is MeshInstance3D: verify(not mesh.visible, "Indoor enclosure hidden: " + room_id + "/" + role)
		verify(room.get_node("BlenderDetail").find_child("TavernDetail_walnut",true,false).visible, "Wood furniture retained: " + room_id)
		verify(room.get_node("BlenderDetail").visible, "Furniture retained: " + room_id)
	verify(world.scene_environment.background_mode == Environment.BG_SKY, "Outdoor sky applied")
	verify(collision_snapshot(world) == before, "All collision transforms, shapes and masks unchanged")
	verify(world.RunCheckpoint.capture(world.run_game) == run_before, "Architecture does not mutate Run")
	world.travel("tavern")
	var saved: Dictionary = world.checkpoint_state()
	world.travel("stash")
	verify(world.scene_environment.background_mode == Environment.BG_COLOR, "Stash background restored")
	for setup in world.ROOMS.values():
		verify(not world.get_node(setup.node).get_node("RooftopArchitecture").visible, "Terrace hidden in stash")
	verify(world.restore_checkpoint(saved), "Restore rooftop checkpoint")
	verify(world.scene_environment.background_mode == Environment.BG_SKY, "Restore reapplies sky")
	var after_instances := []
	for setup in world.ROOMS.values(): after_instances.append(world.get_node(setup.node).get_node("RooftopArchitecture").get_instance_id())
	verify(instances == after_instances, "Reuses existing terrace instances")
	for venue in ["smoky-den", "high-rise-suite", "neon-poker-club"]:
		world.venue_lighting.apply(world.get_node("Tavern"),venue)
		verify(world.scene_environment.background_mode == Environment.BG_COLOR and world.scene_environment.sky == null, "Indoor sky restored: " + venue)
		for setup in world.ROOMS.values():
			var room = world.get_node(setup.node)
			verify(room.get_node("BlenderDetail").find_child("TavernFloor",true,false).visible, "Indoor floor restored")
			verify(not room.get_node("RooftopArchitecture").visible, "Terrace hidden: " + venue + "/" + setup.node)
			for body in room.get_children():
				for mesh in body.get_children():
					if mesh is MeshInstance3D and mesh.has_meta("indoor_visible"): verify(mesh.visible == mesh.get_meta("indoor_visible"), "Indoor enclosure restored")
	world.restore_checkpoint(saved)
	world.travel("tavern")
	if OS.get_cmdline_user_args().has("--capture"):
		world.player.position = Vector3(10, 0.05, 0.8)
		world.player.rotation.y = PI
		world.player.camera.rotation.x = -0.05
		for i in range(12): await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../output/3d/rooftop-in-game.png"))
		for view in [{"name":"entry","position":Vector3(8,0.05,1.7),"yaw":0.0},{"name":"table","position":Vector3(9.55,0.05,0.04),"yaw":PI},{"name":"exit","position":Vector3(7.6,0.05,1.65),"yaw":PI/2}]:
			world.player.position = view.position
			world.player.rotation.y = view.yaw
			for i in range(8): await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../output/3d/rooftop-city-"+view.name+".png"))
	print("ROOFTOP_LAYOUT ", JSON.stringify({"checks":checks,"failed":failures.size(),"failures":failures}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
