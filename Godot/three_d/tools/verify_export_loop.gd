extends SceneTree
var failures := 0
var checks := 0

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not OS.get_cmdline_user_args().has("--test"):
		push_error("Pass -- --test to protect player saves")
		quit(1)
		return
	var world = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	var rules = load("res://three_d/rules/run.gd")
	var checkpoint = load("res://three_d/rules/run_checkpoint.gd")
	var store = load("res://three_d/rules/save_store.gd")
	var save_path: String = OS.get_cache_dir().path_join("texaspub-pack-probe-%d.save" % OS.get_process_id())
	verify(not FileAccess.file_exists(save_path), "Probe save path is unused")
	if FileAccess.file_exists(save_path):
		world.queue_free()
		quit(1)
		return
	for venue in rules.SCENE_NAMES:
		var night = rules.new(world.table_content)
		verify(night.start(night.revision, venue, 41), "Start " + venue)
		var starting_vault: int = night.vault
		var searched := false
		var event: Dictionary = rules.SearchEvents.event_for(night, "cargo-table")
		for choice in event.choices:
			if night.service_reason("search", "cargo-table", choice.id).is_empty():
				searched = night.service_action("search", "cargo-table", night.revision, choice.id)
				break
		verify(searched, "Resolve legal search in " + venue)
		var expected_wealth: int = night.vault + night.cash + night.valuable_total()
		for site in ["cargo-table", "ledger-cellar", "mirror-hall", "embers-table"]:
			if night.heat > 0 and not night.heat_reduced:
				var cooling_cost: int = night.scene_definition().heatReductionCost
				verify(night.service_action("cool", "", night.revision), "Use real cooling service")
				expected_wealth -= cooling_cost
			var table = night.enter_table(301, night.revision, site)
			verify(table != null, "Enter " + site + " in " + venue)
			if table == null: continue
			var snapshot: Dictionary = checkpoint.capture(night)
			verify(store.write_checkpoint(save_path, snapshot) == OK, "Pack writes active table checkpoint")
			var loaded: Dictionary = store.read_checkpoint(save_path)
			verify(loaded.status == "ok" and loaded.state == snapshot, "Pack reads active table checkpoint exactly")
			if loaded.status != "ok": continue
			var restored = checkpoint.restore(loaded.state, world.table_content)
			verify(restored != null, "Pack restores active table and RNG")
			if restored == null: continue
			verify(checkpoint.capture(restored) == snapshot, "Restored packed state equals source state")
			night = restored
			table = night.table
			var steps := 0
			while table.state.status != "finished" and steps < 200:
				steps += 1
				if table.state.status == "hand_over":
					table.next_hand(table.revision)
				elif table.state.currentActorId.is_empty():
					table.advance(table.revision)
				else:
					var id: String = table.state.currentActorId
					var legal: Dictionary = table.legal_actions(id)
					verify(table.act(id, "fold" if id != "player" else ("check" if legal.check else "call"), table.revision), "Legal packed table action")
			verify(table.state.status == "finished", "Packed table terminates")
			expected_wealth += int(table.state.players[0].stack) - int(table.state.tableDef.buyIn)
			verify(night.settle_table(night.revision), "Packed table settles")
			if night.last_table_result.reward_added:
				expected_wealth += int(night.content.items[night.last_table_result.reward].value)
			verify(night.vault + night.cash + night.valuable_total() == expected_wealth, "Independent packed wealth ledger balances")
			verify(not night.enforce_pressure(), "Legal cooling keeps whole evening playable")
			print("Packed table completed: ", venue, "/", site)
		verify(night.completed.size() == 4, "All four packed tables completed without unlock fixtures")
		verify(night.public_exit, "Completed packed table reveals public exit")
		var active_snapshot: Dictionary = checkpoint.capture(night)
		for route in ["fixed", "dropbag-cash", "dropbag-valuables"]:
			var branch = checkpoint.restore(active_snapshot, world.table_content)
			verify(branch != null, "Restore legal route branch")
			if branch == null: continue
			var prepaid := 0
			if route == "fixed":
				if branch.heat > int(branch.route_offer().maxHeat):
					prepaid += int(branch.scene_definition().heatReductionCost)
					verify(branch.service_action("cool", "", branch.revision), "Cool legally before reserved extraction")
				prepaid += branch.reserve_fee()
				verify(branch.service_action("reserve", "", branch.revision), "Reserve actual available route")
				verify(not branch.service_action("reserve", "", branch.revision), "Reject duplicate reservation")
			var prepared: Dictionary = checkpoint.capture(branch)
			branch = checkpoint.restore(prepared, world.table_content)
			verify(branch != null, "Prepared route survives checkpoint")
			if branch == null: continue
			var route_quote: Dictionary = branch.extraction_quote(route)
			verify(route_quote.reason.is_empty(), "Legal packed route available: " + venue + "/" + route + ": " + route_quote.reason)
			verify(branch.extract(branch.revision, route), "Packed special extraction: " + route)
			verify(branch.vault == expected_wealth - prepaid - int(route_quote.fee) - int(route_quote.lostCash) - int(route_quote.lostGoods), "Special route independent wealth ledger")
			var result: Dictionary = checkpoint.capture(branch)
			verify(not branch.extract(branch.revision, route) and checkpoint.capture(branch) == result, "Special extraction cannot repeat")
			print("Packed route completed: ", venue, "/", route)
		var quote: Dictionary = night.extraction_quote()
		verify(quote.reason.is_empty(), "Packed extraction is available")
		verify(night.extract(night.revision), "Packed extraction succeeds")
		verify(night.vault == starting_vault + int(quote.net) and night.cash == 0 and not night.active, "Packed extraction banks exact quote")
		verify(night.vault == expected_wealth - int(quote.fee), "Final packed wealth equals table ledger minus public exit fee")
		var completed: Dictionary = checkpoint.capture(night)
		verify(store.write_checkpoint(save_path, completed) == OK, "Pack replaces completed checkpoint")
		var completed_file: Dictionary = store.read_checkpoint(save_path)
		verify(completed_file.status == "ok", "Pack reads completed checkpoint")
		if completed_file.status == "ok":
			var resumed = checkpoint.restore(completed_file.state, world.table_content)
			verify(resumed != null, "Pack restores completed extraction")
			if resumed != null:
				var banked: int = resumed.vault
				verify(not resumed.extract(resumed.revision) and resumed.vault == banked, "Restored extraction cannot credit twice")
		verify(not FileAccess.file_exists(save_path + ".tmp"), "Atomic replacement leaves no temporary save")
		print("Packed loop completed: ", venue)
	if FileAccess.file_exists(save_path):
		verify(DirAccess.remove_absolute(save_path) == OK, "Remove isolated probe save")
	world.queue_free()
	await process_frame
	print("Export loop: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
