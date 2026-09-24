extends SceneTree
const RunRules = preload("res://three_d/rules/run.gd")
const RunCheckpoint = preload("res://three_d/rules/run_checkpoint.gd")
const Table = preload("res://three_d/rules/table.gd")
const TableCheckpoint = preload("res://three_d/rules/table_checkpoint.gd")
var failures: Array[String] = []
var hits := {}
var checks := 0

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func record(id: String, ok: bool) -> void:
	if ok: hits[id] = {"test":"persistence_capture_coverage_test.gd","postcondition_verified":true}

func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var run := RunRules.new(content)
	run.start(run.revision, "smoky-den", 2409)
	run.inventory.assign(["marked-lens"])
	var table: RefCounted = run.enter_table(881, run.revision, "cargo-table")
	var run_before: Dictionary = RunCheckpoint.capture(run)
	var captured_run: Dictionary = RunCheckpoint.capture(run)
	var run_valid: bool = captured_run.cash == run.cash and captured_run.inventory == run.inventory and captured_run.variant_plan == run.variant_plan and captured_run.table == TableCheckpoint.capture(table) and run_before == captured_run
	verify(run_valid, "Run snapshot captures stable values and active table")
	var live_stack: int = table.state.players[0].stack
	captured_run.inventory.append("not-owned")
	captured_run.variant_plan.room_layout = "not-a-layout"
	captured_run.table.state.players[0].stack += 1
	var run_isolated: bool = run.inventory == ["marked-lens"] and run.variant_plan.room_layout != "not-a-layout" and table.state.players[0].stack == live_stack and RunCheckpoint.capture(run) == run_before
	verify(run_isolated, "Mutating nested Run snapshot cannot mutate live game")
	record("persistence_capture.run_snapshot_isolated", run_valid and run_isolated)

	var standalone := Table.new()
	standalone.start(content.tables["cargo-table"], 992)
	var table_before: Dictionary = TableCheckpoint.capture(standalone)
	var captured_table: Dictionary = TableCheckpoint.capture(standalone)
	var table_valid: bool = captured_table.state == standalone.state and captured_table.revision == standalone.revision and captured_table.rngValue == standalone.rng.value
	verify(table_valid, "Table snapshot captures state revision and RNG")
	captured_table.state.players[0].holeCards.clear()
	captured_table.state.deck.clear()
	captured_table.state.pot += 1
	var table_isolated: bool = TableCheckpoint.capture(standalone) == table_before and standalone.state.players[0].holeCards.size() == 2 and standalone.state.deck.size() == 46
	verify(table_isolated, "Mutating nested Table snapshot cannot mutate live table")
	record("persistence_capture.table_snapshot_isolated", table_valid and table_isolated)

	var catalog_text := FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json")
	var catalog: Dictionary = JSON.parse_string(catalog_text)
	var expected: Array = catalog.transitions.filter(func(row): return str(row.id).begins_with("persistence_capture.")).map(func(row): return row.id)
	for id in hits:
		if id not in expected: failures.append("Uncatalogued hit: "+id)
	var missing: Array = expected.filter(func(id): return not hits.has(id))
	for id in missing: failures.append("Missing: "+id)
	var hashes := {}
	for file in DirAccess.get_files_at("res://three_d/rules"):
		if file.ends_with(".gd") or file.ends_with(".json"):
			hashes[file] = FileAccess.get_file_as_string("res://three_d/rules/"+file).sha256_text()
	var report := {"scope":"Run and Table checkpoint capture isolation","source_sha256":hashes,"test_sha256":FileAccess.get_file_as_string("res://three_d/tests/persistence_capture_coverage_test.gd").sha256_text(),"catalog_sha256":catalog_text.sha256_text(),"denominator":expected.size(),"numerator":hits.size(),"missing":missing,"failures":failures,"hits":hits,"overall_state_transition_coverage":null}
	FileAccess.open("res://../output/3d/persistence-capture-coverage.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("PERSISTENCE_CAPTURE checks=",checks," covered=",hits.size(),"/",expected.size()," failures=",failures)
	quit(0 if failures.is_empty() and missing.is_empty() else 1)
