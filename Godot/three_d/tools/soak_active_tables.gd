extends SceneTree
## Sustained windowed production AI and owned-inventory renders from a resource pack.
var failures: Array[String] = []
var output := ""
var duration := 1800
var cycles := 0
var world
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--soak-output="): output = arg.trim_prefix("--soak-output=")
		if arg.begins_with("--soak-seconds="): duration = arg.trim_prefix("--soak-seconds=").to_int()
	if DisplayServer.get_name()=="headless" or not OS.get_cmdline_user_args().has("--test") or not output.is_absolute_path() or duration<30:
		push_error("Windowed --test, absolute --soak-output and duration >=30 required")
		quit(1)
		return
	world = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	var started := Time.get_ticks_usec()
	var sampled := started
	var previous := started
	var frames: Array = []
	var samples: Array = []
	var ai_transitions := 0
	var completed_venues: Array = []
	var engine_args := OS.get_cmdline_args()
	var pack_index := engine_args.find("--main-pack")
	var pack_path := engine_args[pack_index+1] if pack_index>=0 else ""
	var venues: Array = world.RunRules.SCENE_NAMES.keys()
	var phase := "start"
	var phase_started := started
	var report := {"status":"running","duration_target_seconds":duration,"process_id":OS.get_process_id(),"executable_path":OS.get_executable_path(),"engine":Engine.get_version_info().string,"processor":OS.get_processor_name(),"scope":"Packed resources, real World._process production AI and UI. Repeated cargo tables across four venues with legal automatic check/call/fold; each cycle resets the financial fixture. Position/ray fixtures, not physical walking, human 20-30-minute balance, four-table unlock chains, target hardware certification or independent GPU timing.","samples":samples,"pack_path":pack_path,"pack_sha256":FileAccess.get_sha256(pack_path) if not pack_path.is_empty() else null,"completed_venues":completed_venues}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	while Time.get_ticks_usec()-started<duration*1000000:
		var actor := ""
		var revision := -1
		if phase=="start":
			world.run_game = world.RunRules.new(world.table_content)
			if not world.run_game.start(world.run_game.revision,venues[cycles%venues.size()],41+cycles):
				failures.append("Cannot start fixture run")
				break
			world.travel("tavern")
			for id in world.run_game.shop_stock():
				if world.run_game.service_reason("buy",id).is_empty():
					world.run_game.service_action("buy",id,world.run_game.revision)
					break
			world.open_services()
			phase="bag"
			phase_started=Time.get_ticks_usec()
		elif phase=="bag" and Time.get_ticks_usec()-phase_started>1000000:
			world.close_services()
			world.player.position=Vector3(9.55,0.05,1.15)
			world.player.camera.look_at(world.table_target.global_position)
			phase="seat"
			phase_started=Time.get_ticks_usec()
		elif phase=="seat" and Time.get_ticks_usec()-phase_started>200000:
			if not world.request_action(world.table_target):
				failures.append("Actual table focus ray refused")
				break
			world.start_table(301+cycles)
			if world.table_game==null:
				failures.append("Cannot start cargo table")
				break
			phase="table"
			phase_started=Time.get_ticks_usec()
		elif phase=="table":
			var game = world.table_game
			actor=game.state.currentActorId
			revision=game.revision
			if game.state.status=="finished":
				world.leave_seat()
				world.run_game.discover_exit()
				if not world.run_game.extract(world.run_game.revision):
					failures.append("Legal banking refused")
					break
				if world.run_game.scene_id not in completed_venues: completed_venues.append(world.run_game.scene_id)
				world.travel("stash")
				cycles+=1
				phase="start"
			elif Time.get_ticks_usec()-phase_started>90000000:
				failures.append("Table exceeded 90 seconds")
				break
			elif world.table_delay<=0:
				if game.state.status=="hand_over": world.continue_hand(game.revision)
				elif actor=="player":
					var legal: Dictionary = game.legal_actions(actor)
					world.play_action("check" if legal.check else ("call" if legal.call else "fold"),game.revision)
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		frames.append(float(now-previous)/1000.0)
		previous=now
		if world.table_game!=null and revision>=0 and world.table_game.revision!=revision and actor!="player" and not actor.is_empty(): ai_transitions+=1
		if now-sampled>=10000000:
			frames.sort()
			samples.append({"elapsed_seconds":float(now-started)/1000000.0,"phase":phase,"cycles":cycles,"ai_transitions":ai_transitions,"frames":frames.size(),"p95_callback_ms":frames[int(ceil(frames.size()*0.95))-1],"max_callback_ms":frames[-1],"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)})
			frames.clear()
			sampled=now
			report.merge({"elapsed_seconds":float(now-started)/1000000.0,"cycles":cycles,"ai_transitions":ai_transitions},true)
			FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
			print("ACTIVE_SOAK cycles=",cycles," AI=",ai_transitions)
	if cycles==0 or ai_transitions==0: failures.append("No completed production-AI cycle")
	report.merge({"status":"completed" if failures.is_empty() else "failed","elapsed_seconds":float(Time.get_ticks_usec()-started)/1000000.0,"cycles":cycles,"ai_transitions":ai_transitions,"failures":failures},true)
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
