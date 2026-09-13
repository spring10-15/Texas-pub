extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
var failures: Array[String] = []
var evaluated := 0
var valid := 0
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
	var report := {"evaluated":evaluated,"validQuotes":valid,"failed":failures.size(),"failures":failures,"scope":"Cash 0..200, heat 0..6, four venues, six exit kinds; known routes and one valuable. Not full state-transition coverage."}
	FileAccess.open("res://../output/3d/extraction-conservation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("EXTRACTION_CONSERVATION ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
