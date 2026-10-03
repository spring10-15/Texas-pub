extends SceneTree
var checks := 0
var failures := 0

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var rules = load("res://three_d/rules/run.gd")
	var checkpoint = load("res://three_d/rules/run_checkpoint.gd")
	for venue in rules.SCENE_NAMES:
		for item in ["kitchen-pass", "dock-passkey"]:
			var night = rules.new(content)
			verify(night.start(night.revision, venue, 0), "Start baseline shelf plan")
			var wealth: int = night.vault + night.cash
			for site in ["cargo-table", "ledger-cellar", "mirror-hall", "embers-table"]:
				if item in night.shop_stock(): break
				if night.heat > 0:
					wealth -= int(night.scene_definition().heatReductionCost)
					verify(night.service_action("cool", "", night.revision), "Cool through actual service")
				var table = night.enter_table(301, night.revision, site)
				verify(table != null, "Unlock next shelf by playing table")
				if table == null: break
				finish(table)
				wealth += int(table.state.players[0].stack) - int(table.state.tableDef.buyIn)
				verify(night.settle_table(night.revision), "Settle shelf-unlocking table")
				if night.last_table_result.reward_added:
					wealth += int(content.items[night.last_table_result.reward].value)
			var route: String = content.items[item].unlockRoute
			verify(not night.extract(night.revision, route), "Unknown special exit rejected")
			verify(item in night.shop_stock(), "Pass appears on actual shelf")
			verify(night.service_action("buy", item, night.revision), "Purchase pass using cash and AP")
			wealth -= int(content.items[item].buy)
			verify(night.service_action("pass", item, night.revision), "Consume pass and reveal exit")
			verify(item not in night.inventory and night.route_known(route), "Pass consumed exactly once")
			verify(not night.service_action("pass", item, night.revision), "Used pass cannot be reused")
			var snapshot: Dictionary = checkpoint.capture(night)
			night = checkpoint.restore(snapshot, content)
			verify(night != null, "Pass route restores")
			if night == null: continue
			verify(night.route_known(route) and item not in night.inventory, "Restored lead keeps consumed pass absent")
			var quote: Dictionary = night.extraction_quote(route)
			verify(quote.reason.is_empty(), "Pass route meets heat and fee conditions")
			verify(night.extract(night.revision, route), "Pass extraction succeeds")
			verify(night.vault == wealth - int(quote.fee), "Pass purchase and extraction wealth balances")
			var banked: int = night.vault
			verify(not night.extract(night.revision, route) and night.vault == banked, "Pass extraction cannot pay twice")
			print("Packed pass route: ", venue, "/", route)
	print("Export pass routes: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func finish(table) -> void:
	var steps := 0
	while table.state.status != "finished" and steps < 200:
		steps += 1
		if table.state.status == "hand_over": table.next_hand(table.revision)
		elif table.state.currentActorId.is_empty(): table.advance(table.revision)
		else:
			var id: String = table.state.currentActorId
			var legal: Dictionary = table.legal_actions(id)
			verify(table.act(id, "fold" if id != "player" else ("check" if legal.check else "call"), table.revision), "Use legal table action")
	verify(table.state.status == "finished", "Table finishes before pass purchase")
