extends SceneTree
var failures := 0
var checks := 0

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not OS.get_cmdline_user_args().has("--test"):
		push_error("Pass -- --test to protect player saves")
		quit(1)
		return
	var world = load("res://three_d/scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	var rules = load("res://three_d/rules/run.gd")
	for venue in rules.SCENE_NAMES:
		var night = rules.new(world.table_content)
		verify(night.start(night.revision, venue, 41), "Start " + venue)
		var starting_vault: int = night.vault
		var searched := false
		var event: Dictionary = rules.SearchEvents.event_for(night, "cargo-table")
		for choice in event.choices:
			if night.service_reason("search", "cargo-table", choice.id).is_empty():
				searched = night.service_action("search", "cargo-table", night.revision, choice.id)
				break
		verify(searched, "Resolve legal search in " + venue)
		var table = night.enter_table(301, night.revision, "cargo-table")
		verify(table != null, "Enter cargo table in " + venue)
		if table == null: continue
		var steps := 0
		while table.state.status != "finished" and steps < 200:
			steps += 1
			if table.state.status == "hand_over":
				table.next_hand(table.revision)
			elif table.state.currentActorId.is_empty():
				table.advance(table.revision)
			else:
				var id: String = table.state.currentActorId
				var legal: Dictionary = table.legal_actions(id)
				verify(table.act(id, "fold" if id != "player" else ("check" if legal.check else "call"), table.revision), "Legal packed table action")
		verify(table.state.status == "finished", "Packed table terminates")
		verify(night.settle_table(night.revision), "Packed table settles")
		verify(night.public_exit, "Completed packed table reveals public exit")
		var quote: Dictionary = night.extraction_quote()
		verify(quote.reason.is_empty(), "Packed extraction is available")
		verify(night.extract(night.revision), "Packed extraction succeeds")
		verify(night.vault == starting_vault + int(quote.net) and night.cash == 0 and not night.active, "Packed extraction banks exact quote")
		print("Packed loop completed: ", venue)
	world.queue_free()
	await process_frame
	print("Export loop: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
