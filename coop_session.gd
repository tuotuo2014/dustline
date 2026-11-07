extends Node
## Real co-op over ENet or an HTTPS WebSocket relay. Player 1 owns the world.
const PROTOCOL := 4
const MAX_PLAYERS := 4
const Avatar = preload("res://coop_avatar.gd")
const Invite = preload("res://coop_invite.gd")
const RelayPeer = preload("res://coop_relay_peer.gd")
var relay_url := ""
var room_code := ""
var _relay_host := false
var discovery: Node
var host_port := 24567
var game: Node3D
var enabled := false
var connecting := false
var in_round := false
var message := "创建房间，或输入房主 IP 和端口加入。"
var members: Dictionary = {}
var avatars: Dictionary = {}
var actor_skills: Dictionary = {}
var actor_guns: Dictionary = {}
var pickup_nodes: Dictionary = {}
var room_region := 0
var room_mode := 0
var generation := 0
var context_peer := 0
var _nickname := "幸存者"
var _saved_profile: RefCounted
var _pending_load: Dictionary = {}
var _clock := 0.0
var _timeout := 0.0
var _last_pose: Dictionary = {}
var _last_action: Dictionary = {}
var _damage_target := 1
var _loading := false
var _leaving := false
var team: Node
var squad_profile: RefCounted
var _squad_round_id := ""
var _squad_settlement: Dictionary = {}
var _round_party_size := 0
var _heartbeats: Dictionary = {}
var _heartbeat_clock := 0.0
var _last_server_message := 0
var _round_roster: Dictionary = {}


func _ready() -> void:
	squad_profile=game.Profile.new(str(game.profile.save_path)+".coop.json")
	team=preload("res://coop_teamplay.gd").new()
	team.name="Teamplay"
	team.net=self
	team.game=game
	add_child(team)
	relay_url=OS.get_environment("DUSTLINE_RELAY_URL")
	if OS.has_feature("web"):
		message="创建房间邀请朋友，或输入朋友的 6 位房间码加入。"
		relay_url=str(JavaScriptBridge.eval("location.origin.replace(/^http/, 'ws') + '/multiplayer'"))
	discovery=preload("res://coop_discovery.gd").new()
	discovery.session=self
	add_child(discovery)
	multiplayer.peer_disconnected.connect(_peer_left)
	multiplayer.peer_connected.connect(_configure_peer)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func(): leave_room(_connection_error("连接失败：请检查网络或游戏网址后重试。")))
	multiplayer.server_disconnected.connect(func(): leave_room(_connection_error("房主已离线，组队行动已结束。")))

func uses_relay() -> bool:
	return OS.has_feature("web") or not relay_url.is_empty()
func _connection_error(fallback: String) -> String:
	var peer = multiplayer.multiplayer_peer
	return peer.last_error if peer is RelayPeer and not peer.last_error.is_empty() else fallback
func set_relay_url(value: String) -> void:
	if enabled or connecting: return
	var url := value.strip_edges().trim_suffix("/")
	if url.begins_with("https://"): url="wss://"+url.substr(8)
	elif url.begins_with("http://"): url="ws://"+url.substr(7)
	if not url.is_empty() and not url.ends_with("/multiplayer"): url+="/multiplayer"
	relay_url=url
func online_invite() -> String:
	var base := relay_url.trim_suffix("/multiplayer")
	if base.begins_with("wss://"): base="https://"+base.substr(6)
	elif base.begins_with("ws://"): base="http://"+base.substr(5)
	return base+"/?room="+room_code
func _start_relay(value: String, code: String, hosting: bool) -> Error:
	_nickname=clean_name(value)
	_relay_host=hosting
	room_code=""
	var peer := RelayPeer.new()
	peer.room_ready.connect(_relay_ready)
	var error: Error=peer.open(relay_url,hosting,code)
	if error!=OK:
		message="无法连接游戏房间，请检查游戏网址和网络。"
		return error
	connecting=true
	_timeout=60
	message="正在创建真人房间…" if hosting else "正在加入真人房间…"
	multiplayer.multiplayer_peer=peer
	return OK
func _relay_ready(code: String) -> void:
	if OS.get_environment("DUSTLINE_NETWORK_TRACE")=="1": print("NET relay ready hosting=",_relay_host," code=",code)
	room_code=code
	if not _relay_host: return
	connecting=false
	enabled=true
	_timeout=0
	room_region=game._selected_region
	room_mode=game.mode
	members={1:new_member(_nickname,game.player.character_id,squad_profile.level(game.player.character_id))}
	members[1].ready=true
	message="房间 %s 已创建 · 把房间号或邀请链接发给朋友，等待真人加入。"%room_code
func _lock_online(locked: bool) -> void:
	if is_host() and multiplayer.multiplayer_peer is RelayPeer:
		multiplayer.multiplayer_peer.refuse_new_connections=locked

func _configure_peer(id: int) -> void:
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer==null or (not multiplayer.is_server() and id!=1): return
	var connection := peer.get_peer(id)
	if connection!=null: connection.set_timeout(32,60000,120000)

func is_host() -> bool: return enabled and multiplayer.is_server()
func local_id() -> int: return multiplayer.get_unique_id() if enabled else 1
func client_round() -> bool: return in_round and not is_host()
func can_connect() -> bool:
	if enabled or connecting: return false
	if game.round_started and not game.round_over:
		message="请先完成或放弃当前单人行动，再进入组队房间。"
		return false
	return true
func clean_name(value: String) -> String:
	var result := value.strip_edges().replace("\n"," ").replace("\r"," ").replace("\t"," ").left(16)
	return result if not result.is_empty() else "幸存者"
func new_member(value: String, character: int, rank: int = 1) -> Dictionary:
	rank=clampi(rank,1,5)
	return {"name":clean_name(value),"character":clampi(character,0,game.player.CharacterCatalog.CHARACTERS.size()-1),"rank":rank,"max_hp":100.0+15*(rank-1),"ready":false,"hp":100.0+15*(rank-1),"ammo":30,"grace":0.0,"repel":0.0,"rtt":0}
func host_room(value: String, port: int = 24567) -> Error:
	if not can_connect(): return ERR_BUSY
	if uses_relay(): return _start_relay(value,"",true)
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port,MAX_PLAYERS-1,3)
	if error!=OK:
		message="无法创建房间：端口可能已被占用，请更换端口。"
		return error
	multiplayer.multiplayer_peer=peer
	enabled=true
	room_region=game._selected_region
	room_mode=game.mode
	members={1:new_member(value,game.player.character_id,squad_profile.level(game.player.character_id))}
	members[1].ready=true
	host_port=port
	discovery.advertise()
	var addresses: Array[String]=Invite.local_addresses()
	message="房间已创建 · %s · 端口 %d · 等待队友准备"%[" / ".join(addresses) if not addresses.is_empty() else "127.0.0.1",port]
	return OK
func join_room(value: String, address: String, port: int = 24567) -> Error:
	if not can_connect(): return ERR_BUSY
	if uses_relay():
		var code := address.strip_edges()
		if "?room=" in code: code=code.split("?room=",false,1)[1].split("&",false,1)[0]
		code=code.to_upper()
		var valid_code := code.length()==6
		for symbol in code:
			if symbol not in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789": valid_code=false
		if not valid_code:
			message="请输入朋友的 6 位房间号，或粘贴完整邀请链接。"
			return ERR_INVALID_PARAMETER
		return _start_relay(value,code,false)
	var endpoint := Invite.parse(address,port)
	if endpoint.is_empty():
		message="请输入有效的房主地址，或粘贴完整邀请地址。端口范围为 1024–65535。"
		return ERR_INVALID_PARAMETER
	_nickname=clean_name(value)
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(endpoint.address,endpoint.port,3)
	if error!=OK:
		message="无法连接，请检查地址和端口。"
		return error
	multiplayer.multiplayer_peer=peer
	connecting=true
	_timeout=12
	message="正在连接房主…"
	return OK
func _connected() -> void:
	if OS.get_environment("DUSTLINE_NETWORK_TRACE")=="1": print("NET connected hello rank=",squad_profile.level(game.player.character_id))
	connecting=false
	enabled=true
	_timeout=45
	message="已连接，正在加入小队…"
	_hello.rpc_id(1,PROTOCOL,_nickname,game.player.character_id,squad_profile.level(game.player.character_id))
@rpc("any_peer","call_remote","reliable")
func _hello(version: int, value: String, character: int, rank: int) -> void:
	if OS.get_environment("DUSTLINE_NETWORK_TRACE")=="1": print("NET hello version=",version," host=",is_host()," sender=",multiplayer.get_remote_sender_id())
	if not is_host(): return
	var sender := multiplayer.get_remote_sender_id()
	if members.has(sender): return
	if version!=PROTOCOL or in_round or _loading or members.size()>=MAX_PLAYERS:
		_rejected.rpc_id(sender,"房间正在行动、人数已满，或游戏版本不同。请等房主回到大厅后再加入。")
		return
	members[sender]=new_member(value,character,rank)
	_lobby_state.rpc(members,room_region,room_mode)
@rpc("authority","call_remote","reliable")
func _rejected(reason: String) -> void: leave_room(reason)
@rpc("authority","call_local","reliable")
func _lobby_state(data: Dictionary, region: int, mode: int) -> void:
	room_region=region
	room_mode=mode
	members=data.duplicate(true)
	_timeout=0
	if not is_host(): message="已加入小队 · 点击准备，等待房主开始行动。"
func toggle_ready() -> void:
	if not enabled or in_round or _loading or not members.has(local_id()): return
	if is_host():
		members[1].ready=not members[1].ready
		_lobby_state.rpc(members,room_region,room_mode)
	else: _ready_request.rpc_id(1,not members[local_id()].ready)
@rpc("any_peer","call_remote","reliable")
func _ready_request(value: bool) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not is_host() or not members.has(sender) or in_round or _loading: return
	members[sender].ready=value
	_lobby_state.rpc(members,room_region,room_mode)
func start_expedition(region: int, mode: int) -> bool:
	if not is_host() or in_round or _loading: return false
	if not retry_squad_settlement(): return false
	if members.size()<2:
		message="还需要一位真人队友。请复制邀请地址，或让朋友在附近房间中加入。"
		return false
	for member in members.values():
		if not member.ready:
			message="请等待所有小队成员点击准备。"
			return false
	room_region=clampi(region,0,3)
	room_mode=clampi(mode,0,2)
	generation+=1
	_pending_load.clear()
	for id in members: _pending_load[id]=true
	_loading=true
	_lock_online(true)
	_timeout=120
	for id in multiplayer.get_peers(): _configure_peer(id)
	_prepare.rpc(generation,clampi(region,0,3),clampi(mode,0,2),members)
	return true
@rpc("authority","call_local","reliable")
func _prepare(serial: int, region: int, mode: int, roster: Dictionary) -> void:
	generation=serial
	_loading=true
	_timeout=120
	if not is_host(): _configure_peer(1)
	members=roster.duplicate(true)
	in_round=false
	_clear_actors()
	if _saved_profile==null:
		_saved_profile=game.profile
		game.profile=game.Profile.new(str(squad_profile.save_path)+".loadout")
		game.profile.read_only=true
		game.profile.owned.assign(["repulsor"])
		game.profile.equipped="repulsor"
	if not retry_squad_settlement():
		_report_load_failure("联机收益尚未保存，请在大厅重试保存。")
		return
	var departure: Dictionary=squad_profile.begin_expedition()
	if not departure.ok:
		_report_load_failure(departure.message)
		return
	_squad_round_id=departure.id
	_round_party_size=members.size()
	_round_roster=members.duplicate(true)
	team.reset()
	game.profile.levels.assign(squad_profile.levels)
	game.expedition.reset("")
	game.region_id=region
	game._selected_region=region
	game.region=game.Layout.expedition(region)
	game.player.select_character(members[local_id()].character)
	game.hud.set_character_selected(members[local_id()].character)
	game._prepare_round(mode)
	await get_tree().process_frame
	if not enabled or generation!=serial: return
	game.round_started=true
	game.round_over=false
	game.round_ammo=30
	game.medkits=2*members.size()
	game.flares=members.size()
	pickup_nodes.clear()
	for i in game.pickups.size():
		var item: Area3D=game.pickups[i]
		item.set_meta("network_id",i)
		pickup_nodes[i]=item
	var slot := 0
	for id in members.keys():
		if not members.has(id): continue
		members[id].hp=members[id].max_hp
		members[id].ammo=30
		members[id].grace=3.0
		members[id].repel=0.0
		var spawn: Vector3=game._ground(Vector3(game.region.base)+Vector3((slot%2)*2.0-1.0,0,1.0-floori(slot/2.0)*2.0))
		slot+=1
		if id==local_id():
			game.player.reset_for_round(spawn)
			continue
		var avatar := Avatar.new()
		avatar.name="Peer_%d"%id
		avatar.peer_id=id
		avatar.nickname=members[id].name
		game.add_child(avatar)
		avatar.select_character(members[id].character)
		avatar.set_pose(spawn,0,Vector3.ZERO,true,true)
		avatars[id]=avatar
		var skill: Node3D=game.Skills.new()
		skill.game=game
		add_child(skill)
		actor_skills[id]=skill
		var gun: Node3D=game.Firearm.new()
		gun.game=game
		add_child(gun)
		gun.set_physics_process(false)
		actor_guns[id]=gun
		_with_actor(id,func(): gun.reset_round())
		await get_tree().process_frame
		if not enabled or generation!=serial: return
	in_round=true
	game.active=false
	game.player.set_controls_enabled(false)
	game.hud._coop_panel.hide()
	game.hud.show_game()
	message="正在等待队友加载地图…"
	game._update_hud()
	if is_host(): _loaded_local(1)
	else: _loaded.rpc_id(1,generation)
@rpc("any_peer","call_remote","reliable")
func _loaded(serial: int) -> void:
	if is_host() and serial==generation: _loaded_local(multiplayer.get_remote_sender_id())
func _loaded_local(id: int) -> void:
	_pending_load.erase(id)
	if _pending_load.is_empty() and _loading:
		_loading=false
		_timeout=0
		_launch.rpc(generation)
@rpc("authority","call_local","reliable")
func _launch(serial: int) -> void:
	if serial!=generation: return
	_loading=false
	_timeout=0
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	for id in multiplayer.get_peers():
		if not is_host() and id!=1: continue
		if peer!=null:
			var connection := peer.get_peer(id)
			if connection!=null: connection.set_timeout(32,5000,15000)
	_last_server_message=Time.get_ticks_msec()
	for id in members: _heartbeats[id]=Time.get_ticks_msec()
	game.active=true
	game.player.set_controls_enabled(true)
	game.hud.show_game()
	message="小队行动中 · 菜单不会暂停世界"
	game._show_toast("真人小队出发：G 标物资 · H 标危险 · T 集合；靠近倒下队友按 E 开始 3 秒救援。",8)
	game._update_hud()

func actor(id: int) -> CharacterBody3D:
	return game.player if id==local_id() else avatars.get(id)
func _with_actor(id: int, callback: Callable) -> Variant:
	if not members.has(id): return null
	var target: CharacterBody3D=actor(id)
	if not is_instance_valid(target): return null
	var saved := [game.player,game.health,game.max_health,game.round_ammo,game.skills,game.arsenal,game.damage_grace,game._repel_cooldown,context_peer]
	game.player=target
	game.health=float(members[id].hp)
	game.max_health=float(members[id].max_hp)
	game.round_ammo=int(members[id].ammo)
	game.damage_grace=float(members[id].grace)
	game._repel_cooldown=float(members[id].repel)
	if id!=local_id():
		game.skills=actor_skills[id]
		game.arsenal=actor_guns[id]
	context_peer=id
	var result: Variant=callback.call()
	members[id].hp=game.health
	members[id].ammo=game.round_ammo
	members[id].grace=game.damage_grace
	members[id].repel=game._repel_cooldown
	game.player=saved[0]
	game.health=saved[1]
	game.max_health=saved[2]
	game.round_ammo=saved[3]
	game.skills=saved[4]
	game.arsenal=saved[5]
	game.damage_grace=saved[6]
	game._repel_cooldown=saved[7]
	context_peer=saved[8]
	return result
func request_action(action: String) -> void:
	if not in_round or not game.active or not members.has(local_id()): return
	var target: Vector3=game.weapon_target() if action=="fire_weapon" else Vector3.ZERO
	if is_host(): _execute(1,action,target)
	else: _action.rpc_id(1,generation,action,target)
@rpc("any_peer","call_remote","reliable")
func _action(serial: int, action: String, target: Vector3 = Vector3.ZERO) -> void:
	if not is_host() or serial!=generation: return
	if not target.is_finite(): return
	_execute(multiplayer.get_remote_sender_id(),action,target)
func _execute(id: int, action: String, target: Vector3 = Vector3.ZERO) -> void:
	if not in_round or not game.active or not members.has(id) or members[id].hp<=0: return
	if action not in ["interact","heal","build_shelter","repel","character_skill","fire_weapon"]: return
	if action=="fire_weapon" and (not target.is_finite() or actor(id).global_position.distance_to(target)>250.0): return
	var now := Time.get_ticks_msec()
	var action_key := str(id)+":"+action
	if now-int(_last_action.get(action_key,0))<80: return
	_last_action[action_key]=now
	if action=="interact":
		for other in members:
			if other==id or members[other].hp>0: continue
			if actor(id).global_position.distance_to(actor(other).global_position)<3.2:
				team.begin_rescue(id,other)
				return
	if action!="interact": team.cancel_rescue(id)
	_with_actor(id,func():
		match action:
			"interact": game.interact()
			"heal": game.use_medkit()
			"build_shelter": game.build_shelter()
			"repel": game.repel_mutants()
			"character_skill":
				if game.skills.activate():
					_effect.rpc(id,"skill",game.player.global_position,Vector3.ZERO)
					if game.player.character_id==0: team.share_scan(game.player.global_position)
			"fire_weapon":
				if game.arsenal.fire(target): _effect.rpc(id,"shot",game.player.global_position+Vector3(0,1.2,0),game.arsenal.last_impact)
	)
	_sync_local()
	game._update_hud()

func tick(delta: float) -> void:
	if not is_host() or not in_round or not game.active: return
	for id in members:
		members[id].grace=maxf(0,float(members[id].grace)-delta)
		members[id].repel=maxf(0,float(members[id].repel)-delta)
		if members[id].hp<=0: continue
		_with_actor(id,func():
			game.skills.tick(delta)
			game.arsenal.tick(delta)
			if id!=1:
				for pickup in game.pickups.duplicate():
					if is_instance_valid(pickup) and not pickup.is_queued_for_deletion() and game.player.global_position.distance_to(pickup.global_position)<1.5: game._collect(pickup)
		)
		if id!=1 and game.storm_active and not game.is_sheltered(actor(id).global_position): damage(id,2.8*delta,false)
	team.tick(delta)
	_sync_local()
func target_for(wolf: CharacterBody3D) -> CharacterBody3D:
	var nearest: CharacterBody3D=game.player
	var best := INF
	var chosen := 1
	for id in members:
		if members[id].hp<=0: continue
		var candidate := actor(id)
		if not is_instance_valid(candidate): continue
		var distance := wolf.global_position.distance_squared_to(candidate.global_position)
		if game.is_sheltered(candidate.global_position): distance+=100000
		if distance<best:
			best=distance
			nearest=candidate
			chosen=id
	_damage_target=chosen
	return nearest
func damage(id: int, amount: float, bite: bool) -> void:
	if not is_host() or not in_round or not game.active or not members.has(id): return
	if members[id].hp<=0 or members[id].grace>0 or amount<=0: return
	if bite and actor(id).is_dashing(): return
	team.cancel_rescue(id,"受到攻击，救援已中断。")
	members[id].hp=maxf(0,float(members[id].hp)-amount)
	if bite:
		members[id].grace=1.0
		tell(id,"被狼兽扑咬！Q 治疗，F 驱兽。")
	if members[id].hp<=0: _feedback.rpc("%s 已倒下，队友靠近按 E 持续救援 3 秒。"%members[id].name)
	_sync_local()
	if members.values().all(func(member): return member.hp<=0): finish(false,"小队全员倒下","所有队员失去行动能力，本次行动结束。")
func _sync_local() -> void:
	if not members.has(local_id()): return
	var member: Dictionary=members[local_id()]
	game.health=member.hp
	game.max_health=float(member.max_hp)
	game.round_ammo=member.ammo
	var controls: bool=game.active and game.hud._hud.visible and not game.hud._coop_panel.visible and member.hp>0
	if game.player.controls_enabled!=controls: game.player.set_controls_enabled(controls)
	for id in avatars:
		if members.has(id):
			avatars[id].label.text=members[id].name+(" · 倒下 [E 救援]" if members[id].hp<=0 else " · %d HP"%members[id].hp)
			avatars[id].character.rotation.z=PI*.45 if members[id].hp<=0 else 0.0
			if members[id].hp<=0: avatars[id].velocity=Vector3.ZERO
	game.hud._team_status.text="小队 %d / 4 · %s"%[members.size(),"倒下：等待队友救援" if member.hp<=0 else team.status_text()]
	game.hud._bank.text="联机资产 %d G · 独立成长 Lv.%d"%[squad_profile.assets,squad_profile.level(game.player.character_id)]
func tell(id: int, value: String) -> void:
	if id==local_id():
		game.toast=value
		game.toast_remaining=3
	else: _feedback.rpc_id(id,value)
@rpc("authority","call_local","reliable")
func _feedback(value: String) -> void:
	game.toast=value
	game.toast_remaining=4
@rpc("authority","call_remote","reliable")
func _effect(id: int, kind: String, from: Vector3, to: Vector3) -> void:
	if not in_round: return
	if kind=="shot":
		game.arsenal._spawn_tracer(from,to)
		_with_actor(id,func():
			game.arsenal.cooldown=.75
			game.arsenal.aim_remaining=.68
			game.arsenal.flash_remaining=.08
			var direction := (to-from).normalized()
			game.arsenal._shot_yaw=atan2(-direction.x,-direction.z)
			game.arsenal._shot_pitch=asin(clampf(direction.y,-1,1))
			game.arsenal._apply_firing_pose()
		)
	elif kind=="skill":
		game.skills._pulse(from,Color("77e4dd"),12,.65)
		_with_actor(id,func():
			if game.player.character_id==2: game.player.begin_dash()
			if game.player.character_id==1: game.player.play_shock_action()
			if game.player.character_id==3:
				game.skills.cancel_active()
				game.skills.active_id=3
				game.skills.active_remaining=12.0
				game.skills._make_drone()
		)

func _process(delta: float) -> void:
	_poll_health(delta)
	if _timeout>0:
		_timeout-=delta
		if _timeout<=0 and (connecting or _loading or members.is_empty()): leave_room("等待连接或地图加载超时，请检查网络后重新建房。")
	if not in_round or not enabled or not game.active: return
	_clock+=delta
	if _clock<.066: return
	_clock=0
	if is_host():
		var data := make_snapshot()
		_snapshot.rpc(generation,var_to_bytes(data).compress(FileAccess.COMPRESSION_DEFLATE))
	else:
		_pose.rpc_id(1,generation,game.player.global_position,game.player.get_node("Body").rotation.y,game.player.velocity if game.player.controls_enabled else Vector3.ZERO,game.player.is_on_floor(),game.player.camera_yaw)
@rpc("any_peer","call_remote","unreliable_ordered",1)
func _pose(serial: int, pos: Vector3, yaw: float, motion: Vector3, grounded: bool, camera_yaw: float) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_host() or not in_round or serial!=generation or not avatars.has(id) or not members.has(id): return
	if not pos.is_finite() or not motion.is_finite() or not is_finite(yaw) or not is_finite(camera_yaw): return
	var avatar: CharacterBody3D=avatars[id]
	if members[id].hp<=0: return
	var now := Time.get_ticks_msec()
	var interval := clampf((now-int(_last_pose.get(id,now-100)))/1000.0,.05,.5)
	_last_pose[id]=now
	var max_step := interval*(30 if avatar.is_dashing() else 11)+1.5
	if avatar.target_position.distance_to(pos)>max_step or not game.Layout.inside_playable(pos,0,game.region_id) or absf(pos.y-game.world.ground_height(pos.x,pos.z))>12:
		_correct.rpc_id(id,generation,avatar.target_position)
		return
	avatar.camera_yaw=camera_yaw
	avatar.set_pose(pos,yaw,motion.limit_length(32),grounded)
@rpc("authority","call_remote","reliable")
func _correct(serial: int, pos: Vector3) -> void:
	if generation==serial and in_round: game.player.global_position=pos
func make_snapshot() -> Dictionary:
	var poses: Dictionary={}
	for id in members:
		var body := actor(id)
		if not is_instance_valid(body): continue
		var skill: Node3D=game.skills if id==1 else actor_skills[id]
		poses[id]={"p":body.global_position,"yaw":body.get_node("Body").rotation.y,"v":body.velocity if (id!=1 or body.controls_enabled) and members[id].hp>0 else Vector3.ZERO,"floor":game.actor_grounded(body),"hp":members[id].hp,"ammo":members[id].ammo,"cd":skill.cooldowns.duplicate(),"rtt":members[id].rtt}
	var wolves: Array=[]
	for wolf in game.mutants: wolves.append([wolf.global_position,wolf.rotation.y,wolf.velocity,wolf.state])
	var remaining: Array[int]=[]
	for item in game.pickups:
		if is_instance_valid(item) and not item.is_queued_for_deletion(): remaining.append(item.get_meta("network_id",-1))
	var relay_states: Array[bool]=[]
	for relay in game.relays: relay_states.append(relay.get_meta("active",false))
	var shelter_positions: Array[Vector3]=[]
	for shelter in game.shelters: shelter_positions.append(shelter.global_position)
	var flares: Array=[]
	for flare in game.flare_nodes: flares.append([flare.global_position,flare.get_meta("remaining",0)])
	return {"poses":poses,"wolves":wolves,"remaining":remaining,"relays":relay_states,"shelters":shelter_positions,"flares":flares,"scrap":game.scrap,"medkits":game.medkits,"flare_count":game.flares,"elapsed":game.elapsed,"storm":game.storm_active,"repaired":game.repaired,"bag":game.expedition.bag_value,"items":game.expedition.bag_items,"collected":game.collected,"team":team.snapshot()}
@rpc("authority","call_remote","unreliable_ordered",2)
func _snapshot(serial: int, packet: PackedByteArray) -> void:
	if not in_round or serial!=generation: return
	var decoded: Variant=bytes_to_var(packet.decompress_dynamic(262144,FileAccess.COMPRESSION_DEFLATE))
	if not decoded is Dictionary: return
	var data: Dictionary=decoded
	_last_server_message=Time.get_ticks_msec()
	team.apply_snapshot(data.get("team",{}))
	for id in data.poses:
		if not members.has(id): continue
		var pose: Dictionary=data.poses[id]
		members[id].hp=pose.hp
		members[id].ammo=pose.ammo
		members[id].rtt=pose.get("rtt",0)
		if id==local_id(): game.skills.cooldowns=pose.cd
		elif avatars.has(id): avatars[id].set_pose(pose.p,pose.yaw,pose.v,pose.floor)
	for i in mini(game.mutants.size(),data.wolves.size()):
		var wolf: CharacterBody3D=game.mutants[i]
		var state: Array=data.wolves[i]
		wolf.set_meta("network_target",state[0])
		wolf.set_meta("network_yaw",state[1])
		if wolf.global_position.distance_to(state[0])>12: wolf.global_position=state[0]
		wolf.velocity=state[2]
		wolf._set_state(state[3])

	for key in pickup_nodes.keys():
		if key in data.remaining: continue
		var item: Area3D=pickup_nodes[key]
		if is_instance_valid(item):
			item.set_meta("taken",true)
			game.pickups.erase(item)
			item.queue_free()
		pickup_nodes.erase(key)
	for i in game.relays.size():
		if game.relays[i].get_meta("active",false)!=data.relays[i]: game.Props.set_relay_active(game.relays[i],data.relays[i])
	while game.shelters.size()<data.shelters.size():
		var shelter: Node3D=game.Props.shelter(false)
		shelter.position=data.shelters[game.shelters.size()]
		game.round_root.add_child(shelter)
		game.shelters.append(shelter)
	while game.flare_nodes.size()>data.flares.size():
		var old: Node3D=game.flare_nodes.pop_back()
		old.queue_free()
	while game.flare_nodes.size()<data.flares.size():
		var flare := Node3D.new()
		flare.add_child(game.Effects.flare())
		game.round_root.add_child(flare)
		game.flare_nodes.append(flare)
	for i in data.flares.size():
		game.flare_nodes[i].global_position=data.flares[i][0]
		game.flare_nodes[i].set_meta("remaining",data.flares[i][1])
	game.scrap=data.scrap
	game.medkits=data.medkits
	game.flares=data.flare_count
	game.elapsed=data.elapsed
	game.repaired=data.repaired
	game.collected=data.collected
	game.expedition.bag_value=data.bag
	game.expedition.bag_items=data.items
	if game.storm_active!=data.storm:
		game.storm_active=data.storm
		game._set_weather(data.storm)
	_sync_local()
	game._update_hud()
func finish(success: bool, title: String, summary: String) -> void:
	if not is_host() or not in_round or game.round_over: return
	_finished.rpc(generation,success,title,summary,game.expedition.bag_value,game.repaired,game.elapsed,game.collected,game.expedition.bag_items)
@rpc("authority","call_local","reliable")
func _finished(serial: int, success: bool, title: String, summary: String, value: int, repaired: int, elapsed: float, collected: int, items: int) -> void:
	if serial!=generation or not in_round or game.round_over: return
	_lock_online(false)
	game.active=false
	game.round_over=true
	game.won=success
	game.player.set_controls_enabled(false)
	var reward := (100+floori(float(value)/maxi(1,_round_party_size))) if success else 0
	_squad_settlement={"id":_squad_round_id,"success":success,"value":reward}
	var saved := retry_squad_settlement()
	var details := {"context":game.region.name+"  /  真人小队 · %d 人"%members.size(),
		"stats":["行动用时|"+game._time(elapsed),"回收零件|%d"%collected,"修复信标|%d 座"%repaired],
		"cash":(("小队带回 %d 件战利品 · %d G" if success else "小队遗失 %d 件战利品 · %d G")%[items,value])+"\n你的联机收益 +%d G"%reward,
		"equipment":"本局使用小队配发装备；营地购买的装备未带入联机。",
		"notice":("每人平分战利品 + 完成奖励 100 G；你的收益 +%d G · 联机余额 %d G"%[reward,squad_profile.assets]) if saved else "联机收益暂未保存：返回组队大厅重试，保存前无法再次出发。","saved":saved}
	game.hud.show_result(success,title,summary,details)
	in_round=false
	message="本次行动结束。返回组队大厅可再次出发。"
func _peer_left(id: int) -> void:
	if _leaving or not enabled: return
	members.erase(id)
	_pending_load.erase(id)
	_remove_actor(id)
	if is_host():
		_removed.rpc(id)
		if not in_round: _lobby_state.rpc(members,room_region,room_mode)
		elif _loading: _loaded_local(id)
		elif members.values().all(func(m): return m.hp<=0): finish(false,"小队失去行动能力","最后一名可行动的队员已离开。")
@rpc("authority","call_remote","reliable")
func _removed(id: int) -> void:
	members.erase(id)
	_remove_actor(id)
func _remove_actor(id: int) -> void:
	for collection in [actor_guns,actor_skills,avatars]:
		if collection.has(id):
			if is_instance_valid(collection[id]): collection[id].queue_free()
			collection.erase(id)
func _clear_actors() -> void:
	for id in avatars.keys(): _remove_actor(id)
	_last_pose.clear()
	_last_action.clear()
func leave_room(reason := "已离开房间") -> void:
	if _leaving: return
	_leaving=true
	discovery.stop_advertising()
	var had_session := enabled or connecting
	var reset_world := in_round or _loading or _saved_profile!=null
	enabled=false
	connecting=false
	in_round=false
	_loading=false
	_timeout=0
	if multiplayer.multiplayer_peer: multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new()
	_clear_actors()
	members.clear()
	pickup_nodes.clear()
	if not _squad_round_id.is_empty() and _squad_settlement.is_empty():
		_squad_settlement={"id":_squad_round_id,"success":false,"value":0}
	retry_squad_settlement()
	team.reset()
	_heartbeats.clear()
	if _saved_profile!=null:
		game.profile=_saved_profile
		_saved_profile=null
	if had_session:
		game.active=false
		game.round_started=false
		game.round_over=false
		if reset_world: game._prepare_round(game.mode)
		game.player.set_controls_enabled(false)
		game.hud.show_menu(false)
		game.hud._team_status.text="单人行动"
		game._refresh_economy()
		game._update_hud()
	room_code=""
	message=reason
	_leaving=false

func tick_client(delta: float) -> void:
	team.tick(delta)
	for wolf in game.mutants:
		if wolf.has_meta("network_target"):
			wolf.global_position=wolf.global_position.lerp(wolf.get_meta("network_target"),1.0-exp(-delta*16))
			wolf.rotation.y=lerp_angle(wolf.rotation.y,float(wolf.get_meta("network_yaw")),1.0-exp(-delta*16))
			wolf.visual.animate(delta,Vector2(wolf.velocity.x,wolf.velocity.z).length(),wolf.state in ["lunge","windup"])
	for id in avatars:
		_with_actor(id,func():
			game.arsenal.tick(delta)
			game.skills.tick(delta)
			if game.arsenal.aim_remaining>0: game.arsenal._apply_firing_pose()
		)
	for pad in game.extraction_points: game.Effects.tick(pad,game.elapsed)
	for flare in game.flare_nodes: game.Effects.tick(flare,8.0-float(flare.get_meta("remaining",0)))

func change_settings(region: int, mode: int) -> void:
	if not is_host() or in_round or _loading: return
	room_region=clampi(region,0,3)
	room_mode=clampi(mode,0,2)
	for id in members:
		if id!=1: members[id].ready=false
	_lobby_state.rpc(members,room_region,room_mode)

func retry_squad_settlement() -> bool:
	if _squad_settlement.is_empty(): return not squad_profile.read_only
	var result: Dictionary=squad_profile.finish_expedition(str(_squad_settlement.id),bool(_squad_settlement.success),int(_squad_settlement.value),0)
	if not result.ok:
		message=result.message
		return false
	_squad_settlement.clear()
	_squad_round_id=""
	return true

func upgrade_squad_character(character: int) -> void:
	if in_round or _loading or not retry_squad_settlement(): return
	var result: Dictionary=squad_profile.upgrade(character)
	message=result.message
	if result.ok and enabled:
		if is_host(): _member_choice(local_id(),character,squad_profile.level(character))
		else: _choice.rpc_id(1,character,squad_profile.level(character))

func choose_character(character: int) -> void:
	if in_round or _loading: return
	character=clampi(character,0,3)
	game.player.select_character(character)
	game.hud.set_character_selected(character)
	if not enabled: return
	if is_host(): _member_choice(1,character,squad_profile.level(character))
	else: _choice.rpc_id(1,character,squad_profile.level(character))

@rpc("any_peer","call_remote","reliable")
func _choice(character: int, rank: int) -> void:
	if is_host(): _member_choice(multiplayer.get_remote_sender_id(),character,rank)

func _member_choice(id: int, character: int, rank: int) -> void:
	if not members.has(id) or in_round or _loading: return
	var previous: Dictionary=members[id]
	members[id]=new_member(previous.name,clampi(character,0,3),clampi(rank,1,5))
	members[id].ready=id==1
	_lobby_state.rpc(members,room_region,room_mode)

func cooldown_for_actor() -> float:
	var id: int=context_peer if context_peer>0 else local_id()
	return 1.0-.07*(int(members.get(id,{}).get("rank",1))-1)

func _report_load_failure(reason: String) -> void:
	if is_host(): _abort_loading.rpc(generation,reason)
	else: _load_failed.rpc_id(1,generation,reason)

@rpc("any_peer","call_remote","reliable")
func _load_failed(serial: int, reason: String) -> void:
	if is_host() and _loading and serial==generation and members.has(multiplayer.get_remote_sender_id()):
		_abort_loading.rpc(serial,reason.left(160))

@rpc("authority","call_local","reliable")
func _abort_loading(serial: int, reason: String) -> void:
	if serial==generation: leave_room("行动未开始："+reason)

func connection_stalled() -> bool:
	if not enabled or not in_round or is_host(): return false
	return Time.get_ticks_msec()-_last_server_message>3000

func _poll_health(delta: float) -> void:
	if not enabled: return
	_heartbeat_clock+=delta
	if _heartbeat_clock<1.0: return
	_heartbeat_clock=0
	var now := Time.get_ticks_msec()
	if is_host():
		for id in members.keys():
			if id==1: continue
			if not _heartbeats.has(id): _heartbeats[id]=now
			if not _loading and now-int(_heartbeats[id])>20000:
				_feedback.rpc("队友连接超时，已移出小队；本轮可继续。")
				multiplayer.multiplayer_peer.disconnect_peer(id)
				_peer_left(id)
				continue
			_heartbeat.rpc_id(id,now)
	elif not _loading and _last_server_message>0 and now-_last_server_message>20000:
		leave_room("与房主失去连接，已返回菜单。本局未结算，已保存的联机资产保留。")

@rpc("authority","call_remote","reliable")
func _heartbeat(stamp: int) -> void:
	_last_server_message=Time.get_ticks_msec()
	_heartbeat_reply.rpc_id(1,stamp)

@rpc("any_peer","call_remote","reliable")
func _heartbeat_reply(stamp: int) -> void:
	if not is_host(): return
	var id := multiplayer.get_remote_sender_id()
	if not members.has(id): return
	var now := Time.get_ticks_msec()
	_heartbeats[id]=now
	members[id].rtt=clampi(now-stamp,0,20000)
