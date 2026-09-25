extends SceneTree
const SaveStore = preload("res://three_d/rules/save_store.gd")
const ID := "world.window_focus_out"
const WORLD_SOURCES := ["world.gd", "player.gd", "scene_props.gd", "interactable.gd"]
var checks := 0
var hits := {}
var failures: Array[String] = []
func verify(ok: bool) -> void:
	checks += 1
	if ok:
		hits[ID] = {"test":"world_focus_out_test.gd", "postcondition_verified":true}
	else:
		failures.append(ID)
		push_error(ID)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world: Node3D = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	for i in range(3): await physics_frame
	world.set_process(false)
	var fresh_save_ready: bool = world.readiness and world.saving_enabled
	var save_path := "user://window-focus-out-%d.save" % OS.get_process_id()
	world.save_path = save_path
	world.run_game.start(world.run_game.revision, "smoky-den", 0)
	world.travel("tavern")
	world.open_services()
	var checkpoint_before: Dictionary = world.checkpoint_state()
	var was_modal: bool = world.services_panel.visible and not world.paused and not world.player.controls_enabled
	world._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	var stored: Dictionary = SaveStore.read_checkpoint(save_path)
	var saved_matches_before_pause: bool = stored.get("status") == "ok" and stored.get("state", {}) == checkpoint_before
	var result_ok: bool = fresh_save_ready and was_modal and saved_matches_before_pause and world.checkpoint_state() == checkpoint_before and not world.services_panel.visible and world.paused and world.pause_panel.visible and not world.player.controls_enabled and world.saving_enabled and world.save_notice.text == "已自动保存"
	verify(result_ok)
	world.saving_enabled = false
	if FileAccess.file_exists(save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	var catalog_text := FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json")
	var catalog: Dictionary = JSON.parse_string(catalog_text)
	var expected: Array = catalog.transitions.filter(func(row): return row.id == ID).map(func(row): return row.id)
	var missing: Array = expected.filter(func(id): return not hits.has(id))
	var source_hashes := {}
	for file in DirAccess.get_files_at("res://three_d/rules"):
		if file.ends_with(".gd") or file.ends_with(".json"):
			source_hashes[file] = FileAccess.get_file_as_string("res://three_d/rules/" + file).sha256_text()
	var world_hashes := {}
	for file in WORLD_SOURCES:
		world_hashes[file] = FileAccess.get_file_as_string("res://three_d/scripts/" + file).sha256_text()
	var report := {"scope":"Window-focus-out notification saves a full checkpoint, closes services and pauses exploration","source_sha256":source_hashes,"world_source_sha256":world_hashes,"test_sha256":FileAccess.get_file_as_string("res://three_d/tests/world_focus_out_test.gd").sha256_text(),"catalog_sha256":catalog_text.sha256_text(),"numerator":hits.size(),"denominator":expected.size(),"checks":checks,"hits":hits,"missing":missing,"failures":failures,"overall_state_transition_coverage":null}
	FileAccess.open("res://../output/3d/world-focus-out-coverage.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("WORLD_FOCUS_OUT checks=", checks, " failures=", failures)
	quit(0 if failures.is_empty() and missing.is_empty() else 1)
