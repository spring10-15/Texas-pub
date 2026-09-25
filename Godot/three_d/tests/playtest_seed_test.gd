extends SceneTree
const SaveStore = preload("res://three_d/rules/save_store.gd")
var failures: Array[String] = []
var checks := 0
func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func _initialize() -> void:
	call_deferred("run_tests")
func run_tests() -> void:
	var world: Node3D = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	for args in [["--playtest-seed"],["--playtest-seed="],["--playtest-seed=0"],["--playtest-seed=-1"],["--playtest-seed=1.5"],["--playtest-seed=2147483647"],["--playtest-seed=1","--playtest-seed=2"]]:
		verify(not world.configure_playtest(PackedStringArray(args)),"Reject invalid argument "+str(args))
	verify(world.configure_playtest(PackedStringArray()),"Normal mode remains available")
	verify(world.playtest_seed == 0,"Normal mode uses random departure")
	verify(world.configure_playtest(PackedStringArray(["--playtest-seed=20260922"])),"Valid fixed seed")
	var trace_path := "user://playtest-trace-test-%d.jsonl" % OS.get_process_id()
	world.playtest_trace_path = trace_path
	var before: Dictionary = world.checkpoint_state()
	world.save_path = "user://playtest-isolation-%d.save" % OS.get_process_id()
	var on_disk_state: Dictionary = before.duplicate(true)
	on_disk_state.run.vault += 51
	var seeded_save_ok: bool = SaveStore.write_checkpoint(world.save_path, on_disk_state) == OK
	var bytes_before_guards: PackedByteArray = FileAccess.get_file_as_bytes(world.save_path)
	world.load_checkpoint()
	var blocked_load_preserved: bool = seeded_save_ok and not world.saving_enabled and world.checkpoint_state() == before and FileAccess.get_file_as_bytes(world.save_path) == bytes_before_guards
	verify(blocked_load_preserved,"Playtest load guard preserves memory and pre-existing save bytes")
	var blocked_save_preserved: bool = not world.save_checkpoint() and world.checkpoint_state() == before and FileAccess.get_file_as_bytes(world.save_path) == bytes_before_guards
	verify(blocked_save_preserved,"Even direct save guard preserves memory and pre-existing save bytes")
	world.show_run_panel("enter")
	world.confirm_run_action()
	verify(world.run_game.run_seed == 20260922 and world.run_game.bankroll == 300 and world.run_game.vault == 900,"UI departure uses fixed seed and fresh bankroll")
	var first_trace := FileAccess.get_file_as_string(trace_path).split("\n", false)
	verify(first_trace.size() == 1 and JSON.parse_string(first_trace[0]).event == "run_started" and JSON.parse_string(first_trace[0]).seed == 20260922,"Accepted departure writes one isolated trace event")
	world.open_services("bar")
	world.service_action("buy", "nonexistent", world.run_game.revision)
	verify(FileAccess.get_file_as_string(trace_path).split("\n", false).size() == 1,"Rejected service action does not enter trace")
	world.service_action("intel", "cargo-table", world.run_game.revision)
	var service_trace := FileAccess.get_file_as_string(trace_path).split("\n", false)
	var service_record: Dictionary = JSON.parse_string(service_trace[1]) if service_trace.size() == 2 else {}
	var available_actions: Array = service_record.get("details", {}).get("available_actions", [])
	verify(service_trace.size() == 2 and service_record.get("event") == "service_action" and service_record.get("choice") == "intel" and available_actions.size() > 1 and available_actions.any(func(action): return action.kind == "intel" and action.id == "cargo-table"),"Accepted service action records the offered decision set")
	world.close_services()
	world.seated = true
	world.start_table(301)
	verify(FileAccess.get_file_as_string(trace_path).split("\n", false).size() == 3,"Starting a table writes one trace event")
	world.table_delay = 0
	var turn: int = world.table_game.revision
	world.play_action("fold", turn)
	var poker_trace := FileAccess.get_file_as_string(trace_path).split("\n", false)
	verify(poker_trace.size() == 4 and JSON.parse_string(poker_trace[3]).event == "table_action" and JSON.parse_string(poker_trace[3]).details.legal_before.fold,"Accepted poker action preserves pre-action legal choices")
	world.table_game = null
	world.seated = false
	var plan: Dictionary = world.run_game.variant_plan.duplicate(true)
	world.run_game = world.RunRules.new(world.table_content)
	world.travel("stash")
	world.show_run_panel("enter")
	world.confirm_run_action()
	verify(world.run_game.variant_plan == plan,"Same initial conditions reproduce plan")
	verify(FileAccess.get_file_as_string(trace_path).split("\n", false).size() == 5,"Repeated fresh departure appends instead of replacing trace")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(trace_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(world.save_path))
	var catalog_text := FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json")
	var catalog: Dictionary = JSON.parse_string(catalog_text)
	var expected: Array = catalog.transitions.filter(func(row): return row.id == "persistence_restore.playtest_save_blocked").map(func(row): return row.id)
	var hits := {}
	if blocked_load_preserved and blocked_save_preserved and failures.is_empty():
		hits["persistence_restore.playtest_save_blocked"] = {"test":"playtest_seed_test.gd", "postcondition_verified":true, "checks":["blocked_load_preserved", "blocked_save_preserved"]}
	var hashes := {}
	for source in ["world.gd", "player.gd", "content.json"]:
		hashes[source] = FileAccess.get_file_as_string("res://three_d/" + ("scripts/" if source.ends_with(".gd") else "rules/") + source).sha256_text()
	var missing: Array = expected.filter(func(id): return not hits.has(id))
	var report := {"scope":"Playtest seed mode cannot read or write the real save slot", "source_sha256":hashes, "test_sha256":FileAccess.get_file_as_string("res://three_d/tests/playtest_seed_test.gd").sha256_text(), "catalog_sha256":catalog_text.sha256_text(), "numerator":hits.size(), "denominator":expected.size(), "checks":checks, "hits":hits, "missing":missing, "failures":failures, "overall_state_transition_coverage":null}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../output/3d"))
	FileAccess.open("res://../output/3d/playtest-seed-coverage.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("PLAYTEST_SEED checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() and missing.is_empty() else 1)
