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
	for source in Run.SCENE_NAMES:
		for destination in Run.SCENE_NAMES:
			if source == destination: continue
			var r := Run.new(content)
			r.start(r.revision,source,41)
			var initial := Checkpoint.capture(r)
			verify(not r.transfer_venue(destination,r.revision) and Checkpoint.capture(r)==initial,"Cannot transfer before playing")
			r.completed.append("cargo-table")
			r.public_exit = true
			r.heat = 3
			r.heat_reduced = true
			r.search_index = 2
			r.inventory.assign(["ivory-chip","kitchen-pass"])
			r.route_flags = {"service-stairs":true,"fixed":true}
			r.reservation = {"id":"fixture"}
			var event: Dictionary = Run.SearchEvents.event_for(r,"cargo-table")
			r.search_results = {"cargo-table":{"event":Run.SearchEvents.event_id(r,"cargo-table"),"choice":event.choices[0].id,"message":"已完成搜索（迁移夹具）"}}
			var before := Checkpoint.capture(r)
			var quote: Dictionary = r.transfer_quote(destination)
			verify(quote.fee==r.extraction_quote().fee+15 and Checkpoint.capture(r)==before,"Preview quotes exact exit fee plus fare without mutation")
			verify(not r.transfer_venue(destination,r.revision-1) and Checkpoint.capture(r)==before,"Stale transfer cannot charge")
			verify(r.transfer_venue(destination,r.revision),"Each ordered venue pair transfers")
			verify(r.cash==before.cash-quote.fee and r.vault==before.vault and r.action_points==before.action_points-1,"Only quoted cash and AP debited; vault untouched")
			for field in ["inventory","completed","heat","heat_reduced","search_results","search_index","run_seed"]:
				verify(r.get(field)==before[field],"Evening state carried: "+field)
			for field in ["opponents","events","room_layout","table_seeds"]:
				verify(r.variant_plan[field]==before.variant_plan[field],"Transfer cannot reroll "+field)
			verify(r.scene_id==destination and not r.public_exit and r.route_flags.is_empty() and r.reservation.is_empty() and not r.fixed_known(),"Local exits and reservation require fresh discovery")
			verify(Run.Variants.valid(r.variant_plan,content,destination),"Destination shelf plan valid")
			verify(r.venue_history==[source,destination] and r.transfer_log[0].fee==quote.fee,"Journey recorded")
			var after := Checkpoint.capture(r)
			verify(not r.transfer_venue(destination,r.revision) and not r.transfer_venue(source,r.revision) and Checkpoint.capture(r)==after,"No revisit or repeated transfer")
			var third: String = Run.SCENE_NAMES.keys().filter(func(id): return id not in r.venue_history)[0]
			verify(not r.transfer_venue(third,r.revision) and Checkpoint.capture(r)==after,"Must play at arrival before another hop")
			var loaded: RefCounted = Checkpoint.restore(after,content)
			verify(loaded != null and Checkpoint.capture(loaded)==after,"Whole journey restores")
			if loaded == null: continue
			loaded.discover_exit()
			var exit_quote: Dictionary = loaded.extraction_quote()
			verify(loaded.extract(loaded.revision) and loaded.vault==before.vault+exit_quote.net and loaded.last_result.journey==r.transfer_log,"Arrival can extract once with journey audit at destination rates")
	for source in Run.SCENE_NAMES:
		for destination in Run.SCENE_NAMES:
			if source == destination: continue
			var night := Run.new(content)
			night.start(night.revision,source,0)
			var expected_total := int(content.startingVault)
			for site in Run.Variants.TABLES:
				if night.heat > 0 and not night.heat_reduced:
					var fee: int = night.scene_definition().heatReductionCost
					verify(night.service_action("cool","",night.revision),"Night cooling uses available action")
					expected_total -= fee
				var table: RefCounted = night.enter_table(301,night.revision,site)
				verify(table != null,"Night reaches table "+site)
				if table == null: break
				finish(table)
				expected_total += int(table.state.players[0].stack)-int(table.state.tableDef.buyIn)
				verify(night.settle_table(night.revision),"Night settles table once")
				if night.last_table_result.reward_added:
					expected_total += int(content.items[night.last_table_result.reward].value)
				verify(night.vault+night.cash+night.valuable_total()==expected_total,"Independent evening wealth ledger balances after table")
				verify(not night.enforce_pressure(),"Cooling keeps scripted night below forced exit")
				if site=="cargo-table":
					var quote: Dictionary = night.transfer_quote(destination)
					verify(night.transfer_venue(destination,night.revision),"Real completed table enables transfer")
					expected_total -= int(quote.fee)
					verify(night.vault+night.cash+night.valuable_total()==expected_total,"Travel preserves all wealth except quoted fee")
					var copied: RefCounted = Checkpoint.restore(Checkpoint.capture(night),content)
					verify(copied != null,"Between-venue save restores")
					night = copied
			var quote: Dictionary = night.extraction_quote()
			expected_total -= int(quote.fee)
			verify(night.completed.size()==4 and night.extract(night.revision) and night.vault==expected_total,"Complete two-venue evening ends with exact independent ledger")
	var r := Run.new(content)
	r.start(r.revision,"smoky-den",82)
	r.completed.append("cargo-table")
	r.public_exit = true
	for blocker in ["heat","ap","cash","finished"]:
		var isolated: RefCounted = Checkpoint.restore(Checkpoint.capture(r),content)
		match blocker:
			"heat": isolated.heat = 6
			"ap": isolated.action_points = 0
			"cash": isolated.cash = 10
			"finished": isolated.completed.assign(Run.Variants.TABLES)
		var before := Checkpoint.capture(isolated)
		verify(not isolated.transfer_venue("rooftop-club",isolated.revision) and Checkpoint.capture(isolated)==before,"Blocked transfer leaves state untouched: "+blocker)
	var corrupt := Checkpoint.capture(r)
	corrupt.venue_history = 12
	verify(Checkpoint.restore(corrupt,content)==null,"Malformed history type rejected safely")
	var old := Checkpoint.capture(r)
	for field in ["venue_history","arrival_completed","transfer_log"]: old.erase(field)
	var legacy: RefCounted = Checkpoint.restore(old,content)
	verify(legacy != null and legacy.venue_history==["smoky-den"] and legacy.transfer_log.is_empty(),"Old save initializes current venue only")
	var world: Node = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	world.run_game = r
	world.travel("tavern")
	world.show_run_panel("extract",true)
	verify(not world.transfer_button.visible,"Remote route preview cannot start a city trip")
	world.show_run_panel("extract")
	verify(world.transfer_button.visible,"Physical exit offers continued evening")
	world.transfer_button.pressed.emit()
	verify(world.run_action=="transfer" and world.run_body.text.contains("原预约失效且不退款"),"UI explains transfer losses")
	var destination: String = world.scene_choice.get_item_metadata(world.scene_choice.selected)
	var quote: Dictionary = r.transfer_quote(destination)
	if OS.get_cmdline_user_args().has("--capture"):
		for i in range(12): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../output/3d/venue-transfer.png"))
	world.confirm_run_action()
	verify(world.current_room=="tavern" and r.scene_id==destination and r.cash==300-quote.fee and r.vault==900,"UI transfers without banking or resetting bankroll")
	verify(world.restore_checkpoint(world.checkpoint_state()) and world.run_game.venue_history.size()==2,"World restores transferred location")
	world.queue_free()
	print("VENUE_TRANSFER checks=",checks," failed=",failures.size()," failures=",failures)
	quit(0 if failures.is_empty() else 1)

func finish(table: RefCounted) -> void:
	var steps := 0
	while table.state.status != "finished" and steps < 200:
		steps += 1
		if table.state.status == "hand_over": table.next_hand(table.revision)
		elif table.state.currentActorId.is_empty(): table.advance(table.revision)
		else:
			var id: String = table.state.currentActorId
			var legal: Dictionary = table.legal_actions(id)
			verify(table.act(id,"fold" if id!="player" else ("check" if legal.check else "call"),table.revision),"Script uses legal table action")
	verify(table.state.status=="finished","Table terminates")
