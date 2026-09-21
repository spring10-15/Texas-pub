extends SceneTree
const Table = preload("res://three_d/rules/table.gd")
const Checkpoint = preload("res://three_d/rules/table_checkpoint.gd")
var failures: Array[String] = []
var checks := 0
func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	for table_id in content.tables:
		for busted in [1,2]:
			var t := Table.new()
			var definition: Dictionary = content.tables[table_id].duplicate(true)
			definition.hands = 4
			t.start(definition,7)
			var funded: int = 2 if busted == 1 else 1
			var buy_in: int = definition.buyIn
			# Initial distribution fixture; all later hands use public actions.
			t.state.players[0].stack = buy_in
			t.state.players[funded].stack = buy_in*2
			t.state.players[busted].stack = 0
			t.start_hand()
			for hand in range(4):
				var label: String = table_id+"/busted="+str(busted)+"/hand="+str(hand+1)
				var dealer: int = 0 if hand%2 == 0 else funded
				var big: int = funded if dealer == 0 else 0
				verify(t.state.dealerSeat == dealer and t.state.smallBlindSeat == dealer and t.state.bigBlindSeat == big,"Alternating blinds "+label)
				verify(t.state.currentActorId == t.state.players[dealer].id,"Dealer acts first preflop "+label)
				verify(t.state.players[busted].holeCards.is_empty() and t.state.players[busted].folded,"Busted seat excluded "+label)
				verify(t.act(t.state.currentActorId,"call",t.revision),"Dealer completes small blind "+label)
				verify(t.act(t.state.currentActorId,"check",t.revision),"Big blind checks preflop "+label)
				verify(t.advance(t.revision) and t.state.street == "flop" and t.state.currentActorId == t.state.players[big].id,"Nondealer acts first postflop "+label)
				verify(t.act(t.state.currentActorId,"fold",t.revision),"Hand completes by fold "+label)
				var total := 0
				for player in t.state.players: total += int(player.stack)
				verify(total == buy_in*3,"Wealth conserved "+label)
				if hand < 3:
					# Resume each inter-hand checkpoint before rotating the button.
					var saved := Checkpoint.capture(t)
					t = Checkpoint.restore(saved)
					verify(t != null,"Checkpoint restores "+label)
					if t == null: quit(1); return
					verify(t.next_hand(t.revision),"Next hand accepted "+label)
	print("DEALER_ROTATION checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
