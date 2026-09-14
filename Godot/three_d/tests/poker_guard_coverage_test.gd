extends SceneTree
const Table = preload("res://three_d/rules/table.gd")
const Checkpoint = preload("res://three_d/rules/table_checkpoint.gd")
var failures: Array[String] = []
var hits := {}
func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json"))
	for table_id in content.tables:
		for key in ["stale_revision","unknown_action","not_playing","wrong_turn","unknown_actor","folded_actor","empty_stack","check_owes","call_zero","call_short","raise_used","raise_short","open_short","matched_raise_short","below_minimum"]:
			var t := Table.new()
			t.start(content.tables[table_id],7)
			var actor: String = t.state.currentActorId
			var p: Dictionary = t.find_player(actor)
			var action := "fold"
			var target := -1
			var expected_legal := false
			match key:
				"unknown_action": action = "allIn"
				"not_playing": t.state.status = "hand_over"
				"wrong_turn": actor = t.state.players[1].id
				"unknown_actor": actor = "unknown"; t.state.currentActorId = actor
				"folded_actor": p.folded = true
				"empty_stack": p.stack = 0
				"check_owes": action = "check"
				"call_zero": action = "call"; p.currentBet = t.state.currentBet
				"call_short": action = "call"; p.stack = t.state.currentBet-p.currentBet-1
				"raise_used": action = "raise"; t.state.raiseUsed = true
				"raise_short": action = "raise"; p.stack = t.state.currentBet-p.currentBet+int(t.state.tableDef.raiseIncrement)-(10 if t.state.firstAggressionDiscountAvailable else 0)
				"open_short": action = "raise"; t.state.currentBet = 0; p.currentBet = 0; p.stack = int(t.state.tableDef.openBet)-(10 if t.state.firstAggressionDiscountAvailable else 0)
				"matched_raise_short": action = "raise"; p.currentBet = t.state.currentBet; p.stack = int(t.state.tableDef.raiseIncrement)-(10 if t.state.firstAggressionDiscountAvailable else 0)
				"below_minimum": action = "raise"; target = t.state.currentBet+int(t.state.tableDef.raiseIncrement)-1; expected_legal = true
				"stale_revision": expected_legal = true
			var before := Checkpoint.capture(t)
			# Unknown command intentionally has a UI legal key; act must still reject it.
			if key == "unknown_action": expected_legal = true
			var legal: Dictionary = t.legal_actions(actor)
			var ok: bool = bool(legal.get(action,false)) == expected_legal and Checkpoint.capture(t) == before
			ok = ok and not t.act(actor,action,t.revision-1 if key == "stale_revision" else t.revision,target) and Checkpoint.capture(t) == before
			var id: String = "poker_guard."+key
			if ok: hits[id] = {"test":"poker_guard_coverage_test.gd","postcondition_verified":true}
			else: failures.append(id+"/"+table_id); push_error(failures.back())
	var expected: Array = catalog.transitions.filter(func(row): return str(row.id).begins_with("poker_guard.")).map(func(row): return row.id)
	for id in hits:
		if id not in expected: failures.append("Uncatalogued hit: "+id)
	var missing: Array = expected.filter(func(id): return not hits.has(id))
	var hashes := {}
	for file in DirAccess.get_files_at("res://three_d/rules"):
		if not (file.ends_with(".gd") or file.ends_with(".json")): continue
		hashes[file] = FileAccess.get_file_as_string("res://three_d/rules/"+file).sha256_text()
	var report := {"scope":"poker_guard subgraph only","source_sha256":hashes,"test_sha256":FileAccess.get_file_as_string("res://three_d/tests/poker_guard_coverage_test.gd").sha256_text(),"catalog_sha256":FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json").sha256_text(),"denominator":expected.size(),"numerator":hits.size(),"missing":missing,"failures":failures,"hits":hits,"overall_state_transition_coverage":null,"overall_status":"Other families not yet enumerated; no global percentage claimed."}
	FileAccess.open("res://../output/3d/poker_guard-coverage.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("POKER_GUARD_COVERAGE covered=",hits.size()," total=",expected.size()," missing=",missing," failures=",failures)
	quit(0 if failures.is_empty() and missing.is_empty() else 1)
