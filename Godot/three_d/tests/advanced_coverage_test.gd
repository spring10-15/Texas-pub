extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Checkpoint = preload("res://three_d/rules/run_checkpoint.gd")
var failures: Array[String] = []
var hits := {}
func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json"))
	var cases := {
		"phone_route":["phone-route",""],"phone_table":["phone-table",""],"phone_rules_only":["phone-table",""],"kitchen":["pass",""],"dock":["pass",""],"notes":["notes",""],"notes_folded":["notes",""],"signal":["signal",""],
		"inactive":["phone-route","尚未出发"],"unowned":["phone-route","背包中没有对应物品"],"mismatch":["phone-route","背包中没有对应物品"],"table_active":["phone-route","请先结束牌桌并离座"],"no_actions":["phone-route","行动力不足"],"phone_unknown":["phone-table","请选择有效牌桌"],"phone_completed":["phone-table","该牌桌已完成，无需获取情报"],"phone_known":["phone-table","已知该桌全部情报"],"pass_invalid":["pass","不是路线通行证"],"pass_known":["pass","此路线已揭示"],"no_table":["signal","只能在进行中的牌桌使用"],"finished":["signal","只能在进行中的牌桌使用"],"target_unknown":["signal","请选一位有效对手"],"target_player":["signal","请选一位有效对手"],"target_folded":["signal","请选一位有效对手"],"signal_used":["signal","本桌已使用过信号打火机"],"notes_known":["notes","已记录这位对手的风格"],"stale_revision":["phone-route",""]}
	for key in cases:
		var r := Run.new(content)
		r.start(r.revision,"smoky-den",0)
		var kind: String = cases[key][0]
		var item: String = {"phone-route":"disposable-phone","phone-table":"disposable-phone","pass":"kitchen-pass","notes":"player-notes","signal":"signal-lighter"}[kind]
		if key == "dock": item = "dock-passkey"
		if key == "pass_invalid": item = "ivory-chip"
		r.inventory.append(item)
		var target := "mirror-hall"
		if kind in ["notes","signal"] or key == "table_active":
			r.enter_table(7,r.revision)
			target = r.table.state.players[1].id
		match key:
			"inactive": r.active = false
			"unowned": r.inventory.clear()
			"mismatch": item = "steadying-drink"
			"no_actions": r.action_points = 0
			"phone_unknown": target = "unknown"
			"phone_completed": r.completed.assign(["cargo-table","ledger-cellar","mirror-hall"])
			"phone_known": r.full_intel[target] = true
			"phone_rules_only": r.known_rules.append(target)
			"pass_known": r.route_flags["service-stairs"] = true
			"no_table": r.table = null
			"finished": r.table.state.status = "finished"
			"target_unknown": target = "unknown"
			"target_player": target = "player"
			"target_folded", "notes_folded": r.table.state.players[1].folded = true
			"signal_used": r.used_tools.append(item)
			"notes_known": r.opponent_notes[target] = content.opponents[target].archetype
		var before := Checkpoint.capture(r)
		var ok: bool = r.service_reason(kind,item,target) == cases[key][1] and Checkpoint.capture(r) == before
		var accepted: bool = r.service_action(kind,item,r.revision-1 if key == "stale_revision" else r.revision,target)
		if key in ["phone_route","phone_table","phone_rules_only","kitchen","dock","notes","notes_folded","signal"]:
			var expected := before.duplicate(true)
			expected.inventory.erase(item)
			expected.revision += 1
			expected.service_message = r.service_message
			if kind in ["notes","signal"]:
				expected.used_tools.append(item)
				expected.heat = mini(6,before.heat+int(content.items[item].heat))
				expected.table.revision += 1
				if kind == "notes": expected.opponent_notes[target] = content.opponents[target].archetype
				else: ok = ok and r.service_message in ["对手牌力：强（概率判断，不展示底牌）","对手牌力：中（概率判断，不展示底牌）","对手牌力：弱（概率判断，不展示底牌）"]
			else:
				expected.action_points -= 1
				if kind == "pass": expected.route_flags["river-launch" if key == "dock" else "service-stairs"] = true
				elif kind == "phone-route": expected.offer_index = 1; expected.route_flags.fixed = true
				else:
					expected.full_intel[target] = true
					if target not in expected.known_rules: expected.known_rules.append(target)
			ok = ok and accepted and not r.service_message.is_empty() and Checkpoint.capture(r) == expected
		else:
			ok = ok and not accepted and Checkpoint.capture(r) == before
		var id: String = "advanced."+key
		if ok: hits[id] = {"test":"advanced_coverage_test.gd","postcondition_verified":true}
		else: failures.append(id); push_error(id)
	var expected: Array = catalog.transitions.filter(func(row): return str(row.id).begins_with("advanced.")).map(func(row): return row.id)
	for id in hits:
		if id not in expected: failures.append("Uncatalogued hit: "+id)
	var missing: Array = expected.filter(func(id): return not hits.has(id))
	var hashes := {}
	for file in DirAccess.get_files_at("res://three_d/rules"):
		if not (file.ends_with(".gd") or file.ends_with(".json")): continue
		hashes[file] = FileAccess.get_file_as_string("res://three_d/rules/"+file).sha256_text()
	var report := {"scope":"advanced subgraph only","source_sha256":hashes,"test_sha256":FileAccess.get_file_as_string("res://three_d/tests/advanced_coverage_test.gd").sha256_text(),"catalog_sha256":FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json").sha256_text(),"denominator":expected.size(),"numerator":hits.size(),"missing":missing,"failures":failures,"hits":hits,"overall_state_transition_coverage":null,"overall_status":"Other families not yet enumerated; no global percentage claimed."}
	FileAccess.open("res://../output/3d/advanced-coverage.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ADVANCED_COVERAGE covered=",hits.size()," total=",expected.size()," missing=",missing," failures=",failures)
	quit(0 if failures.is_empty() and missing.is_empty() else 1)
