extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Checkpoint = preload("res://three_d/rules/run_checkpoint.gd")
var failures: Array[String] = []
var hits := {}
func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json"))
	for key in ["lens", "sleeve", "preserve_preview", "heat_cap", "stale_revision", "inactive", "mismatch", "no_table", "finished", "unowned", "used", "river", "after_preflop", "after_action", "other_actor"]:
		var r := Run.new(content)
		r.start(r.revision,"smoky-den",0)
		r.inventory.assign(["marked-lens","sleeve-clip"])
		r.enter_table(7,r.revision)
		var kind := "sleeve" if key in ["sleeve","preserve_preview","after_preflop","after_action","other_actor"] else "lens"
		var item := "sleeve-clip" if kind == "sleeve" else "marked-lens"
		var reason := ""
		match key:
			"preserve_preview": r.service_action("lens","marked-lens",r.revision)
			"heat_cap": r.heat = 6
			"inactive": r.active = false; reason = "请先带钱进入酒馆"
			"mismatch": item = "steadying-drink"; reason = "道具与动作不匹配"
			"no_table": r.table = null; reason = "只能在进行中的牌桌使用"
			"finished": r.table.state.status = "finished"; reason = "只能在进行中的牌桌使用"
			"unowned": r.inventory.clear(); reason = "背包中没有此道具"
			"used": r.used_tools.append(item); reason = "本桌已经使用过"
			"river": r.table.state.street = "river"; reason = "公共牌已全部揭晓"
			"after_preflop": r.table.state.street = "flop"; reason = "只能在翻牌前首次行动前换牌"
			"after_action": r.table.state.turnCounter = 1; reason = "只能在翻牌前首次行动前换牌"
			"other_actor": r.table.state.currentActorId = r.table.state.players[1].id; reason = "只能在翻牌前首次行动前换牌"
		var before := Checkpoint.capture(r)
		var ok: bool = r.service_reason(kind,item) == reason and Checkpoint.capture(r) == before
		var cards: Array = r.table.state.deck.duplicate(true) if r.table != null else []
		var hole: Array = r.table.state.players[0].holeCards.duplicate(true) if r.table != null else []
		var table_revision: int = r.table.revision if r.table != null else 0
		var accepted: bool = r.service_action(kind,item,r.revision-1 if key == "stale_revision" else r.revision)
		if key in ["lens","sleeve","preserve_preview","heat_cap"]:
			var expected_inventory: Array = before.inventory.duplicate()
			expected_inventory.erase(item)
			var expected_tools: Array = before.used_tools.duplicate()
			expected_tools.append(item)
			ok = ok and accepted and r.inventory == expected_inventory and r.used_tools == expected_tools and r.cash == before.cash and r.vault == before.vault and r.action_points == before.action_points and r.revision == before.revision+1 and r.table.revision == table_revision+1
			ok = ok and r.heat == mini(6,before.heat+int(content.items[item].heat))
			if kind == "lens":
				ok = ok and r.preview == cards.back() and r.preview_hand == r.table.state.handNumber and r.table.state.deck == cards and r.table.state.players[0].holeCards == hole
			else:
				var next_card: Dictionary = cards.pop_at(cards.size()-2 if key == "preserve_preview" else cards.size()-1)
				hole[1] = next_card
				ok = ok and r.table.state.deck == cards and r.table.state.players[0].holeCards == hole and r.preview == before.preview
		else:
			ok = ok and not accepted and Checkpoint.capture(r) == before
		var id: String = "tool."+key
		if ok: hits[id] = {"test":"tool_coverage_test.gd","postcondition_verified":true}
		else: failures.append(id); push_error(id)
	var expected: Array = catalog.transitions.filter(func(row): return str(row.id).begins_with("tool.")).map(func(row): return row.id)
	for id in hits:
		if id not in expected: failures.append("Uncatalogued hit: "+id)
	var missing: Array = expected.filter(func(id): return not hits.has(id))
	var hashes := {}
	for file in DirAccess.get_files_at("res://three_d/rules"):
		if not (file.ends_with(".gd") or file.ends_with(".json")): continue
		hashes[file] = FileAccess.get_file_as_string("res://three_d/rules/"+file).sha256_text()
	var report := {"scope":"tool subgraph only","source_sha256":hashes,"test_sha256":FileAccess.get_file_as_string("res://three_d/tests/tool_coverage_test.gd").sha256_text(),"catalog_sha256":FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json").sha256_text(),"denominator":expected.size(),"numerator":hits.size(),"missing":missing,"failures":failures,"hits":hits,"overall_state_transition_coverage":null,"overall_status":"Other families not yet enumerated; no global percentage claimed."}
	FileAccess.open("res://../output/3d/tool-coverage.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TOOL_COVERAGE covered=",hits.size()," total=",expected.size()," missing=",missing," failures=",failures)
	quit(0 if failures.is_empty() and missing.is_empty() else 1)
