extends SceneTree
const Table = preload("res://three_d/rules/table.gd")
const Checkpoint = preload("res://three_d/rules/table_checkpoint.gd")
var failures: Array[String] = []
var checks := 0
var hits := {}
func verify(ok: bool, label: String, id := "") -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
	elif not id.is_empty(): hits["ending."+id] = {"test":"table_endings_test.gd","postcondition_verified":true}
func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json"))
	for table_id in content.tables:
		var t := Table.new()
		t.start(content.tables[table_id],7)
		for hand in range(1,int(content.tables[table_id].hands)+1):
			var pot: int = t.state.pot
			var winner: Dictionary = t.state.players[t.state.bigBlindSeat]
			var prior: int = winner.stack
			verify(t.act(t.state.currentActorId,"fold",t.revision),"First fold "+table_id)
			verify(t.act(t.state.currentActorId,"fold",t.revision),"Second fold "+table_id)
			verify(winner.stack == prior+pot and t.state.summary.awards == {winner.id:pot},"Fold winner receives exact pot "+table_id,"fold_award")
			var last: bool = hand == int(content.tables[table_id].hands)
			verify(t.state.status == ("finished" if last else "hand_over") and t.state.pendingConclusion == last and t.state.pendingNextHand == not last,"Hand limit decides conclusion "+table_id,"hand_limit" if last else "continue_hand")
			if not last:
				verify(t.next_hand(t.revision) and t.state.players.all(func(p): return not p.folded),"Funded folded opponents return "+table_id,"folded_return")
		var finished := Checkpoint.capture(t)
		verify(not t.next_hand(t.revision) and Checkpoint.capture(t) == finished,"Finished table cannot restart "+table_id,"finished_guard")
		# Isolate bankruptcy and single-funded-seat terminal conditions using a final all-in board.
		for player_wins in [false,true]:
			t = Table.new()
			t.start(content.tables[table_id],7)
			t.state.street = "river"
			t.state.currentActorId = ""
			t.state.toAct = []
			t.state.community = [{"rank":2,"suit":"S"},{"rank":4,"suit":"H"},{"rank":7,"suit":"D"},{"rank":9,"suit":"C"},{"rank":11,"suit":"S"}]
			t.state.pot = int(content.tables[table_id].buyIn)*3
			for i in range(3):
				var p: Dictionary = t.state.players[i]
				var rank_value: int = [14,13,12][i] if player_wins else [12,14,14][i]
				p.holeCards = [{"rank":rank_value,"suit":"H"},{"rank":rank_value,"suit":"D"}]
				if not player_wins and i == 2: p.holeCards = [{"rank":14,"suit":"S"},{"rank":14,"suit":"C"}]
				p.stack = 0
				p.handContribution = int(content.tables[table_id].buyIn)
			var ended: bool = t.advance(t.revision)
			verify(ended and t.state.status == "finished" and t.state.pendingConclusion and not t.state.pendingNextHand,"All-in terminal condition "+table_id+str(player_wins))
			verify(ended and t.state.status == "finished" and t.state.players[0].stack == (int(content.tables[table_id].buyIn)*3 if player_wins else 0) and t.state.players.filter(func(p): return p.stack > 0).size() == (1 if player_wins else 2),"Terminal exact player wealth "+table_id,"single_funded" if player_wins else "player_bankrupt")
	var expected: Array = catalog.transitions.filter(func(row): return str(row.id).begins_with("ending.")).map(func(row): return row.id)
	for id in hits:
		if id not in expected: failures.append("Uncatalogued hit: "+id)
	var missing: Array = expected.filter(func(id): return not hits.has(id))
	var hashes := {}
	for file in DirAccess.get_files_at("res://three_d/rules"):
		if not (file.ends_with(".gd") or file.ends_with(".json")): continue
		hashes[file] = FileAccess.get_file_as_string("res://three_d/rules/"+file).sha256_text()
	var report := {"scope":"ending subgraph only","source_sha256":hashes,"test_sha256":FileAccess.get_file_as_string("res://three_d/tests/table_endings_test.gd").sha256_text(),"catalog_sha256":FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json").sha256_text(),"denominator":expected.size(),"numerator":hits.size(),"missing":missing,"failures":failures,"hits":hits,"overall_state_transition_coverage":null,"overall_status":"Other families not yet enumerated; no global percentage claimed."}
	FileAccess.open("res://../output/3d/ending-coverage.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ENDING_COVERAGE covered=",hits.size()," total=",expected.size()," missing=",missing," failures=",failures)
	quit(0 if failures.is_empty() and missing.is_empty() else 1)
