extends SceneTree
## V1 辅助探针（**不是真实玩家操作路径**，仅为「未知路线是否泄露」与背景房间复用范围提供依据）。
##
## 作用：用与 capture_extraction_states.gd 相同的情境构造，**不打开撤离弹窗**，
## 直接拍四家酒馆的 Tavern 房间原貌，用来核对：
##   1) 四家酒馆的背景房间是否同一间（travel("tavern") 之后）；
##   2) 墙面 Label3D 路线告示在「路线未获得」时显示了什么。
## 产物写到 output/external-handoff/V1/signage/（诊断区，不是交付的 12 张）。
##
## 用法：
##   python3 output/external-handoff/V1/run_godot.py --log <log> --timeout 120 --windowed \
##     -- --script <abs>/probe_tavern_signage.gd -- --test

const Run = preload("res://three_d/rules/run.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var out := ProjectSettings.globalize_path("res://../output/external-handoff/V1/signage")
	DirAccess.make_dir_recursive_absolute(out)
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var world: Node = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	for scene in Run.SCENE_NAMES:
		var session := Run.new(content)
		session.start(session.revision, scene, 0)
		session.completed.append("cargo-table")
		session.public_exit = true
		session.heat = 5
		session.cash = 19
		world.run_game = session
		world.travel("tavern")
		for i in range(12):
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		img.save_png(out.path_join("%s__tavern-noonpanel.png" % scene))
		# 顺便把墙面Label3D的文本原样打印出来，供人工核对
		var signs: Array = []
		for node in world.get_node("Tavern").get_children():
			if node is Label3D and node.has_meta("route_kind"):
				signs.append({"kind": str(node.get_meta("route_kind")), "text": node.text})
		print("SIGNAGE ", JSON.stringify({
			"venue": scene,
			"known": {
				"service-stairs": session.route_known("service-stairs"),
				"river-launch": session.route_known("river-launch"),
				"fixed": session.route_known("fixed"),
				"dropbag-cash": session.route_known("dropbag-cash"),
			},
			"signs": signs,
			"route_name_service_stairs": session.route_name("service-stairs"),
		}))
	print("SIGNAGE_DONE")
	quit()
