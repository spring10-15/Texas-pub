extends SceneTree
var world
var output := ""
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output.path_join(name + ".png"))
	if error != OK:
		push_error("Screenshot write failed")
		quit(1)
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.has("--test") or DisplayServer.get_name() == "headless":
		push_error("Capture requires window and --test")
		quit(1)
		return
	for arg in args:
		if arg.begins_with("--media-output="): output = arg.trim_prefix("--media-output=")
	if not output.is_absolute_path():
		push_error("Absolute media output required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	world = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	await capture("01-stash")
	world.show_run_panel("enter")
	await capture("02-departure")
	world.confirm_run_action()
	world.player.position = Vector3(9.55, 0.02, 1.15)
	world.player.camera.look_at(world.table_target.global_position)
	for i in range(5): await physics_frame
	world.player.update_focus()
	if not world.request_action(world.table_target):
		push_error("Cannot seat through actual focus")
		quit(1)
		return
	world.start_table(301)
	if world.table_game == null:
		push_error("Cannot buy in")
		quit(1)
		return
	world.set_process(true)
	await create_timer(0.6).timeout
	world.set_process(false)
	await capture("03-table")
	world.queue_free()
	await process_frame
	print("PREVIEW_MEDIA captured=3")
	quit(0)
