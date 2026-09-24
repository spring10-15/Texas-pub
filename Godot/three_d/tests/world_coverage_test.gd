extends SceneTree
const RunCheckpoint = preload("res://three_d/rules/run_checkpoint.gd")
const WORLD_SOURCES := ["world.gd", "player.gd", "scene_props.gd"]
var hits := {}
var failures: Array[String] = []
var checks := 0
func verify(id: String, ok: bool) -> void:
	checks += 1
	if ok:
		hits["world."+id] = {"test":"world_coverage_test.gd", "postcondition_verified":true}
	else:
		failures.append(id)
		push_error(id)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world: Node3D = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	for i in range(3): await physics_frame
	world.set_process(false)
	var lamp: Dictionary = world.props.entries.lamp
	var anchor: Area3D = lamp.anchor
	var original: Dictionary = world.checkpoint_state()
	verify("raycast_unfocused", not world.request_action(anchor) and world.checkpoint_state()==original)
	var focus_events: Array = []
	world.player.focus_changed.connect(func(hit): focus_events.append(hit))
	world.player.position = Vector3(1.6, 0.02, -1.1)
	world.player.camera.look_at(anchor.global_position)
	for i in range(3): await physics_frame
	world.player.update_focus()
	verify("focus_acquired", world.player.focused==anchor and not focus_events.is_empty() and focus_events.back()==anchor and world.hint_label.text.contains(anchor.title))
	var target: Vector3 = anchor.global_position
	world.player.global_position = Vector3(target.x, 0.02, target.z + 3.0)
	world.player.camera.look_at(target)
	for i in range(3): await physics_frame
	world.player.update_focus()
	verify("focus_cleared", world.player.focused==null and not focus_events.is_empty() and focus_events.back()==null and world.hint_label.text.is_empty())
	var far: Dictionary = world.checkpoint_state()
	verify("raycast_out_of_reach", world.player.camera.global_position.distance_to(target)>world.player.REACH and world.player.focused!=anchor and not world.request_action(anchor) and world.checkpoint_state()==far)
	world.player.position = Vector3(1.6, 0.02, -1.1)
	world.player.camera.look_at(anchor.global_position)
	for i in range(3): await physics_frame
	world.player.update_focus()
	var reachable: bool = world.player.focused==anchor and world.player.camera.global_position.distance_to(target)<world.player.REACH
	var middle: Vector3 = (world.player.camera.global_position + target) * 0.5
	var occluder: Node3D = world.box(world, "CoverageOccluder", Vector3(middle.x,1.5,middle.z), Vector3(0.08,2.2,1.4), "wall")
	for i in range(3): await physics_frame
	world.player.update_focus()
	var occluded: Dictionary = world.checkpoint_state()
	verify("raycast_occluded", reachable and world.player.focused!=anchor and not world.request_action(anchor) and world.checkpoint_state()==occluded)
	occluder.queue_free()
	for i in range(3): await physics_frame
	world.player.update_focus()
	var aimed: Dictionary = world.checkpoint_state()
	verify("prop_on", world.request_action(anchor) and world.props.states.lamp and RunCheckpoint.capture(world.run_game)==aimed.run)
	var busy: Dictionary = world.checkpoint_state()
	verify("busy_guard", not world.request_action(anchor) and world.checkpoint_state()==busy)
	await create_timer(0.5).timeout
	verify("prop_visual", is_equal_approx(float(lamp.node.light_energy),0.0) and world.props.states.lamp)
	world.pause_game()
	for i in range(2): await physics_frame
	verify("focus_controls_disabled", not world.player.controls_enabled and world.player.focused==null and not focus_events.is_empty() and focus_events.back()==null and world.hint_label.text.is_empty())
	var paused: Dictionary = world.checkpoint_state()
	verify("pause_guard", not world.request_action(anchor) and world.checkpoint_state()==paused)
	world.open_services()
	verify("services_open_paused", world.paused and not world.services_panel.visible and world.pause_panel.visible and world.checkpoint_state()==paused)
	world.resume()
	world.show_run_panel("enter")
	var run_modal: Dictionary = world.checkpoint_state()
	world.open_services()
	verify("services_open_run_panel", world.run_panel.visible and not world.services_panel.visible and not world.player.controls_enabled and world.checkpoint_state()==run_modal)
	world.close_run_panel()
	world.open_services()
	var modal: Dictionary = world.checkpoint_state()
	verify("services_open", world.services_panel.visible and world.services_panel.rows.get_child_count()>0 and not world.player.controls_enabled and not world.crosshair.visible and not world.seat_panel.visible and world.checkpoint_state()==modal)
	verify("modal_guard", not world.request_action(anchor) and world.checkpoint_state()==modal)
	world.close_services()
	verify("services_close", not world.services_panel.visible and world.player.controls_enabled and world.crosshair.visible and not world.seat_panel.visible and world.checkpoint_state()==modal)
	var hidden_service: Dictionary = world.checkpoint_state()
	world.service_action("intel", "cargo-table", world.run_game.revision)
	verify("services_action_hidden", not world.services_panel.visible and world.checkpoint_state()==hidden_service)
	world.open_services()
	var unoffered_service: Dictionary = world.checkpoint_state()
	world.service_action("buy", "ivory-chip", world.run_game.revision)
	verify("services_action_unoffered", world.services_panel.visible and world.checkpoint_state()==unoffered_service)
	world.close_services()
	var saved: Dictionary = world.checkpoint_state()
	world.props.restore({})
	verify("prop_restore", world.restore_checkpoint(saved) and world.props.states.lamp and is_equal_approx(float(lamp.node.light_energy),0.0))
	world.player.position = Vector3(1.6, 0.02, -1.1)
	world.player.camera.look_at(anchor.global_position)
	for i in range(3): await physics_frame
	var lamp_before_reverse: Dictionary = RunCheckpoint.capture(world.run_game)
	var lamp_reversed: bool = world.request_action(anchor)
	await create_timer(0.5).timeout
	verify("prop_lamp_reverse", lamp_reversed and not world.props.states.lamp and is_equal_approx(float(lamp.node.light_energy),1.7) and RunCheckpoint.capture(world.run_game)==lamp_before_reverse)
	for prop_id in ["drawer0", "window", "card", "chip"]:
		await use_stash_prop(world, prop_id)
	var case_before: Dictionary = RunCheckpoint.capture(world.run_game)
	var case_aimed: bool = await aim_room_anchor(world, world.case_target)
	var case_closed: bool = case_aimed and world.case_open and world.request_action(world.case_target)
	await create_timer(0.75).timeout
	verify("case_close", case_closed and not world.case_open and world.case_target.title=="打开皮箱" and world.lid.rotation.is_equal_approx(world.lid_open_rotation + Vector3(deg_to_rad(102),0,0)) and RunCheckpoint.capture(world.run_game)==case_before)
	case_aimed = await aim_room_anchor(world, world.case_target)
	var case_reopened: bool = case_aimed and world.request_action(world.case_target)
	await create_timer(0.75).timeout
	verify("case_reopen", case_reopened and world.case_open and world.case_target.title=="合上皮箱" and world.lid.rotation.is_equal_approx(world.lid_open_rotation) and RunCheckpoint.capture(world.run_game)==case_before)
	var lamp_anchor: Area3D = world.props.entries.lamp.anchor
	var window_anchor: Area3D = world.props.entries.window.anchor
	var lamp_aimed: bool = await aim_room_anchor(world, lamp_anchor)
	var lamp_position: Vector3 = world.player.global_position
	var window_aimed: bool = await aim_room_anchor(world, window_anchor)
	var window_position: Vector3 = world.player.global_position
	world.player.global_position = lamp_position
	world.player.camera.look_at(lamp_anchor.global_position)
	for i in range(2): await physics_frame
	var lamp_started: bool = lamp_aimed and window_aimed and world.request_action(lamp_anchor)
	world.player.global_position = window_position
	world.player.camera.look_at(window_anchor.global_position)
	world.player.update_focus()
	var busy_before: Dictionary = world.checkpoint_state()
	var cross_rejected: bool = not world.request_action(window_anchor)
	verify("cross_prop_busy", lamp_started and world.action_busy and world.player.focused==window_anchor and cross_rejected and not world.props.states.window and world.checkpoint_state()==busy_before)
	await create_timer(0.5).timeout
	var room_prop_results := {"light_on":true, "light_off":true, "cupboard_open":true, "cupboard_close":true}
	for room_name in ["tavern", "ledger", "mirror", "embers"]:
		world.travel(room_name)
		for i in range(3): await physics_frame
		var prefix: String = {"tavern":"Tavern", "ledger":"LedgerCellar", "mirror":"MirrorHall", "embers":"EmbersRoom"}[room_name]
		await use_room_prop(world, prefix + "light", "light_on", "light_off", room_prop_results)
		await use_room_prop(world, prefix + "cupboard", "cupboard_open", "cupboard_close", room_prop_results)
	for outcome in room_prop_results:
		verify("room_" + outcome, room_prop_results[outcome])
	world.travel("tavern")
	world.player.position = Vector3(9.55, 0.02, 1.15)
	world.player.camera.look_at(world.table_target.global_position)
	for i in range(5): await physics_frame
	var unopened: Dictionary = world.checkpoint_state()
	verify("seat_blocked", not world.request_action(world.table_target) and not world.seated and world.checkpoint_state()==unopened)
	world.travel("stash")
	world.player.camera.look_at(world.door_target.global_position)
	for i in range(3): await physics_frame
	var door: bool = world.request_action(world.door_target)
	if door: world.confirm_run_action()
	verify("room_entry", door and world.current_room=="tavern" and world.run_game.active and world.run_game.vault==900 and world.run_game.cash==300)
	world.player.position = Vector3(9.55, 0.02, 1.15)
	world.player.camera.look_at(world.table_target.global_position)
	for i in range(5): await physics_frame
	var return_position: Vector3 = world.player.global_position
	verify("seat", world.request_action(world.table_target) and world.seated and world.seat_panel.visible and not world.player.controls_enabled and world.seat_camera.current)
	var seated_before_services: Dictionary = world.checkpoint_state()
	world.open_services()
	verify("services_open_seated", world.services_panel.visible and not world.seat_panel.visible and not world.player.controls_enabled and world.seat_camera.current and world.checkpoint_state()==seated_before_services)
	world.close_services()
	verify("services_close_seated", not world.services_panel.visible and world.seat_panel.visible and not world.player.controls_enabled and not world.crosshair.visible and world.seat_camera.current and world.checkpoint_state()==seated_before_services)
	world.pause_game()
	verify("pause", world.paused and not world.seat_panel.visible and world.pause_panel.visible and not world.player.controls_enabled)
	world.resume()
	verify("resume", not world.paused and world.seat_panel.visible and not world.pause_panel.visible and world.seated)
	world.leave_seat()
	verify("leave_pregame", not world.seated and world.table_game==null and world.player.controls_enabled and world.player.camera.current and world.player.global_position.is_equal_approx(return_position))
	world.player.camera.look_at(world.table_target.global_position)
	for i in range(5): await physics_frame
	var seated_again: bool = world.request_action(world.table_target)
	if seated_again: world.start_table(301)
	var active_table: RefCounted = world.table_game
	var cash_before: int = world.run_game.cash
	world.leave_seat()
	verify("leave_active_rejected", seated_again and active_table!=null and world.seated and world.table_game==active_table and world.run_game.cash==cash_before)
	var steps := 0
	while world.table_game.state.status != "finished" and steps < 200:
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
	var finished: bool = steps < 200 and world.table_game.state.status == "finished"
	var returned_stack: int = world.table_game.state.players[0].stack
	world.leave_seat()
	verify("leave_finished", finished and not world.seated and world.table_game == null and world.player.controls_enabled and world.player.camera.current and world.run_game.cash == cash_before + returned_stack and "cargo-table" in world.run_game.completed)
	var settled: Dictionary = world.checkpoint_state()
	world.leave_seat()
	verify("leave_unseated", world.checkpoint_state() == settled)
	world.show_run_panel("transfer")
	var destination: String = world.scene_choice.get_item_metadata(world.scene_choice.selected)
	var travel_quote: Dictionary = world.run_game.transfer_quote(destination)
	var vault_before: int = world.run_game.vault
	var cash_before_travel: int = world.run_game.cash
	world.confirm_run_action()
	verify("transfer_confirm", travel_quote.reason.is_empty() and world.current_room == "tavern" and world.run_game.scene_id == destination and world.run_game.venue_history.size() == 2 and world.run_game.vault == vault_before and world.run_game.cash == cash_before_travel - travel_quote.fee and not world.run_game.public_exit and not world.run_panel.visible)
	world.run_game.discover_exit()
	world.open_services()
	var route_preview_before: Dictionary = world.checkpoint_state()
	world.service_action("route", "general", world.run_game.revision)
	verify("services_route_preview", not world.services_panel.visible and world.run_panel.visible and world.run_action=="extract" and world.selected_route=="general" and world.run_confirm.disabled and world.run_body.text.contains("大厅入口门旁") and world.checkpoint_state()==route_preview_before)
	world.close_run_panel()
	var exit_quote: Dictionary = world.run_game.extraction_quote()
	world.show_run_panel("extract")
	world.confirm_run_action()
	verify("extract_confirm", exit_quote.reason.is_empty() and world.current_room == "stash" and not world.run_game.active and world.run_game.vault == vault_before + exit_quote.net and world.run_game.cash == 0 and not world.run_panel.visible)
	world.show_run_panel("enter")
	world.confirm_run_action()
	var before_abandon: Dictionary = world.run_game.abandon_quote()
	world.show_run_panel("abandon")
	world.confirm_run_action()
	verify("abandon_confirm", before_abandon.reason.is_empty() and world.current_room == "stash" and not world.run_game.active and world.run_game.vault == before_abandon.vaultAfter and world.run_game.last_result.abandoned and world.run_game.cash == 0 and not world.run_panel.visible)
	world.run_game.vault = 119
	world.show_run_panel("enter")
	var reset_offered: bool = world.run_action == "reset"
	world.confirm_run_action()
	verify("reset_confirm", reset_offered and world.run_game.vault == int(world.table_content.startingVault) and not world.run_game.active and world.current_room == "stash" and world.run_panel.visible and world.run_action == "enter")
	world.close_run_panel()
	var services_run_started: bool = world.run_game.start(world.run_game.revision, "smoky-den", 7)
	world.travel("tavern")
	world.open_services("bar")
	var intel_before: Dictionary = RunCheckpoint.capture(world.run_game)
	world.service_action("intel", "cargo-table", world.run_game.revision)
	verify("services_intel", services_run_started and world.services_panel.visible and world.run_game.known_rules == ["cargo-table"] and world.run_game.action_points == intel_before.action_points - 1 and world.run_game.revision == intel_before.revision + 1 and world.run_game.cash == intel_before.cash and world.run_game.service_view("bar").revision == world.run_game.revision)
	world.close_services()
	var product_id := ""
	for stocked_id in world.run_game.shop_stock():
		if world.run_game.service_reason("buy", stocked_id).is_empty():
			product_id = stocked_id
			break
	if not product_id.is_empty():
		world.open_services("product", product_id)
		var buy_before: Dictionary = RunCheckpoint.capture(world.run_game)
		world.service_action("buy", product_id, world.run_game.revision)
		verify("services_buy", not world.services_panel.visible and world.player.controls_enabled and product_id in world.run_game.inventory and world.run_game.cash == buy_before.cash - int(world.table_content.items[product_id].buy) and world.run_game.action_points == buy_before.action_points - 1 and world.run_game.revision == buy_before.revision + 1 and world.hint_label.text.contains(world.run_game.item_name(product_id)))
	else:
		verify("services_buy", false)
	var catalog_text := FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json")
	var catalog: Dictionary = JSON.parse_string(catalog_text)
	var expected: Array = catalog.transitions.filter(func(row): return str(row.id).begins_with("world.")).map(func(row): return row.id)
	var missing: Array = expected.filter(func(id): return not hits.has(id))
	for id in hits:
		if id not in expected: failures.append("Uncatalogued "+id)
	var hashes := {}
	for file in DirAccess.get_files_at("res://three_d/rules"):
		if file.ends_with(".gd") or file.ends_with(".json"): hashes[file] = FileAccess.get_file_as_string("res://three_d/rules/"+file).sha256_text()
	var world_hashes := {}
	for file in WORLD_SOURCES:
		world_hashes[file] = FileAccess.get_file_as_string("res://three_d/scripts/"+file).sha256_text()
	var report := {"scope":"Physical stash props, room entry, seating, full table leave, venue transfer, extraction, abandonment and demo reset through world UI","source_sha256":hashes,"world_source_sha256":world_hashes,"test_sha256":FileAccess.get_file_as_string("res://three_d/tests/world_coverage_test.gd").sha256_text(),"catalog_sha256":catalog_text.sha256_text(),"numerator":hits.size(),"denominator":expected.size(),"checks":checks,"hits":hits,"missing":missing,"failures":failures,"overall_state_transition_coverage":null}
	FileAccess.open("res://../output/3d/world-coverage.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("WORLD_COVERAGE covered=",hits.size()," total=",expected.size()," failed=",failures.size())
	quit(0 if failures.is_empty() and missing.is_empty() else 1)

func use_stash_prop(world: Node3D, prop_id: String) -> void:
	var entry: Dictionary = world.props.entries[prop_id]
	var anchor: Area3D = entry.anchor
	var offset := Vector3(0, 0, 0.65)
	if prop_id == "drawer0": offset = Vector3(0.7, 0, 0.65)
	if prop_id in ["card", "chip"]: offset = Vector3(0, 0, -0.7)
	world.player.global_position = Vector3(anchor.global_position.x + offset.x, 0.02, anchor.global_position.z + offset.z)
	for i in range(3): await physics_frame
	world.player.camera.look_at(anchor.global_position)
	await physics_frame
	var before: Dictionary = RunCheckpoint.capture(world.run_game)
	var activated: bool = world.request_action(anchor)
	await create_timer(0.5).timeout
	var actual: Variant = entry.node.get_indexed(NodePath(entry.property))
	var opened: Variant = entry.opened
	var visual_ok: bool = actual.is_equal_approx(opened) if actual is Vector3 else is_equal_approx(float(actual), float(opened))
	verify("prop_" + prop_id, activated and world.props.states[prop_id] and visual_ok and RunCheckpoint.capture(world.run_game)==before)
	world.player.global_position = Vector3(anchor.global_position.x + offset.x, 0.02, anchor.global_position.z + offset.z)
	for i in range(3): await physics_frame
	world.player.camera.look_at(anchor.global_position)
	await physics_frame
	before = RunCheckpoint.capture(world.run_game)
	var reversed: bool = world.request_action(anchor)
	await create_timer(0.5).timeout
	actual = entry.node.get_indexed(NodePath(entry.property))
	var closed: Variant = entry.closed
	visual_ok = actual.is_equal_approx(closed) if actual is Vector3 else is_equal_approx(float(actual), float(closed))
	verify("prop_" + prop_id + "_reverse", reversed and not world.props.states[prop_id] and visual_ok and RunCheckpoint.capture(world.run_game)==before)

func aim_room_anchor(world: Node3D, anchor: Area3D) -> bool:
	var target: Vector3 = anchor.global_position
	for radius in [0.55, 0.8, 1.1, 1.45]:
		for step in range(16):
			var angle: float = TAU * step / 16.0
			var position := Vector3(target.x + cos(angle) * radius, 0.02, target.z + sin(angle) * radius)
			world.player.global_position = position
			world.player.velocity = Vector3.ZERO
			for i in range(2): await physics_frame
			world.player.global_position = position
			world.player.camera.look_at(target)
			for i in range(2): await physics_frame
			world.player.update_focus()
			if world.player.focused == anchor: return true
	return false

func use_room_prop(world: Node3D, id: String, opened_key: String, closed_key: String, results: Dictionary) -> void:
	var entry: Dictionary = world.props.entries[id]
	var anchor: Area3D = entry.anchor
	var before: Dictionary = RunCheckpoint.capture(world.run_game)
	var aimed: bool = await aim_room_anchor(world, anchor)
	var opened: bool = aimed and world.request_action(anchor)
	await create_timer(0.5).timeout
	var actual: Variant = entry.node.get_indexed(NodePath(entry.property))
	results[opened_key] = results[opened_key] and opened and world.props.states[id] and is_equal_approx(float(actual), float(entry.opened)) and RunCheckpoint.capture(world.run_game)==before
	aimed = await aim_room_anchor(world, anchor)
	var closed: bool = aimed and world.request_action(anchor)
	await create_timer(0.5).timeout
	actual = entry.node.get_indexed(NodePath(entry.property))
	results[closed_key] = results[closed_key] and closed and not world.props.states[id] and is_equal_approx(float(actual), float(entry.closed)) and RunCheckpoint.capture(world.run_game)==before
