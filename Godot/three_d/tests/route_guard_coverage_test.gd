extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Checkpoint = preload("res://three_d/rules/run_checkpoint.gd")
const CASES := {
	"general_unknown":["general","尚未找到出口线索：查看门旁告示"],
	"general_locked":["general","风声达到 6，普通出口已封锁"],
	"fixed_missing":["fixed","尚未预约接应，先到酒保服务预订"],
	"fixed_expired":["fixed","预约已过期"],
	"fixed_heat":["fixed","风声超过预约路线限制"],
	"stairs_unknown":["service-stairs","需要先使用对应通行证揭示入口"],
	"stairs_heat":["service-stairs","风声超过此路线限制"],
	"river_unknown":["river-launch","需要先使用对应通行证揭示入口"],
	"river_heat":["river-launch","风声超过此路线限制"],
	"emergency_unknown":["dropbag-cash","尚未发现紧急出口线索"],
	"goods_empty":["dropbag-valuables","没有可舍弃的贵重物"],
	"unknown_kind":["unknown","未知路线"],
	"inactive":["general","当前没有进行中的出局"],
	"table_active":["general","请先完成牌桌并离座"],
	"general_surcharge":["general",""],
	"fixed_expiry_boundary":["fixed",""],
	"stairs_heat_boundary":["service-stairs",""],
	"river_heat_boundary":["river-launch",""]
}
var hits := {}
var failures: Array[String] = []
var samples := 0
func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var cases := CASES.duplicate(true)
	for route in Run.Routes.NAMES: cases["cash_"+route] = [route,"随身现金不足以支付费用"]
	for scene in Run.SCENE_NAMES:
		for offer in range(content.routes[scene].fixedRoutes.size()):
			for key in cases:
				var r := Run.new(content)
				r.start(r.revision,scene,0)
				r.public_exit = true
				r.inventory.append("ivory-chip")
				r.route_flags = {"service-stairs":true,"river-launch":true}
				r.offer_index = offer
				r.reservation = r.route_offer().duplicate(true)
				r.reservation.expiresAfterSearch = 3
				var route: String = cases[key][0]
				match key:
					"general_unknown": r.public_exit = false
					"general_locked": r.heat = 6
					"fixed_missing": r.reservation.clear()
					"fixed_expired": r.search_index = 4
					"fixed_heat": r.heat = int(r.reservation.maxHeat)+1
					"stairs_unknown","river_unknown": r.route_flags.clear()
					"stairs_heat","river_heat": r.heat = int(content.routes[scene].specialRoutes[route].maxHeat)+1
					"emergency_unknown","goods_empty": r.inventory.clear()
					"inactive": r.active = false
					"table_active": r.enter_table(1,r.revision)
					"general_surcharge": r.heat = 5
					"fixed_expiry_boundary": r.search_index = 3
					"stairs_heat_boundary","river_heat_boundary": r.heat = int(content.routes[scene].specialRoutes[route].maxHeat)
				if str(key).begins_with("cash_"): r.cash = 0
				var before := Checkpoint.capture(r)
				var quote: Dictionary = r.extraction_quote(route)
				var ok: bool = quote.reason==cases[key][1] and Checkpoint.capture(r)==before
				var accepted: bool = r.extract(r.revision,route)
				if cases[key][1].is_empty():
					var fee: int
					if key=="general_surcharge":
						fee = int(content.scenes[scene].generalExtractionFlatFee)+int(floor(300*float(content.scenes[scene].generalExtractionRate)))+int(content.scenes[scene].lockdownSurcharge)
					elif route=="fixed":
						fee = int(before.reservation.finalCost)
					else:
						fee = maxi(10,int(content.routes[scene].specialRoutes[route].finalCost)-int(content.scenes[scene].hiddenRouteRevealDiscount))
					var net: int = 300+int(content.items["ivory-chip"].value)-fee
					ok = ok and accepted and quote.fee==fee and r.vault==before.vault+net and r.cash==0 and r.inventory.is_empty() and not r.active
				else:
					ok = ok and not accepted and Checkpoint.capture(r)==before
				samples += 1
				var id: String = "route_guard."+key
				if ok: hits[id] = {"test":"route_guard_coverage_test.gd","postcondition_verified":true}
				else: failures.append(id+":"+scene+":"+str(offer)); push_error(failures.back())
	var text := FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json")
	var catalog: Dictionary = JSON.parse_string(text)
	var expected: Array = catalog.transitions.filter(func(row): return str(row.id).begins_with("route_guard.")).map(func(row): return row.id)
	var missing: Array = expected.filter(func(id): return not hits.has(id))
	for id in hits:
		if id not in expected: failures.append("Uncatalogued "+id)
	var hashes := {}
	for file in DirAccess.get_files_at("res://three_d/rules"):
		if file.ends_with(".gd") or file.ends_with(".json"): hashes[file] = FileAccess.get_file_as_string("res://three_d/rules/"+file).sha256_text()
	var report := {"scope":"Route rejection outcomes and fee/expiry/heat boundaries","source_sha256":hashes,"test_sha256":FileAccess.get_file_as_string("res://three_d/tests/route_guard_coverage_test.gd").sha256_text(),"catalog_sha256":text.sha256_text(),"numerator":hits.size(),"denominator":expected.size(),"samples":samples,"hits":hits,"missing":missing,"failures":failures,"overall_state_transition_coverage":null}
	FileAccess.open("res://../output/3d/route-guard-coverage.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ROUTE_GUARD_COVERAGE covered=",hits.size()," total=",expected.size()," samples=",samples," failures=",failures)
	quit(0 if failures.is_empty() and missing.is_empty() else 1)
