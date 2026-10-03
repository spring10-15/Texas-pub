extends SceneTree
var failures: Array[String] = []
var checks := 0
func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	var game: RefCounted = world.run_game
	verify(game.start(game.revision,"smoky-den",41), "Start isolated run")
	# Explicit terminal-record fixtures cover all presentation branches, not award rules.
	for returned in [true,false]:
		for awarded in [true,false]:
			game.last_table_result = {"table":"cargo-table","net":25,"collateral":"ruby-cufflink","returned":returned,"reward":"ivory-chip","reward_added":awarded}
			var before: Dictionary = world.RunCheckpoint.capture(game)
			world.refresh_economy()
			var cards: Array = world.settlement_receipt.rows.get_child(1).get_children()
			verify(cards.size()==2 and cards[0].get_meta("settlement_status")==("奖励已入包" if awarded else "背包已满 · 未获得") and cards[1].get_meta("settlement_status")==("抵押物已归还" if returned else "抵押物已失去"), "Correct reward/pledge statuses")
			world.refresh_economy()
			verify(world.settlement_receipt.rows.get_child(1).get_child(0)==cards[0] and world.RunCheckpoint.capture(game)==before, "Refresh reuses model and never changes authoritative state")
	var fresh = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(fresh)
	fresh.set_process(false)
	fresh.settlement_receipt.sync(game)
	verify(fresh.settlement_receipt.visible and fresh.settlement_receipt.rows.get_child(1).get_child_count()==2, "Fresh UI rebuilds historical receipt")
	fresh.queue_free()
	verify(game.enter_table(301,game.revision)!=null,"Start next table")
	world.refresh_economy()
	verify(not world.settlement_receipt.visible,"Active table hides previous result")
	print("SETTLEMENT_RECEIPT ",JSON.stringify({"checks":checks,"failed":failures.size(),"failures":failures}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
