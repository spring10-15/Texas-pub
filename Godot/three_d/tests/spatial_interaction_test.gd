extends SceneTree
const Table = preload("res://three_d/rules/table.gd")
var world: Node3D
var failures: Array[String] = []
var checks := 0
func verify(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)
		push_error(text)
func _initialize() -> void:
	call_deferred("run")
func settle() -> void:
	for i in range(5):
		await physics_frame
func capture(name: String) -> void:
	if OS.get_cmdline_user_args().has("--capture"):
		for i in range(8):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../output/3d/" + name + ".png"))
func aim(position: Vector3, anchor: Area3D) -> void:
	world.player.position = position
	world.player.camera.look_at(anchor.global_position)
	await settle()
func walk_to(pos: Vector3) -> void:
	var count := 0
	world.player.controls_enabled = true
	while Vector2(world.player.position.x - pos.x, world.player.position.z - pos.z).length() > 0.13 and count < 240:
		count += 1
		var direction: Vector3 = pos - world.player.position
		world.player.rotation.y = atan2(-direction.x, -direction.z)
		Input.action_press("move_forward")
		await physics_frame
	Input.action_release("move_forward")
	verify(count < 240, "Walk reaches " + str(pos))

func finish_first_hand(table: RefCounted, force_player_win: bool) -> bool:
	var steps := 0
	while table.state.status == "playing" and steps < 100:
		steps += 1
		var actor: String = table.state.currentActorId
		if actor.is_empty():
			if not table.advance(table.revision): return false
		else:
			var legal: Dictionary = table.legal_actions(actor)
			var action := "all-in" if force_player_win and actor == "player" else ("fold" if force_player_win else "")
			if action.is_empty():
				if actor == "player":
					action = "call" if table.state.street == "preflop" else "fold"
				else:
					action = "check" if legal.get("check", false) else ("call" if legal.get("call", false) else "fold")
			if not table.act(actor, action, table.revision): return false
	return steps < 100 and table.state.status in ["hand_over", "finished"]

func run() -> void:
	world = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await settle()
	world.set_process(false)
	world.open_services()
	verify(world.services_panel.visible and world.run_game.service_view().actions.is_empty(), "Empty stash bag contains no shop or unknown routes")
	world.close_services()
	var positions := {"lamp":Vector3(1.6, 0.02, -1.1), "drawer0":Vector3(-1.8, 0.02, -1.2), "drawer1":Vector3(-2.1, 0.02, -0.9), "drawer2":Vector3(-1.8, 0.02, -1.2), "window":Vector3(1.8, 0.02, -0.4), "card":Vector3(0.55, 0.02, 0.5), "chip":Vector3(1.2, 0.02, 0.45)}
	for id in positions:
		var entry: Dictionary = world.props.entries[id]
		await aim(positions[id], entry.anchor)
		verify(world.request_action(entry.anchor), "Actual ray operates " + id)
		await create_timer(0.5).timeout
		verify(world.props.states[id], "Prop changed " + id)
		var actual: Variant = entry.node.get_indexed(NodePath(entry.property))
		var reached: bool = actual.is_equal_approx(entry.opened) if actual is Vector3 else (absf(angle_difference(float(actual), float(entry.opened))) < 0.001 if str(entry.property).begins_with("rotation:") else is_equal_approx(float(actual), float(entry.opened)))
		verify(reached, "Animated property reaches target " + id)
	var saved: Dictionary = world.checkpoint_state()
	world.props.restore({})
	verify(world.restore_checkpoint(saved) and world.props.states.window and world.props.states.card, "Interactive prop state restores")
	await aim(Vector3(1.65, 0.02, -0.7), world.props.entries.window.anchor)
	await capture("open-window")
	world.show_run_panel("enter")
	world.confirm_run_action()
	verify(world.run_game.service_view().actions.is_empty(), "New run bag hides all unknown routes")
	world.run_game.discover_exit()
	var routes: Array = world.run_game.service_view().actions.filter(func(a): return a.kind == "route")
	verify(routes.size() == 1 and routes[0].id == "general", "Only discovered route appears")
	world.open_services()
	world.service_action("route", "general", world.run_game.revision)
	verify(world.run_confirm.disabled and world.run_body.text.contains("大厅入口"), "Bag route is location preview, not remote extraction")
	world.close_run_panel()
	world.open_services()
	var cash: int = world.run_game.cash
	world.service_action("buy", "marked-lens", world.run_game.revision)
	verify(world.run_game.cash == cash, "Bag cannot dispatch a hidden purchase")
	world.close_services()
	var shelf: Area3D
	for node in world.get_node("Tavern/ShopObjects").get_children():
		if node is Area3D and str(node.action_id).begins_with("shop:"):
			shelf = node
			break
	verify(shelf != null, "Seeded shop has a physical product")
	if shelf == null:
		quit(1)
		return
	var product_id: String = str(shelf.action_id).trim_prefix("shop:")
	await aim(Vector3(shelf.global_position.x - 1.18, 0.02, shelf.global_position.z - 0.45), shelf)
	verify(world.request_action(shelf) and world.service_mode == "product", "Physical shelf opens single product")
	await capture("shelf-purchase")
	world.service_action("buy", product_id, world.run_game.revision)
	verify(world.run_game.inventory == [product_id] and not world.services_panel.visible, "Purchase hands off and enters bag once")
	await create_timer(0.65).timeout
	await capture("bartender-handoff")
	world.open_services()
	verify(world.run_game.service_view().actions.all(func(a): return a.kind not in ["buy", "intel", "sell", "cool", "reserve"]), "Owned bag does not expose shop or services")
	await capture("owned-bag")
	world.close_services()
	# Walk through connected architecture, including rising and descending floors.
	world.player.position = Vector3(10, 0.02, -2.7)
	await walk_to(Vector3(10, 0, -7))
	world.player.camera.look_at(Vector3(10, 1.8, -10))
	await capture("service-junction")
	await walk_to(Vector3(7.25, 0, -7))
	await walk_to(Vector3(7.25, 0, -8.6))
	await walk_to(Vector3(7.25, 1.2, -12.25))
	verify(world.player.position.y > 1.1, "Kitchen stair raises player onto upper landing")
	world.player.camera.look_at(Vector3(7.25, 2.6, -13))
	await capture("upper-kitchen-exit")
	await walk_to(Vector3(7.25, 0, -7))
	await walk_to(Vector3(10, 0, -7))
	await walk_to(Vector3(10, 0, -11.6))
	verify(absf(world.player.position.y) < 0.15, "Lift remains on storeroom ground level")
	world.player.camera.look_at(Vector3(11.3, 1.7, -11))
	await capture("storeroom-lift")
	await walk_to(Vector3(10, 0, -7))
	await walk_to(Vector3(12.75, 0, -7))
	await walk_to(Vector3(12.75, -1.2, -13))
	verify(world.player.position.y < -1.1, "Loading ramp descends to quay")
	world.player.camera.look_at(Vector3(12.75, -0.1, -14.5))
	await capture("river-quay")
	# Verify results from completed actions, as well as the neutral banner wording.
	var table: RefCounted = world.run_game.enter_table(301, world.run_game.revision)
	var view: Dictionary = table.public_state()
	var win_completed: bool = finish_first_hand(table, true)
	view = table.public_state()
	world.seat_panel.refresh(view)
	var win_net: int = int(view.summary.get("awards", {}).get("player", 0)) - int(view.players[0].handContribution)
	verify(win_completed and win_net > 0 and world.seat_panel.result_banner.visible and world.seat_panel.result_banner.text.contains("赢了") and world.seat_panel.result_banner.text.contains("+" + str(win_net)) and world.seat_panel.history.text.contains("你 全押"), "Real all-in win reaches the result banner and action history")
	var loss_table := Table.new()
	loss_table.start(world.table_content.tables["cargo-table"], 302)
	var loss_completed: bool = finish_first_hand(loss_table, false)
	var loss_view: Dictionary = loss_table.public_state()
	world.seat_panel.refresh(loss_view)
	var loss_net: int = int(loss_view.summary.get("awards", {}).get("player", 0)) - int(loss_view.players[0].handContribution)
	verify(loss_completed and loss_net < 0 and world.seat_panel.result_banner.visible and world.seat_panel.result_banner.text.contains("输了这一手") and world.seat_panel.result_banner.text.contains(str(loss_net)), "Real folded loss reaches the result banner")
	var tie_view: Dictionary = view.duplicate(true)
	tie_view.status = "hand_over"
	tie_view.players[0].handContribution = 40
	tie_view.summary = {"awards":{"player":40}}
	world.seat_panel.refresh(tie_view)
	verify(world.seat_panel.result_banner.visible and world.seat_panel.result_banner.text.contains("本手持平"), "Zero net uses neutral result wording")
	world.travel("tavern")
	world.seat_camera.current = true
	world.seat_panel.show()
	world.seat_panel.refresh(view)
	await capture("hand-result-banner")
	print("SPATIAL_INTERACTION ", JSON.stringify({"checks":checks, "failed":failures.size(), "failures":failures}))
	quit(0 if failures.is_empty() else 1)
