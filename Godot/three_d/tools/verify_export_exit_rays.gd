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
	for venue in world.RunRules.SCENE_NAMES:
		for name in positions:
			world.run_game = world.RunRules.new(world.table_content)
			verify(world.run_game.start(world.run_game.revision, venue, 0), "Start legitimate physical exit branch")
			var anchor: Area3D = world.get_node("Tavern/" + name)
			var route: String = str(anchor.action_id).trim_prefix("route:")
			prepare(world, route)
			world.travel("tavern")
			if route in ["fixed", "service-stairs", "river-launch"]:
				world.player.position = Vector3(10, 0.02, -2.7)
				await walk_to(world, Vector3(10, 0, -7))
				if route == "service-stairs":
					await walk_to(world, Vector3(7.25, 0, -7))
					await walk_to(world, Vector3(7.25, 0, -8.6))
					await walk_to(world, positions[name])
					verify(world.player.position.y > 1.1, "Walk climbs kitchen landing")
				elif route == "river-launch":
					await walk_to(world, Vector3(12.75, 0, -7))
					await walk_to(world, positions[name])
					verify(world.player.position.y < -1.1, "Walk descends to quay")
				else:
					await walk_to(world, positions[name])
			else:
				world.player.position = positions[name]
			world.player.camera.look_at(anchor.global_position)
			for i in range(5): await physics_frame
			var quote: Dictionary = world.run_game.extraction_quote(route)
			verify(quote.reason.is_empty(), "Legitimate physical route is available")
			var vault: int = world.run_game.vault
			verify(world.player.can_interact(anchor), "Unlocked exit is focused before E input")
			if DisplayServer.get_name() == "headless":
				verify(world.request_action(anchor), "Headless ray dispatch opens exit")
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				var key := InputEventKey.new()
				key.physical_keycode = KEY_E
				key.keycode = KEY_E
				key.pressed = true
				Input.parse_input_event(key)
				Input.flush_buffered_events()
				await process_frame
				var released: InputEventKey = key.duplicate()
				released.pressed = false
				Input.parse_input_event(released)
				Input.flush_buffered_events()
			verify(world.run_panel.visible and not world.run_confirm.disabled and world.selected_route == route, "Actual exit enables correct settlement")
			verify(world.run_body.text.contains("最终到账 " + str(quote.net)), "Exit preview shows exact quoted payout")
			world.confirm_run_action()
			verify(world.current_room == "stash" and not world.run_game.active, "Physical confirmation returns to stash")
			verify(world.run_game.vault == vault + int(quote.net) and world.run_game.last_result.route == route, "Physical confirmation credits selected route exactly")
			var completed: Dictionary = world.RunCheckpoint.capture(world.run_game)
			world.confirm_run_action()
			verify(world.RunCheckpoint.capture(world.run_game) == completed, "Repeated panel confirmation cannot credit twice")
			print("Physical exit completed: ", venue, "/", route)
	world.queue_free()
	await process_frame
	print("Export exit rays: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func prepare(world, route: String) -> void:
	var night = world.run_game
	var item: String = {"service-stairs":"kitchen-pass", "river-launch":"dock-passkey"}.get(route, "")
	for site in ["cargo-table", "ledger-cellar", "mirror-hall", "embers-table"]:
		if (not item.is_empty() and item in night.shop_stock()) or (item.is_empty() and not night.completed.is_empty()): break
		if night.heat > 0:
			verify(night.service_action("cool", "", night.revision), "Pay for cooling through actual service")
		var table = night.enter_table(301, night.revision, site)
		verify(table != null, "Unlock exit preparation by real table")
		if table == null: return
		var steps := 0
		while table.state.status != "finished" and steps < 200:
			steps += 1
			if table.state.status == "hand_over": table.next_hand(table.revision)
			elif table.state.currentActorId.is_empty(): table.advance(table.revision)
			else:
				var id: String = table.state.currentActorId
				var legal: Dictionary = table.legal_actions(id)
				verify(table.act(id, "fold" if id != "player" else ("check" if legal.check else "call"), table.revision), "Legal preparation table action")
		verify(night.settle_table(night.revision), "Settle preparation table")
	if not item.is_empty():
		verify(night.service_action("buy", item, night.revision), "Buy physical route pass")
		verify(night.service_action("pass", item, night.revision), "Use purchased route pass")
	elif route == "fixed":
		verify(night.service_action("reserve", "", night.revision), "Reserve physical lift route")
	verify(night.route_known(route), "Preparation discovers route without direct flags")

func walk_to(world, destination: Vector3) -> void:
	world.player.controls_enabled = true
	var frames := 0
	while Vector2(world.player.position.x - destination.x, world.player.position.z - destination.z).length() > 0.13 and frames < 300:
		frames += 1
		var direction: Vector3 = destination - world.player.position
		world.player.rotation.y = atan2(-direction.x, -direction.z)
		Input.action_press("move_forward")
		await physics_frame
	Input.action_release("move_forward")
	verify(frames < 300, "Continuous walk reaches " + str(destination))
