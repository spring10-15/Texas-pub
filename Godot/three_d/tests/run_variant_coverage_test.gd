extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Checkpoint = preload("res://three_d/rules/run_checkpoint.gd")
var checks := 0
var failures: Array[String] = []
var hits := {}

func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json"))
	var layouts_by_scene := {}
	for scene_id in content.scenes:
		var seeds := {}
		for seed_value in range(1, 101):
			var plan: Dictionary = Run.Variants.generate(content, scene_id, seed_value)
			if plan.room_layout in ["linear", "fork"]:
				seeds[plan.room_layout] = seed_value
		layouts_by_scene[scene_id] = seeds
		verify(seeds.size() == 2, "Both room layouts generate for " + str(scene_id))
		verify(Run.Variants.generate(content, scene_id, 0).room_layout == "linear", "Zero seed keeps the linear fallback for " + str(scene_id))
		for layout in ["linear", "fork"]:
			if not seeds.has(layout):
				continue
			var run := Run.new(content)
			var started: bool = run.start(run.revision, scene_id, int(seeds[layout]))
			var mirror_requirements: Array = run.room_requirements("mirror-hall")
			var embers_requirements: Array = run.room_requirements("embers-table")
			var expected_mirror := ["cargo-table"] if layout == "fork" else ["ledger-cellar"]
			var expected_embers := ["ledger-cellar", "mirror-hall"] if layout == "fork" else ["mirror-hall"]
			var restored: RefCounted = Checkpoint.restore(Checkpoint.capture(run), content)
			verify(started and run.variant_plan.room_layout == layout and mirror_requirements == expected_mirror and embers_requirements == expected_embers and restored != null and restored.variant_plan.room_layout == layout and restored.room_requirements("mirror-hall") == expected_mirror and restored.room_requirements("embers-table") == expected_embers, "Committed room layout affects access and survives restore: " + str(scene_id) + "/" + layout)
	var expected: Array = catalog.transitions.filter(func(row): return str(row.id).begins_with("run_variant.")).map(func(row): return row.id)
	var all_layouts_found: bool = layouts_by_scene.size() == content.scenes.size()
	for scene_id in content.scenes:
		all_layouts_found = all_layouts_found and layouts_by_scene[scene_id].size() == 2
	if expected == ["run_variant.room_layout_selected"] and all_layouts_found and failures.is_empty():
		hits["run_variant.room_layout_selected"] = {"test": "run_variant_coverage_test.gd", "postcondition_verified": true}
	else:
		failures.append("run_variant.room_layout_selected")
	var source_hashes := {}
	for file in DirAccess.get_files_at("res://three_d/rules"):
		if file.ends_with(".gd") or file.ends_with(".json"):
			source_hashes[file] = FileAccess.get_file_as_string("res://three_d/rules/" + file).sha256_text()
	var report := {"scope": "room-layout selection and persisted topology", "source_sha256": source_hashes, "test_sha256": FileAccess.get_file_as_string("res://three_d/tests/run_variant_coverage_test.gd").sha256_text(), "catalog_sha256": FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json").sha256_text(), "denominator": expected.size(), "numerator": hits.size(), "checks": checks, "missing": expected.filter(func(id): return not hits.has(id)), "failures": failures, "hits": hits, "overall_state_transition_coverage": null}
	var output := ProjectSettings.globalize_path("res://../output/3d/run-variant-coverage.json")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var report_file := FileAccess.open(output, FileAccess.WRITE)
	report_file.store_string(JSON.stringify(report, "  "))
	print("RUN_VARIANT_COVERAGE covered=", hits.size(), " total=", expected.size(), " checks=", checks, " failures=", failures)
	quit(0 if failures.is_empty() and hits.size() == expected.size() else 1)
