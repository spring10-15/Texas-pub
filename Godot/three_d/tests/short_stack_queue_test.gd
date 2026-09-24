extends SceneTree
const Table = preload("res://three_d/rules/table.gd")
var failures: Array[String] = []
var checks := 0
var hits := {}
func record(key: String, failure_count: int) -> void:
	if failures.size() == failure_count:
		hits["queue."+key] = {"test":"short_stack_queue_test.gd","postcondition_verified":true}
func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
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
	var report := {"scope":"queue subgraph fixtures only","source_sha256":hashes,"test_sha256":FileAccess.get_file_as_string("res://three_d/tests/short_stack_queue_test.gd").sha256_text(),"catalog_sha256":catalog_text.sha256_text(),"denominator":expected.size(),"numerator":hits.size(),"missing":missing,"failures":failures,"hits":hits,"overall_state_transition_coverage":null}
	FileAccess.open("res://../output/3d/queue-coverage.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
