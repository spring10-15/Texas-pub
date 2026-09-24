extends SceneTree
## A5 诊断探针：world.gd restore/load 的矛盾快照与拒绝副作用。
## 只在 --tmp 指定的隔离临时目录写文件；不触碰 user:// 正式槽位。
## 用法：godot --headless --script <本文件绝对路径> -- --test --tmp=<隔离临时目录绝对路径>
const SaveStore = preload("res://three_d/rules/save_store.gd")
var failures: Array[String] = []
var cases := {}
var tmp := ""
var world: Node3D

func note(case_id: String, data: Dictionary) -> void:
	cases[case_id] = data
	print("A5_CASE ", JSON.stringify({"case": case_id, "data": data}))

func verify(case_id: String, ok: bool, detail: String) -> void:
	if not ok:
		failures.append(case_id + ": " + detail)
		push_error("A5 PROBE FAIL " + case_id + ": " + detail)

func hash_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "missing"
	return FileAccess.get_file_as_bytes(path).hex_encode().sha256_text()

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tmp="):
			tmp = argument.trim_prefix("--tmp=")
	if tmp.is_empty() or not tmp.begins_with("/"):
		push_error("A5 probe requires --tmp=<absolute isolated dir>")
		quit(1)
		return
	call_deferred("run")

func run() -> void:
	world = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	world.run_game.start(world.run_game.revision)
	world.travel("tavern")
	world.player.position = Vector3(world.ROOMS["tavern"].x - 0.45, 0.02, 1.15)
	world.player.camera.look_at(world.table_target.global_position)
	for i in range(5):
		await physics_frame
	var seated_ok: bool = world.request_action(world.table_target)
	verify("baseline_seated", seated_ok and world.seated, "could not seat through real ray")
	world.start_table(101)
	verify("baseline_active_table", world.table_game != null and world.run_game.table != null, "could not open real table")
	var baseline: Dictionary = world.checkpoint_state()
	note("baseline", {"room": baseline.room, "seated": baseline.seated, "active": baseline.run.active,
		"hand": baseline.run.table.state.handNumber if baseline.run.table != null else -1,
		"player": str(baseline.player.origin)})

	# 拒绝类用例：每个都要求 restore 返回 false 且世界状态与 baseline 完全一致
	var rejects := {
		"room_stash_but_active": func(bad): bad.room = "stash",
		"active_table_not_seated": func(bad): bad.seated = false,
		"room_unknown": func(bad): bad.room = "attic",
		"seated_in_stash": func(bad): bad.room = "stash",
		"inactive_with_table": func(bad): bad.run.active = false,
		"room_locked": func(bad): bad.room = "ledger",
		"table_id_mismatch": func(bad): bad.room = "ledger"; bad.run.completed = ["cargo-table"],
		"table_def_forged": func(bad): bad.run.table.state.tableDef.buyIn = 120,
		"props_non_bool": func(bad): bad.props = {"lamp": 1},
		"props_not_dictionary": func(bad): bad.props = "yes",
		"look_not_vector": func(bad): bad.look = "x",
		"player_outside": func(bad): bad.player.origin.x = 1e9,
		"return_nan_seated": func(bad): bad["return"].origin.z = NAN,
	}
	var results := {}
	for key in rejects:
		var bad: Dictionary = baseline.duplicate(true)
		rejects[key].call(bad)
		var accepted: bool = world.restore_checkpoint(bad)
		var unchanged: bool = world.checkpoint_state() == baseline
		results[key] = {"accepted": accepted, "world_unchanged": unchanged}
		verify("reject_" + key, not accepted and unchanged, "accepted=%s unchanged=%s" % [str(accepted), str(unchanged)])
	note("reject_matrix", results)

	# 通过类对照：baseline 本身必须可恢复
	var control_ok: bool = world.restore_checkpoint(baseline)
	note("control_valid_restore", {"accepted": control_ok, "world_equals_baseline": world.checkpoint_state() == baseline})
	verify("control_valid_restore", control_ok and world.checkpoint_state() == baseline, "valid baseline restore")

	# 文件层：写入隔离文件后，所有拒绝恢复都不得改动该文件
	var save_path := tmp.path_join("contradiction.save")
	world.save_path = save_path
	var wrote: bool = world.save_checkpoint()
	var file_hash_before := hash_file(save_path)
	var read_ok: bool = SaveStore.read_checkpoint(save_path).status == "ok"
	note("isolated_write", {"wrote": wrote, "read_status_ok": read_ok, "hash": file_hash_before, "path": save_path})
	verify("isolated_write", wrote and read_ok, "isolated checkpoint write failed")
	var hash_stable := true
	for key in rejects:
		var bad: Dictionary = baseline.duplicate(true)
		rejects[key].call(bad)
		world.restore_checkpoint(bad)
		if hash_file(save_path) != file_hash_before:
			hash_stable = false
	note("file_untouched_on_reject", {"stable": hash_stable, "hash_after": hash_file(save_path)})
	verify("file_untouched_on_reject", hash_stable, "a rejected restore modified the isolated save file")

	# load_checkpoint 路径：损坏文件必须保留原文件且关闭自动存盘，世界状态不变
	var corrupt_path := tmp.path_join("corrupt.save")
	SaveStore.write_checkpoint(corrupt_path, baseline)
	var corrupt_envelope: Dictionary = FileAccess.open(corrupt_path, FileAccess.READ).get_var(false)
	corrupt_envelope.payload[0] = (corrupt_envelope.payload[0] + 1) % 256
	var writer := FileAccess.open(corrupt_path, FileAccess.WRITE)
	writer.store_var(corrupt_envelope)
	writer.close()
	var corrupt_hash := hash_file(corrupt_path)
	var fresh: Node3D = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(fresh)
	await physics_frame
	fresh.set_process(false)
	fresh.run_game.start(fresh.run_game.revision)
	fresh.travel("tavern")
	var fresh_before: Dictionary = fresh.checkpoint_state()
	fresh.save_path = corrupt_path
	fresh.load_checkpoint()
	var fresh_after: Dictionary = fresh.checkpoint_state()
	note("load_corrupt", {"saving_enabled": fresh.saving_enabled, "world_unchanged": fresh_before == fresh_after,
		"file_hash_unchanged": hash_file(corrupt_path) == corrupt_hash})
	verify("load_corrupt", not fresh.saving_enabled and fresh_before == fresh_after and hash_file(corrupt_path) == corrupt_hash,
		"corrupt load must keep file, keep world, disable autosave")

	# load_checkpoint 路径：空档必须允许后续自动存盘
	var absent_path := tmp.path_join("absent.save")
	DirAccess.remove_absolute(absent_path)
	var fresh2: Node3D = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(fresh2)
	await physics_frame
	fresh2.set_process(false)
	fresh2.run_game.start(fresh2.run_game.revision)
	fresh2.travel("tavern")
	fresh2.save_path = absent_path
	fresh2.load_checkpoint()
	note("load_missing", {"saving_enabled": fresh2.saving_enabled, "file_still_missing": not FileAccess.file_exists(absent_path)})
	verify("load_missing", fresh2.saving_enabled and not FileAccess.file_exists(absent_path), "missing load must enable autosave and not create a file")

	world.queue_free()
	fresh.queue_free()
	fresh2.queue_free()
	var summary := {"cases": cases, "checks": cases.size(), "isolated_tmp": tmp, "failures": failures, "failed": failures.size()}
	print("A5_WORLD_CONTRADICTION_PROBE ", JSON.stringify(summary))
	quit(0 if failures.is_empty() else 1)
