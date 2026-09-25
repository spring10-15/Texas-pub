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
	world.show_run_panel("enter")
	world.confirm_run_action()
	world.player.position = Vector3(9.55, 0.02, 1.15)
	world.player.camera.look_at(world.table_target.global_position)
	for i in range(5):
		await physics_frame
	verify(world.request_action(world.table_target), "Player seats through actual ray interaction")
	verify(world.run_game.vault == 900 and world.run_game.cash == 300, "Entering tavern transfers 300 from vault")
	world.pause_game()
	world.toggle_pause()
	verify(not world.paused and world.seated and world.seat_panel.visible, "Esc resumes a pregame pause without trapping the player")
	world.start_table(301)
	verify(world.run_game.cash == 240, "Starting table pays buy-in once")
	world.start_table(302)
	verify(world.run_game.cash == 240, "Repeated start cannot charge twice")
	verify(world.table_game != null, "Start creates a real table")
	world.leave_seat()
	verify(world.seated, "Cannot leave while table remains active")
	var revision: int = world.table_game.revision
	world.toggle_pause()
	verify(not world.seat_panel.visible and world.pause_panel.visible, "Pause hides table controls")
	world._process(10)
	world.play_action("fold", revision)
	verify(world.paused and world.table_game.revision == revision, "Pause freezes timer and blocks player input")
	world.resume()
	verify(world.seat_panel.visible and not world.pause_panel.visible, "Resume restores table controls")
	verify(world.seated and world.seat_camera.current and not world.player.controls_enabled, "Resume keeps table camera and player seated")
	var output := ProjectSettings.globalize_path("res://../output/3d")
	DirAccess.make_dir_recursive_absolute(output)
	var frames := 0
	var world_ai_beats := 0
	var world_empty_actor_beats := 0
	while world.table_game.state.status != "finished" and frames < 150:
		frames += 1
		world.table_delay = 0
		world.refresh_table()
		var state: Dictionary = world.table_game.state
		if state.status == "hand_over":
			world.seat_panel.next_button.pressed.emit()
		elif state.currentActorId == "player":
			var legal: Dictionary = world.table_game.legal_actions("player")
			var kind := "fold" if state.handNumber == 1 else ("check" if legal.get("check", false) else ("call" if legal.get("call", false) else "all-in"))
			var prior: int = world.table_game.revision
			world.seat_panel.action_buttons[kind].pressed.emit()
			verify(world.table_game.revision == prior + 1, "HUD button submits exactly one legal action")
			world.play_action(kind, prior)
			verify(world.table_game.revision == prior + 1, "Double click during beat is ignored")
		else:
			if state.currentActorId.is_empty():
				world_empty_actor_beats += 1
			else:
				world_ai_beats += 1
			var prior: int = world.table_game.revision
			var before_beat: Dictionary = world.table_game.public_state()
			world._process(0.01)
			verify(world.table_game.revision == prior + 1 and world.table_game.public_state() != before_beat, "World process advances exactly one AI action or street")
		var view: Dictionary = world.table_game.public_state()
		if view.status == "playing":
			verify(view.players[1].holeCards.is_empty() and view.players[2].holeCards.is_empty(), "HUD receives no private opponent cards during play")
		await process_frame
	verify(world.table_game.state.status == "finished", "A whole table ends via UI and AI controller")
	verify(world_ai_beats > 0, "World scheduler exercised at least one opponent decision")
	verify(world_empty_actor_beats > 0, "World scheduler advances a street when no actor is pending")
	verify(world.table_game.state.handNumber == 2, "Second hand was played through the HUD")
	verify(world.seat_panel.leave_button.visible, "Terminal table exposes leave button")
	var bankroll := 0
	for person in world.table_game.state.players:
		bankroll += person.stack
	verify(bankroll == 180, "End-of-table chips sum to original bankrolls")
	var final_stack: int = world.table_game.state.players[0].stack
	world.seat_panel.leave_button.pressed.emit()
	verify(not world.seated and world.table_game == null and world.player.camera.current, "Leave restores exploration and clears table session")
	verify(world.run_game.cash == 240 + final_stack, "Leaving returns actual final stack to run cash")
	world.leave_seat()
	verify(world.run_game.cash == 240 + final_stack, "Repeated leave does not duplicate cash")
	world.player.position = Vector3(9.55, 0.02, 1.15)
	world.player.camera.look_at(world.table_target.global_position)
	for i in range(5):
		await physics_frame
	verify(not world.request_action(world.table_target), "Completed table cannot be bought into twice")
	world.player.position = Vector3(8.0, 0.02, 2.55)
	world.player.camera.look_at(world.exit_notice.global_position)
	for i in range(5):
		await physics_frame
	verify(world.request_action(world.exit_notice), "Discover exit through real scene interaction")
	world.open_services("bag")
	var route_buttons: Array = world.services_panel.rows.get_children().filter(func(child): return child is Button and child.text.begins_with("查看路线"))
	var general_quote: Dictionary = world.run_game.extraction_quote("general")
	verify(route_buttons.any(func(button): return button.text.contains("普通出口") and button.text.contains("到账 %d" % general_quote.net)), "Backpack shows the discovered exit's current payout")
	verify(not route_buttons.any(func(button): return button.text.contains("后厨楼梯") or button.text.contains("河边接驳")), "Backpack hides unknown special exits")
	world.close_services()
	var door: Area3D = world.get_node("Tavern/DoorTarget")
	world.player.position = Vector3(8.0, 0.02, 1.65)
	world.player.camera.look_at(door.global_position)
	for i in range(5):
		await physics_frame
	verify(world.request_action(door), "Exit door opens quote")
	var net: int = world.run_game.cash - 24 - int(floor(world.run_game.cash * 0.12)) + (60 if final_stack > 60 else 0)
	world.run_confirm.pressed.emit()
	verify(world.current_room == "stash" and world.run_game.vault == 900 + net and not world.run_game.active, "Exit button settles cash and returns to stash")
	world.run_confirm.pressed.emit()
	verify(world.run_game.vault == 900 + net, "Duplicate exit input cannot pay twice")
	var save_path := "user://first-run-integration-%d.save" % OS.get_process_id()
	world.save_path = save_path
	verify(world.save_checkpoint(), "Completed run saves after returning to stash")
	var reopened: Node3D = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(reopened)
	await physics_frame
	reopened.set_process(false)
	reopened.save_path = save_path
	reopened.load_checkpoint()
	verify(reopened.current_room == "stash" and not reopened.run_game.active and reopened.run_game.vault == 900 + net and reopened.paused, "Restart restores completed run and vault")
	reopened.resume()
	verify(reopened.player.controls_enabled and not reopened.run_game.extract(reopened.run_game.revision), "Restart resumes exploration without a second payout")
	verify(DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path)) == OK, "Temporary completed-run save is removed")
	var report := {"checks": checks, "failed": failures.size(), "failures": failures, "transitions": frames}
	var file := FileAccess.open(output.path_join("table-integration.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("TABLE_INTEGRATION ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
