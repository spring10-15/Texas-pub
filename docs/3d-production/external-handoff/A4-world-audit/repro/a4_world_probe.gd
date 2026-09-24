extends SceneTree
## A4 世界交互状态转移取证探针（重做版）
##
## 与同目录 `probe_world_transitions.gd`（更早的一次不完整尝试）的区别：
##   1. 修正 `world.service_action(...)` 返回 void 的事实——原脚本把它当 bool 赋值，抛
##      SCRIPT ERROR 后 services_panel 未被关闭，controls_enabled 一直为 false，
##      导致其后所有 aim() 失败（8 条 "no landing offset" 假失败）。
##   2. 每次交互前**重新瞄准**：抽屉这类道具会把自身 anchor 一起平移，
##      复用旧瞄准会让反向操作因射线偏离而失败。
##   3. 每个阶段结束后显式关闭面板 / 复位状态，避免阶段间污染。
##
## 原则：
##   - 只走公开入口；不直接改 props.states 伪造命中；
##   - 真实相机射线（player.camera.look_at + player.update_focus），与既有测试同法；
##   - 找不到输入一律 FAIL，绝不静默 continue；
##   - 内存中实例化场景；`--test` 下 world._ready() 不 load_checkpoint()，也不开自动存档。
##
## 显式构造前置条件的地方（completed / heat / controls_enabled）都在输出里以
## A4ISO / A4NOTE 标注，并在 README 中说明；这些不作为"玩家可达路径"证据。

const RunCheckpoint = preload("res://three_d/rules/run_checkpoint.gd")

var world: Node3D
var cases := 0
var fails: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func rec(id: String, ok: bool, detail: String) -> void:
	cases += 1
	print("A4CASE %s %s %s" % [id, "PASS" if ok else "FAIL", detail])
	if not ok:
		fails.append(id + " :: " + detail)

func note(text: String) -> void:
	print("A4NOTE " + text)

func iso(text: String) -> void:
	print("A4ISO " + text)

func settle(n := 3) -> void:
	for i in range(n):
		await physics_frame

func prop_matches(e: Dictionary, actual: Variant, want: Variant) -> bool:
	if actual is Vector3:
		return actual.is_equal_approx(want)
	if str(e.property).begins_with("rotation:"):
		return absf(angle_difference(float(actual), float(want))) < 0.001
	return is_equal_approx(float(actual), float(want))

## 围绕锚点找站位：16 个方向 × 4 个半径，命中即返回。
## 全部失败返回 ok=false（调用方必须报 FAIL）。
func aim(anchor: Area3D, radii := [0.55, 0.8, 1.1, 1.45]) -> Dictionary:
	if not world.player.controls_enabled:
		return {"ok": false, "dist": -1.0, "why": "controls_enabled=false"}
	var target: Vector3 = anchor.global_position
	for r in radii:
		for i in range(16):
			var a: float = TAU * float(i) / 16.0
			var pos := Vector3(target.x + cos(a) * r, 0.02, target.z + sin(a) * r)
			world.player.global_position = pos
			world.player.velocity = Vector3.ZERO
			await settle(2)
			world.player.global_position = pos
			world.player.velocity = Vector3.ZERO
			world.player.camera.look_at(target)
			await settle(2)
			world.player.update_focus()
			if world.player.focused == anchor:
				return {"ok": true, "dist": world.player.camera.global_position.distance_to(target), "why": "hit"}
	return {"ok": false, "dist": -1.0, "why": "no landing spot"}

func run() -> void:
	world = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await settle(4)
	world.set_process(false)
	world.save_path = "user://a4-probe-must-never-exist-%d.save" % OS.get_process_id()
	note("world ready; saving_enabled=%s; save_path isolated" % str(world.saving_enabled))

	await phase_raycast()
	await phase_props_stash()
	await phase_props_tavern()
	await phase_seat_blocked()
	await phase_enter_run()
	await phase_room_doors()
	await phase_services()
	await phase_seat_pause()
	await phase_active_table()
	await phase_forced_pressure()
	await phase_confirm_rejections()

	# 正式存档隔离自检
	var leaked: bool = FileAccess.file_exists(world.save_path)
	rec("no_save_file_written", not leaked, "临时 save_path 未生成=%s" % str(not leaked))

	print("A4PROBE_DONE cases=%d fails=%d" % [cases, fails.size()])
	for f in fails:
		print("A4FAIL " + f)
	quit(1 if not fails.is_empty() else 0)

# ================================================================ physical_raycast
func phase_raycast() -> void:
	world.travel("stash")
	await settle(3)
	var anchor: Area3D = world.props.entries.lamp.anchor

	# 1) 准星未对准
	world.player.global_position = Vector3(1.6, 0.02, -1.1)
	world.player.velocity = Vector3.ZERO
	await settle(3)
	world.player.camera.look_at(world.player.camera.global_position + Vector3(3, 0, 0))
	await settle(3)
	world.player.update_focus()
	var s1: Dictionary = world.checkpoint_state()
	var r1: bool = world.request_action(anchor)
	rec("raycast_unfocused", world.player.focused != anchor and not r1 and world.checkpoint_state() == s1,
		"focused!=anchor=%s r=%s snapshot_unchanged=%s" % [str(world.player.focused != anchor), str(r1), str(world.checkpoint_state() == s1)])

	# 2) 距离不够（REACH=2.0）
	var t: Vector3 = anchor.global_position
	world.player.global_position = Vector3(t.x, 0.02, t.z + 3.0)
	world.player.velocity = Vector3.ZERO
	await settle(3)
	world.player.camera.look_at(t)
	await settle(3)
	world.player.update_focus()
	var dist: float = world.player.camera.global_position.distance_to(t)
	var s2: Dictionary = world.checkpoint_state()
	var r2: bool = world.request_action(anchor)
	rec("raycast_out_of_reach", world.player.focused != anchor and not r2 and world.checkpoint_state() == s2,
		"dist=%.2f(REACH=2.0) focused!=anchor=%s r=%s snapshot_unchanged=%s" % [dist, str(world.player.focused != anchor), str(r2), str(world.checkpoint_state() == s2)])

	# 3) 不可交互碰撞体遮挡（整块实心墙）
	var pos: Vector3 = (anchor.global_position + world.player.camera.global_position) * 0.5
	var wall: Node3D = world.box(world, "A4Occluder", Vector3(pos.x, 1.5, pos.z), Vector3(0.08, 2.2, 1.4), "wall")
	await settle(4)
	world.player.update_focus()
	var s3: Dictionary = world.checkpoint_state()
	var r3: bool = world.request_action(anchor)
	rec("raycast_occluded_solid", world.player.focused != anchor and not r3 and world.checkpoint_state() == s3,
		"focused!=anchor=%s r=%s snapshot_unchanged=%s" % [str(world.player.focused != anchor), str(r3), str(world.checkpoint_state() == s3)])
	wall.queue_free()
	await settle(3)

	# 4) 暂停 / 服务弹窗 / 路线弹窗 三个守卫项在"自然路径"下被 can_interact 掩盖：
	#    这些面板都会把 controls_enabled 置 false，所以无法用公开入口区分是哪一项拦下的。
	#    下面用 A4ISO 显式把 controls_enabled 置真，隔离出守卫项本身。
	world.pause_game()
	iso("guard_paused_isolated: 把 controls_enabled 置真，使 paused 成为唯一决定因素")
	world.player.controls_enabled = true
	var ap: Dictionary = await aim(anchor)
	var s4: Dictionary = world.checkpoint_state()
	var r4: bool = world.request_action(anchor)
	world.player.controls_enabled = false
	world.resume()
	rec("guard_paused_isolated", ap.ok and not r4 and world.checkpoint_state() == s4,
		"aim=%s r=%s snapshot_unchanged=%s" % [str(ap.ok), str(r4), str(world.checkpoint_state() == s4)])

	world.show_run_panel("enter")
	iso("guard_run_panel_isolated: 把 controls_enabled 置真，使 run_panel.visible 成为唯一决定因素")
	world.player.controls_enabled = true
	var ar: Dictionary = await aim(anchor)
	var s5: Dictionary = world.checkpoint_state()
	var r5: bool = world.request_action(anchor)
	world.player.controls_enabled = false
	world.close_run_panel()
	rec("guard_run_panel_isolated", ar.ok and not r5 and world.checkpoint_state() == s5,
		"aim=%s r=%s snapshot_unchanged=%s" % [str(ar.ok), str(r5), str(world.checkpoint_state() == s5)])

	# 自然路径：面板可见且 controls 已被面板关掉（与已登记的 world.modal_guard 同一后继）
	world.open_services()
	var s6: Dictionary = world.checkpoint_state()
	var r6: bool = world.request_action(anchor)
	rec("guard_services_natural", not r6 and world.services_panel.visible and not world.player.controls_enabled and world.checkpoint_state() == s6,
		"services_visible=%s controls=%s r=%s snapshot_unchanged=%s" % [str(world.services_panel.visible), str(world.player.controls_enabled), str(r6), str(world.checkpoint_state() == s6)])
	world.close_services()

# ================================================================ prop_interactions
func prop_cycle(id: String) -> void:
	var e: Dictionary = world.props.entries[id]
	var a: Dictionary = await aim(e.anchor)
	if not a.ok:
		rec("prop_" + id + "_aim", false, "找不到命中锚点的站位 (%s, controls=%s)" % [a.why, str(world.player.controls_enabled)])
		return
	var snap_start: Dictionary = world.checkpoint_state()
	var r1: bool = world.request_action(e.anchor)
	var snap_after: Dictionary = world.checkpoint_state()
	var busy: bool = world.action_busy
	var r2: bool = world.request_action(e.anchor)
	var snap_busy: Dictionary = world.checkpoint_state()
	rec("prop_" + id + "_forward", r1 and world.props.states[id],
		"r=%s states=%s dist=%.2f" % [str(r1), str(world.props.states[id]), a.dist])
	rec("prop_" + id + "_busy", busy and not r2 and snap_after == snap_busy,
		"action_busy=%s second=%s snapshot_unchanged=%s" % [str(busy), str(r2), str(snap_after == snap_busy)])
	await create_timer(0.6).timeout
	var v1: Variant = e.node.get_indexed(NodePath(e.property))
	rec("prop_" + id + "_visual_open", prop_matches(e, v1, e.opened),
		"actual=%s want_opened=%s" % [str(v1), str(e.opened)])
	# 反向：道具可能把自身 anchor 一起移动（抽屉），必须重新瞄准
	var b: Dictionary = await aim(e.anchor)
	if not b.ok:
		rec("prop_" + id + "_reverse", false, "反向操作前找不到站位 (%s, controls=%s)" % [b.why, str(world.player.controls_enabled)])
	else:
		var r3: bool = world.request_action(e.anchor)
		await create_timer(0.6).timeout
		var v2: Variant = e.node.get_indexed(NodePath(e.property))
		rec("prop_" + id + "_reverse", r3 and not world.props.states[id] and prop_matches(e, v2, e.closed),
			"r=%s states=%s actual=%s want_closed=%s" % [str(r3), str(world.props.states[id]), str(v2), str(e.closed)])
	var snap_end: Dictionary = world.checkpoint_state()
	rec("prop_" + id + "_run_untouched", snap_start.run == snap_end.run, "run 未变=%s" % str(snap_start.run == snap_end.run))

func phase_props_stash() -> void:
	world.travel("stash")
	await settle(3)
	for id in ["lamp", "drawer0", "drawer1", "drawer2", "window", "card", "chip"]:
		await prop_cycle(id)

	# 跨道具 busy：一个道具动画期间按另一个道具也被拒
	var lamp_a: Area3D = world.props.entries.lamp.anchor
	var al: Dictionary = await aim(lamp_a)
	if al.ok:
		var rl: bool = world.request_action(lamp_a)
		var aw: Dictionary = await aim(world.props.entries.window.anchor)
		var busy: bool = world.action_busy
		var sw: Dictionary = world.checkpoint_state()
		var rw: bool = world.request_action(world.props.entries.window.anchor)
		rec("cross_prop_busy", rl and aw.ok and busy and not rw and world.checkpoint_state() == sw,
			"lamp=%s window_aim=%s action_busy=%s window_press=%s snapshot_unchanged=%s" % [str(rl), str(aw.ok), str(busy), str(rw), str(world.checkpoint_state() == sw)])
		await create_timer(0.7).timeout
	else:
		rec("cross_prop_busy_aim", false, "lamp 找不到站位 (%s)" % al.why)

	# 皮箱盖 toggle_case（request_action 内实现，不走 props.interact）
	if not is_instance_valid(world.lid):
		rec("toggle_case_lid_present", false, "world.lid 无效")
		return
	rec("toggle_case_lid_present", true, "stash.glb 内 CaseLidPivot 存在")
	await settle(2)
	var ac: Dictionary = await aim(world.case_target, [1.0, 1.3])
	if not ac.ok:
		rec("toggle_case_aim", false, "case_target 找不到站位 (%s)" % ac.why)
		return
	var open0: bool = world.case_open
	var c1: bool = world.request_action(world.case_target)
	await create_timer(0.8).timeout
	rec("toggle_case_close", c1 and open0 and not world.case_open and world.case_target.title == "打开皮箱",
		"r=%s case_open %s->%s title=%s" % [str(c1), str(open0), str(world.case_open), world.case_target.title])
	var c2: bool = world.request_action(world.case_target)
	await create_timer(0.8).timeout
	rec("toggle_case_open", c2 and world.case_open and world.case_target.title == "合上皮箱",
		"r=%s case_open=%s title=%s" % [str(c2), str(world.case_open), world.case_target.title])

func phase_props_tavern() -> void:
	var rooms := {
		"tavern": ["Tavernlight", "Taverncupboard"],
		"ledger": ["LedgerCellarlight", "LedgerCellarcupboard"],
		"mirror": ["MirrorHalllight", "MirrorHallcupboard"],
		"embers": ["EmbersRoomlight", "EmbersRoomcupboard"],
	}
	for dest in rooms:
		world.travel(dest)
		await settle(3)
		for id in rooms[dest]:
			await prop_cycle(id)

# ================================================================ seat
func phase_seat_blocked() -> void:
	world.travel("tavern")
	await settle(3)
	var a: Dictionary = await aim(world.table_target, [0.9, 1.2])
	if not a.ok:
		rec("seat_blocked_aim", false, "table_target 找不到站位 (%s)" % a.why)
		return
	var s: Dictionary = world.checkpoint_state()
	var r: bool = world.request_action(world.table_target)
	rec("seat_blocked_no_run", not r and not world.seated and not world.hint_label.text.is_empty() and world.checkpoint_state() == s,
		"r=%s seated=%s hint=%s snapshot_unchanged=%s" % [str(r), str(world.seated), world.hint_label.text, str(world.checkpoint_state() == s)])

# ================================================================ room_entry: 离开藏匿点
func phase_enter_run() -> void:
	world.travel("stash")
	await settle(3)
	var a: Dictionary = await aim(world.door_target, [0.9, 1.2])
	if not a.ok:
		rec("enter_panel_aim", false, "door_target 找不到站位 (%s)" % a.why)
		return
	var r1: bool = world.request_action(world.door_target)
	rec("enter_panel_open", r1 and world.run_panel.visible and world.run_action == "enter",
		"r=%s panel=%s action=%s" % [str(r1), str(world.run_panel.visible), world.run_action])
	var vault_before: int = world.run_game.vault
	world.confirm_run_action()
	rec("confirm_enter", world.current_room == "tavern" and world.run_game.active and world.run_game.vault == vault_before - 300 and world.run_game.cash == 300 and not world.run_panel.visible,
		"room=%s active=%s vault %d->%d cash=%d panel=%s" % [world.current_room, str(world.run_game.active), vault_before, world.run_game.vault, world.run_game.cash, str(world.run_panel.visible)])

# ================================================================ room_entry: 转房间
func phase_room_doors() -> void:
	world.travel("tavern")
	await settle(3)

	# 锁定房间门被拒（货运桌未完成）
	var a: Dictionary = await aim(world.ledger_door, [1.0, 1.3])
	if not a.ok:
		rec("room_door_blocked_aim", false, "ledger_door 找不到站位 (%s)" % a.why)
	else:
		var s: Dictionary = world.checkpoint_state()
		var r: bool = world.request_action(world.ledger_door)
		rec("room_door_blocked", not r and world.current_room == "tavern" and not world.hint_label.text.is_empty() and world.checkpoint_state() == s,
			"r=%s room=%s hint=%s snapshot_unchanged=%s" % [str(r), world.current_room, world.hint_label.text, str(world.checkpoint_state() == s)])

	# travel() 公开入参：五个目的地
	var expect := {"tavern": "烟雾酒馆", "ledger": "账房地窖", "mirror": "镜厅", "embers": "余烬牌室", "stash": "藏匿点"}
	var detail: Array[String] = []
	var all_ok := true
	for dest in ["tavern", "ledger", "mirror", "embers", "stash"]:
		world.travel(dest)
		await settle(2)
		var ok: bool = world.current_room == dest
		all_ok = all_ok and ok
		detail.append("%s->%s" % [dest, world.current_room])
	rec("travel_all_destinations", all_ok, " ".join(detail))
	note("travel() 只核对 current_room；title/落点等后继见注释，未逐项断言")

	# 解锁后经真实门进入（completed 为显式构造前置条件）
	iso("room_door_unlock: 显式注入 completed=[cargo-table] 以到达解锁分支（非玩家逐步累加）")
	world.travel("tavern")
	await settle(2)
	world.run_game.completed.append("cargo-table")
	world.refresh_route_labels()
	var b: Dictionary = await aim(world.ledger_door, [1.0, 1.3])
	if b.ok:
		var r2: bool = world.request_action(world.ledger_door)
		rec("room_door_unlock", r2 and world.current_room == "ledger", "r=%s room=%s" % [str(r2), world.current_room])
	else:
		rec("room_door_unlock_aim", false, "解锁后 ledger_door 找不到站位 (%s)" % b.why)
	world.travel("tavern")
	await settle(2)
	# 复原：把构造用的 completed 去掉，避免后续真实开桌时"该桌已完成不能重打"
	world.run_game.completed.erase("cargo-table")
	iso("room_door_unlock 结束：erase completed=[cargo-table] 以复原状态")
	world.refresh_route_labels()

# ================================================================ modal_guards / services
func phase_services() -> void:
	world.travel("tavern")
	await settle(2)
	world.run_game.discover_exit()
	var rev: int = world.run_game.revision

	# open_services 被 paused 拒绝
	world.pause_game()
	world.open_services()
	rec("open_services_blocked_paused", not world.services_panel.visible,
		"paused=%s services_visible=%s" % [str(world.paused), str(world.services_panel.visible)])
	world.resume()

	# open_services 被 run_panel 拒绝
	world.show_run_panel("enter")
	world.open_services()
	rec("open_services_blocked_run_panel", not world.services_panel.visible,
		"run_panel=%s services_visible=%s" % [str(world.run_panel.visible), str(world.services_panel.visible)])
	world.close_run_panel()

	# service_action：面板不可见 -> no-op
	var s1: Dictionary = world.checkpoint_state()
	world.service_action("buy", "marked-lens", rev)
	rec("service_action_panel_hidden_noop", world.checkpoint_state() == s1 and not world.services_panel.visible,
		"snapshot_unchanged=%s" % str(world.checkpoint_state() == s1))

	# service_action：未提供的动作 -> no-op（bag 视图无 buy）
	world.open_services()
	var s2: Dictionary = world.checkpoint_state()
	world.service_action("buy", "marked-lens", rev)
	rec("service_action_not_offered_noop", world.checkpoint_state() == s2 and world.services_panel.visible,
		"panel=%s snapshot_unchanged=%s" % [str(world.services_panel.visible), str(world.checkpoint_state() == s2)])

	# service_action：paused 时 no-op（pause_game 不会关闭 services_panel）
	world.pause_game()
	var s3: Dictionary = world.checkpoint_state()
	world.service_action("buy", "marked-lens", rev)
	rec("service_action_paused_noop", world.paused and world.services_panel.visible and world.checkpoint_state() == s3,
		"paused=%s panel=%s snapshot_unchanged=%s" % [str(world.paused), str(world.services_panel.visible), str(world.checkpoint_state() == s3)])
	world.resume()

	# service_action：已知路线 -> 关闭服务弹窗并打开路线预览弹窗（confirm 禁用）
	world.service_action("route", "general", rev)
	rec("service_action_route_preview", not world.services_panel.visible and world.run_panel.visible and world.run_confirm.disabled,
		"services=%s run_panel=%s confirm_disabled=%s" % [str(world.services_panel.visible), str(world.run_panel.visible), str(world.run_confirm.disabled)])
	world.close_run_panel()

	# close_services 恢复控制权
	world.open_services()
	var opened: bool = world.services_panel.visible and not world.player.controls_enabled
	world.close_services()
	rec("close_services_restores", opened and not world.services_panel.visible and world.player.controls_enabled,
		"open: panel=%s controls=%s | close: panel=%s controls=%s" % [str(opened), str(not world.player.controls_enabled), str(world.services_panel.visible), str(world.player.controls_enabled)])

# ================================================================ seat / pause / resume / leave_seat
func phase_seat_pause() -> void:
	world.travel("tavern")
	await settle(3)
	var a: Dictionary = await aim(world.table_target, [0.9, 1.2])
	if not a.ok:
		rec("seat_aim", false, "table_target 找不到站位 (%s)" % a.why)
		return
	var return_pos: Vector3 = world.player.global_position
	var r: bool = world.request_action(world.table_target)
	rec("seat", r and world.seated and world.seat_panel.visible and not world.player.controls_enabled and world.seat_camera.current,
		"r=%s seated=%s seat_panel=%s controls=%s seat_cam=%s" % [str(r), str(world.seated), str(world.seat_panel.visible), str(world.player.controls_enabled), str(world.seat_camera.current)])

	# 入座态 request_action 被 seated 项拒绝（自然路径：controls 已被入座关掉）
	var la: Area3D = world.props.entries.lamp.anchor
	var ss: Dictionary = world.checkpoint_state()
	var rs: bool = world.request_action(la)
	rec("guard_seated_natural", not rs and world.seated and not world.player.controls_enabled and world.checkpoint_state() == ss,
		"r=%s seated=%s controls=%s snapshot_unchanged=%s" % [str(rs), str(world.seated), str(world.player.controls_enabled), str(world.checkpoint_state() == ss)])

	# pause（入座态）
	world.pause_game()
	var btn: Button = world.pause_panel.find_children("*", "Button", true, false)[0]
	rec("pause_seated", world.paused and not world.seat_panel.visible and world.pause_panel.visible and not world.player.controls_enabled and btn.text == "继续牌局",
		"paused=%s seat_panel=%s pause_panel=%s button=%s" % [str(world.paused), str(world.seat_panel.visible), str(world.pause_panel.visible), btn.text])
	# resume（入座态）
	world.resume()
	rec("resume_seated", not world.paused and world.seat_panel.visible and not world.pause_panel.visible and world.seated and not world.player.controls_enabled,
		"paused=%s seat_panel=%s pause_panel=%s seated=%s controls=%s" % [str(world.paused), str(world.seat_panel.visible), str(world.pause_panel.visible), str(world.seated), str(world.player.controls_enabled)])

	# 服务弹窗在入座态打开/关闭
	world.open_services()
	var ok_open: bool = world.services_panel.visible and not world.seat_panel.visible
	world.close_services()
	var ok_close: bool = not world.services_panel.visible and world.seat_panel.visible
	rec("services_while_seated", ok_open and ok_close,
		"open: services=%s seat_hidden=%s | close: services=%s seat_restored=%s" % [str(ok_open), str(ok_open), str(world.services_panel.visible), str(world.seat_panel.visible)])

	# leave_seat：暂停中被拒
	world.pause_game()
	var lp: Dictionary = world.checkpoint_state()
	world.leave_seat()
	rec("leave_paused_rejected", world.seated and world.paused and world.checkpoint_state() == lp,
		"seated=%s paused=%s snapshot_unchanged=%s" % [str(world.seated), str(world.paused), str(world.checkpoint_state() == lp)])
	world.resume()

	# leave_seat：未开局接受
	world.leave_seat()
	rec("leave_pregame", not world.seated and world.table_game == null and world.player.controls_enabled and world.player.camera.current and world.player.global_position.is_equal_approx(return_pos),
		"seated=%s table=%s controls=%s cam=%s back_to_return=%s" % [str(world.seated), str(world.table_game), str(world.player.controls_enabled), str(world.player.camera.current), str(world.player.global_position.is_equal_approx(return_pos))])

# ================================================================ 活动牌桌
func phase_active_table() -> void:
	world.travel("tavern")
	await settle(3)
	var a: Dictionary = await aim(world.table_target, [0.9, 1.2])
	if not a.ok:
		rec("active_seat_aim", false, "table_target 找不到站位 (%s)" % a.why)
		return
	if not world.request_action(world.table_target):
		rec("active_seat", false, "入座失败")
		return
	world.start_table(301)
	var table: RefCounted = world.table_game
	if table == null:
		rec("active_start_table", false, "start_table(301) 返回 null")
		return
	var cash_before: int = world.run_game.cash
	world.leave_seat()
	rec("leave_active_rejected", world.seated and world.table_game == table and world.run_game.cash == cash_before,
		"seated=%s same_table=%s cash %d->%d" % [str(world.seated), str(world.table_game == table), cash_before, world.run_game.cash])

	var finished: bool = finish_table()
	if not finished:
		rec("active_finish_table", false, "牌桌未在步数上限内 finished")
		return
	var returned: int = world.table_game.state.players[0].stack
	world.leave_seat()
	rec("leave_finished", not world.seated and world.table_game == null and world.player.controls_enabled and world.run_game.cash == cash_before + returned and "cargo-table" in world.run_game.completed,
		"seated=%s cash %d+%d=%d completed=%s" % [str(world.seated), cash_before, returned, world.run_game.cash, str(world.run_game.completed)])
	var settled: Dictionary = world.checkpoint_state()
	world.leave_seat()
	rec("leave_unseated", world.checkpoint_state() == settled and not world.seated,
		"snapshot_unchanged=%s seated=%s" % [str(world.checkpoint_state() == settled), str(world.seated)])

func finish_table() -> bool:
	var steps := 0
	while world.table_game != null and world.table_game.state.status != "finished" and steps < 400:
		steps += 1
		var table: RefCounted = world.table_game
		if table.state.status == "hand_over":
			table.next_hand(table.revision)
		elif table.state.currentActorId.is_empty():
			table.advance(table.revision)
		else:
			var actor: String = table.state.currentActorId
			var legal: Dictionary = table.legal_actions(actor)
			var action: String = "fold" if actor != "player" else ("check" if legal.check else "call")
			table.act(actor, action, table.revision)
	return steps < 400 and world.table_game != null and world.table_game.state.status == "finished"

# ================================================================ 风声封锁强制撤离（经 leave_seat -> check_pressure）
func phase_forced_pressure() -> void:
	# 上一阶段已真实完成 cargo-table，同一 run 不能重打该桌；换一个全新 run（room_pool_test.gd 同法）
	iso("forced_pressure: 显式换上一个全新 Run 作为前置条件（cargo-table 已在上一阶段完成）")
	var fresh := preload("res://three_d/rules/run.gd").new(world.table_content)
	fresh.start(fresh.revision, "smoky-den", 0)
	world.run_game = fresh
	world.travel("tavern")
	await settle(3)
	var a: Dictionary = await aim(world.table_target, [0.9, 1.2])
	if not a.ok:
		rec("forced_seat_aim", false, "table_target 找不到站位 (%s)" % a.why)
		return
	if not world.request_action(world.table_target):
		rec("forced_seat", false, "入座失败")
		return
	iso("forced_pressure: 显式注入 heat=6 与 ivory-chip 以到达风声封锁分支（非玩家逐步累加）")
	world.run_game.heat = 6
	world.run_game.inventory.append("ivory-chip")
	world.leave_seat()
	var res: Dictionary = world.run_game.last_result
	rec("leave_pregame_pressure_forced", not world.seated and not world.run_game.active and world.current_room == "stash" and res.get("forced", false) == true,
		"seated=%s active=%s room=%s forced=%s vault=%d" % [str(world.seated), str(world.run_game.active), world.current_room, str(res.get("forced", false)), world.run_game.vault])

# ================================================================ confirm_run_action 拒绝
func phase_confirm_rejections() -> void:
	world.travel("stash")
	await settle(2)
	# a) 面板未显示
	world.close_run_panel()
	var active_before: bool = world.run_game.active
	world.confirm_run_action()
	rec("confirm_panel_hidden_noop", world.run_game.active == active_before and not world.run_panel.visible,
		"active %s->%s panel=%s" % [str(active_before), str(world.run_game.active), str(world.run_panel.visible)])

	# b) 暂停中
	world.show_run_panel("enter")
	world.pause_game()
	var rev_b: int = world.run_game.revision
	world.confirm_run_action()
	rec("confirm_paused_noop", world.run_panel.visible and world.paused and world.run_game.revision == rev_b,
		"panel=%s paused=%s revision_unchanged=%s" % [str(world.run_panel.visible), str(world.paused), str(world.run_game.revision == rev_b)])
	world.resume()
	world.close_run_panel()

	# c) 路线未确认 -> confirm 禁用
	world.show_run_panel("route:fixed")
	var dis_c: bool = world.run_confirm.disabled
	var rev_c: int = world.run_game.revision
	world.confirm_run_action()
	rec("confirm_disabled_unknown_route", dis_c and world.run_panel.visible and world.run_game.revision == rev_c,
		"confirm_disabled=%s panel=%s revision_unchanged=%s" % [str(dis_c), str(world.run_panel.visible), str(world.run_game.revision == rev_c)])
	world.close_run_panel()

	# d) 预览模式（preview_only）-> confirm 禁用
	world.show_run_panel("route:general", true)
	var dis_d: bool = world.run_confirm.disabled and world.run_confirm.text == "到实际入口按 E 撤离"
	var rev_d: int = world.run_game.revision
	world.confirm_run_action()
	rec("confirm_disabled_preview", dis_d and world.run_game.revision == rev_d,
		"confirm_disabled=%s text=%s revision_unchanged=%s" % [str(world.run_confirm.disabled), world.run_confirm.text, str(world.run_game.revision == rev_d)])
	world.close_run_panel()

	# e) 未发现出口时进入撤离面板 -> confirm 禁用
	world.close_run_panel()
	var r := preload("res://three_d/rules/run.gd").new(world.table_content)
	r.start(r.revision, "smoky-den", 0)
	world.run_game = r
	world.travel("tavern")
	iso("confirm_disabled_exit_unknown: 换上一个未发现出口的全新 run（构造前置条件）")
	var rev_e: int = world.run_game.revision
	world.show_run_panel("extract")
	var dis_e: bool = world.run_confirm.disabled
	world.confirm_run_action()
	rec("confirm_disabled_exit_unknown", dis_e and world.run_game.revision == rev_e and world.run_game.active,
		"confirm_disabled=%s revision_unchanged=%s active=%s" % [str(dis_e), str(world.run_game.revision == rev_e), str(world.run_game.active)])
	world.close_run_panel()
