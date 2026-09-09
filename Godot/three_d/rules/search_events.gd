extends RefCounted
## Authored choices: costs are shown before commitment; each site resolves once per run.
const EVENTS := {
	"cargo-table": {"title":"遗落的外套", "text":"衣袋里有一枚银打火机和写着员工门禁的便笺。只能趁无人注意拿走其中一件。", "choices":[{"id":"goods", "label":"拿银打火机 · 1 行动力，风声 +1", "item":"old-silver-lighter", "heat":1}, {"id":"lead", "label":"只抄下接应线索 · 1 行动力", "route":"fixed"}]},
	"ledger-cellar": {"title":"账房的封口信", "text":"账房愿意透露下一桌的规则，或者买下你替他跑腿的时间。", "choices":[{"id":"intel", "label":"花 15 查明镜厅情报 · 1 行动力", "cost":15, "intel":"mirror-hall"}, {"id":"cash", "label":"代送封口信 · 现金 +25，风声 +1，1 行动力", "cash":25, "heat":1}]},
	"mirror-hall": {"title":"寄存柜里的胸针", "text":"柜门虚掩。一枚胸针压着工作人员的通道记录。你必须决定带走什么。", "choices":[{"id":"goods", "label":"拿翡翠胸针 · 1 行动力，风声 +1", "item":"emerald-brooch", "heat":1}, {"id":"intel", "label":"查看余烬桌情报 · 1 行动力", "intel":"embers-table"}]},
	"embers-table": {"title":"收班前的交易", "text":"侍者准备离开。他可以指点一条员工通道，也可以收钱替你拖延巡查。", "choices":[{"id":"route", "label":"记下员工通道 · 1 行动力", "route":"service-stairs"}, {"id":"cool", "label":"付 30 拖延巡查 · 风声 -1，1 行动力", "cost":30, "cool":true}]}
}
static func choice(site: String, id: String) -> Dictionary:
	for option in EVENTS.get(site, {}).get("choices", []):
		if option.id == id: return option
	return {}
static func reason(run: RefCounted, site: String, id: String) -> String:
	var option := choice(site, id)
	if option.is_empty(): return "未知选择"
	if not run.active or run.table != null: return "只能在离桌探索时处理"
	var required: Variant = run.content.tables[site].unlocksAfter
	if required != null and required not in run.completed: return "该房间尚未解锁"
	if run.search_results.has(site): return "本局已处理此处"
	if run.action_points < 1: return "行动力不足"
	if run.cash < int(option.get("cost", 0)): return "随身现金不足"
	if option.has("item") and run.slots_used() + int(run.content.items[option.item].slots) > int(run.content.inventorySlots): return "背包已满"
	if option.has("route") and run.route_known(option.route): return "已知这条路线，无需重复取线索"
	if option.has("intel") and run.full_intel.has(option.intel): return "已知全部情报"
	if option.get("cool", false) and (run.heat_reduced or run.heat <= 0): return "本轮已降过风声或无需降低"
	return ""
static func apply(run: RefCounted, site: String, id: String) -> void:
	var option := choice(site, id)
	run.cash += int(option.get("cash", 0)) - int(option.get("cost", 0))
	run.heat = mini(6, run.heat + int(option.get("heat", 0)))
	if option.has("item"): run.inventory.append(option.item)
	if option.has("route"): run.route_flags[option.route] = true
	if option.has("intel"):
		run.full_intel[option.intel] = true
		if option.intel not in run.known_rules: run.known_rules.append(option.intel)
	if option.get("cool", false):
		run.heat -= 1
		run.heat_reduced = true
	run.action_points -= 1
	run.service_message = EVENTS[site].title + "：" + option.label
	run.search_results[site] = {"choice":id, "message":run.service_message}
