extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Checkpoint = preload("res://three_d/rules/run_checkpoint.gd")
var failures: Array[String] = []
var hits := {}
func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json"))
	for venue in content.scenes:
		for offer in range(2):
			for key in ["success","renew_expired","phone_preserves","stale_revision","inactive","wrong_item","table_active","no_actions","unknown_route","valid_booking","cash_short"]:
				var r := Run.new(content)
				r.start(r.revision,venue,0)
				r.offer_index = offer
				r.route_flags.fixed = true
				var item := ""
				var reason := ""
				if key in ["renew_expired","valid_booking","phone_preserves"]:
					r.service_action("reserve","",r.revision)
					if key == "renew_expired": r.search_index = r.reservation.expiresAfterSearch+1
				match key:
					"inactive": r.active = false; reason = "尚未出发"
					"wrong_item": item = "ivory-chip"; reason = "背包中没有对应物品"
					"table_active": r.enter_table(7,r.revision); reason = "请先结束牌桌并离座"
					"no_actions": r.action_points = 0; reason = "行动力不足"
					"unknown_route": r.route_flags.clear(); reason = "先完成货运桌或使用手机获取接应线索"
					"valid_booking": reason = "已有有效预约"
					"cash_short": r.cash = r.reserve_fee()-1; reason = "预约现金不足"
				var before := Checkpoint.capture(r)
				var ok: bool = true
				if key == "phone_preserves":
					r.inventory.append("disposable-phone")
					var accepted: bool = r.service_action("phone-route","disposable-phone",r.revision)
					ok = accepted and r.reservation == before.reservation and r.offer_index == (offer+1)%2 and r.cash == before.cash and r.inventory.is_empty() and r.action_points == before.action_points-1
					ok = ok and r.extraction_quote("fixed").fee == before.reservation.finalCost
				else:
					ok = r.service_reason("reserve",item) == reason and Checkpoint.capture(r) == before
					var accepted: bool = r.service_action("reserve",item,r.revision-1 if key == "stale_revision" else r.revision)
					if key in ["success","renew_expired"]:
						var expected := before.duplicate(true)
						var definition: Dictionary = content.routes[venue].fixedRoutes[offer].duplicate(true)
						var fee := maxi(10,int(definition.reserveCost)-int(content.scenes[venue].fixedRouteReserveDiscount))
						definition.reserveCost = fee
						definition.expiresAfterSearch = before.search_index+maxi(1,int(content.scenes[venue].fixedRouteGraceSearches))
						expected.reservation = definition
						expected.cash -= fee
						expected.action_points -= 1
						expected.revision += 1
						expected.service_message = r.service_message
						ok = ok and accepted and Checkpoint.capture(r) == expected
					else:
						ok = ok and not accepted and Checkpoint.capture(r) == before
				var id: String = "reservation."+key
				if ok: hits[id] = {"test":"reservation_coverage_test.gd","postcondition_verified":true}
				else: failures.append(id+"/"+venue+"/"+str(offer)); push_error(failures.back())
	var expected: Array = catalog.transitions.filter(func(row): return str(row.id).begins_with("reservation.")).map(func(row): return row.id)
	for id in hits:
		if id not in expected: failures.append("Uncatalogued hit: "+id)
	var missing: Array = expected.filter(func(id): return not hits.has(id))
	var hashes := {}
	for file in DirAccess.get_files_at("res://three_d/rules"):
		if not (file.ends_with(".gd") or file.ends_with(".json")): continue
		hashes[file] = FileAccess.get_file_as_string("res://three_d/rules/"+file).sha256_text()
	var report := {"scope":"reservation subgraph only","source_sha256":hashes,"test_sha256":FileAccess.get_file_as_string("res://three_d/tests/reservation_coverage_test.gd").sha256_text(),"catalog_sha256":FileAccess.get_file_as_string("res://../docs/3d-production/phase-1/coverage/transitions.json").sha256_text(),"denominator":expected.size(),"numerator":hits.size(),"missing":missing,"failures":failures,"hits":hits,"overall_state_transition_coverage":null,"overall_status":"Other families not yet enumerated; no global percentage claimed."}
	FileAccess.open("res://../output/3d/reservation-coverage.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("RESERVATION_COVERAGE covered=",hits.size()," total=",expected.size()," missing=",missing," failures=",failures)
	quit(0 if failures.is_empty() and missing.is_empty() else 1)
