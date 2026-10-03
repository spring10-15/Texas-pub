extends SceneTree
var failures: Array[String] = []
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	check(world.run_game.start(world.run_game.revision, "rooftop-club", 41), "normal departure")
	world.travel("tavern")
	var initial_vault: int = world.run_game.vault
	for room in ["tavern", "ledger", "mirror"]:
		world.travel(room)
		world.player.position = Vector3(world.ROOMS[room].x - 0.45, 0.02, 1.15)
		world.player.camera.look_at(world.table_target.global_position)
		for i in range(5): await physics_frame
		world.player.update_focus()
		check(world.request_action(world.table_target) and world.seated, "physical table seat " + room)
		world.start_table(301)
		var table = world.table_game
		check(table != null, "legal buy-in " + room)
		if table == null: break
		var beats := 0
		while table.state.status != "finished" and beats < 200:
			beats += 1
			if table.state.status == "hand_over": check(table.next_hand(table.revision), "next hand")
			elif table.state.currentActorId.is_empty(): check(table.advance(table.revision), "advance street")
			else:
				var actor: String = table.state.currentActorId
				var legal: Dictionary = table.legal_actions(actor)
				check(table.act(actor, "fold" if actor != "player" else ("check" if legal.check else "call"), table.revision), "legal table action")
		check(table.state.status == "finished", "table completes")
		var heat: int = world.run_game.heat
		var cash_after: int = world.run_game.cash + table.state.players[0].stack
		var goods_before: int = world.run_game.valuable_total()
		world.leave_seat()
		check(not world.seated and world.table_game == null, "leave clears seat")
		if room != "mirror":
			check(world.run_game.active and heat < 6, "earlier tables remain playable")
		else:
			check(heat == 6, "natural entry bonuses reach heat cap")
			check(not world.run_game.active and world.current_room == "stash", "forced extraction returns home")
			var result: Dictionary = world.run_game.last_result
			check(result.get("forced", false), "forced result visible")
			var goods_after := goods_before
			var settled: Dictionary = world.run_game.last_table_result
			if settled.get("reward_added", false):
				goods_after += world.run_game.sale_value(settled.reward)
			check(result.cash == cash_after, "extraction uses actual settled cash")
			check(cash_after + goods_after == result.net + result.fee + result.lostCash + result.lostGoods, "cash and goods conserved across extraction")
			check(world.run_game.inventory.is_empty(), "extraction clears carried rewards")
			check(world.run_game.cash == 0 and world.run_game.vault == initial_vault + int(result.get("net", -1)), "banked result matches vault")
			check(cash_after > 0 and not result.get("abandoned", false), "earned cash extracted rather than abandoned")
			var banked: Dictionary = world.checkpoint_state()
			world.check_pressure()
			world.leave_seat()
			check(world.checkpoint_state() == banked, "repeated pressure and leave cannot bank twice")
	world.queue_free()
	await process_frame
	print("NATURAL_PRESSURE_EXIT checks=", checks, " failed=", failures.size())
	quit(0 if failures.is_empty() else 1)
