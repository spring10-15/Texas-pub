extends SceneTree
const Table = preload("res://three_d/rules/table.gd")
var failures: Array[String] = []
var checks := 0
func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	for table_id in content.tables:
		for exact in [false,true]:
			var t := Table.new()
			t.start(content.tables[table_id],7)
			var p: Dictionary = t.state.players[0]
			var amount: int = t.state.currentBet-(0 if exact else 1)
			t.state.players[1].stack += p.stack-amount
			p.stack = amount
			var target: int = t.state.currentBet
			var pot: int = t.state.pot
			verify(t.act("player","call" if exact else "all-in",t.revision) and p.stack == 0 and t.state.currentBet == target and t.state.pot == pot+amount,"Short/exact contribution "+table_id+str(exact))
			verify(t.state.toAct == [t.state.players[1].id,t.state.players[2].id] and not t.state.raiseUsed,"Short/exact preserves remaining queue "+table_id)
		var t := Table.new()
		t.start(content.tables[table_id],7)
		t.act("player","call",t.revision)
		var raiser: String = t.state.currentActorId
		verify(t.act(raiser,"raise",t.revision) and t.state.toAct == [t.state.players[2].id,"player"],"Raise recalls prior caller "+table_id)
		t.act(t.state.currentActorId,"call",t.revision)
		verify(t.state.currentActorId == "player","Original caller owes new amount "+table_id)
		t.act("player","call",t.revision)
		verify(t.state.currentActorId.is_empty() and t.state.toAct.is_empty(),"Matched round ends "+table_id)
		# Preserve total wealth while moving chips into the player's stack before posting blinds.
		t = Table.new()
		t.start(content.tables[table_id],7)
		var buy_in: int = content.tables[table_id].buyIn
		t.state.players[0].stack = buy_in*2
		t.state.players[1].stack = buy_in/2
		t.state.players[2].stack = buy_in-buy_in/2
		t.start_hand()
		t.act("player","call",t.revision)
		t.act(t.state.currentActorId,"all-in",t.revision)
		t.act(t.state.currentActorId,"all-in",t.revision)
		verify(t.state.currentActorId == "player" and t.state.toAct == ["player"],"Lone funded player still owes call "+table_id)
		t.act("player","call",t.revision)
		verify(t.state.players[0].stack > 0 and t.state.toAct.is_empty(),"Lone funded matched player skips betting "+table_id)
		for street in ["flop","turn","river"]:
			verify(t.advance(t.revision) and t.state.street == street and t.state.toAct.is_empty(),"All-in board runs out "+table_id+street)
		verify(t.advance(t.revision) and t.state.summary.kind == "showdown","Runout reaches showdown "+table_id)
		var total := 0
		for p in t.state.players: total += int(p.stack)
		verify(total == buy_in*3,"Runout wealth conserved "+table_id)
	print("SHORT_STACK_QUEUE checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
