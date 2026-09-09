extends RefCounted
## Connected back-of-house spaces. Coordinates are local to the tavern.
static func sign_at(w: Node3D, room: Node3D, value: String, pos: Vector3, yaw := 0.0) -> void:
	var sign := Label3D.new()
	sign.text = value
	var kind: String = {"预约接应 · 货梯":"fixed", "后厨出口":"service-stairs", "河边接驳":"river-launch", "← 后厨楼梯    库房 ↑    装卸码头 →":"directions"}.get(value, "")
	if not kind.is_empty():
		sign.set_meta("route_kind", kind)
	sign.font_size = 44
	sign.pixel_size = 0.002
	sign.double_sided = false
	sign.position = pos
	sign.rotation.y = yaw
	room.add_child(sign)

static func build(w: Node3D, room: Node3D) -> void:
	# A narrow service hall opens into a cross corridor, then three separate wings.
	w.box(room, "ServiceHall", Vector3(0, -0.12, -4.7), Vector3(2, 0.24, 2.6), "floor")
	for x in [-1.0, 1.0]:
		w.box(room, "HallWall", Vector3(x, 1.5, -4.7), Vector3(0.16, 3, 2.6), "wall")
	w.box(room, "CrossHall", Vector3(0, -0.12, -7), Vector3(8, 0.24, 2), "floor")
	for x in [-2.5, 2.5]:
		w.box(room, "CrossWall", Vector3(x, 1.5, -6), Vector3(3, 3, 0.16), "wall")
	for x in [-4.0, 4.0]:
		w.box(room, "HallEnd", Vector3(x, 1.5, -7), Vector3(0.16, 3, 2), "wall")
	for x in [-1.5, 1.5]:
		w.box(room, "WingDivider", Vector3(x, 1.5, -10.5), Vector3(0.16, 3, 5), "wall")
	w.box(room, "MaintenanceHatch", Vector3(-3.86, 1.1, -7), Vector3(0.08, 1.8, 1.2), "dark", false)
	w.target(room, "EmergencyCash", Vector3(-3.7, 1.45, -7), Vector3(0.15, 0.45, 1.0), "route:dropbag-cash", "检修口 · 舍弃现金撤离")
	w.target(room, "EmergencyGoods", Vector3(-3.7, 0.8, -7), Vector3(0.15, 0.45, 1.0), "route:dropbag-valuables", "检修口 · 舍弃贵重物撤离")
	sign_at(w, room, "检修口 · 紧急撤离", Vector3(-3.75, 2.2, -7), PI / 2)
	# Central storeroom and loading lift at ground level.
	w.box(room, "StoreFloor", Vector3(0, -0.12, -10.5), Vector3(3, 0.24, 5), "floor")
	w.box(room, "LiftWall", Vector3(0, 1.5, -13), Vector3(3, 3, 0.16), "wall")
	for z in [-9.0, -10.5]:
		w.box(room, "Crate", Vector3(-0.95, 0.45, z), Vector3(0.7, 0.9, 0.8), "wood")
	w.box(room, "LiftGate", Vector3(1.36, 1.1, -11), Vector3(0.1, 2.2, 1.5), "dark", false)
	for z in [-11.6, -11.3, -11.0, -10.7, -10.4]:
		w.box(room, "GateBar", Vector3(1.25, 1.1, z), Vector3(0.03, 2.1, 0.025), "brass", false)
	w.target(room, "FixedExit", Vector3(1.12, 1.2, -11), Vector3(0.15, 2, 1.4), "route:fixed", "库房侧门货梯 · 预约接应")
	# Kitchen wing: level preparation space, then a stair with a smooth collision ramp.
	w.box(room, "KitchenFloor", Vector3(-2.75, -0.12, -8.5), Vector3(2.5, 0.24, 1), "floor")
	w.box(room, "KitchenWall", Vector3(-4, 2, -10.5), Vector3(0.16, 4, 5), "wall")
	for i in range(12):
		var h := (i + 1) * 0.1
		w.box(room, "StairTread", Vector3(-2.75, h - 0.06, -9.125 - i * 0.25), Vector3(2.4, 0.12, 0.25), "wood", false)
	var stairs: Node3D = w.box(room, "StairRamp", Vector3(-2.75, 0.51, -10.5), Vector3(2.45, 0.18, 3.24), "dark")
	stairs.rotation.x = atan(1.2 / 3.0)
	stairs.get_child(0).hide()
	w.box(room, "UpperLanding", Vector3(-2.75, 1.08, -12.5), Vector3(2.5, 0.24, 1), "floor")
	w.box(room, "UpperExitWall", Vector3(-2.75, 2.7, -13), Vector3(2.5, 3, 0.16), "wall")
	w.box(room, "UpperDoor", Vector3(-2.75, 2.3, -12.84), Vector3(1.2, 2.2, 0.12), "green", false)
	w.target(room, "KitchenExit", Vector3(-2.75, 2.3, -12.65), Vector3(1.2, 2, 0.15), "route:service-stairs", "后厨楼梯 · 屋后出口")
	w.box(room, "PrepCounter", Vector3(-3.65, 0.48, -8.55), Vector3(0.5, 0.96, 0.7), "cloth")
	w.box(room, "Sink", Vector3(-3.65, 1.0, -8.55), Vector3(0.45, 0.08, 0.6), "dark", false)
	w.box(room, "WaterPipe", Vector3(-3.83, 1.3, -8.55), Vector3(0.06, 0.5, 0.06), "brass", false)
	# Loading corridor descends to a lower river quay.
	var ramp: Node3D = w.box(room, "LoadingRamp", Vector3(2.75, -0.69, -10), Vector3(2.5, 0.18, 4.18), "floor")
	ramp.rotation.x = -atan(1.2 / 4.0)
	w.box(room, "DockFloor", Vector3(2.75, -1.32, -13), Vector3(2.5, 0.24, 2), "wood")
	w.box(room, "LoadingWall", Vector3(4, 0.7, -10), Vector3(0.16, 3, 4), "wall")
	w.box(room, "DockRail", Vector3(4, -0.55, -13), Vector3(0.1, 1.3, 2), "brass")
	w.box(room, "QuayEnd", Vector3(2.75, -0.65, -14), Vector3(2.5, 1.1, 0.16), "wood")
	w.box(room, "River", Vector3(2.75, -1.45, -16), Vector3(5, 0.1, 4), "green", false)
	w.box(room, "LaunchHull", Vector3(2.7, -1.25, -15), Vector3(1.4, 0.5, 2.4), "dark", false)
	w.target(room, "RiverExit", Vector3(2.75, -0.2, -13.75), Vector3(1.6, 1.6, 0.15), "route:river-launch", "装卸码头 · 河边接驳")
	for z in [-12.4, -13.6]:
		w.box(room, "DockPost", Vector3(3.9, -0.4, z), Vector3(0.16, 1.6, 0.16), "wood", false)
	w.box(room, "LaunchSeat", Vector3(2.7, -0.95, -15.1), Vector3(1.25, 0.12, 0.35), "wood", false)
	w.box(room, "LaunchBow", Vector3(2.7, -0.9, -16), Vector3(0.7, 0.35, 0.2), "wood", false)
	# Ceilings and fixtures articulate the different elevations.
	w.box(room, "HallCeiling", Vector3(0, 3.1, -5.7), Vector3(8, 0.2, 4.6), "dark", false)
	w.box(room, "StoreCeiling", Vector3(0, 3.1, -10.5), Vector3(3, 0.2, 5), "dark", false)
	w.box(room, "KitchenCeiling", Vector3(-2.75, 3.1, -8.5), Vector3(2.5, 0.2, 1), "dark", false)
	var stair_roof: Node3D = w.box(room, "StairCeiling", Vector3(-2.75, 3.7, -10.5), Vector3(2.5, 0.2, 3.24), "dark", false)
	stair_roof.rotation.x = atan(1.2 / 3.0)
	w.box(room, "LoadingCeiling", Vector3(2.75, 2.5, -10), Vector3(2.5, 0.2, 4), "dark", false)
	w.box(room, "UpperCeiling", Vector3(-2.75, 4.3, -12.5), Vector3(2.5, 0.2, 1), "dark", false)
	for pos in [Vector3(0, 2.6, -4.5), Vector3(0, 2.6, -7), Vector3(0, 2.6, -11), Vector3(-2.75, 2.7, -9), Vector3(-2.75, 3.8, -12.5)]:
		w.point_light(room, pos, Color("ffd49c"), 1.1, 4)
	w.point_light(room, Vector3(2.75, 1.2, -12.5), Color("92bddf"), 1.4, 5)
	sign_at(w, room, "后勤通道", Vector3(0, 2.5, -3.35))
	sign_at(w, room, "← 后厨楼梯    库房 ↑    装卸码头 →", Vector3(0, 2.5, -7.9))
	sign_at(w, room, "预约接应 · 货梯", Vector3(1.20, 2.45, -11), -PI / 2)
	sign_at(w, room, "后厨出口", Vector3(-2.75, 3.65, -12.75))
	sign_at(w, room, "河边接驳", Vector3(2.75, 0.65, -13.85))
