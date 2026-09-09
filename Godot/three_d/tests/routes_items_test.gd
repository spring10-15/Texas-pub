extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Checkpoint = preload("res://three_d/rules/run_checkpoint.gd")
var checks := 0
var failures: Array[String] = []
var content: Dictionary
func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
func fresh() -> RefCounted:
	var run := Run.new(content)
	run.start(0)
	return run
func _initialize() -> void:
	call_deferred("run_tests")
func run_tests() -> void:
	content = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var run := fresh()
	verify(not run.service_action("reserve", "", run.revision), "Reservation requires lead")
	run.completed.append("cargo-table")
	verify(run.service_action("reserve", "", run.revision), "Reservation pays discounted upfront fee")
	verify(run.cash == 260 and run.action_points == 1 and run.reservation.expiresAfterSearch == 3, "Reservation records cost and exact expiry")
	verify(not run.service_action("reserve", "", run.revision), "Cannot accidentally reserve twice")
	var loaded := Checkpoint.restore(Checkpoint.capture(run), content)
	verify(loaded.reservation == run.reservation, "Reservation survives checkpoint")
	loaded.search_index = 3
	verify(loaded.extraction_quote("fixed").reason.is_empty(), "Valid on final reserved search")
	loaded.search_index = 4
	verify(not loaded.extract(loaded.revision, "fixed"), "Expired route cannot extract")
	run.inventory.append("ivory-chip")
	var revision: int = run.revision
	verify(run.extract(revision, "fixed"), "Reserved exit succeeds")
	verify(run.vault == 1210 and run.last_result.fee == 10, "Upfront and final fee are separate and goods count once")
	verify(not run.extract(revision, "fixed"), "No duplicate extraction")
	for item in ["kitchen-pass", "dock-passkey"]:
		run = fresh()
		run.inventory.append(item)
		var route: String = content.items[item].unlockRoute
		verify(not run.extract(run.revision, route), "Undiscovered special route is blocked")
		verify(run.service_action("pass", item, run.revision), "Pass reveals route")
		verify(run.inventory.is_empty() and run.action_points == 1, "Pass consumed exactly once")
		loaded = Checkpoint.restore(Checkpoint.capture(run), content)
		verify(loaded.route_flags[route], "Special route lead survives load")
		var max_heat: int = content.routes["smoky-den"].specialRoutes[route].maxHeat
		loaded.heat = max_heat + 1
		verify(not loaded.extract(loaded.revision, route), "Special route heat cap enforced")
		loaded.heat = max_heat
		verify(loaded.extract(loaded.revision, route), "Special route works at cap")
		verify(loaded.vault == 1200 - int(content.routes["smoky-den"].specialRoutes[route].finalCost), "Special route fee correct")
	for kind in ["dropbag-cash", "dropbag-valuables"]:
		run = fresh()
		run.heat = 6
		run.inventory.append("ivory-chip")
		verify(run.extract(run.revision, kind), "Emergency exits work at lockdown")
		verify(run.vault == (1130 if kind == "dropbag-cash" else 1190), "Emergency sacrifice and fee correct")
		verify(run.inventory.is_empty(), "Extraction clears run inventory")
	run = fresh()
	run.heat = 6
	verify(not run.extract(run.revision, "dropbag-valuables"), "Cannot dump nonexistent goods")
	run.cash = 9
	verify(not run.extract(run.revision, "dropbag-cash"), "Emergency exit requires fee")
	run = fresh()
	run.inventory.assign(["disposable-phone", "disposable-phone"])
	verify(run.service_action("phone-route", "disposable-phone", run.revision), "Phone refreshes route")
	verify(run.offer_index == 1 and run.fixed_known(), "Phone creates fixed lead and rotates offer")
	verify(run.service_action("phone-table", "disposable-phone", run.revision, "ledger-cellar"), "Phone reveals all table layers")
	verify(run.full_intel.has("ledger-cellar") and run.inventory.is_empty(), "Phone target saved and consumed")
	run = fresh()
	run.inventory.assign(["player-notes", "signal-lighter"])
	run.enter_table(301, run.revision)
	var target: String = run.table.state.players[1].id
	verify(not run.service_action("notes", "player-notes", run.revision, "player"), "Notes cannot target self")
	verify(run.service_action("notes", "player-notes", run.revision, target), "Notes reveals valid opponent")
	verify(run.opponent_notes[target] == content.opponents[target].archetype, "Archetype matches content")
	verify(run.service_action("signal", "signal-lighter", run.revision, target), "Signal reads target pressure")
	verify(run.service_message.contains("概率判断") and run.table.public_state().players[1].holeCards.is_empty(), "Signal does not expose hole cards")
	loaded = Checkpoint.restore(Checkpoint.capture(run), content)
	verify(loaded.opponent_notes == run.opponent_notes and loaded.used_tools == run.used_tools, "Reads and tool use survive save")
	run = fresh()
	run.inventory.append("false-bottom-wallet")
	verify(run.abandon(run.revision), "Wallet applies at loss")
	verify(run.vault == 980 and run.last_result.net == 80, "Wallet salvages max 80")
	run = fresh()
	run.search_index = 2
	verify("disposable-phone" in run.shop_stock(), "Phone can be bought before final table")
	var old_save := Checkpoint.capture(run)
	for field in ["route_flags", "reservation", "offer_index", "full_intel", "opponent_notes"]:
		old_save.erase(field)
	loaded = Checkpoint.restore(old_save, content)
	verify(loaded != null and loaded.cash == 300 and loaded.reservation.is_empty(), "Previous version saves load with new field defaults")
	run.heat = 6
	run.inventory.append("ivory-chip")
	verify(run.enforce_pressure(), "Lockdown resolves automatically outside table")
	verify(run.last_result.route == "dropbag-valuables" and run.vault == 1190, "Lockdown preserves highest total net value")
	verify(not run.enforce_pressure(), "Lockdown cannot settle twice")
	run = fresh()
	run.heat = 6
	run.cash = 9
	run.inventory.append("false-bottom-wallet")
	verify(run.enforce_pressure() and run.vault == 909, "No affordable exit applies wallet salvage")
	run = fresh()
	run.enter_table(301, run.revision)
	run.heat = 6
	verify(not run.enforce_pressure() and run.table != null, "Lockdown waits for table settlement")
	# Actual special-route entrance and modal confirmation.
	var world: Node3D = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	world.show_run_panel("enter")
	world.confirm_run_action()
	world.run_game.inventory.append("kitchen-pass")
	world.open_services()
	world.service_action("pass", "kitchen-pass", world.run_game.revision)
	if OS.get_cmdline_user_args().has("--capture"):
		for i in range(12):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../output/3d/route-services-runtime.png"))
	world.close_services()
	var anchor: Area3D
	for node in world.get_node("Tavern").get_children():
		if node is Area3D and node.action_id == "route:service-stairs":
			anchor = node
	world.player.position = Vector3(7.25, 1.22, -11.6)
	world.player.camera.look_at(anchor.global_position)
	for i in range(5):
		await physics_frame
	verify(world.request_action(anchor), "Special route entrance reachable by actual ray")
	verify(world.selected_route == "service-stairs" and not world.run_confirm.disabled, "Physical entrance quotes correct route")
	if OS.get_cmdline_user_args().has("--capture"):
		for i in range(12):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../output/3d/special-route-runtime.png"))
	world.run_confirm.pressed.emit()
	verify(world.current_room == "stash" and world.run_game.vault == 1175, "Special exit UI settles and returns")
	var report := {"checks":checks, "failed":failures.size(), "failures":failures}
	print("ROUTES_ITEMS ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
