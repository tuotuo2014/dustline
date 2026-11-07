extends Node
## Cooperative decisions and shared effects are always resolved by the player host.
const RESCUE_SECONDS := 3.0
const EXTRACTION_SECONDS := 5.0
const EXTRACTION_RADIUS := 8.0
var net: Node
var game: Node3D
var pings: Dictionary = {}
var scans: Array = []
var scan_remaining := 0.0
var rescues: Dictionary = {}
var extraction: Dictionary = {}
var _ping_at: Dictionary = {}
var extraction_ring: MeshInstance3D

func reset() -> void:
	if is_instance_valid(extraction_ring): extraction_ring.queue_free()
	extraction_ring=null
	pings.clear()
	scans.clear()
	scan_remaining=0
	rescues.clear()
	extraction.clear()
	_ping_at.clear()

func request_ping(kind: String) -> void:
	if not net.in_round or not game.active or not game.player.controls_enabled: return
	var point: Vector3=game.weapon_target()
	if not point.is_finite(): return
	var origin: Vector3=game.player.global_position
	point=origin+(point-origin).limit_length(100)
	point=game._ground(point)
	if net.is_host(): add_ping(net.local_id(),kind,point)
	else: _ping_request.rpc_id(1,net.generation,kind,point)

@rpc("any_peer","call_remote","reliable")
func _ping_request(serial: int, kind: String, point: Vector3) -> void:
	if net.is_host() and serial==net.generation: add_ping(multiplayer.get_remote_sender_id(),kind,point)

func add_ping(id: int, kind: String, point: Vector3) -> void:
	if not net.is_host() or not net.in_round or not game.active or not net.members.has(id): return
	if net.members[id].hp<=0 or kind not in ["supply","danger","rally"] or not point.is_finite(): return
	if not game.Layout.inside_playable(point,0,game.region_id) or net.actor(id).global_position.distance_to(point)>105: return
	var now := Time.get_ticks_msec()
	if now-int(_ping_at.get(id,-2000))<1000: return
	_ping_at[id]=now
	_ping.rpc(net.generation,id,kind,point)

@rpc("authority","call_local","reliable")
func _ping(serial: int, id: int, kind: String, point: Vector3) -> void:
	if serial!=net.generation or not net.in_round or not net.members.has(id): return
	pings[id]={"kind":kind,"point":point,"remaining":12.0,"name":net.members[id].name}
	game._show_toast("%s：%s"%[net.members[id].name,ping_title(kind)],3)

static func ping_title(kind: String) -> String:
	return {"supply":"这里有物资","danger":"这里有危险","rally":"来这里集合"}.get(kind,"小队标记")

func visible_between(a: Vector3, b: Vector3) -> bool:
	if a.distance_squared_to(b)<.01: return true
	var exclude: Array[RID]=[]
	for id in net.members:
		var body: CharacterBody3D=net.actor(id)
		if is_instance_valid(body): exclude.append(body.get_rid())
	var query := PhysicsRayQueryParameters3D.create(a+Vector3.UP,b+Vector3.UP,1,exclude)
	return game.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func begin_rescue(id: int, other: int) -> bool:
	if not net.is_host() or not net.members.has(id) or not net.members.has(other): return false
	if net.members[id].hp<=0 or net.members[other].hp>0: return false
	var a: Vector3=net.actor(id).global_position
	var b: Vector3=net.actor(other).global_position
	if a.distance_to(b)>=3.2 or not visible_between(a,b):
		net.tell(id,"靠近倒下的队友，并确保中间没有墙壁。")
		return false
	if rescues.has(id): return true
	rescues[id]={"target":other,"remaining":RESCUE_SECONDS,"origin":a}
	net.tell(id,"正在救援，保持位置 3 秒；移动或受伤会中断。")
	return true

func cancel_rescue(id: int, reason := "救援已中断") -> void:
	if rescues.has(id):
		rescues.erase(id)
		net.tell(id,reason)

func begin_extraction(id: int, destination: Node3D) -> void:
	if not net.is_host() or not net.members.has(id) or net.members[id].hp<=0 or not game._can_extract(): return
	if not is_instance_valid(destination) or net.actor(id).global_position.distance_to(destination.global_position)>4.6: return
	if not extraction.is_empty():
		net.tell(id,"撤离已呼叫：所有队员救起后在撤离圈内集合。")
		return
	extraction={"point":destination.global_position,"remaining":EXTRACTION_SECONDS,"missing":[],"ready":0,"total":net.members.size()}
	_sync_circle()
	net._feedback.rpc("撤离已呼叫：全员进入 8 米集合圈，倒下队友需要先救起；集齐后倒计时 5 秒。")

func tick(delta: float) -> void:
	for id in pings.keys():
		pings[id].remaining-=delta
		if pings[id].remaining<=0 or not net.members.has(id): pings.erase(id)
	scan_remaining=maxf(0,scan_remaining-delta)
	if scan_remaining<=0: scans.clear()
	if not net.is_host(): return
	for id in rescues.keys():
		var rescue: Dictionary=rescues[id]
		var other: int=rescue.target
		if not net.members.has(id) or not net.members.has(other):
			rescues.erase(id)
			continue
		var a: Vector3=net.actor(id).global_position
		var b: Vector3=net.actor(other).global_position
		if net.members[id].hp<=0 or net.members[other].hp>0 or a.distance_to(rescue.origin)>.65 or a.distance_to(b)>=3.2 or not visible_between(a,b):
			cancel_rescue(id)
			continue
		rescue.remaining-=delta
		if rescue.remaining<=0:
			net.members[other].hp=minf(40,net.members[other].max_hp)
			net.members[other].grace=3.0
			rescues.erase(id)
			net._feedback.rpc("%s 已救起 %s"%[net.members[id].name,net.members[other].name])
	if extraction.is_empty(): return
	var missing: Array[String]=[]
	for id in net.members:
		if net.members[id].hp<=0: missing.append(str(net.members[id].name)+"（待救援）")
		elif net.actor(id).global_position.distance_to(extraction.point)>EXTRACTION_RADIUS: missing.append(net.members[id].name)
	extraction.missing=missing
	extraction.total=net.members.size()
	extraction.ready=net.members.size()-missing.size()
	if missing.is_empty(): extraction.remaining=maxf(0,extraction.remaining-delta)
	else: extraction.remaining=EXTRACTION_SECONDS
	if extraction.remaining<=0:
		net.finish(true,"小队安全撤离","队员全员集结，带着战利品离开了荒原。")

func share_scan(origin: Vector3) -> void:
	if not net.is_host(): return
	var points: Array=[]
	var candidates: Array=[]
	for node in game.pickups+game.relays:
		if not is_instance_valid(node) or node.is_queued_for_deletion(): continue
		if node.get_meta("taken",false) or node.get_meta("active",false) or node.global_position.distance_to(origin)>65: continue
		candidates.append(node)
	candidates.sort_custom(func(a,b): return a.global_position.distance_squared_to(origin)<b.global_position.distance_squared_to(origin))
	for node in candidates.slice(0,16):
		points.append({"point":node.global_position,"title":str(node.get_meta("display_name","信标" if node in game.relays else "物资"))})
	_scanned.rpc(net.generation,points)

@rpc("authority","call_local","reliable")
func _scanned(serial: int, points: Array) -> void:
	if serial!=net.generation or not net.in_round: return
	scans=points
	scan_remaining=10.0
	game._show_toast("行者已向全队共享 %d 处侦察结果，持续 10 秒。"%points.size(),4)

func heal_nearby(id: int, amount: float) -> void:
	if not net.is_host() or not net.members.has(id): return
	var origin: Vector3=net.actor(id).global_position
	for other in net.members:
		if net.members[other].hp<=0: continue
		var point: Vector3=net.actor(other).global_position
		if point.distance_to(origin)>8 or not visible_between(origin,point): continue
		net.members[other].hp=minf(net.members[other].max_hp,net.members[other].hp+amount)
	# The existing skill runner temporarily binds the caster's health to game.health.
	game.health=net.members[id].hp

func snapshot() -> Dictionary:
	return {"rescues":rescues.duplicate(true),"extraction":extraction.duplicate(true)}

func apply_snapshot(data: Dictionary) -> void:
	rescues=data.get("rescues",{}).duplicate(true)
	extraction=data.get("extraction",{}).duplicate(true)
	_sync_circle()

func _sync_circle() -> void:
	if extraction.is_empty() or is_instance_valid(extraction_ring): return
	extraction_ring=game.Effects.mesh_node(game.round_root,"SquadExtractionCircle",game.Effects.band(EXTRACTION_RADIUS,.13,.1,96),game.Effects.material(Color("9ce7a7"),1.5,.75))
	extraction_ring.global_position=extraction.point

func status_text() -> String:
	var id: int=net.local_id()
	if rescues.has(id): return "救援中 %.1f 秒 · 保持位置"%rescues[id].remaining
	if not extraction.is_empty():
		if extraction.missing.is_empty(): return "全员集齐 · 撤离倒计时 %.1f 秒"%extraction.remaining
		return "集合 %d/%d · 等待：%s"%[extraction.ready,extraction.total,"、".join(extraction.missing)]
	return "G 物资标记 · H 危险标记 · T 集合标记"
