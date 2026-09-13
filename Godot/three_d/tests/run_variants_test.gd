extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Checkpoint = preload("res://three_d/rules/run_checkpoint.gd")
var checks := 0
var failures: Array[String] = []
func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var diversity := {}
	for scene in Run.SCENE_NAMES:
		var combinations := {}
		for seed_value in range(1, 101):
			var r := Run.new(content)
			verify(r.start(r.revision,scene,seed_value),"Seeded departure accepted")
			verify(Run.Variants.valid(r.variant_plan,content,scene),"Generated plan satisfies pool constraints")
			verify(r.variant_plan == Run.Variants.generate(content,scene,seed_value),"Same seed and venue reproduce plan")
			combinations[JSON.stringify([r.variant_plan.shelves,r.variant_plan.initial_offer])] = true
			for stage in range(1,6):
				r.search_index = stage
				var before: Dictionary = Checkpoint.capture(r)
				var stock: Array = r.shop_stock()
				verify(stock == r.shop_stock() and before == Checkpoint.capture(r),"Inspection never draws RNG or mutates run")
				for item in content.shops[scene][str(stage)]:
					if item not in stock:
						verify(not r.service_action("buy",item,r.revision) and Checkpoint.capture(r)==before,"Unavailable tool cannot be bought or consume resources")
				stock.clear()
				verify(not r.shop_stock().is_empty(),"Caller cannot mutate committed shelf")
				var loaded: RefCounted = Checkpoint.restore(before,content)
				verify(loaded != null and loaded.variant_plan == r.variant_plan and loaded.shop_stock() == r.shop_stock() and loaded.run_seed == seed_value,"Restore preserves seed and all planned stages")
			var rejected := Checkpoint.capture(r)
			rejected.variant_plan.shelves["1"] = ["not-an-item"]
			verify(Checkpoint.restore(rejected,content)==null,"Unknown shelf item rejected")
			rejected = Checkpoint.capture(r)
			rejected.variant_plan.table_seeds["cargo-table"] = -1
			verify(Checkpoint.restore(rejected,content)==null,"Invalid table seed rejected")
		diversity[scene] = combinations.size()
		verify(combinations.size()>1,"Different seeds change actual stock/route combination")
	var legacy := Run.new(content)
	legacy.start(legacy.revision)
	var old_save := Checkpoint.capture(legacy)
	for field in ["run_seed","variant_plan"]: old_save.erase(field)
	var restored: RefCounted = Checkpoint.restore(old_save,content)
	verify(restored != null and restored.variant_plan.is_empty() and restored.shop_stock()==content.shops["smoky-den"]["1"],"Old active run keeps original shelf without reroll")
	var world: Node = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.show_run_panel("enter")
	world.confirm_run_action()
	verify(world.run_game.run_seed>0 and not world.run_game.variant_plan.is_empty(),"Normal UI departure commits random seed")
	var targets: Array = world.get_node("Tavern/ShopObjects").get_children().filter(func(node): return node is Area3D)
	var displayed: Array = targets.map(func(node): return str(node.action_id).trim_prefix("shop:"))
	verify(displayed==world.run_game.shop_stock(),"Physical shelf targets match seeded stock")
	var saved: Dictionary = world.checkpoint_state()
	var planned: int = world.run_game.variant_plan.table_seeds["cargo-table"]
	await seat(world)
	world.start_table()
	verify(world.table_game != null and world.table_game.state.seed==planned,"Normal table start uses committed seed")
	var deck: Array = world.table_game.state.deck.duplicate(true)
	world.queue_free()
	await process_frame
	world = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false)
	verify(world.restore_checkpoint(saved),"Restore pre-table checkpoint in fresh game")
	world.paused = false
	await seat(world)
	world.start_table()
	verify(world.table_game != null and world.table_game.state.deck==deck,"Reload before seating cannot reroll deck")
	var report := {"checks":checks,"failed":failures.size(),"failures":failures,"distinct_shelf_route_plans_per_100_seeds":diversity,"scope":"Shelf availability and initial fixed offer only. Room/event/opponent pools and human strategy diversity remain unverified."}
	FileAccess.open("res://../output/3d/run-variants.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("RUN_VARIANTS ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func seat(world: Node) -> void:
	world.player.position = Vector3(9.55, 0.02, 1.15)
	world.player.camera.look_at(world.table_target.global_position)
	for i in range(5): await physics_frame
	verify(world.request_action(world.table_target),"Seat through actual interaction")
