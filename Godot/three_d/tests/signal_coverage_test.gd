extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Checkpoint = preload("res://three_d/rules/run_checkpoint.gd")
var failures: Array[String] = []
var hits := {}
func cards(values: Array) -> Array:
	return values.map(func(v): return {"rank":v[0],"suit":v[1]})
func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	# A royal flush is unbeatable. A royal board splits equity 1/3 or 1/2.
	# Expected labels are derived from those facts, not the estimator under test.
	var cases := {"strong":"强","three_active_weak":"弱","folded_opponent_medium":"中","folded_player_medium":"中","all_in_counts":"弱"}
	for table_id in content.tables:
		for key in cases:
			var r := Run.new(content)
			r.start(r.revision,"smoky-den",0)
			r.enter_table(7,r.revision)
			# River fixture: test service semantics for each table, not room unlocks.
			r.table.start(content.tables[table_id],7)
			r.inventory.assign(["signal-lighter"])
			r.heat = 5
			var t: RefCounted = r.table
			t.state.street = "river"
			t.state.community = cards([[10,"S"],[11,"S"],[12,"S"],[13,"S"],[14,"S"]])
			for i in range(3):
				t.state.players[i].holeCards = cards([[2+i,"H"],[2+i,"D"]])
			if key == "strong":
				t.state.community = cards([[10,"S"],[11,"S"],[12,"S"],[13,"S"],[7,"D"]])
				t.state.players[1].holeCards = cards([[14,"S"],[3,"D"]])
			if key == "folded_opponent_medium": t.state.players[2].folded = true
			if key == "folded_player_medium": t.state.players[0].folded = true
			if key == "all_in_counts":
				t.state.pot += t.state.players[2].stack
				t.state.players[2].handContribution += t.state.players[2].stack
				t.state.players[2].stack = 0
			var target: String = t.state.players[1].id
			var before := Checkpoint.capture(r)
			var expected := before.duplicate(true)
			expected.inventory.clear()
			expected.used_tools.append("signal-lighter")
			expected.heat = mini(6,5+int(content.items["signal-lighter"].heat)+int(content.tables[table_id].get("tableToolHeatBonus",0)))
			expected.revision += 1
			expected.table.revision += 1
			expected.service_message = "对手牌力："+cases[key]+"（概率判断，不展示底牌）"
			var ok: bool = r.service_action("signal","signal-lighter",r.revision,target) and Checkpoint.capture(r) == expected
			# Repeated consumption is rejected without changing any state.
			ok = ok and not r.service_action("signal","signal-lighter",r.revision,target) and Checkpoint.capture(r) == expected
			var id: String = "signal."+key
			if ok: hits[id] = {"test":"signal_coverage_test.gd","postcondition_verified":true}
			else: failures.append(id+"/"+table_id); push_error(failures.back())
	var catalog_text := FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json")
	var catalog: Dictionary = JSON.parse_string(catalog_text)
	var expected_ids: Array = catalog.transitions.filter(func(row): return str(row.id).begins_with("signal.")).map(func(row): return row.id)
	var missing: Array = expected_ids.filter(func(id): return not hits.has(id))
	for id in hits:
		if id not in expected_ids: failures.append("Uncatalogued hit: "+id)
	var hashes := {}
	for file in DirAccess.get_files_at("res://three_d/rules"):
		if file.ends_with(".gd") or file.ends_with(".json"):
			hashes[file] = FileAccess.get_file_as_string("res://three_d/rules/"+file).sha256_text()
	var report := {"scope":"signal analysis river fixtures","source_sha256":hashes,"test_sha256":FileAccess.get_file_as_string("res://three_d/tests/signal_coverage_test.gd").sha256_text(),"catalog_sha256":catalog_text.sha256_text(),"denominator":expected_ids.size(),"numerator":hits.size(),"missing":missing,"failures":failures,"hits":hits,"overall_state_transition_coverage":null}
	FileAccess.open("res://../output/3d/signal-coverage.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("SIGNAL_COVERAGE covered=",hits.size()," missing=",missing," failures=",failures)
	quit(0 if failures.is_empty() and missing.is_empty() else 1)
