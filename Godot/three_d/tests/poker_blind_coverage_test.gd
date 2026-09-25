extends SceneTree

const Table = preload("res://three_d/rules/table.gd")

var checks := 0
var failures: Array[String] = []

func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json"))
	var all_tables_pass := true
	for table_id in content.tables:
		var definition: Dictionary = content.tables[table_id].duplicate(true)
		var table := Table.new()
		table.start(definition, 19)
		var expected_wealth := int(definition.buyIn) * 3
		var short_small := mini(int(definition.smallBlind) - 1, expected_wealth / 4)
		var short_big := mini(int(definition.openBet) - 1, expected_wealth / 4)
		var dealer_stack := expected_wealth - short_small - short_big
		table.state.players[0].stack = dealer_stack
		table.state.players[1].stack = short_small
		table.state.players[2].stack = short_big
		table.state.pot = 0
		table.state.dealerSeat = 0
		var before_revision: int = table.revision
		table.start_hand()
		var total_wealth := int(table.state.pot)
		for player in table.state.players:
			total_wealth += int(player.stack)
		var small: Dictionary = table.state.players[table.state.smallBlindSeat]
		var big: Dictionary = table.state.players[table.state.bigBlindSeat]
		var ok := table.revision == before_revision + 1
		ok = ok and table.state.status == "playing" and table.state.dealerSeat == 0 and table.state.smallBlindSeat == 1 and table.state.bigBlindSeat == 2
		ok = ok and int(small.currentBet) == short_small and int(small.stack) == 0 and int(small.handContribution) == short_small
		ok = ok and int(big.currentBet) == short_big and int(big.stack) == 0 and int(big.handContribution) == short_big
		ok = ok and not small.folded and not big.folded and small.holeCards.size() == 2 and big.holeCards.size() == 2
		ok = ok and int(table.state.currentBet) == maxi(short_small, short_big) and int(table.state.pot) == short_small + short_big
		ok = ok and table.state.currentActorId == table.state.players[0].id and total_wealth == expected_wealth
		verify(ok, "Short-stack blinds are capped, dealt in, and conserved: " + str(table_id))
		all_tables_pass = all_tables_pass and ok
	var expected: Array = catalog.transitions.filter(func(row): return str(row.id).begins_with("poker_blind.")).map(func(row): return row.id)
	var hits := {}
	if expected == ["poker_blind.short_stack_posts"] and all_tables_pass:
		hits["poker_blind.short_stack_posts"] = {"test": "poker_blind_coverage_test.gd", "postcondition_verified": true}
	else:
		failures.append("poker_blind.short_stack_posts")
		push_error("poker_blind.short_stack_posts")
	var source_hashes := {}
	for file in DirAccess.get_files_at("res://three_d/rules"):
		if file.ends_with(".gd") or file.ends_with(".json"):
			source_hashes[file] = FileAccess.get_file_as_string("res://three_d/rules/" + file).sha256_text()
	var report := {"scope": "short-stack blind posting across all configured tables", "source_sha256": source_hashes, "test_sha256": FileAccess.get_file_as_string("res://three_d/tests/poker_blind_coverage_test.gd").sha256_text(), "catalog_sha256": FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json").sha256_text(), "denominator": expected.size(), "numerator": hits.size(), "checks": checks, "missing": expected.filter(func(id): return not hits.has(id)), "failures": failures, "hits": hits, "overall_state_transition_coverage": null}
	var output := ProjectSettings.globalize_path("res://../output/3d/poker-blind-coverage.json")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var report_file := FileAccess.open(output, FileAccess.WRITE)
	report_file.store_string(JSON.stringify(report, "  "))
	print("POKER_BLIND_COVERAGE covered=", hits.size(), " total=", expected.size(), " checks=", checks, " failures=", failures)
	quit(0 if failures.is_empty() and hits.size() == expected.size() else 1)
