extends SceneTree
var checks := 0
var failures: Array[String] = []
func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world: Node3D = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	for room in world.characters.rooms:
		for id in world.characters.rooms[room]:
			var entry: Dictionary = world.characters.rooms[room][id]
			var skeleton: Skeleton3D = entry.model.find_children("*", "Skeleton3D", true, false)[0]
			verify(skeleton.get_bone_count() == 14, "Skeleton imports " + room + "/" + id)
			var meshes: Array = entry.model.find_children("*", "MeshInstance3D", true, false)
			verify(meshes.size() == 1 and meshes[0].skin != null, "Mesh has skin binding")
			for clip in ["idle", "bet", "win", "fold"]:
				verify(entry.clips.has(clip) and entry.player.get_animation(entry.clips[clip]).get_track_count() >= 1, "Imported animated bones " + clip)
			entry.player.play(entry.clips.fold)
			entry.player.advance(0)
			var head := skeleton.find_bone("head")
			var before := skeleton.get_bone_pose_rotation(head)
			entry.player.advance(.45)
			verify(before.angle_to(skeleton.get_bone_pose_rotation(head)) > .02, "Animation deforms skeleton")
			entry.player.play(entry.clips.idle)
		for node in world.get_node(str(room)).get_children():
			if str(node.get_meta("visual_role", "")).begins_with("Bartender"):
				verify(not node.visible, "Old bartender placeholder hidden")
	world.show_run_panel("enter")
	world.confirm_run_action()
	world.player.position = Vector3(9.55,.02,1.15)
	world.player.camera.look_at(world.table_target.global_position)
	for i in range(5): await physics_frame
	verify(world.request_action(world.table_target), "Characters do not block seat ray")
	world.start_table(301)
	world.table_game.state.players[1].lastAction = "fold"
	world.refresh_table()
	var actor: Dictionary = world.characters.rooms.Tavern[world.table_game.state.players[1].id]
	verify(actor.player.current_animation == actor.clips.fold, "Public fold action triggers character reaction")
	world.characters.deliver()
	verify(world.characters.rooms.Tavern.bartender.player.current_animation == world.characters.rooms.Tavern.bartender.clips.bet, "Handoff triggers bartender animation")
	if OS.get_cmdline_user_args().has("--capture"):
		for i in range(12): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../output/3d/characters-table.png"))
	var report := {"checks":checks,"failed":failures.size(),"failures":failures}
	FileAccess.open("res://../output/3d/characters-test.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("CHARACTERS ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
