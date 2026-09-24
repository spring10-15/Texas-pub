extends SceneTree
## A3 只读诊断探针（任务 A3 第 4 步）。
##
## 目的：独立于既有测试断言的措辞，重新推导六条待拆分边界的「可达性 + 实际受影响的字段」，
## 并补一处现有测试未覆盖的空档（首次进攻折扣是否只减一次）。
##
## 约束遵守：
## - 只在内存中构造牌局；不读写任何存档（不碰 user://）。
## - 不修改任何生产代码、测试、覆盖目录；本脚本自身不写任何文件，只把结果打到 stdout。
## - 前置条件构造失败必须报失败（verify(false, ...)），不允许静默 continue 后报通过。
##
## 运行：
##   python3 output/external-handoff/V1/run_godot.py --log output/external-handoff/A3/<名字>.log \
##     --timeout 180 -- --script <本文件绝对路径> -- --test
const Table = preload("res://three_d/rules/table.gd")
const Checkpoint = preload("res://three_d/rules/table_checkpoint.gd")

var checks := 0
var failures: Array[String] = []
var cases := {}

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

## 记录「实际受影响的字段」：只比较会进入 Checkpoint 的牌桌状态字段。
func snapshot(table: RefCounted) -> Dictionary:
	var s: Dictionary = table.state.duplicate(true)
	var stacks: Array = []
	var bets: Array = []
	var contribs: Array = []
	var folded: Array = []
	for p in s.players:
		stacks.append(int(p.stack))
		bets.append(int(p.currentBet))
		contribs.append(int(p.handContribution))
		folded.append(bool(p.folded))
	return {
		"pot": int(s.pot), "tableBet": int(s.currentBet), "street": str(s.street),
		"community": int(s.community.size()), "toAct": s.toAct.duplicate(),
		"actor": str(s.currentActorId), "dealer": int(s.get("dealerSeat", -1)),
		"sb": int(s.get("smallBlindSeat", -1)), "bb": int(s.get("bigBlindSeat", -1)),
		"raiseUsed": bool(s.raiseUsed),
		"discount": bool(s.get("firstAggressionDiscountAvailable", false)),
		"turnCounter": int(s.turnCounter), "stacks": stacks, "bets": bets,
		"contribs": contribs, "folded": folded,
		"revision": int(table.revision), "rng": int(table.rng.value),
		"deckSize": int(s.deck.size()),
	}

func changed_fields(before: Dictionary, after: Dictionary) -> Array:
	var out: Array = []
	for key in before:
		if before[key] != after[key]:
			out.append(key)
	return out

func rules() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))

func starting_table(table_id: String, seed_value: int) -> RefCounted:
	var t := Table.new()
	t.start(rules().tables[table_id], seed_value)
	return t

func _initialize() -> void:
	var c := rules()
	var cargo: Dictionary = c.tables["cargo-table"]
	var open_bet: int = int(cargo.openBet)
	var raise_inc: int = int(cargo.raiseIncrement)
	var discount: int = int(cargo.get("firstAggressionDiscount", 0))

	# ---------- S1 short_all_in ----------
	# 0 < stack < 欠注额时的全押：筹码全下但补不满当前下注额，不重开队列。
	var t := starting_table("cargo-table", 7)
	var p0: Dictionary = t.find_player("player")
	verify(not p0.is_empty() and t.state.currentActorId == "player", "S1 前置：首行动者应为 player")
	var owed: int = int(t.state.currentBet) - int(p0.currentBet)
	verify(owed == open_bet, "S1 前置：player 欠注应为 openBet(%d)，实为 %d" % [open_bet, owed])
	p0.stack = owed - 1                                  # 短筹码夹具（总筹码守恒）
	var before := Checkpoint.capture(t)
	var sb := snapshot(t)
	var accepted: bool = t.act("player", "all-in", t.revision)
	var sa := snapshot(t)
	verify(accepted, "S1 short_all_in 应被接受")
	verify(int(p0.stack) == 0, "S1 全押后 stack 应为 0")
	verify(t.state.pot == int(before.state.pot) + owed - 1, "S1 底池应只增加实付 %d" % (owed - 1))
	verify(int(t.state.currentBet) == owed, "S1 短全押不得抬高当前下注额（不重开队列）")
	verify(not bool(t.state.raiseUsed), "S1 短全押不得置 raiseUsed")
	verify(t.rng.value == before.rngValue and t.state.deck == before.state.deck, "S1 不得消耗 RNG / 改动牌堆")
	verify(t.state.toAct == ["dock-braggart", "ledger-clerk"], "S1 队列应只前进一位")
	cases["short_all_in"] = {"accepted": accepted, "pot_delta": sa.pot - sb.pot,
		"affected": changed_fields(sb, sa), "before": sb, "after": sa}

	# ---------- S2 exact_call_all_in ----------
	# stack 恰好等于欠注额的跟注：筹码归零；后继状态与 S1 不同（底池/贡献各差 1），因此不重复计数。
	var e := starting_table("cargo-table", 7)
	var q0: Dictionary = e.find_player("player")
	var owed2: int = int(e.state.currentBet) - int(q0.currentBet)
	q0.stack = owed2
	var eb := snapshot(e)
	var accepted2: bool = e.act("player", "call", e.revision)
	var ea := snapshot(e)
	verify(accepted2, "S2 exact_call_all_in 应被接受")
	verify(int(q0.stack) == 0, "S2 刚好耗尽的跟注后 stack 应为 0")
	verify(int(e.state.pot) == int(eb.pot) + owed2, "S2 底池应增加全额欠注 %d" % owed2)
	verify(int(e.state.currentBet) == owed2, "S2 当前下注额不变")
	# 用 all-in 命令达到同一目标也应等价（同一语义结果，不重复计数）。
	var e2 := starting_table("cargo-table", 7)
	var r0: Dictionary = e2.find_player("player")
	r0.stack = owed2
	var accepted3: bool = e2.act("player", "all-in", e2.revision)
	verify(accepted3 and e2.state.pot == e.state.pot and e2.state.currentBet == e.state.currentBet,
		"S2 等价性：stack==欠注时 call 与 all-in 后继状态应等价")
	cases["exact_call_all_in"] = {"accepted": accepted2, "pot_delta": ea.pot - eb.pot,
		"affected": changed_fields(eb, ea), "before": eb, "after": ea,
		"pot_delta_minus_short": (ea.pot - eb.pot) - (sa.pot - sb.pot)}

	# ---------- S3 queue_reopen ----------
	# 后位加注把已经跟注过的玩家重新召回队列。
	var m := starting_table("cargo-table", 7)
	verify(m.act("player", "call", m.revision), "S3 前置：player 跟注应被接受")
	var raiser: String = str(m.state.currentActorId)
	var mb := snapshot(m)
	verify(raiser == "dock-braggart", "S3 前置：加注者应为 dock-braggart，实为 %s" % raiser)
	var accepted4: bool = m.act(raiser, "raise", m.revision)
	var ma := snapshot(m)
	verify(accepted4, "S3 加注应被接受")
	verify(m.state.toAct == ["ledger-clerk", "player"], "S3 加注后队列应为 [ledger-clerk, player]（召回先前跟注者）")
	verify(int(m.state.currentBet) == int(mb.tableBet) + raise_inc,
		"S3 加注应抬高当前下注额 +%d（实为 %d）" % [raise_inc, int(m.state.currentBet)])
	verify(m.act("ledger-clerk", "call", m.revision), "S3 后位跟注应被接受")
	verify(m.state.currentActorId == "player", "S3 原跟注者应重新欠注并回到行动位")
	cases["queue_reopen"] = {"accepted": accepted4, "affected": changed_fields(mb, ma),
		"before": mb, "after": ma, "reopened_actor_after_others_call": str(m.state.currentActorId)}

	# ---------- S4 lone_funded_queue ----------
	# 只有一名玩家还有筹码时：仍欠注则继续行动；已跟平则跳过下注、直接发完公共牌。
	var l := starting_table("cargo-table", 7)
	var buy_in: int = int(cargo.buyIn)
	l.state.players[0].stack = buy_in * 2
	l.state.players[1].stack = buy_in / 2
	l.state.players[2].stack = buy_in - buy_in / 2
	l.start_hand()          # pot 归零并按新筹码重发盲注
	var wealth_before: int = int(l.state.pot)
	for person in l.state.players:
		wealth_before += int(person.stack)
	verify(wealth_before == buy_in * 3, "S4 前置：start_hand 后总筹码应守恒（实为 %d）" % wealth_before)
	verify(l.act("player", "call", l.revision), "S4 前置：player 跟注应被接受")
	verify(l.act(l.state.currentActorId, "all-in", l.revision), "S4 前置：首个对手全押应被接受")
	verify(l.act(l.state.currentActorId, "all-in", l.revision), "S4 前置：次个对手全押应被接受")
	var lo := snapshot(l)
	verify(l.state.currentActorId == "player" and l.state.toAct == ["player"],
		"S4 lone_funded_owes：唯一有筹码者仍欠注时应留在队列")
	verify(l.act("player", "call", l.revision), "S4 前置：唯一有筹码者补足应被接受")
	var lm := snapshot(l)
	verify(int(l.state.players[0].stack) > 0 and l.state.toAct.is_empty() and l.state.currentActorId == "",
		"S4 lone_funded_matched：补平后不得再有行动者")
	var runout_ok := true
	var runout_notes: Array = []
	for street in ["flop", "turn", "river"]:
		var deck_size: int = int(l.state.deck.size())
		var community_size: int = int(l.state.community.size())
		var pot_before: int = int(l.state.pot)
		var rng_before: int = int(l.rng.value)
		var drawn: int = 3 if street == "flop" else 1
		var ok: bool = l.advance(l.revision)
		runout_ok = runout_ok and ok and l.state.street == street and l.state.toAct.is_empty() \
			and l.state.currentActorId == "" and int(l.state.pot) == pot_before and int(l.rng.value) == rng_before \
			and int(l.state.deck.size()) == deck_size - drawn \
			and int(l.state.community.size()) == community_size + drawn
		runout_notes.append({"street": street, "accepted": ok, "pot": int(l.state.pot),
			"actor": str(l.state.currentActorId), "community": int(l.state.community.size())})
	verify(runout_ok, "S4 lone_funded_runout：无人可行动时应按街发牌且不消耗 RNG / 不改底池")
	cases["lone_funded_queue"] = {"owes": lo, "matched": lm, "runout": runout_notes}

	# ---------- S5 aggression_discount ----------
	# 首次激进行动折扣（货运桌 10）：只减一次；flag 为假时全额；非激进动作不消耗它。
	var g := starting_table("cargo-table", 7)
	var g0: Dictionary = g.find_player("player")
	verify(bool(g.state.firstAggressionDiscountAvailable), "S5 前置：货运桌开局应有首次进攻折扣")
	var g_owed: int = int(g.state.currentBet) - int(g0.currentBet)
	var stack0: int = int(g0.stack)
	verify(g.act("player", "raise", g.revision), "S5 前置：首次加注应被接受")
	var paid_first: int = stack0 - int(g0.stack)
	var full_first: int = g_owed + raise_inc
	verify(paid_first == full_first - discount,
		"S5 首次加注实付应为 %d（欠注 %d + 加注增量 %d - 折扣 %d），实为 %d" % [full_first - discount, g_owed, raise_inc, discount, paid_first])
	verify(not bool(g.state.firstAggressionDiscountAvailable), "S5 首次进攻后折扣标志应被消耗")
	var flag_after_first: bool = bool(g.state.firstAggressionDiscountAvailable)
	verify(g.act("dock-braggart", "call", g.revision), "S5 前置：对手跟注应被接受")
	verify(g.act("ledger-clerk", "call", g.revision), "S5 前置：次位跟注应被接受")
	verify(g.advance(g.revision) and g.state.street == "flop", "S5 前置：应推进到翻牌")
	var actor_after_flop: String = str(g.state.currentActorId)
	var guard := 0
	while g.state.currentActorId != "player" and not g.state.currentActorId.is_empty() and guard < 8:
		guard += 1
		var who: String = str(g.state.currentActorId)
		var legal: Dictionary = g.legal_actions(who)
		verify(g.act(who, "check" if legal.check else "call", g.revision),
			"S5 前置：非玩家位应能过牌/跟注")
	var paid_second: int = 0
	if g.state.currentActorId == "player":
		var stack1: int = int(g0.stack)
		verify(g.act("player", "raise", g.revision), "S5 第二次进攻应被接受")
		paid_second = stack1 - int(g0.stack)
		verify(paid_second == open_bet, "S5 第二次进攻应按全额 %d 支付（不得再减折扣），实为 %d" % [open_bet, paid_second])
	else:
		verify(false, "S5 未能把行动位交回 player（实际 %s），第二次进攻未验证" % str(g.state.currentActorId))
	# flag 为假时全额（隔离夹具，直接置假）。
	var iso := starting_table("cargo-table", 7)
	var i0: Dictionary = iso.find_player("player")
	iso.state.firstAggressionDiscountAvailable = false
	var iso_owed: int = int(iso.state.currentBet) - int(i0.currentBet)
	var iso_stack: int = int(i0.stack)
	verify(iso.act("player", "raise", iso.revision), "S5 隔离：flag=false 时加注应被接受")
	verify(iso_stack - int(i0.stack) == iso_owed + raise_inc, "S5 隔离：flag=false 时不得减折扣")
	# 非激进动作不消耗折扣。
	var pas := starting_table("cargo-table", 7)
	verify(pas.act("player", "call", pas.revision), "S5 非激进：跟注应被接受")
	verify(bool(pas.state.firstAggressionDiscountAvailable), "S5 非激进：跟注不得消耗首次进攻折扣")
	cases["aggression_discount"] = {
		"discount_config": discount, "flag_after_first_aggression": flag_after_first,
		"paid_first_aggression": paid_first, "paid_second_aggression": paid_second,
		"second_aggression_full_cost": open_bet, "actor_after_flop": actor_after_flop,
		"flag_survives_non_aggression": bool(pas.state.firstAggressionDiscountAvailable)}

	# ---------- S6 next_hand_heads_up ----------
	# 两人有筹码、第三人出局时的下一手：庄位轮转到另一名有筹码的玩家，且单挑由庄家下小盲。
	var definition: Dictionary = cargo.duplicate(true)
	definition.hands = 4
	var h := Table.new()
	h.start(definition, 7)
	var hb: int = int(definition.buyIn)
	h.state.players[0].stack = hb
	h.state.players[1].stack = hb * 2
	h.state.players[2].stack = 0
	h.start_hand()
	verify(bool(h.state.players[2].folded), "S6 前置：零筹码席应被视为已出局")
	verify(h.state.currentActorId == "player", "S6 前置：单挑应由庄家先行动")
	verify(h.state.smallBlindSeat == h.state.dealerSeat, "S6 前置：单挑应由庄家下小盲")
	verify(h.act("player", "call", h.revision), "S6 前置：庄家补小盲应被接受")
	verify(h.act("dock-braggart", "check", h.revision), "S6 前置：大盲过牌应被接受")
	verify(h.advance(h.revision) and h.state.street == "flop", "S6 前置：应推进到翻牌")
	verify(h.state.currentActorId == "dock-braggart", "S6 前置：翻牌后应由非庄家先行动")
	verify(h.act("dock-braggart", "fold", h.revision), "S6 前置：非庄家弃牌应收手")
	verify(h.state.status == "hand_over" and h.state.pendingNextHand, "S6 前置：应有下一手")
	var dealer_before: int = int(h.state.dealerSeat)
	var hand_before: int = int(h.state.handNumber)
	verify(Checkpoint.restore(Checkpoint.capture(h)) != null, "S6 前置：该局面应被 Checkpoint 接受（合法状态）")
	var ok_next: bool = h.next_hand(h.revision)
	verify(ok_next, "S6 next_hand 应被接受")
	verify(int(h.state.handNumber) == hand_before + 1, "S6 手数应 +1")
	verify(int(h.state.dealerSeat) == 1, "S6 庄位应轮转到 seat 1（实际 %d）" % int(h.state.dealerSeat))
	verify(int(h.state.dealerSeat) != dealer_before, "S6 庄位应发生轮转")
	verify(h.state.smallBlindSeat == h.state.dealerSeat, "S6 单挑庄家仍下小盲")
	verify(h.state.bigBlindSeat != h.state.dealerSeat, "S6 大盲应在另一名有筹码玩家")
	verify(h.state.currentActorId == h.state.players[h.state.dealerSeat].id, "S6 单挑翻牌前由庄家先行动")
	verify(h.state.players[2].holeCards.is_empty(), "S6 出局席不得发牌")
	var wealth_after: int = int(h.state.pot)
	for person in h.state.players:
		wealth_after += int(person.stack)
	verify(wealth_after == hb * 3, "S6 换手后总筹码应守恒")
	cases["next_hand_heads_up"] = {
		"dealer_before": dealer_before, "dealer_after": int(h.state.dealerSeat),
		"sb": int(h.state.smallBlindSeat), "bb": int(h.state.bigBlindSeat),
		"actor": str(h.state.currentActorId), "hand": int(h.state.handNumber),
		"wealth": wealth_after}

	# ---------- S7 疑似不一致：同一「全押」结果，两条命令的折扣标志不同 ----------
	# act(id,"raise", 超大目标) 会先执行 table.gd:94-96 的折扣消耗，再在 table.gd:97-98 转成全押；
	# act(id,"all-in") 直接走 table.gd:109-116，不经过折扣块。两者的筹码/底池/目标/队列相同，
	# 只有 firstAggressionDiscountAvailable 不同。任务书要求只给复现与实际结果，不自行改规则。
	var a1 := starting_table("cargo-table", 7)
	verify(a1.act("player", "raise", a1.revision, 10000), "S7 经 raise 超额目标触发全押应被接受")
	var a1_after := snapshot(a1)
	var a2 := starting_table("cargo-table", 7)
	verify(a2.act("player", "all-in", a2.revision), "S7 经 all-in 命令应被接受")
	var a2_after := snapshot(a2)
	verify(a1_after["stacks"] == a2_after["stacks"] and a1_after["pot"] == a2_after["pot"] \
		and a1_after["tableBet"] == a2_after["tableBet"] and a1_after["toAct"] == a2_after["toAct"] \
		and a1_after["actor"] == a2_after["actor"] and a1_after["raiseUsed"] == a2_after["raiseUsed"],
		"S7 前置：两条命令的筹码/底池/下注目标/队列/raiseUsed 应完全一致")
	verify(a1_after["discount"] != a2_after["discount"],
		"S7 疑似不一致：经 raise 转全押会消耗首次进攻折扣，经 all-in 不会（此断言即该现象的复现）")
	cases["discount_consumption_divergence"] = {
		"discount_via_raise_to_all_in": a1_after["discount"],
		"discount_via_all_in_command": a2_after["discount"],
		"stacks_via_raise": a1_after["stacks"], "stacks_via_all_in": a2_after["stacks"],
		"pot_via_raise": a1_after["pot"], "pot_via_all_in": a2_after["pot"],
		"tableBet_via_raise": a1_after["tableBet"], "tableBet_via_all_in": a2_after["tableBet"]}

	# ---------- 汇总 ----------
	var report := {
		"scope": "A3 六条待拆分边界：可达性与实际受影响字段复核（只读、纯内存）",
		"checks": checks, "failed": failures.size(), "failures": failures, "cases": cases,
	}
	print("A3_BOUNDARY_PROBE ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
