extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Opponent = preload("res://three_d/rules/opponent.gd")
const SEEDS := [1, 17, 43, 79, 101, 137, 173, 211, 257, 307, 359, 419]
var failures: Array[String] = []
var results := []

func play(content: Dictionary, scene: String, site: String, seed_value: int, policy: String) -> void:
	var run := Run.new(content)
	run.start(run.revision, scene, seed_value)
	run.completed.assign(Run.Variants.TABLES.slice(0, Run.Variants.TABLES.find(site)))
	var table: RefCounted = run.enter_table(int(run.variant_plan.table_seeds[site]), run.revision, site)
	if table == null:
		failures.append("enter " + scene + "/" + site + "/" + str(seed_value))
		return
	var buy_in: int = table.state.tableDef.buyIn
	var actions := {"fold":0,"check":0,"call":0,"raise":0,"all-in":0}
	var steps := 0
	while table.state.status != "finished" and steps < 200:
		steps += 1
		if table.state.status == "hand_over":
			if not table.next_hand(table.revision):
				failures.append("next hand " + scene + "/" + site)
				return
		elif table.state.currentActorId.is_empty():
			if not table.advance(table.revision):
				failures.append("advance " + scene + "/" + site)
				return
		else:
			var id: String = table.state.currentActorId
			var actor: Dictionary = table.find_player(id)
			var legal: Dictionary = table.legal_actions(id)
			var action: String
			if id != "player":
				action = Opponent.choose(table.state, actor, legal, content.opponents[id], table.rng.next())
			else:
				action = "check" if legal.get("check", false) else ("call" if legal.get("call", false) else "all-in")
				if policy == "equity-guided":
					var others: int = table.state.players.filter(func(p): return p.id != id and not p.folded).size()
					var odds: float = Opponent.estimate_odds(actor.holeCards, table.state.community, others, table.state.seed + table.state.handNumber * 137 + table.state.turnCounter * 19, 35)
					if odds < 0.27 and legal.get("fold", false) and not legal.get("check", false): action = "fold"
					elif odds > 0.68 and legal.get("raise", false): action = "raise"
				actions[action] += 1
			if not table.act(id, action, table.revision):
				failures.append("action " + scene + "/" + site + "/" + str(seed_value) + "/" + policy)
				return
		var wealth: int = table.state.pot if table.state.status == "playing" else 0
		for player in table.state.players: wealth += int(player.stack)
		if wealth != buy_in * 3:
			failures.append("wealth " + scene + "/" + site + "/" + str(seed_value) + "/" + policy)
			return
	if table.state.status != "finished":
		failures.append("limit " + scene + "/" + site + "/" + str(seed_value) + "/" + policy)
		return
	results.append({"venue":scene,"table":site,"seed":seed_value,"policy":policy,"buyIn":buy_in,"playerNet":int(table.state.players[0].stack)-buy_in,"playerActions":actions,"steps":steps})

func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	for scene in Run.SCENE_NAMES:
		for site in Run.Variants.TABLES:
			for seed_value in SEEDS:
				for policy in ["passive", "equity-guided"]:
					play(content, scene, site, seed_value, policy)
	var report := {"seeds":SEEDS,"results":results,"failures":failures,"scope":"Twelve fixed seeds per venue/table and two deterministic player policies against production AI. Independent table-entry fixtures; not human skill, whole-evening survival, or win-rate balance evidence."}
	FileAccess.open("res://../output/3d/difficulty-probe.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("DIFFICULTY_PROBE results=", results.size(), " failed=", failures.size(), " failures=", failures)
	quit(0 if failures.is_empty() and results.size() == 384 else 1)
