extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Checkpoint = preload("res://three_d/rules/run_checkpoint.gd")
const Opponent = preload("res://three_d/rules/opponent.gd")
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
	var ai_rows: Array = []
	var guided_rows: Array = []
	var single_venue_rows: Array = []
	for first in scenes:
		for second in scenes:
			if second == first: continue
			for third in scenes:
				if third in [first, second]: continue
				for fourth in scenes:
					if fourth in [first, second, third]: continue
					var itinerary := [first, second, third, fourth]
					rows.append(simulate(content, itinerary, false, 0, false))
					eager_rows.append(simulate(content, itinerary, true, 0, false))
	for seed_value in [1, 17, 97]:
		for start_index in range(scenes.size()):
			var itinerary: Array = []
			for offset in range(scenes.size()):
				itinerary.append(scenes[(start_index + offset) % scenes.size()])
			ai_rows.append(simulate(content, itinerary, false, seed_value, true))
			guided_rows.append(simulate(content, itinerary, false, seed_value, true, "equity-guided"))
			single_venue_rows.append(simulate(content, [scenes[start_index], scenes[start_index], scenes[start_index], scenes[start_index]], false, seed_value, true))
			single_venue_rows.append(simulate(content, [scenes[start_index], scenes[start_index], scenes[start_index], scenes[start_index]], false, seed_value, true, "equity-guided"))
	verify(rows.size() == 24, "All four-venue visit orders sampled")
	verify(rows.all(func(item): return item.outcome == "complete"), "Every venue order reaches final extraction under scripted policy")
	verify(eager_rows.size() == 24 and eager_rows.any(func(item): return item.outcome == "table_blocked"), "Cooling at every opportunity can prevent final buy-in")
	verify(ai_rows.size() == 12, "Three seeds sample each starting venue against live AI")
	verify(guided_rows.size() == 12, "Same live AI seeds sampled with equity-guided player")
	verify(single_venue_rows.size() == 24, "Same live AI seeds sampled without travel")
	var report := {"checks":checks, "failed":failures.size(), "failures":failures, "runs":rows, "eager_cooling_comparison":eager_rows, "live_ai_sample":ai_rows, "guided_ai_sample":guided_rows, "single_venue_ai_sample":single_venue_rows, "scope":"Seed 0 compares two cooling policies with folding opponents across 24 venue orders. Three positive seeds and four cyclic orders compare passive and equity-guided players against production AI, both across four venues and within one venue. These measure scripted reachability and economy, not human skill, win rate or duration."}
	FileAccess.open("res://../output/3d/venue-order-matrix.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("VENUE_ORDER ", JSON.stringify({"checks":checks, "failed":failures.size(), "outcomes":count_outcomes(rows), "eager_cooling_outcomes":count_outcomes(eager_rows), "live_ai_outcomes":count_outcomes(ai_rows), "guided_ai_outcomes":count_outcomes(guided_rows), "single_venue_ai_outcomes":count_outcomes(single_venue_rows), "failures":failures}))
	quit(0 if failures.is_empty() else 1)

func simulate(content: Dictionary, itinerary: Array, cool_eagerly: bool, seed_value: int, live_ai: bool, player_policy := "passive") -> Dictionary:
	var run_game := Run.new(content)
	var path: String = "→".join(itinerary) + " seed " + str(seed_value)
	verify(run_game.start(run_game.revision, itinerary[0], seed_value), path + " starts")
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
			return row(itinerary, "table_blocked", i, fees, run_game, run_game.table_blocked_reason(site), seed_value, player_policy)
		finish(table, content, live_ai, player_policy)
		var gain: int = int(table.state.players[0].stack) - int(table.state.tableDef.buyIn)
		verify(run_game.settle_table(run_game.revision), path + " settles " + site)
		wealth += gain
		if run_game.last_table_result.reward_added:
			wealth += int(content.items[run_game.last_table_result.reward].value)
		verify(run_game.vault + run_game.cash + run_game.valuable_total() == wealth, path + " wealth balances after " + site)
		if run_game.enforce_pressure():
			wealth -= int(run_game.last_result.fee) + int(run_game.last_result.lostCash) + int(run_game.last_result.lostGoods)
			verify(run_game.vault == wealth and not run_game.active and run_game.last_result.forced, path + " forced result balances")
			return row(itinerary, "forced", i + 1, fees, run_game, "heat 6 after " + site, seed_value, player_policy)
		if live_ai and i == 0:
			verify(run_game.extraction_quote().reason.is_empty(), path + " can bank after first table")
		if i == 3:
			var exit_kind := ""
			var exit_quote := {}
			for kind in Run.Routes.NAMES:
				if not run_game.route_known(kind): continue
				var option: Dictionary = run_game.extraction_quote(kind)
				if option.reason.is_empty() and (exit_kind.is_empty() or option.net > exit_quote.net):
					exit_kind = kind
					exit_quote = option
			if exit_kind.is_empty():
				return row(itinerary, "exit_blocked", 4, fees, run_game, run_game.extraction_quote().reason, seed_value, player_policy)
			verify(run_game.extract(run_game.revision, exit_kind), path + " extracts")
			wealth -= int(exit_quote.fee) + int(exit_quote.lostCash) + int(exit_quote.lostGoods)
			verify(run_game.vault == wealth, path + " final vault balances")
			var expected_history: Array = [itinerary[0]] if itinerary[0] == itinerary[3] else itinerary
			verify(run_game.venue_history == expected_history and run_game.last_result.journey == run_game.transfer_log and run_game.transfer_log.size() == expected_history.size() - 1, path + " preserves full journey")
			var result: Dictionary = row(itinerary, "complete", 4, fees + int(exit_quote.fee), run_game, "", seed_value, player_policy)
			result["exit_route"] = exit_kind
			return result
		var destination: String = itinerary[i + 1]
		if destination == run_game.scene_id:
			continue
		var quote: Dictionary = run_game.transfer_quote(destination)
		if not quote.reason.is_empty():
			return row(itinerary, "transfer_blocked", i + 1, fees, run_game, quote.reason, seed_value, player_policy)
		verify(run_game.transfer_venue(destination, run_game.revision), path + " transfers to " + destination)
		wealth -= int(quote.fee)
		fees += int(quote.fee)
		verify(run_game.vault + run_game.cash + run_game.valuable_total() == wealth, path + " wealth balances after transfer")
		verify(not run_game.public_exit and run_game.route_flags.is_empty() and run_game.arrival_completed == i + 1, path + " resets local exit intel")
		var restored: RefCounted = Checkpoint.restore(Checkpoint.capture(run_game), content)
		verify(restored != null and Checkpoint.capture(restored) == Checkpoint.capture(run_game), path + " restores between venues")
		if restored != null:
			run_game = restored
	return row(itinerary, "incomplete", run_game.completed.size(), fees, run_game, "loop ended", seed_value, player_policy)

func finish(table: RefCounted, content: Dictionary, live_ai: bool, player_policy: String) -> void:
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
			var decision: String = "check" if legal.check else ("call" if legal.call else "all-in")
			if actor != "player":
				decision = Opponent.choose(table.state, table.find_player(actor), legal, content.opponents[actor], table.rng.next()) if live_ai else "fold"
			elif player_policy == "equity-guided":
				var player: Dictionary = table.find_player(actor)
				var others: int = table.state.players.filter(func(p): return p.id != actor and not p.folded).size()
				var odds: float = Opponent.estimate_odds(player.holeCards, table.state.community, others, table.state.seed + table.state.handNumber * 137 + table.state.turnCounter * 19, 35)
				if odds < 0.27 and legal.fold and not legal.check: decision = "fold"
				elif odds > 0.68 and legal.raise: decision = "raise"
			verify(table.act(actor, decision, table.revision), "Scripted action is legal")
	verify(table.state.status == "finished", "Table ends within 200 steps")

func row(itinerary: Array, outcome: String, tables: int, fees: int, run_game: RefCounted, reason: String, seed_value: int, player_policy: String) -> Dictionary:
	return {"itinerary":itinerary, "seed":seed_value, "player_policy":player_policy, "outcome":outcome, "tables":tables, "fees":fees, "heat":run_game.heat, "cash":run_game.cash, "vault":run_game.vault, "reason":reason}

func count_outcomes(rows: Array) -> Dictionary:
	var counts := {}
	for item in rows:
		counts[item.outcome] = int(counts.get(item.outcome, 0)) + 1
	return counts
