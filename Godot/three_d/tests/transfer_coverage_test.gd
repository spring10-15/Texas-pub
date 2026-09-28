extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Checkpoint = preload("res://three_d/rules/run_checkpoint.gd")
var failures: Array[String] = []
var hits := {}
func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json"))
	var reasons := {"success":"","stale_revision":"","inactive":"当前没有进行中的出局","table_active":"请先完成牌桌并离座","unknown_destination":"未知酒馆","already_visited":"本晚已去过这家酒馆","no_local_completion":"至少完成本店一桌并离座后再转场","evening_complete":"本晚四桌已完成，请撤离落袋","no_action_points":"转场需要 1 行动力","insufficient_cash":"现金不足以支付出口费和 15 车费","exit_unknown":"尚未找到出口线索：查看门旁告示","exit_locked":"风声达到 6，普通出口已封锁"}
	for key in reasons:
		var r := Run.new(content)
		r.start(r.revision,"smoky-den",0)
		r.completed.append("cargo-table")
		r.search_index = 2
		r.public_exit = true
		var destination := "high-rise-suite"
		match key:
			"inactive": r.active = false
			"table_active": r.enter_table(1,r.revision,"ledger-cellar")
			"unknown_destination": destination = "unknown"
			"already_visited": destination = "smoky-den"
			"no_local_completion": r.completed.clear()
			"evening_complete": r.completed.assign(Run.Variants.TABLES)
			"no_action_points": r.action_points = 0
			"insufficient_cash": r.cash = 43 # 24 + floor(43*.12) + 15 = 44.
			"exit_unknown": r.public_exit = false
			"exit_locked": r.heat = 6
		var before := Checkpoint.capture(r)
		var quote: Dictionary = r.transfer_quote(destination)
		var ok: bool = quote.reason==reasons[key] and Checkpoint.capture(r)==before
		var accepted: bool = r.transfer_venue(destination,r.revision-1 if key=="stale_revision" else r.revision)
		if key=="success":
			ok = ok and accepted and r.cash==before.cash-quote.fee and r.action_points==before.action_points-1 and r.vault==before.vault and r.scene_id==destination and r.completed==before.completed and r.variant_plan.table_seeds==before.variant_plan.table_seeds and r.venue_history==["smoky-den",destination]
		else:
			ok = ok and not accepted and Checkpoint.capture(r)==before
		var id: String = "transfer."+key
		if ok: hits[id] = {"test":"transfer_coverage_test.gd","reason":quote.reason,"accepted":accepted,"checks":"quote and actual command outcome; rejected command preserves full checkpoint; first transfer records both venues"}
		else: failures.append(id); push_error(id)
	var legacy_transfer_cases := {}
	for format in ["empty_plan", "v1_plan"]:
		var legacy_source := Run.new(content)
		legacy_source.start(legacy_source.revision,"smoky-den",0 if format=="empty_plan" else 791)
		legacy_source.completed.append("cargo-table")
		legacy_source.search_index = 2
		legacy_source.public_exit = true
		var legacy_run: RefCounted = legacy_source
		if format=="empty_plan":
			legacy_source.variant_plan.clear()
		else:
			var legacy_save: Dictionary = Checkpoint.capture(legacy_source)
			legacy_save.variant_plan.version = 1
			for field in ["events", "opponents", "room_layout"]: legacy_save.variant_plan.erase(field)
			legacy_run = Checkpoint.restore(legacy_save,content)
		if legacy_run == null:
			failures.append("transfer."+format+"_restore"); push_error("transfer."+format+"_restore")
			continue
		var previous: Dictionary = Run.Variants.generate(content,"smoky-den",0) if format=="empty_plan" else legacy_run.variant_plan.duplicate(true)
		var old_revision: int = legacy_run.revision
		var old_cash: int = legacy_run.cash
		var fee_quote: Dictionary = legacy_run.transfer_quote("high-rise-suite")
		var accepted: bool = fee_quote.reason.is_empty() and legacy_run.transfer_venue("high-rise-suite",old_revision)
		var expected_opponents: Dictionary = previous.get("opponents",{})
		if expected_opponents.is_empty():
			for table_id in Run.Variants.TABLES: expected_opponents[table_id] = content.tables[table_id].opponentIds.duplicate()
		var expected_events: Dictionary = previous.get("events",{})
		if expected_events.is_empty():
			for table_id in Run.Variants.TABLES: expected_events[table_id] = table_id
		var ok: bool = accepted and legacy_run.scene_id=="high-rise-suite" and legacy_run.cash==old_cash-fee_quote.fee and legacy_run.action_points==1 and legacy_run.venue_history==["smoky-den","high-rise-suite"]
		ok = ok and legacy_run.variant_plan.table_seeds==previous.table_seeds and legacy_run.variant_plan.opponents==expected_opponents and legacy_run.variant_plan.events==expected_events
		ok = ok and legacy_run.variant_plan.room_layout==str(previous.get("room_layout","linear")) and Run.Variants.valid(legacy_run.variant_plan,content,"high-rise-suite")
		if ok:
			legacy_transfer_cases[format] = "legacy plan preserved where present; missing dimensions receive deterministic fallback during accepted transfer"
		else:
			failures.append("transfer."+format+"_plan"); push_error("transfer."+format+"_plan")
	if hits.has("transfer.success"):
		hits["transfer.success"]["legacy_transfer_cases"] = legacy_transfer_cases.keys()
	var expected: Array = catalog.transitions.filter(func(row): return str(row.id).begins_with("transfer.")).map(func(row): return row.id)
	for id in hits:
		if id not in expected: failures.append("Uncatalogued hit: "+id)
	var missing: Array = expected.filter(func(id): return not hits.has(id))
	var hashes := {}
	for file in DirAccess.get_files_at("res://three_d/rules"):
		if not (file.ends_with(".gd") or file.ends_with(".json")): continue
		hashes[file] = FileAccess.get_file_as_string("res://three_d/rules/"+file).sha256_text()
	var report := {"scope":"transfer subgraph plus legacy-plan compatibility paths","source_sha256":hashes,"test_sha256":FileAccess.get_file_as_string("res://three_d/tests/transfer_coverage_test.gd").sha256_text(),"catalog_sha256":FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json").sha256_text(),"denominator":expected.size(),"numerator":hits.size(),"missing":missing,"failures":failures,"hits":hits,"legacy_transfer_cases":legacy_transfer_cases,"overall_state_transition_coverage":null,"overall_status":"Other families not yet enumerated; no global percentage claimed."}
	FileAccess.open("res://../output/3d/transfer-coverage.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TRANSFER_COVERAGE covered=",hits.size()," total=",expected.size()," missing=",missing," failures=",failures)
	quit(0 if failures.is_empty() and missing.is_empty() else 1)
