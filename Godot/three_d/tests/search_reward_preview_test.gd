extends SceneTree
var failures: Array[String] = []
var checks := 0
func verify(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures.append(message)
		push_error(message)
func _initialize() -> void: call_deferred("run")
func cards(world) -> Array:
	return world.services_panel.rows.get_children().filter(func(node):return node.has_meta("search_reward"))
func run() -> void:
	var world=load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	var seed := 0
	for candidate in range(1,65):
		world.run_game=world.RunRules.new(world.table_content)
		world.run_game.start(world.run_game.revision,"smoky-den",candidate)
		if world.RunRules.SearchEvents.event_id(world.run_game,"cargo-table")=="cargo-table":
			seed=candidate
			break
	verify(seed>0,"Find authored item event through actual seed pool")
	world.travel("tavern")
	var before: Dictionary=world.RunCheckpoint.capture(world.run_game)
	world.open_services("search","cargo-table")
	verify(cards(world).is_empty(),"No obtained model before choosing reward")
	verify(world.RunCheckpoint.capture(world.run_game)==before,"Opening reward display does not alter run")
	world.service_action("search","cargo-table",world.run_game.revision,"goods")
	verify(world.run_game.inventory.count("old-silver-lighter")==1 and world.run_game.search_results.has("cargo-table"),"Real successful search awards exactly once")
	verify(cards(world).size()==1 and cards(world)[0].get_meta("search_reward")=="old-silver-lighter","Obtained item is shown from authoritative record")
	verify(cards(world)[0].get_child(1).get_child(0) is SubViewport,"Reward uses actual 3D asset")
	before=world.RunCheckpoint.capture(world.run_game)
	world.service_action("search","cargo-table",world.run_game.revision,"goods")
	verify(world.RunCheckpoint.capture(world.run_game)==before and cards(world).size()==1,"Repeat attempt neither awards nor duplicates visual")
	world.close_services()
	world.open_services("search","cargo-table")
	verify(cards(world).size()==1 and world.RunCheckpoint.capture(world.run_game)==before,"Reopening completed search preserves rule state")
	var saved: Dictionary=world.checkpoint_state()
	var fresh=load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(fresh)
	fresh.set_process(false)
	verify(fresh.restore_checkpoint(saved),"Fresh world restores completed search")
	fresh.open_services("search","cargo-table")
	verify(cards(fresh).size()==1 and cards(fresh)[0].get_meta("search_reward")=="old-silver-lighter" and fresh.RunCheckpoint.capture(fresh.run_game)==saved.run,"Loaded reward display preserves saved rule state")
	fresh.queue_free()
	await process_frame
	world.player.camera.current=true
	if DisplayServer.get_name()!="headless":
		for i in range(8):await RenderingServer.frame_post_draw
		verify(cards(world)[0].get_child(1).get_child(0).render_target_update_mode==SubViewport.UPDATE_DISABLED,"Reward render stops after initial frame")
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../output/3d/search-reward-preview.png"))
	world.run_game.variant_plan.events["cargo-table"]="embers-table"
	verify(world.received_search_item().get("id")=="old-silver-lighter","Historical result uses recorded event, not changed current pool")
	world.close_services()
	world.open_services("bar")
	world.service_action("sell","old-silver-lighter",world.run_game.revision)
	verify(not "old-silver-lighter" in world.run_game.inventory,"Real sale removes reward")
	world.close_services()
	world.open_services("search","cargo-table")
	verify(cards(world).is_empty(),"Sold reward is not displayed as still held")
	world.close_services()
	world.run_game=world.RunRules.new(world.table_content)
	world.run_game.start(world.run_game.revision,"smoky-den",seed)
	for i in range(6):world.run_game.inventory.append("ivory-chip")
	world.open_services("search","cargo-table")
	before=world.RunCheckpoint.capture(world.run_game)
	world.service_action("search","cargo-table",world.run_game.revision,"goods")
	verify(cards(world).is_empty() and world.RunCheckpoint.capture(world.run_game)==before,"Full bag rejects award without reward visual")
	world.close_services()
	world.run_game=world.RunRules.new(world.table_content)
	world.run_game.start(world.run_game.revision,"smoky-den",seed)
	world.open_services("search","cargo-table")
	world.service_action("search","cargo-table",world.run_game.revision,"lead")
	verify(world.run_game.search_results.has("cargo-table") and cards(world).is_empty(),"Choosing route lead creates no item reward visual")
	world.queue_free()
	await process_frame
	print("SEARCH_REWARD_PREVIEW ",JSON.stringify({"checks":checks,"failed":failures.size(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
