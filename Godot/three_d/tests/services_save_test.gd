extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Checkpoint = preload("res://three_d/rules/run_checkpoint.gd")
const Store = preload("res://three_d/rules/save_store.gd")
var checks := 0
var failures: Array[String] = []
func verify(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)
		push_error(text)
func _initialize() -> void:
	call_deferred("run_tests")
func run_tests() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var game := Run.new(content)
	game.start(0)
	verify(game.service_action("buy", "marked-lens", game.revision), "Buy lens from actual stock")
	verify(game.cash == 260 and game.action_points == 1 and game.inventory.size() == 1, "Purchase charges cash and action")
	verify(not game.service_action("lens", "steadying-drink", game.revision), "Mismatched item action cannot exploit inventory")
	verify(not game.service_action("buy", "sleeve-clip", game.revision), "Unavailable stock rejected")
	verify(game.service_action("intel", "cargo-table", game.revision), "Intel consumes action")
	verify(not game.service_action("buy", "steadying-drink", game.revision), "No action points cannot buy")
	game.enter_table(301, game.revision)
	var old_revision := game.revision
	verify(game.service_action("lens", "marked-lens", game.revision), "Lens usable in active hand")
	verify(game.preview == game.table.state.deck.back() and game.inventory.is_empty() and game.heat == 2, "Lens previews next card, consumes item and adds heat")
	verify(not game.service_action("lens", "marked-lens", old_revision), "Duplicate item request rejected")
	var restored := Checkpoint.restore(Checkpoint.capture(game), content)
	verify(restored != null and Checkpoint.capture(restored) == Checkpoint.capture(game), "Full run preserves cash, intel, usage and private deck")
	verify(not restored.service_action("lens", "marked-lens", restored.revision), "Reload cannot reuse consumed lens")
	# Fixture terminal stack values exercise the original reward thresholds independently of poker odds.
	for pair in [["cargo-table", 80, "ivory-chip"], ["ledger-cellar", 120, "emerald-brooch"], ["ledger-cellar", 130, "pearl-necklace"]]:
		var reward_run := Run.new(content)
		reward_run.start(0)
		if pair[0] == "ledger-cellar":
			reward_run.completed.append("cargo-table")
		reward_run.enter_table(1, reward_run.revision, pair[0])
		reward_run.table.state.status = "finished"
		reward_run.table.state.players[0].stack = pair[1]
		verify(reward_run.settle_table(reward_run.revision), "Profitable table settles")
		verify(reward_run.inventory == [pair[2]], "Correct threshold reward")
		var after := Checkpoint.restore(Checkpoint.capture(reward_run), content)
		verify(not after.settle_table(after.revision), "Reload cannot award twice")
		var cash: int = after.cash
		var value := int(content.items[pair[2]].value)
		verify(after.extraction_quote().net == cash - 24 - int(floor(cash * 0.12)) + value, "Valuable is included once in extraction")
		verify(after.service_action("sell", pair[2], after.revision), "Reward can be sold")
		verify(after.cash == cash + value and after.inventory.is_empty(), "Sale removes reward and credits value")
	var full := Run.new(content)
	full.start(0)
	full.inventory.assign(["steadying-drink", "steadying-drink", "steadying-drink", "steadying-drink", "steadying-drink", "steadying-drink"])
	verify(not full.service_action("buy", "marked-lens", full.revision), "Full inventory blocks purchase")
	full.enter_table(1, full.revision)
	full.table.state.status = "finished"
	full.table.state.players[0].stack = 80
	full.settle_table(full.revision)
	verify(full.inventory.size() == 6 and full.last_reward.contains("背包已满"), "Full bag refuses reward explicitly")
	var tools_run := Run.new(content)
	tools_run.start(0)
	tools_run.completed.append("cargo-table")
	tools_run.inventory.assign(["marked-lens", "sleeve-clip"])
	tools_run.enter_table(301, tools_run.revision, "ledger-cellar")
	tools_run.service_action("lens", "marked-lens", tools_run.revision)
	var predicted: Dictionary = tools_run.preview.duplicate()
	verify(tools_run.service_action("sleeve", "sleeve-clip", tools_run.revision), "Sleeve replaces before first action")
	verify(tools_run.table.state.deck.back() == predicted and tools_run.table.state.players[0].holeCards[1] != predicted, "Sleeve preserves previously previewed public card")
	verify(tools_run.heat == 6 and tools_run.inventory.is_empty(), "Ledger tools include extra heat and consume both items")
	verify(not tools_run.abandon(tools_run.revision), "Cannot abandon unsettled poker table")
	tools_run.table.state.status = "finished"
	tools_run.table.state.players[0].stack = 0
	tools_run.settle_table(tools_run.revision)
	verify(not tools_run.extract(tools_run.revision), "Lockdown blocks normal exit")
	verify(tools_run.abandon(tools_run.revision), "Explicit abandon escapes blocked run with loss")
	var abandoned := Checkpoint.restore(Checkpoint.capture(tools_run), content)
	verify(abandoned.vault == 900 and abandoned.cash == 0 and not abandoned.active and not abandoned.extract(abandoned.revision), "Saved loss cannot be cashed out again")
	var world: Node3D = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	world.show_run_panel("enter")
	world.confirm_run_action()
	world.open_services("product", "marked-lens")
	world.service_action("buy", "marked-lens", world.run_game.revision)
	verify(world.run_game.inventory == ["marked-lens"] and not world.services_panel.visible, "Actual service UI callback buys item")
	world.close_services()
	world.player.position = Vector3(9.55, 0.02, 1.15)
	world.player.camera.look_at(world.table_target.global_position)
	for i in range(5):
		await physics_frame
	world.request_action(world.table_target)
	world.start_table(301)
	world.open_services()
	var turn: int = world.table_game.revision
	world._process(10)
	world.play_action("fold", turn)
	verify(world.table_game.revision == turn, "Services freeze table progression and hidden buttons")
	world.service_action("lens", "marked-lens", world.run_game.revision)
	if OS.get_cmdline_user_args().has("--capture"):
		for i in range(12):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../output/3d/services-runtime.png"))
	world.close_services()
	var path := "user://full-run-test-%d.save" % OS.get_process_id()
	world.save_path = path
	verify(world.save_checkpoint(), "World writes complete checkpoint")
	var saved: Dictionary = Store.read_checkpoint(path).state
	var fresh: Node3D = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(fresh)
	await physics_frame
	fresh.set_process(false)
	fresh.save_path = path
	fresh.load_checkpoint()
	verify(fresh.paused and fresh.saving_enabled, "Startup loader restores and pauses for user")
	fresh.resume()
	verify(fresh.seated and fresh.table_game == fresh.run_game.table and fresh.seat_camera.current, "Restored scene links controller and seated camera")
	verify(fresh.run_game.cash == 200 and fresh.run_game.used_tools == ["marked-lens"], "Reload does not charge buy-in or undo item usage")
	verify(fresh.table_game.state.deck == world.table_game.state.deck, "Private deck preserved in real scene")
	fresh.table_delay = 0
	fresh.play_action("fold", fresh.table_game.revision)
	verify(fresh.table_game.revision == world.table_game.revision + 1, "Restored HUD can continue legally")
	fresh.saving_enabled = false
	DirAccess.remove_absolute(path)
	print("SERVICES_SAVE ", JSON.stringify({"checks": checks, "failed": failures.size(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)
