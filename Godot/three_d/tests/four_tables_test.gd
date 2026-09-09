extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Checkpoint = preload("res://three_d/rules/run_checkpoint.gd")
var world: Node3D
var checks := 0
var failures: Array[String] = []
func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func aim(pos: Vector3, anchor: Area3D) -> void:
	world.player.position = pos
	world.player.camera.look_at(anchor.global_position)
	for i in range(5): await physics_frame
func doorway(action: String) -> Area3D:
	for node in world.get_node(world.ROOMS[world.current_room].node).get_children():
		if node is Area3D and str(node.action_id) == action:
			return node
	return null
func play(winner := true) -> void:
	var steps := 0
	while world.table_game.state.status != "finished" and steps < 200:
		steps += 1
		var table: RefCounted = world.table_game
		if table.state.status == "hand_over":
			world.continue_hand(table.revision)
		elif table.state.currentActorId.is_empty():
			table.advance(table.revision)
		else:
			var actor: String = table.state.currentActorId
			var legal: Dictionary = table.legal_actions(actor)
			var action := "fold" if (actor != "player" if winner else actor == "player") else ("check" if legal.check else "call")
			verify(table.act(actor, action, table.revision), "Legal scripted action " + actor)
		world.refresh_table()
	verify(world.table_game.state.status == "finished", "Table terminates without skipped streets")
func run() -> void:
	world = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	world.show_run_panel("enter")
	world.confirm_run_action()
	var start_vault: int = world.run_game.vault
	verify(world.run_game.enter_table(1, world.run_game.revision, "mirror-hall") == null, "Mirror remains locked initially")
	verify(world.run_game.enter_table(1, world.run_game.revision, "embers-table") == null, "Embers remains locked initially")
	for room in ["tavern", "ledger", "mirror", "embers"]:
		if room != "tavern":
			var action: String = "enter_ledger" if room == "ledger" else "room:" + room
			var door := doorway(action)
			await aim(Vector3(world.ROOMS[world.current_room].x + 1.65, 0.02, 1.65), door)
			verify(world.request_action(door) and world.current_room == room, "Physical door enters " + room)
		await aim(Vector3(world.ROOMS[room].x - 0.45, 0.02, 1.15), world.table_target)
		verify(world.request_action(world.table_target), "Actual ray seats " + room)
		var pledged := ""
		if room in ["mirror", "embers"]:
			verify(world.seat_panel.collateral_choice.visible and world.seat_panel.collateral_choice.item_count > 1, "Only owned valuables available to pledge")
			world.seat_panel.collateral_choice.select(1)
			pledged = world.seat_panel.selected_collateral()
		if room == "mirror" and OS.get_cmdline_user_args().has("--capture"):
			for i in range(12): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../output/3d/mirror-collateral.png"))
		var before: int = world.run_game.cash
		world.start_table(401)
		verify(world.table_game != null and world.table_game.state.tableDef.id == world.ROOMS[room].table, "Correct rule set " + room)
		verify(world.run_game.cash == before - int(world.table_game.state.tableDef.buyIn), "Buy-in charged once")
		verify(world.run_game.collateral == pledged, "Escrow matches choice")
		if not pledged.is_empty():
			verify(pledged not in world.run_game.inventory, "Escrow cannot be sold or used")
		var snapshot: Dictionary = world.checkpoint_state()
		verify(world.restore_checkpoint(snapshot), "Mid-table save restores " + room)
		verify(world.run_game.collateral == pledged, "Escrow persists in save")
		if room == "mirror" and OS.get_cmdline_user_args().has("--capture"):
			for i in range(16): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../output/3d/mirror-playable.png"))
		await play()
		var stack: int = world.table_game.state.players[0].stack
		var before_leave: int = world.run_game.cash
		world.leave_seat()
		verify(world.run_game.cash == before_leave + stack, "Stack returned once " + room)
		verify(not world.run_game.settle_table(world.run_game.revision), "Duplicate settlement rejected")
		if not pledged.is_empty():
			verify(pledged in world.run_game.inventory and world.run_game.collateral.is_empty(), "Winning final hand returns collateral")
		if room == "mirror": verify(world.run_game.last_table_result.reward == "antique-coin", "Profitable final win with collateral grants signature")
		if room == "embers": verify(world.run_game.heat == 5, "Profitable embers cools before lockdown")
	verify(world.run_game.completed.size() == 4, "All four tables completed")
	var back := doorway("back_tavern")
	await aim(Vector3(38, 0.02, 1.65), back)
	verify(world.request_action(back) and world.current_room == "tavern", "Final room returns to exits")
	world.show_run_panel("extract")
	var quote: Dictionary = world.run_game.extraction_quote()
	world.confirm_run_action()
	verify(not world.run_game.active and world.current_room == "stash" and world.run_game.vault == start_vault + quote.net, "Four-table run settles cash and goods into vault")
	# Exercise a legal loss of pledged goods, then repeat settlement and reload checks.
	world.run_game.start(world.run_game.revision)
	world.run_game.completed.assign(["cargo-table", "ledger-cellar"])
	world.run_game.inventory.assign(["ivory-chip"])
	var r: RefCounted = world.run_game
	var rev: int = r.revision
	verify(r.enter_table(1, rev, "cargo-table", "ivory-chip") == null, "Non-collateral table rejects pledge")
	verify(r.enter_table(1, rev, "mirror-hall", "antique-coin") == null, "Unowned pledge rejected atomically")
	verify(r.inventory == ["ivory-chip"] and r.revision == rev and r.cash == 300, "Rejected pledge changes no economy")
	world.table_game = r.enter_table(1, rev, "mirror-hall", "ivory-chip")
	await play(false)
	verify(r.settle_table(r.revision), "Losing table settles")
	verify("ivory-chip" not in r.inventory and not r.last_table_result.returned and r.collateral.is_empty(), "Final loss forfeits exactly pledged item")
	var restored: RefCounted = Checkpoint.restore(Checkpoint.capture(r), world.table_content)
	verify(restored != null and restored.last_table_result == r.last_table_result, "Collateral outcome survives checkpoint")
	# Settlement fixtures isolate main-pot vs side-pot awards and a tied main pot.
	for winners in [["calm-widow"], ["player", "calm-widow"]]:
		var fixture := Run.new(world.table_content)
		fixture.start(fixture.revision)
		fixture.completed.assign(["cargo-table", "ledger-cellar"])
		fixture.inventory.assign(["ivory-chip"])
		var t: RefCounted = fixture.enter_table(9, fixture.revision, "mirror-hall", "ivory-chip")
		t.state.status = "finished"
		t.state.players[0].stack = 180
		t.state.summary = {"awards":{"player":60}, "pots":[{"winnerIds":winners}, {"winnerIds":["player"]}]}
		fixture.settle_table(fixture.revision)
		verify(fixture.last_table_result.returned == ("player" in winners), "Only main-pot victory or tie returns collateral")
		verify(fixture.last_table_result.reward == ("antique-coin" if "player" in winners else "sealed-bond"), "Side-pot payout cannot unlock collateral reward")
	var legacy: Dictionary = Checkpoint.capture(r)
	legacy.erase("collateral")
	legacy.erase("last_table_result")
	verify(Checkpoint.restore(legacy, world.table_content) != null, "Pre-expansion saves remain readable")
	var report := {"checks":checks,"failed":failures.size(),"failures":failures}
	FileAccess.open("res://../output/3d/four-tables.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("FOUR_TABLES ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
