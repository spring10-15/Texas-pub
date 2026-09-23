extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Checkpoint = preload("res://three_d/rules/run_checkpoint.gd")
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
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var scenes: Array = Run.SCENE_NAMES.keys()
	var rows: Array = []
	var eager_rows: Array = []
	for first in scenes:
		for second in scenes:
			if second == first: continue
			for third in scenes:
				if third in [first, second]: continue
				for fourth in scenes:
					if fourth in [first, second, third]: continue
					var itinerary := [first, second, third, fourth]
					rows.append(simulate(content, itinerary, false))
					eager_rows.append(simulate(content, itinerary, true))
	verify(rows.size() == 24, "All four-venue visit orders sampled")
	verify(rows.all(func(item): return item.outcome == "complete"), "Every venue order reaches final extraction under scripted policy")
	verify(eager_rows.size() == 24 and eager_rows.any(func(item): return item.outcome == "table_blocked"), "Cooling at every opportunity can prevent final buy-in")
	var report := {"checks":checks, "failed":failures.size(), "failures":failures, "runs":rows, "eager_cooling_comparison":eager_rows, "scope":"Seed 0, linear table order, legal player calls/checks with folding opponents. The main policy pays for cooling only when projected heat reaches 5; comparison cools whenever possible. This measures scripted reachability and economy, not player skill, win rate or duration."}
	FileAccess.open("res://../output/3d/venue-order-matrix.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("VENUE_ORDER ", JSON.stringify({"checks":checks, "failed":failures.size(), "outcomes":count_outcomes(rows), "eager_cooling_outcomes":count_outcomes(eager_rows), "failures":failures}))
	quit(0 if failures.is_empty() else 1)

func simulate(content: Dictionary, itinerary: Array, cool_eagerly: bool) -> Dictionary:
	var run_game := Run.new(content)
	var path: String = "→".join(itinerary)
	verify(run_game.start(run_game.revision, itinerary[0], 0), path + " starts")
	var wealth := int(content.startingVault)
	var fees := 0
	for i in range(4):
		var site: String = Run.Variants.TABLES[i]
		verify(run_game.scene_id == itinerary[i] and run_game.completed.size() == i, path + " reaches assigned table " + site)
		var projected_heat: int = run_game.heat + int(run_game.table_definition(site).heatGain) + int(run_game.scene_definition().entryHeatBonus)
		if run_game.heat > 0 and (cool_eagerly or projected_heat >= 5) and not run_game.heat_reduced:
			var cooling: int = run_game.scene_definition().heatReductionCost
			if run_game.service_action("cool", "", run_game.revision):
				wealth -= cooling
				fees += cooling
		var table: RefCounted = run_game.enter_table(int(run_game.variant_plan.table_seeds[site]), run_game.revision, site)
		if table == null:
			return row(itinerary, "table_blocked", i, fees, run_game, run_game.table_blocked_reason(site))
		finish(table)
		var gain: int = int(table.state.players[0].stack) - int(table.state.tableDef.buyIn)
		verify(run_game.settle_table(run_game.revision), path + " settles " + site)
		wealth += gain
		if run_game.last_table_result.reward_added:
			wealth += int(content.items[run_game.last_table_result.reward].value)
		verify(run_game.vault + run_game.cash + run_game.valuable_total() == wealth, path + " wealth balances after " + site)
		if run_game.enforce_pressure():
			wealth -= int(run_game.last_result.fee) + int(run_game.last_result.lostCash) + int(run_game.last_result.lostGoods)
			verify(run_game.vault == wealth and not run_game.active and run_game.last_result.forced, path + " forced result balances")
			return row(itinerary, "forced", i + 1, fees, run_game, "heat 6 after " + site)
		if i == 3:
			var exit_quote: Dictionary = run_game.extraction_quote()
			if not exit_quote.reason.is_empty():
				return row(itinerary, "exit_blocked", 4, fees, run_game, exit_quote.reason)
			verify(run_game.extract(run_game.revision), path + " extracts")
			wealth -= int(exit_quote.fee)
			verify(run_game.vault == wealth, path + " final vault balances")
			verify(run_game.venue_history == itinerary and run_game.last_result.journey == run_game.transfer_log and run_game.transfer_log.size() == 3, path + " preserves full journey")
			return row(itinerary, "complete", 4, fees + int(exit_quote.fee), run_game, "")
		var destination: String = itinerary[i + 1]
		var quote: Dictionary = run_game.transfer_quote(destination)
		if not quote.reason.is_empty():
			return row(itinerary, "transfer_blocked", i + 1, fees, run_game, quote.reason)
		verify(run_game.transfer_venue(destination, run_game.revision), path + " transfers to " + destination)
		wealth -= int(quote.fee)
		fees += int(quote.fee)
		verify(run_game.vault + run_game.cash + run_game.valuable_total() == wealth, path + " wealth balances after transfer")
		verify(not run_game.public_exit and run_game.route_flags.is_empty() and run_game.arrival_completed == i + 1, path + " resets local exit intel")
		var restored: RefCounted = Checkpoint.restore(Checkpoint.capture(run_game), content)
		verify(restored != null and Checkpoint.capture(restored) == Checkpoint.capture(run_game), path + " restores between venues")
		if restored != null:
			run_game = restored
	return row(itinerary, "incomplete", run_game.completed.size(), fees, run_game, "loop ended")

func finish(table: RefCounted) -> void:
	var steps := 0
	while table.state.status != "finished" and steps < 200:
		steps += 1
		if table.state.status == "hand_over":
			table.next_hand(table.revision)
		elif table.state.currentActorId.is_empty():
			table.advance(table.revision)
		else:
			var actor: String = table.state.currentActorId
			var legal: Dictionary = table.legal_actions(actor)
			verify(table.act(actor, "fold" if actor != "player" else ("check" if legal.check else "call"), table.revision), "Scripted action is legal")
	verify(table.state.status == "finished", "Table ends within 200 steps")

func row(itinerary: Array, outcome: String, tables: int, fees: int, run_game: RefCounted, reason: String) -> Dictionary:
	return {"itinerary":itinerary, "outcome":outcome, "tables":tables, "fees":fees, "heat":run_game.heat, "cash":run_game.cash, "vault":run_game.vault, "reason":reason}

func count_outcomes(rows: Array) -> Dictionary:
	var counts := {}
	for item in rows:
		counts[item.outcome] = int(counts.get(item.outcome, 0)) + 1
	return counts
