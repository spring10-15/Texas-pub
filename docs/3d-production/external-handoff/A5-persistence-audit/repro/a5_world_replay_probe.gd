extends SceneTree
## A5 诊断探针：世界存档写出→新实例 load_checkpoint→两侧同步驱动，
## 比较后续“可见结果”（public_state、rng.value、run 快照），覆盖下一手牌。
## 只在 --tmp 指定的隔离临时目录写文件；不触碰 user:// 正式槽位。
## 用法：godot --headless --script <本文件绝对路径> -- --test --tmp=<隔离临时目录绝对路径>
const RunCheckpoint = preload("res://three_d/rules/run_checkpoint.gd")
const SaveStore = preload("res://three_d/rules/save_store.gd")
var failures: Array[String] = []
var tmp := ""

func verify(label: String, ok: bool, detail: String) -> void:
	if not ok:
		failures.append(label + ": " + detail)
		push_error("A5 PROBE FAIL " + label + ": " + detail)

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tmp="):
			tmp = argument.trim_prefix("--tmp=")
	if tmp.is_empty() or not tmp.begins_with("/"):
		push_error("A5 probe requires --tmp=<absolute isolated dir>")
		quit(1)
		return
	call_deferred("run")

func seat_and_open(world: Node3D, seed_value: int) -> bool:
	world.run_game.start(world.run_game.revision)
	world.travel("tavern")
	world.player.position = Vector3(world.ROOMS["tavern"].x - 0.45, 0.02, 1.15)
	world.player.camera.look_at(world.table_target.global_position)
	for i in range(5):
		await physics_frame
	if not world.request_action(world.table_target):
		return false
	world.start_table(seed_value)
	return world.table_game != null

func drive_step(world: Node3D) -> void:
	var table: RefCounted = world.table_game
	if table == null:
		return
	if table.state.status == "hand_over":
		world.continue_hand(table.revision)
		return
	if table.state.status != "playing":
		return
	if table.state.currentActorId.is_empty():
		table.advance(table.revision)
		return
	if table.state.currentActorId == "player":
		world.table_delay = 0
		var legal: Dictionary = table.legal_actions("player")
		var action := "check" if legal.get("check", false) else ("call" if legal.get("call", false) else "fold")
		world.play_action(action, table.revision)
		return
	world.advance_table_beat()

func snapshot(world: Node3D) -> Dictionary:
	return {"hand": world.table_game.state.handNumber if world.table_game != null else -1,
		"status": world.table_game.state.status if world.table_game != null else "",
		"rng": world.table_game.rng.value if world.table_game != null else -1,
		"public": world.table_game.public_state() if world.table_game != null else {},
		"run": RunCheckpoint.capture(world.run_game)}

func run() -> void:
	var reference: Node3D = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(reference)
	await physics_frame
	reference.set_process(false)
	var seated: bool = await seat_and_open(reference, 4242)
	verify("baseline_seated", seated, "reference world could not seat and open a real table")
	if not seated:
		quit(1)
		return
	# 走到局面中段（跨过若干动作），再存盘
	for i in range(12):
		drive_step(reference)
	var save_path := tmp.path_join("replay.save")
	DirAccess.remove_absolute(save_path)
	reference.save_path = save_path
	var wrote: bool = reference.save_checkpoint()
	var read_back := SaveStore.read_checkpoint(save_path)
	var saved_snapshot := snapshot(reference)
	print("A5_REPLAY saved ", JSON.stringify({"wrote": wrote, "status": read_back.status, "hand": saved_snapshot.hand,
		"rng": saved_snapshot.rng, "revision": reference.run_game.revision}))
	verify("save_written", wrote and read_back.status == "ok", "checkpoint not written ok")

	# 新实例从同一存档恢复
	var restored: Node3D = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(restored)
	await physics_frame
	restored.set_process(false)
	restored.save_path = save_path
	restored.load_checkpoint()
	verify("restored_seated", restored.seated and restored.table_game != null and restored.table_game == restored.run_game.table,
		"restored world did not link a live table")
	restored.resume()
	var start_compare := snapshot(restored)
	verify("restore_immediate_visible", start_compare.public == saved_snapshot.public and start_compare.rng == saved_snapshot.rng,
		"restored visible state differs from saved immediately after load")

	# 两侧同步驱动，逐步比较“后续可见结果”
	var steps := 0
	var mismatches := 0
	var hands_seen := {saved_snapshot.hand: true}
	var rng_checks := 0
	var first_mismatch := {}
	while steps < 160:
		steps += 1
		drive_step(reference)
		drive_step(restored)
		var left := snapshot(reference)
		var right := snapshot(restored)
		hands_seen[left.hand] = true
		if left.rng == right.rng:
			rng_checks += 1
		if left.public != right.public or left.rng != right.rng or left.run != right.run or left.hand != right.hand or left.status != right.status:
			mismatches += 1
			if first_mismatch.is_empty():
				first_mismatch = {"step": steps, "reference_hand": left.hand, "restored_hand": right.hand,
					"reference_rng": left.rng, "restored_rng": right.rng, "reference_status": left.status, "restored_status": right.status,
					"public_equal": left.public == right.public, "run_equal": left.run == right.run}
	verify("replay_no_divergence", mismatches == 0, "visible state diverged after restore")
	verify("replay_crossed_next_hand", hands_seen.size() >= 2, "drive did not cross a hand boundary")

	# 负对照：故意扰动 RNG，证明上面的比较确实能发现不可重放（否则可能是空转）
	var golden: Node3D = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(golden)
	await physics_frame
	golden.set_process(false)
	golden.save_path = save_path
	golden.load_checkpoint()
	golden.resume()
	var tampered: Node3D = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(tampered)
	await physics_frame
	tampered.set_process(false)
	tampered.save_path = save_path
	tampered.load_checkpoint()
	tampered.resume()
	tampered.table_game.rng.value = (tampered.table_game.rng.value + 12345) & 0xffffffff
	var negative_mismatches := 0
	for i in range(60):
		drive_step(golden)
		drive_step(tampered)
		var left := snapshot(golden)
		var right := snapshot(tampered)
		if left.public != right.public or left.rng != right.rng:
			negative_mismatches += 1
	verify("negative_control_detects", negative_mismatches > 0, "tampered RNG did not diverge; comparison may be vacuous")

	var summary := {"steps": steps, "rng_equal_steps": rng_checks, "mismatches": mismatches, "first_mismatch": first_mismatch,
		"hands_covered": hands_seen.keys(), "final_hand": snapshot(reference).hand, "final_status": snapshot(reference).status,
		"final_rng": snapshot(reference).rng, "final_restored_rng": snapshot(restored).rng,
		"negative_control_mismatches": negative_mismatches,
		"failures": failures, "failed": failures.size(), "isolated_tmp": tmp}
	print("A5_REPLAY_PROBE ", JSON.stringify(summary))
	quit(0 if failures.is_empty() else 1)
