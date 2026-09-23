extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Checkpoint = preload("res://three_d/rules/run_checkpoint.gd")
var failures: Array[String] = []
var hits := {}
func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json"))
	# Finished-table fixtures isolate the settlement boundary; poker outcomes are tested separately.
	var cases := [["ivory", "cargo-table", 61, "ivory-chip"], ["lighter", "cargo-table", 89, "old-silver-lighter"], ["ruby", "cargo-table", 90, "ruby-cufflink"], ["emerald", "ledger-cellar", 129, "emerald-brooch"], ["pearl", "ledger-cellar", 130, "pearl-necklace"], ["watch", "mirror-hall", 169, "gold-cased-watch"], ["bond", "mirror-hall", 170, "sealed-bond"], ["antique", "mirror-hall", 121, "antique-coin"], ["idol", "embers-table", 219, "obsidian-idol"], ["promissory", "embers-table", 220, "vault-promissory"], ["break_even", "cargo-table", 60, ""], ["loss", "cargo-table", 0, ""], ["full_bag", "cargo-table", 61, "old-silver-lighter"], ["collateral_lost", "mirror-hall", 0, ""], ["collateral_tie", "mirror-hall", 120, ""], ["side_pot_only", "mirror-hall", 120, ""], ["legacy_award", "mirror-hall", 120, ""]]
	var observed_rewards := {}
	for row in cases:
		var key: String = row[0]
		var id: String = row[1]
		var stack: int = row[2]
		var reward: String = row[3]
		var r := Run.new(content)
		r.start(r.revision,"smoky-den",0)
		r.completed.assign(Run.Variants.TABLES.slice(0,Run.Variants.TABLES.find(id)))
		var pledged: bool = key in ["antique","collateral_lost","collateral_tie","side_pot_only","legacy_award"]
		if pledged or key in ["lighter","ruby"]: r.inventory.append("ivory-chip")
		if key == "full_bag": r.inventory.assign(["ivory-chip","ivory-chip","ivory-chip","ivory-chip","ivory-chip","ivory-chip"])
		r.enter_table(7,r.revision,id,"ivory-chip" if pledged else "")
		r.table.state.status = "finished"
		r.table.state.players[0].stack = stack
		r.table.state.summary = {"pots":[{"winnerIds":["player"]}]}
		if key == "collateral_lost": r.table.state.summary.pots[0].winnerIds = ["opponent"]
		if key == "collateral_tie": r.table.state.summary.pots[0].winnerIds = ["player","opponent"]
		if key == "side_pot_only": r.table.state.summary = {"pots":[{"winnerIds":["opponent"]},{"winnerIds":["player"]}]}
		if key == "legacy_award": r.table.state.summary = {"awards":{"player":10}}
		r.action_points = 0
		r.heat_reduced = true
		var before := Checkpoint.capture(r)
		var inventory := r.inventory.duplicate()
		var returned: bool = pledged and key not in ["collateral_lost","side_pot_only"]
		if returned: inventory.append("ivory-chip")
		var added: bool = not reward.is_empty() and key != "full_bag"
		if added: inventory.append(reward)
		var accepted: bool = r.settle_table(r.revision)
		var ok: bool = accepted and r.cash == before.cash+stack and r.vault == before.vault and r.inventory == inventory and r.collateral.is_empty() and r.table == null
		ok = ok and r.last_table_result == {"table":id,"net":stack-int(content.tables[id].buyIn),"collateral":"ivory-chip" if pledged else "","returned":returned,"reward":reward,"reward_added":added}
		ok = ok and r.heat == before.heat-(1 if id == "embers-table" and stack > 160 else 0) and r.action_points == 2 and not r.heat_reduced and r.public_exit and r.search_index == before.search_index+1 and r.revision == before.revision+1
		var completed: Array = before.completed.duplicate()
		completed.append(id)
		ok = ok and r.completed == completed
		if ok and not reward.is_empty():
			if not observed_rewards.has(id): observed_rewards[id] = []
			if reward not in observed_rewards[id]: observed_rewards[id].append(reward)
		var settled := Checkpoint.capture(r)
		ok = ok and not r.settle_table(r.revision) and Checkpoint.capture(r) == settled
		record(key,ok)
	for id in content.tables:
		var listed: Array = content.tables[id].baseRewardPool.duplicate()
		var observed: Array = observed_rewards.get(id, []).duplicate()
		listed.sort()
		observed.sort()
		if listed != observed:
			var mismatch := "Reward disclosure mismatch for %s: listed %s, settled %s" % [id, listed, observed]
			failures.append(mismatch)
			push_error(mismatch)
	for key in ["stale_revision","inactive","no_table","unfinished"]:
		var r := Run.new(content)
		r.start(r.revision,"smoky-den",0)
		if key != "no_table":
			r.enter_table(7,r.revision)
			if key != "unfinished": r.table.state.status = "finished"
		if key == "inactive": r.active = false
		var before := Checkpoint.capture(r)
		var accepted: bool = r.settle_table(r.revision-1 if key == "stale_revision" else r.revision)
		record(key,not accepted and Checkpoint.capture(r) == before)
	var expected: Array = catalog.transitions.filter(func(row): return str(row.id).begins_with("settlement.")).map(func(row): return row.id)
	for id in hits:
		if id not in expected: failures.append("Uncatalogued hit: "+id)
	var missing: Array = expected.filter(func(id): return not hits.has(id))
	var hashes := {}
	for file in DirAccess.get_files_at("res://three_d/rules"):
		if not (file.ends_with(".gd") or file.ends_with(".json")): continue
		hashes[file] = FileAccess.get_file_as_string("res://three_d/rules/"+file).sha256_text()
	var report := {"scope":"settlement subgraph only","source_sha256":hashes,"test_sha256":FileAccess.get_file_as_string("res://three_d/tests/settlement_coverage_test.gd").sha256_text(),"catalog_sha256":FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json").sha256_text(),"denominator":expected.size(),"numerator":hits.size(),"missing":missing,"failures":failures,"hits":hits,"overall_state_transition_coverage":null,"overall_status":"Other families not yet enumerated; no global percentage claimed."}
	FileAccess.open("res://../output/3d/settlement-coverage.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("SETTLEMENT_COVERAGE covered=",hits.size()," total=",expected.size()," missing=",missing," failures=",failures)
	quit(0 if failures.is_empty() and missing.is_empty() else 1)
func record(key: String, ok: bool) -> void:
	var id := "settlement."+key
	if ok: hits[id] = {"test":"settlement_coverage_test.gd","postcondition_verified":true}
	else: failures.append(id); push_error(id)
