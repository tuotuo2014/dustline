extends SceneTree
var game: Node3D
var net: Node
var failed := 0
var checks := 0
var role := "host"
var prefix := "/private/tmp/dustline-coop-test"
var port := 24679
var save_path := ""
var remote_id := 0
var finishing := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+role+": "+message)
	if not ok: failed+=1
func until(predicate: Callable, label: String, timeout := 45.0) -> bool:
	var end := Time.get_ticks_msec()+int(timeout*1000)
	while not predicate.call() and Time.get_ticks_msec()<end: await process_frame
	var ok: bool=predicate.call()
	check(ok,label)
	if not ok:
		if is_instance_valid(net): print("DIAGNOSTIC ",role," enabled=",net.enabled," connecting=",net.connecting," room=",net.room_code," message=",net.message)
		finish()
	return ok
func phase(value: String) -> void:
	var file := FileAccess.open(prefix+"-phase",FileAccess.WRITE)
	file.store_string(value)
func phase_is(value: String) -> bool:
	return FileAccess.file_exists(prefix+"-phase") and FileAccess.get_file_as_string(prefix+"-phase")==value
func ack(value: String) -> void:
	var file := FileAccess.open(prefix+"-ack",FileAccess.WRITE)
	file.store_string(value)
func ack_is(value: String) -> bool:
	return FileAccess.file_exists(prefix+"-ack") and FileAccess.get_file_as_string(prefix+"-ack")==value
func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func relocate_remote(pos: Vector3) -> void:
	var point: Vector3=game._ground(pos)
	net.avatars[remote_id].set_pose(point,0,Vector3.ZERO,true,true)
	net._correct.rpc_id(remote_id,net.generation,point)
func run() -> void:
	if DisplayServer.get_name()!="headless":
		RenderingServer.render_loop_enabled=false
		root.size=Vector2i(1280,800)
		root.content_scale_size=Vector2i(1280,800)
	var args := OS.get_cmdline_user_args()
	if args.size()>0: role=args[0]
	if args.size()>1: prefix=args[1]
	if args.size()>2: port=int(args[2])
	save_path=prefix+"-"+role+".json"
	OS.set_environment("DUSTLINE_PROFILE_PATH",save_path)
	OS.set_environment("DUSTLINE_TUTORIAL_DISABLED","1")
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	net=game.coop
	net.discovery.listen_port=port+1
	if role=="host": await host_run()
	else: await client_run()
	finish()
func host_run() -> void:
	check(net.host_room("测试房主",port)==OK,"create actual player-hosted room")
	if not await until(func(): return net.enabled,"host room becomes ready"): return
	if net.uses_relay():
		var code_file := FileAccess.open(prefix+"-room",FileAccess.WRITE)
		code_file.store_string(net.room_code)
		code_file.close()
	check(not net.start_expedition(3,1),"one player cannot start a real-team round")
	phase("room")
	if not await until(func(): return net.members.size()==2,"client handshake accepted"): return
	remote_id=net.members.keys().filter(func(id): return id!=1)[0]
	if not await until(func(): return net.members[remote_id].ready,"ready state received"): return
	check(net.start_expedition(3,1),"host starts shared expedition")
	if not await until(func(): return game.active and net.in_round,"all clients loaded"): return
	check(game.region_id==3 and game.mode==1,"host map and mode")
	check(net.avatars.size()==1,"one teammate avatar")
	for id in net.members: net.members[id].grace=999.0
	var initial: Vector3=net.avatars[remote_id].global_position
	phase("move")
	if not await until(func(): return ack_is("move"),"client completed input"): return
	if not await until(func(): return net.avatars[remote_id].global_position.distance_to(initial)>.5,"real movement received by host"): return
	var item: Area3D=game.pickups[0]
	var item_id: int=item.get_meta("network_id")
	var instance_id := item.get_instance_id()
	item.global_position=net.avatars[remote_id].global_position
	if not await until(func(): return not is_instance_id_valid(instance_id),"client proximity collects shared pickup"): return
	phase("collected:%d"%item_id)
	if not await until(func(): return ack_is("collected"),"pickup removal reaches client"): return
	net.members[remote_id].hp=50.0
	var medkits: int=game.medkits
	phase("heal")
	if not await until(func(): return net.members[remote_id].hp>=85,"remote heal applied by host"): return
	check(game.medkits==medkits-1,"heal consumes shared medkit exactly once")
	phase("skill")
	if not await until(func(): return net.actor_skills[remote_id].cooldowns[1]>1,"remote skill cooldown authoritative"): return
	phase("fire")
	if not await until(func(): return net.members[remote_id].ammo==29,"remote shot uses one round"): return
	var sent: Array=JSON.parse_string(FileAccess.get_file_as_string(prefix+"-aim"))
	var target := Vector3(sent[0],sent[1],sent[2])
	var muzzle: Vector3=net.avatars[remote_id].global_position+Vector3(0,1.1,0)
	var actual: Vector3=net.actor_guns[remote_id].last_impact-muzzle
	check(actual.normalized().dot((target-muzzle).normalized())>.995,"host fires along remote cursor target rather than host camera")
	await create_timer(.2).timeout
	check(net.members[remote_id].ammo==29,"rapid duplicate fire rejected")
	game.scrap=4
	relocate_remote(game.relays[0].global_position+Vector3(0,0,1))
	await create_timer(.5).timeout
	phase("relay")
	if not await until(func(): return game.repaired==1,"remote repairs shared relay"): return
	check(game.scrap==2,"repair cost authoritative")
	if not await until(func(): return ack_is("relay"),"relay update reaches client"): return
	var wolf: CharacterBody3D=game.mutants[0]
	wolf.global_position=net.avatars[remote_id].global_position+Vector3(0,0,6)
	check(net.target_for(wolf)==net.avatars[remote_id],"wolf targets nearby teammate")
	net.members[remote_id].grace=0.0
	net.damage(remote_id,200,true)
	check(net.members[1].hp==100,"remote damage does not hit host")
	phase("down")
	if not await until(func(): return ack_is("down"),"client sees downed state"): return
	game.player.global_position=net.avatars[remote_id].global_position+Vector3(1,0,0)
	net.request_action("interact")
	check(net.members[remote_id].hp==0,"rescue starts without instant revival")
	if not await until(func(): return net.members[remote_id].hp==40,"three-second rescue completes"): return
	phase("revive")
	if not await until(func(): return ack_is("revive"),"revive restores client controls"): return
	game.open_menu()
	var elapsed: float=game.elapsed
	await create_timer(.25).timeout
	check(game.elapsed>elapsed and not game.player.controls_enabled,"menu does not pause co-op world")
	game.resume_game()
	game.scrap=6
	game.player.reset_for_round(game._ground(game.extraction.global_position+Vector3(-1,0,0)))
	relocate_remote(game.extraction.global_position+Vector3(0,0,1))
	await create_timer(.5).timeout
	phase("exit")
	if not await until(func(): return game.round_over,"remote extraction ends shared round"): return
	check(game.won,"host receives shared success")
	if not await until(func(): return ack_is("exit"),"client receives shared result"): return
	check(not FileAccess.file_exists(save_path),"co-op does not write singleplayer save")
	phase("leave")
	if not await until(func(): return net.members.size()==1,"disconnect removes member"): return
	check(net.avatars.is_empty(),"disconnect removes ghost avatar")
	net.leave_room("测试结束")
	check(not net.enabled and not game.round_started,"host returns to singleplayer menu")
	phase("done")
func client_run() -> void:
	if not await until(func(): return phase_is("room"),"host room available"): return
	game._on_character_selected(1)
	game.hud._coop_panel.open()
	if net.uses_relay():
		var lobby: Control=game.hud._coop_panel
		lobby.internet_toggle.button_pressed=true
		lobby.endpoint.text=net.relay_url
		lobby.address.text=FileAccess.get_file_as_string(prefix+"-room")
		lobby.nickname.text="测试队友"
		lobby._join_room()
	else:
		if not await until(func(): return not net.discovery.rooms.is_empty(),"discover actual host over UDP"): return
		var room: Dictionary=net.discovery.rooms.values()[0]
		check(room.port==port and room.count==1 and not room.playing,"discovered room reports real endpoint and occupancy")
		game.hud._coop_panel.nickname.text="测试队友"
		game.hud._coop_panel.refresh()
		game.hud._coop_panel.join_nearby()
	check(net.connecting,"join discovered host from lobby button")
	if not await until(func(): return net.members.size()==2,"lobby roster received"): return
	net.toggle_ready()
	if not await until(func(): return game.active and net.in_round,"shared round starts",40): return
	check(game.region_id==3 and game.mode==1,"client uses host-selected map and mode")
	check(net.avatars.has(1),"host avatar visible")
	check(game.player.character_id==1,"selected character preserved")
	if not await until(func(): return phase_is("move"),"movement phase"): return
	key(KEY_W,true)
	for frame in 65: await physics_frame
	key(KEY_W,false)
	await create_timer(.2).timeout
	ack("move")
	if not await until(func(): return FileAccess.get_file_as_string(prefix+"-phase").begins_with("collected:"),"collection phase"): return
	var item_id := int(FileAccess.get_file_as_string(prefix+"-phase").split(":")[1])
	if not await until(func(): return not net.pickup_nodes.has(item_id),"collected item removed locally"): return
	ack("collected")
	if not await until(func(): return phase_is("heal") and game.health==50,"personal HP synchronized"): return
	net.request_action("heal")
	if not await until(func(): return phase_is("skill"),"skill phase"): return
	net.request_action("character_skill")
	if not await until(func(): return phase_is("fire"),"fire phase"): return
	await create_timer(.12).timeout
	var point := root.get_visible_rect().size*Vector2(.58,.55)
	var motion := InputEventMouseMotion.new()
	motion.position=point
	root.push_input(motion,true)
	var target: Vector3=game.weapon_target()
	var file := FileAccess.open(prefix+"-aim",FileAccess.WRITE)
	file.store_string(JSON.stringify([target.x,target.y,target.z]))
	file.close()
	for down in [true,false]:
		var mouse := InputEventMouseButton.new()
		mouse.button_index=MOUSE_BUTTON_RIGHT
		mouse.position=point
		mouse.pressed=down
		root.push_input(mouse,true)
	net.request_action("fire_weapon")
	if not await until(func(): return phase_is("relay"),"relay phase"): return
	net.request_action("interact")
	if not await until(func(): return game.repaired==1 and game.relays[0].get_meta("active",false),"shared beacon active locally"): return
	ack("relay")
	if not await until(func(): return phase_is("down") and game.health==0,"downed HP synchronized"): return
	check(not game.player.controls_enabled,"downed player cannot move")
	ack("down")
	if not await until(func(): return phase_is("revive") and game.health>0,"revive synchronized"): return
	check(game.player.controls_enabled,"revived player can move")
	ack("revive")
	if not await until(func(): return phase_is("exit"),"extraction phase"): return
	net.request_action("interact")
	if not await until(func(): return game.round_over,"shared result received"): return
	check(game.won,"client receives victory")
	check(not FileAccess.file_exists(save_path),"client singleplayer save untouched")
	ack("exit")
	if not await until(func(): return phase_is("leave"),"leave phase"): return
	net.leave_room("测试退出")
	check(not net.enabled and game.hud._menu.visible,"client returns to offline menu")
	if not await until(func(): return phase_is("done"),"host cleaned disconnect"): return
func finish() -> void:
	if finishing: return
	finishing=true
	if is_instance_valid(game):
		if is_instance_valid(net) and net.enabled: net.leave_room("测试结束")
		game.queue_free()
	print("COOP %s: %d checks, %d failures"%[role,checks,failed])
	quit(1 if failed else 0)
