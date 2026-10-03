extends SceneTree
var failures: Array[String] = []
var checks := 0
func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
func _initialize() -> void: call_deferred("run")
func matches(entry: Dictionary) -> bool:
	var actual: Variant = entry.node.get_indexed(NodePath(entry.property))
	return actual.is_equal_approx(entry.closed) if actual is Vector3 else is_equal_approx(float(actual),float(entry.closed))
func run() -> void:
	var world = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	var saved: Dictionary = world.checkpoint_state()
	for id in ["drawer0","window","card","lamp"]:
		world.props.interact(id)
		await create_timer(0.12).timeout
		var entry: Dictionary = world.props.entries[id]
		verify(not matches(entry), "Animation actually started: " + id)
		verify(world.restore_checkpoint(saved), "Checkpoint restores during prop animation: " + id)
		await create_timer(0.5).timeout
		verify(not world.props.states[id] and matches(entry), "Old animation cannot overwrite restored prop: " + id)
		verify(not world.action_busy, "Restore leaves interaction available: " + id)
		world.props.interact(id)
		await create_timer(0.5).timeout
		verify(world.props.states[id] and not matches(entry) and not world.action_busy, "New interaction completes after restore: " + id)
		world.props.restore({})
	world.player.position = Vector3(0.5,0.02,0.9)
	world.player.camera.look_at(world.case_target.global_position)
	for i in range(5): await physics_frame
	verify(world.request_action(world.case_target), "Actual ray starts case lid animation")
	await create_timer(0.12).timeout
	verify(not world.lid.rotation.is_equal_approx(world.lid_open_rotation), "Case lid animation actually started")
	var invalid: Dictionary = saved.duplicate(true)
	invalid.props = "invalid"
	verify(not world.restore_checkpoint(invalid) and world.action_busy and world.case_tween != null, "Rejected restore preserves the running case animation")
	verify(world.restore_checkpoint(saved), "Checkpoint restores during case animation")
	verify(not world.action_busy and world.case_tween == null, "Accepted restore cancels case animation and busy state")
	await create_timer(0.75).timeout
	verify(world.case_open and world.lid.rotation.is_equal_approx(world.lid_open_rotation), "Old case animation cannot overwrite restored lid")
	world.player.position = Vector3(0.5,0.02,0.9)
	world.player.camera.look_at(world.case_target.global_position)
	for i in range(5): await physics_frame
	verify(world.request_action(world.case_target), "Actual ray can operate case again after restore")
	await create_timer(0.75).timeout
	verify(not world.case_open and not world.action_busy and world.case_tween == null and world.lid.rotation.is_equal_approx(world.lid_open_rotation+Vector3(deg_to_rad(102),0,0)), "New case animation completes after restore")
	var report := {"checks":checks,"failed":failures.size(),"failures":failures}
	FileAccess.open("res://../output/3d/prop-restore-tween-test.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("PROP_RESTORE_TWEEN ",JSON.stringify(report))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
