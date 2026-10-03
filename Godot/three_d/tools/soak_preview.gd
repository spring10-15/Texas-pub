extends SceneTree
var world
var output := ""
var duration := 1800
var checks := 0
var failures := 0

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.has("--test") or DisplayServer.get_name() == "headless":
		push_error("Soak requires a real window and --test")
		quit(1)
		return
	for arg in args:
		if arg.begins_with("--soak-output="): output = arg.trim_prefix("--soak-output=")
		if arg.begins_with("--soak-seconds="): duration = arg.trim_prefix("--soak-seconds=").to_int()
	if not output.is_absolute_path() or duration < 30:
		push_error("Use an absolute output path and duration >= 30 seconds")
		quit(1)
		return
	world = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var started := Time.get_ticks_msec()
	var last_frame := Time.get_ticks_usec()
	var sampled_at := started
	var intervals: Array[float] = []
	var samples := []
	var segment := maxf(3.0, minf(30.0, float(duration) / 8.0))
	var last_step := -1
	var report := {"status":"running", "duration_target_seconds":duration, "process_id":OS.get_process_id(),
		"engine":Engine.get_version_info().string, "cpu":OS.get_processor_name(),
		"gpu":RenderingServer.get_video_adapter_name(), "window_pixels":DisplayServer.window_get_size(),
		"executable_path":OS.get_executable_path(), "template_runtime":OS.has_feature("template"),
		"scope":"Windowed packed resources on this Mac; scripted legal tables and camera tours, not physical walking or target-machine certification. Executable path and template feature identify the runtime."}
	while Time.get_ticks_msec() - started < duration * 1000:
		var elapsed := float(Time.get_ticks_msec() - started) / 1000.0
		var step := int(elapsed / segment)
		if step != last_step:
			advance(step)
			last_step = step
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		intervals.append(float(now - last_frame) / 1000.0)
		last_frame = now
		if Time.get_ticks_msec() - sampled_at >= 10000:
			intervals.sort()
			samples.append({"elapsed_seconds":elapsed, "tour_step":step, "frames":intervals.size(),
				"median_callback_ms":intervals[intervals.size()/2],
				"p95_callback_ms":intervals[int(intervals.size()*0.95)],
				"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),
				"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
				"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)})
			intervals.clear()
			sampled_at = Time.get_ticks_msec()
			report.merge({"elapsed_seconds":elapsed,"checks":checks,"failures":failures,"samples":samples}, true)
			write_report(report)
			print("SOAK elapsed=", int(elapsed), " step=", step, " failures=", failures)
		if failures > 0: break
	report.merge({"status":"completed" if failures == 0 else "failed",
		"elapsed_seconds":float(Time.get_ticks_msec()-started)/1000.0,
		"checks":checks,"failures":failures,"samples":samples}, true)
	write_report(report)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)

func write_report(report: Dictionary) -> void:
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		verify(false, "Cannot write soak report")
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()

func advance(step: int) -> void:
	var phase := step % 8
	if phase == 0:
		world.run_game = world.RunRules.new(world.table_content)
		var venues: Array = world.RunRules.SCENE_NAMES.keys()
		verify(world.run_game.start(world.run_game.revision, venues[(step/8)%venues.size()], 41), "Start soak venue")
		world.travel("tavern")
	elif phase in [1, 2, 3, 4]:
		finish_table(["cargo-table", "ledger-cellar", "mirror-hall", "embers-table"][phase-1])
		world.travel(["ledger", "mirror", "embers", "tavern"][phase-1])
	if phase == 4: world.player.position = Vector3(10, 0.02, -11)
	if phase == 5: world.player.position = Vector3(7.25, 1.22, -12.1)
	if phase == 6: world.player.position = Vector3(12.75, -1.18, -13.1)
	if phase == 7:
		verify(world.run_game.extract(world.run_game.revision), "Bank soak evening")
		world.travel("stash")
	world.player.camera.rotation = Vector3(-0.1, 0, 0)
	world.player.rotation.y = -0.4 if phase < 4 else 0

func finish_table(site: String) -> void:
	var night = world.run_game
	if night.heat > 0:
		verify(night.service_action("cool", "", night.revision), "Soak cooling service")
	var table = night.enter_table(301, night.revision, site)
	verify(table != null, "Soak table available")
	if table == null: return
	var count := 0
	while table.state.status != "finished" and count < 200:
		count += 1
		if table.state.status == "hand_over": table.next_hand(table.revision)
		elif table.state.currentActorId.is_empty(): table.advance(table.revision)
		else:
			var id: String = table.state.currentActorId
			var legal: Dictionary = table.legal_actions(id)
			verify(table.act(id, "fold" if id != "player" else ("check" if legal.check else "call"), table.revision), "Soak legal action")
	verify(night.settle_table(night.revision), "Soak table settles")
