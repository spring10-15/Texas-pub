extends SceneTree
var checks := 0
var failures: Array[String] = []
func verify(ok: bool,message: String) -> void:
	checks += 1
	if not ok: failures.append(message);push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	verify(world.run_game.start(world.run_game.revision,"rooftop-club",41),"Start real rooftop run")
	world.travel("tavern")
	var original_stage: int = world.run_game.search_index
	# Temporary stage fixtures only inspect shelf projection; restore before gameplay/save checks.
	for stage in range(1,6):
		world.run_game.search_index = stage
		var before: Dictionary = world.RunCheckpoint.capture(world.run_game)
		world.bar_display.refresh()
		verify(world.RunCheckpoint.capture(world.run_game)==before,"Shelf presentation preserves full Run stage "+str(stage))
		var display = world.get_node("Tavern/ShopObjects")
		var stock: Array = world.run_game.shop_stock()
		verify(display.get_children().filter(func(node):return node is Area3D).size()==stock.size(),"Shelf targets match actual stock")
		for prop in display.get_children():
			if prop is Area3D: continue
			for mesh: MeshInstance3D in prop.find_children("*","MeshInstance3D",true,false):
				var bounds: AABB = mesh.global_transform * mesh.get_aabb()
				verify(abs(bounds.position.y-1.70)<.0001 and bounds.position.x>=12.46-.0001 and bounds.end.x<=12.88+.0001 and bounds.position.z>=-2.55-.0001 and bounds.end.z<=.15+.0001,"Actual stocked model rests on shelf: "+str(prop.name)+" "+str(bounds))
	world.run_game.search_index = original_stage
	world.bar_display.refresh()
	var id: String = world.run_game.shop_stock()[0]
	var target = world.get_node("Tavern/ShopObjects").get_children().filter(func(node):return node is Area3D and str(node.action_id)=="shop:"+id)[0]
	world.player.position=Vector3(11.25,.05,-1.7)
	world.player.camera.look_at(target.global_position)
	for i in range(5): await physics_frame
	verify(world.request_action(target) and world.services_panel.visible,"Shelf opens real product UI through focus ray")
	var cash: int = world.run_game.cash
	var revision: int = world.run_game.revision
	world.service_action("buy",id,revision)
	verify(id in world.run_game.inventory and world.run_game.cash==cash-int(world.table_content.items[id].buy),"Actual purchase awards item and charges once")
	var socket = world.characters.handoff_socket("Tavern")
	verify(socket.get_child_count()==1,"Purchased item attaches to existing bartender handoff socket")
	var after: Dictionary = world.RunCheckpoint.capture(world.run_game)
	world.service_action("buy",id,revision)
	verify(world.RunCheckpoint.capture(world.run_game)==after,"Repeated closed UI submit does not award twice")
	var saved: Dictionary = world.checkpoint_state()
	var fresh = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(fresh);fresh.set_process(false)
	verify(fresh.restore_checkpoint(saved) and id in fresh.run_game.inventory and fresh.get_node("Tavern/RooftopArchitecture/RooftopBar").is_visible_in_tree(),"Fresh save restore retains purchase and new bar")
	fresh.queue_free()
	world.player.camera.current = true
	if DisplayServer.get_name()!="headless":
		for i in range(8): await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../output/3d/rooftop-bar-purchase.png"))
	var sale: int = world.run_game.sale_value(id)
	world.open_services("bar")
	world.service_action("sell",id,world.run_game.revision)
	verify(not id in world.run_game.inventory and world.run_game.cash==cash-int(world.table_content.items[id].buy)+sale,"Actual sale removes item and credits published price")
	print("ROOFTOP_BAR ",JSON.stringify({"checks":checks,"failed":failures.size(),"failures":failures}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
