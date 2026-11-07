extends "res://tests/coop_network_regression.gd"
## Real independent player connections, with host authority and isolated profiles.

func host_run() -> void:
	game._on_character_selected(3)
	check(net.host_room("维修队长",port)==OK,"create cooperative room")
	if not await until(func(): return net.enabled,"host ready"): return
	if net.uses_relay():
		var file := FileAccess.open(prefix+"-room",FileAccess.WRITE)
		file.store_string(net.room_code)
		file.close()
	phase("room")
	if not await until(func(): return net.members.size()==2,"real scout joined"): return
	remote_id=net.members.keys().filter(func(id): return id!=1)[0]
	if not await until(func(): return net.members[remote_id].ready,"scout ready"): return
	check(net.start_expedition(3,1),"launch team expedition")
	if not await until(func(): return game.active,"both players loaded"): return
	for id in net.members: net.members[id].grace=999
	for wolf in game.mutants: wolf.global_position=game._ground(Vector3(-95,0,-95))
	var meeting: Vector3=game._ground(Vector3(0,0,53))
	game.player.reset_for_round(meeting)
	relocate_remote(meeting+Vector3(2,0,0))
	await create_timer(.5).timeout
	phase("scan")
	if not await until(func(): return not net.team.scans.is_empty(),"client scan reaches host"): return
	check(net.team.scans.size()<=16 and net.team.scan_remaining>0,"shared scan has bounded targets and lifetime")
	if not await until(func(): return net.team.pings.has(remote_id),"keyboard danger ping reaches host"): return
	check(net.team.pings[remote_id].kind=="danger","correct ping type synchronized")
	var point: Vector3=net.team.pings[remote_id].point
	net.team.add_ping(remote_id,"rally",meeting)
	check(net.team.pings[remote_id].point==point,"ping rate limit blocks immediate spam")
	await capture_cooperation("coop-shared-scan")
	net.team.add_ping(1,"danger",Vector3(INF,0,0))
	check(not net.team.pings.has(1),"nonfinite ping rejected")
	net.members[1].hp=70
	net.members[remote_id].hp=60
	net.request_action("character_skill")
	if not await until(func(): return net.members[remote_id].hp>=65,"repair drone heals nearby real teammate"): return
	check(net.members[1].hp>70,"repair drone still heals its caster")
	net.actor_skills[remote_id].cancel_active()
	game.skills.cancel_active()
	# A remote actor beyond the aura must not receive free healing.
	relocate_remote(meeting+Vector3(18,0,0))
	await create_timer(.5).timeout
	var before: float=net.members[remote_id].hp
	net.team.heal_nearby(1,3)
	check(is_equal_approx(before,net.members[remote_id].hp),"healing respects eight-meter radius")
	net.members[remote_id].hp=0
	relocate_remote(meeting+Vector3(1,0,0))
	await create_timer(.3).timeout
	check(net.team.begin_rescue(1,remote_id),"nearby rescue begins")
	check(net.members[remote_id].hp==0,"rescue is not instantaneous")
	net.members[1].grace=0
	net.damage(1,1,false)
	check(not net.team.rescues.has(1),"damage interrupts rescue")
	check(net.team.begin_rescue(1,remote_id),"rescue can be restarted")
	game.player.global_position+=Vector3(1,0,0)
	await create_timer(.1).timeout
	check(not net.team.rescues.has(1),"moving away interrupts rescue")
	game.player.reset_for_round(meeting)
	net.members[1].grace=999
	if not net.members.has(remote_id):
		check(false,"teammate remains connected during rescue")
		return
	print("RESCUE_CHECK ",game.player.global_position," target ",net.actor(remote_id).global_position," hp ",net.members[remote_id].hp," LOS ",net.team.visible_between(game.player.global_position,net.actor(remote_id).global_position))
	if not net.team.begin_rescue(1,remote_id):
		check(false,"third rescue begins")
		return
	check(true,"third rescue begins")
	if not await until(func(): return net.members[remote_id].hp>0,"uninterrupted rescue completes"): return
	game.scrap=6
	game.expedition.bag_value=840
	game.expedition.bag_items=6
	game.player.reset_for_round(game._ground(game.extraction.global_position+Vector3(-1,0,0)))
	net.request_action("interact")
	await create_timer(.25).timeout
	check(not net.team.extraction.is_empty() and not game.round_over,"one player calls extraction without teleporting the team")
	check(not net.team.extraction.missing.is_empty(),"distant teammate is listed as missing")
	await capture_cooperation("coop-extraction-rally")
	relocate_remote(game.extraction.global_position+Vector3(1,0,0))
	if not await until(func(): return net.team.extraction.remaining<4.8,"full squad starts five-second countdown"): return
	relocate_remote(game.extraction.global_position+Vector3(15,0,0))
	if not await until(func(): return net.team.extraction.remaining==5,"leaving the circle resets countdown"): return
	check(not game.round_over,"leaving does not grant success")
	relocate_remote(game.extraction.global_position+Vector3(1,0,0))
	if not await until(func(): return game.round_over,"regrouped squad extracts"): return
	check(game.won and net.squad_profile.assets==520,"equal share plus completion bonus saved for host")
	var balance: int=net.squad_profile.assets
	net._finished(net.generation,true,"duplicate","duplicate",840,0,0,0,6)
	check(net.squad_profile.assets==balance,"duplicate result cannot mint rewards")
	var reloaded=game.Profile.new(net.squad_profile.save_path)
	check(reloaded.assets==520,"cooperative rewards survive reload")
	check(not FileAccess.file_exists(save_path),"solo profile remains untouched")
	net.upgrade_squad_character(3)
	check(net.squad_profile.level(3)==2 and net.squad_profile.assets==400,"cooperative upgrade spends correct personal assets")
	phase("upgrade")
	if not await until(func(): return net.members[remote_id].rank==2 and net.members[remote_id].ready,"client upgrade and readiness arrive"): return
	check(net.start_expedition(3,1),"upgraded squad starts another expedition")
	if not await until(func(): return game.active,"second expedition loaded"): return
	check(game.max_health==115 and net.members[remote_id].max_hp==115,"both players receive their own upgraded health")
	check(is_equal_approx(net._with_actor(remote_id,func(): return net.cooldown_for_actor()),.93),"remote skill uses the remote player's own level")
	# A failed disk write retains a retryable result and cannot double-pay.
	var original_path: String=net.squad_profile.save_path
	net.squad_profile.save_path="/tmp/nonexistent-coop-%d/profile.json"%OS.get_process_id()
	net.finish(true,"存档重试测试","验证保存失败不会重复入账")
	check(not net._squad_settlement.is_empty() and net.squad_profile.assets==400,"failed result save rolls back and retains receipt")
	net.squad_profile.save_path=original_path
	check(net.retry_squad_settlement() and net.squad_profile.assets==500,"pending receipt retries successfully")
	check(net.retry_squad_settlement() and net.squad_profile.assets==500,"retry cannot duplicate reward")
	phase("saved")
	if not await until(func(): return ack_is("saved"),"client validates own rewards"): return
	net.leave_room("房主正常退出")
	phase("closed")
	if not await until(func(): return ack_is("closed"),"host departure returns teammate to menu"): return

func client_run() -> void:
	game._on_character_selected(0)
	if not await until(func(): return phase_is("room"),"room available"): return
	if net.uses_relay():
		check(net.join_room("侦察队员",FileAccess.get_file_as_string(prefix+"-room"))==OK,"join real room by code")
	else:
		check(net.join_room("侦察队员","127.0.0.1",port)==OK,"join real LAN room")
	if not await until(func(): return net.members.size()==2,"roster synchronized"): return
	net.toggle_ready()
	if not await until(func(): return phase_is("scan") and game.active,"shared scan phase"): return
	key(KEY_H,true)
	key(KEY_H,false)
	net.request_action("character_skill")
	if not await until(func(): return not net.team.scans.is_empty(),"scout sees shared scan"): return
	if not await until(func(): return net.team.pings.has(net.local_id()),"scout receives authoritative ping"): return
	if not await until(func(): return phase_is("upgrade") and game.round_over,"first squad result",90): return
	check(net.squad_profile.assets==520,"client gets same per-player reward")
	net.upgrade_squad_character(0)
	check(net.squad_profile.level(0)==2 and net.squad_profile.assets==400,"client owns independent progression")
	await create_timer(.2).timeout
	net.toggle_ready()
	if not await until(func(): return phase_is("saved") and game.round_over and net.generation==2,"second squad result"): return
	check(net.squad_profile.assets==500,"second result adds exactly one completion reward")
	check(not FileAccess.file_exists(save_path),"client solo save remains untouched")
	ack("saved")
	if not await until(func(): return phase_is("closed") and not net.enabled,"host shutdown propagated"): return
	check(game.hud._menu.visible,"host departure opens offline menu")
	ack("closed")

func capture_cooperation(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	game.player._update_camera()
	for frame in 5: await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://previews/"+label+".png")
