extends SceneTree
var failures: Array[String] = []
var checks := 0
func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	world.player.set_physics_process(false)
	verify(world.run_game.start(world.run_game.revision), "Start run")
	world.travel("tavern")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var initial: Basis = world.player.transform.basis
	verify(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Mouse capture active in windowed test")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(13, 0)
	for i in range(10000): world.player._unhandled_input(motion)
	var saved: Dictionary = world.checkpoint_state()
	verify(not initial.is_equal_approx(saved.player.basis), "Repeated real mouse input changes orientation")
	verify(is_equal_approx(saved.player.basis.determinant(), 1.0), "Rotation does not accumulate scale drift")
	print("ROTATION_BASIS determinant=", saved.player.basis.determinant())
	verify(world.restore_checkpoint(saved), "Real mouse rotation remains loadable after repeated turns")
	verify(world.checkpoint_state() == saved, "Rotation checkpoint preserves full state")
	var old_save: Dictionary = saved.duplicate(true)
	old_save.player.basis = old_save.player.basis.scaled(Vector3.ONE * 1.0001)
	verify(world.restore_checkpoint(old_save), "Small float32 drift in old save remains loadable")
	verify(world.checkpoint_state() == old_save, "Accepted old drift preserves snapshot")
	var malformed: Dictionary = old_save.duplicate(true)
	malformed.player.basis = Basis.IDENTITY.scaled(Vector3(1.01, 1, 1))
	verify(not world.restore_checkpoint(malformed) and world.checkpoint_state() == old_save, "Significant scale rejected without live changes")
	world.queue_free()
	await process_frame
	print("ROTATION_CHECKPOINT checks=", checks, " failed=", failures.size())
	quit(0 if failures.is_empty() else 1)
