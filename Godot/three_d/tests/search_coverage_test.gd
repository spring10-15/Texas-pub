extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Checkpoint = preload("res://three_d/rules/run_checkpoint.gd")
var failures: Array[String] = []
var hits := {}
func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json"))
	var reasons := {"goods":"", "route":"", "cash":"", "paid_intel":"", "free_intel":"", "cool":"", "unknown_choice":"未知选择", "inactive":"只能在离桌探索时处理", "table_active":"只能在离桌探索时处理", "locked":"该房间尚未解锁", "repeat":"本局已处理此处", "no_action_points":"行动力不足", "insufficient_cash":"随身现金不足", "full_bag":"背包已满", "known_route":"已知这条路线，无需重复取线索", "completed_intel":"该牌桌已完成，无需购买情报", "known_intel":"已知全部情报", "cool_used":"本轮已降过风声或无需降低", "cool_unneeded":"本轮已降过风声或无需降低", "stale_revision":""}
	for key in reasons:
		var r := Run.new(content)
		r.start(r.revision,"smoky-den",0)
		r.heat = 2
		var site := "cargo-table"
		var choice := "goods"
		if key in ["cash", "paid_intel", "insufficient_cash", "completed_intel", "known_intel"]:
			site = "ledger-cellar"
			choice = "cash" if key == "cash" else "intel"
			r.completed.assign(["cargo-table"])
		if key == "free_intel":
			site = "mirror-hall"
			choice = "intel"
			r.completed.assign(["cargo-table", "ledger-cellar"])
		if key in ["route", "cool", "cool_used", "cool_unneeded", "known_route"]:
			site = "embers-table"
			choice = "route" if key in ["route", "known_route"] else "cool"
			r.completed.assign(["cargo-table", "ledger-cellar", "mirror-hall"])
		match key:
			"unknown_choice": choice = "unknown"
			"inactive": r.active = false
			"table_active": r.enter_table(1,r.revision,"cargo-table")
			"locked": site = "mirror-hall"
			"repeat": r.service_action("search",site,r.revision,choice)
			"no_action_points": r.action_points = 0
			"insufficient_cash": r.cash = 14
			"full_bag": r.inventory.assign(["ivory-chip", "ivory-chip", "ivory-chip", "ivory-chip", "ivory-chip", "ivory-chip"])
			"known_route": r.route_flags["service-stairs"] = true
			"completed_intel": r.completed.append("mirror-hall")
			"known_intel": r.full_intel["mirror-hall"] = true
			"cool_used": r.heat_reduced = true
			"cool_unneeded": r.heat = 0
		var before := Checkpoint.capture(r)
		var reason: String = r.service_reason("search",site,choice)
		var ok: bool = reason == reasons[key] and Checkpoint.capture(r) == before
		var accepted: bool = r.service_action("search",site,r.revision-1 if key == "stale_revision" else r.revision,choice)
		if key in ["goods", "route", "cash", "paid_intel", "free_intel", "cool"]:
			var expected := before.duplicate(true)
			expected.action_points -= 1
			expected.revision += 1
			match key:
				"goods": expected.inventory.append("old-silver-lighter"); expected.heat += 1
				"route": expected.route_flags["service-stairs"] = true
				"cash": expected.cash += 25; expected.heat += 1
				"paid_intel": expected.cash -= 15; expected.full_intel["mirror-hall"] = true; expected.known_rules.append("mirror-hall")
				"free_intel": expected.full_intel["embers-table"] = true; expected.known_rules.append("embers-table")
				"cool": expected.cash -= 30; expected.heat -= 1; expected.heat_reduced = true
			# Text is presentation data; require a nonempty message and its exact recorded copy.
			expected.service_message = r.service_message
			expected.search_results[site] = {"event":site,"choice":choice,"message":r.service_message}
			ok = ok and accepted and not r.service_message.is_empty() and Checkpoint.capture(r) == expected
		else:
			ok = ok and not accepted and Checkpoint.capture(r) == before
		var id: String = "search."+key
		if ok: hits[id] = {"test":"search_coverage_test.gd","postcondition_verified":true}
		else: failures.append(id); push_error(id)
	var expected: Array = catalog.transitions.filter(func(row): return str(row.id).begins_with("search.")).map(func(row): return row.id)
	for id in hits:
		if id not in expected: failures.append("Uncatalogued hit: "+id)
	var missing: Array = expected.filter(func(id): return not hits.has(id))
	var hashes := {}
	for file in DirAccess.get_files_at("res://three_d/rules"):
		if not (file.ends_with(".gd") or file.ends_with(".json")): continue
		hashes[file] = FileAccess.get_file_as_string("res://three_d/rules/"+file).sha256_text()
	var report := {"scope":"search subgraph only","source_sha256":hashes,"test_sha256":FileAccess.get_file_as_string("res://three_d/tests/search_coverage_test.gd").sha256_text(),"catalog_sha256":FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json").sha256_text(),"denominator":expected.size(),"numerator":hits.size(),"missing":missing,"failures":failures,"hits":hits,"overall_state_transition_coverage":null,"overall_status":"Other families not yet enumerated; no global percentage claimed."}
	FileAccess.open("res://../output/3d/search-coverage.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("SEARCH_COVERAGE covered=",hits.size()," total=",expected.size()," missing=",missing," failures=",failures)
	quit(0 if failures.is_empty() and missing.is_empty() else 1)
