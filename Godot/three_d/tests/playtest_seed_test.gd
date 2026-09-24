extends SceneTree
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
	world.load_checkpoint()
	verify(not world.saving_enabled and world.checkpoint_state() == before,"Playtest does not load or enable persistence")
	verify(not world.save_checkpoint() and not FileAccess.file_exists(world.save_path),"Even direct save writes no file")
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
	print("PLAYTEST_SEED checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
