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
	world.open_services()
	verify(world.services_panel.rows.find_children("*","VBoxContainer",true,false).filter(func(node): return node.has_meta("owned_item")).is_empty(), "Empty bag has no item previews")
	world.close_services()
	world.run_game.inventory.append_array(["signal-lighter","ruby-cufflink"])
	var before: Dictionary = world.checkpoint_state()
	world.open_services()
	var cards: Array = world.services_panel.rows.find_children("*","VBoxContainer",true,false).filter(func(node): return node.has_meta("owned_item"))
	verify(cards.size()==2 and cards.map(func(node): return node.get_meta("owned_item"))==world.run_game.inventory, "Only owned item IDs appear, including valuables")
	var previews: Array = cards.map(func(node): return node.get_child(0))
	verify(previews.size()==2, "Each held item has a presentation card")
	var viewport: SubViewport = previews[0].get_child(0)
	verify(viewport.own_world_3d and viewport.get_children()[0].get_child_count()==1, "Existing lighter uses isolated 3D model")
	verify(previews[1].get_child(0) is Label, "Unmodeled valuable uses a symbol without a fake model")
	verify(world.checkpoint_state()==before, "Opening visual inventory does not alter saved game state")
	world.close_services()
	world.open_services()
	verify(world.services_panel.rows.find_children("*","VBoxContainer",true,false).filter(func(node): return node.has_meta("owned_item")).size()==2, "Reopening replaces previews without duplication")
	if DisplayServer.get_name() != "headless":
		for i in range(8): await RenderingServer.frame_post_draw
		verify(not is_instance_valid(viewport), "Old preview is detached after refresh")
		var active: SubViewport = world.services_panel.rows.find_children("*","VBoxContainer",true,false).filter(func(node): return node.has_meta("owned_item"))[0].get_child(0).get_child(0)
		verify(active.render_target_update_mode==SubViewport.UPDATE_DISABLED, "Preview renders once and stops ongoing 3D work")
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../output/3d/inventory-preview.png"))
	print("INVENTORY_PREVIEW ",JSON.stringify({"checks":checks,"failed":failures.size(),"failures":failures}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
