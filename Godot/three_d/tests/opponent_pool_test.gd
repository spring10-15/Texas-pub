extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Checkpoint = preload("res://three_d/rules/run_checkpoint.gd")
const Opponent = preload("res://three_d/rules/opponent.gd")
var checks := 0
var failures: Array[String] = []
func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void: call_deferred("run")
func legal_action(legal: Dictionary, action: String) -> bool:
	return legal.get("allIn" if action == "all-in" else action, false)
func play_to_settlement(r: RefCounted, table: RefCounted, content: Dictionary) -> bool:
	var steps := 0
	while table.state.status != "finished" and steps < 250:
		steps += 1
		if table.state.status == "hand_over":
			if not table.next_hand(table.revision): return false
		elif table.state.currentActorId.is_empty():
			if not table.advance(table.revision): return false
		else:
			var actor_id: String = table.state.currentActorId
			var legal: Dictionary = table.legal_actions(actor_id)
			var action: String
			if actor_id == "player":
				action = "check" if legal.check else ("call" if legal.call else "fold")
			else:
				var actor: Dictionary = table.state.players.filter(func(p): return p.id == actor_id)[0]
				action = Opponent.choose(table.state, actor, legal, content.opponents[actor_id], 0.5)
			if not legal_action(legal, action) or not table.act(actor_id, action, table.revision): return false
	return table.state.status == "finished" and r.settle_table(r.revision)
func run() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var original_content := content.duplicate(true)
	var coverage := {}
	var distinct := {}
	var complete_runs := 0
	var run_failures := 0
	for scene in Run.SCENE_NAMES:
		var layouts := {}
		for seed_value in range(1,101):
			var r := Run.new(content)
			r.start(r.revision,scene,seed_value)
			verify(Run.Variants.valid(r.variant_plan,content,scene),"Generated roster valid")
			layouts[JSON.stringify(r.variant_plan.opponents)] = true
			for site in Run.Variants.TABLES:
				var definition: Dictionary = r.table_definition(site)
				for id in definition.opponentIds:
					var key: String = scene+":"+site+":"+id
					if coverage.has(key): continue
					var test_run := Run.new(content)
					test_run.start(test_run.revision,scene,seed_value)
					test_run.completed.assign(Run.Variants.TABLES.slice(0,Run.Variants.TABLES.find(site)))
					var initial_wealth: int = test_run.vault + test_run.cash + test_run.valuable_total()
					var table: RefCounted = test_run.enter_table(74,test_run.revision,site)
					verify(table != null and table.state.tableDef.opponentIds==definition.opponentIds,"Runtime seats planned roster")
					var actor: Dictionary = table.state.players.filter(func(p): return p.id==id)[0]
					# Use a valid decision snapshot with this actor to exercise the live estimator and policy.
					var snapshot: Dictionary = table.state.duplicate(true)
					snapshot.currentActorId = id
					var legal := {"allIn":true,"raise":true,"call":true,"fold":true,"check":false}
					var action := Opponent.choose(snapshot,actor,legal,content.opponents[id],.5)
					verify(legal.get("allIn" if action=="all-in" else action,false),"Each venue/table/opponent produces a legal decision")
					var saved := Checkpoint.capture(test_run)
					var loaded: RefCounted = Checkpoint.restore(saved,content)
					verify(loaded != null and loaded.table.state==table.state,"Active roster and cards survive restore")
					var buy_in: int = int(table.state.tableDef.buyIn)
					var finished: bool = play_to_settlement(test_run, table, content)
					var player_stack: int = int(table.state.players.filter(func(p): return p.id == "player")[0].stack)
					var result: Dictionary = test_run.last_table_result
					var reward_value: int = int(content.items[result.reward].value) if result.reward_added else 0
					verify(finished, "Full legal table run settles: " + key)
					verify(test_run.vault + test_run.cash + test_run.valuable_total() == initial_wealth + player_stack - buy_in + reward_value, "Independent table wealth ledger balances: " + key)
					if finished and test_run.vault + test_run.cash + test_run.valuable_total() == initial_wealth + player_stack - buy_in + reward_value:
						complete_runs += 1
					else:
						run_failures += 1
					coverage[key] = true
				distinct[scene] = layouts.size()
	verify(content==original_content,"Variant definitions do not mutate shared content")
	verify(coverage.size()==128,"All four venues x four tables x eight actors reached")
	verify(complete_runs==128 and run_failures==0,"Every venue/table/opponent line completes with a balanced independent ledger")
	var r := Run.new(content)
	r.start(r.revision,"smoky-den",71)
	var bad := Checkpoint.capture(r)
	bad.variant_plan.opponents["cargo-table"][0] = "unknown"
	verify(Checkpoint.restore(bad,content)==null,"Unknown actor rejected")
	bad = Checkpoint.capture(r)
	bad.variant_plan.opponents["cargo-table"][0] = bad.variant_plan.opponents["cargo-table"][1]
	verify(Checkpoint.restore(bad,content)==null,"Repeated actor rejected")
	r.enter_table(22,r.revision)
	bad = Checkpoint.capture(r)
	var roster: Array = bad.variant_plan.opponents["cargo-table"]
	roster.reverse()
	verify(Checkpoint.restore(bad,content)==null,"Saved active table cannot disagree with committed seat order")
	r.table = null
	var legacy := Checkpoint.capture(r)
	legacy.variant_plan.version = 2
	legacy.variant_plan.erase("opponents")
	legacy.variant_plan.erase("room_layout")
	var loaded: RefCounted = Checkpoint.restore(legacy,content)
	verify(loaded != null and loaded.table_definition("cargo-table").opponentIds==content.tables["cargo-table"].opponentIds,"Old plan retains historical roster")
	var world: Node = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.run_game = r
	for room in world.ROOMS:
		world.travel(room)
		var setup: Dictionary = world.ROOMS[room]
		var ids: Array = r.table_definition(setup.table).opponentIds
		r.full_intel[setup.table] = true
		var info: Dictionary = r.service_view()
		verify(info.text.contains(r.actor_name(ids[0])) and info.text.contains(r.actor_name(ids[1])),"Full intelligence names this run's opponents")
		var people: Dictionary = world.characters.rooms[setup.node]
		verify(people.keys().filter(func(id): return id!="bartender")==ids,"Visible character roster matches plan")
		world.seat_panel.pregame(r.cash,r.table_definition(setup.table),r.inventory,r)
		verify(world.seat_panel.opponent_left.text==r.actor_name(ids[0]) and world.seat_panel.opponent_right.text==r.actor_name(ids[1]),"Pregame labels match visible roster")
	world.queue_free()
	var report := {"checks":checks,"failed":failures.size(),"failures":failures,"venue_table_actor_combinations":coverage.size(),"complete_table_runs":complete_runs,"unbalanced_or_incomplete_runs":run_failures,"distinct_rosters_per_100_seeds":distinct,"scope":"Every venue/table/opponent combination completes one full table using legal player/AI actions; the independent wealth ledger is checked. This does not prove full-night survival or human difficulty balance."}
	FileAccess.open("res://../output/3d/opponent-pool.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("OPPONENT_POOL ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
