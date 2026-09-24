extends SceneTree
const Store = preload("res://three_d/rules/save_store.gd")
var checks := 0
var failures: Array[String] = []
var hits := {}
func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
func record(id: String, ok: bool) -> void:
	verify(ok, id)
	if ok: hits["persistence_io." + id] = {"test":"save_store_test.gd", "postcondition_verified":true}
func _initialize() -> void:
	var path := "user://checkpoint-test-%d.save" % OS.get_process_id()
	record("read_missing", Store.read_checkpoint(path).status == "missing" and not FileAccess.file_exists(path))
	var state := {"cash": 240, "active": true, "cards": [{"rank": 14, "suit": "S"}], "position": Vector3(1, 2, 3)}
	record("write_new", Store.write_checkpoint(path, state) == OK and FileAccess.file_exists(path))
	var loaded := Store.read_checkpoint(path)
	record("read_valid", loaded.status == "ok" and loaded.state == state)
	state.cash = 180
	var replaced: bool = Store.write_checkpoint(path, state) == OK
	loaded = Store.read_checkpoint(path)
	record("write_replace", replaced and loaded.status == "ok" and loaded.state == state and not FileAccess.file_exists(path + ".tmp"))
	var file := FileAccess.open(path, FileAccess.READ)
	var envelope: Dictionary = file.get_var(false)
	file.close()
	envelope.payload[0] = (envelope.payload[0] + 1) % 256
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_var(envelope)
	file.close()
	var corrupt_bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var corrupt_result: Dictionary = Store.read_checkpoint(path)
	record("read_corrupt", corrupt_result.status == "invalid" and FileAccess.get_file_as_bytes(path) == corrupt_bytes)
	file = FileAccess.open(path, FileAccess.WRITE)
	var future_payload: PackedByteArray = var_to_bytes(state)
	file.store_var({"version": 99, "digest": future_payload.hex_encode().sha256_text(), "payload": future_payload}, false)
	file.close()
	var version_bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var version_result: Dictionary = Store.read_checkpoint(path)
	record("read_version", version_result.status == "unsupported_version" and version_result.version == 99 and FileAccess.get_file_as_bytes(path) == version_bytes)
	var non_dictionary_payload: PackedByteArray = var_to_bytes([1, 2, 3])
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_var({"version": Store.VERSION, "digest": non_dictionary_payload.hex_encode().sha256_text(), "payload": non_dictionary_payload}, false)
	file.close()
	var non_dictionary_bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var non_dictionary_result: Dictionary = Store.read_checkpoint(path)
	record("read_non_dictionary", non_dictionary_result.status == "invalid" and FileAccess.get_file_as_bytes(path) == non_dictionary_bytes)
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(PackedByteArray([1, 2, 3]))
	file.close()
	var short_bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var short_result: Dictionary = Store.read_checkpoint(path)
	var short_preserved: bool = short_result.status == "invalid" and FileAccess.get_file_as_bytes(path) == short_bytes
	Store.write_checkpoint(path, state)
	var complete: PackedByteArray = FileAccess.get_file_as_bytes(path)
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(complete.slice(0, complete.size() / 2))
	file.close()
	var truncated_bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var truncated_result: Dictionary = Store.read_checkpoint(path)
	record("read_truncated", short_preserved and truncated_result.status == "invalid" and FileAccess.get_file_as_bytes(path) == truncated_bytes)
	DirAccess.remove_absolute(path)
	var unavailable_parent := "user://missing-save-dir-%d" % OS.get_process_id()
	var unavailable_path := unavailable_parent + "/checkpoint.save"
	var open_error: Error = Store.write_checkpoint(unavailable_path, state)
	record("write_open_rejected", open_error != OK and not FileAccess.file_exists(unavailable_path) and not FileAccess.file_exists(unavailable_path + ".tmp") and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(unavailable_parent)))
	var directory_target := "user://save-target-directory-%d" % OS.get_process_id()
	var absolute_target: String = ProjectSettings.globalize_path(directory_target)
	DirAccess.make_dir_recursive_absolute(absolute_target)
	var rename_error: Error = Store.write_checkpoint(directory_target, state)
	var rename_rejected: bool = rename_error != OK and DirAccess.dir_exists_absolute(absolute_target) and not FileAccess.file_exists(directory_target + ".tmp")
	record("write_rename_rejected", rename_rejected)
	if FileAccess.file_exists(directory_target + ".tmp"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(directory_target + ".tmp"))
	DirAccess.remove_absolute(absolute_target)
	var catalog_text := FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json")
	var catalog: Dictionary = JSON.parse_string(catalog_text)
	var expected: Array = catalog.transitions.filter(func(row): return str(row.id).begins_with("persistence_io.")).map(func(row): return row.id)
	var missing: Array = expected.filter(func(id): return not hits.has(id))
	for id in hits:
		if id not in expected: failures.append("Uncatalogued " + id)
	var hashes := {}
	for source_file in DirAccess.get_files_at("res://three_d/rules"):
		if source_file.ends_with(".gd") or source_file.ends_with(".json"):
			hashes[source_file] = FileAccess.get_file_as_string("res://three_d/rules/" + source_file).sha256_text()
	var report := {"scope":"Checkpoint file creation, replacement, read and invalid envelope handling","source_sha256":hashes,"test_sha256":FileAccess.get_file_as_string("res://three_d/tests/save_store_test.gd").sha256_text(),"catalog_sha256":catalog_text.sha256_text(),"numerator":hits.size(),"denominator":expected.size(),"checks":checks,"hits":hits,"missing":missing,"failures":failures,"failed":failures.size(),"overall_state_transition_coverage":null}
	FileAccess.open("res://../output/3d/persistence-io-coverage.json", FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("PERSISTENCE_IO ", JSON.stringify(report))
	quit(0 if failures.is_empty() and missing.is_empty() else 1)
