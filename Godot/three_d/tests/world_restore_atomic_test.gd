extends SceneTree
const Store = preload("res://three_d/rules/save_store.gd")
const Run = preload("res://three_d/rules/run.gd")
const RunCheckpoint = preload("res://three_d/rules/run_checkpoint.gd")
const PlayerController = preload("res://three_d/scripts/player.gd")
var failures: Array[String] = []
var checks := 0
var hits := {}
func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func record(id: String, ok: bool) -> void:
	verify(ok, id)
	if ok: hits["persistence_restore." + id] = {"test":"world_restore_atomic_test.gd", "postcondition_verified":true}
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
	var invalid_groups := {"invalid_props":true,"invalid_transform":true,"outside_room":true,"active_in_stash":true,"locked_room":true}
	for key in ["props_type","prop_value","player_nan","look_inf","look_remote","return_nan","basis_nan","player_remote","wrong_room","return_remote","active_in_stash","locked_room"]:
		var bad: Dictionary = baseline.duplicate(true)
		bad.run.cash += 100
		match key:
			"props_type": bad.props = "not-a-dictionary"
			"prop_value": bad.props = {"lamp":"yes"}
			"player_nan": bad.player.origin.x = NAN
			"look_inf": bad.look.x = INF
			"look_remote": bad.look.x = PlayerController.LOOK_PITCH_LIMIT + 0.1
			"return_nan": bad["return"].origin.z = NAN
			"basis_nan": bad.player.basis.x.x = NAN
			"player_remote": bad.player.origin.x = 1e9
			"wrong_room": bad.player.origin.x += 10
			"return_remote":
				bad.seated = true
				bad["return"].origin.z = -1e9
			"active_in_stash":
				bad.room = "stash"
				bad.player.origin = Vector3(1.95, 0.05, 1.7)
			"locked_room":
				bad.room = "ledger"
				bad.player.origin = Vector3(world.ROOMS.ledger.x - 2.0, 0.05, 1.7)
		var accepted: bool = world.restore_checkpoint(bad)
		var unchanged: bool = world.checkpoint_state() == baseline
		verify(not accepted,"Invalid world snapshot rejected "+key)
		verify(unchanged,"Failed restore leaves entire world unchanged "+key)
		var group: String = key if key in ["active_in_stash","locked_room"] else ("invalid_props" if key.begins_with("props") else ("outside_room" if key in ["player_remote","wrong_room","return_remote"] else "invalid_transform"))
		invalid_groups[group] = invalid_groups[group] and not accepted and unchanged
		world.restore_checkpoint(baseline)
	for group in invalid_groups: record(group, invalid_groups[group])
	for pitch in [-PlayerController.LOOK_PITCH_LIMIT, PlayerController.LOOK_PITCH_LIMIT]:
		var pitch_boundary: Dictionary = baseline.duplicate(true)
		pitch_boundary.look.x = pitch
		verify(world.restore_checkpoint(pitch_boundary) and is_equal_approx(world.player.camera.rotation.x, pitch),"Camera pitch control boundary restores: "+str(pitch))
	world.restore_checkpoint(baseline)
	var seated_snapshot: Dictionary = baseline.duplicate(true)
	seated_snapshot.seated = true
	seated_snapshot["return"] = seated_snapshot.player
	var seated_setup: bool = world.restore_checkpoint(seated_snapshot)
	if seated_setup:
		world.start_table(42)
	var active_snapshot: Dictionary = world.checkpoint_state()
	var active_without_seat: Dictionary = active_snapshot.duplicate(true)
	active_without_seat.seated = false
	world.restore_checkpoint(baseline)
	var active_table_not_seated: bool = seated_setup and active_snapshot.run.table is Dictionary and not world.restore_checkpoint(active_without_seat) and world.checkpoint_state() == baseline
	record("active_table_not_seated", active_table_not_seated)
	seated_setup = world.restore_checkpoint(seated_snapshot)
	if seated_setup:
		world.start_table(42)
	var table_mismatch: Dictionary = world.checkpoint_state()
	var table_mismatch_ready: bool = seated_setup and table_mismatch.run.table is Dictionary and str(table_mismatch.run.table.state.tableDef.id) == "cargo-table"
	if table_mismatch_ready:
		table_mismatch.room = "ledger"
		table_mismatch.player.origin = Vector3(world.ROOMS.ledger.x - 2.0, 0.05, 1.7)
		table_mismatch["return"].origin = table_mismatch.player.origin
		table_mismatch.run.completed.append("cargo-table")
	world.restore_checkpoint(baseline)
	var table_id_mismatch: bool = table_mismatch_ready and not world.restore_checkpoint(table_mismatch) and world.checkpoint_state() == baseline
	record("table_id_mismatch", table_id_mismatch)
	record("valid", world.restore_checkpoint(baseline) and world.checkpoint_state() == baseline)
	for pos in [Vector3(10,0.05,-7),Vector3(7.25,1.2,-12.5),Vector3(12.75,-1.2,-13)]:
		var valid: Dictionary = baseline.duplicate(true)
		valid.player.origin = pos
		verify(world.restore_checkpoint(valid) and world.player.global_position.is_equal_approx(pos),"Corridor, upper landing and lower quay remain loadable")
	world.restore_checkpoint(baseline)
	var legacy: Dictionary = baseline.duplicate(true)
	legacy.erase("props")
	world.props.restore({"Tavernlight":true})
	var tavern_light: Dictionary = world.props.entries["Tavernlight"]
	var legacy_restored: bool = world.props.states["Tavernlight"] and world.restore_checkpoint(legacy)
	legacy_restored = legacy_restored and world.checkpoint_state() == baseline and is_equal_approx(tavern_light.node.get_indexed(NodePath(tavern_light.property)), tavern_light.closed)
	var legacy_path := "user://legacy-world-test-%d.save" % OS.get_process_id()
	world.save_path = legacy_path
	var written: bool = Store.write_checkpoint(legacy_path, legacy) == OK
	var on_disk: Dictionary = Store.read_checkpoint(legacy_path)
	world.props.restore({"Tavernlight":true})
	if written and on_disk.status == "ok" and on_disk.state == legacy:
		world.load_checkpoint()
		legacy_restored = legacy_restored and world.saving_enabled and world.paused and world.checkpoint_state() == baseline and is_equal_approx(tavern_light.node.get_indexed(NodePath(tavern_light.property)), tavern_light.closed)
		world.resume()
		var restored_revision: int = world.run_game.revision
		var continued: bool = world.run_game.service_action("intel", "cargo-table", restored_revision)
		legacy_restored = legacy_restored and world.player.controls_enabled and continued and world.run_game.revision == restored_revision + 1 and "cargo-table" in world.run_game.known_rules
		world.restore_checkpoint(baseline)
	else:
		legacy_restored = false
	legacy_restored = legacy_restored and DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy_path)) == OK
	world.saving_enabled = false
	record("legacy_props", legacy_restored)
	var legacy_run_state: Dictionary = baseline.duplicate(true)
	for field in ["route_flags", "reservation", "offer_index", "full_intel", "opponent_notes", "collateral", "last_table_result", "scene_id", "search_results", "run_seed", "variant_plan", "venue_history", "arrival_completed", "transfer_log"]:
		legacy_run_state.run.erase(field)
	var migrated_run: RefCounted = RunCheckpoint.restore(legacy_run_state.run, world.run_game.content)
	var migrated_expected: Dictionary = legacy_run_state.duplicate(true)
	if migrated_run != null:
		migrated_expected.run = RunCheckpoint.capture(migrated_run)
		var default_run := Run.new(world.run_game.content)
		for field in ["route_flags", "reservation", "offer_index", "full_intel", "opponent_notes", "collateral", "last_table_result", "scene_id", "search_results", "run_seed", "variant_plan", "venue_history", "arrival_completed", "transfer_log"]:
			var expected_default: Variant = default_run.get(field)
			if field == "venue_history" and migrated_run.active:
				expected_default = [migrated_run.scene_id]
			verify(migrated_run.get(field) == expected_default, "Legacy field uses migration default: " + field)
	var legacy_run_path := "user://legacy-run-test-%d.save" % OS.get_process_id()
	var legacy_run_written: bool = Store.write_checkpoint(legacy_run_path, legacy_run_state) == OK
	world.save_path = legacy_run_path
	world.saving_enabled = true
	if legacy_run_written:
		world.load_checkpoint()
	var legacy_run_restored: bool = legacy_run_written and migrated_run != null and world.saving_enabled and world.checkpoint_state() == migrated_expected
	if legacy_run_restored:
		world.resume()
		var migrated_revision: int = world.run_game.revision
		var continued_migrated: bool = world.run_game.service_action("intel", "cargo-table", migrated_revision)
		legacy_run_restored = world.player.controls_enabled and continued_migrated and world.run_game.revision == migrated_revision + 1 and "cargo-table" in world.run_game.known_rules
	legacy_run_restored = legacy_run_restored and DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy_run_path)) == OK
	world.saving_enabled = false
	record("legacy_run_fields", legacy_run_restored)
	var repair_path := "user://repair-world-test-%d.save" % OS.get_process_id()
	world.save_path = repair_path
	world.saving_enabled = true
	var repair_state: Dictionary = world.checkpoint_state()
	var repair_ok: bool = world.save_checkpoint() and Store.read_checkpoint(repair_path).get("state", {}) == repair_state
	if repair_ok:
		repair_ok = DirAccess.remove_absolute(ProjectSettings.globalize_path(repair_path)) == OK
		repair_ok = repair_ok and world.save_checkpoint() and Store.read_checkpoint(repair_path).get("state", {}) == repair_state
	var repair_file := FileAccess.open(repair_path, FileAccess.WRITE)
	if repair_file != null:
		repair_file.store_string("invalid checkpoint")
		repair_file.close()
	else:
		repair_ok = false
	repair_ok = repair_ok and world.save_checkpoint() and Store.read_checkpoint(repair_path).get("state", {}) == repair_state and world.checkpoint_state() == repair_state
	repair_ok = repair_ok and DirAccess.remove_absolute(ProjectSettings.globalize_path(repair_path)) == OK
	world.saving_enabled = false
	record("save_repaired_from_memory", repair_ok)
	var missing_path := "user://missing-world-test-%d.save" % OS.get_process_id()
	world.save_path = missing_path
	world.saving_enabled = false
	world.load_checkpoint()
	var missing_ok: bool = world.saving_enabled and not FileAccess.file_exists(missing_path) and world.save_checkpoint() and Store.read_checkpoint(missing_path).get("state", {}) == world.checkpoint_state()
	missing_ok = missing_ok and DirAccess.remove_absolute(ProjectSettings.globalize_path(missing_path)) == OK
	record("missing_checkpoint_recovered", missing_ok)
	var playtest_path := "user://playtest-save-test-%d.save" % OS.get_process_id()
	world.save_path = playtest_path
	world.playtest_seed = 42
	world.saving_enabled = false
	world.load_checkpoint()
	var playtest_blocked: bool = not world.saving_enabled and not world.save_checkpoint() and not FileAccess.file_exists(playtest_path)
	world.playtest_seed = 0
	record("playtest_save_blocked", playtest_blocked)
	var corrupt_path := "user://corrupt-world-test-%d.save" % OS.get_process_id()
	var corrupt_file := FileAccess.open(corrupt_path, FileAccess.WRITE)
	corrupt_file.store_string("invalid checkpoint")
	corrupt_file.close()
	var corrupt_bytes: PackedByteArray = FileAccess.get_file_as_bytes(corrupt_path)
	var before_corrupt: Dictionary = world.checkpoint_state()
	world.save_path = corrupt_path
	world.saving_enabled = true
	world.load_checkpoint()
	var corrupt_preserved: bool = world.checkpoint_state() == before_corrupt and not world.saving_enabled and not world.paused and FileAccess.get_file_as_bytes(corrupt_path) == corrupt_bytes and world.save_notice.text.contains("已保留原文件")
	corrupt_preserved = corrupt_preserved and DirAccess.remove_absolute(ProjectSettings.globalize_path(corrupt_path)) == OK
	record("corrupt_load_preserved", corrupt_preserved)
	var future_path := "user://future-world-test-%d.save" % OS.get_process_id()
	var future_payload: PackedByteArray = var_to_bytes(before_corrupt)
	var future_envelope := {"version": Store.VERSION + 1, "digest": future_payload.hex_encode().sha256_text(), "payload": future_payload}
	var future_file := FileAccess.open(future_path, FileAccess.WRITE)
	future_file.store_var(future_envelope, false)
	future_file.close()
	var future_bytes: PackedByteArray = FileAccess.get_file_as_bytes(future_path)
	world.save_path = future_path
	world.saving_enabled = true
	world.load_checkpoint()
	var future_preserved: bool = world.checkpoint_state() == before_corrupt and not world.saving_enabled and not world.paused and FileAccess.get_file_as_bytes(future_path) == future_bytes and world.save_notice.text.contains("v%d" % (Store.VERSION + 1)) and world.save_notice.text.contains("v%d" % Store.VERSION)
	future_preserved = future_preserved and DirAccess.remove_absolute(ProjectSettings.globalize_path(future_path)) == OK
	record("unsupported_version_preserved", future_preserved)
	var seated_save: Dictionary = baseline.duplicate(true)
	seated_save.seated = true
	seated_save["return"] = seated_save.player
	record("seated", world.restore_checkpoint(seated_save) and world.seated and world.seat_panel.visible)
	world.start_table(42)
	verify(world.cards_root.get_child_count() > 0,"Live table has displayed cards")
	var replaced: bool = world.restore_checkpoint(baseline)
	record("replace_live_table", replaced and world.player.camera.current and not world.seat_camera.current and world.player.controls_enabled and world.crosshair.visible and not world.seat_panel.visible and world.explore_instructions.visible and world.cards_root.get_child_count() == 0 and world.checkpoint_state() == baseline)
	world.pause_game()
	record("paused_seated", world.restore_checkpoint(seated_save) and world.paused and not world.seat_panel.visible)
	world.resume()
	verify(world.seat_camera.current and world.seat_panel.visible and not world.player.controls_enabled,"Resume returns to restored seat")
	var catalog_text := FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json")
	var catalog: Dictionary = JSON.parse_string(catalog_text)
	var expected: Array = catalog.transitions.filter(func(row): return str(row.id).begins_with("persistence_restore.")).map(func(row): return row.id)
	var missing: Array = expected.filter(func(id): return not hits.has(id))
	for id in hits:
		if id not in expected: failures.append("Uncatalogued " + id)
	var hashes := {}
	for file in DirAccess.get_files_at("res://three_d/rules"):
		if file.ends_with(".gd") or file.ends_with(".json"):
			hashes[file] = FileAccess.get_file_as_string("res://three_d/rules/" + file).sha256_text()
	var world_hashes := {}
	for file in ["world.gd", "player.gd", "scene_props.gd"]:
		world_hashes[file] = FileAccess.get_file_as_string("res://three_d/scripts/" + file).sha256_text()
	var report := {"scope":"World snapshot validation, legacy props, seating, live-table replacement and paused restore","source_sha256":hashes,"world_source_sha256":world_hashes,"test_sha256":FileAccess.get_file_as_string("res://three_d/tests/world_restore_atomic_test.gd").sha256_text(),"catalog_sha256":catalog_text.sha256_text(),"numerator":hits.size(),"denominator":expected.size(),"checks":checks,"hits":hits,"missing":missing,"failures":failures,"failed":failures.size(),"overall_state_transition_coverage":null}
	FileAccess.open("res://../output/3d/persistence-restore-coverage.json", FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("PERSISTENCE_RESTORE ", JSON.stringify(report))
	quit(0 if failures.is_empty() and missing.is_empty() else 1)
