extends SceneTree
var game: Node3D
var checks := 0
var failed := 0
var save_path := "/tmp/dustline-death-result-%d.json"%OS.get_process_id()
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failed+=1
func capture(label: String, size := Vector2i(1280,800)) -> void:
	if DisplayServer.get_name()=="headless": return
	root.size=size
	root.content_scale_size=size
	game.hud._layout()
	for i in 6: await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://previews/"+label+".png")
func run() -> void:
	OS.set_environment("DUSTLINE_PROFILE_PATH",save_path)
	OS.set_environment("DUSTLINE_TUTORIAL_DISABLED","1")
	root.size=Vector2i(1280,800)
	root.content_scale_size=Vector2i(1280,800)
	if DisplayServer.get_name()!="headless": RenderingServer.render_loop_enabled=false
	game=load("res://main.tscn").instantiate()
	var funding: Dictionary=game.profile.begin_expedition()
	game.profile.finish_expedition(funding.id,true,2000,0)
	for item in ["repulsor","armor","field_kit","ammo_pack"]: game.profile.purchase(item)
	game.profile.upgrade(0)
	root.add_child(game)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.start_mode(1)
	game.expedition.bag_value=350
	game.expedition.bag_items=4
	game.elapsed=73
	game.collected=9
	game.scrap=6
	game.player.global_position=game.extraction.global_position+Vector3(0,0,1)
	game.interact()
	check(game.won and game.hud._result.visible and game.hud._result_details.visible,"Successful extraction displays detailed settlement")
	check(game.hud._result_cash.text.contains("+350 G") and game.hud._result_equipment.text.contains("保留装备"),"Success report shows income and retained equipment")
	check(game.profile.owned.size()==3 and game.profile.ammo_stock==24,"Successful round keeps all purchased equipment")
	check(game.hud._result_stats.get_child_count()==3 and game.hud._result_notice.text=="结算已保存","Result shows time, scrap, relays and save status")
	await capture("settlement-success")
	game.start_mode(1)
	game.expedition.bag_value=180
	game.expedition.bag_items=1
	game.elapsed=42
	game.round_ammo=8
	game.damage_grace=0
	var balance: int=game.profile.assets
	game.take_damage(10000)
	check(game.health==0 and game.round_over and not game.active and not game.won,"Actual fatal damage ends round and disables play")
	check(game.profile.owned.is_empty() and game.profile.equipped.is_empty() and game.profile.ammo_stock==0,"Actual death clears gun, armor, medical component and ammunition")
	check(not is_instance_valid(game.arsenal.weapon) and not game.arsenal.fire(),"Weapon disappears and cannot fire after death")
	check(game.profile.assets==balance and game.profile.level(0)==2,"Death preserves bank and character level")
	check(game.hud._result.visible and game.hud._result_kicker.text.contains("死亡结算"),"Death displays its own settlement screen")
	check(game.hud._result_equipment.text.contains("荒原驱狼枪") and game.hud._result_equipment.text.contains("加固废土护甲") and game.hud._result_equipment.text.contains("野战医疗组件") and game.hud._result_equipment.text.contains("20 发"),"Death screen lists all lost items and exact ammunition")
	check(game.hud._result_cash.text.contains("180 G") and game.hud._result_camp.text.contains("重新购买"),"Death screen shows lost loot and shop action")
	var reload=game.Profile.new(save_path)
	check(reload.owned.is_empty() and reload.assets==balance,"Saved death loss survives reload")
	await capture("settlement-death")
	await capture("settlement-death-compact",Vector2i(900,700))
	if DisplayServer.get_name()!="headless":
		check(root.get_visible_rect().encloses(game.hud._result_camp.get_global_rect()),"Compact death result keeps repurchase button on screen")
	if "--preview-only" in OS.get_cmdline_user_args():
		await finish()
		return
	game.hud._result_restart.pressed.emit()
	check(game.active and game.round_ammo==0 and game.medkits==2 and not is_instance_valid(game.arsenal.weapon),"Restart does not restore lost gun, ammo or medical upgrade")
	game.damage_grace=0
	game.take_damage(10,true)
	check(is_equal_approx(game.health,105),"Lost armor no longer reduces damage; level bonus remains")
	game.damage_grace=0
	game.take_damage(10000)
	game.hud._result_camp.pressed.emit()
	check(game.hud._camp.visible,"Death result shop button opens camp")
	var buy: Button=game.hud._camp_items.find_child("ItemAction_repulsor",true,false)
	check(not buy.disabled,"Destroyed gun is available to buy again")
	buy.pressed.emit()
	check(game.profile.assets==balance-300 and game.profile.owned.has("repulsor") and is_instance_valid(game.arsenal.weapon),"Shop repurchase charges full price and restores weapon model")
	game.start_mode(1)
	check(game.round_ammo==12,"Repurchased gun supplies a fresh twelve-round loadout")
	game.profile.save_path="/tmp/no-such-dustline-directory-%d/death.json"%OS.get_process_id()
	game.damage_grace=0
	game.take_damage(10000)
	check(not game._pending_settlement.is_empty() and game.hud._result_restart.disabled and game.hud._result_notice.text.contains("尚未保存"),"Failed death save displays retry status and blocks departure")
	game.profile.save_path=save_path
	game.hud._result_camp.pressed.emit()
	check(game._pending_settlement.is_empty() and game.profile.owned.is_empty() and game.hud._camp.visible,"Returning to camp retries death settlement and persists item loss")
	await finish()

func finish() -> void:
	game.queue_free()
	await process_frame
	for suffix in ["",".bak",".tmp",".bak.tmp"]: DirAccess.remove_absolute(save_path+suffix)
	print("DEATH SETTLEMENT: %d checks; %d failures"%[checks,failed])
	quit(1 if failed else 0)
