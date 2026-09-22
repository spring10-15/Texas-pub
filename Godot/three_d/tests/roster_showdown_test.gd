extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Checkpoint = preload("res://three_d/rules/run_checkpoint.gd")
var failures: Array[String] = []
var checks := 0
var completed := {}
func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func play(content: Dictionary, scene: String, site: String, actor: String, seed_value: int) -> void:
	var key := scene+":"+site+":"+actor
	var r := Run.new(content)
	r.start(r.revision,scene,seed_value)
	# Prior-room unlock fixture. The table, its hands, settlement and exit use public commands.
	r.completed.assign(Run.Variants.TABLES.slice(0,Run.Variants.TABLES.find(site)))
	var t: RefCounted = r.enter_table(int(r.variant_plan.table_seeds[site]),r.revision,site)
	verify(t != null,"Table enters "+key)
	if t == null: return
	verify(t.find_player(actor).id == actor,"Target opponent is seated "+key)
	var cash_after_buy: int = r.cash
	var buy_in: int = t.state.tableDef.buyIn
	var showdowns := 0
	var steps := 0
	while t.state.status != "finished" and steps < 200:
		steps += 1
		if t.state.status == "hand_over":
			var saved := Checkpoint.capture(r)
			r = Checkpoint.restore(saved,content)
			verify(r != null,"Between-hand save restores "+key)
			if r == null: return
			t = r.table
			verify(t.next_hand(t.revision),"Next hand accepted "+key)
		elif t.state.currentActorId.is_empty():
			verify(t.advance(t.revision),"Street advances "+key)
			if t.state.status in ["hand_over","finished"]:
				verify(t.state.summary.kind == "showdown","Hand reaches showdown "+key)
				showdowns += 1
		else:
			var id: String = t.state.currentActorId
			var legal: Dictionary = t.legal_actions(id)
			verify(t.act(id,"check" if legal.get("check",false) else ("call" if legal.get("call",false) else "all-in"),t.revision),"Legal non-fold action "+key)
		var wealth: int = t.state.pot if t.state.status == "playing" else 0
		for player in t.state.players: wealth += int(player.stack)
		verify(wealth == buy_in*3,"Every action conserves table wealth "+key)
	verify(steps < 200 and t.state.status == "finished" and showdowns == int(t.state.totalHands),"Every configured hand completes "+key)
	var returned: int = t.state.players[0].stack
	verify(r.settle_table(r.revision) and r.cash == cash_after_buy+returned,"Settlement returns exactly remaining chips "+key)
	var after := Checkpoint.capture(r)
	verify(not r.settle_table(r.revision) and Checkpoint.capture(r) == after,"No duplicate settlement "+key)
	r.discover_exit()
	var quote: Dictionary = r.extraction_quote()
	var vault: int = r.vault
	verify(quote.reason.is_empty() and r.extract(r.revision) and r.vault == vault+int(quote.net) and r.cash == 0 and r.inventory.is_empty(),"Ordinary exit banks the quoted amount once "+key)
	completed[key] = {"seed":seed_value,"hands":showdowns,"steps":steps}
func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	for scene in Run.SCENE_NAMES:
		for seed_value in range(1,101):
			var r := Run.new(content)
			r.start(r.revision,scene,seed_value)
			for site in Run.Variants.TABLES:
				for actor in r.table_definition(site).opponentIds:
					if not completed.has(scene+":"+site+":"+actor): play(content,scene,site,actor,seed_value)
	verify(completed.size() == 128,"Four venues x four tables x eight opponents")
	var report := {"checks":checks,"failed":failures.size(),"failures":failures,"combinations":completed,"scope":"Controlled check/call policies through showdown, save, settlement and extraction; prior unlocks are fixtures, not full evening or live AI balance evidence."}
	FileAccess.open("res://../output/3d/roster-showdown.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ROSTER_SHOWDOWN ",JSON.stringify({"checks":checks,"failed":failures.size(),"failures":failures,"combinations":completed.size()}))
	quit(0 if failures.is_empty() else 1)
