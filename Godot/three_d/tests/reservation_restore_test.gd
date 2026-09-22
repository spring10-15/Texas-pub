extends SceneTree
const Run = preload("res://three_d/rules/run.gd")
const Checkpoint = preload("res://three_d/rules/run_checkpoint.gd")
var failures: Array[String] = []
var checks := 0
func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func _initialize() -> void:
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://three_d/rules/content.json"))
	for scene_id in content.scenes:
		for offer in range(2):
			var r := Run.new(content)
			r.start(r.revision,scene_id,0)
			r.offer_index = offer
			r.route_flags.fixed = true
			verify(r.service_action("reserve","",r.revision),"Create actual reservation")
			var good := Checkpoint.capture(r)
			var restored := Checkpoint.restore(good,content)
			verify(restored != null and restored.extraction_quote("fixed") == r.extraction_quote("fixed"),"Quote survives restore "+scene_id)
			var defects := {"finalCost":-1,"reserveCost":-1,"maxHeat":7,"expiresAfterSearch":0,"id":"not-a-route"}
			for field in defects:
				for missing in [false,true]:
					var bad := good.duplicate(true)
					if missing: bad.reservation.erase(field)
					else: bad.reservation[field] = defects[field]
					verify(Checkpoint.restore(bad,content) == null,"Reject invalid reservation "+field+str(missing))
			for amount in [0.5,NAN,INF,"10"]:
				var bad := good.duplicate(true)
				bad.reservation.finalCost = amount
				verify(Checkpoint.restore(bad,content) == null,"Reject malformed numeric fee")
			var expired := good.duplicate(true)
			expired.search_index = int(expired.reservation.expiresAfterSearch)+1
			restored = Checkpoint.restore(expired,content)
			verify(restored != null and restored.extraction_quote("fixed").reason == "预约已过期","Expired reservation remains expired")
	print("RESERVATION_RESTORE checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
