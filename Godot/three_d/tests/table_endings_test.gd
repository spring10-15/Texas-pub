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
		var t := Table.new()
		t.start(content.tables[table_id],7)
		for hand in range(1,int(content.tables[table_id].hands)+1):
			var pot: int = t.state.pot
			var winner: Dictionary = t.state.players[t.state.bigBlindSeat]
			var prior: int = winner.stack
			verify(t.act(t.state.currentActorId,"fold",t.revision),"First fold "+table_id)
			verify(t.act(t.state.currentActorId,"fold",t.revision),"Second fold "+table_id)
			verify(winner.stack == prior+pot and t.state.summary.awards == {winner.id:pot},"Fold winner receives exact pot "+table_id)
			var last: bool = hand == int(content.tables[table_id].hands)
			verify(t.state.status == ("finished" if last else "hand_over") and t.state.pendingConclusion == last and t.state.pendingNextHand == not last,"Hand limit decides conclusion "+table_id)
			if not last:
				verify(t.next_hand(t.revision) and t.state.players.all(func(p): return not p.folded),"Funded folded opponents return "+table_id)
		var finished := Checkpoint.capture(t)
		verify(not t.next_hand(t.revision) and Checkpoint.capture(t) == finished,"Finished table cannot restart "+table_id)
		# Isolate bankruptcy and single-funded-seat terminal conditions using a final all-in board.
		for player_wins in [false,true]:
			t = Table.new()
			t.start(content.tables[table_id],7)
			t.state.street = "river"
			t.state.currentActorId = ""
			t.state.toAct = []
			t.state.community = [{"rank":2,"suit":"S"},{"rank":4,"suit":"H"},{"rank":7,"suit":"D"},{"rank":9,"suit":"C"},{"rank":11,"suit":"S"}]
			t.state.pot = int(content.tables[table_id].buyIn)*3
			for i in range(3):
				var p: Dictionary = t.state.players[i]
				var rank_value: int = [14,13,12][i] if player_wins else [13,14,12][i]
				p.holeCards = [{"rank":rank_value,"suit":"H"},{"rank":rank_value,"suit":"D"}]
				p.stack = 0
				p.handContribution = int(content.tables[table_id].buyIn)
			verify(t.advance(t.revision) and t.state.status == "finished" and t.state.pendingConclusion and not t.state.pendingNextHand,"All-in terminal condition "+table_id+str(player_wins))
			verify(t.state.players[0].stack == (int(content.tables[table_id].buyIn)*3 if player_wins else 0),"Terminal exact player wealth "+table_id)
	print("TABLE_ENDINGS checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
