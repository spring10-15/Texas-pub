extends SceneTree
const RunCheckpoint = preload("res://three_d/rules/run_checkpoint.gd")
const WORLD_SOURCES := ["world.gd", "player.gd", "scene_props.gd"]
var hits := {}
var failures: Array[String] = []
var checks := 0
func verify(id: String, ok: bool) -> void:
	checks += 1
	if ok:
		hits["world."+id] = {"test":"world_coverage_test.gd", "postcondition_verified":true}
	else:
		failures.append(id)
		push_error(id)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world: Node3D = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	for i in range(3): await physics_frame
	world.set_process(false)
	var lamp: Dictionary = world.props.entries.lamp
	var anchor: Area3D = lamp.anchor
	var original: Dictionary = world.checkpoint_state()
	verify("raycast_unfocused", not world.request_action(anchor) and world.checkpoint_state()==original)
	world.player.position = Vector3(1.6, 0.02, -1.1)
	world.player.camera.look_at(anchor.global_position)
	for i in range(3): await physics_frame
	var aimed: Dictionary = world.checkpoint_state()
	verify("prop_on", world.request_action(anchor) and world.props.states.lamp and RunCheckpoint.capture(world.run_game)==aimed.run)
	var busy: Dictionary = world.checkpoint_state()
	verify("busy_guard", not world.request_action(anchor) and world.checkpoint_state()==busy)
	await create_timer(0.5).timeout
	verify("prop_visual", is_equal_approx(float(lamp.node.light_energy),0.0) and world.props.states.lamp)
	world.pause_game()
	var paused: Dictionary = world.checkpoint_state()
	verify("pause_guard", not world.request_action(anchor) and world.checkpoint_state()==paused)
	world.resume()
	world.open_services()
	var modal: Dictionary = world.checkpoint_state()
	verify("modal_guard", not world.request_action(anchor) and world.checkpoint_state()==modal)
	world.close_services()
	var saved: Dictionary = world.checkpoint_state()
	world.props.restore({})
	verify("prop_restore", world.restore_checkpoint(saved) and world.props.states.lamp and is_equal_approx(float(lamp.node.light_energy),0.0))
	for prop_id in ["drawer0", "window", "card", "chip"]:
		await use_stash_prop(world, prop_id)
	world.travel("tavern")
	world.player.position = Vector3(9.55, 0.02, 1.15)
	world.player.camera.look_at(world.table_target.global_position)
	for i in range(5): await physics_frame
	var unopened: Dictionary = world.checkpoint_state()
	verify("seat_blocked", not world.request_action(world.table_target) and not world.seated and world.checkpoint_state()==unopened)
	world.travel("stash")
	world.player.camera.look_at(world.door_target.global_position)
	for i in range(3): await physics_frame
	var door: bool = world.request_action(world.door_target)
	if door: world.confirm_run_action()
	verify("room_entry", door and world.current_room=="tavern" and world.run_game.active and world.run_game.vault==900 and world.run_game.cash==300)
	world.player.position = Vector3(9.55, 0.02, 1.15)
	world.player.camera.look_at(world.table_target.global_position)
	for i in range(5): await physics_frame
	var return_position: Vector3 = world.player.global_position
	verify("seat", world.request_action(world.table_target) and world.seated and world.seat_panel.visible and not world.player.controls_enabled and world.seat_camera.current)
	world.pause_game()
	verify("pause", world.paused and not world.seat_panel.visible and world.pause_panel.visible and not world.player.controls_enabled)
	world.resume()
	verify("resume", not world.paused and world.seat_panel.visible and not world.pause_panel.visible and world.seated)
	world.leave_seat()
	verify("leave_pregame", not world.seated and world.table_game==null and world.player.controls_enabled and world.player.camera.current and world.player.global_position.is_equal_approx(return_position))
	world.player.camera.look_at(world.table_target.global_position)
	for i in range(5): await physics_frame
	var seated_again: bool = world.request_action(world.table_target)
	if seated_again: world.start_table(301)
	var active_table: RefCounted = world.table_game
	var cash_before: int = world.run_game.cash
	world.leave_seat()
	verify("leave_active_rejected", seated_again and active_table!=null and world.seated and world.table_game==active_table and world.run_game.cash==cash_before)
	var catalog_text := FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json")
	var catalog: Dictionary = JSON.parse_string(catalog_text)
	var expected: Array = catalog.transitions.filter(func(row): return str(row.id).begins_with("world.")).map(func(row): return row.id)
	var missing: Array = expected.filter(func(id): return not hits.has(id))
	for id in hits:
		if id not in expected: failures.append("Uncatalogued "+id)
	var hashes := {}
	for file in DirAccess.get_files_at("res://three_d/rules"):
		if file.ends_with(".gd") or file.ends_with(".json"): hashes[file] = FileAccess.get_file_as_string("res://three_d/rules/"+file).sha256_text()
	var world_hashes := {}
	for file in WORLD_SOURCES:
		world_hashes[file] = FileAccess.get_file_as_string("res://three_d/scripts/"+file).sha256_text()
	var report := {"scope":"Physical stash prop interactions, busy/pause/modal refusals, visual results, in-memory restore, seating and room entry","source_sha256":hashes,"world_source_sha256":world_hashes,"test_sha256":FileAccess.get_file_as_string("res://three_d/tests/world_coverage_test.gd").sha256_text(),"catalog_sha256":catalog_text.sha256_text(),"numerator":hits.size(),"denominator":expected.size(),"checks":checks,"hits":hits,"missing":missing,"failures":failures,"overall_state_transition_coverage":null}
	FileAccess.open("res://../output/3d/world-coverage.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("WORLD_COVERAGE covered=",hits.size()," total=",expected.size()," failed=",failures.size())
	quit(0 if failures.is_empty() and missing.is_empty() else 1)

func use_stash_prop(world: Node3D, prop_id: String) -> void:
	var entry: Dictionary = world.props.entries[prop_id]
	var anchor: Area3D = entry.anchor
	var offset := Vector3(0, 0, 0.65)
	if prop_id == "drawer0": offset = Vector3(0.7, 0, 0.65)
	if prop_id in ["card", "chip"]: offset = Vector3(0, 0, -0.7)
	world.player.global_position = Vector3(anchor.global_position.x + offset.x, 0.02, anchor.global_position.z + offset.z)
	for i in range(3): await physics_frame
	world.player.camera.look_at(anchor.global_position)
	await physics_frame
	var before: Dictionary = RunCheckpoint.capture(world.run_game)
	var activated: bool = world.request_action(anchor)
	await create_timer(0.5).timeout
	var actual: Variant = entry.node.get_indexed(NodePath(entry.property))
	var opened: Variant = entry.opened
	var visual_ok: bool = actual.is_equal_approx(opened) if actual is Vector3 else is_equal_approx(float(actual), float(opened))
	verify("prop_" + prop_id, activated and world.props.states[prop_id] and visual_ok and RunCheckpoint.capture(world.run_game)==before)
