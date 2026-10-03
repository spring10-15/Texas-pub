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
	if args.size() != 4 or args[0] != "--test" or args[1] not in ["write", "read"] or args[2] not in ["stash", "table", "search", "shopping", "reservation", "extracted", "collateral"]:
		push_error("Expected -- --test write|read stash|table|search|shopping|reservation|extracted|collateral ABSOLUTE_TEMP_PATH")
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
			if args[2] != "stash":
				check(world.run_game.start(world.run_game.revision, "smoky-den", 41), "Start real world run")
				world.travel("tavern")
				if args[2] in ["table", "reservation", "extracted", "collateral"]:
					world.player.position = Vector3(9.55, 0.02, 1.15)
					world.player.camera.look_at(world.table_target.global_position)
					for i in range(5): await physics_frame
					check(world.request_action(world.table_target), "Seat using actual ray interaction")
					world.start_table(301)
					check(world.table_game != null, "Create active world table")
					if args[2] != "table" and world.table_game != null:
						await finish_for_upgrade(world)
						check(world.table_game == null and not world.seated, "Settle and leave real table")
						if args[2] == "reservation":
							check(world.run_game.service_action("reserve", "", world.run_game.revision), "Pay for legal reservation")
							check(not world.run_game.reservation.is_empty(), "Reservation recorded")
						elif args[2] == "extracted":
							var quote: Dictionary = world.run_game.extraction_quote()
							var vault_before: int = world.run_game.vault
							world.show_run_panel("extract")
							world.confirm_run_action()
							check(not world.run_game.active and world.current_room == "stash" and world.run_game.vault == vault_before + quote.net, "Actual extraction banks quoted amount")
						elif args[2] == "collateral":
							if not world.run_game.room_blocked_reason("mirror-hall").is_empty():
								world.travel("ledger")
								await seat_for_upgrade(world)
								world.start_table(301)
								await finish_for_upgrade(world)
							world.travel("mirror")
							await seat_for_upgrade(world)
							check(world.seat_panel.collateral_choice.item_count > 1, "Earned valuable available for collateral")
							world.seat_panel.collateral_choice.select(1)
							var pledged: String = world.seat_panel.selected_collateral()
							world.start_table(301)
							check(world.table_game != null and world.run_game.collateral == pledged and not pledged.is_empty() and pledged not in world.run_game.inventory, "Real mirror buy-in pledges earned valuable")
				elif args[2] == "search":
					var events = load("res://three_d/rules/search_events.gd")
					var applied := false
					for choice in events.event_for(world.run_game, "cargo-table").choices:
						if world.run_game.service_reason("search", "cargo-table", choice.id).is_empty():
							applied = world.run_game.service_action("search", "cargo-table", world.run_game.revision, choice.id)
							break
					check(applied and world.run_game.search_results.has("cargo-table"), "Resolve real search event")
				elif args[2] == "shopping":
					var purchased := false
					for item in world.run_game.shop_stock():
						if world.run_game.service_reason("buy", item).is_empty():
							purchased = world.run_game.service_action("buy", item, world.run_game.revision)
							check(item in world.run_game.inventory, "Purchased item enters inventory")
							break
					check(purchased and world.run_game.cash < world.run_game.bankroll, "Actual purchase deducts cash")
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
			check(world.seated == (args[2] in ["table", "collateral"]), "Restore correct seat mode")
			check(not world.player.controls_enabled, "Pause blocks player movement")
			world.resume()
			check(not world.paused and not world.pause_panel.visible, "Continue exits loaded pause")
			check(world.player.controls_enabled == not world.seated, "Restore appropriate player controls")
			for id in ["lamp", "window", "drawer0"]:
				check(world.props.states[id], "Restore opened prop " + id)
			check(world.seat_camera.current if world.seated else world.player.camera.current, "Restore correct camera")
			if args[2] == "extracted":
				var banked: Dictionary = world.checkpoint_state()
				world.check_pressure()
				world.leave_seat()
				check(world.checkpoint_state() == banked, "Restored extraction cannot bank twice")
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

func seat_for_upgrade(world: Node3D) -> void:
	world.player.position = Vector3(world.ROOMS[world.current_room].x - 0.45, 0.02, 1.15)
	world.player.camera.look_at(world.table_target.global_position)
	for i in range(5): await physics_frame
	world.player.update_focus()
	check(world.request_action(world.table_target), "Seat through physical mirror path")

func finish_for_upgrade(world: Node3D) -> void:
	var table = world.table_game
	check(table != null, "Buy into prerequisite table")
	if table == null: return
	var beats := 0
	while table.state.status != "finished" and beats < 200:
		beats += 1
		if table.state.status == "hand_over": check(table.next_hand(table.revision), "Next prerequisite hand")
		elif table.state.currentActorId.is_empty(): check(table.advance(table.revision), "Advance prerequisite street")
		else:
			var actor: String = table.state.currentActorId
			var legal: Dictionary = table.legal_actions(actor)
			check(table.act(actor, "fold" if actor != "player" else ("check" if legal.check else "call"), table.revision), "Legal prerequisite action")
	check(table.state.status == "finished", "Prerequisite table completes")
	world.leave_seat()
