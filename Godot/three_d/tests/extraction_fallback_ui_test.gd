extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Checkpoint = preload("res://three_d/rules/run_checkpoint.gd")
var checks := 0
var failures: Array[String] = []

func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var world: Node = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	for scene in Run.SCENE_NAMES:
		var session := Run.new(content)
		verify(session.start(session.revision, scene, 0), scene + " starts")
		session.completed.append("cargo-table")
		session.public_exit = true
		session.heat = 5
		session.cash = 19
		world.run_game = session
		world.travel("tavern")
		var before: Dictionary = Checkpoint.capture(session)
		var fallback: Dictionary = session.extraction_quote("dropbag-cash")
		verify(fallback.reason.is_empty(), scene + " has affordable emergency exit")
		var bag_routes: Array = session.service_view("bag").actions.filter(func(action): return action.kind == "route")
		var fallback_rows: Array = bag_routes.filter(func(action): return action.id == "dropbag-cash")
		verify(fallback_rows.size() == 1 and fallback_rows[0].label.contains("费用 %d / 弃现 %d / 弃物 %d / 到账 %d" % [fallback.fee, fallback.lostCash, fallback.lostGoods, fallback.net]) and not bag_routes.any(func(action): return action.id == "service-stairs"), scene + " bag compares only known usable routes")
		world.show_run_panel("extract")
		verify(world.run_confirm.disabled and world.run_body.text.contains("当前路线不可用：随身现金不足以支付费用") and not world.run_body.text.contains("最终到账"), scene + " does not show impossible settlement")
		verify(world.run_body.text.contains("紧急出口 · 丢现金：费用 %d，弃现金 %d，弃贵重物 %d，预计到账 %d" % [fallback.fee, fallback.lostCash, fallback.lostGoods, fallback.net]), scene + " shows exact reachable fallback")
		verify(not world.run_body.text.contains(session.route_name("service-stairs")) and world.forfeit_button.text.contains("主动放弃"), scene + " hides unknown exit and distinguishes abandonment")
		verify(Checkpoint.capture(session) == before, scene + " fallback preview does not change game")
		session.cash = 0
		world.show_run_panel("extract")
		verify(world.run_body.text.contains("当前没有其他已知可用路线") and not world.run_body.text.contains("\n已知可用路线（"), scene + " does not offer an unaffordable route")
		session.cash = 19
		session.inventory.append("ivory-chip")
		var goods: Dictionary = session.extraction_quote("dropbag-valuables")
		world.show_run_panel("extract")
		verify(goods.reason.is_empty() and world.run_body.text.contains("紧急出口 · 丢贵重物：费用 %d，弃现金 %d，弃贵重物 %d，预计到账 %d" % [goods.fee, goods.lostCash, goods.lostGoods, goods.net]), scene + " shows valuable-sacrifice alternative")
		session.cash = 300
		session.heat = 0
		var general: Dictionary = session.extraction_quote("general")
		var general_rows: Array = session.service_view("bag").actions.filter(func(action): return action.kind == "route" and action.id == "general")
		verify(general_rows.size() == 1 and general_rows[0].label.contains("费用 %d / 弃现 %d / 弃物 %d / 到账 %d" % [general.fee, general.lostCash, general.lostGoods, general.net]), scene + " bag shows current general quote")
		world.show_run_panel("extract")
		verify(not world.run_confirm.disabled and world.run_body.text.contains("最终到账") and not world.run_body.text.contains("已知可用路线"), scene + " affordable exit keeps normal settlement")
		session.route_flags = {"service-stairs":true, "river-launch":true}
		session.reservation = session.route_offer().duplicate(true)
		session.reservation.expiresAfterSearch = 1
		session.search_index = 2
		var expired_rows: Array = session.service_view("bag").actions.filter(func(action): return action.kind == "route" and action.id == "fixed")
		verify(expired_rows.size() == 1 and expired_rows[0].label.contains("暂不可用：预约已过期") and expired_rows[0].reason.is_empty(), scene + " bag explains expired route without hiding its preview")
		world.close_run_panel()
		world.open_services()
		await process_frame
		verify(world.services_panel.visible and world.services_panel.rows.get_child_count() > 0, scene + " opens populated bag before width check")
		verify(world.services_panel.rows.get_combined_minimum_size().x <= world.services_panel.size.x - 36, scene + " route comparison fits bag width")
		world.close_services()
		world.show_run_panel("route:fixed")
		await process_frame
		verify(world.run_body.text.contains("预约已过期") and world.run_body.text.contains("紧急出口 · 丢贵重物"), scene + " longest fallback list shows known routes")
		verify(world.run_panel.get_combined_minimum_size().x <= world.run_panel.size.x and world.run_panel.get_combined_minimum_size().y <= world.run_panel.size.y and world.run_body.get_combined_minimum_size().y <= world.run_body.size.y, scene + " longest fallback text fits panel")
		world.close_run_panel()
	world.queue_free()
	print("EXTRACTION_FALLBACK_UI ", JSON.stringify({"checks":checks, "failed":failures.size(), "failures":failures}))
	quit(0 if failures.is_empty() else 1)
