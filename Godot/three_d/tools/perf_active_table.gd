extends SceneTree
## Windowed production AI, UI and animation timing in one naturally completed table.
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func stats(values: Array) -> Dictionary:
	if values.is_empty(): return {"samples":0}
	var ordered := values.duplicate()
	ordered.sort()
	return {"samples":ordered.size(),"median_ms":ordered[ordered.size()/2],"p95_ms":ordered[int(ceil(ordered.size()*0.95))-1],"max_ms":ordered[-1],"over_16_67_ms":ordered.filter(func(value): return value>16.67).size()}
func asset_hash(path: String) -> Variant:
	if not FileAccess.file_exists(path): return null
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(FileAccess.get_file_as_bytes(path))
	return context.finish().hex_encode()
func run() -> void:
	if DisplayServer.get_name() == "headless" or not OS.get_cmdline_user_args().has("--test"):
		push_error("Windowed --test required; no formal player save access")
		quit(1)
		return
	var world = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	world.show_run_panel("enter")
	world.confirm_run_action()
	world.player.position = Vector3(9.55,0.05,1.15)
	world.player.camera.look_at(world.table_target.global_position)
	for i in range(5): await physics_frame
	if not world.request_action(world.table_target):
		push_error("Cannot enter table with actual focus ray")
		quit(1)
		return
	for i in range(120): await RenderingServer.frame_post_draw
	world.start_table(301)
	if world.table_game == null:
		push_error("Cannot start table")
		quit(1)
		return
	var frames: Array = []
	var ai_frames: Array = []
	var transitions: Array = []
	var last := Time.get_ticks_usec()
	var started := last
	while world.table_game.state.status != "finished" and Time.get_ticks_usec()-started < 90000000:
		var game: RefCounted = world.table_game
		var actor: String = game.state.currentActorId
		var revision: int = game.revision
		var hand: int = game.state.handNumber
		var street: String = game.state.street
		if world.table_delay <= 0:
			if game.state.status == "hand_over":
				world.continue_hand(game.revision)
			elif actor == "player":
				var legal: Dictionary = game.legal_actions(actor)
				world.play_action("check" if legal.check else ("call" if legal.call else "fold"),game.revision)
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		var interval := float(now-last)/1000.0
		last = now
		frames.append(interval)
		if game.revision != revision:
			transitions.append({"actor_before":actor,"hand_before":hand,"street_before":street,"interval_ms":interval,"revision_after":game.revision})
			if actor != "player" and not actor.is_empty(): ai_frames.append(interval)
	if world.table_game.state.status != "finished": failures.append("Table did not finish within 90 seconds")
	if ai_frames.is_empty(): failures.append("No actual production AI transition sampled")
	var report := {"scope":"One cargo-table seed 301 on this host; normal World._process runs production AI and UI/animation. Automated check/call player, ray-focused seat position fixture. Render callback intervals include display pacing/scheduling, not independent GPU timing, human input, full-game or target-device certification.","engine":Engine.get_version_info().string,"processor":OS.get_processor_name(),"renderer":str(ProjectSettings.get_setting("rendering/renderer/rendering_method")),"window_pixels":[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y],"vsync_mode":DisplayServer.window_get_vsync_mode(),"seconds":float(last-started)/1000000.0,"seed":301,"all_frames":stats(frames),"ai_transition_frames":stats(ai_frames),"transitions":transitions,"terminal_status":world.table_game.state.status,"failed":failures.size(),"failures":failures,"source_sha256":{}}
	for path in ["rules/poker.gd","rules/opponent.gd","rules/content.json","scripts/world.gd","scripts/characters.gd","scripts/table_hud.gd"]:
		report.source_sha256[path] = FileAccess.get_file_as_string("res://three_d/"+path).sha256_text()
	report["run_seed"] = world.playtest_seed
	report["scene_id"] = world.run_game.scene_id
	report["opponent_ids"] = world.table_game.state.players.filter(func(player): return player.id != "player").map(func(player): return player.id)
	report["asset_sha256"] = {}
	for path in ["stash.glb","stash-room-detail.glb","tavern-detail.glb","tavern-routes.glb","interactive-props.glb"]:
		report.asset_sha256[path] = asset_hash("res://three_d/assets/"+path)
	for id in world.table_game.state.players.map(func(player): return player.id) + ["bartender"]:
		if id == "player": continue
		var path: String = "characters/" + id + ".glb"
		report.asset_sha256[path] = asset_hash("res://three_d/assets/"+path)
	var output := "res://../output/3d/perf-active-table.json"
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	world.queue_free()
	await process_frame
	print("PERF_ACTIVE_TABLE frames=",frames.size()," ai_frames=",ai_frames.size()," failed=",failures.size()," report=",output)
	quit(0 if failures.is_empty() else 1)
