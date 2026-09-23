extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Checkpoint = preload("res://three_d/rules/run_checkpoint.gd")
var failures: Array[String] = []
var evaluated := 0
var valid := 0
var boundary_evaluated := 0
var boundary_valid := 0
func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	for scene in Run.SCENE_NAMES:
		for kind in Run.Routes.NAMES:
			for cash in range(201):
				for heat in range(7):
					var r := Run.new(content)
					r.start(r.revision, scene)
					r.cash = cash
					r.heat = heat
					r.public_exit = true
					r.route_flags = {"fixed":true,"service-stairs":true,"river-launch":true}
					r.reservation = r.route_offer().duplicate(true)
					r.reservation.expiresAfterSearch = 3
					r.inventory.append("ivory-chip")
					var goods: int = r.valuable_total()
					var q: Dictionary = r.extraction_quote(kind)
					evaluated += 1
					if not q.reason.is_empty(): continue
					valid += 1
					var balance: int = q.net + q.fee + q.lostCash + q.lostGoods - cash - goods
					if balance != 0 and failures.size() < 10:
						failures.append("%s/%s cash=%d heat=%d balance=%d" % [scene,kind,cash,heat,balance])
					var vault: int = r.vault
					if not r.extract(r.revision,kind) or r.vault - vault != q.net or r.cash != 0 or not r.inventory.is_empty():
						if failures.size() < 10: failures.append("Execution differs from quotation")
					if r.extract(r.revision,kind):
						if failures.size() < 10: failures.append("Duplicate extraction accepted")
	var loadouts := [[], ["ivory-chip"], ["sealed-bond", "pearl-necklace", "obsidian-idol"]]
	for scene in Run.SCENE_NAMES:
		for offer in range(content.routes[scene].fixedRoutes.size()):
			for loadout in loadouts:
				for booking in ["none", "valid", "expired"]:
					for kind in Run.Routes.NAMES:
						for cash in [0, 9, 10, 19, 60, 120, 300]:
							for heat in [0, 5, 6]:
								var r := Run.new(content)
								r.start(r.revision, scene, 100 + offer)
								r.cash = cash
								r.heat = heat
								r.public_exit = true
								r.route_flags = {"service-stairs": true, "river-launch": true}
								r.inventory.assign(loadout)
								r.offer_index = offer
								if booking != "none":
									r.reservation = r.route_offer().duplicate(true)
									r.reservation.expiresAfterSearch = 1 if booking == "expired" else 3
									r.search_index = 2
								var before: Dictionary = Checkpoint.capture(r)
								var quote: Dictionary = r.extraction_quote(kind)
								boundary_evaluated += 1
								var ok: bool = Checkpoint.capture(r) == before
								var accepted: bool = r.extract(r.revision, kind)
								if quote.reason.is_empty():
									boundary_valid += 1
									var goods: int = 0
									for item in loadout: goods += int(content.items[item].value)
									ok = ok and accepted and quote.net + quote.fee + quote.lostCash + quote.lostGoods == cash + goods
									ok = ok and r.vault == before.vault + quote.net and r.last_result.fee == quote.fee and r.last_result.lostGoods == quote.lostGoods and r.cash == 0 and r.inventory.is_empty()
								else:
									ok = ok and not accepted and Checkpoint.capture(r) == before
								if not ok and failures.size() < 10:
									failures.append("Boundary %s/%s offer=%d goods=%s booking=%s cash=%d heat=%d reason=%s" % [scene, kind, offer, str(loadout), booking, cash, heat, quote.reason])
	var report := {"evaluated":evaluated,"validQuotes":valid,"boundaryEvaluated":boundary_evaluated,"boundaryValidQuotes":boundary_valid,"failed":failures.size(),"failures":failures,"scope":"Cash 0..200 and heat 0..6 with one valuable; plus 9,072 boundary states across zero/one/three valuables, both fixed offers, absent/valid/expired reservations, six routes, four venues. All boundary inventories and cash are state fixtures; not a complete end-to-end run or global transition coverage."}
	FileAccess.open("res://../output/3d/extraction-conservation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("EXTRACTION_CONSERVATION ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
