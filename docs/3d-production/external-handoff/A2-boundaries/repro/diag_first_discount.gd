extends SceneTree
## A2-3 / L-2 首次加注优惠（firstAggressionDiscountAvailable）诊断
##
## 目的：把 A 报告 L-2 线索变成可判断的证据 —— 覆盖「同手第二次加注不再享优惠」、
##      「下一手是否复位」、「玩家/对手使用优惠」、「余额刚好与不足」，
##      并逐次记录扣筹码、目标下注额、底池、其他玩家跟注额、全桌总财富。
##
## 设计原则（对应 A2 任务书步骤 3）：
##   1. FIXTURE 与 ACTION 分开：直接写 stack 只用于构造余额边界；所有下注都走 act()。
##   2. 设计语义疑问（优惠是否该改变 currentBet 与实付的对应关系）与守恒错误分开记录，
##      不在诊断里改动规则，也不把优惠删除。
##
## 规则来源（table.gd）：
##   - :26   start_hand() 每手把 firstAggressionDiscountAvailable 重置为 (tableDef.id == "cargo-table")
##   - :67-69 legal_actions() 里 discount=10 只影响 open_cost / raise_cost 的**可负担性**判断
##   - :94-96 act() 在 raise 时 amount = maxi(0, amount - 10) 并消耗标记
##   - :101  commit 之后 state.currentBet = target（**目标下注额不减 10**）
##   - :102  raiseUsed = old_target != 0 → 同一轮内第二次加注被 raiseUsed 挡住
##
## 运行：
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path Godot \
##     --script "$PWD/docs/3d-production/external-handoff/A2-boundaries/repro/diag_first_discount.gd" -- --test
const Table = preload("res://three_d/rules/table.gd")

var failures: Array[String] = []
var checks := 0
var semantic_questions: Array[String] = []
var def: Dictionary = {}
var buy_in := 0

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("  ASSERT-FAIL ", label)

func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	def = content.tables["cargo-table"].duplicate(true)
	buy_in = int(def.buyIn)
	print("=== A2-3 首次加注优惠诊断 (L-2) ===")
	print("cargo-table 参数：buyIn=%s smallBlind=%s openBet=%s raiseIncrement=%s hands=%s discount=10" % [
		def.buyIn, def.smallBlind, def.openBet, def.raiseIncrement, def.hands])
	print("优惠语义：实付 = 目标下注额 - 当前已投 - 10；但 state.currentBet 记录**不减 10 的目标值**。")

	case_open_discount()
	case_same_hand_second_aggression()
	case_next_hand_reset()
	case_opponent_uses_discount()
	case_balance_boundary()
	case_non_discount_table()

	print("")
	print("DIAG_FIRST_DISCOUNT checks=", checks, " failures=", failures.size())
	if not failures.is_empty():
		print("FAILURES=", failures)
	if not semantic_questions.is_empty():
		print("SEMANTIC_QUESTIONS（交主 Agent 决定，不在本诊断内定论）:")
		for q in semantic_questions:
			print("  - ", q)
	quit(0 if failures.is_empty() else 1)

## FIXTURE：建立一张三座位、筹码可控的牌桌；所有下注随后都走 act()
func fresh(stacks: Array) -> RefCounted:
	var definition: Dictionary = def.duplicate(true)
	definition.hands = 3
	var table := Table.new()
	table.start(definition, 7)
	# FIXTURE-START
	for i in range(stacks.size()):
		table.state.players[i].stack = int(stacks[i])
	table.start_hand()
	# FIXTURE-END
	return table

func wealth(table: RefCounted) -> int:
	var total := 0
	for player in table.state.players:
		total += int(player.stack)
	return total + int(table.state.pot)

func others_contribution(table: RefCounted, skip_index: int) -> int:
	var total := 0
	for i in range(table.state.players.size()):
		if i != skip_index:
			total += int(table.state.players[i].currentBet)
	return total

func stash_of(table: RefCounted, index: int) -> int:
	return int(table.state.players[index].stack)

## 用例 1：玩家首次进攻使用优惠
func case_open_discount() -> void:
	print("")
	print("--- 用例 1：玩家首次进攻（翻前）使用优惠 ---")
	var table := fresh([buy_in * 5, buy_in * 5, buy_in * 5])
	var baseline := wealth(table)
	var before := stash_of(table, 0)
	var pot_before := int(table.state.pot)
	print("  座位0(玩家) 首行动=%s  下注前：stack=%d pot=%d 其他跟注=%d 全桌=%d" % [
		table.state.currentActorId, before, pot_before, others_contribution(table, 0), baseline])
	verify(table.state.currentActorId == "player", "翻前首行动者是玩家")
	verify(table.state.firstAggressionDiscountAvailable, "优惠开局可用")
	var revision: int = table.revision
	verify(table.act("player", "raise", revision), "玩家可以加注")
	var paid := before - stash_of(table, 0)
	print("  加注后：stack=%d 实付=%d currentBet=%d pot=%d 其他跟注=%d 全桌=%d 优惠标记=%s" % [
		stash_of(table, 0), paid, int(table.state.currentBet), int(table.state.pot),
		others_contribution(table, 0), wealth(table), table.state.firstAggressionDiscountAvailable])
	# 目标 40，已投 0，名义应付 40，优惠后实付 30
	verify(int(table.state.currentBet) == 40, "目标下注额=40（名义值不减 10）")
	verify(paid == 30, "实付=30（名义 40 减 10）")
	verify(not table.state.firstAggressionDiscountAvailable, "首次进攻后优惠标记被消耗")
	verify(wealth(table) == baseline, "全桌财富守恒")
	semantic_questions.append("优惠让实付(30)与 currentBet(40) 相差 10：这 10 应理解为「折扣」还是「下注额的虚拟抬升」？底池按实付记账，因此 pot 小于名义下注额×人数。需主 Agent 确认设计意图。")

## 用例 2：同一手、跨街的第二次进攻不再享优惠
func case_same_hand_second_aggression() -> void:
	print("")
	print("--- 用例 2：同一手第二次进攻（跨街：翻前→翻牌） ---")
	var table := fresh([buy_in * 5, buy_in * 5, buy_in * 5])
	var baseline := wealth(table)
	var hand_number: int = int(table.state.handNumber)
	table.act("player", "raise", table.revision)
	# 其余两人跟注到 40
	var guard := 0
	while table.state.street == "preflop" and table.state.currentActorId != "" and guard < 8:
		guard += 1
		var actor: String = table.state.currentActorId
		var legal: Dictionary = table.legal_actions(actor)
		var kind: String = "call" if legal.get("call", false) else "check"
		if not table.act(actor, kind, table.revision):
			break
	if table.state.currentActorId == "":
		table.advance(table.revision)
	print("  进入街道=%s handNumber=%s 优惠标记=%s 首行动者=%s" % [
		table.state.street, table.state.handNumber, table.state.firstAggressionDiscountAvailable, table.state.currentActorId])
	verify(int(table.state.handNumber) == hand_number, "仍在同一手")
	verify(table.state.street == "flop", "已进入翻牌")
	verify(not table.state.firstAggressionDiscountAvailable, "优惠标记在翻牌仍为已消耗（同一手内不复位）")
	if table.state.currentActorId == "":
		print("  （翻牌无行动者，本用例无法继续，标记为未覆盖）")
		failures.append("用例2 翻牌无行动者，未能验证第二次进攻")
		return
	var actor2: String = table.state.currentActorId
	var before := stash_of(table, table.find_player(actor2).seatIndex)
	var seat2: int = int(table.find_player(actor2).seatIndex)
	var delta_before := before
	print("  %s 在翻牌下注前：stack=%d 其他跟注=%d 全桌=%d" % [actor2, before, others_contribution(table, seat2), wealth(table)])
	verify(table.act(actor2, "raise", table.revision), "%s 在翻牌可以加注" % actor2)
	var paid2 := delta_before - stash_of(table, seat2)
	print("  翻牌加注后：stack=%d 实付=%d currentBet=%d pot=%d 全桌=%d" % [
		stash_of(table, seat2), paid2, int(table.state.currentBet), int(table.state.pot), wealth(table)])
	# 翻牌 old_target=0 → 目标 openBet=20；若无优惠则实付 20；若有优惠则为 10
	verify(paid2 == 20, "同一手第二次进攻实付=20（无 10 元优惠）")
	verify(int(table.state.currentBet) == 20, "翻牌目标下注额=20")
	verify(wealth(table) == baseline, "全桌财富守恒")

## 用例 3：下一手复位
func case_next_hand_reset() -> void:
	print("")
	print("--- 用例 3：下一手是否复位 ---")
	var table := fresh([buy_in * 5, buy_in * 5, buy_in * 5])
	# 先让玩家真的用掉优惠，再把这手打完 —— 否则整手没有加注，标记从未被消耗，后面「是否复位」就失去意义
	verify(table.act("player", "raise", table.revision), "第一手玩家首攻加注，消耗优惠")
	verify(not table.state.firstAggressionDiscountAvailable, "第一手内标记已被消耗")
	var guard := 0
	while table.state.status == "playing" and guard < 40:
		guard += 1
		if table.state.currentActorId == "":
			if not table.advance(table.revision):
				break
			continue
		var actor: String = table.state.currentActorId
		var legal: Dictionary = table.legal_actions(actor)
		var kind: String = "check" if legal.get("check", false) else ("call" if legal.get("call", false) else "fold")
		if not table.act(actor, kind, table.revision):
			break
	verify(table.state.status == "hand_over", "第一手正常结束（status=hand_over）")
	verify(not table.state.firstAggressionDiscountAvailable, "第一手结束后标记仍为已消耗")
	var ok: bool = table.next_hand(table.revision)
	verify(ok, "next_hand 接受")
	verify(table.state.firstAggressionDiscountAvailable, "下一手开局优惠标记复位为可用")
	var baseline := wealth(table)
	var seat: int = int(table.state.players[table.state.dealerSeat].seatIndex)
	var before := stash_of(table, seat)
	var first: String = table.state.currentActorId
	print("  第二手：庄家=%d 首行动=%s 优惠标记=%s stack=%d" % [table.state.dealerSeat, first, table.state.firstAggressionDiscountAvailable, before])
	verify(table.act(first, "raise", table.revision), "第二手首位行动者可以加注")
	var paid := before - stash_of(table, seat)
	print("  第二手首次进攻实付=%d（若享优惠应为 30，全额为 40）currentBet=%d" % [paid, int(table.state.currentBet)])
	verify(paid == 30, "第二手首次进攻重新享受 10 元优惠（实付 30）")
	verify(wealth(table) == baseline, "全桌财富守恒")

## 用例 4：对手使用优惠
func case_opponent_uses_discount() -> void:
	print("")
	print("--- 用例 4：对手作为首次进攻者使用优惠 ---")
	var table := fresh([buy_in * 5, buy_in * 5, buy_in * 5])
	var baseline := wealth(table)
	verify(table.act("player", "call", table.revision), "玩家先跟注")
	var actor: String = table.state.currentActorId
	var seat: int = int(table.find_player(actor).seatIndex)
	print("  玩家跟注后首行动者=%s (座位%d) 优惠标记=%s" % [actor, seat, table.state.firstAggressionDiscountAvailable])
	verify(actor != "player", "首行动者已切换到对手")
	var before := stash_of(table, seat)
	var already_in := int(table.state.players[seat].currentBet)
	verify(table.act(actor, "raise", table.revision), "%s 可以加注" % actor)
	var paid := before - stash_of(table, seat)
	print("  %s 加注后：stack=%d 已投(盲注)=%d 实付=%d currentBet=%d pot=%d 全桌=%d" % [
		actor, stash_of(table, seat), already_in, paid, int(table.state.currentBet), int(table.state.pot), wealth(table)])
	# 座位1是庄家? 本用例座位1=小盲(已投10)：目标40 → 名义 30 → 优惠后 20；座位2=大盲(已投20)：名义 20 → 优惠后 10
	var nominal := 40 - already_in
	verify(paid == nominal - 10, "对手实付=名义(%d)-10=%d" % [nominal, nominal - 10])
	verify(not table.state.firstAggressionDiscountAvailable, "对手用掉优惠后标记被消耗")
	verify(wealth(table) == baseline, "全桌财富守恒")

## 用例 5：余额刚好与不足（加注可负担性边界）
func case_balance_boundary() -> void:
	print("")
	print("--- 用例 5：加注可负担性边界（含优惠） ---")
	# legal_actions: cost = currentBet - currentBet_player = 20；raise_cost = raiseIncrement - 10 = 10
	# can_raise = not raiseUsed and stack > cost + raise_cost = 30  → 需要 stack >= 31
	for stack_variant in [29, 30, 31, 32]:
		var stack: int = int(stack_variant)
		var table := fresh([stack, buy_in * 5, buy_in * 5])
		var legal: Dictionary = table.legal_actions("player")
		var can := bool(legal.get("raise", false))
		var expect_can: bool = stack > 30
		print("  stack=%2d → 可加注=%s (规则要求 stack > 30) 可跟注=%s 可全下=%s" % [
			stack, can, legal.get("call", false), legal.get("allIn", false)])
		verify(can == expect_can, "stack=%d 时加注可负担性符合规则" % stack)
		if can:
			var before := stash_of(table, 0)
			var baseline := wealth(table)
			verify(table.act("player", "raise", table.revision), "stack=%d 时加注成功" % stack)
			var paid := before - stash_of(table, 0)
			print("       实付=%d 剩余=%d currentBet=%d" % [paid, stash_of(table, 0), int(table.state.currentBet)])
			verify(paid == 30, "stack=%d 时实付仍为 30（优惠按固定 10 元）" % stack)
			verify(wealth(table) == baseline, "stack=%d 时全桌财富守恒" % stack)
		else:
			# 不足时改跟注，验证跟注不吃优惠
			var before2 := stash_of(table, 0)
			var baseline2 := wealth(table)
			verify(table.act("player", "call", table.revision), "stack=%d 时至少可以跟注" % stack)
			print("       改为跟注：实付=%d（跟注不享优惠）currentBet=%d" % [before2 - stash_of(table, 0), int(table.state.currentBet)])
			verify(before2 - stash_of(table, 0) == 20, "跟注实付=20（优惠只作用于加注）")
			verify(wealth(table) == baseline2, "stack=%d 跟注时全桌财富守恒" % stack)
	# 刚好只够跟注
	var exact := fresh([20, buy_in * 5, buy_in * 5])
	verify(exact.act("player", "call", exact.revision), "stack=20 刚好够跟注")
	verify(stash_of(exact, 0) == 0, "跟注后 stack=0")
	semantic_questions.append("玩家 stack 刚好等于跟注额时，跟注后 stack=0：下一手会被判 folded（table.gd:27-28）。这属于「打光」的正常语义，还是应判 all-in 并保留在桌？属语义确认项。")

## 用例 6：非优惠桌（对照组）
func case_non_discount_table() -> void:
	print("")
	print("--- 用例 6：对照组 ledger-cellar（无首攻优惠） ---")
	var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json")).tables["ledger-cellar"].duplicate(true)
	definition.hands = 3
	var table := Table.new()
	table.start(definition, 7)
	# FIXTURE
	for i in range(3):
		table.state.players[i].stack = buy_in * 5
	table.start_hand()
	# FIXTURE-END
	print("  firstAggressionDiscountAvailable=%s openBet=%s" % [table.state.firstAggressionDiscountAvailable, definition.openBet])
	verify(not table.state.firstAggressionDiscountAvailable, "非货运桌开局无优惠")
	var before := stash_of(table, 0)
	var baseline := wealth(table)
	verify(table.act("player", "raise", table.revision), "账房地窖玩家可以加注")
	var paid := before - stash_of(table, 0)
	# 当前下注额 30（大盲），首攻加注最小值 = 30 + 加注步长 30 = 60，且无优惠
	var expected := int(definition.openBet) + int(definition.raiseIncrement)
	print("  实付=%d currentBet=%d（当前下注额 %s + 加注步长 %s = %d，无优惠）" % [
		paid, int(table.state.currentBet), definition.openBet, definition.raiseIncrement, expected])
	verify(paid == expected, "无优惠时实付=当前下注额+加注步长=%d" % expected)
	verify(int(table.state.currentBet) == expected, "目标下注额=%d" % expected)
	verify(wealth(table) == baseline, "全桌财富守恒")
