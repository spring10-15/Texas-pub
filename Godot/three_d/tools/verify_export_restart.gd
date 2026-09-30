extends SceneTree
var failed := false

func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 4 or args[0] != "--test" or args[1] not in ["write", "read"] or args[2] not in ["stash", "table"]:
		push_error("Expected -- --test write|read stash|table ABSOLUTE_TEMP_PATH")
		quit(1)
		return
	var path := args[3]
	if not path.is_absolute_path() or not path.get_file().begins_with("texaspub-restart-"):
		push_error("Use an isolated absolute texaspub-restart- path")
		quit(1)
		return
	var world = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	var store = load("res://three_d/rules/save_store.gd")
	if args[1] == "write":
		check(not FileAccess.file_exists(path), "Refuse to overwrite probe state")
		if not failed:
			world.props.restore({"lamp":true, "window":true, "drawer0":true})
			world.player.position = Vector3(-0.2, 0.05, 1.6)
			world.player.camera.rotation = Vector3(-0.2, 0.4, 0)
			if args[2] == "table":
				check(world.run_game.start(world.run_game.revision, "smoky-den", 41), "Start real world run")
				world.travel("tavern")
				world.player.position = Vector3(9.55, 0.02, 1.15)
				world.player.camera.look_at(world.table_target.global_position)
				for i in range(5): await physics_frame
				check(world.request_action(world.table_target), "Seat using actual ray interaction")
				world.start_table(301)
				check(world.table_game != null, "Create active world table")
			if not failed:
				check(store.write_checkpoint(path, world.checkpoint_state()) == OK, "Write world snapshot")
	else:
		var loaded: Dictionary = store.read_checkpoint(path)
		check(loaded.status == "ok", "Read snapshot from previous process")
		if not failed:
			check(world.restore_checkpoint(loaded.state), "Restore whole world")
			check(world.checkpoint_state() == loaded.state, "World position, look, props, table and RNG match")
			check(world.seated == (args[2] == "table"), "Restore correct seat mode")
			check(world.player.controls_enabled == not world.seated, "Restore appropriate player controls")
			for id in ["lamp", "window", "drawer0"]:
				check(world.props.states[id], "Restore opened prop " + id)
			check(world.seat_camera.current if world.seated else world.player.camera.current, "Restore correct camera")
	world.queue_free()
	await process_frame
	print("Pack restart %s %s: %s" % [args[1], args[2], "FAILED" if failed else "PASS"])
	quit(1 if failed else 0)
