extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Checkpoint = preload("res://three_d/rules/run_checkpoint.gd")
var checks := 0
var failures: Array[String] = []
var content: Dictionary
func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func fresh(scene: String) -> RefCounted:
	var r := Run.new(content)
	verify(r.start(r.revision, scene), "Starts " + scene)
	return r
func run() -> void:
	content = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var quotes := {"smoky-den":60, "high-rise-suite":96, "rooftop-club":67, "neon-poker-club":76}
	var prepay := {"smoky-den":[40,40], "high-rise-suite":[60,55], "rooftop-club":[40,50], "neon-poker-club":[50,60]}
	var grace := {"smoky-den":2, "high-rise-suite":3, "rooftop-club":1, "neon-poker-club":2}
	for scene in Run.SCENE_NAMES:
		var r: RefCounted = fresh(scene)
		r.discover_exit()
		verify(r.extraction_quote().fee == quotes[scene], "Scene-specific public fee " + scene)
		verify(r.shop_stock() == content.shops[scene]["1"], "Scene-specific opening shelf " + scene)
		var saved := Checkpoint.capture(r)
		var restored: RefCounted = Checkpoint.restore(saved, content)
		verify(restored != null and restored.scene_id == scene and restored.extraction_quote() == r.extraction_quote(), "Scene and fee survive reload " + scene)
		for offer in range(2):
			r = fresh(scene)
			r.route_flags.fixed = true
			r.offer_index = offer
			var before: int = r.cash
			verify(r.service_action("reserve", "", r.revision), "Can reserve " + scene + str(offer))
			verify(r.cash == before - prepay[scene][offer], "Correct prepayment including scene discount")
			verify(r.reservation.expiresAfterSearch == 1 + grace[scene], "Correct scene-specific reservation lifetime")
			verify(r.reservation.id == content.routes[scene].fixedRoutes[offer].id, "Correct route identity")
			verify(r.extraction_quote("fixed").fee == int(content.routes[scene].fixedRoutes[offer].finalCost), "Final fee paid separately")
			verify(not r.service_action("reserve", "", r.revision), "Live reservation cannot be overwritten")
			r.search_index = int(r.reservation.expiresAfterSearch)
			verify(r.extraction_quote("fixed").reason.is_empty(), "Valid through final reserved round")
			r.search_index += 1
			verify(not r.extraction_quote("fixed").reason.is_empty(), "Expired after its final reserved round")
		for kind in ["service-stairs", "river-launch"]:
			r = fresh(scene)
			var item := "kitchen-pass" if kind == "service-stairs" else "dock-passkey"
			r.inventory.append(item)
			verify(not r.extraction_quote(kind).reason.is_empty(), "Special route starts unknown")
			verify(r.service_action("pass", item, r.revision), "Pass reveals route in current scene")
			var route: Dictionary = content.routes[scene].specialRoutes[kind]
			r.heat = int(route.maxHeat)
			verify(r.extraction_quote(kind).reason.is_empty() and r.extraction_quote(kind).fee == maxi(10, int(route.finalCost) - int(content.scenes[scene].hiddenRouteRevealDiscount)), "Special route has own threshold and fee")
			r.heat += 1
			verify(not r.extraction_quote(kind).reason.is_empty(), "Special route blocks excess pressure")
			r.heat = 0
			var net: int = r.extraction_quote(kind).net
			verify(r.extract(r.revision, kind) and r.vault == 900 + net, "Special exit settles exact vault value")
			verify(r.start(r.revision, "smoky-den") and r.route_flags.is_empty() and r.reservation.is_empty(), "Scene intel cannot leak into next run")
		r = fresh(scene)
		r.enter_table(30, r.revision)
		verify(r.heat == 1 + int(content.scenes[scene].entryHeatBonus), "Scene entry heat applies per table")
	var invalid := Run.new(content)
	verify(not invalid.start(invalid.revision, "unknown") and invalid.vault == 1200, "Invalid destination is atomic")
	var legacy := Checkpoint.capture(fresh("smoky-den"))
	legacy.erase("scene_id")
	verify(Checkpoint.restore(legacy, content).scene_id == "smoky-den", "Legacy saves default to original scene")
	legacy.scene_id = "missing"
	verify(Checkpoint.restore(legacy, content) == null, "Unknown saved scene rejected")
	# Reach selection through the actual departure UI and observe runtime identities.
	var world: Node3D = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	for i in range(world.scene_choice.item_count):
		var scene: String = world.scene_choice.get_item_metadata(i)
		world.scene_choice.select(i)
		world.show_run_panel("enter")
		if scene == "high-rise-suite" and OS.get_cmdline_user_args().has("--capture"):
			for j in range(12): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../output/3d/venue-choice.png"))
		verify(world.run_heading.text.ends_with(Run.SCENE_NAMES[scene]), "Departure names chosen venue")
		world.confirm_run_action()
		verify(world.run_game.scene_id == scene and world.title_label.text == Run.SCENE_NAMES[scene], "Runtime uses chosen venue")
		verify(world.get_node("Tavern/KitchenExit").title.begins_with(world.run_game.route_name("service-stairs")), "Physical target uses current route name")
		verify(world.restore_checkpoint(world.checkpoint_state()) and world.run_game.scene_id == scene, "World restore preserves venue")
		world.run_game.discover_exit()
		world.show_run_panel("extract")
		var net: int = world.run_game.extraction_quote().net
		var vault: int = world.run_game.vault
		world.confirm_run_action()
		verify(world.current_room == "stash" and world.run_game.vault == vault + net, "Each selectable scene can extract through UI")
	var report := {"checks":checks,"failed":failures.size(),"failures":failures}
	FileAccess.open("res://../output/3d/scene-rules.json", FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("SCENE_RULES ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
