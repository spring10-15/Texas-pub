extends SceneTree
const Store = preload("res://three_d/rules/save_store.gd")

func _initialize() -> void:
	call_deferred("run")

func fail(message: String) -> void:
	push_error(message)
	print("PROCESS_EVENING ", JSON.stringify({"failed": 1, "failures": [message]}))
	quit(1)

func wealth(world: Node3D) -> int:
	return world.run_game.vault + world.run_game.cash + world.run_game.valuable_total()

func cool_if_needed(world: Node3D, site: String) -> int:
	var run_game: RefCounted = world.run_game
	var projected: int = run_game.heat + int(run_game.table_definition(site).heatGain) + int(run_game.scene_definition().entryHeatBonus)
	if run_game.heat > 0 and projected >= 5 and not run_game.heat_reduced:
		var cost: int = int(run_game.scene_definition().heatReductionCost)
		return cost if run_game.service_action("cool", "", run_game.revision) else -1
	return 0

func enter(world: Node3D, room: String, site: String) -> bool:
	world.travel(room)
	world.return_transform = world.player.global_transform
	world.seated = true
	world.table_game = world.run_game.enter_table(31, world.run_game.revision, site)
	return world.table_game != null

func finish(table: RefCounted) -> bool:
	var steps := 0
	while table.state.status != "finished" and steps < 200:
		steps += 1
		if table.state.status == "hand_over":
			if not table.next_hand(table.revision): return false
		elif table.state.currentActorId.is_empty():
			if not table.advance(table.revision): return false
		else:
			var actor: String = table.state.currentActorId
			var legal: Dictionary = table.legal_actions(actor)
			var action := ("check" if legal.check else "call") if actor == "player" else "fold"
			if not table.act(actor, action, table.revision): return false
	return table.state.status == "finished"

func settle(world: Node3D, expected: int) -> int:
	var table: RefCounted = world.table_game
	if not finish(table): return -1
	var stack: int = int(table.state.players[0].stack)
	var buy_in: int = int(table.state.tableDef.buyIn)
	world.leave_seat()
	if world.run_game.table != null or not world.run_game.active: return -1
	var result: Dictionary = world.run_game.last_table_result
	var reward: int = int(world.table_content.items[result.reward].value) if result.reward_added else 0
	var next_expected: int = expected + stack - buy_in + reward
	return next_expected if wealth(world) == next_expected else -1

func run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var writing := arguments.has("--phase=write")
	var expected := -1
	for argument in arguments:
		if argument.begins_with("--wealth="): expected = argument.trim_prefix("--wealth=").to_int()
	var world: Node3D = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	if writing:
		if not world.saving_enabled or not world.run_game.start(world.run_game.revision, "smoky-den", 0):
			fail("Cannot start first venue")
			return
		expected = wealth(world)
		if not enter(world, "tavern", "cargo-table"):
			fail("Cannot enter cargo table")
			return
		expected = settle(world, expected)
		if expected < 0:
			fail("Cargo table ledger failed")
			return
		var transfer: Dictionary = world.run_game.transfer_quote("high-rise-suite")
		if not transfer.reason.is_empty() or not world.run_game.transfer_venue("high-rise-suite", world.run_game.revision):
			fail("Cannot transfer after actual first table")
			return
		expected -= int(transfer.fee)
		if wealth(world) != expected:
			fail("Transfer ledger failed")
			return
		var cooling: int = cool_if_needed(world, "ledger-cellar")
		if cooling < 0 or not enter(world, "ledger", "ledger-cellar"):
			fail("Cannot enter second table")
			return
		expected = settle(world, expected - cooling)
		if expected < 0:
			fail("Second table ledger failed")
			return
		cooling = cool_if_needed(world, "mirror-hall")
		if cooling < 0 or not enter(world, "mirror", "mirror-hall"):
			fail("Cannot enter third table")
			return
		expected -= cooling + int(world.table_game.state.tableDef.buyIn)
		var table: RefCounted = world.table_game
		var actor: String = table.state.currentActorId
		var legal: Dictionary = table.legal_actions(actor)
		var action := ("check" if legal.check else "call") if actor == "player" else "fold"
		if not table.act(actor, action, table.revision) or wealth(world) != expected:
			fail("Mid-third-table state failed")
			return
		world._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		var disk: Dictionary = Store.read_checkpoint(world.save_path)
		if disk.status != "ok" or disk.state != world.checkpoint_state():
			fail("Mid-evening disk checkpoint differs")
			return
		print("PROCESS_EVENING ", JSON.stringify({"failed": 0, "phase": "write", "wealth": expected, "completed": world.run_game.completed.size(), "journey": world.run_game.venue_history}))
		quit()
		return
	var disk: Dictionary = Store.read_checkpoint(world.save_path)
	if expected < 0 or disk.status != "ok" or not world.paused or not world.seated or world.table_game == null or world.run_game.completed.size() != 2 or world.run_game.venue_history != ["smoky-den", "high-rise-suite"] or world.checkpoint_state() != disk.state or wealth(world) != expected:
		fail("New process did not restore actual two-venue history")
		return
	world.resume()
	var table: RefCounted = world.table_game
	if not finish(table):
		fail("Restored third table did not finish")
		return
	var stack: int = int(table.state.players[0].stack)
	world.leave_seat()
	if world.run_game.table != null or not world.run_game.active:
		fail("Restored third table did not settle")
		return
	var result: Dictionary = world.run_game.last_table_result
	expected += stack + (int(world.table_content.items[result.reward].value) if result.reward_added else 0)
	if wealth(world) != expected:
		fail("Restored third table ledger failed")
		return
	var cooling: int = cool_if_needed(world, "embers-table")
	if cooling < 0 or not enter(world, "embers", "embers-table"):
		fail("Cannot enter final table")
		return
	expected = settle(world, expected - cooling)
	if expected < 0 or world.run_game.completed.size() != 4:
		fail("Final table ledger failed")
		return
	var quote: Dictionary = world.run_game.extraction_quote()
	if not quote.reason.is_empty() or not world.run_game.extract(world.run_game.revision):
		fail("Cannot extract after four real tables")
		return
	expected -= int(quote.fee) + int(quote.lostCash) + int(quote.lostGoods)
	if world.run_game.vault != expected or world.run_game.active or world.run_game.last_result.journey != world.run_game.transfer_log:
		fail("Final bank or journey ledger failed")
		return
	print("PROCESS_EVENING ", JSON.stringify({"failed": 0, "phase": "restore", "wealth": expected, "completed": world.run_game.completed.size(), "journey": world.run_game.venue_history}))
	quit()
