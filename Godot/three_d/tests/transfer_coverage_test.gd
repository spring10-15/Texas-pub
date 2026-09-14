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
			ok = ok and accepted and r.cash==before.cash-quote.fee and r.action_points==before.action_points-1 and r.vault==before.vault and r.scene_id==destination and r.completed==before.completed and r.variant_plan.table_seeds==before.variant_plan.table_seeds
		else:
			ok = ok and not accepted and Checkpoint.capture(r)==before
		var id: String = "transfer."+key
		if ok: hits[id] = {"test":"transfer_coverage_test.gd","reason":quote.reason,"accepted":accepted,"checks":"quote and actual command outcome; rejected command preserves full checkpoint"}
		else: failures.append(id); push_error(id)
	var expected: Array = catalog.transitions.filter(func(row): return str(row.id).begins_with("transfer.")).map(func(row): return row.id)
	for id in hits:
		if id not in expected: failures.append("Uncatalogued hit: "+id)
	var missing: Array = expected.filter(func(id): return not hits.has(id))
	var hashes := {}
	for file in DirAccess.get_files_at("res://three_d/rules"):
		if not (file.ends_with(".gd") or file.ends_with(".json")): continue
		hashes[file] = FileAccess.get_file_as_string("res://three_d/rules/"+file).sha256_text()
	var report := {"scope":"transfer subgraph only","source_sha256":hashes,"test_sha256":FileAccess.get_file_as_string("res://three_d/tests/transfer_coverage_test.gd").sha256_text(),"catalog_sha256":FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json").sha256_text(),"denominator":expected.size(),"numerator":hits.size(),"missing":missing,"failures":failures,"hits":hits,"overall_state_transition_coverage":null,"overall_status":"Other families not yet enumerated; no global percentage claimed."}
	FileAccess.open("res://../output/3d/transfer-coverage.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TRANSFER_COVERAGE covered=",hits.size()," total=",expected.size()," missing=",missing," failures=",failures)
	quit(0 if failures.is_empty() and missing.is_empty() else 1)
