extends SceneTree
## Render-only timing of five existing venue views; never a target-hardware gate.
var output := ""
func _initialize() -> void: call_deferred("run")
func stats(values: Array) -> Dictionary:
	if values.is_empty(): return {"samples":0,"available":false}
	var sorted := values.duplicate()
	sorted.sort()
	return {"samples":sorted.size(),"available":true,"median_ms":sorted[sorted.size()/2],"p95_ms":sorted[int(ceil(sorted.size()*0.95))-1],"max_ms":sorted[-1],"over_16_67_ms":sorted.filter(func(v):return v>16.67).size()}
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile-output="): output=arg.trim_prefix("--profile-output=")
	if DisplayServer.get_name()=="headless" or not OS.get_cmdline_user_args().has("--test") or not output.is_absolute_path():
		push_error("Windowed --test and absolute --profile-output required")
		quit(1)
		return
	var world=load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	var viewport := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport,true)
	var results := []
	for venue in ["stash","smoky-den","high-rise-suite","rooftop-club","neon-poker-club"]:
		if venue!="stash":
			world.run_game=world.RunRules.new(world.table_content)
			world.run_game.start(world.run_game.revision,venue,41)
		world.travel("stash" if venue=="stash" else "tavern")
		for i in range(120): await RenderingServer.frame_post_draw
		var cpu := []
		var gpu := []
		var intervals := []
		var zero_gpu := 0
		var last := Time.get_ticks_usec()
		var started := last
		var first_frame := Engine.get_frames_drawn()
		while Time.get_ticks_usec()-started<6000000:
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			intervals.append(float(now-last)/1000.0)
			last=now
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
			var measured := RenderingServer.viewport_get_measured_render_time_gpu(viewport)
			if measured>0: gpu.append(measured)
			else: zero_gpu+=1
		results.append({"venue":venue,"warmup_render_callbacks":120,"seconds":float(last-started)/1000000.0,"drawn_frame_delta":Engine.get_frames_drawn()-first_frame,"render_cpu":stats(cpu),"render_gpu":stats(gpu),"gpu_unavailable_samples":zero_gpu,"render_callback_interval":stats(intervals)})
	RenderingServer.viewport_set_measure_render_time(viewport,false)
	var report := {"scope":"Five stationary entry-camera fixtures, six seconds each after 120 warmup render callbacks. Root viewport only; no inventory subviewport, AI table or full-game path. CPU render excludes scripts/physics; GPU results may be delayed or repeated. Callback intervals are not display-present FPS. No target-device or 30-minute certification.","engine":Engine.get_version_info().string,"processor":OS.get_processor_name(),"renderer":str(ProjectSettings.get_setting("rendering/renderer/rendering_method")),"adapter":RenderingServer.get_video_adapter_name(),"window_pixels":[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y],"viewport_pixels":[root.size.x,root.size.y],"vsync_mode":DisplayServer.window_get_vsync_mode(),"results":results}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"	")+"\n")
	world.queue_free()
	await process_frame
	print("VIEWPORT_PROFILE ",output)
	quit(0)
