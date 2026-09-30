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
	world.save_path = path
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
				check(world.save_checkpoint(), "Save through actual world save entry")
	else:
		var loaded: Dictionary = store.read_checkpoint(path)
		check(loaded.status == "ok", "Read snapshot from previous process")
		if not failed:
			world.load_checkpoint()
			check(world.paused and world.pause_panel.visible, "Loaded game waits for Continue")
			check(world.saving_enabled, "Valid loaded game permits saving")
			check(world.checkpoint_state() == loaded.state, "World position, look, props, table and RNG match")
			check(world.seated == (args[2] == "table"), "Restore correct seat mode")
			check(not world.player.controls_enabled, "Pause blocks player movement")
			world.resume()
			check(not world.paused and not world.pause_panel.visible, "Continue exits loaded pause")
			check(world.player.controls_enabled == not world.seated, "Restore appropriate player controls")
			for id in ["lamp", "window", "drawer0"]:
				check(world.props.states[id], "Restore opened prop " + id)
			check(world.seat_camera.current if world.seated else world.player.camera.current, "Restore correct camera")
			var valid_bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
			var corrupt := FileAccess.open(path, FileAccess.WRITE)
			corrupt.store_string("invalid probe save")
			corrupt.close()
			var corrupt_bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
			var before: Dictionary = world.checkpoint_state()
			world.load_checkpoint()
			check(not world.saving_enabled, "Invalid save disables automatic replacement")
			check(world.checkpoint_state() == before, "Invalid load leaves live world unchanged")
			check(FileAccess.get_file_as_bytes(path) == corrupt_bytes, "Invalid file remains preserved")
			check(world.save_notice.text.contains("损坏"), "Invalid load gives player readable notice")
			var replacement := FileAccess.open(path, FileAccess.WRITE)
			replacement.store_buffer(valid_bytes)
			replacement.close()
	world.queue_free()
	await process_frame
	print("Pack restart %s %s: %s" % [args[1], args[2], "FAILED" if failed else "PASS"])
	quit(1 if failed else 0)
