extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Checkpoint = preload("res://three_d/rules/run_checkpoint.gd")
var checks := 0
var failures: Array[String] = []
func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	for site in Run.SearchEvents.EVENTS:
		for option in Run.SearchEvents.EVENTS[site].choices:
			var r := Run.new(content)
			r.start(r.revision)
			r.completed.assign(["cargo-table", "ledger-cellar", "mirror-hall"].slice(0, ["cargo-table", "ledger-cellar", "mirror-hall", "embers-table"].find(site)))
			r.heat = 2
			var original := Checkpoint.capture(r)
			var view := r.service_view("search", site)
			verify(view.actions.size() == 2 and Checkpoint.capture(r) == original, "Inspecting costs nothing")
			verify(not r.service_action("search", site, r.revision - 1, option.id), "Stale action rejected")
			verify(r.service_action("search", site, r.revision, option.id), "Resolves " + site + "/" + option.id)
			verify(r.action_points == 1, "Exactly one action spent")
			verify(r.cash == 300 + int(option.get("cash", 0)) - int(option.get("cost", 0)), "Exact cash change")
			verify(r.heat == 2 + int(option.get("heat", 0)) - (1 if option.get("cool", false) else 0), "Exact pressure change")
			if option.has("item"): verify(r.inventory.count(option.item) == 1, "One reward added")
			if option.has("route"): verify(r.route_known(option.route), "Route intel available")
			if option.has("intel"): verify(r.full_intel.has(option.intel), "Table intel available")
			var resolved := Checkpoint.capture(r)
			verify(not r.service_action("search", site, r.revision, option.id) and Checkpoint.capture(r) == resolved, "Fresh repeat cannot gain reward")
			var loaded: RefCounted = Checkpoint.restore(resolved, content)
			verify(loaded != null and loaded.search_results == r.search_results and not loaded.service_action("search", site, loaded.revision, option.id), "Reload cannot farm event")
			loaded.abandon(loaded.revision)
			loaded.start(loaded.revision)
			verify(loaded.search_results.is_empty(), "New run resets sites")
	var r := Run.new(content)
	r.start(r.revision)
	verify(not r.service_reason("search", "embers-table", "route").is_empty(), "Locked room rejected")
	r.inventory.assign(["ivory-chip", "ivory-chip", "ivory-chip", "ivory-chip", "ivory-chip", "ivory-chip"])
	var before := Checkpoint.capture(r)
	verify(not r.service_action("search", "cargo-table", r.revision, "goods") and Checkpoint.capture(r) == before, "Full bag changes nothing")
	r.inventory.clear()
	r.action_points = 0
	verify(not r.service_action("search", "cargo-table", r.revision, "lead"), "No AP blocks event")
	r.action_points = 2
	r.enter_table(4, r.revision)
	verify(not r.service_action("search", "cargo-table", r.revision, "lead"), "Active table blocks search")
	var world: Node3D = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	world.show_run_panel("enter")
	world.confirm_run_action()
	world.run_game.completed.assign(["cargo-table", "ledger-cellar", "mirror-hall"])
	for room in world.ROOMS:
		world.travel(room)
		var target: Area3D = world.get_node(world.ROOMS[room].node + "/SearchSite")
		world.player.position = Vector3(world.ROOMS[room].x - 1.4, 0.02, -2.65)
		world.player.camera.look_at(target.global_position)
		for i in range(5): await physics_frame
		verify(world.request_action(target) and world.service_mode == "search", "Actual ray opens search " + room)
		verify(world.services_panel.rows.get_child(0).text.contains(Run.SearchEvents.EVENTS[world.ROOMS[room].table].title), "Correct event shown")
		if room == "ledger" and OS.get_cmdline_user_args().has("--capture"):
			for i in range(12): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../output/3d/search-choice.png"))
		world.close_services()
	var report := {"checks":checks,"failed":failures.size(),"failures":failures}
	FileAccess.open("res://../output/3d/search-events.json", FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("SEARCH_EVENTS ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
