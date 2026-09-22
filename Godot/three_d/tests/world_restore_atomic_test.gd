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
	world.run_game.start(world.run_game.revision)
	world.travel("tavern")
	var baseline: Dictionary = world.checkpoint_state()
	for key in ["props_type","prop_value","player_nan","look_inf","return_nan","basis_nan","player_remote","wrong_room","return_remote"]:
		var bad: Dictionary = baseline.duplicate(true)
		bad.run.cash += 100
		match key:
			"props_type": bad.props = "not-a-dictionary"
			"prop_value": bad.props = {"lamp":"yes"}
			"player_nan": bad.player.origin.x = NAN
			"look_inf": bad.look.x = INF
			"return_nan": bad["return"].origin.z = NAN
			"basis_nan": bad.player.basis.x.x = NAN
			"player_remote": bad.player.origin.x = 1e9
			"wrong_room": bad.player.origin.x += 10
			"return_remote":
				bad.seated = true
				bad["return"].origin.z = -1e9
		var accepted: bool = world.restore_checkpoint(bad)
		verify(not accepted,"Invalid world snapshot rejected "+key)
		verify(world.checkpoint_state() == baseline,"Failed restore leaves entire world unchanged "+key)
		world.restore_checkpoint(baseline)
	verify(world.restore_checkpoint(baseline) and world.checkpoint_state() == baseline,"Valid snapshot restores exactly")
	for pos in [Vector3(10,0.05,-7),Vector3(7.25,1.2,-12.5),Vector3(12.75,-1.2,-13)]:
		var valid: Dictionary = baseline.duplicate(true)
		valid.player.origin = pos
		verify(world.restore_checkpoint(valid) and world.player.global_position.is_equal_approx(pos),"Corridor, upper landing and lower quay remain loadable")
	world.restore_checkpoint(baseline)
	var legacy: Dictionary = baseline.duplicate(true)
	legacy.erase("props")
	verify(world.restore_checkpoint(legacy),"Legacy snapshot without props accepted")
	print("WORLD_RESTORE_ATOMIC checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
