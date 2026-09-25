extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Opponent = preload("res://three_d/rules/opponent.gd")
const Checkpoint = preload("res://three_d/rules/run_checkpoint.gd")
var failures: Array[String] = []
var checks := 0
var completed := {}
var ai_actions := {}
var ai_actions_by_actor := {}
var ai_table_appearances := {}
var ai_decisions := 0
var matched_samples := 0
var matched_samples_by_actor := {}
var matched_policy_differences := {}
var matched_contexts := []
var varied_repeated_raise_differences := {}
var varied_repeated_raise_contexts := []
var varied_player_actions := {}
var stale_bet_handover_restores := 0
var varied_seed_samples := {}
func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func play(content: Dictionary, scene: String, site: String, actor: String, seed_value: int, live_ai := false, varied_player := false) -> void:
	var key := ("ai-varied:"+str(seed_value)+":" if live_ai and varied_player else ("ai:" if live_ai else "controlled:"))+scene+":"+site+":"+actor
	var r := Run.new(content)
	r.start(r.revision,scene,seed_value)
	# Prior-room unlock fixture. The table, its hands, settlement and exit use public commands.
	r.completed.assign(Run.Variants.TABLES.slice(0,Run.Variants.TABLES.find(site)))
	var wealth_before_table: int = r.vault + r.cash + r.valuable_total()
	var t: RefCounted = r.enter_table(int(r.variant_plan.table_seeds[site]),r.revision,site)
	verify(t != null,"Table enters "+key)
	if t == null: return
	verify(t.find_player(actor).id == actor,"Target opponent is seated "+key)
	if live_ai and not varied_player:
		for player in t.state.players.slice(1):
			var actor_id: String = player.id
			ai_table_appearances[actor_id] = int(ai_table_appearances.get(actor_id, 0)) + 1
	var cash_after_buy: int = r.cash
	var buy_in: int = t.state.tableDef.buyIn
	var player_action_rng := RandomNumberGenerator.new()
	player_action_rng.seed = absi(seed_value * 1009 + scene.hash() + site.hash() + actor.hash()) + 1
	var showdowns := 0
	var steps := 0
	var sampled_varied_raise_context := false
	while t.state.status != "finished" and steps < 200:
		steps += 1
		if t.state.status == "hand_over":
			var saved := Checkpoint.capture(r)
			var saved_table: Dictionary = saved.table.state
			var highest_current_bet := 0
			for player in saved_table.players:
				highest_current_bet = maxi(highest_current_bet, int(player.currentBet))
			if highest_current_bet != saved_table.currentBet:
				stale_bet_handover_restores += 1
			r = Checkpoint.restore(saved,content)
			verify(r != null,"Between-hand save restores "+key)
			if r == null: return
			verify(Checkpoint.capture(r) == saved,"Between-hand save preserves the full snapshot "+key)
			t = r.table
			verify(t.next_hand(t.revision),"Next hand accepted "+key)
		elif t.state.currentActorId.is_empty():
			verify(t.advance(t.revision),"Street advances "+key)
			if t.state.status in ["hand_over","finished"]:
				if not live_ai: verify(t.state.summary.kind == "showdown","Hand reaches showdown "+key)
				if t.state.summary.kind == "showdown": showdowns += 1
		else:
			var id: String = t.state.currentActorId
			var legal: Dictionary = t.legal_actions(id)
			var decision: String = "check" if legal.get("check",false) else ("call" if legal.get("call",false) else "all-in")
			if id == "player" and varied_player:
				var options: Array[String] = []
				for candidate in ["fold", "check", "call", "raise", "all-in"]:
					var legal_key: String = "allIn" if candidate == "all-in" else candidate
					if legal.get(legal_key, false): options.append(candidate)
				decision = options[player_action_rng.randi_range(0, options.size() - 1)]
				varied_player_actions[decision] = int(varied_player_actions.get(decision, 0)) + 1
			if live_ai and id != "player":
				var player: Dictionary = t.find_player(id)
				var random_value: float = t.rng.next()
				decision = Opponent.choose(t.state,player,legal,content.opponents[id],random_value)
				if varied_player and not sampled_varied_raise_context and t.state.playerPattern.raiseCount >= 2:
					sampled_varied_raise_context = true
					var active_opponents: int = t.state.players.filter(func(p): return p.id != id and not p.folded).size()
					var odds: float = Opponent.estimate_odds(player.holeCards,t.state.community,active_opponents,t.state.seed+t.state.handNumber*137+t.state.turnCounter*19+player.seatIndex*11)
					var profiles: Array = content.opponents.keys()
					profiles.sort()
					var choices := {}
					for profile_id in profiles:
						choices[profile_id] = Opponent.choose_with_odds(t.state,player,legal,content.opponents[profile_id],random_value,odds)
					var context := {"venue":scene,"table":site,"seed":seed_value,"actor":id,"street":t.state.street,"hand":t.state.handNumber,"totalHands":t.state.totalHands,"playerRaises":t.state.playerPattern.raiseCount,"bet":t.state.currentBet,"stack":player.stack,"buyIn":t.state.tableDef.buyIn,"openBet":t.state.tableDef.openBet,"odds":odds,"randomValue":random_value,"legal":legal.duplicate(),"choices":choices}
					varied_repeated_raise_contexts.append(context)
					for left in range(profiles.size()):
						for right in range(left+1,profiles.size()):
							var pair: String = profiles[left]+"/"+profiles[right]
							if choices[profiles[left]] != choices[profiles[right]]:
								varied_repeated_raise_differences[pair] = int(varied_repeated_raise_differences.get(pair,0))+1
				if not varied_player:
					ai_actions[decision] = int(ai_actions.get(decision,0))+1
					if not ai_actions_by_actor.has(id): ai_actions_by_actor[id] = {}
					ai_actions_by_actor[id][decision] = int(ai_actions_by_actor[id].get(decision,0))+1
					ai_decisions += 1
				if not varied_player and ai_decisions % 10 == 0:
					var opponents: int = t.state.players.filter(func(p): return p.id != id and not p.folded).size()
					var odds: float = Opponent.estimate_odds(player.holeCards,t.state.community,opponents,t.state.seed+t.state.handNumber*137+t.state.turnCounter*19+player.seatIndex*11)
					var profiles: Array = content.opponents.keys()
					profiles.sort()
					var choices := {}
					for profile_id in profiles:
						choices[profile_id] = Opponent.choose_with_odds(t.state,player,legal,content.opponents[profile_id],random_value,odds)
					verify(choices[id] == decision,"Matched policy reproduces live decision "+key)
					matched_contexts.append({"actor":id,"street":t.state.street,"hand":t.state.handNumber,"totalHands":t.state.totalHands,"playerRaises":t.state.playerPattern.raiseCount,"bet":t.state.currentBet,"stack":player.stack,"odds":snappedf(odds,0.01),"randomValue":snappedf(random_value,0.001),"legal":legal.duplicate(),"choices":choices})
					for left in range(profiles.size()):
						for right in range(left+1,profiles.size()):
							var pair: String = profiles[left]+"/"+profiles[right]
							if choices[profiles[left]] != choices[profiles[right]]:
								matched_policy_differences[pair] = int(matched_policy_differences.get(pair,0))+1
					matched_samples += 1
					matched_samples_by_actor[id] = int(matched_samples_by_actor.get(id,0))+1
			verify(t.act(id,decision,t.revision),"Decision accepted "+key)
		var wealth: int = t.state.pot if t.state.status == "playing" else 0
		for player in t.state.players: wealth += int(player.stack)
		verify(wealth == buy_in*3,"Every action conserves table wealth "+key)
	verify(steps < 200 and t.state.status == "finished" and (live_ai or showdowns == int(t.state.totalHands)),"Table completes "+key)
	var returned: int = t.state.players[0].stack
	verify(r.settle_table(r.revision) and r.cash == cash_after_buy+returned,"Settlement returns exactly remaining chips "+key)
	var reward_value: int = int(content.items[r.last_table_result.reward].value) if r.last_table_result.reward_added else 0
	var wealth_after_settlement: int = wealth_before_table + returned - buy_in + reward_value
	verify(r.vault + r.cash + r.valuable_total() == wealth_after_settlement,"Independent vault/cash/valuable ledger balances after reward "+key)
	var after := Checkpoint.capture(r)
	verify(not r.settle_table(r.revision) and Checkpoint.capture(r) == after,"No duplicate settlement "+key)
	r.discover_exit()
	var quote: Dictionary = r.extraction_quote()
	var vault: int = r.vault
	var expected_final_vault: int = wealth_after_settlement - int(quote.fee) - int(quote.lostCash) - int(quote.lostGoods)
	verify(quote.reason.is_empty() and r.extract(r.revision) and r.vault == vault+int(quote.net) and r.vault == expected_final_vault and r.cash == 0 and r.inventory.is_empty(),"Independent ledger balances after ordinary extraction "+key)
	completed[key] = {"seed":seed_value,"showdowns":showdowns,"steps":steps,"buyIn":buy_in,"playerChips":returned,"playerNet":returned-buy_in,"targetChips":t.find_player(actor).stack}
func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	for scene in Run.SCENE_NAMES:
		for seed_value in range(1,101):
			var r := Run.new(content)
			r.start(r.revision,scene,seed_value)
			for site in Run.Variants.TABLES:
				for actor in r.table_definition(site).opponentIds:
					for live_ai in [false,true]:
						var key: String = ("ai:" if live_ai else "controlled:")+scene+":"+site+":"+actor
						if not completed.has(key): play(content,scene,site,actor,seed_value,live_ai)
					var varied_base_key: String = scene+":"+site+":"+actor
					if int(varied_seed_samples.get(varied_base_key,0)) < 3:
						var varied_key: String = "ai-varied:"+str(seed_value)+":"+varied_base_key
						if not completed.has(varied_key):
							play(content,scene,site,actor,seed_value,true,true)
							varied_seed_samples[varied_base_key] = int(varied_seed_samples.get(varied_base_key,0)) + 1
	verify(completed.size() == 640 and varied_seed_samples.size() == 128 and varied_seed_samples.values().all(func(count): return count == 3),"Two baseline policies plus three varied-player seeds for each venue/table/opponent combination")
	verify(varied_player_actions.get("raise",0) > 0 and varied_player_actions.get("fold",0) > 0 and varied_player_actions.get("all-in",0) > 0,"Varied player policy reaches raises, folds and all-ins")
	verify(stale_bet_handover_restores > 0,"Fold-ended hand with stale street bet restores exactly")
	var report := {"checks":checks,"failed":failures.size(),"failures":failures,"combinations":completed,"ai_actions":ai_actions,"ai_actions_by_actor":ai_actions_by_actor,"ai_table_appearances":ai_table_appearances,"varied_player_actions":varied_player_actions,"varied_seed_samples":varied_seed_samples,"stale_bet_handover_restores":stale_bet_handover_restores,"matched_samples":matched_samples,"matched_samples_by_actor":matched_samples_by_actor,"matched_policy_differences":matched_policy_differences,"matched_contexts":matched_contexts,"varied_repeated_raise_contexts":varied_repeated_raise_contexts,"varied_repeated_raise_differences":varied_repeated_raise_differences,"scope":"Controlled check/call and production opponent AI each use one baseline seed for each venue/table/opponent combination; production AI against a deterministic varied legal player policy uses three distinct seeds for every venue/table/opponent combination. All policies check exact full-state restoration at between-hand saves, per-action table chip conservation, independent run wealth after settlement rewards, and final extraction ledger. Varied-player runs record the first real AI response after at least two player raises and compare all profiles on identical state and randomness. These strategy comparisons do not establish human recognition or balanced difficulty."}
	FileAccess.open("res://../output/3d/roster-showdown.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ROSTER_SHOWDOWN ",JSON.stringify({"checks":checks,"failed":failures.size(),"failures":failures,"combinations":completed.size()}))
	quit(0 if failures.is_empty() else 1)
