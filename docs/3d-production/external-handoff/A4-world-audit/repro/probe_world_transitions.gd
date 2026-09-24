extends SceneTree
## A4 世界交互状态转移诊断探针（**只为补齐现有测试未覆盖的后继状态**，不是新玩法规则）。
##
## 设计原则（对应任务书 A4）：
##   1. 一律走**公开入口**（world.request_action / travel / leave_seat / pause_game / resume /
##      show_run_panel / close_run_panel / confirm_run_action / open_services / close_services /
##      service_action），不直接改 props.states 伪造命中；
##   2. 一律用**真实相机射线**（player.camera.look_at + player.update_focus），与既有
##      world_coverage_test.gd / spatial_interaction_test.gd 同一套瞄准方式；
##   3. 每个用例同时核对**返回值 + 后继状态快照**（checkpoint_state()），拒绝类用例额外核对快照完全不变；
##   4. 找不到输入一律报 FAIL，**不做静默 continue**。
##
## 场景在内存中实例化；`--test` 下 world._ready() 不会 load_checkpoint()，也不开自动存档，
## 因此不读写玩家正式存档（正式存档路径见 README 的 mtime 前后比对）。
##
## 用法：
##   python3 output/external-handoff/V1/run_godot.py --log output/external-handoff/A4/probe-world.log \
##     --timeout 240 -- --script <abs>/probe_world_transitions.gd -- --test

const Run = preload("res://three_d/rules/run.gd")

var world: Node3D
var fails: Array[String] = []
var cases := 0
var notes: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func rec(id: String, ok: bool, detail: String) -> void:
	cases += 1
	print("A4CASE %s %s %s" % [id, "PASS" if ok else "FAIL", detail])
	if not ok:
		fails.append(id + " :: " + detail)

func note(text: String) -> void:
	notes.append(text)
	print("A4NOTE " + text)

func settle(n := 3) -> void:
	for i in range(n):
		await physics_frame

func prop_matches(e: Dictionary, actual: Variant, want: Variant) -> bool:
	if actual is Vector3:
		return actual.is_equal_approx(want)
	if str(e.property).begins_with("rotation:"):
		return absf(angle_difference(float(actual), float(want))) < 0.001
	return is_equal_approx(float(actual), float(want))

## 用真实射线把锚点瞄准：围绕锚点尝试多个落地偏移，直到 player.focused == anchor。
## 全部候选都失败则返回 false（由调用方报 FAIL，绝不静默跳过）。
func aim(anchor: Area3D, radius := 0.8) -> bool:
	var dirs := [
		Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1),
		Vector3(0.7071, 0, 0.7071), Vector3(-0.7071, 0, 0.7071),
		Vector3(0.7071, 0, -0.7071), Vector3(-0.7071, 0, -0.7071),
	]
	var target: Vector3 = anchor.global_position
	for r in [radius, radius * 0.6, radius * 1.4]:
		for d in dirs:
			var pos: Vector3 = target + d * r
			pos.y = 0.02
			world.player.global_position = pos
			world.player.velocity = Vector3.ZERO
			await settle(2)
			world.player.camera.look_at(target)
			await settle(2)
			world.player.update_focus()
			if world.player.focused == anchor:
				return true
	return false

func run() -> void:
	world = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await settle(4)
	world.set_process(false)
	note("world instantiated, set_process(false); saving_enabled=%s" % str(world.saving_enabled))

	await phase_guards()
	await phase_props_stash()
	await phase_seat_blocked()
	await phase_enter_run()
	await phase_room_and_doors()
	await phase_services()
	await phase_props_tavern()
	await phase_travel()
	await phase_seat_and_pause()
	await phase_heat_forced()
	await phase_active_table()
	await phase_services_after_table()
	await phase_confirm_rejections()

	print("A4PROBE_DONE cases=%d fails=%d" % [cases, fails.size()])
	for f in fails:
		print("A4FAIL " + f)
	quit(1 if not fails.is_empty() else 0)

# ---------------------------------------------------------------- 守卫类
func phase_guards() -> void:
	world.travel("stash")
	await settle(3)
	var lamp: Dictionary = world.props.entries.lamp
	var anchor: Area3D = lamp.anchor

	# 1) 准星未对准（射线方向偏离锚点）
	world.player.global_position = Vector3(1.6, 0.05, -1.1)
	await settle(2)
	world.player.camera.look_at(world.player.camera.global_position + Vector3(0, 0, 3.0))
	await settle(2)
	world.player.update_focus()
	var b1: Dictionary = world.checkpoint_state()
	var r1: bool = world.request_action(anchor)
	rec("raycast_not_aimed", r1 == false and world.player.focused != anchor and world.checkpoint_state() == b1,
		"r=%s focused!=anchor=%s snapshot_unchanged=%s" % [str(r1), str(world.player.focused != anchor), str(world.checkpoint_state() == b1)])

	# 2) 距离不够（瞄准正确但超出 REACH=2.0）
	world.player.global_position = Vector3(0.55, 0.05, 1.7)
	await settle(2)
	world.player.camera.look_at(anchor.global_position)
	await settle(2)
	world.player.update_focus()
	var dist: float = world.player.camera.global_position.distance_to(anchor.global_position)
	var b2: Dictionary = world.checkpoint_state()
	var r2: bool = world.request_action(anchor)
	rec("raycast_too_far", r2 == false and world.player.focused != anchor and world.checkpoint_state() == b2,
		"dist=%.2f(REACH=2.0) r=%s focused!=anchor=%s snapshot_unchanged=%s" % [dist, str(r2), str(world.player.focused != anchor), str(world.checkpoint_state() == b2)])

	# 3) 暂停阻挡
	world.pause_game()
	var b3: Dictionary = world.checkpoint_state()
	var r3: bool = world.request_action(anchor)
	var ok3: bool = r3 == false and world.checkpoint_state() == b3
	world.resume()
	rec("guard_paused", ok3, "paused=%s r=%s snapshot_unchanged=%s" % [str(world.paused), str(r3), str(world.checkpoint_state() == b3)])

	# 4) 服务弹窗阻挡
	world.open_services()
	var b4: Dictionary = world.checkpoint_state()
	var r4: bool = world.request_action(anchor)
	var ok4: bool = r4 == false and world.services_panel.visible and world.checkpoint_state() == b4
	world.close_services()
	rec("guard_services_modal", ok4, "services_visible=%s r=%s snapshot_unchanged=%s" % [str(world.services_panel.visible), str(r4), str(world.checkpoint_state() == b4)])

	# 5) 路线弹窗阻挡
	world.show_run_panel("enter")
	var b5: Dictionary = world.checkpoint_state()
	var r5: bool = world.request_action(anchor)
	var ok5: bool = r5 == false and world.run_panel.visible and world.checkpoint_state() == b5
	world.close_run_panel()
	rec("guard_run_panel", ok5, "run_panel_visible=%s r=%s snapshot_unchanged=%s" % [str(world.run_panel.visible), str(r5), str(world.checkpoint_state() == b5)])

# ---------------------------------------------------------------- 道具（藏匿点）
func phase_props_stash() -> void:
	world.travel("stash")
	await settle(3)
	for id in ["lamp", "drawer0", "drawer1", "drawer2", "window", "card", "chip"]:
		await prop_cycle(id)
	await busy_guard_case()
	await toggle_case_case()

func prop_cycle(id: String) -> void:
	var e: Dictionary = world.props.entries[id]
	if not await aim(e.anchor):
		rec("prop_" + id + "_aim", false, "no landing offset reached anchor (input not found)")
		return
	var before: Dictionary = world.checkpoint_state()
	var r1: bool = world.request_action(e.anchor)
	await create_timer(0.6).timeout
	var v1: Variant = e.node.get_indexed(NodePath(e.property))
	var forward_ok: bool = r1 and world.props.states[id] and prop_matches(e, v1, e.opened)
	rec("prop_" + id + "_forward", forward_ok,
		"r=%s states=%s actual=%s want_opened=%s" % [str(r1), str(world.props.states[id]), str(v1), str(e.opened)])
	var r2: bool = world.request_action(e.anchor)
	await create_timer(0.6).timeout
	var v2: Variant = e.node.get_indexed(NodePath(e.property))
	var reverse_ok: bool = r2 and not world.props.states[id] and prop_matches(e, v2, e.closed)
	rec("prop_" + id + "_reverse", reverse_ok,
		"r=%s states=%s actual=%s want_closed=%s" % [str(r2), str(world.props.states[id]), str(v2), str(e.closed)])
	var after: Dictionary = world.checkpoint_state()
	rec("prop_" + id + "_run_untouched", before.run == after.run,
		"run_capture_before==after=%s" % str(before.run == after.run))

func busy_guard_case() -> void:
	var e: Dictionary = world.props.entries.window
	if not await aim(e.anchor):
		rec("busy_guard_aim", false, "no landing offset reached window anchor")
		return
	var r1: bool = world.request_action(e.anchor)
	var mid: Dictionary = world.checkpoint_state()
	var busy_now: bool = world.action_busy
	var r2: bool = world.request_action(e.anchor)
	var ok: bool = r1 and busy_now and r2 == false and world.checkpoint_state() == mid
	rec("busy_guard", ok, "first=%s action_busy=%s second=%s snapshot_unchanged=%s" % [str(r1), str(busy_now), str(r2), str(world.checkpoint_state() == mid)])
	await create_timer(0.6).timeout
	world.request_action(e.anchor)  # 复位到 closed
	await create_timer(0.6).timeout

func toggle_case_case() -> void:
	world.travel("stash")
	await settle(2)
	if not is_instance_valid(world.lid):
		rec("toggle_case_lid_present", false, "world.lid invalid -> Toggle_Case would be unreachable")
		return
	rec("toggle_case_lid_present", true, "CaseLidPivot found in stash.glb")
	var anchor: Area3D = world.case_target
	if not await aim(anchor, 1.1):
		rec("toggle_case_aim", false, "no landing offset reached case_target")
		return
	var start_open: bool = world.case_open
	var r1: bool = world.request_action(anchor)
	await create_timer(0.8).timeout
	var mid_open: bool = world.case_open
	var title1: String = anchor.title
	rec("toggle_case_close", r1 and start_open and mid_open == false and title1 == "打开皮箱",
		"r=%s case_open %s -> %s title=%s" % [str(r1), str(start_open), str(mid_open), title1])
	var r2: bool = world.request_action(anchor)
	await create_timer(0.8).timeout
	rec("toggle_case_open", r2 and world.case_open == true and anchor.title == "合上皮箱",
		"r=%s case_open=%s title=%s" % [str(r2), str(world.case_open), anchor.title])

# ---------------------------------------------------------------- 入座前置
func phase_seat_blocked() -> void:
	world.travel("tavern")
	await settle(3)
	if not await aim(world.table_target, 1.2):
		rec("seat_blocked_aim", false, "no landing offset reached table_target")
		return
	var before: Dictionary = world.checkpoint_state()
	var r: bool = world.request_action(world.table_target)
	rec("seat_blocked_inactive", r == false and not world.seated and not world.hint_label.text.is_empty() and world.checkpoint_state() == before,
		"r=%s seated=%s hint=%s snapshot_unchanged=%s" % [str(r), str(world.seated), world.hint_label.text, str(world.checkpoint_state() == before)])

# ---------------------------------------------------------------- 进入酒馆
func phase_enter_run() -> void:
	world.travel("stash")
	await settle(3)
	if not await aim(world.door_target, 1.2):
		rec("enter_panel_aim", false, "no landing offset reached door_target")
		return
	var r1: bool = world.request_action(world.door_target)
	rec("enter_panel_open", r1 and world.run_panel.visible and world.run_action == "enter",
		"r=%s run_panel=%s run_action=%s" % [str(r1), str(world.run_panel.visible), world.run_action])
	var vault_before: int = world.run_game.vault
	world.confirm_run_action()
	var ok: bool = world.current_room == "tavern" and world.run_game.active and world.run_game.vault == vault_before - 300 and world.run_game.cash == 300 and not world.run_panel.visible
	rec("confirm_enter", ok, "room=%s active=%s vault %d->%d cash=%d panel=%s" % [world.current_room, str(world.run_game.active), vault_before, world.run_game.vault, world.run_game.cash, str(world.run_panel.visible)])

# ---------------------------------------------------------------- 房间门与告示
func phase_room_and_doors() -> void:
	world.travel("tavern")
	await settle(3)

	# 账房地窖门：尚未完成货运桌 -> 拒绝
	if not await aim(world.ledger_door, 1.2):
		rec("room_door_blocked_aim", false, "no landing offset reached ledger_door")
	else:
		var before: Dictionary = world.checkpoint_state()
		var r: bool = world.request_action(world.ledger_door)
		rec("room_door_blocked", r == false and world.current_room == "tavern" and not world.hint_label.text.is_empty() and world.checkpoint_state() == before,
			"r=%s room=%s hint=%s snapshot_unchanged=%s" % [str(r), world.current_room, world.hint_label.text, str(world.checkpoint_state() == before)])

	# 出口告示：首次生效
	if not await aim(world.exit_notice, 1.1):
		rec("discover_exit_aim", false, "no landing offset reached exit_notice")
	else:
		var r1: bool = world.request_action(world.exit_notice)
		var rev1: int = world.run_game.revision
		var ok1: bool = r1 and world.run_game.public_exit and world.run_game.route_known("general")
		rec("discover_exit", ok1, "r=%s public_exit=%s revision=%d" % [str(r1), str(world.run_game.public_exit), rev1])
		var r2: bool = world.request_action(world.exit_notice)
		var rev2: int = world.run_game.revision
		rec("discover_exit_repeat_noop", r2 == true and rev2 == rev1,
			"r=%s revision %d -> %d (重复触发仍返回 true，但运行状态不变)" % [str(r2), rev1, rev2])

# ---------------------------------------------------------------- 服务
func phase_services() -> void:
	world.travel("tavern")
	await settle(3)
	await services_guards()
	await services_search_apply()
	await services_bag_reject_and_preview()

func services_guards() -> void:
	world.pause_game()
	world.open_services()
	var ok1: bool = not world.services_panel.visible
	world.resume()
	rec("services_open_blocked_paused", ok1, "paused 时 open_services 是否被拒绝（services_visible=%s）" % str(world.services_panel.visible))

	world.show_run_panel("enter")
	world.open_services()
	var ok2: bool = not world.services_panel.visible
	world.close_run_panel()
	rec("services_open_blocked_run_panel", ok2, "run_panel 可见时 open_services 是否被拒绝（services_visible=%s）" % str(world.services_panel.visible))

func services_search_apply() -> void:
	world.travel("tavern")
	await settle(2)
	var site: Area3D
	for node in world.get_node("Tavern").get_children():
		if node is Area3D and str(node.action_id) == "search:cargo-table":
			site = node
			break
	if site == null:
		rec("services_search_open_aim", false, "Tavern 下找不到 search:cargo-table 锚点")
		return
	if not await aim(site, 1.0):
		rec("services_search_open_aim", false, "no landing offset reached search anchor")
		return
	var r1: bool = world.request_action(site)
	rec("services_search_open", r1 and world.services_panel.visible and world.service_mode == "search",
		"r=%s visible=%s mode=%s" % [str(r1), str(world.services_panel.visible), world.service_mode])
	var rev: int = world.run_game.revision
	var points_before: int = world.run_game.action_points
	var r2: bool = world.service_action("search", "cargo-table", rev, "lead")
	var ok2: bool = r2 and world.run_game.route_flags.get("fixed", false) == true and world.run_game.action_points == points_before - 1 and world.services_panel.visible
	rec("services_search_apply_lead", ok2,
		"r=%s route_flags.fixed=%s action_points %d->%d panel_visible=%s" % [str(r2), str(world.run_game.route_flags.get("fixed", false)), points_before, world.run_game.action_points, str(world.services_panel.visible)])
	world.close_services()

func services_bar_cool() -> void:
	world.travel("tavern")
	await settle(2)
	var bar: Area3D
	for node in world.get_node("Tavern").get_children():
		if node is Area3D and str(node.action_id) == "services":
			bar = node
			break
	if bar == null:
		rec("services_bar_open_aim", false, "Tavern 下找不到 services 锚点")
		return
	if not await aim(bar, 1.0):
		rec("services_bar_open_aim", false, "no landing offset reached bar anchor")
		return
	var r1: bool = world.request_action(bar)
	rec("services_bar_open", r1 and world.services_panel.visible and world.service_mode == "bar",
		"r=%s visible=%s mode=%s" % [str(r1), str(world.services_panel.visible), world.service_mode])
	var rev: int = world.run_game.revision
	var heat_before: int = world.run_game.heat
	var cash_before: int = world.run_game.cash
	var offered: bool = world.run_game.service_view("bar", "").actions.any(func(a): return a.kind == "cool")
	if not offered:
		rec("services_bar_cool_offered", false, "bar 视图未提供 cool 动作（heat=%d）" % heat_before)
		world.close_services()
		return
	var r2: bool = world.service_action("cool", "", rev)
	var ok2: bool = r2 and world.run_game.heat == heat_before - 1 and world.run_game.cash == cash_before - 24 and world.services_panel.visible
	rec("services_bar_cool_apply", ok2,
		"r=%s heat %d->%d cash %d->%d panel_visible=%s" % [str(r2), heat_before, world.run_game.heat, cash_before, world.run_game.cash, str(world.services_panel.visible)])
	world.close_services()

func services_bag_reject_and_preview() -> void:
	world.travel("tavern")
	await settle(2)
	world.open_services()
	var ok1: bool = world.services_panel.visible and world.service_mode == "bag"
	var rev: int = world.run_game.revision
	var cash: int = world.run_game.cash
	var r1: bool = world.service_action("buy", "marked-lens", rev)
	rec("services_bag_buy_not_offered", ok1 and r1 == false and world.run_game.cash == cash and world.services_panel.visible,
		"panel=%s r=%s cash %d->%d panel_still_visible=%s" % [str(ok1), str(r1), cash, world.run_game.cash, str(world.services_panel.visible)])
	var unknown := "dropbag-cash"
	var r2: bool = world.service_action("route", unknown, world.run_game.revision)
	var ok2: bool = r2 == false and world.services_panel.visible and not world.run_game.route_known(unknown)
	rec("services_route_unknown_rejected", ok2, "route=%s known=%s r=%s panel_visible=%s" % [unknown, str(world.run_game.route_known(unknown)), str(r2), str(world.services_panel.visible)])
	# 已公开出口后再试已知路线：应转入路线预览弹窗
	world.close_services()
	var r3_ok := await route_preview_case()
	rec("services_route_general_preview", r3_ok, "已发现出口后 route 预览弹窗状态")

func route_preview_case() -> bool:
	world.open_services()
	var r: bool = world.service_action("route", "general", world.run_game.revision)
	var ok: bool = r and not world.services_panel.visible and world.run_panel.visible and world.run_confirm.disabled
	world.close_run_panel()
	return ok

# ---------------------------------------------------------------- 道具（四家酒馆）
func phase_props_tavern() -> void:
	var rooms := {"tavern": ["Tavernlight", "Taverncupboard"], "ledger": ["LedgerCellarlight", "LedgerCellarcupboard"], "mirror": ["MirrorHalllight", "MirrorHallcupboard"], "embers": ["EmbersRoomlight", "EmbersRoomcupboard"]}
	for dest in rooms:
		world.travel(dest)
		await settle(3)
		for id in rooms[dest]:
			await prop_cycle(id)

# ---------------------------------------------------------------- travel
func phase_travel() -> void:
	var expect := {"tavern": "烟雾酒馆", "ledger": "账房地窖", "mirror": "镜厅", "embers": "余烬牌室", "stash": "藏匿点"}
	var detail: Array[String] = []
	var all_ok := true
	for dest in expect:
		world.travel(dest)
		await settle(2)
		var ok: bool = world.current_room == dest
		all_ok = all_ok and ok
		detail.append("%s->%s" % [dest, world.current_room])
	rec("travel_all_destinations", all_ok, " ".join(detail))

# ---------------------------------------------------------------- 入座/暂停/离座
func phase_seat_and_pause() -> void:
	world.travel("tavern")
	await settle(3)
	if not await aim(world.table_target, 1.2):
		rec("seat_aim", false, "no landing offset reached table_target")
		return
	var return_pos: Vector3 = world.player.global_position
	var r: bool = world.request_action(world.table_target)
	rec("seat", r and world.seated and world.seat_panel.visible and not world.player.controls_enabled and world.seat_camera.current,
		"r=%s seated=%s seat_panel=%s controls=%s seat_cam=%s" % [str(r), str(world.seated), str(world.seat_panel.visible), str(world.player.controls_enabled), str(world.seat_camera.current)])

	# 入座态下的 request_action 守卫
	var lamp_anchor: Area3D = world.props.entries.lamp.anchor
	var bs: Dictionary = world.checkpoint_state()
	var rs: bool = world.request_action(lamp_anchor)
	rec("guard_seated", rs == false and world.seated and world.checkpoint_state() == bs,
		"r=%s seated=%s snapshot_unchanged=%s" % [str(rs), str(world.seated), str(world.checkpoint_state() == bs)])

	# 暂停/继续（入座态）
	world.pause_game()
	var btn: Button = world.pause_panel.find_children("*", "Button", true, false)[0]
	var ok_pause: bool = world.paused and not world.seat_panel.visible and world.pause_panel.visible and not world.player.controls_enabled and btn.text == "继续牌局"
	rec("pause_seated", ok_pause, "paused=%s seat_panel=%s pause_panel=%s controls=%s button=%s" % [str(world.paused), str(world.seat_panel.visible), str(world.pause_panel.visible), str(world.player.controls_enabled), btn.text])
	world.resume()
	rec("resume_seated", not world.paused and world.seat_panel.visible and not world.pause_panel.visible and world.seated and not world.player.controls_enabled,
		"paused=%s seat_panel=%s pause_panel=%s seated=%s controls=%s" % [str(world.paused), str(world.seat_panel.visible), str(world.pause_panel.visible), str(world.seated), str(world.player.controls_enabled)])

	# 入座态打开/关闭服务（open_services 不检查 seated）
	world.open_services()
	var ok_open: bool = world.services_panel.visible and not world.seat_panel.visible
	world.close_services()
	var ok_close: bool = not world.services_panel.visible and world.seat_panel.visible
	rec("services_while_seated", ok_open and ok_close, "open: services=%s seat_panel=%s | close: services=%s seat_panel=%s" % [str(ok_open), str(world.seat_panel.visible), str(ok_close), str(world.seat_panel.visible)])

	# 暂停态离座被拒绝
	world.pause_game()
	var bp: Dictionary = world.checkpoint_state()
	world.leave_seat()
	var ok_lp: bool = world.seated and world.paused and world.checkpoint_state() == bp
	world.resume()
	rec("leave_paused_rejected", ok_lp, "seated=%s paused=%s snapshot_unchanged=%s" % [str(world.seated), str(world.paused), str(world.checkpoint_state() == bp)])

	# 未开局离座（接受）
	world.leave_seat()
	var ok_lf: bool = not world.seated and world.table_game == null and world.player.controls_enabled and world.player.camera.current and world.player.global_position.is_equal_approx(return_pos)
	rec("leave_pregame", ok_lf, "seated=%s table_game=%s controls=%s cam_current=%s back_to_return=%s" % [str(world.seated), str(world.table_game), str(world.player.controls_enabled), str(world.player.camera.current), str(world.player.global_position.is_equal_approx(return_pos))])

func phase_heat_forced() -> void:
	# 构造风声 6 的**前置条件**（heat 本身可由多桌入场自然累加；此处为省时直接注入并如实标注）
	world.travel("tavern")
	await settle(3)
	if not await aim(world.table_target, 1.2):
		rec("leave_heat6_aim", false, "no landing offset reached table_target")
		return
	if not world.request_action(world.table_target):
		rec("leave_heat6_seat", false, "seat failed")
		return
	world.run_game.heat = 6
	var active_before: bool = world.run_game.active
	world.leave_seat()
	var res: Dictionary = world.run_game.last_result
	var ok: bool = active_before and not world.seated and not world.run_game.active and world.current_room == "stash" and res.get("forced", false) == true and world.run_game.cash == 0
	rec("leave_pregame_heat6_forced", ok,
		"active %s -> %s room=%s forced=%s cash=%d result.route=%s" % [str(active_before), str(world.run_game.active), world.current_room, str(res.get("forced", false)), world.run_game.cash, str(res.get("route", ""))])
	note("leave_pregame_heat6_forced 的 heat=6 为注入前置条件（非玩家逐步累加），仅用于到达该分支")

# ---------------------------------------------------------------- 活动牌桌
func phase_active_table() -> void:
	# 重新开局
	world.travel("stash")
	await settle(3)
	if not await aim(world.door_target, 1.2):
		rec("active_door_aim", false, "no landing offset reached door_target")
		return
	if not world.request_action(world.door_target):
		rec("active_door_press", false, "door press failed")
		return
	world.confirm_run_action()
	if world.current_room != "tavern":
		rec("active_enter_run", false, "enter run failed, room=%s" % world.current_room)
		return
	world.travel("tavern")
	await settle(3)
	if not await aim(world.table_target, 1.2):
		rec("active_seat_aim", false, "no landing offset reached table_target")
		return
	if not world.request_action(world.table_target):
		rec("active_seat", false, "seat failed")
		return
	world.start_table(301)
	var table: RefCounted = world.table_game
	if table == null:
		rec("active_start_table", false, "start_table(301) returned null")
		return
	var cash_before: int = world.run_game.cash
	world.leave_seat()
	rec("leave_active_rejected", world.seated and world.table_game == table and world.run_game.cash == cash_before,
		"seated=%s same_table=%s cash %d->%d" % [str(world.seated), str(world.table_game == table), cash_before, world.run_game.cash])

	var finished := finish_table()
	if not finished:
		rec("active_finish_table", false, "table did not reach finished within cap")
		return
	var returned: int = world.table_game.state.players[0].stack
	world.leave_seat()
	var ok: bool = not world.seated and world.table_game == null and world.player.controls_enabled and world.run_game.cash == cash_before + returned and "cargo-table" in world.run_game.completed
	rec("leave_finished", ok, "seated=%s table=%s cash %d+%d=%d completed=%s" % [str(world.seated), str(world.table_game), cash_before, returned, world.run_game.cash, str(world.run_game.completed)])

	var settled: Dictionary = world.checkpoint_state()
	world.leave_seat()
	rec("leave_unseated", world.checkpoint_state() == settled and not world.seated, "snapshot_unchanged=%s seated=%s" % [str(world.checkpoint_state() == settled), str(world.seated)])

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
			var action := "fold" if actor != "player" else ("check" if legal.check else "call")
			table.act(actor, action, table.revision)
	return steps < 400 and world.table_game != null and world.table_game.state.status == "finished"

# ---------------------------------------------------------------- 完成一桌后的服务（heat=1 才有 cool）
func phase_services_after_table() -> void:
	world.travel("tavern")
	await settle(3)
	rec("post_table_heat_is_one", world.run_game.heat == 1 and world.run_game.table == null,
		"heat=%d table=%s completed=%s" % [world.run_game.heat, str(world.run_game.table), str(world.run_game.completed)])
	await services_bar_cool()

# ---------------------------------------------------------------- 确认弹窗拒绝
func phase_confirm_rejections() -> void:
	world.travel("stash")
	await settle(2)
	# a) 面板已关闭
	world.close_run_panel()
	var active_before: bool = world.run_game.active
	world.confirm_run_action()
	rec("confirm_panel_hidden", world.run_game.active == active_before and not world.run_panel.visible,
		"active %s -> %s panel=%s" % [str(active_before), str(world.run_game.active), str(world.run_panel.visible)])

	# b) 暂停中
	world.show_run_panel("enter")
	world.pause_game()
	var rev_b: int = world.run_game.revision
	world.confirm_run_action()
	var ok_b: bool = world.run_panel.visible and world.run_game.revision == rev_b and world.paused
	world.resume()
	rec("confirm_paused", ok_b, "panel_visible=%s revision_unchanged=%s paused=%s" % [str(world.run_panel.visible), str(world.run_game.revision == rev_b), str(world.paused)])

	# c) route 未知（fixed 未预约）-> 确认按钮禁用
	world.show_run_panel("route:fixed")
	var disabled_c: bool = world.run_confirm.disabled
	var rev_c: int = world.run_game.revision
	world.confirm_run_action()
	var ok_c: bool = disabled_c and world.run_panel.visible and world.run_game.revision == rev_c
	rec("confirm_disabled_unprepared_route", ok_c, "confirm_disabled=%s panel_visible=%s revision_unchanged=%s" % [str(disabled_c), str(world.run_panel.visible), str(world.run_game.revision == rev_c)])

	# d) 预览模式 -> 禁用
	world.close_run_panel()
	world.show_run_panel("route:general", true)
	var disabled_d: bool = world.run_confirm.disabled and world.run_confirm.text == "到实际入口按 E 撤离"
	var rev_d: int = world.run_game.revision
	world.confirm_run_action()
	var ok_d: bool = disabled_d and world.run_game.revision == rev_d
	world.close_run_panel()
	rec("confirm_disabled_preview", ok_d, "confirm_disabled=%s text=%s revision_unchanged=%s" % [str(disabled_d), world.run_confirm.text, str(world.run_game.revision == rev_d)])

	# e) 未发现出口时进入撤离面板 -> 确认禁用
	world.close_run_panel()
	var session := Run.new(world.table_content)
	session.start(session.revision, "smoky-den", 0)
	world.run_game = session
	world.travel("tavern")
	var rev_e: int = world.run_game.revision
	world.show_run_panel("extract")
	var disabled_e: bool = world.run_confirm.disabled
	world.confirm_run_action()
	var ok_e: bool = disabled_e and world.run_game.revision == rev_e and world.run_game.active
	world.close_run_panel()
	rec("confirm_disabled_exit_unknown", ok_e, "confirm_disabled=%s revision_unchanged=%s active=%s" % [str(disabled_e), str(world.run_game.revision == rev_e), str(world.run_game.active)])
