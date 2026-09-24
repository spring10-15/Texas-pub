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
	call_deferred("run_tests")

func run_tests() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var run := RunRules.new(content)
	run.start(run.revision, "smoky-den", 2409)
	run.inventory.assign(["marked-lens"])
	var table: RefCounted = run.enter_table(881, run.revision, "cargo-table")
	var run_before: Dictionary = RunCheckpoint.capture(run)
	var captured_run: Dictionary = RunCheckpoint.capture(run)
	var run_valid: bool = captured_run.cash == run.cash and captured_run.inventory == run.inventory and captured_run.variant_plan == run.variant_plan and captured_run.table == TableCheckpoint.capture(table) and run_before == captured_run
	verify(run_valid, "Run snapshot captures stable values and active table")
	var run_fields: Array[String] = ["vault", "active", "cash", "bankroll", "heat", "public_exit", "completed", "last_result", "revision", "inventory", "known_rules", "used_tools", "preview", "preview_hand", "action_points", "search_index", "heat_reduced", "service_message", "last_reward", "route_flags", "reservation", "offer_index", "full_intel", "opponent_notes", "collateral", "last_table_result", "scene_id", "search_results", "run_seed", "variant_plan", "venue_history", "arrival_completed", "transfer_log", "table"]
	var captured_run_fields_complete: bool = captured_run.size() == run_fields.size()
	for field in run_fields:
		captured_run_fields_complete = captured_run_fields_complete and captured_run.has(field) and captured_run[field] == (TableCheckpoint.capture(run.table) if field == "table" else run.get(field))
	verify(captured_run_fields_complete, "Run snapshot captures every persisted Run field")
	record("persistence_capture.run_fields_complete", captured_run_fields_complete)
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
	var table_fields_complete: bool = captured_table.size() == 3 and captured_table.has_all(["state", "revision", "rngValue"])
	verify(table_fields_complete, "Table snapshot captures every persisted Table field")
	record("persistence_capture.table_fields_complete", table_fields_complete)
	captured_table.state.players[0].holeCards.clear()
	captured_table.state.deck.clear()
	captured_table.state.pot += 1
	var table_isolated: bool = TableCheckpoint.capture(standalone) == table_before and standalone.state.players[0].holeCards.size() == 2 and standalone.state.deck.size() == 46
	verify(table_isolated, "Mutating nested Table snapshot cannot mutate live table")
	record("persistence_capture.table_snapshot_isolated", table_valid and table_isolated)

	var world: Node3D = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.run_game.start(world.run_game.revision, "smoky-den", 712)
	var world_before: Dictionary = world.checkpoint_state()
	var captured_world: Dictionary = world.checkpoint_state()
	var world_fields: Array[String] = ["run", "room", "player", "look", "seated", "return", "caseOpen", "props"]
	var world_fields_complete: bool = captured_world.size() == world_fields.size()
	for field in world_fields:
		world_fields_complete = world_fields_complete and captured_world.has(field)
	var world_expected := {"run": RunCheckpoint.capture(world.run_game), "room": world.current_room, "player": world.player.global_transform, "look": world.player.camera.rotation, "seated": world.seated, "return": world.return_transform, "caseOpen": world.case_open, "props": world.props.states.duplicate()}
	for field in world_fields:
		world_fields_complete = world_fields_complete and captured_world[field] == world_expected[field]
	verify(world_fields_complete, "World snapshot captures every persisted World field")
	record("persistence_capture.world_fields_complete", world_fields_complete)
	var lamp_open: bool = not bool(world_before.props.lamp)
	captured_world.run.inventory.append("not-owned")
	captured_world.run.cash += 1
	captured_world.props.lamp = lamp_open
	var world_copy_isolated: bool = world.checkpoint_state() == world_before
	verify(world_copy_isolated, "Mutating nested world checkpoint cannot mutate live Run or prop state")
	var detached_world: Dictionary = world.checkpoint_state()
	world.run_game.cash += 1
	world.props.states.lamp = lamp_open
	var world_snapshot_detached: bool = detached_world.run.cash == world_before.run.cash and detached_world.props.lamp == world_before.props.lamp
	verify(world_snapshot_detached, "Later live world changes cannot mutate an earlier checkpoint")
	record("persistence_capture.world_snapshot_isolated", world_copy_isolated and world_snapshot_detached)
	world.queue_free()

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
	var report := {"scope":"World, Run and Table checkpoint capture isolation","source_sha256":hashes,"world_source_sha256":{"world.gd":FileAccess.get_file_as_string("res://three_d/scripts/world.gd").sha256_text()},"test_sha256":FileAccess.get_file_as_string("res://three_d/tests/persistence_capture_coverage_test.gd").sha256_text(),"catalog_sha256":catalog_text.sha256_text(),"denominator":expected.size(),"numerator":hits.size(),"checks":checks,"missing":missing,"failures":failures,"hits":hits,"overall_state_transition_coverage":null}
	FileAccess.open("res://../output/3d/persistence-capture-coverage.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("PERSISTENCE_CAPTURE checks=",checks," covered=",hits.size(),"/",expected.size()," failures=",failures)
	quit(0 if failures.is_empty() and missing.is_empty() else 1)
