extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Checkpoint = preload("res://three_d/rules/run_checkpoint.gd")
var content: Dictionary
var hits := {}
var failures: Array[String] = []
func record(id: String, ok: bool) -> void:
	if ok: hits[id] = {"test":"lifecycle_coverage_test.gd","postcondition_verified":true}
	else: failures.append(id); push_error(id)
func fresh() -> RefCounted:
	var r := Run.new(content)
	r.start(r.revision,"smoky-den",0)
	return r
func _initialize() -> void:
	content = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	for case in ["success","partial_bankroll","stale","active","low_vault","unknown_venue"]:
		var r := Run.new(content)
		if case=="active": r.start(r.revision)
		if case=="low_vault": r.vault = 119
		if case=="partial_bankroll": r.vault = 120
		var before := Checkpoint.capture(r)
		var accepted: bool = r.start(r.revision-1 if case=="stale" else r.revision,"unknown" if case=="unknown_venue" else "smoky-den")
		var ok: bool
		if case=="success":
			ok = accepted and r.vault+r.cash==before.vault and r.cash==300 and r.bankroll==300 and r.active and r.revision==before.revision+1
		elif case=="partial_bankroll":
			ok = accepted and r.vault==0 and r.cash==120 and r.bankroll==120 and r.cash+r.vault==before.vault and r.active and r.revision==before.revision+1
		else:
			ok = not accepted and Checkpoint.capture(r)==before
		record("start."+case,ok)
	for case in ["success","stale","active","sufficient_funds"]:
		var r := Run.new(content)
		r.vault = 119
		if case=="active": r.active = true
		if case=="sufficient_funds": r.vault = 120
		var before := Checkpoint.capture(r)
		var accepted: bool = r.reset_demo(r.revision-1 if case=="stale" else r.revision)
		record("reset."+case,accepted and r.vault==int(content.startingVault) and r.revision==before.revision+1 if case=="success" else not accepted and Checkpoint.capture(r)==before)
	for case in ["success","inactive","table_active","already_known"]:
		var r := fresh()
		if case=="inactive": r.active = false
		if case=="table_active": r.enter_table(1,r.revision)
		if case=="already_known": r.discover_exit()
		var before := Checkpoint.capture(r)
		var accepted: bool = r.discover_exit()
		var expected := before.duplicate(true)
		expected.public_exit = true
		expected.revision += 1
		record("discover."+case,accepted and Checkpoint.capture(r)==expected if case=="success" else not accepted and Checkpoint.capture(r)==before)
	for route in Run.Routes.NAMES:
		var r := fresh()
		r.public_exit = true
		r.inventory.append("ivory-chip")
		r.route_flags = {"service-stairs":true,"river-launch":true}
		r.reservation = r.route_offer().duplicate(true)
		r.reservation.expiresAfterSearch = 3
		var before := Checkpoint.capture(r)
		var quote: Dictionary = r.extraction_quote(route)
		var accepted: bool = r.extract(r.revision,route)
		var after := Checkpoint.capture(r)
		var value: int = content.items["ivory-chip"].value
		var ok: bool = accepted and r.vault==before.vault+quote.net and before.cash+value==quote.net+quote.fee+quote.lostCash+quote.lostGoods and r.cash==0 and r.inventory.is_empty() and not r.active and r.last_result.profit==quote.net-before.bankroll
		ok = ok and not r.extract(r.revision,route) and Checkpoint.capture(r)==after
		record("extract."+route,ok)
	for case in ["stale","rejected_quote"]:
		var r := fresh()
		if case=="stale": r.public_exit = true
		var before := Checkpoint.capture(r)
		record("extract."+case,not r.extract(r.revision-1 if case=="stale" else r.revision) and Checkpoint.capture(r)==before)
	for case in ["success","wallet","stale","inactive","table_active"]:
		var r := fresh()
		r.inventory.append("ivory-chip")
		if case=="wallet": r.inventory.append("false-bottom-wallet")
		if case=="inactive": r.active = false
		if case=="table_active": r.enter_table(1,r.revision)
		var before := Checkpoint.capture(r)
		var accepted: bool = r.abandon(r.revision-1 if case=="stale" else r.revision)
		var salvage := 80 if case=="wallet" else 0
		var ok: bool = accepted and r.vault==before.vault+salvage and r.cash==0 and r.inventory.is_empty() and not r.active and r.last_result.net==salvage and r.last_result.valuables==int(content.items["ivory-chip"].value) if case in ["success","wallet"] else not accepted and Checkpoint.capture(r)==before
		record("abandon."+case,ok)
	for case in ["below_limit","inactive","table_active","extract","abandon"]:
		var r := fresh()
		r.heat = 6
		if case=="below_limit": r.heat = 5
		if case=="inactive": r.active = false
		if case=="table_active": r.enter_table(1,r.revision)
		if case=="abandon": r.cash = 9
		var before := Checkpoint.capture(r)
		# Only dropbag-cash is affordable/eligible in the extraction fixture: 10 fee and 120 discarded.
		var accepted: bool = r.enforce_pressure()
		var net := 170 if case=="extract" else 0
		var ok: bool = accepted and not r.active and r.cash==0 and r.vault==before.vault+net and r.last_result.forced and r.last_result.net==net if case in ["extract","abandon"] else not accepted and Checkpoint.capture(r)==before
		record("pressure."+case,ok)
	var catalog_text := FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json")
	var catalog: Dictionary = JSON.parse_string(catalog_text)
	var prefixes := ["start","reset","discover","extract","abandon","pressure"]
	var expected: Array = catalog.transitions.filter(func(row): return str(row.id).get_slice(".",0) in prefixes).map(func(row): return row.id)
	var missing: Array = expected.filter(func(id): return not hits.has(id))
	for id in hits:
		if id not in expected: failures.append("Uncatalogued "+id)
	var hashes := {}
	for file in DirAccess.get_files_at("res://three_d/rules"):
		if not (file.ends_with(".gd") or file.ends_with(".json")): continue
		hashes[file] = FileAccess.get_file_as_string("res://three_d/rules/"+file).sha256_text()
	var report := {"scope":"Six lifecycle entry points, not entire game","source_sha256":hashes,"test_sha256":FileAccess.get_file_as_string("res://three_d/tests/lifecycle_coverage_test.gd").sha256_text(),"catalog_sha256":catalog_text.sha256_text(),"numerator":hits.size(),"denominator":expected.size(),"hits":hits,"missing":missing,"failures":failures,"overall_state_transition_coverage":null}
	FileAccess.open("res://../output/3d/lifecycle-coverage.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("LIFECYCLE_COVERAGE covered=",hits.size()," total=",expected.size()," missing=",missing," failures=",failures)
	quit(0 if missing.is_empty() and failures.is_empty() else 1)
