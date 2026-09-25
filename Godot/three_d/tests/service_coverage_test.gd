extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Checkpoint = preload("res://three_d/rules/run_checkpoint.gd")
var failures: Array[String] = []
var hits := {}
func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json"))
	var cases := {
		"buy":["buy","steadying-drink",""], "sell":["sell","steadying-drink",""], "drink":["drink","steadying-drink",""], "cool":["cool","",""], "intel":["intel","mirror-hall",""],
		"stale_revision":["buy","steadying-drink",""], "inactive":["buy","steadying-drink","请先带钱进入酒馆"], "mismatch":["drink","ivory-chip","道具与动作不匹配"], "table_active":["buy","steadying-drink","请先结束牌桌并离座"], "no_actions":["buy","steadying-drink","本轮行动力已用完，完成牌桌后刷新"], "not_stocked":["buy","ivory-chip","本轮未上架"], "buy_cash":["buy","steadying-drink","随身现金不足"], "full_bag":["buy","steadying-drink","背包已满"], "sell_unowned":["sell","steadying-drink","背包中没有此物品"], "cool_used":["cool","","本轮已降过风声或无需降风声"], "cool_unneeded":["cool","","本轮已降过风声或无需降风声"], "drink_unowned":["drink","steadying-drink","背包中没有镇定酒"], "cool_cash":["cool","","随身现金不足"], "intel_known":["intel","mirror-hall","该牌桌规则已知或尚未开放"], "intel_unknown":["intel","unknown","该牌桌规则已知或尚未开放"], "unknown_action":["unknown","","未知操作"]}
	for key in cases:
		var r := Run.new(content)
		r.start(r.revision,"smoky-den",0)
		r.heat = 2
		if key in ["sell","drink"]: r.inventory.append("steadying-drink")
		match key:
			"inactive": r.active = false
			"table_active": r.enter_table(7,r.revision)
			"no_actions": r.action_points = 0
			"buy_cash": r.cash = 29
			"full_bag": r.inventory.assign(["ivory-chip","ivory-chip","ivory-chip","ivory-chip","ivory-chip","ivory-chip"])
			"cool_used": r.heat_reduced = true
			"cool_unneeded": r.heat = 0
			"cool_cash": r.cash = 23
			"intel_known": r.known_rules.append("mirror-hall")
		var before := Checkpoint.capture(r)
		var row: Array = cases[key]
		var ok: bool = r.service_reason(row[0],row[1]) == row[2] and Checkpoint.capture(r) == before
		var accepted: bool = r.service_action(row[0],row[1],r.revision-1 if key == "stale_revision" else r.revision)
		if key in ["buy","sell","drink","cool","intel"]:
			var expected := before.duplicate(true)
			expected.action_points -= 1
			expected.revision += 1
			match key:
				"buy": expected.cash -= 30; expected.inventory.append("steadying-drink")
				"sell": expected.cash += 10; expected.inventory.erase("steadying-drink")
				"drink": expected.inventory.erase("steadying-drink"); expected.heat -= 1; expected.heat_reduced = true
				"cool": expected.cash -= 24; expected.heat -= 1; expected.heat_reduced = true
				"intel": expected.known_rules.append("mirror-hall")
			expected.service_message = r.service_message
			ok = ok and accepted and not r.service_message.is_empty() and Checkpoint.capture(r) == expected
		else:
			ok = ok and not accepted and Checkpoint.capture(r) == before
		var id: String = "service."+key
		if ok: hits[id] = {"test":"service_coverage_test.gd","postcondition_verified":true}
		else: failures.append(id); push_error(id)
	var valuable_sales := {}
	for item_id in content.items:
		if content.items[item_id].kind != "valuable": continue
		var run := Run.new(content)
		run.start(run.revision,"smoky-den",0)
		run.inventory.append(item_id)
		var cash_before: int = run.cash
		var wealth_before: int = run.vault + run.cash + run.valuable_total()
		var action_points_before: int = run.action_points
		var revision_before: int = run.revision
		var amount: int = int(content.items[item_id].value)
		var accepted: bool = run.service_reason("sell",item_id).is_empty() and run.service_action("sell",item_id,run.revision)
		var balanced: bool = run.cash == cash_before + amount and item_id not in run.inventory and run.action_points == action_points_before - 1 and run.revision == revision_before + 1 and run.vault + run.cash + run.valuable_total() == wealth_before
		valuable_sales[item_id] = {"value":amount,"sold":accepted,"postcondition_verified":accepted and balanced}
		if not accepted or not balanced:
			failures.append("service.sell_valuable."+item_id)
			push_error("service.sell_valuable."+item_id)
	if valuable_sales.size() != 10:
		failures.append("Expected 10 valuable sale cases")
		push_error("Expected 10 valuable sale cases")
	var expected: Array = catalog.transitions.filter(func(row): return str(row.id).begins_with("service.")).map(func(row): return row.id)
	for id in hits:
		if id not in expected: failures.append("Uncatalogued hit: "+id)
	var missing: Array = expected.filter(func(id): return not hits.has(id))
	var hashes := {}
	for file in DirAccess.get_files_at("res://three_d/rules"):
		if not (file.ends_with(".gd") or file.ends_with(".json")): continue
		hashes[file] = FileAccess.get_file_as_string("res://three_d/rules/"+file).sha256_text()
	var report := {"scope":"service subgraph only; includes the sale postcondition for all 10 valuable item definitions","source_sha256":hashes,"test_sha256":FileAccess.get_file_as_string("res://three_d/tests/service_coverage_test.gd").sha256_text(),"catalog_sha256":FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json").sha256_text(),"denominator":expected.size(),"numerator":hits.size(),"missing":missing,"failures":failures,"hits":hits,"valuable_sales":valuable_sales,"overall_state_transition_coverage":null,"overall_status":"Other families not yet enumerated; no global percentage claimed."}
	FileAccess.open("res://../output/3d/service-coverage.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("SERVICE_COVERAGE covered=",hits.size()," total=",expected.size()," missing=",missing," failures=",failures)
	quit(0 if failures.is_empty() and missing.is_empty() else 1)
