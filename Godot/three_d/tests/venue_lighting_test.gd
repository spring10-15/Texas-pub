extends SceneTree
var checks := 0
var failures: Array[String] = []
func verify(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures.append(message)
		push_error(message)
func _initialize() -> void: call_deferred("run")
func capture(world, id: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"): return
	for i in range(8): await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../output/3d/lighting-"+id+".png"))
func run() -> void:
	var world = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	var stash_color: Color = world.scene_environment.ambient_light_color
	var lamp: OmniLight3D = world.props.entries.lamp.node
	var lamp_color := lamp.light_color
	await capture(world,"stash")
	var seen: Array = [stash_color]
	var initial_light: OmniLight3D = world.props.entries.Tavernlight.node
	var original_color := initial_light.light_color
	var switched := {"Tavernlight":true,"lamp":true}
	world.props.restore(switched)
	for venue in world.RunRules.SCENE_NAMES:
		world.run_game = world.RunRules.new(world.table_content)
		verify(world.run_game.start(world.run_game.revision,venue,41), "Start lighting fixture " + venue)
		var run_before: Dictionary = world.RunCheckpoint.capture(world.run_game)
		var profile: Dictionary = world.venue_lighting.PROFILES[venue]
		for room in world.ROOMS:
			world.travel(room)
			verify(world.scene_environment.ambient_light_color.is_equal_approx(profile.ambient), "Room uses venue ambient " + venue + "/" + room)
			verify(world.RunCheckpoint.capture(world.run_game)==run_before, "Lighting travel does not mutate run " + venue + "/" + room)
		world.travel("tavern")
		verify(not profile.ambient in seen, "Venue ambient differs " + venue)
		seen.append(profile.ambient)
		var expected := original_color.lerp(profile.warm,0.65)
		verify(initial_light.light_color.is_equal_approx(expected), "Color derives from original, not previous venue " + venue)
		verify(initial_light.light_energy==0 and world.props.states.Tavernlight, "Sconce remains switched off " + venue)
		await capture(world,venue)
		var saved: Dictionary = world.checkpoint_state()
		world.venue_lighting.apply(world.get_node("Tavern"),"smoky-den" if venue!="smoky-den" else "neon-poker-club")
		verify(world.restore_checkpoint(saved) and initial_light.light_color.is_equal_approx(expected) and initial_light.light_energy==0, "Restore reapplies correct palette without switching light on " + venue)
		world.travel("stash")
		verify(world.scene_environment.ambient_light_color.is_equal_approx(stash_color) and lamp.light_color==lamp_color and lamp.light_energy==0, "Stash color and lamp state restored " + venue)
	print("VENUE_LIGHTING ",JSON.stringify({"checks":checks,"failed":failures.size(),"failures":failures}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
