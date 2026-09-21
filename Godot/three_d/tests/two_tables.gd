extends SceneTree
var failures: Array[String] = []
var checks := 0
var world: Node3D
func verify(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		push_error(description)
func _initialize() -> void:
	call_deferred("run")
func aim(pos: Vector3, anchor: Area3D) -> void:
	world.player.position = pos
	world.player.camera.look_at(anchor.global_position)
	for i in range(5):
		await physics_frame
func play_table(seed_value: int, expected_id: String) -> void:
	verify(world.request_action(world.table_target), "Actual ray seats at " + expected_id)
	world.start_table(seed_value)
	verify(world.table_game.state.tableDef.id == expected_id, "Correct table definition")
	var buy_in: int = world.table_game.state.tableDef.buyIn
	var before_cash: int = world.run_game.cash
	verify(world.seat_panel.header.text.begins_with(world.TableHUD.TABLE_NAMES[expected_id]), "HUD title matches room")
	verify(world.cards_root.get_parent().name == ("LedgerCellar" if expected_id == "ledger-cellar" else "Tavern"), "Cards belong to current room")
	if expected_id == "ledger-cellar":
		verify(world.table_game.state.currentBet == 30 and not world.table_game.state.firstAggressionDiscountAvailable, "Second table blinds and no cargo discount")
		verify(world.seat_panel.opponent_left.text.begins_with(world.TableHUD.NAMES[world.table_game.state.players[1].id]), "Second table opponent names")
	if expected_id == "ledger-cellar" and OS.get_cmdline_user_args().has("--capture"):
		for i in range(12):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../output/3d/ledger-table.png"))
	var steps := 0
	while world.table_game.state.status != "finished" and steps < 150:
		steps += 1
		world.table_delay = 0
		world.refresh_table()
		if world.table_game.state.status == "hand_over":
			world.seat_panel.next_button.pressed.emit()
		elif world.table_game.state.currentActorId == "player":
			world.seat_panel.action_buttons.fold.pressed.emit()
		else:
			world.advance_table_beat()
	verify(world.table_game.state.status == "finished", "Table terminates")
	var total := 0
	for person in world.table_game.state.players:
		total += person.stack
	verify(total == buy_in * 3, "Each table conserves its own bankroll")
	var returned: int = world.table_game.state.players[0].stack
	world.seat_panel.leave_button.pressed.emit()
	verify(world.run_game.cash == before_cash + returned, "Returned stack credited exactly")
	verify(world.run_game.completed.has(expected_id), "Completion unlock recorded")
func run() -> void:
	world = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	world.show_run_panel("enter")
	world.confirm_run_action()
	verify(world.run_game.enter_table(1, world.run_game.revision, "ledger-cellar") == null, "Rules reject locked second table")
	await aim(Vector3(11.65, 0.02, 1.65), world.ledger_door)
	verify(not world.request_action(world.ledger_door), "Door rejects locked second room")
	await aim(Vector3(9.55, 0.02, 1.15), world.table_target)
	await play_table(301, "cargo-table")
	var cash: int = world.run_game.cash
	await aim(Vector3(11.65, 0.02, 1.65), world.ledger_door)
	verify(world.request_action(world.ledger_door) and world.current_room == "ledger", "Unlocked doorway reaches second room")
	verify(world.run_game.cash == cash, "Travel does not charge buy-in")
	await aim(Vector3(19.55, 0.02, 1.15), world.table_target)
	await play_table(302, "ledger-cellar")
	verify(world.run_game.heat == 2, "Both tables raise heat once")
	verify(world.run_game.enter_table(4, world.run_game.revision, "ledger-cellar") == null, "Second table cannot replay")
	var back: Area3D = world.get_node("LedgerCellar/DoorTarget")
	await aim(Vector3(18.0, 0.02, 1.65), back)
	verify(world.request_action(back) and world.current_room == "tavern", "Return doorway restores first room")
	await aim(Vector3(8.0, 0.02, 2.55), world.exit_notice)
	verify(world.request_action(world.exit_notice), "Exit notice remains reachable")
	var exit_door: Area3D = world.get_node("Tavern/DoorTarget")
	await aim(Vector3(8.0, 0.02, 1.65), exit_door)
	world.request_action(exit_door)
	var quote: Dictionary = world.run_game.extraction_quote()
	world.run_confirm.pressed.emit()
	verify(world.current_room == "stash" and world.run_game.vault == 900 + quote.net, "Two-table run extracts into vault")
	var report := {"checks": checks, "failed": failures.size(), "failures": failures}
	var file := FileAccess.open("res://../output/3d/two-tables.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("TWO_TABLES ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
