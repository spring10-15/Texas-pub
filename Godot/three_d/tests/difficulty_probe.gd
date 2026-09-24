extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Opponent = preload("res://three_d/rules/opponent.gd")
const SEEDS := [1, 17, 43, 79, 101, 137, 173, 211, 257, 307, 359, 419]
var failures: Array[String] = []
var results := []
var repeated_raise_contexts := []

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
				var random_value: float = table.rng.next()
				action = Opponent.choose(table.state, actor, legal, content.opponents[id], random_value)
				if policy == "pressure-raiser" and table.state.playerPattern.raiseCount >= 2:
					var others: int = table.state.players.filter(func(p): return p.id != id and not p.folded).size()
					var odds: float = Opponent.estimate_odds(actor.holeCards, table.state.community, others, table.state.seed + table.state.handNumber * 137 + table.state.turnCounter * 19 + actor.seatIndex * 11)
					var choices := {}
					for profile_id in content.opponents:
						choices[profile_id] = Opponent.choose_with_odds(table.state, actor, legal, content.opponents[profile_id], random_value, odds)
					if choices[id] != action: failures.append("counterfactual " + scene + "/" + site + "/" + str(seed_value))
					repeated_raise_contexts.append({"venue":scene,"table":site,"seed":seed_value,"actor":id,"street":table.state.street,"hand":table.state.handNumber,"playerRaises":table.state.playerPattern.raiseCount,"odds":snappedf(odds,0.01),"bet":table.state.currentBet,"legal":legal.duplicate(),"choices":choices})
			else:
				action = "check" if legal.get("check", false) else ("call" if legal.get("call", false) else "all-in")
				if policy in ["equity-guided", "pressure-raiser"]:
					var others: int = table.state.players.filter(func(p): return p.id != id and not p.folded).size()
					var odds: float = Opponent.estimate_odds(actor.holeCards, table.state.community, others, table.state.seed + table.state.handNumber * 137 + table.state.turnCounter * 19, 35)
					var fold_below: float = 0.2 if policy == "pressure-raiser" else 0.27
					var raise_above: float = 0.4 if policy == "pressure-raiser" else 0.68
					if odds < fold_below and legal.get("fold", false) and not legal.get("check", false): action = "fold"
					elif odds > raise_above and legal.get("raise", false): action = "raise"
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
				if seed_value in SEEDS.slice(0, 4):
					play(content, scene, site, seed_value, "pressure-raiser")
	var report := {"seeds":SEEDS,"results":results,"repeatedRaiseContexts":repeated_raise_contexts,"failures":failures,"scope":"Twelve fixed seeds per venue/table for passive and equity-guided players, plus the first four seeds for a raise-heavy diagnostic player, against production AI. Repeated-raise contexts compare all eight opponent policies on identical information. Independent table-entry fixtures; not human skill, whole-evening survival, or win-rate balance evidence."}
	FileAccess.open("res://../output/3d/difficulty-probe.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("DIFFICULTY_PROBE results=", results.size(), " failed=", failures.size(), " failures=", failures)
	quit(0 if failures.is_empty() and results.size() == 448 else 1)
