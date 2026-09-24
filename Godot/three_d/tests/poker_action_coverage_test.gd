extends SceneTree
const Table = preload("res://three_d/rules/table.gd")
const Checkpoint = preload("res://three_d/rules/table_checkpoint.gd")
var failures: Array[String] = []
var hits := {}
func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json"))
	for table_id in content.tables:
		for key in ["fold","call","check","raise","open","custom_raise","raise_to_all_in","all_in"]:
			var t := Table.new()
			t.start(content.tables[table_id],7)
			if key in ["check","open"]:
				while not t.state.currentActorId.is_empty():
					var who: String = t.state.currentActorId
					var legal: Dictionary = t.legal_actions(who)
					t.act(who,"check" if legal.check else "call",t.revision)
				t.advance(t.revision)
			var actor: String = t.state.currentActorId
			var player: Dictionary = t.find_player(actor)
			var before := Checkpoint.capture(t)
			var discount_available: bool = t.state.firstAggressionDiscountAvailable
			var own := player.duplicate(true)
			var action: String = {"fold":"fold","call":"call","check":"check","raise":"raise","open":"raise","custom_raise":"raise","raise_to_all_in":"raise","all_in":"all-in"}[key]
			var target := -1
			if key == "custom_raise": target = t.state.currentBet+int(t.state.tableDef.raiseIncrement)+5
			if key == "raise_to_all_in": target = 10000
			var amount := 0
			var new_bet: int = t.state.currentBet
			if action == "call": amount = new_bet-int(own.currentBet)
			if action == "raise":
				new_bet = maxi(int(t.state.tableDef.openBet) if new_bet == 0 else new_bet+int(t.state.tableDef.raiseIncrement),target)
				amount = new_bet-int(own.currentBet)-(10 if t.state.firstAggressionDiscountAvailable else 0)
			if key in ["all_in","raise_to_all_in"]:
				amount = own.stack
				new_bet = own.currentBet+amount
			var accepted: bool = t.act(actor,action,t.revision,target)
			var ok: bool = accepted and player.stack == own.stack-amount and player.handContribution == own.handContribution+amount and player.currentBet == own.currentBet+amount and t.state.pot == before.state.pot+amount
			ok = ok and t.state.currentBet == new_bet and t.revision == before.revision+1 and t.state.turnCounter == before.state.turnCounter+1 and t.rng.value == before.rngValue and t.state.deck == before.state.deck and t.state.community == before.state.community
			ok = ok and player.folded == (key == "fold") and player.lastAction == ("all-in" if key == "raise_to_all_in" else action)
			ok = ok and t.state.firstAggressionDiscountAvailable == (discount_available and key not in ["raise","open","custom_raise","raise_to_all_in","all_in"])
			var total: int = t.state.pot
			for p in t.state.players: total += int(p.stack)
			ok = ok and total == int(content.tables[table_id].buyIn)*3 and t.state.currentActorId == before.state.players[(int(own.seatIndex)+1)%3].id
			for p in t.state.players:
				ok = ok and p.holeCards == before.state.players[p.seatIndex].holeCards
				if p.id != actor: ok = ok and p.stack == before.state.players[p.seatIndex].stack and p.handContribution == before.state.players[p.seatIndex].handContribution
			var id: String = "poker_action."+key
			if ok: hits[id] = {"test":"poker_action_coverage_test.gd","postcondition_verified":true}
			else: failures.append(id+"/"+table_id); push_error(failures.back())
	var expected: Array = catalog.transitions.filter(func(row): return str(row.id).begins_with("poker_action.")).map(func(row): return row.id)
	for id in hits:
		if id not in expected: failures.append("Uncatalogued hit: "+id)
	var missing: Array = expected.filter(func(id): return not hits.has(id))
	var hashes := {}
	for file in DirAccess.get_files_at("res://three_d/rules"):
		if not (file.ends_with(".gd") or file.ends_with(".json")): continue
		hashes[file] = FileAccess.get_file_as_string("res://three_d/rules/"+file).sha256_text()
	var report := {"scope":"poker_action subgraph only","source_sha256":hashes,"test_sha256":FileAccess.get_file_as_string("res://three_d/tests/poker_action_coverage_test.gd").sha256_text(),"catalog_sha256":FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json").sha256_text(),"denominator":expected.size(),"numerator":hits.size(),"missing":missing,"failures":failures,"hits":hits,"overall_state_transition_coverage":null,"overall_status":"Other families not yet enumerated; no global percentage claimed."}
	FileAccess.open("res://../output/3d/poker_action-coverage.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("POKER_ACTION_COVERAGE covered=",hits.size()," total=",expected.size()," missing=",missing," failures=",failures)
	quit(0 if failures.is_empty() and missing.is_empty() else 1)
