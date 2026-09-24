extends SceneTree
const Table = preload("res://three_d/rules/table.gd")
var failures: Array[String] = []
var hits := {}
var checks := 0

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func record(id: String, ok: bool) -> void:
	if ok:
		hits[id] = {"test":"poker_discount_coverage_test.gd","postcondition_verified":true}

func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var definition: Dictionary = content.tables["cargo-table"]
	var passive_ok := true
	for action in ["call", "fold", "check"]:
		var t := Table.new()
		t.start(definition, 91)
		if action == "check":
			t.state.street = "flop"
			t.state.currentBet = 0
			t.state.players[0].currentBet = 0
			t.state.currentActorId = "player"
			for player in t.state.players: player.currentBet = 0
		var before: int = int(t.state.players[0].stack)
		var accepted: bool = t.act("player", action, t.revision)
		var retained: bool = accepted and t.state.firstAggressionDiscountAvailable
		if action == "call": retained = retained and before-t.state.players[0].stack == 20
		passive_ok = passive_ok and retained
		verify(retained, "Passive action preserves aggression discount: "+action)
	record("poker_discount.passive_action_preserves", passive_ok)

	var discount_table := Table.new()
	discount_table.start(definition, 91)
	# Preserve total chips while ensuring the small blind can afford a later-street open raise.
	discount_table.state.players[1].stack += 5
	discount_table.state.players[2].stack -= 5
	var before_stack: int = discount_table.state.players[0].stack
	var first_ok: bool = discount_table.act("player", "raise", discount_table.revision)
	first_ok = first_ok and before_stack-discount_table.state.players[0].stack == 30 and discount_table.state.currentBet == 40 and not discount_table.state.firstAggressionDiscountAvailable
	verify(first_ok, "First aggression uses configured discount once")
	record("poker_discount.first_aggression_consumes", first_ok)

	# Reach the next street through calls, a check, and the normal advance path.
	while not discount_table.state.currentActorId.is_empty():
		var preflop_actor: String = discount_table.state.currentActorId
		verify(discount_table.act(preflop_actor, "call", discount_table.revision), "Opponent calls first raise")
	verify(discount_table.advance(discount_table.revision), "Advance to next street")
	var actor: String = discount_table.state.currentActorId
	var actor_player: Dictionary = discount_table.find_player(actor)
	var repeat_before: int = actor_player.stack
	var repeat_ok: bool = discount_table.act(actor, "raise", discount_table.revision)
	repeat_ok = repeat_ok and repeat_before-actor_player.stack == int(definition.openBet) and not discount_table.state.firstAggressionDiscountAvailable
	verify(repeat_ok, "Later aggression pays full open bet after discount consumed")
	record("poker_discount.consumed_aggression_full_cost", repeat_ok)

	var steps := 0
	while discount_table.state.status == "playing" and steps < 80:
		steps += 1
		if not discount_table.state.currentActorId.is_empty():
			var current_actor: String = discount_table.state.currentActorId
			var legal: Dictionary = discount_table.legal_actions(current_actor)
			var passive_action := "call" if legal.get("call", false) else "check" if legal.get("check", false) else "all-in"
			var accepted := discount_table.act(current_actor, passive_action, discount_table.revision)
			verify(accepted, "Finish hand with passive action")
			if not accepted: break
		else:
			verify(discount_table.advance(discount_table.revision), "Advance hand to showdown")
	var reset_hand: bool = discount_table.next_hand(discount_table.revision)
	var reset_ok: bool = reset_hand and discount_table.state.status == "playing" and discount_table.state.firstAggressionDiscountAvailable
	verify(reset_ok, "New hand restores configured aggression discount")
	record("poker_discount.next_hand_resets", reset_ok)

	var catalog_text := FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json")
	var catalog: Dictionary = JSON.parse_string(catalog_text)
	var expected: Array = catalog.transitions.filter(func(row): return str(row.id).begins_with("poker_discount.")).map(func(row): return row.id)
	for id in hits:
		if id not in expected: failures.append("Uncatalogued hit: "+id)
	var missing: Array = expected.filter(func(id): return not hits.has(id))
	for id in missing: failures.append("Missing: "+id)
	var hashes := {}
	for file in DirAccess.get_files_at("res://three_d/rules"):
		if file.ends_with(".gd") or file.ends_with(".json"):
			hashes[file] = FileAccess.get_file_as_string("res://three_d/rules/"+file).sha256_text()
	var report := {"scope":"aggression discount lifecycle subgraph","source_sha256":hashes,"test_sha256":FileAccess.get_file_as_string("res://three_d/tests/poker_discount_coverage_test.gd").sha256_text(),"catalog_sha256":catalog_text.sha256_text(),"denominator":expected.size(),"numerator":hits.size(),"missing":missing,"failures":failures,"hits":hits,"overall_state_transition_coverage":null}
	FileAccess.open("res://../output/3d/poker_discount-coverage.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("POKER_DISCOUNT checks=",checks," covered=",hits.size(),"/",expected.size()," failures=",failures)
	quit(0 if failures.is_empty() and missing.is_empty() else 1)
