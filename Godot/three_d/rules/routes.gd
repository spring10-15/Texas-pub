extends RefCounted
const NAMES := {"general": "普通出口", "fixed": "预约接应", "service-stairs": "后厨楼梯", "river-launch": "河边接驳", "dropbag-cash": "紧急出口 · 丢现金", "dropbag-valuables": "紧急出口 · 丢贵重物"}
static func quote(run: RefCounted, kind: String) -> Dictionary:
	var reason := ""
	var fee := 0
	var lost_cash := 0
	var goods: int = run.valuable_total()
	var lost_goods := 0
	var scene: Dictionary = run.scene_definition()
	if kind == "general":
		fee = int(scene.generalExtractionFlatFee) + int(floor(run.cash * float(scene.generalExtractionRate))) + (int(scene.lockdownSurcharge) if run.heat == 5 else 0)
		if not run.public_exit:
			reason = "尚未找到出口线索：查看门旁告示"
		elif run.heat >= 6:
			reason = "风声达到 6，普通出口已封锁"
	elif kind == "fixed":
		if run.reservation.is_empty():
			reason = "尚未预约接应，先到酒保服务预订"
		else:
			fee = int(run.reservation.finalCost)
			if run.search_index > run.reservation.expiresAfterSearch:
				reason = "预约已过期"
			elif run.heat > run.reservation.maxHeat:
				reason = "风声超过预约路线限制"
	elif kind in ["service-stairs", "river-launch"]:
		var route: Dictionary = run.content.routes[run.scene_id].specialRoutes[kind]
		fee = maxi(10, int(route.finalCost) - int(scene.hiddenRouteRevealDiscount))
		if not run.route_flags.get(kind, false):
			reason = "需要先使用对应通行证揭示入口"
		elif run.heat > route.maxHeat:
			reason = "风声超过此路线限制"
	elif kind in ["dropbag-cash", "dropbag-valuables"]:
		fee = 10
		if not run.emergency_known():
			reason = "尚未发现紧急出口线索"
		if kind == "dropbag-cash":
			lost_cash = int(floor(run.cash * 0.4))
		else:
			lost_goods = goods
			goods = 0
			if lost_goods == 0:
				reason = "没有可舍弃的贵重物"
	else:
		reason = "未知路线"
	if not run.active:
		reason = "当前没有进行中的出局"
	elif run.table != null:
		reason = "请先完成牌桌并离座"
	elif run.cash < fee:
		reason = "随身现金不足以支付费用"
	return {"route": kind, "fee": fee, "lostCash": lost_cash, "lostGoods": lost_goods, "valuables": goods, "net": maxi(0, run.cash - fee - lost_cash) + goods, "reason": reason, "revision": run.revision}
