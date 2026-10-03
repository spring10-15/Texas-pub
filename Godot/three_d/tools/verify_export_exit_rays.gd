extends SceneTree
var failures := 0
var checks := 0

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	if not OS.get_cmdline_user_args().has("--test"):
		quit(1)
		return
	var world = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	var positions := {"FixedExit":Vector3(10, 0.02, -11), "KitchenExit":Vector3(7.25, 1.22, -12.1), "RiverExit":Vector3(12.75, -1.18, -13.1), "EmergencyCash":Vector3(7.2, 0.02, -7), "EmergencyGoods":Vector3(7.2, 0.02, -7)}
	for venue in world.RunRules.SCENE_NAMES:
		world.run_game = world.RunRules.new(world.table_content)
		verify(world.run_game.start(world.run_game.revision, venue, 0), "Start venue for exit rays")
		world.travel("tavern")
		for name in positions:
			var anchor: Area3D = world.get_node("Tavern/" + name)
			world.player.position = positions[name]
			world.player.camera.look_at(anchor.global_position)
			for i in range(5): await physics_frame
			var route: String = str(anchor.action_id).trim_prefix("route:")
			verify(world.player.can_interact(anchor), "Actual ray hits " + venue + "/" + name)
			verify(world.request_action(anchor), "Exit ray opens run panel")
			verify(world.run_panel.visible and world.selected_route == route, "Physical exit selects exact route")
			verify(world.run_confirm.disabled and world.run_body.text.contains("尚未获得"), "Unknown exit explains and prevents extraction")
			var before: Dictionary = world.RunCheckpoint.capture(world.run_game)
			world.confirm_run_action()
			verify(world.RunCheckpoint.capture(world.run_game) == before, "Disabled exit cannot charge or extract")
			world.close_run_panel()
	world.queue_free()
	await process_frame
	print("Export exit rays: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
