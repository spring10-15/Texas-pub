extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Checkpoint = preload("res://three_d/rules/run_checkpoint.gd")
var checks := 0
var failures: Array[String] = []
func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var seeds := {}
	for seed_value in range(1,101):
		var plan := Run.Variants.generate(content,"smoky-den",seed_value)
		seeds[plan.room_layout] = seed_value
	verify(seeds.size()==2,"Two room graphs generated")
	for scene in Run.SCENE_NAMES:
		for layout in seeds:
			# Read the committed graph rather than assume venue draws match.
			var r := Run.new(content)
			r.start(r.revision,scene,seed_for(content,scene,layout))
			var actual: String = r.variant_plan.room_layout
			verify(not r.room_blocked_reason("mirror-hall").is_empty(),"Mirror locked before cargo")
			r.completed.append("cargo-table")
			verify(r.room_blocked_reason("ledger-cellar").is_empty(),"Ledger opens after cargo")
			verify(r.room_blocked_reason("mirror-hall").is_empty()==(actual=="fork"),"Mirror entry follows graph")
			verify((r.service_reason("search","mirror-hall",Run.SearchEvents.event_for(r,"mirror-hall").choices[0].id)!="该房间尚未解锁")==(actual=="fork"),"Search cannot bypass graph lock")
			r.completed.append("mirror-hall")
			verify(r.room_blocked_reason("embers-table").is_empty()==(actual=="linear"),"Fork final room requires both middle tables")
			var loaded: RefCounted = Checkpoint.restore(Checkpoint.capture(r),content)
			verify(loaded != null and loaded.room_requirements("embers-table")==r.room_requirements("embers-table"),"Room requirements survive save")
	for scene in Run.SCENE_NAMES:
		for layout in seeds:
			var paths := [["cargo-table","ledger-cellar","mirror-hall","embers-table"]]
			if layout == "fork": paths.append(["cargo-table","mirror-hall","ledger-cellar","embers-table"])
			for path in paths:
				var r := Run.new(content)
				r.start(r.revision,scene,seed_for(content,scene,layout))
				verify(r.variant_plan.room_layout==layout,"Fixture uses intended room graph")
				for site in path:
					if r.heat > 0: verify(r.service_action("cool","",r.revision),"Manage heat before next room")
					var before: int = r.cash
					var table: RefCounted = r.enter_table(101,r.revision,site)
					verify(table != null,"Path can enter "+site)
					if table == null: continue
					verify(r.cash==before-int(table.state.tableDef.buyIn),"Exact buy-in debit")
					finish(table)
					var stack: int = table.state.players[0].stack
					var remaining: int = r.cash
					verify(r.settle_table(r.revision) and r.cash==remaining+stack,"Exact stack return")
					verify(not r.enforce_pressure(),"Planned cooling avoids forced settlement")
					var copy: RefCounted = Checkpoint.restore(Checkpoint.capture(r),content)
					verify(copy != null and copy.completed==r.completed,"Either visit order restores")
				r.discover_exit()
				var quote: Dictionary = r.extraction_quote()
				var vault: int = r.vault
				verify(quote.reason.is_empty() and r.extract(r.revision) and r.vault==vault+quote.net,"Complete path extracts exact quoted amount")
	var finished_intel := Run.new(content)
	finished_intel.start(finished_intel.revision)
	finished_intel.completed.assign(["cargo-table","mirror-hall"])
	var before_intel := Checkpoint.capture(finished_intel)
	verify(not finished_intel.service_action("search","ledger-cellar",finished_intel.revision,"intel") and Checkpoint.capture(finished_intel)==before_intel,"Completed table intelligence cannot charge resources")
	var world: Node = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	var r := Run.new(content)
	r.start(r.revision,"smoky-den",seeds.fork)
	world.run_game = r
	world.travel("tavern")
	var passage: Node3D = world.get_node("Tavern/MirrorPassage")
	var door: Area3D = passage.get_children().filter(func(n): return n is Area3D)[0]
	verify(passage.visible and door.collision_layer==2,"Fork adds physical mirror passage")
	await aim(world,door)
	verify(not world.request_action(door) and world.current_room=="tavern","Real door rejects locked early entry")
	r.completed.append("cargo-table")
	world.refresh_route_labels()
	verify(door.title.contains("120") and door.get_node("RoomSign").text.contains("开放"),"Door shows price and unlocked status")
	await aim(world,door)
	if OS.get_cmdline_user_args().has("--capture"):
		for i in range(12): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../output/3d/room-fork.png"))
	verify(world.request_action(door) and world.current_room=="mirror","Player can choose mirror before ledger through real door")
	var saved: Dictionary = world.checkpoint_state()
	verify(world.restore_checkpoint(saved) and world.current_room=="mirror","Early mirror position restores in fork")
	var invalid: Dictionary = saved.duplicate(true)
	invalid.run.completed.clear()
	verify(not world.restore_checkpoint(invalid),"Restore cannot teleport to locked room")
	world.run_game.completed.append("mirror-hall")
	world.travel("mirror")
	var final_door: Area3D = world.get_node("MirrorHall").get_children().filter(func(n): return n is Area3D and str(n.action_id)=="room:embers")[0]
	await aim(world,final_door)
	verify(not world.request_action(final_door),"Actual final door still requires ledger")
	world.run_game.completed.append("ledger-cellar")
	await aim(world,final_door)
	verify(world.request_action(final_door) and world.current_room=="embers","Final door opens after both middle rooms")
	world.run_game.variant_plan.room_layout = "linear"
	world.travel("tavern")
	verify(not passage.visible and door.collision_layer==0,"Linear layout closes extra physical passage")
	verify(world.get_node("LedgerCellar").get_children().any(func(n): return n is Area3D and str(n.action_id)=="room:mirror"),"Linear layout restores ledger-to-mirror link")
	var old := Checkpoint.capture(world.run_game)
	old.variant_plan.version = 3
	old.variant_plan.erase("room_layout")
	var legacy: RefCounted = Checkpoint.restore(old,content)
	verify(legacy != null and legacy.room_requirements("mirror-hall")==["ledger-cellar"],"Version 3 keeps linear rooms")
	var bad := Checkpoint.capture(world.run_game)
	bad.variant_plan.room_layout = "unknown"
	verify(Checkpoint.restore(bad,content)==null,"Unknown room graph rejected")
	world.queue_free()
	print("ROOM_POOL checks=",checks," failed=",failures.size()," failures=",failures)
	quit(0 if failures.is_empty() else 1)
func aim(world: Node, door: Area3D) -> void:
	world.player.position = door.global_position + Vector3(-1.0,-1.08,0)
	world.player.camera.look_at(door.global_position)
	for i in range(5): await physics_frame

func finish(table: RefCounted) -> void:
	var steps := 0
	while table.state.status != "finished" and steps < 200:
		steps += 1
		if table.state.status == "hand_over": table.next_hand(table.revision)
		elif table.state.currentActorId.is_empty(): table.advance(table.revision)
		else:
			var id: String = table.state.currentActorId
			var legal: Dictionary = table.legal_actions(id)
			verify(table.act(id,"fold" if id!="player" else ("check" if legal.check else "call"),table.revision),"Legal scripted progression")
	verify(table.state.status=="finished","Table finishes within bound")

func seed_for(content: Dictionary, scene: String, layout: String) -> int:
	for value in range(1,101):
		if Run.Variants.generate(content,scene,value).room_layout==layout: return value
	push_error("Missing room graph for venue")
	return 0
