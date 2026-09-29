extends SceneTree
## Windowed render baseline for the stash and the first tavern room.

const WARMUP_FRAMES := 120
const SAMPLE_FRAMES := 300

func _initialize() -> void:
	call_deferred("run")

func sample(label: String) -> Dictionary:
	for i in range(WARMUP_FRAMES):
		await process_frame
	var intervals: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in range(SAMPLE_FRAMES):
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		intervals.append(float(now - last) / 1000.0)
		last = now
	intervals.sort()
	return {
		"scene": label,
		"frames": SAMPLE_FRAMES,
		"median_render_callback_interval_ms": intervals[SAMPLE_FRAMES / 2],
		"p95_render_callback_interval_ms": intervals[int(SAMPLE_FRAMES * 0.95) - 1],
		"fps_monitor": Performance.get_monitor(Performance.TIME_FPS),
		"video_memory_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
	}

func run() -> void:
	var world: Node3D = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var samples := [await sample("stash")]
	world.show_run_panel("enter")
	world.confirm_run_action()
	if world.current_room != "tavern":
		push_error("Cannot reach the tavern baseline viewpoint")
		quit(1)
		return
	samples.append(await sample("tavern_cargo"))
	var result := {
		"engine": Engine.get_version_info().string,
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "gl_compatibility")),
		"window_pixels": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"viewport_pixels": [root.get_visible_rect().size.x, root.get_visible_rect().size.y],
		"vsync_mode": DisplayServer.window_get_vsync_mode(),
		"warmup_frames_per_scene": WARMUP_FRAMES,
		"scope": "Stationary stash and cargo-room viewpoints on this host; render callback intervals may include scheduling/display pacing and do not prove target-device 60 fps or 30-minute stability.",
		"samples": samples,
	}
	var path := ProjectSettings.globalize_path("res://../output/3d/perf-baseline.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t") + "\n")
	print("PERF_BASELINE ", path)
	quit()
