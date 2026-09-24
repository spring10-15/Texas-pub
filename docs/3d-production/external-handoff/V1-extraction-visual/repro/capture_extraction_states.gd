extends SceneTree
## V1 诊断脚本（**不是真实玩家操作路径**）。
##
## 作用：在真实图形窗口中，按 Godot/three_d/tests/extraction_fallback_ui_test.gd 的
## 情境基准构造 4 店 × 3 状态，逐个 save_png，供人工目视验收弹窗排版。
## 只读生产代码；不写正式存档；不接入正式测试列表。
##
## 状态取法严格照抄测试脚本的**同一会话变更顺序**（不能只截取片段，否则 completed /
## inventory 等累积字段与测试不一致）：
##   :25-28  completed=["cargo-table"], public_exit=true, heat=5, cash=19
##   :43     inventory.append("ivory-chip")
##   :47-48  cash=300, heat=0
##   :51-54  route_flags / reservation.expiresAfterSearch=1 / search_index=2
##
## 用法：
##   python3 output/external-handoff/V1/run_godot.py --log <log> --timeout 180 --windowed \
##     -- --script <abs>/capture_extraction_states.gd -- --test

const Run = preload("res://three_d/rules/run.gd")

const STATES := [
	{"id": "short-cash", "note": "现金19/风声5，普通出口付款不足，紧急出口可走"},
	{"id": "normal", "note": "现金300/风声0，普通出口可付款"},
	{"id": "expired-reservation", "note": "预约过期，route:fixed 最长备选"},
]

func _initialize() -> void:
	call_deferred("run")

func shots_dir() -> String:
	return ProjectSettings.globalize_path("res://../docs/3d-production/external-handoff/V1-extraction-visual/screenshots")

func run() -> void:
	var out := shots_dir()
	DirAccess.make_dir_recursive_absolute(out)
	print("CAPTURE_ENV ", JSON.stringify({
		"window": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"screen_size": [DisplayServer.screen_get_size().x, DisplayServer.screen_get_size().y],
		"screen_scale": DisplayServer.screen_get_scale(),
		"display_server": DisplayServer.get_name(),
		"video_adapter": RenderingServer.get_video_adapter_name(),
		"driver": ProjectSettings.get_setting("rendering/rendering_device/driver.macos", "n/a"),
	}))

	var t0 := Time.get_ticks_msec()
	print("CAPTURE_TIME boot=%d ms" % (Time.get_ticks_msec() - t0))
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var world: Node = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	print("CAPTURE_TIME world_ready=%d ms" % (Time.get_ticks_msec() - t0))

	var made := 0
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
		var t_travel := Time.get_ticks_msec()
		world.travel("tavern")
		for i in range(6):
			await process_frame
		print("CAPTURE_TIME %s travel=%d ms" % [scene, Time.get_ticks_msec() - t_travel])

		# —— 状态②：普通出口不足 + 紧急出口可用（测试 :34）——
		world.show_run_panel("extract")
		made += await shoot(world, out, scene, "short-cash")

		# —— 测试 :39-46 的中间态（不截图，仅为了保持后续状态累积一致）——
		session.cash = 0
		world.show_run_panel("extract")
		session.cash = 19
		session.inventory.append("ivory-chip")
		world.show_run_panel("extract")

		# —— 状态①：普通出口可付款（测试 :47-49）——
		session.cash = 300
		session.heat = 0
		world.show_run_panel("extract")
		made += await shoot(world, out, scene, "normal")

		# —— 状态③：预约过期 + route:fixed 最长备选（测试 :51-55）——
		session.route_flags = {"service-stairs": true, "river-launch": true}
		session.reservation = session.route_offer().duplicate(true)
		session.reservation.expiresAfterSearch = 1
		session.search_index = 2
		world.show_run_panel("route:fixed")
		made += await shoot(world, out, scene, "expired-reservation")

		world.close_run_panel()
		for i in range(3):
			await process_frame

	world.queue_free()
	print("CAPTURE_DONE made=%d" % made)
	quit(0 if made == 12 else 1)

func shoot(world: Node, out: String, scene: String, state_id: String) -> int:
	var t_show := Time.get_ticks_msec()
	for i in range(12):
		await process_frame
	var t_frames := Time.get_ticks_msec()
	await RenderingServer.frame_post_draw
	var t_draw := Time.get_ticks_msec()
	var path: String = out.path_join("%s__%s.png" % [scene, state_id])
	var img: Image = root.get_texture().get_image()
	var err: int = img.save_png(path)
	print("CAPTURE_TIME %s__%s frames=%d draw=%d save=%d" % [scene, state_id,
		t_frames - t_show, t_draw - t_frames, Time.get_ticks_msec() - t_draw])
	# 诊断元数据：仅供人工与 PNG 目视结论对照，**不能**替代画面验收。
	print("CAPTURE_ROW ", JSON.stringify({
		"venue": scene,
		"scenario": state_id,
		"file": "%s__%s.png" % [scene, state_id],
		"png": [img.get_width(), img.get_height()],
		"save_err": err,
		"exists": FileAccess.file_exists(path),
		"heading": world.run_heading.text,
		"confirm_text": world.run_confirm.text,
		"confirm_disabled": world.run_confirm.disabled,
		"forfeit_visible": world.forfeit_button.visible,
		"forfeit_text": world.forfeit_button.text,
		"panel_size": [world.run_panel.size.x, world.run_panel.size.y],
		"panel_min": [world.run_panel.get_combined_minimum_size().x, world.run_panel.get_combined_minimum_size().y],
		"body_min_h": world.run_body.get_combined_minimum_size().y,
		"body_size_h": world.run_body.size.y,
		"body": world.run_body.text,
	}))
	return 1 if err == OK else 0
