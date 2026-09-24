extends SceneTree
## A2-2 / L-1 单挑（及其余座位出局）庄位轮换诊断
##
## 目的：把 A 报告 L-1 线索变成可判断的证据，而不是"按手数取模推导正确结果"。
##
## 设计原则（对应 A2 任务书步骤 2）：
##   1. 夹具(FIXTURE) 与 行动路径(ACTION) 严格分开，逐行标注：
##      - FIXTURE：为了让某座位出局，直接写 state.players[i].stack。只用于建立初始局面。
##      - ACTION ：出局之后的每一手，全部通过 act/advance/next_hand 推进，不再直接改状态。
##   2. 预期值「按规则来源列出」，不按 handNumber % N 推导：
##      - table.gd:24-46 start_hand()：rotate_dealer 为真或当前庄家已 folded 时，庄家改为
##        ordered_after(dealer)[0]，即"庄家之后第一个有筹码且未弃牌的座位"。
##      - table.gd:184-189 next_hand()：调用 start_hand(true)，所以换手时必然轮换。
##      - table.gd:40-41 单挑（starters.size()==2）：庄家=小盲，另一人=大盲。
##      - table.gd:51 set_queue(ordered_after(bigBlindSeat))：翻前首行动者 = 大盲之后第一个 = 庄家。
##      - table.gd:169 advance() 里 set_queue(ordered_after(dealerSeat))：翻后首行动者 = 庄家之后 = 大盲。
##      - table.gd:31 start_hand() 守卫：funded<2 **或 state.players[0].stack<=0** → finished。
##        （注意 players[0] 被单独特判，即"玩家座位出局"直接结束这一局。）
##   3. 覆盖三种出局座位：1、2（任务书要求），外加 0（用于暴露上面的特判）。
##
## 运行：
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot \
##     --script "$PWD/docs/3d-production/external-handoff/A2-boundaries/repro/diag_dealer_rotation.gd" -- --test
const Table = preload("res://three_d/rules/table.gd")
const Checkpoint = preload("res://three_d/rules/table_checkpoint.gd")

var failures: Array[String] = []
var checks := 0
var hands_recorded := 0

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("  ASSERT-FAIL ", label)

func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	print("=== A2-2 庄位轮换诊断 (L-1) ===")
	print("规则来源：table.gd:24-46 start_hand / :184-189 next_hand / :40-51 盲注与首行动者 / :31 players[0] 特判")
	for fixture in ["deep", "shallow"]:
		for busted in [1, 2, 0]:
			run_case(content, fixture, busted)
	print("")
	print("DIAG_DEALER_ROTATION checks=", checks, " failures=", failures.size(), " 记录手数=", hands_recorded)
	if not failures.is_empty():
		print("FAILURES=", failures)
	quit(0 if failures.is_empty() else 1)

## 夹具：只负责建立"某座位无筹码"的初始局面，不参与轮换本身
func build_case(content: Dictionary, fixture: String, busted: int) -> RefCounted:
	var table_id := "cargo-table"
	var definition: Dictionary = content.tables[table_id].duplicate(true)
	definition.hands = 6
	var table := Table.new()
	table.start(definition, 7)
	var buy_in: int = int(definition.buyIn)
	# FIXTURE-START —— 以下三行只用于设定初始筹码，属于夹具，不属于行动路径
	var survivor_stack: int = buy_in * 20 if fixture == "deep" else buy_in * 2
	for i in range(table.state.players.size()):
		table.state.players[i].stack = survivor_stack
	table.state.players[busted].stack = 0
	# FIXTURE-END
	table.start_hand()   # FIXTURE 收尾：让 folded 标记按新筹码重算（rotate=false，不轮换）
	return table

func snapshot(table: RefCounted) -> String:
	return "dealer=%s small=%s big=%s firstPreflop=%s" % [
		table.state.dealerSeat, table.state.smallBlindSeat, table.state.bigBlindSeat,
		table.state.currentActorId,
	]

## 两个不同时点的守恒口径 —— 混用会假报不守恒：
##   in_play  ：刚发完盲注、手还在进行中 → sum(stacks) + pot 才是全桌财富
##   settled ：一手刚结束、底池已派发给赢家 → sum(stacks) 就是全桌财富
## 注意：state.pot 在手结束后**不清零**（finish_hand 只把 pot 复制进 summary），
## 所以在 settled 时点再加 pot 会把已派发的底池重复计入。
func wealth_in_play(table: RefCounted) -> int:
	var total := 0
	for player in table.state.players:
		total += int(player.stack)
	return total + int(table.state.pot)

func wealth_settled(table: RefCounted) -> int:
	var total := 0
	for player in table.state.players:
		total += int(player.stack)
	return total

## ACTION 路径：翻前由首行动者跟注、大盲过牌；翻后记录首行动者，再用被动策略打完这手
func play_hand(table: RefCounted) -> Dictionary:
	var out := {"preflop_first": table.state.currentActorId, "postflop_first": "", "steps": 0}
	var first: String = table.state.currentActorId
	if first != "" and table.legal_actions(first).get("call", false):
		table.act(first, "call", table.revision)
	var second: String = table.state.currentActorId
	if second != "" and table.legal_actions(second).get("check", false):
		table.act(second, "check", table.revision)
	if table.state.currentActorId == "":
		table.advance(table.revision)          # 进入翻牌
	out.postflop_first = table.state.currentActorId
	var steps := 0
	while table.state.status == "playing" and steps < 80:
		steps += 1
		if table.state.currentActorId == "":
			if not table.advance(table.revision):
				break
		else:
			var actor: String = table.state.currentActorId
			var legal: Dictionary = table.legal_actions(actor)
			var kind: String = "check" if legal.get("check", false) else ("call" if legal.get("call", false) else "fold")
			if not table.act(actor, kind, table.revision):
				break
	out.steps = steps
	return out

func run_case(content: Dictionary, fixture: String, busted: int) -> void:
	var table := build_case(content, fixture, busted)
	var buy_in: int = int(content.tables["cargo-table"].buyIn)
	var baseline_wealth := wealth_in_play(table)   # 刚 start_hand()，手进行中
	print("")
	print("--- fixture=%s busted_seat=%d  (基数财富=%d) ---" % [fixture, busted, baseline_wealth])
	if busted == 0:
		# players[0] 出局 → 规则守卫应直接结束，不进入任何一手
		print("  规则守卫命中：status=", table.state.status, " 期望=finished（table.gd:31 对 players[0] 的特判）")
		verify(table.state.status == "finished", "busted=0 应直接结束 fixture=%s" % fixture)
		verify(table.state.currentActorId == "", "busted=0 不应有首行动者 fixture=%s" % fixture)
		return
	for hand in range(4):
		if table.state.status == "finished":
			print("  第 %d 手前已 finished，停止（未达 3 手，属未覆盖而非通过）" % (hand + 1))
			break
		var before := snapshot(table)
		verify(wealth_in_play(table) == baseline_wealth,
			"手开始时全桌财富守恒 fixture=%s busted=%d hand=%d" % [fixture, busted, hand + 1])
		var preflop_first: String = table.state.currentActorId
		var dealer: int = int(table.state.dealerSeat)
		var small: int = int(table.state.smallBlindSeat)
		var big: int = int(table.state.bigBlindSeat)
		var play := play_hand(table)
		hands_recorded += 1
		print("  hand=%d  %s  postflop_first=%s" % [hand + 1, before, play.postflop_first])
		# --- 预期按规则来源，而不是 handNumber % N ---
		# 单挑：庄家=小盲；翻前首行动者=庄家；翻后首行动者=大盲（非庄家）
		verify(small == dealer, "单挑时庄家=小盲 fixture=%s busted=%d hand=%d" % [fixture, busted, hand + 1])
		verify(big != dealer, "单挑时大盲≠庄家 fixture=%s busted=%d hand=%d" % [fixture, busted, hand + 1])
		verify(preflop_first == table.state.players[dealer].id,
			"翻前首行动者=庄家 fixture=%s busted=%d hand=%d" % [fixture, busted, hand + 1])
		verify(play.postflop_first == table.state.players[big].id,
			"翻后首行动者=大盲 fixture=%s busted=%d hand=%d" % [fixture, busted, hand + 1])
		verify(table.state.players[busted].folded and table.state.players[busted].holeCards.is_empty(),
			"出局座位被排除在发牌之外 fixture=%s busted=%d hand=%d" % [fixture, busted, hand + 1])
		verify(small != busted and big != busted and dealer != busted,
			"出局座位不担任盲注或庄家 fixture=%s busted=%d hand=%d" % [fixture, busted, hand + 1])
		# 手刚结束：底池已派发给赢家，此时用 sum(stacks) 口径（不能再加 pot，pot 未清零）
		verify(wealth_settled(table) == baseline_wealth,
			"手结束时全桌财富守恒 fixture=%s busted=%d hand=%d (%d->%d)" % [fixture, busted, hand + 1, baseline_wealth, wealth_settled(table)])
		if hand < 3:
			var saved := Checkpoint.capture(table)
			var restored: RefCounted = Checkpoint.restore(saved)
			verify(restored != null, "换手前 checkpoint 可恢复 fixture=%s busted=%d hand=%d" % [fixture, busted, hand + 1])
			if restored == null:
				return
			table = restored
			verify(table.next_hand(table.revision),
				"next_hand 接受（ACTION 路径轮换）fixture=%s busted=%d hand=%d" % [fixture, busted, hand + 1])
			verify(wealth_in_play(table) == baseline_wealth,
				"换手发盲后全桌财富守恒 fixture=%s busted=%d hand=%d" % [fixture, busted, hand + 1])
