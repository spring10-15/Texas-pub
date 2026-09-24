extends SceneTree
const Opponent = preload("res://three_d/rules/opponent.gd")
var checks := 0
var failures: Array[String] = []
func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var royal := [{"rank":10,"suit":"H"},{"rank":11,"suit":"H"},{"rank":12,"suit":"H"},{"rank":13,"suit":"H"},{"rank":14,"suit":"H"}]
	var hole := [{"rank":2,"suit":"C"},{"rank":3,"suit":"D"}]
	verify(is_equal_approx(Opponent.estimate_odds(hole,royal,2,44,10),1.0/3.0), "Three-way tied board has one-third equity")
	verify(is_equal_approx(Opponent.estimate_odds(hole,royal,1,44,10),.5), "Heads-up tied board has half equity")
	var live_actor := {"id":"ai","seatIndex":1,"stack":60,"folded":false,"holeCards":hole}
	var live_table := {"players":[live_actor,{"id":"player","folded":false,"holeCards":[]},{"id":"other","folded":false,"holeCards":[]}],"community":royal,"seed":44,"turnCounter":1,"tableDef":{"buyIn":120,"openBet":40},"street":"river","handNumber":1,"totalHands":3,"currentBet":40,"playerPattern":{"raiseCount":0}}
	var live_legal := {"allIn":true,"raise":true,"call":true,"check":false,"fold":true}
	var definition: Dictionary = content.opponents["ledger-clerk"]
	var expected := Opponent.choose_with_odds(live_table,live_actor,live_legal,definition,.5,1.0/3.0)
	verify(Opponent.choose(live_table,live_actor,live_legal,definition,.5)==expected,"Live decision uses three-way equity")
	live_table.players[1].holeCards = [{"rank":14,"suit":"C"},{"rank":14,"suit":"D"}]
	verify(Opponent.choose(live_table,live_actor,live_legal,definition,.5)==expected,"Other private cards cannot change live decision")
	live_table.players[2].folded = true
	verify(Opponent.choose(live_table,live_actor,live_legal,definition,.5)==Opponent.choose_with_odds(live_table,live_actor,live_legal,definition,.5,.5),"Folded opponent excluded from equity")
	var cases := [
		{"id":"weak_free","odds":.20,"bet":0,"stack":100,"last":false,"repeats":0},
		{"id":"weak_pressure","odds":.20,"bet":40,"stack":60,"last":false,"repeats":0},
		{"id":"marginal_pressure","odds":.35,"bet":40,"stack":60,"last":false,"repeats":0},
		{"id":"strong_early","odds":.72,"bet":20,"stack":100,"last":false,"repeats":0},
		{"id":"strong_final","odds":.72,"bet":20,"stack":100,"last":true,"repeats":0},
		{"id":"pattern_baseline","odds":.52,"bet":0,"stack":200,"last":false,"repeats":0},
		{"id":"repeated_raises","odds":.52,"bet":0,"stack":200,"last":false,"repeats":8}]
	var distributions := {}
	var sampled_actions := {}
	for id in content.opponents:
		distributions[id] = {}
		sampled_actions[id] = []
		for fixture in cases:
			var table := {"tableDef":{"buyIn":120,"openBet":40},"street":"turn","handNumber":3 if fixture.last else 1,"totalHands":3,"currentBet":fixture.bet,"playerPattern":{"raiseCount":fixture.repeats}}
			var actor := {"stack":fixture.stack}
			var legal := {"allIn":true,"raise":true,"call":fixture.bet>0,"check":fixture.bet==0,"fold":true}
			var counts := {"raise":0,"all-in":0,"call":0,"check":0,"fold":0}
			for i in range(100):
				var action := Opponent.choose_with_odds(table,actor,legal,content.opponents[id],(i+.5)/100.0,fixture.odds)
				verify(legal.get("allIn" if action=="all-in" else action,false), "Policy emits legal action " + id)
				counts[action] += 1
				sampled_actions[id].append(action)
			distributions[id][fixture.id] = counts
	verify(distributions["dock-braggart"].weak_free.raise > distributions["ledger-clerk"].weak_free.raise, "Maniac bluffs more than nit under identical information")
	verify(distributions["smiling-knife"].strong_final["all-in"] > distributions["smiling-knife"].strong_early["all-in"], "Final hand increases knife pressure")
	verify(distributions["calm-widow"].repeated_raises.raise > distributions["calm-widow"].pattern_baseline.raise, "Widow responds to repeated player raises at identical equity")
	verify(distributions["velvet-rook"].weak_pressure.call > distributions["ash-smuggler"].weak_pressure.call, "Calling station continues with a weak draw under pressure")
	var value_table := {"tableDef":{"buyIn":120,"openBet":40},"street":"turn","handNumber":1,"totalHands":3,"currentBet":20,"playerPattern":{"raiseCount":0}}
	var value_actor := {"stack":200}
	var value_legal := {"allIn":true,"raise":true,"call":true,"check":false,"fold":true}
	verify(Opponent.choose_with_odds(value_table,value_actor,value_legal,content.opponents["house-viper"],.5,.65)=="raise", "Viper applies measured value pressure")
	verify(Opponent.choose_with_odds(value_table,value_actor,value_legal,content.opponents["river-shark"],.5,.65)=="call", "River shark waits for stronger value")
	verify(Opponent.choose_with_odds(value_table,value_actor,value_legal,content.opponents["smiling-knife"],.5,.65)=="call", "Knife coasts before final hand")
	value_table.handNumber = 3
	verify(Opponent.choose_with_odds(value_table,value_actor,value_legal,content.opponents["smiling-knife"],.5,.65)=="raise", "Knife presses on final hand")
	value_table.handNumber = 1
	verify(Opponent.choose_with_odds(value_table,value_actor,value_legal,content.opponents["calm-widow"],.5,.65)=="call", "Widow waits without a repeated raise pattern")
	value_table.playerPattern.raiseCount = 8
	verify(Opponent.choose_with_odds(value_table,value_actor,value_legal,content.opponents["calm-widow"],.5,.65)=="raise", "Widow punishes repeated raises")
	value_table.playerPattern.raiseCount = 2
	verify(Opponent.choose_with_odds(value_table,value_actor,value_legal,content.opponents["calm-widow"],.5,.52)=="raise", "Widow counters a repeated raise at marginal equity")
	verify(Opponent.choose_with_odds(value_table,value_actor,value_legal,content.opponents["house-viper"],.5,.52)=="call", "Viper does not copy the widow's repeated-raise counter")
	var pairwise_differences := {}
	var ids: Array = content.opponents.keys()
	ids.sort()
	for left in range(ids.size()):
		for right in range(left + 1, ids.size()):
			var differences := 0
			for sample in range(sampled_actions[ids[left]].size()):
				if sampled_actions[ids[left]][sample] != sampled_actions[ids[right]][sample]:
					differences += 1
			pairwise_differences[ids[left] + "/" + ids[right]] = differences
	var report := {"checks":checks,"failed":failures.size(),"failures":failures,"scope":"Conditional policy probe: 7 fixed public situations and equity inputs, 100 uniform random quantiles per opponent. Pairwise differences count distinct choices under the same input and random quantile. Not gameplay win rates or human recognizability evidence.","cases":cases,"distributions":distributions,"pairwiseDifferences":pairwise_differences}
	FileAccess.open("res://../output/3d/opponent-profiles.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("OPPONENT_PROFILES checks=",checks," failed=",failures.size()," failures=",failures)
	quit(0 if failures.is_empty() else 1)
