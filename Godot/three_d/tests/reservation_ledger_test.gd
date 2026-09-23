extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Checkpoint = preload("res://three_d/rules/run_checkpoint.gd")
var checks := 0
var failures: Array[String] = []
var cases := 0

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func finish_table(table: RefCounted, label: String) -> void:
	var steps := 0
	while table.state.status != "finished" and steps < 200:
		steps += 1
		if table.state.status == "hand_over":
			verify(table.next_hand(table.revision), label + " next hand")
		elif table.state.currentActorId.is_empty():
			verify(table.advance(table.revision), label + " advance")
		else:
			var actor: String = table.state.currentActorId
			var legal: Dictionary = table.legal_actions(actor)
			var action := "fold" if actor != "player" else ("check" if legal.check else "call")
			verify(table.act(actor, action, table.revision), label + " legal action")
	verify(table.state.status == "finished" and steps < 200, label + " finishes")

func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	for scene in Run.SCENE_NAMES:
		for offer in range(content.routes[scene].fixedRoutes.size()):
			var r: RefCounted
			for seed_value in range(1, 101):
				var candidate := Run.new(content)
				candidate.start(candidate.revision, scene, seed_value)
				if candidate.offer_index == offer:
					r = candidate
					break
			verify(r != null, scene + " offer " + str(offer) + " is seed reachable")
			if r == null: continue
			var label: String = scene + "/offer-" + str(offer)
			var wealth: int = r.vault + r.cash + r.valuable_total()
			for site in ["cargo-table", "ledger-cellar"]:
				var table: RefCounted = r.enter_table(int(r.variant_plan.table_seeds[site]), r.revision, site)
				verify(table != null, label + " enters " + site)
				if table == null: break
				var buy_in: int = int(table.state.tableDef.buyIn)
				finish_table(table, label + "/" + site)
				var returned: int = int(table.state.players[0].stack)
				verify(r.settle_table(r.revision), label + " settles " + site)
				var reward_value := int(content.items[r.last_table_result.reward].value) if r.last_table_result.reward_added else 0
				wealth += returned - buy_in + reward_value
				verify(r.vault + r.cash + r.valuable_total() == wealth, label + " table transfers and reward balance " + site)
			verify(r.completed.size() == 2 and r.inventory.size() == 2, label + " earns two separate valuables")
			var upfront: int = r.reserve_fee()
			var cash_before: int = r.cash
			verify(r.service_action("reserve", "", r.revision), label + " pays actual reservation")
			wealth -= upfront
			verify(r.cash == cash_before - upfront and r.vault + r.cash + r.valuable_total() == wealth, label + " upfront is debited once")
			var saved: Dictionary = Checkpoint.capture(r)
			r = Checkpoint.restore(saved, content)
			verify(r != null and Checkpoint.capture(r) == saved, label + " booked run restores")
			if r == null: continue
			var quote: Dictionary = r.extraction_quote("fixed")
			var final_fee: int = int(content.routes[scene].fixedRoutes[offer].finalCost)
			verify(quote.reason.is_empty() and quote.fee == final_fee and quote.net == r.cash - final_fee + r.valuable_total(), label + " independently calculates final payment")
			verify(r.extract(r.revision, "fixed"), label + " exits through booked route")
			wealth -= final_fee
			verify(r.vault == wealth and r.cash == 0 and r.inventory.is_empty() and r.last_result.net == quote.net, label + " final vault balances complete run")
			cases += 1
	verify(cases == 8, "All four venues and both offer variants complete")
	print("RESERVATION_LEDGER ", JSON.stringify({"cases": cases, "checks": checks, "failed": failures.size(), "failures": failures, "scope": "Eight seeded two-table runs with controlled folding opponents, real rewards, paid reservation, save/restore and fixed-route extraction; not live AI difficulty or human playtest evidence."}))
	quit(0 if failures.is_empty() else 1)
