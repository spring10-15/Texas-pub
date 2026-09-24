extends SceneTree
const Table = preload("res://three_d/rules/table.gd")
var failures: Array[String] = []
var checks := 0
var hits := {}
var seat_variant_evidence: Array[Dictionary] = []
func record(key: String, failure_count: int) -> void:
	if failures.size() == failure_count:
		hits["queue."+key] = {"test":"short_stack_queue_test.gd","postcondition_verified":true}
func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)

func record_seat_case(family: String, table_id: String, seat: int, checks_before: int, failures_before: int) -> void:
	seat_variant_evidence.append({"family": family, "table": table_id, "seat": seat, "checks": checks - checks_before, "passed": failures.size() == failures_before})
func verify_all_in_seat(definition: Dictionary, short_seat: int, exact: bool) -> void:
	var t := Table.new()
	t.start(definition,7)
	if short_seat == 1:
		verify(t.act(t.state.currentActorId,"call",t.revision),"Seat setup reaches small blind action")
	elif short_seat == 2:
		verify(t.act(t.state.currentActorId,"raise",t.revision),"Seat setup reaches a full raise before big blind")
		verify(t.act(t.state.currentActorId,"call",t.revision),"Seat setup reaches big blind action")
	var actor: Dictionary = t.state.players[short_seat]
	var cost: int = int(t.state.currentBet)-int(actor.currentBet)
	var required_stack: int = cost if exact else cost-1
	var donor: Dictionary = t.state.players[(short_seat+1)%t.state.players.size()]
	donor.stack += int(actor.stack)-required_stack
	actor.stack = required_stack
	var queue_before: Array = t.state.toAct.duplicate()
	var remaining: Array = queue_before.slice(1)
	var target_before: int = t.state.currentBet
	var pot_before: int = t.state.pot
	var wealth_before: int = pot_before
	for player in t.state.players: wealth_before += int(player.stack)
	var discount_before: bool = t.state.firstAggressionDiscountAvailable
	var raise_used_before: bool = t.state.raiseUsed
	var accepted: bool = t.state.currentActorId == actor.id and required_stack > 0 and t.act(actor.id,"all-in",t.revision)
	var wealth_after: int = int(t.state.pot)
	for player in t.state.players: wealth_after += int(player.stack)
	var label: String = definition.id+" seat="+str(short_seat)+" exact="+str(exact)
	verify(accepted,"Short/exact all-in accepted at each acting seat: "+label)
	verify(actor.stack == 0 and int(t.state.pot) == pot_before+required_stack,"Contribution enters pot once: "+label)
	verify(t.state.currentBet == target_before and t.state.raiseUsed == raise_used_before,"Call-sized all-in preserves the target and raise-right state: "+label)
	verify(t.state.toAct == remaining and t.state.currentActorId == (remaining[0] if not remaining.is_empty() else ""),"Remaining actors retain queue order: "+label)
	verify(t.state.firstAggressionDiscountAvailable == discount_before,"Call-sized all-in preserves first-aggression discount: "+label)
	verify(wealth_after == wealth_before,"Seat-variant action conserves table wealth: "+label)

func finish_check_call_hand(t: RefCounted) -> bool:
	var steps := 0
	while t.state.status == "playing" and steps < 100:
		steps += 1
		if t.state.currentActorId.is_empty():
			if not t.advance(t.revision): return false
		else:
			var actor_id: String = t.state.currentActorId
			var legal: Dictionary = t.legal_actions(actor_id)
			var action: String = "check" if legal.get("check", false) else "call"
			if not legal.get(action, false) or not t.act(actor_id, action, t.revision): return false
	return t.state.status == "hand_over"

func verify_short_raise_seat(definition: Dictionary, short_seat: int) -> void:
	var table_definition: Dictionary = definition.duplicate(true)
	table_definition.hands = 5
	table_definition.buyIn = int(table_definition.openBet) * 20
	var t := Table.new()
	t.start(table_definition, 7)
	var rotations := 0
	while t.state.dealerSeat != short_seat and rotations < 3:
		var hand_before: int = t.state.handNumber
		var completed := finish_check_call_hand(t)
		var advanced := completed and t.next_hand(t.revision)
		verify(advanced and t.state.handNumber == hand_before + 1, "Real check/call hands rotate dealer to target seat")
		if not advanced: return
		rotations += 1
	if t.state.dealerSeat != short_seat:
		verify(false, "Dealer reaches target seat before short raise")
		return
	# Complete the real preflop queue, then let the dealer act after both opponents on the flop.
	while not t.state.currentActorId.is_empty():
		var actor_id: String = t.state.currentActorId
		var legal: Dictionary = t.legal_actions(actor_id)
		var action: String = "check" if legal.get("check", false) else "call"
		verify(legal.get(action, false) and t.act(actor_id, action, t.revision), "Preflop caller reaches flop in target-seat fixture")
	verify(t.state.currentActorId.is_empty() and t.advance(t.revision) and t.state.street == "flop", "Flop begins with the real postflop seat order")
	var prior_seats: Array = [(short_seat + 1) % 3, (short_seat + 2) % 3]
	for prior_seat in prior_seats:
		var prior_id: String = t.state.players[prior_seat].id
		var legal: Dictionary = t.legal_actions(prior_id)
		verify(t.state.currentActorId == prior_id and legal.get("check", false) and t.act(prior_id, "check", t.revision), "Earlier flop seat checks before target raise")
	var actor: Dictionary = t.state.players[short_seat]
	var needed: int = int(t.state.tableDef.openBet) - 1
	var donor: Dictionary = t.state.players[(short_seat + 1) % 3]
	var wealth_before_setup: int = int(t.state.pot)
	for player in t.state.players: wealth_before_setup += int(player.stack)
	donor.stack += int(actor.stack) - needed
	actor.stack = needed
	var wealth_before: int = int(t.state.pot)
	for player in t.state.players: wealth_before += int(player.stack)
	verify(wealth_before == wealth_before_setup, "Short raise seat fixture only redistributes existing chips")
	var accepted: bool = t.state.currentActorId == actor.id and needed > 0 and t.act(actor.id, "all-in", t.revision)
	var label: String = str(definition.id) + " short_raise_seat=" + str(short_seat)
	var expected_recall: Array = [t.state.players[(short_seat + 1) % 3].id, t.state.players[(short_seat + 2) % 3].id]
	verify(accepted and t.state.currentBet == needed and needed < int(t.state.tableDef.openBet), "Short all-in raises below the opening bet: " + label)
	verify(t.state.raiseUsed and not t.state.firstAggressionDiscountAvailable and t.state.toAct == expected_recall and t.state.currentActorId == expected_recall[0], "Short raise recalls both earlier seats and spends the street raise: " + label)
	for recalled_id in expected_recall:
		var legal: Dictionary = t.legal_actions(recalled_id)
		verify(legal.get("call", false) and not legal.get("raise", false), "Recalled seat can call but cannot raise: " + label + "/" + recalled_id)
		verify(t.act(recalled_id, "call", t.revision), "Recalled seat matches short target: " + label + "/" + recalled_id)
	verify(t.state.toAct.is_empty() and t.state.currentActorId.is_empty(), "Matched calls close the round: " + label)
	var wealth_after: int = int(t.state.pot)
	for player in t.state.players: wealth_after += int(player.stack)
	verify(wealth_after == wealth_before, "Short raise seat case conserves table wealth: " + label)

func verify_lone_funded_seat(definition: Dictionary, funded_seat: int) -> void:
	var table_definition: Dictionary = definition.duplicate(true)
	table_definition.hands = 8
	table_definition.buyIn = int(table_definition.openBet) * 1000
	var t := Table.new()
	t.start(table_definition, 11)
	var desired_dealer: int = (funded_seat + 1) % 3
	var prior_dealer: int = (desired_dealer + 2) % 3
	var rotations := 0
	while t.state.dealerSeat != prior_dealer and rotations < 3:
		var completed := finish_check_call_hand(t)
		var advanced := completed and t.next_hand(t.revision)
		verify(advanced, "Real hands rotate button before lone-funded seat fixture")
		if not advanced: return
		rotations += 1
	if t.state.dealerSeat != prior_dealer:
		verify(false, "Button reaches seat before target big blind")
		return
	var completed := finish_check_call_hand(t)
	verify(completed, "Complete hand before assigning one funded seat")
	if not completed: return
	var total_wealth: int = 0
	for player in t.state.players: total_wealth += int(player.stack)
	var other_a: int = (funded_seat + 1) % 3
	var other_b: int = (funded_seat + 2) % 3
	t.state.players[funded_seat].stack = table_definition.buyIn * 2
	t.state.players[other_a].stack = table_definition.buyIn / 2
	t.state.players[other_b].stack = table_definition.buyIn - table_definition.buyIn / 2
	var wealth_after_setup: int = 0
	for player in t.state.players: wealth_after_setup += int(player.stack)
	var next_ok: bool = t.next_hand(t.revision)
	var label: String = str(definition.id) + " funded_seat=" + str(funded_seat)
	verify(next_ok and t.state.dealerSeat == desired_dealer and wealth_after_setup == total_wealth, "Next hand places target at big blind without changing table wealth: " + label)
	var dealer_id: String = t.state.players[desired_dealer].id
	var small_id: String = t.state.players[(desired_dealer + 1) % 3].id
	var funded_id: String = t.state.players[funded_seat].id
	verify(t.state.currentActorId == dealer_id and t.act(dealer_id, "all-in", t.revision), "Dealer makes first all-in raise: " + label)
	verify(t.state.currentActorId == small_id and t.act(small_id, "all-in", t.revision), "Small blind calls all-in before funded big blind: " + label)
	var legal: Dictionary = t.legal_actions(funded_id)
	verify(t.state.currentActorId == funded_id and t.state.toAct == [funded_id] and legal.get("call", false) and not legal.get("raise", false), "Only funded seat owes a call and cannot reopen the raise: " + label)
	verify(t.act(funded_id, "call", t.revision) and t.state.toAct.is_empty() and t.state.currentActorId.is_empty(), "Funded seat matches and leaves no betting action: " + label)
	for street in ["flop", "turn", "river"]:
		var advanced: bool = t.advance(t.revision)
		verify(advanced and t.state.street == street and t.state.currentActorId.is_empty() and t.state.toAct.is_empty(), "One funded seat runs out board without a phantom action: " + label + "/" + street)
	verify(t.advance(t.revision) and t.state.summary.get("kind", "") == "showdown", "Lone-funded hand settles at showdown: " + label)
	var final_wealth: int = 0
	for player in t.state.players: final_wealth += int(player.stack)
	verify(final_wealth == total_wealth, "Lone-funded seat runout conserves wealth: " + label)

func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	for table_id in content.tables:
		for short_seat in range(3):
			for exact in [false,true]:
				var checks_before := checks
				var failures_before := failures.size()
				verify_all_in_seat(content.tables[table_id],short_seat,exact)
				record_seat_case("exact_call_all_in" if exact else "short_all_in", table_id, short_seat, checks_before, failures_before)
			var checks_before := checks
			var failures_before := failures.size()
			verify_short_raise_seat(content.tables[table_id], short_seat)
			record_seat_case("short_all_in_raise", table_id, short_seat, checks_before, failures_before)
			checks_before = checks
			failures_before = failures.size()
			verify_lone_funded_seat(content.tables[table_id], short_seat)
			record_seat_case("lone_funded_heads_up", table_id, short_seat, checks_before, failures_before)
	for table_id in content.tables:
		for exact in [false,true]:
			var failure_count := failures.size()
			var t := Table.new()
			t.start(content.tables[table_id],7)
			var p: Dictionary = t.state.players[0]
			var amount: int = t.state.currentBet-(0 if exact else 1)
			t.state.players[1].stack += p.stack-amount
			p.stack = amount
			var rng_before: int = t.rng.value
			var deck_before: Array = t.state.deck.duplicate()
			var revision_before: int = t.revision
			var target: int = t.state.currentBet
			var pot: int = t.state.pot
			verify(t.act("player","call" if exact else "all-in",t.revision) and p.stack == 0 and t.state.currentBet == target and t.state.pot == pot+amount,"Short/exact contribution "+table_id+str(exact))
			verify(t.state.toAct == [t.state.players[1].id,t.state.players[2].id] and not t.state.raiseUsed,"Short/exact preserves remaining queue "+table_id)
			verify(t.rng.value == rng_before and t.state.deck == deck_before and t.revision == revision_before+1,"Action preserves deal and increments revision "+table_id)
			var wealth: int = t.state.pot
			for person in t.state.players: wealth += int(person.stack)
			verify(wealth == int(content.tables[table_id].buyIn)*3,"Short/exact preserves wealth "+table_id)
			record("exact_call_all_in" if exact else "short_all_in",failure_count)
		var failure_count := failures.size()
		var t := Table.new()
		t.start(content.tables[table_id],7)
		t.act("player","call",t.revision)
		var raiser: String = t.state.currentActorId
		verify(t.act(raiser,"raise",t.revision) and t.state.toAct == [t.state.players[2].id,"player"],"Raise recalls prior caller "+table_id)
		t.act(t.state.currentActorId,"call",t.revision)
		verify(t.state.currentActorId == "player","Original caller owes new amount "+table_id)
		record("raise_reopens_prior_caller",failure_count)
		failure_count = failures.size()
		t.act("player","call",t.revision)
		verify(t.state.currentActorId.is_empty() and t.state.toAct.is_empty(),"Matched round ends "+table_id)
		record("matched_round_ends",failure_count)
		failure_count = failures.size()
		# Preserve total wealth while moving chips into the player's stack before posting blinds.
		t = Table.new()
		t.start(content.tables[table_id],7)
		var buy_in: int = content.tables[table_id].buyIn
		t.state.players[0].stack = buy_in*2
		t.state.players[1].stack = buy_in/2
		t.state.players[2].stack = buy_in-buy_in/2
		t.start_hand()
		t.act("player","call",t.revision)
		t.act(t.state.currentActorId,"all-in",t.revision)
		t.act(t.state.currentActorId,"all-in",t.revision)
		verify(t.state.currentActorId == "player" and t.state.toAct == ["player"],"Lone funded player still owes call "+table_id)
		record("lone_funded_owes",failure_count)
		failure_count = failures.size()
		t.act("player","call",t.revision)
		verify(t.state.players[0].stack > 0 and t.state.toAct.is_empty(),"Lone funded matched player skips betting "+table_id)
		record("lone_funded_matched",failure_count)
		failure_count = failures.size()
		for street in ["flop","turn","river"]:
			var deck: Array = t.state.deck.duplicate()
			var community: Array = t.state.community.duplicate()
			var rng_value: int = t.rng.value
			var pot_before: int = t.state.pot
			for card in range(3 if street == "flop" else 1): community.append(deck.pop_back())
			verify(t.advance(t.revision) and t.state.street == street and t.state.toAct.is_empty(),"All-in board runs out "+table_id+street)
			verify(t.state.deck == deck and t.state.community == community and t.rng.value == rng_value and t.state.pot == pot_before and t.state.currentActorId.is_empty(),"Runout preserves pot and consumes expected cards "+table_id+street)
		record("lone_funded_runout",failure_count)
		failure_count = failures.size()
		verify(t.advance(t.revision) and t.state.summary.kind == "showdown","Runout reaches showdown "+table_id)
		var total := 0
		for p in t.state.players: total += int(p.stack)
		verify(total == buy_in*3,"Runout wealth conserved "+table_id)
		record("runout_showdown_conserves",failure_count)
	# An all-in that raises the target must recall a player who had already called.
	var t := Table.new()
	t.start(content.tables["cargo-table"],7)
	t.act("player","call",t.revision)
	t.state.players[1].stack = 50
	var all_in_target: int = int(t.state.players[1].currentBet)+int(t.state.players[1].stack)
	var reopened := t.act(t.state.players[1].id,"all-in",t.revision)
	var reopen_ok: bool = reopened and all_in_target > 20 and t.state.currentBet == all_in_target and t.state.toAct == [t.state.players[2].id,"player"] and t.state.raiseUsed
	verify(reopen_ok,"All-in raise recalls prior caller")
	if reopen_ok: hits["queue.all_in_raise_reopens_prior_caller"] = {"test":"short_stack_queue_test.gd","postcondition_verified":true}
	# The documented one-raise-per-street rule recalls callers without reopening raises.
	var short_raise := Table.new()
	short_raise.start(content.tables["cargo-table"],7)
	short_raise.act("player","call",short_raise.revision)
	short_raise.state.players[1].stack = 15
	short_raise.state.players[2].stack += 35
	var target_before: int = short_raise.state.currentBet
	var short_raise_target: int = int(short_raise.state.players[1].currentBet)+int(short_raise.state.players[1].stack)
	var short_raise_accepted: bool = short_raise.act(short_raise.state.players[1].id,"all-in",short_raise.revision)
	var actor_legal: Dictionary = short_raise.legal_actions(short_raise.state.currentActorId)
	var one_raise_ok: bool = short_raise_accepted and short_raise_target > target_before and short_raise.state.currentBet == short_raise_target and short_raise.state.toAct == [short_raise.state.players[2].id,"player"] and short_raise.state.raiseUsed and not short_raise.state.firstAggressionDiscountAvailable and not actor_legal.raise
	if one_raise_ok:
		var unacted_raise_actor: String = short_raise.state.currentActorId
		short_raise.act(unacted_raise_actor,"call",short_raise.revision)
		var caller_legal: Dictionary = short_raise.legal_actions("player")
		one_raise_ok = short_raise.state.currentActorId == "player" and caller_legal.call and not caller_legal.raise
	verify(one_raise_ok,"Short all-in recalls callers but keeps the street raise locked")
	if one_raise_ok: hits["queue.short_all_in_raise_one_raise_rule"] = {"test":"short_stack_queue_test.gd","postcondition_verified":true}
	write_report()
	print("SHORT_STACK_QUEUE checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
func write_report() -> void:
	var catalog_text := FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json")
	var catalog: Dictionary = JSON.parse_string(catalog_text)
	var expected: Array = catalog.transitions.filter(func(row): return str(row.id).begins_with("queue.")).map(func(row): return row.id)
	for id in hits:
		if id not in expected: failures.append("Uncatalogued hit: "+id)
	var missing: Array = expected.filter(func(id): return not hits.has(id))
	for id in missing: failures.append("Missing: "+id)
	var hashes := {}
	for file in DirAccess.get_files_at("res://three_d/rules"):
		if file.ends_with(".gd") or file.ends_with(".json"):
			hashes[file] = FileAccess.get_file_as_string("res://three_d/rules/"+file).sha256_text()
	var report := {"scope":"queue subgraph fixtures only","source_sha256":hashes,"test_sha256":FileAccess.get_file_as_string("res://three_d/tests/short_stack_queue_test.gd").sha256_text(),"catalog_sha256":catalog_text.sha256_text(),"denominator":expected.size(),"numerator":hits.size(),"checks":checks,"seat_variant_cases":seat_variant_evidence,"missing":missing,"failures":failures,"hits":hits,"overall_state_transition_coverage":null}
	FileAccess.open("res://../output/3d/queue-coverage.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
