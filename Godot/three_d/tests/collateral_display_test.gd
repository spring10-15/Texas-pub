extends SceneTree
var failures: Array[String] = []
var checks := 0
var venue_id := "smoky-den"
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
	verify(world.run_game.start(world.run_game.revision,venue_id,41),"Start isolated run")
	# Prior room completion is a fixture; this probe tests visual projection, not unlock balance.
	world.run_game.completed.append_array(["cargo-table","ledger-cellar"])
	world.run_game.inventory.append("ruby-cufflink")
	world.travel("mirror")
	world.player.position=Vector3(29.55,0.05,1.15)
	world.player.camera.look_at(world.table_target.global_position)
	for i in range(5):await physics_frame
	verify(world.request_action(world.table_target),"Seat through actual focus ray")
	world.seat_panel.collateral_choice.select(1)
	world.start_table(301)
	verify(world.table_game!=null and world.run_game.collateral=="ruby-cufflink" and not "ruby-cufflink" in world.run_game.inventory,"Authoritative pledge removes held item once")
	if world.table_game==null:
		world.queue_free()
		quit(1)
		return
	if venue_id == "rooftop-club":
		verify(world.get_node("MirrorHall/RooftopArchitecture/RooftopTable").is_visible_in_tree(),"Independent terrace table remains visible while seated")
		verify(not world.get_node("MirrorHall/BlenderDetail").find_child("TavernTable",true,false).visible,"Legacy table remains hidden while seated")
		verify(world.cards_root.get_child_count() > 0,"Live cards rendered on terrace table")
		var felt: MeshInstance3D = world.get_node("MirrorHall/RooftopArchitecture/RooftopTable").find_child("TerraceTable_fabric",true,false)
		var surface: AABB = felt.global_transform * felt.get_aabb()
		for card in world.cards_root.get_children():
			if card.get_meta("visual_role", "") != "Card": continue
			var mesh: MeshInstance3D = card.get_child(0)
			var bounds: AABB = mesh.global_transform * mesh.get_aabb()
			verify(bounds.position.x > surface.position.x and bounds.end.x < surface.end.x and bounds.position.z > surface.position.z and bounds.end.z < surface.end.z and bounds.position.y > surface.end.y, "Live card footprint rests entirely above felt")
	var prop: Node3D=world.collateral_display.prop
	verify(is_instance_valid(prop) and prop.get_parent()==world.get_node("MirrorHall") and prop.scale==Vector3.ONE,"Physical-scale model belongs to active room")
	var bottom := INF
	for mesh: MeshInstance3D in prop.find_children("*","MeshInstance3D",true,false): bottom = minf(bottom,(mesh.global_transform * mesh.get_aabb()).position.y)
	verify(abs(bottom - .857) < .00001,"Pledged model bottom rests on visible felt surface")
	verify(prop.get_meta("pledged_item")=="ruby-cufflink" and prop.position.y>0.85,"Cufflink bottom rests on felt")
	var before: Dictionary=world.RunCheckpoint.capture(world.run_game)
	world.refresh_economy()
	world.refresh_table()
	verify(world.collateral_display.prop==prop and world.RunCheckpoint.capture(world.run_game)==before,"Refresh preserves model identity and full rule state")
	var saved: Dictionary=world.checkpoint_state()
	verify(world.restore_checkpoint(saved) and world.collateral_display.prop.get_meta("pledged_item")=="ruby-cufflink","Loaded active pledge is visible")
	var fresh=load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(fresh)
	fresh.set_process(false)
	verify(fresh.restore_checkpoint(saved) and is_instance_valid(fresh.collateral_display.prop) and fresh.collateral_display.prop.get_parent()==fresh.get_node("MirrorHall"),"Fresh world rebuilds pledged mesh from save")
	fresh.queue_free()
	await process_frame
	world.seat_camera.current=true
	if DisplayServer.get_name()!="headless":
		for i in range(8):await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../output/3d/collateral-tabletop.png"))
	var table: RefCounted=world.table_game
	var steps := 0
	while table.state.status!="finished" and steps<500:
		steps+=1
		if table.state.status=="hand_over":table.next_hand(table.revision)
		elif str(table.state.currentActorId).is_empty():table.advance(table.revision)
		else:
			var actor: String=table.state.currentActorId
			var legal: Dictionary=table.legal_actions(actor)
			table.act(actor,"check" if legal.check else ("call" if legal.call else "fold"),table.revision)
	verify(table.state.status=="finished","Natural legal actions finish fixture table")
	var expected=world.RunCheckpoint.restore(world.RunCheckpoint.capture(world.run_game),world.table_content)
	verify(expected!=null and expected.settle_table(expected.revision),"Control run settles without visuals")
	world.leave_seat()
	verify(world.RunCheckpoint.capture(world.run_game)==world.RunCheckpoint.capture(expected),"Visual cleanup preserves exact settlement state")
	var settled=load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(settled)
	settled.set_process(false)
	verify(settled.restore_checkpoint(world.checkpoint_state()) and settled.settlement_receipt.visible and settled.RunCheckpoint.capture(settled.run_game)==world.RunCheckpoint.capture(world.run_game),"Real settlement save rebuilds receipt without changing state")
	settled.queue_free()
	verify(world.table_game==null and world.run_game.collateral.is_empty() and not is_instance_valid(world.collateral_display.prop),"Settlement clears derived tabletop mesh")
	world.queue_free()
	await process_frame
	print("COLLATERAL_DISPLAY ",JSON.stringify({"checks":checks,"failed":failures.size(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
