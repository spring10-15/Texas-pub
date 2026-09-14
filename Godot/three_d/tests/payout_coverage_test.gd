extends SceneTree
const Table = preload("res://three_d/rules/table.gd")
const Checkpoint = preload("res://three_d/rules/table_checkpoint.gd")
var failures: Array[String] = []
var hits := {}
func cards(values: Array) -> Array:
	return values.map(func(v): return {"rank":v[0],"suit":v[1]})
func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json"))
	# Explicit expected payouts, not derived from the evaluator under test.
	var cases := {
		"single_winner":[[30,30,30],[90,0,0],false,false,[90]],
		"three_tiers":[[30,60,90],[90,60,30],false,false,[90,60,30]],
		"folded_best":[[30,60,90],[0,150,30],true,false,[90,60,30]],
		"three_way_tie":[[30,30,30],[30,30,30],false,true,[90]],
		"tied_side_pots":[[30,60,90],[30,60,90],false,true,[90,60,30]],
		"odd_chip":[[5,5,5],[0,8,7],true,true,[15]]}
	for key in cases:
		var row: Array = cases[key]
		var t := Table.new()
		t.start(content.tables["mirror-hall"],7)
		t.state.street = "river"
		t.state.currentActorId = ""
		t.state.toAct = []
		t.state.community = cards([[2,"S"],[4,"H"],[7,"D"],[9,"C"],[11,"S"]])
		if row[3]: t.state.community = cards([[10,"S"],[11,"S"],[12,"S"],[13,"S"],[14,"S"]])
		t.state.pot = 0
		var expected_awards := {}
		for i in range(3):
			var p: Dictionary = t.state.players[i]
			p.holeCards = cards([[14-i,"H"],[14-i,"D"]])
			p.handContribution = row[0][i]
			p.currentBet = row[0][i]
			p.stack = 120-int(row[0][i])
			p.folded = i == 0 and row[2]
			t.state.pot += int(row[0][i])
			expected_awards[p.id] = row[1][i]
		var before := Checkpoint.capture(t)
		var ok: bool = t.advance(t.revision) and t.state.summary.awards == expected_awards and t.state.summary.pots.map(func(p): return p.amount) == row[4]
		var wealth := 0
		for i in range(3):
			var p: Dictionary = t.state.players[i]
			wealth += int(p.stack)
			ok = ok and p.stack == 120-int(row[0][i])+int(row[1][i])
			for pot in t.state.summary.pots:
				if p.folded: ok = ok and p.id not in pot.winnerIds and p.id not in pot.eligibleIds
		ok = ok and wealth == 360 and t.rng.value == before.rngValue and t.state.deck == before.state.deck and t.state.community == before.state.community
		var settled := Checkpoint.capture(t)
		ok = ok and not t.advance(t.revision) and Checkpoint.capture(t) == settled
		var id: String = "payout."+key
		if ok: hits[id] = {"test":"payout_coverage_test.gd","postcondition_verified":true}
		else: failures.append(id); push_error(id)
	var expected: Array = catalog.transitions.filter(func(row): return str(row.id).begins_with("payout.")).map(func(row): return row.id)
	for id in hits:
		if id not in expected: failures.append("Uncatalogued hit: "+id)
	var missing: Array = expected.filter(func(id): return not hits.has(id))
	var hashes := {}
	for file in DirAccess.get_files_at("res://three_d/rules"):
		if not (file.ends_with(".gd") or file.ends_with(".json")): continue
		hashes[file] = FileAccess.get_file_as_string("res://three_d/rules/"+file).sha256_text()
	var report := {"scope":"payout subgraph only","source_sha256":hashes,"test_sha256":FileAccess.get_file_as_string("res://three_d/tests/payout_coverage_test.gd").sha256_text(),"catalog_sha256":FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json").sha256_text(),"denominator":expected.size(),"numerator":hits.size(),"missing":missing,"failures":failures,"hits":hits,"overall_state_transition_coverage":null,"overall_status":"Other families not yet enumerated; no global percentage claimed."}
	FileAccess.open("res://../output/3d/payout-coverage.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("PAYOUT_COVERAGE covered=",hits.size()," total=",expected.size()," missing=",missing," failures=",failures)
	quit(0 if failures.is_empty() and missing.is_empty() else 1)
