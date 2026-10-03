extends SceneTree
var checks := 0
var failures: Array[String] = []
func verify(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures.append(message)
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world=load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	world.run_game.inventory.append_array(["ruby-cufflink","pearl-necklace","player-notes"])
	var before: Dictionary=world.RunCheckpoint.capture(world.run_game)
	var hud=world.seat_panel
	hud.pregame(world.run_game.cash,world.table_content.tables["mirror-hall"],world.run_game.inventory,world.run_game)
	verify(hud.collateral_choice.item_count==3,"Only two held valuables may be pledged")
	verify(not hud.collateral_preview.visible and hud.collateral_preview.get_child_count()==0,"Default no pledge has no model")
	hud.collateral_choice.select(1)
	hud.collateral_choice.item_selected.emit(1)
	var card=hud.collateral_preview.get_child(0)
	verify(hud.collateral_preview.visible and card.get_meta("collateral_item")=="ruby-cufflink","Chosen cufflink is displayed")
	verify(card.get_child(0).get_child(0) is SubViewport,"Collateral uses actual 3D asset")
	verify(world.RunCheckpoint.capture(world.run_game)==before,"Selection preview does not pledge or mutate saved state")
	hud.collateral_choice.select(2)
	hud.collateral_choice.item_selected.emit(2)
	verify(hud.collateral_preview.get_child_count()==1 and hud.collateral_preview.get_child(0).get_meta("collateral_item")=="pearl-necklace","Changing choice replaces previous item")
	await process_frame
	verify(not is_instance_valid(card),"Old model is freed")
	if DisplayServer.get_name()!="headless":
		hud.show()
		for i in range(8):await RenderingServer.frame_post_draw
		verify(hud.collateral_preview.get_child(0).get_child(0).get_child(0).render_target_update_mode==SubViewport.UPDATE_DISABLED,"Preview stops rendering")
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../output/3d/collateral-preview.png"))
	hud.collateral_choice.select(0)
	hud.collateral_choice.item_selected.emit(0)
	verify(not hud.collateral_preview.visible and hud.collateral_preview.get_child_count()==0,"No pledge clears model immediately")
	hud.pregame(world.run_game.cash,world.table_content.tables["cargo-table"],world.run_game.inventory,world.run_game)
	verify(not hud.collateral_choice.visible and not hud.collateral_preview.visible,"Noncollateral table has no collateral visual")
	verify(world.RunCheckpoint.capture(world.run_game)==before,"All preview transitions preserve complete run checkpoint")
	world.queue_free()
	await process_frame
	print("COLLATERAL_PREVIEW ",JSON.stringify({"checks":checks,"failed":failures.size(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
