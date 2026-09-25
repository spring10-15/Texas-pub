extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Checkpoint = preload("res://three_d/rules/run_checkpoint.gd")
var failures: Array[String] = []
var hits := {}
func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json"))
	for key in ["success", "collateral", "heat_cap", "stale_revision", "unknown_table", "inactive", "table_active", "completed", "locked", "insufficient_cash", "collateral_disallowed", "collateral_unowned", "collateral_not_valuable"]:
		var r := Run.new(content)
		r.start(r.revision,"rooftop-club" if key == "heat_cap" else "smoky-den",123)
		if key == "heat_cap": r.heat = 5
		var id := "cargo-table"
		var pledge := ""
		match key:
			"unknown_table": id = "unknown"
			"inactive": r.active = false
			"table_active": r.enter_table(7,r.revision,id)
			"completed": r.completed.append(id)
			"locked": id = "mirror-hall"
			"insufficient_cash": r.cash = 59
			"collateral_disallowed": pledge = "ivory-chip"; r.inventory.append(pledge)
		if key in ["collateral", "collateral_unowned", "collateral_not_valuable"]:
			id = "mirror-hall"
			r.completed.assign(["cargo-table", "ledger-cellar"])
			pledge = "steadying-drink" if key == "collateral_not_valuable" else "ivory-chip"
			if key != "collateral_unowned": r.inventory.append(pledge)
		var before := Checkpoint.capture(r)
		var result: RefCounted = r.enter_table(7,r.revision-1 if key == "stale_revision" else r.revision,id,pledge)
		var ok: bool
		if key == "heat_cap":
			var definition: Dictionary = content.tables[id]
			ok = result != null and r.cash == before.cash-int(definition.buyIn) and r.heat == 6 and r.heat <= 6 and r.vault == before.vault and r.revision == before.revision+1 and r.table.state.tableDef.id == id
		elif key in ["success", "collateral"]:
			var definition: Dictionary = content.tables[id]
			ok = result != null and r.cash == before.cash-int(definition.buyIn) and r.heat == before.heat+int(definition.heatGain) and r.vault == before.vault and r.revision == before.revision+1 and r.collateral == pledge and r.inventory.is_empty() and r.completed == before.completed and r.action_points == before.action_points
			ok = ok and r.table.state.tableDef.id == id and r.table.state.players.size() == 3
		else:
			ok = result == null and Checkpoint.capture(r) == before
		var outcome: String = "entry.heat_cap" if key == "heat_cap" else "entry."+key
		if ok: hits[outcome] = {"test":"entry_coverage_test.gd","postcondition_verified":true}
		else: failures.append(outcome); push_error(outcome)
	var expected: Array = catalog.transitions.filter(func(row): return str(row.id).begins_with("entry.")).map(func(row): return row.id)
	for id in hits:
		if id not in expected: failures.append("Uncatalogued hit: "+id)
	var missing: Array = expected.filter(func(id): return not hits.has(id))
	var hashes := {}
	for file in DirAccess.get_files_at("res://three_d/rules"):
		if not (file.ends_with(".gd") or file.ends_with(".json")): continue
		hashes[file] = FileAccess.get_file_as_string("res://three_d/rules/"+file).sha256_text()
	var report := {"scope":"entry subgraph only","source_sha256":hashes,"test_sha256":FileAccess.get_file_as_string("res://three_d/tests/entry_coverage_test.gd").sha256_text(),"catalog_sha256":FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json").sha256_text(),"denominator":expected.size(),"numerator":hits.size(),"missing":missing,"failures":failures,"hits":hits,"overall_state_transition_coverage":null,"overall_status":"Other families not yet enumerated; no global percentage claimed."}
	FileAccess.open("res://../output/3d/entry-coverage.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ENTRY_COVERAGE covered=",hits.size()," total=",expected.size()," missing=",missing," failures=",failures)
	quit(0 if failures.is_empty() and missing.is_empty() else 1)
