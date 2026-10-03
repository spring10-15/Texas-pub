extends SceneTree
## CPU cost of unchanged production policies in complete legal table paths.
const Table = preload("res://three_d/rules/table.gd")
const Opponent = preload("res://three_d/rules/opponent.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var samples: Array = []
	var tables: Array = []
	for id in ["cargo-table", "ledger-cellar", "mirror-hall", "embers-table"]:
		var table := Table.new()
		table.start(content.tables[id], 301)
		var steps := 0
		while table.state.status != "finished" and steps < 300:
			steps += 1
			if table.state.status == "hand_over":
				if not table.next_hand(table.revision): failures.append("next hand: " + id)
			elif table.state.currentActorId.is_empty():
				if not table.advance(table.revision): failures.append("advance: " + id)
			else:
				var actor_id: String = table.state.currentActorId
				var legal: Dictionary = table.legal_actions(actor_id)
				var action: String
				if actor_id == "player":
					action = "check" if legal.check else ("call" if legal.call else "fold")
				else:
					var started := Time.get_ticks_usec()
					action = Opponent.choose(table.state, table.find_player(actor_id), legal, content.opponents[actor_id], table.rng.next())
					var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
					samples.append({"table": id, "actor": actor_id, "hand": table.state.handNumber, "street": table.state.street, "milliseconds": elapsed_ms, "action": action})
				if not table.act(actor_id, action, table.revision): failures.append("act: " + id + "/" + actor_id)
			await process_frame
		tables.append({"id":id,"steps":steps,"finished":table.state.status == "finished"})
		if table.state.status != "finished": failures.append("unfinished: " + id)
	var timings: Array = samples.map(func(row): return row.milliseconds)
	timings.sort()
	var report := {"scope":"Production Opponent.choose CPU wall time on this host in four legal table paths, seed 301, player checks/calls. Includes equity estimation, not rendering/GPU or target-device certification.","engine":Engine.get_version_info().string,"processor":OS.get_processor_name(),"seed":301,"samples":samples,"tables":tables,"failures":failures,"failed":failures.size(),"median_ms":timings[timings.size()/2],"p95_ms":timings[int(ceil(timings.size()*0.95))-1],"max_ms":timings[-1],"over_16_67_ms":timings.filter(func(value): return value > 16.67).size(),"source_sha256":{}}
	for path in ["rules/opponent.gd","rules/poker.gd","rules/table.gd","rules/content.json"]:
		report.source_sha256[path] = FileAccess.get_file_as_string("res://three_d/" + path).sha256_text()
	var output := "res://../output/3d/ai-perf-probe.json"
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report,"\t") + "\n")
	print("AI_PERF samples=",samples.size()," median_ms=",report.median_ms," p95_ms=",report.p95_ms," max_ms=",report.max_ms," failed=",failures.size())
	quit(0 if failures.is_empty() else 1)
