extends SceneTree
var checks := 0
var failures: Array[String] = []
func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world: Node3D = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	for room_name in ["Stash", "Tavern", "LedgerCellar"]:
		var room: Node3D = world.get_node(room_name)
		var meshes := room.get_node("BlenderDetail").find_children("*", "MeshInstance3D", true, false)
		verify(meshes.size() == (1 if room_name == "Stash" else 8), "Material-grouped Blender kit imported in " + room_name)
		for node in room.get_children():
			if node.get_meta("visual_role", "") in ["Floor", "PokerTable", "Felt", "TableLeg", "OpponentChair", "BarCounter", "BarTop", "BarStool", "BottleShelf", "Bottle"]:
				verify(node.get_child(0) is MeshInstance3D and not node.get_child(0).visible, "Original placeholder hidden " + str(node.get_meta("visual_role")))
		verify(room.get_node("Floor").get_child(1) is CollisionShape3D, "Floor collision retained " + room_name)
	for id in world.run_game.SUPPORTED_ITEMS + ["loose-card", "loose-chip", "drawer"]:
		var prop: Node3D = world.make_detailed_prop(id)
		var surfaces := prop.find_children("*", "MeshInstance3D", true, false)
		verify(surfaces.size() == 1, "Single movable detailed mesh for " + id)
		verify(surfaces[0].get_aabb().size.length() < 1.1, "Metre-scale near-field prop " + id)
		prop.free()
	for key in ["wood", "wall", "cloth"]:
		verify(world.materials[key].albedo_texture != null and world.materials[key].normal_texture != null, "Baked maps loaded for " + key)
	verify(is_equal_approx(world.get_node("Stash/DeskPhysics").get_child(0).shape.size.y, 0.81), "Desk collision matches exported surface")
	if OS.get_cmdline_user_args().has("--capture"):
		world.show_run_panel("enter")
		world.confirm_run_action()
		world.player.position = Vector3(9.55, 0.02, 1.15)
		world.player.camera.look_at(world.table_target.global_position)
		for i in range(5):await physics_frame
		verify(world.request_action(world.table_target), "Detailed table still seats through ray")
		world.start_table(301)
		for i in range(20):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../output/3d/detailed-table.png"))
		var metrics := {"renderer":"Metal / Forward+", "resolution":str(root.size), "draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), "video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED), "scope":"Single warm table frame; not a sustained frame-rate benchmark"}
		var report := FileAccess.open("res://../output/3d/detail-runtime-metrics.json", FileAccess.WRITE)
		report.store_string(JSON.stringify(metrics, "  "))
	print("ART_INTEGRATION ", JSON.stringify({"checks":checks,"failed":failures.size(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
