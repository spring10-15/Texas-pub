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
	var before: Dictionary = world.checkpoint_state()
	world.save_path = "user://playtest-isolation-%d.save" % OS.get_process_id()
	world.load_checkpoint()
	verify(not world.saving_enabled and world.checkpoint_state() == before,"Playtest does not load or enable persistence")
	verify(not world.save_checkpoint() and not FileAccess.file_exists(world.save_path),"Even direct save writes no file")
	world.show_run_panel("enter")
	world.confirm_run_action()
	verify(world.run_game.run_seed == 20260922 and world.run_game.bankroll == 300 and world.run_game.vault == 900,"UI departure uses fixed seed and fresh bankroll")
	var plan: Dictionary = world.run_game.variant_plan.duplicate(true)
	world.run_game = world.RunRules.new(world.table_content)
	world.travel("stash")
	world.show_run_panel("enter")
	world.confirm_run_action()
	verify(world.run_game.variant_plan == plan,"Same initial conditions reproduce plan")
	print("PLAYTEST_SEED checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
