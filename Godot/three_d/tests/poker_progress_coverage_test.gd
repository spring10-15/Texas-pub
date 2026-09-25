extends SceneTree
const Table = preload("res://three_d/rules/table.gd")
const Checkpoint = preload("res://three_d/rules/table_checkpoint.gd")
const Poker = preload("res://three_d/rules/poker.gd")
var failures: Array[String] = []
var hits := {}
func round_actions(t: RefCounted) -> void:
	for step in range(12):
		if t.state.currentActorId.is_empty(): return
		var actor: String = t.state.currentActorId
		var legal: Dictionary = t.legal_actions(actor)
		t.act(actor,"check" if legal.check else "call",t.revision)
	failures.append("Action round did not end")
func record(key: String, ok: bool, table_id: String) -> void:
	var id := "poker_progress."+key
	if ok: hits[id] = {"test":"poker_progress_coverage_test.gd","postcondition_verified":true}
	else: failures.append(id+"/"+table_id); push_error(failures.back())
func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json"))
	for table_id in content.tables:
		var t := Table.new()
		t.start(content.tables[table_id],7)
		var expected_rng := Poker.DeterministicRng.new(7)
		var expected_deck: Array = Poker.shuffle_deck(Poker.create_deck(), expected_rng)
		var expected_holes := [[], [], []]
		for deal_round in range(2):
			for seat in [1, 2, 0]: expected_holes[seat].append(expected_deck.pop_back())
		var dealt_exactly: bool = t.state.deck == expected_deck and t.rng.value == expected_rng.value and t.revision == 1 and t.state.players.size() == 3
		for seat in range(3): dealt_exactly = dealt_exactly and t.state.players[seat].holeCards == expected_holes[seat]
		record("seeded_deal",dealt_exactly,table_id)
		var before := Checkpoint.capture(t)
		record("actor_pending",not t.advance(t.revision) and Checkpoint.capture(t) == before,table_id)
		record("next_while_playing",not t.next_hand(t.revision) and Checkpoint.capture(t) == before,table_id)
		for street in ["flop","turn","river"]:
			round_actions(t)
			before = Checkpoint.capture(t)
			record("advance_stale",not t.advance(t.revision-1) and Checkpoint.capture(t) == before,table_id)
			var deck: Array = before.state.deck.duplicate(true)
			var community: Array = before.state.community.duplicate(true)
			for i in range(3 if street == "flop" else 1): community.append(deck.pop_back())
			var ok: bool = t.advance(t.revision) and t.state.street == street and t.state.community == community and t.state.deck == deck and t.rng.value == before.rngValue and t.revision == before.revision+1
			ok = ok and t.state.pot == before.state.pot and t.state.currentBet == 0 and not t.state.raiseUsed and t.state.currentActorId == t.state.players[1].id
			for p in t.state.players: ok = ok and p.currentBet == 0 and p.stack == before.state.players[p.seatIndex].stack and p.handContribution == before.state.players[p.seatIndex].handContribution and p.holeCards == before.state.players[p.seatIndex].holeCards
			record(street,ok,table_id)
		round_actions(t)
		before = Checkpoint.capture(t)
		var ok: bool = t.advance(t.revision) and t.state.summary.kind == "showdown" and t.state.summary.pot == before.state.pot and t.state.status == "hand_over"
		var paid := 0
		var wealth := 0
		for p in t.state.players:
			paid += int(t.state.summary.awards[p.id])
			wealth += int(p.stack)
			ok = ok and p.stack == before.state.players[p.seatIndex].stack+int(t.state.summary.awards[p.id])
		ok = ok and paid == before.state.pot and wealth == int(content.tables[table_id].buyIn)*3 and t.state.toAct.is_empty() and t.state.currentActorId.is_empty() and t.state.pendingNextHand and not t.state.pendingConclusion
		record("showdown",ok,table_id)
		before = Checkpoint.capture(t)
		record("advance_finished_hand",not t.advance(t.revision) and Checkpoint.capture(t) == before,table_id)
		record("next_stale",not t.next_hand(t.revision-1) and Checkpoint.capture(t) == before,table_id)
		ok = t.next_hand(t.revision) and t.state.handNumber == 2 and t.revision == before.revision+1 and t.state.street == "preflop" and t.state.community.is_empty() and t.state.summary.is_empty()
		wealth = t.state.pot
		for p in t.state.players:
			wealth += int(p.stack)
			ok = ok and p.holeCards.size() == 2 and p.handContribution == p.currentBet
		ok = ok and wealth == int(content.tables[table_id].buyIn)*3 and t.state.pot == int(content.tables[table_id].smallBlind)+int(content.tables[table_id].openBet) and t.state.dealerSeat == 1 and t.state.currentActorId == t.state.players[1].id
		record("next_hand",ok,table_id)
		for busted in [1,2]:
			var duel := Table.new()
			var definition: Dictionary = content.tables[table_id].duplicate(true)
			definition.hands = 3
			duel.start(definition,7)
			var funded: int = 2 if busted == 1 else 1
			var buy_in: int = int(definition.buyIn)
			duel.state.players[0].stack = buy_in
			duel.state.players[funded].stack = buy_in * 2
			duel.state.players[busted].stack = 0
			duel.start_hand()
			var first_dealer: int = duel.state.dealerSeat
			var started: bool = first_dealer == 0 and duel.state.smallBlindSeat == 0 and duel.state.bigBlindSeat == funded and duel.state.currentActorId == duel.state.players[0].id
			duel.act(duel.state.currentActorId,"fold",duel.revision)
			var duel_before := Checkpoint.capture(duel)
			var rotated: bool = duel.state.status == "hand_over" and duel.next_hand(duel.revision)
			rotated = rotated and duel.revision == duel_before.revision + 1 and duel.state.handNumber == 2 and duel.state.dealerSeat == funded and duel.state.smallBlindSeat == funded and duel.state.bigBlindSeat == 0 and duel.state.currentActorId == duel.state.players[funded].id
			rotated = rotated and duel.state.players[busted].folded and duel.state.players[busted].holeCards.is_empty() and duel.state.players[0].holeCards.size() == 2 and duel.state.players[funded].holeCards.size() == 2 and duel.rng.value != duel_before.rngValue
			var duel_wealth: int = int(duel.state.pot)
			for participant in duel.state.players: duel_wealth += int(participant.stack)
			record("next_hand_heads_up",started and rotated and duel_wealth == buy_in * 3,table_id+"/busted="+str(busted))
	var expected: Array = catalog.transitions.filter(func(row): return str(row.id).begins_with("poker_progress.")).map(func(row): return row.id)
	for id in hits:
		if id not in expected: failures.append("Uncatalogued hit: "+id)
	var missing: Array = expected.filter(func(id): return not hits.has(id))
	var hashes := {}
	for file in DirAccess.get_files_at("res://three_d/rules"):
		if not (file.ends_with(".gd") or file.ends_with(".json")): continue
		hashes[file] = FileAccess.get_file_as_string("res://three_d/rules/"+file).sha256_text()
	var report := {"scope":"poker_progress subgraph only","source_sha256":hashes,"test_sha256":FileAccess.get_file_as_string("res://three_d/tests/poker_progress_coverage_test.gd").sha256_text(),"catalog_sha256":FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json").sha256_text(),"denominator":expected.size(),"numerator":hits.size(),"missing":missing,"failures":failures,"hits":hits,"overall_state_transition_coverage":null,"overall_status":"Other families not yet enumerated; no global percentage claimed."}
	FileAccess.open("res://../output/3d/poker_progress-coverage.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("POKER_PROGRESS_COVERAGE covered=",hits.size()," total=",expected.size()," missing=",missing," failures=",failures)
	quit(0 if failures.is_empty() and missing.is_empty() else 1)
