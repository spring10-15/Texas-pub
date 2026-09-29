extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Opponent = preload("res://three_d/rules/opponent.gd")
const SITES := ["cargo-table", "ledger-cellar", "mirror-hall", "embers-table"]
const VENUES := ["smoky-den", "high-rise-suite", "rooftop-club", "neon-poker-club"]
var checks := 0
var failures: Array[String] = []

func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func play(table: RefCounted, content: Dictionary) -> bool:
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
			var action := "check" if legal.check else ("call" if legal.call else "fold")
			if actor_id != "player":
				var actor: Dictionary = table.state.players.filter(func(p): return p.id == actor_id)[0]
				action = Opponent.choose(table.state, actor, legal, content.opponents[actor_id], 0.5)
			if not table.act(actor_id, action, table.revision): return false
	return table.state.status == "finished"

func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var complete := 0
	var early_extractions := 0
	var emergency_extractions := 0
	var abandonments := 0
	var blocked := {}
	for seed_value in range(12):
		var evening := Run.new(content)
		verify(evening.start(evening.revision, VENUES[0], seed_value), "Evening starts: " + str(seed_value))
		var expected: int = evening.vault + evening.cash + evening.valuable_total()
		var stopped := false
		for index in range(SITES.size()):
			var site: String = SITES[index]
			if index > 0:
				var transfer: Dictionary = evening.transfer_quote(VENUES[index])
				if not transfer.reason.is_empty():
					blocked[transfer.reason] = int(blocked.get(transfer.reason, 0)) + 1
					stopped = true
					break
				verify(evening.transfer_venue(VENUES[index], evening.revision), "Real-AI transfer succeeds")
				expected -= int(transfer.fee)
				verify(evening.vault + evening.cash + evening.valuable_total() == expected, "Transfer wealth balances")
			var projected: int = evening.heat + int(evening.table_definition(site).heatGain) + int(evening.scene_definition().entryHeatBonus)
			if evening.heat > 0 and projected >= 5:
				var cool_cost: int = int(evening.scene_definition().heatReductionCost)
				if evening.service_action("cool", "", evening.revision):
					expected -= cool_cost
			var reason: String = evening.table_blocked_reason(site)
			if not reason.is_empty():
				blocked[reason] = int(blocked.get(reason, 0)) + 1
				stopped = true
				break
			var table: RefCounted = evening.enter_table(int(evening.variant_plan.table_seeds[site]), evening.revision, site)
			verify(table != null and play(table, content), "Real-AI table finishes: " + site)
			if table == null or table.state.status != "finished":
				stopped = true
				break
			var buy_in: int = int(table.state.tableDef.buyIn)
			var stack: int = int(table.state.players[0].stack)
			verify(evening.settle_table(evening.revision), "Real-AI table settles: " + site)
			var result: Dictionary = evening.last_table_result
			expected += stack - buy_in + (int(content.items[result.reward].value) if result.reward_added else 0)
			verify(evening.vault + evening.cash + evening.valuable_total() == expected, "Real-AI table wealth balances: " + site)
		if stopped:
			if evening.table != null: continue
			var exit_quote: Dictionary = evening.extraction_quote("general")
			if exit_quote.reason.is_empty():
				verify(evening.extract(evening.revision, "general"), "Blocked evening can extract early")
				verify(evening.vault == expected - int(exit_quote.fee) and not evening.active, "Early extraction ledger balances")
				early_extractions += 1
			else:
				var emergency: Dictionary = evening.extraction_quote("dropbag-cash")
				if emergency.reason.is_empty():
					verify(evening.extract(evening.revision, "dropbag-cash"), "Blocked evening can use known emergency exit")
					verify(evening.vault == expected - int(emergency.fee) - int(emergency.lostCash) and not evening.active, "Emergency extraction ledger balances")
					emergency_extractions += 1
				else:
					var abandon_quote: Dictionary = evening.abandon_quote()
					verify(evening.abandon(evening.revision), "Blocked evening can abandon")
					verify(evening.vault == int(abandon_quote.vaultAfter) and not evening.active, "Abandonment ledger balances")
					abandonments += 1
			continue
		var quote: Dictionary = evening.extraction_quote("general")
		verify(quote.reason.is_empty(), "Four-table evening has public exit")
		if not quote.reason.is_empty(): continue
		verify(evening.extract(evening.revision, "general"), "Four-table evening extracts")
		verify(evening.vault == expected - int(quote.fee) and evening.completed.size() == 4, "Four-table evening final ledger balances")
		complete += 1
	verify(complete > 0 and complete + early_extractions + emergency_extractions + abandonments == 12, "Every real-AI evening reaches an accounted ending")
	print("REAL_AI_EVENING ", JSON.stringify({"seeds":12,"complete":complete,"early_extractions":early_extractions,"emergency_extractions":emergency_extractions,"abandonments":abandonments,"blocked":blocked,"checks":checks,"failed":failures.size(),"scope":"Twelve seeded four-venue real-AI attempts without completed-room fixtures; fixed conservative player strategy. Completion rate is a diagnostic, not a human difficulty measure."}))
	quit(0 if failures.is_empty() else 1)
