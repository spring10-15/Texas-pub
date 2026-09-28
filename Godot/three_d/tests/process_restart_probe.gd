extends SceneTree
const Store = preload("res://three_d/rules/save_store.gd")
const SITES := ["cargo-table", "ledger-cellar", "mirror-hall", "embers-table"]
const SITE_ROOMS := ["tavern", "ledger", "mirror", "embers"]

func _initialize() -> void:
	call_deferred("run")

func fail(message: String) -> void:
	push_error(message)
	print("PROCESS_RESTART ", JSON.stringify({"failed": 1, "failures": [message]}))
	quit(1)

func run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var phase := "write" if arguments.has("--phase=write") else "restore"
	var scene := ""
	var site := ""
	for argument in arguments:
		if argument.begins_with("--scene="): scene = argument.trim_prefix("--scene=")
		if argument.begins_with("--site="): site = argument.trim_prefix("--site=")
	if site not in SITES or scene not in ["smoky-den", "high-rise-suite", "rooftop-club", "neon-poker-club"]:
		fail("Invalid process-restart case")
		return
	var world: Node3D = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	if phase == "write":
		if not world.saving_enabled or not world.run_game.start(world.run_game.revision, scene, 17):
			fail("Fresh startup cannot begin a run")
			return
		world.run_game.completed.assign(SITES.slice(0, SITES.find(site)))
		world.travel(SITE_ROOMS[SITES.find(site)])
		world.return_transform = world.player.global_transform
		world.seated = true
		world.table_game = world.run_game.enter_table(31, world.run_game.revision, site)
		if world.table_game == null:
			fail("Cannot enter first table")
			return
		var table: RefCounted = world.table_game
		var actor: String = table.state.currentActorId
		var legal: Dictionary = table.legal_actions(actor)
		var action := "check" if legal.check else ("call" if legal.call else "fold")
		if not table.act(actor, action, table.revision):
			fail("Cannot take first legal action")
			return
		world._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		var saved: Dictionary = Store.read_checkpoint(world.save_path)
		if saved.status != "ok" or saved.state != world.checkpoint_state():
			fail("Disk checkpoint differs from live world")
			return
		print("PROCESS_RESTART ", JSON.stringify({"failed": 0, "phase": phase, "scene": scene, "site": site, "turn": table.state.turnCounter}))
		quit()
		return
	var disk: Dictionary = Store.read_checkpoint(world.save_path)
	if disk.status != "ok" or not world.saving_enabled or not world.paused or not world.seated or world.table_game == null or world.run_game.scene_id != scene or world.table_game.state.tableDef.id != site or world.checkpoint_state() != disk.state:
		fail("Fresh process did not auto-restore the seated world")
		return
	world.resume()
	var table: RefCounted = world.table_game
	var steps := 0
	while table.state.status != "finished" and steps < 200:
		steps += 1
		if table.state.status == "hand_over":
			if not table.next_hand(table.revision): break
		elif table.state.currentActorId.is_empty():
			if not table.advance(table.revision): break
		else:
			var actor: String = table.state.currentActorId
			var legal: Dictionary = table.legal_actions(actor)
			var action := "check" if legal.check else ("call" if legal.call else "fold") if actor == "player" else "fold"
			if not table.act(actor, action, table.revision): break
	if table.state.status != "finished":
		fail("Restored table did not finish")
		return
	var stack: int = int(table.state.players[0].stack)
	var opening_wealth: int = int(disk.state.run.vault) + int(disk.state.run.cash) + world.run_game.valuable_total()
	world.leave_seat()
	var reward_value: int = int(world.table_content.items[world.run_game.last_table_result.reward].value) if world.run_game.last_table_result.reward_added else 0
	if world.run_game.table != null or world.run_game.vault + world.run_game.cash + world.run_game.valuable_total() != opening_wealth + stack + reward_value:
		fail("Restored table did not settle")
		return
	print("PROCESS_RESTART ", JSON.stringify({"failed": 0, "phase": phase, "scene": scene, "site": site, "turn": int(disk.state.run.table.state.turnCounter), "steps": steps}))
	quit()
