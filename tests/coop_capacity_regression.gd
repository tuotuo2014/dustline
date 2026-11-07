extends "res://tests/coop_network_regression.gd"
func host_run() -> void:
	game.hud._coop_panel.open()
	await capture("coop-browse")
	check(net.host_room("房主",port)==OK,"four-player room created")
	if not await until(func(): return net.enabled,"four-player host ready"): return
	if net.uses_relay():
		var file := FileAccess.open(prefix+"-room",FileAccess.WRITE)
		file.store_string(net.room_code)
		file.close()
	game.hud._coop_panel.refresh()
	await capture("coop-invite")
	phase("room")
	if not await until(func(): return net.members.size()==4,"three real clients joined",50): return
	if not await until(func(): return net.members.values().all(func(m): return m.ready),"all four players ready",30): return
	net.change_settings(3,2)
	check(net.members.values().filter(func(m): return m.ready).size()==1,"changing map clears guest readiness")
	phase("settings")
	if not await until(func(): return net.members.values().all(func(m): return m.ready),"guests confirm new map",30): return
	game.hud._coop_panel.open()
	await capture("coop-lobby")
	check(net.start_expedition(3,2),"start four-player survival")
	if not await until(func(): return game.active and net.in_round,"four players loaded",60): return
	check(net.avatars.size()==3,"three teammate models")
	await create_timer(.4).timeout
	game.hud._minimap.refresh_markers()
	check(game.hud._minimap.markers.filter(func(m): return m.kind=="teammate").size()==3,"all three teammates on minimap")
	check(game.hud._minimap.markers.filter(func(m): return m.kind=="threat").size()==5,"all five wolves on minimap")
	var packet := var_to_bytes(net.make_snapshot()).compress(FileAccess.COMPRESSION_DEFLATE)
	check(packet.size()<1300,"compressed four-player snapshot fits network MTU")
	print("Snapshot bytes: ",packet.size())
	await capture("coop-four-players")
	phase("round")
	if not await until(func(): return all_acked("round"),"all clients see same round",30): return
	net.request_action("character_skill")
	net.request_action("fire_weapon")
	if not await until(func(): return net.members.values().all(func(m): return m.ammo==29),"all four real players fire successfully"): return
	if not await until(func(): return net.actor_skills.values().all(func(skill): return skill.cooldowns.any(func(cd): return cd>0)),"all three teammate skills run concurrently"): return
	check(not net.team.scans.is_empty(),"host scan shared during four-player skills")
	for id in net.members:
		net.members[id].grace=0
		net.damage(id,1000,false)
	check(game.round_over and not game.won,"team wipe ends round once")
	phase("wipe")
	if not await until(func(): return all_acked("wipe"),"failure reaches all clients",30): return
	check(net.start_expedition(1,0),"host can start another map without reconnecting")
	if not await until(func(): return game.active and net.generation==2,"second map loaded",60): return
	phase("restart")
	if not await until(func(): return all_acked("restart"),"all clients switched map",30): return
	net.leave_room("房主关闭房间")
	phase("closed")
	if not await until(func(): return all_acked("closed"),"host departure returns clients to menus",40): return
	check(game.profile.save_path==save_path,"host singleplayer profile restored")
func client_run() -> void:
	if not await until(func(): return phase_is("room"),"host available",40): return
	var index := int(role.trim_prefix("client"))
	game._on_character_selected(index)
	if net.uses_relay():
		check(net.join_room("队员%d"%index,FileAccess.get_file_as_string(prefix+"-room"))==OK,"join four-player relay room")
	elif index==1:
		game.hud._coop_panel.open()
		game.hud._coop_panel.nickname.text="队员1"
		game.hud._coop_panel.address.text=net.Invite.format_address("127.0.0.1",port)
		game.hud._coop_panel.join_button.pressed.emit()
		check(net.connecting,"join via pasted invitation and actual UI button")
	else:
		check(net.join_room("队员%d"%index,"127.0.0.1",port)==OK,"join full-sized team")
	if not await until(func(): return net.members.has(net.local_id()),"handshake",40): return
	net.toggle_ready()
	if not await until(func(): return phase_is("settings") and net.room_region==3 and not net.members[net.local_id()].ready,"new room settings synchronized",40): return
	net.toggle_ready()
	if not await until(func(): return game.active and net.in_round and phase_is("round"),"four-player session active",75): return
	check(net.members.size()==4 and net.avatars.size()==3,"correct roster and avatar count")
	check(game.mode==2 and game.region_id==3,"same survival region")
	check(game.player.character_id==index,"distinct teammate character retained")
	game.hud._minimap.refresh_markers()
	check(game.hud._minimap.markers.filter(func(m): return m.kind=="teammate").size()==3,"teammates on client map")
	net.request_action("character_skill")
	net.request_action("fire_weapon")
	client_ack("round")
	if not await until(func(): return game.round_over and phase_is("wipe"),"team wipe delivered",30): return
	check(not game.won,"no false success on team wipe")
	client_ack("wipe")
	if not await until(func(): return game.active and net.generation==2 and phase_is("restart"),"restart delivered",75): return
	check(game.region_id==1 and game.mode==0,"new map synchronized")
	check(game.health==100 and net.avatars.size()==3,"HP reset and no duplicate avatars")
	client_ack("restart")
	if not await until(func(): return not net.enabled and not net.connecting and phase_is("closed"),"host disconnection handled",50): return
	check(game.hud._menu.visible and not game.round_started,"offline menu after host leaves")
	check(game.profile.save_path==save_path,"original profile restored")
	client_ack("closed")
func client_ack(value: String) -> void:
	var file := FileAccess.open(prefix+"-"+role+"-ack",FileAccess.WRITE)
	file.store_string(value)
func all_acked(value: String) -> bool:
	for i in range(1,4):
		var path := prefix+"-client%d-ack"%i
		if not FileAccess.file_exists(path) or FileAccess.get_file_as_string(path)!=value: return false
	return true
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	game.player._update_camera()
	for i in 10: await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://previews/"+label+".png")
