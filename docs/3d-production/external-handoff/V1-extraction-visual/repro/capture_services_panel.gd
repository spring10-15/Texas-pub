extends SceneTree
## V1 补充取证脚本（**状态复现探针，不是真实玩家操作路径**）。
##
## 背景：V1 交付后基线漂移（07f22459→39cb971a），
## Godot/three_d/tests/extraction_fallback_ui_test.gd 新增 12 行，最后 6 行
## 打开背包（world.open_services()）并对路线对比行做宽度断言
##   world.services_panel.rows.get_combined_minimum_size().x <= world.services_panel.size.x - 36
## 背包（services_panel）的路线对比行是**新出现的可视界面**，此前一条画面证据都没有。
## 本脚本在真实图形窗口中把它渲染出来，供人工目视（末行完整 / 裁切 / 重叠 / 数字可读 /
## 未知路线是否泄露 / 内边距余量）。
##
## 状态构造严格照抄当前 HEAD 测试的**同一会话变更顺序**（不能只截片段，否则 completed /
## inventory 等累积字段与测试不一致）：
##   :25-28  completed=["cargo-table"], public_exit=true, heat=5, cash=19
##   :42/45  cash=0 → 19
##   :46     inventory.append("ivory-chip")
##   :50-51  cash=300, heat=0
##   :57-60  route_flags={"service-stairs":true,"river-launch":true}
##           reservation=route_offer().duplicate(true), expiresAfterSearch=1, search_index=2
##
## 另外记录一个**探针 A**：忠实复现测试 :55→:63 的调用顺序（先 show_run_panel("extract")，
## 不清面板就直接 open_services()），打印 services_panel 是否真的被刷新，用于核对
## 宽度断言到底测到了什么。**这是诊断产物，不是玩家路径。**
##
## 用法：
##   python3 output/external-handoff/V1/run_godot.py --log <log> --timeout 180 --windowed \
##     -- --script <abs>/capture_services_panel.gd -- --test

const Run = preload("res://three_d/rules/run.gd")

const STATE_NOTE := "route_flags={service-stairs,river-launch} + 预约过期(search_index=2,expiresAfterSearch=1) → 背包路线对比行最长态"

func _initialize() -> void:
	call_deferred("run")

func delivery_dir() -> String:
	return ProjectSettings.globalize_path("res://../docs/3d-production/external-handoff/V1-extraction-visual/screenshots-supplement")

func diag_dir() -> String:
	return ProjectSettings.globalize_path("res://../output/external-handoff/V1/services-bag-initial")

func run() -> void:
	var out := delivery_dir()
	var diag := diag_dir()
	DirAccess.make_dir_recursive_absolute(out)
	DirAccess.make_dir_recursive_absolute(diag)
	print("CAPTURE_ENV ", JSON.stringify({
		"window": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"screen_size": [DisplayServer.screen_get_size().x, DisplayServer.screen_get_size().y],
		"screen_scale": DisplayServer.screen_get_scale(),
		"display_server": DisplayServer.get_name(),
		"video_adapter": RenderingServer.get_video_adapter_name(),
		"driver": ProjectSettings.get_setting("rendering/rendering_device/driver.macos", "n/a"),
		"godot": Engine.get_version_info().string,
	}))

	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var world: Node = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)

	var delivery := 0
	var diagnostic := 0
	for scene in Run.SCENE_NAMES:
		var session := Run.new(content)
		if not session.start(session.revision, scene, 0):
			print("CAPTURE_FAIL start ", scene)
			quit(1)
			return
		# —— 与测试 :25-28 完全一致的初始构造 ——
		session.completed.append("cargo-table")
		session.public_exit = true
		session.heat = 5
		session.cash = 19
		world.run_game = session
		world.travel("tavern")
		for i in range(8):
			await process_frame

		# ================= 探针 A：忠实复现测试 :55 → :63 的调用顺序 =================
		# 测试在 :55 show_run_panel("extract") 后，未关面板就在 :63 调 open_services()。
		world.show_run_panel("extract")
		await process_frame
		print("PROBE_A_PRE ", JSON.stringify({
			"venue": scene,
			"run_panel_visible": world.run_panel.visible,
			"services_panel_visible": world.services_panel.visible,
			"services_panel_size": [world.services_panel.size.x, world.services_panel.size.y],
			"rows_child_count": world.services_panel.rows.get_child_count(),
			"rows_min": [world.services_panel.rows.get_combined_minimum_size().x, world.services_panel.rows.get_combined_minimum_size().y],
		}))
		world.open_services()
		await process_frame
		print("PROBE_A_POST ", JSON.stringify({
			"venue": scene,
			"run_panel_visible": world.run_panel.visible,
			"services_panel_visible": world.services_panel.visible,
			"services_panel_size": [world.services_panel.size.x, world.services_panel.size.y],
			"rows_child_count": world.services_panel.rows.get_child_count(),
			"rows_min": [world.services_panel.rows.get_combined_minimum_size().x, world.services_panel.rows.get_combined_minimum_size().y],
			"width_assert_rhs": world.services_panel.size.x - 36,
			"width_assert_lhs": world.services_panel.rows.get_combined_minimum_size().x,
			"width_assert_passes": world.services_panel.rows.get_combined_minimum_size().x <= world.services_panel.size.x - 36,
			"note": "若 services_panel_visible=false 且 rows_child_count=0，则本轮宽度断言是在未刷新的空面板上求值（假通过）",
		}))
		world.close_run_panel()
		await process_frame

		# ================= 诊断图：初始态背包（未知路线泄露对照） =================
		# 此刻 route_flags 仍为空 → service-stairs/river-launch 不应出现在背包。
		world.open_services()
		diagnostic += await shoot(world, diag, scene, "bag-initial", "diagnostic-initial")

		# —— 测试 :42/:45-46 的中间态（不截图，仅保持累积字段一致）——
		session.cash = 0
		session.cash = 19
		session.inventory.append("ivory-chip")

		# —— 测试 :50-51（正常出口可付款，不截图）——
		session.cash = 300
		session.heat = 0

		# ================= 交付图：多行路线 + 过期路线预览 =================
		session.route_flags = {"service-stairs": true, "river-launch": true}
		session.reservation = session.route_offer().duplicate(true)
		session.reservation.expiresAfterSearch = 1
		session.search_index = 2
		world.open_services()
		delivery += await shoot(world, out, scene, "bag-expired-routes", STATE_NOTE)
		world.close_services()
		for i in range(3):
			await process_frame

	world.queue_free()
	print("CAPTURE_DONE delivery=%d diagnostic=%d" % [delivery, diagnostic])
	quit(0 if delivery == 4 else 1)

func shoot(world: Node, dir: String, scene: String, state_id: String, note: String) -> int:
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = dir.path_join("%s__%s.png" % [scene, state_id])
	var img: Image = root.get_texture().get_image()
	var err: int = img.save_png(path)
	var panel: Control = world.services_panel
	var rows: VBoxContainer = panel.rows
	var row_dump: Array = []
	for child in rows.get_children():
		var text := ""
		if child is Button:
			text = child.text
		elif child is Label:
			text = child.text
		row_dump.append({
			"type": child.get_class(),
			"min_x": child.get_combined_minimum_size().x,
			"size_x": child.size.x,
			"clipped": child.get_combined_minimum_size().x > child.size.x + 0.5,
			"text": text,
		})
	var known_dump: Array = []
	for action in world.run_game.service_view("bag").actions:
		if action.kind == "route":
			known_dump.append({
				"id": action.id,
				"route_known": world.run_game.route_known(action.id),
				"label": action.label,
				"reason": action.reason,
			})
	print("CAPTURE_ROW ", JSON.stringify({
		"venue": scene,
		"scenario": state_id,
		"note": note,
		"file": dir.path_join("%s__%s.png" % [scene, state_id]),
		"png": [img.get_width(), img.get_height()],
		"save_err": err,
		"exists": FileAccess.file_exists(path),
		"panel_size": [panel.size.x, panel.size.y],
		"panel_min": [panel.get_combined_minimum_size().x, panel.get_combined_minimum_size().y],
		"panel_margin": 18,
		"rows_min": [rows.get_combined_minimum_size().x, rows.get_combined_minimum_size().y],
		"rows_size": [rows.size.x, rows.size.y],
		"rows_child_count": rows.get_child_count(),
		"width_margin_px": panel.size.x - 36 - rows.get_combined_minimum_size().x,
		"rows": row_dump,
		"bag_route_actions": known_dump,
	}))
	return 1 if err == OK else 0
