extends SceneTree
## A2-4 / L-3 非法存档与恢复边界诊断
##
## 三组分层，避免互相污染：
##   组1 纯规则层  ：直接调 RunCheckpoint.restore()，验证数值/ID/结构校验
##   组2 文件层    ：用 SaveStore 读写**A2 专用文件** user://a2-boundary-probe.save，验证
##                   截断 / 缺字段 / 非法状态 / 旧版本 / 摘要(摘要自洽的篡改)
##   组3 世界层    ：经 world.restore_checkpoint() 验证姿态与房间一致性
##                   （L-3 线索 2：world.gd:900 只校验 is Transform3D，不校验坐标有限性/边界）
##
## 边界：只写 A2 专用文件；**绝不读写玩家真实存档** user://three-d-checkpoint.save。
##
## 运行：
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot \
##     --script "$PWD/docs/3d-production/external-handoff/A2-boundaries/repro/diag_save_recovery.gd" -- --test
const Run = preload("res://three_d/rules/run.gd")
const RunCheckpoint = preload("res://three_d/rules/run_checkpoint.gd")
const Table = preload("res://three_d/rules/table.gd")
const Checkpoint = preload("res://three_d/rules/table_checkpoint.gd")
const SaveStore = preload("res://three_d/rules/save_store.gd")

const PROBE_PATH := "user://a2-boundary-probe.save"
const PROBE_TMP := "user://a2-boundary-probe.save.tmp"

var failures: Array[String] = []
var findings: Array[String] = []
var checks := 0
var semantic_questions: Array[String] = []
var environment_notes: Array[String] = []
var content: Dictionary = {}
var world: Node3D

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("  ASSERT-FAIL ", label)

## 「预期拒绝但被接受」属于**发现**（校验缺口），不是诊断脚本自身的失败。
## 记录进 findings 并明确打印，避免把两类问题混在一起。
func expect_reject(label: String, accepted: bool) -> void:
	checks += 1
	if accepted:
		findings.append("预期拒绝但被接受：" + label)
		print("  FINDING 预期拒绝但被接受 → ", label)
	else:
		print("  %-30s → 拒绝（符合预期）" % label)

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	for i in range(6):
		await physics_frame

func run() -> void:
	content = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	print("=== A2-4 存档恢复边界诊断 (L-3) ===")
	print("专用文件：", PROBE_PATH, "（玩家真实存档未被读写）")
	group_pure_rules()
	group_file_layer()
	group_rng_restore()
	await group_world_layer()
	cleanup()

	print("")
	print("DIAG_SAVE_RECOVERY checks=", checks, " failures=", failures.size(), " findings=", findings.size())
	if not failures.is_empty():
		print("FAILURES（诊断脚本自身的断言失败）=", failures)
	if not findings.is_empty():
		print("FINDINGS（预期拒绝但被接受 → 校验缺口）:")
		for item in findings:
			print("  * ", item)
	for note in environment_notes:
		print("ENV-NOTE: ", note)
	if not semantic_questions.is_empty():
		print("SEMANTIC_QUESTIONS（交主 Agent 决定）:")
		for q in semantic_questions:
			print("  - ", q)
	quit(0 if failures.is_empty() else 1)

func base_run_dict() -> Dictionary:
	var r := Run.new(content)
	r.start(r.revision, "smoky-den", 0)
	return RunCheckpoint.capture(r)

## ---------- 组1：纯规则层 ----------
func group_pure_rules() -> void:
	print("")
	print("--- 组1：RunCheckpoint.restore() 纯规则校验 ---")
	var base := base_run_dict()
	verify(RunCheckpoint.restore(base, content) != null, "基线存档应被接受")

	var cases := {
		"cash=-1": ["cash", -1],
		"vault=-1": ["vault", -1],
		"heat=7": ["heat", 7],
		"heat=-1": ["heat", -1],
		"bankroll=-1": ["bankroll", -1],
		"revision=-1": ["revision", -1],
		"search_index=0": ["search_index", 0],
		"action_points=-1": ["action_points", -1],
		"action_points=上限+1": ["action_points", int(content.searchActions) + 1],
		"known_rules=未知桌": ["known_rules", ["unknown-table", "cargo-table"]],
		"used_tools=未知道具": ["used_tools", ["unknown-item"]],
		"inventory=未知道具": ["inventory", ["unknown-item"]],
		"scene_id=未知酒馆": ["scene_id", "nowhere"],
		"offer_index=越界": ["offer_index", 999],
		"completed=重复项": ["completed", ["cargo-table", "cargo-table"]],
	}
	for label in cases:
		var bad: Dictionary = base.duplicate(true)
		bad[cases[label][0]] = cases[label][1]
		expect_reject("非法存档 " + label, RunCheckpoint.restore(bad, content) != null)

	# 缺字段 / 类型不符
	var missing: Dictionary = base.duplicate(true)
	missing.erase("cash")
	expect_reject("缺 cash 字段", RunCheckpoint.restore(missing, content) != null)
	var wrong: Dictionary = base.duplicate(true)
	wrong.cash = "1"
	expect_reject("cash 类型不符", RunCheckpoint.restore(wrong, content) != null)

	# 背包超容量：用合法物品填到超出 inventorySlots
	var overfull: Array = []
	var slot_total := 0
	while slot_total <= int(content.inventorySlots):
		overfull.append("ivory-chip")
		slot_total += int(content.items["ivory-chip"].slots)
	var of_bad: Dictionary = base.duplicate(true)
	of_bad.inventory = overfull
	expect_reject("背包超容量（%d 件 / 上限 %s 格）" % [overfull.size(), content.inventorySlots],
		RunCheckpoint.restore(of_bad, content) != null)

	# 记录字段读取语义：preview/full_intel 等展示型字段不参与校验
	semantic_questions.append("run_checkpoint.gd 对 preview / full_intel / opponent_notes / last_result 等只做类型检查，不对内容做语义校验；这类字段被篡改不会导致拒绝。是否属可接受范围请主 Agent 确认。")

## ---------- 组2：文件层 ----------
func group_file_layer() -> void:
	print("")
	print("--- 组2：SaveStore 文件层（专用文件）---")
	var state := {"probe": "a2", "run": base_run_dict(), "n": 1}
	var error := SaveStore.write_checkpoint(PROBE_PATH, state)
	if error != OK:
		environment_notes.append("专用文件写入失败（%s）→ 组2 未执行；这属环境限制，不是游戏缺陷" % error_string(error))
		print("  写入失败：", error_string(error), "（组2 标记为未执行）")
		return
	print("  写入成功 → ", PROBE_PATH)

	var ok_read := SaveStore.read_checkpoint(PROBE_PATH)
	verify(ok_read.get("status") == "ok", "正常文件应读回 ok")
	print("  正常文件读回 status=%s" % ok_read.get("status"))

	# (a) 改 payload 不改 digest
	var env: Dictionary = FileAccess.open(PROBE_PATH, FileAccess.READ).get_var(false)
	var tampered: Dictionary = env.duplicate(true)
	tampered.payload = var_to_bytes({"probe": "tampered", "run": {}, "n": 999})
	write_envelope(tampered)
	var r1 := SaveStore.read_checkpoint(PROBE_PATH)
	print("  (a) 改 payload 不改 digest → status=%s" % r1.get("status"))
	verify(r1.get("status") == "invalid", "摘要不匹配应被拒绝 (a)")

	# (b) 改 payload 并重算 digest（自洽篡改）
	tampered.digest = (tampered.payload as PackedByteArray).hex_encode().sha256_text()
	write_envelope(tampered)
	var r2 := SaveStore.read_checkpoint(PROBE_PATH)
	print("  (b) 改 payload 并重算 digest → status=%s（证明摘要只防意外损坏，不防有意改档）" % r2.get("status"))
	verify(r2.get("status") == "ok", "自洽篡改会被读出 ok —— 这是已知设计边界 (b)")

	# (c) 旧版本
	var old_env: Dictionary = {"version": 0, "digest": env.digest, "payload": env.payload}
	write_envelope(old_env)
	var r3 := SaveStore.read_checkpoint(PROBE_PATH)
	print("  (c) version=0 → status=%s" % r3.get("status"))
	verify(r3.get("status") == "invalid", "旧版本应被拒绝 (c)")

	# (d) 截断文件
	write_envelope(env)
	var raw := FileAccess.get_file_as_bytes(PROBE_PATH)
	var half := raw.slice(0, raw.size() / 2)
	var handle := FileAccess.open(PROBE_PATH, FileAccess.WRITE)
	handle.store_buffer(half)
	handle.close()
	var r4 := SaveStore.read_checkpoint(PROBE_PATH)
	print("  (d) 截断到 %d/%d 字节 → status=%s" % [half.size(), raw.size(), r4.get("status")])
	verify(r4.get("status") in ["invalid", "unreadable"], "截断文件应被拒绝 (d)")

	# (e) 缺字段（读得出 ok，但 RunCheckpoint 拒绝）
	write_envelope({"version": 1, "digest": var_to_bytes({"probe": "a2", "n": 1}).hex_encode().sha256_text(), "payload": var_to_bytes({"probe": "a2", "n": 1})})
	var r5 := SaveStore.read_checkpoint(PROBE_PATH)
	print("  (e) payload 缺 run 字段 → read status=%s" % r5.get("status"))
	verify(r5.get("status") == "ok", "缺字段只是结构完整性问题，文件层仍读出 ok (e)")
	if r5.get("status") == "ok":
		var restored: bool = RunCheckpoint.restore(r5.state.get("run", {}), content) != null
		print("      再走 RunCheckpoint.restore → %s" % ("接受" if restored else "拒绝"))
		verify(not restored, "缺字段的 run 应被规则层拒绝 (e)")

## ---------- 组3：世界层（姿态与房间一致性）----------
func group_world_layer() -> void:
	print("")
	print("--- 组3：world.restore_checkpoint() 姿态与房间一致性 ---")
	world = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await settle()
	world.set_process(false)
	world.show_run_panel("enter")
	world.confirm_run_action()
	await settle()
	var base: Dictionary = world.checkpoint_state()
	print("  基线：room=%s seated=%s active=%s" % [base.room, base.seated, base.run.active])
	var baseline_ok: bool = world.restore_checkpoint(base)
	print("  基线恢复（自身 capture → restore 往返）→ %s" % ("接受" if baseline_ok else "拒绝"))
	if not baseline_ok:
		checks += 1
		findings.append("组3 无法建立基线：world.restore_checkpoint() 拒绝了刚由 world.checkpoint_state() 生成的存档（room=%s / active=%s）。后续姿态用例标记为**未执行**，不作通过也不作失败。" % [base.room, base.run.active])
		semantic_questions.append("world.gd:905 的一致性判据 (state.room == \"stash\") == restored.active 决定了「在藏匿点且本局进行中」无法通过往返校验；若起始/回藏匿点会自动存档，则该存档不可恢复。请主 Agent 确认这是有意约束还是遗漏。")
		return

	# L-3 线索 2：NaN 姿态
	var nan_state: Dictionary = base.duplicate(true)
	nan_state.player = Transform3D(Basis(), Vector3(NAN, NAN, NAN))
	var nan_ok: bool = world.restore_checkpoint(nan_state)
	var origin_after: Vector3 = world.player.global_transform.origin
	print("  NaN 姿态 → %s；恢复后玩家坐标=%s 有限=%s" % [
		"接受" if nan_ok else "拒绝", origin_after, origin_after.is_finite()])
	expect_reject("NaN 姿态（world.gd:900 只校验 is Transform3D）", nan_ok)
	if nan_ok:
		findings.append("L-3 线索2 复现：NaN 姿态被接受并写入玩家关节，坐标变为非有限值 %s" % origin_after)
	else:
		findings.append("L-3 线索2 未复现：NaN 姿态已被拒绝（与 A 报告预测不同，需更新结论）")

	# 坐标远超房间边界
	world.restore_checkpoint(base)   # 复位，避免上一次尝试的副作用
	var far_state: Dictionary = base.duplicate(true)
	far_state.player = Transform3D(Basis(), Vector3(9999, 0, 9999))
	var far_ok: bool = world.restore_checkpoint(far_state)
	var far_origin: Vector3 = world.player.global_transform.origin
	print("  坐标 (9999,0,9999) 越界 → %s；恢复后坐标=%s" % ["接受" if far_ok else "拒绝", far_origin])
	expect_reject("越界坐标 (9999,0,9999)", far_ok)
	if far_ok:
		findings.append("L-3 线索2 复现：越界坐标 %s 被接受（无房间包围盒校验）" % far_origin)
	world.restore_checkpoint(base)

	# 房间非法
	var room_state: Dictionary = base.duplicate(true)
	room_state.room = "nowhere"
	expect_reject("room=nowhere", world.restore_checkpoint(room_state))
	world.restore_checkpoint(base)

	# props 类型非法：world.gd:900 的守卫**没有检查 props**，直到 :912 才因类型不符抛 SCRIPT ERROR
	var props_state: Dictionary = base.duplicate(true)
	props_state.props = "not-a-dictionary"
	expect_reject("props 非 Dictionary（经 :912 抛错，而非守卫 :900 拦截）", world.restore_checkpoint(props_state))

	# 关键追问：:912 抛错前，:911 已经执行 run_game = restored —— 是否留下"半恢复"状态？
	world.restore_checkpoint(base)
	var a_room: String = world.current_room
	var a_cash: int = int(world.run_game.cash)
	var partial: Dictionary = base.duplicate(true)
	partial.props = "not-a-dictionary"
	partial.run = base.run.duplicate(true)
	partial.run.cash = int(base.run.cash) + 100      # 让"是否已替换 run_game"可观测
	var partial_ok: bool = world.restore_checkpoint(partial)
	var b_room: String = world.current_room
	var b_cash: int = int(world.run_game.cash)
	print("  半恢复探针：返回=%s  |  房间 %s→%s  |  现金 %d→%d" % [
		"接受" if partial_ok else "拒绝", a_room, b_room, a_cash, b_cash])
	if b_cash != a_cash:
		findings.append("半恢复确认：world.gd:911 先执行 run_game = restored，:912 才因 props 类型不符抛 SCRIPT ERROR。函数返回失败，但 run_game **已被替换**（现金 %d→%d；房间未变 %s）→ 拒绝不彻底、无回滚，世界停在半恢复状态。" % [a_cash, b_cash, b_room])

	semantic_questions.append("world.gd:900 只校验 player 是 Transform3D，不校验坐标有限性与房间边界；restore_checkpoint 直接把 state.player 写进玩家关节（:917）。是否补 is_finite() 与房间包围盒校验，请主 Agent 决定。")

## ---------- RNG 恢复 ----------
func group_rng_restore() -> void:
	print("")
	print("--- 组4：RNG 恢复是否确定性延续 ---")
	var definition: Dictionary = content.tables["cargo-table"].duplicate(true)
	definition.hands = 3
	var table := Table.new()
	table.start(definition, 7)
	var guard := 0
	while table.state.status == "playing" and guard < 60:
		guard += 1
		if table.state.currentActorId == "":
			if not table.advance(table.revision):
				break
			continue
		var actor: String = table.state.currentActorId
		var legal: Dictionary = table.legal_actions(actor)
		var kind: String = "check" if legal.get("check", false) else ("call" if legal.get("call", false) else "fold")
		if not table.act(actor, kind, table.revision):
			break
	verify(table.state.status == "hand_over", "RNG 用例：第一手正常结束")
	var snapshot := Checkpoint.capture(table)
	var restored: RefCounted = Checkpoint.restore(snapshot)
	verify(restored != null, "RNG 用例：可恢复")
	if restored == null:
		return
	verify(int(restored.rng.value) == int(table.rng.value), "rng.value 被完整保存与恢复")
	var ok1: bool = table.next_hand(table.revision)
	var ok2: bool = restored.next_hand(restored.revision)
	verify(ok1 and ok2, "RNG 用例：两侧都能进入下一手")
	var deck_a := JSON.stringify(table.state.deck)
	var deck_b := JSON.stringify(restored.state.deck)
	print("  恢复后牌堆与未中断一致 = ", deck_a == deck_b)
	verify(deck_a == deck_b, "恢复后洗牌结果与未中断链路一致（RNG 确定性）")

func write_envelope(envelope: Dictionary) -> void:
	var handle := FileAccess.open(PROBE_PATH, FileAccess.WRITE)
	handle.store_var(envelope, false)
	handle.flush()
	handle.close()

func cleanup() -> void:
	for path in [PROBE_PATH, PROBE_TMP]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("")
	print("清理：A2 专用文件已删除")
