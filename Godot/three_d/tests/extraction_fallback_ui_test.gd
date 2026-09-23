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
		world.show_run_panel("extract")
		verify(not world.run_confirm.disabled and world.run_body.text.contains("最终到账") and not world.run_body.text.contains("已知可用路线"), scene + " affordable exit keeps normal settlement")
		world.close_run_panel()
	world.queue_free()
	print("EXTRACTION_FALLBACK_UI ", JSON.stringify({"checks":checks, "failed":failures.size(), "failures":failures}))
	quit(0 if failures.is_empty() else 1)
