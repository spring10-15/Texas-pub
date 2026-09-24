extends SceneTree
const RunCheckpoint = preload("res://three_d/rules/run_checkpoint.gd")
const SaveStore = preload("res://three_d/rules/save_store.gd")
var failures: Array[String] = []
var checks := 0
var hits := {}

func verify(id: String, ok: bool) -> void:
	checks += 1
	if ok:
		hits["persistence_replay." + id] = {"test":"world_rng_replay_test.gd", "postcondition_verified":true}
	else:
		failures.append(id)
		push_error(id)

func _initialize() -> void:
	call_deferred("run")

func open_table(world: Node3D, seed_value: int) -> bool:
	world.run_game.start(world.run_game.revision)
	world.travel("tavern")
	world.player.position = Vector3(world.ROOMS.tavern.x - 0.45, 0.02, 1.15)
	world.player.camera.look_at(world.table_target.global_position)
	for i in range(5): await physics_frame
	if not world.request_action(world.table_target): return false
	world.start_table(seed_value)
	return world.table_game != null

func drive_step(world: Node3D) -> void:
	var table: RefCounted = world.table_game
	if table.state.status == "hand_over":
		world.continue_hand(table.revision)
	elif table.state.status == "playing" and table.state.currentActorId.is_empty():
		table.advance(table.revision)
	elif table.state.status == "playing" and table.state.currentActorId == "player":
		world.table_delay = 0
		var legal: Dictionary = table.legal_actions("player")
		world.play_action("check" if legal.get("check", false) else ("call" if legal.get("call", false) else "fold"), table.revision)
	elif table.state.status == "playing":
		world.advance_table_beat()

func snapshot(world: Node3D) -> Dictionary:
	return {"hand":world.table_game.state.handNumber, "status":world.table_game.state.status,
		"rng":world.table_game.rng.value, "public":world.table_game.public_state(),
		"run":RunCheckpoint.capture(world.run_game)}

func run() -> void:
	var path := "user://world-rng-replay-%d.save" % OS.get_process_id()
	var reference: Node3D = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(reference)
	await physics_frame
	reference.set_process(false)
	var opened: bool = await open_table(reference, 4242)
	if not opened:
		failures.append("table_open")
		push_error("table_open")
		quit(1)
		return
	for i in range(12): drive_step(reference)
	reference.save_path = path
	var wrote: bool = reference.save_checkpoint()
	var stored: Dictionary = SaveStore.read_checkpoint(path)
	var expected: Dictionary = snapshot(reference)
	var restored: Node3D = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(restored)
	await physics_frame
	restored.set_process(false)
	restored.save_path = path
	restored.load_checkpoint()
	var immediate: Dictionary = snapshot(restored)
	var restored_ok: bool = wrote and stored.status == "ok" and restored.seated and restored.table_game == restored.run_game.table and immediate == expected
	if restored.paused: restored.resume()
	var hands := {expected.hand:true}
	var matched_steps := 0
	for i in range(160):
		drive_step(reference)
		drive_step(restored)
		var left: Dictionary = snapshot(reference)
		var right: Dictionary = snapshot(restored)
		hands[left.hand] = true
		if left == right: matched_steps += 1
		restored_ok = restored_ok and left == right
	verify("world_rng_resume", restored_ok and hands.size() >= 2 and matched_steps == 160)

	var control_a: Node3D = load("res://three_d/scenes/main.tscn").instantiate()
	var control_b: Node3D = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(control_a)
	root.add_child(control_b)
	await physics_frame
	control_a.set_process(false)
	control_b.set_process(false)
	control_a.save_path = path
	control_b.save_path = path
	control_a.load_checkpoint()
	control_b.load_checkpoint()
	if control_a.paused: control_a.resume()
	if control_b.paused: control_b.resume()
	control_b.table_game.rng.value = (control_b.table_game.rng.value + 12345) & 0xffffffff
	var negative_divergence := false
	for i in range(60):
		drive_step(control_a)
		drive_step(control_b)
		var left: Dictionary = snapshot(control_a)
		var right: Dictionary = snapshot(control_b)
		if left.public != right.public or left.rng != right.rng:
			negative_divergence = true
	verify("rng_negative_control", negative_divergence)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var catalog_text := FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json")
	var catalog: Dictionary = JSON.parse_string(catalog_text)
	var expected_ids: Array = catalog.transitions.filter(func(row): return str(row.id).begins_with("persistence_replay.")).map(func(row): return row.id)
	var missing: Array = expected_ids.filter(func(id): return not hits.has(id))
	for id in hits:
		if id not in expected_ids: failures.append("Uncatalogued " + id)
	var hashes := {}
	for file in DirAccess.get_files_at("res://three_d/rules"):
		if file.ends_with(".gd") or file.ends_with(".json"): hashes[file] = FileAccess.get_file_as_string("res://three_d/rules/" + file).sha256_text()
	var world_hashes := {}
	for file in ["world.gd", "player.gd", "scene_props.gd"]:
		world_hashes[file] = FileAccess.get_file_as_string("res://three_d/scripts/" + file).sha256_text()
	var report := {"scope":"World save/load continuation with visible result and RNG comparison; includes altered-RNG negative control","source_sha256":hashes,"world_source_sha256":world_hashes,"checks":checks,"hits":hits,"missing":missing,"failures":failures,"failed":failures.size(),"numerator":hits.size(),"denominator":expected_ids.size(),"catalog_sha256":catalog_text.sha256_text(),"test_sha256":FileAccess.get_file_as_string("res://three_d/tests/world_rng_replay_test.gd").sha256_text(),"overall_state_transition_coverage":null}
	FileAccess.open("res://../output/3d/persistence-replay-coverage.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("WORLD_RNG_REPLAY ",JSON.stringify(report))
	quit(0 if failures.is_empty() and missing.is_empty() else 1)
