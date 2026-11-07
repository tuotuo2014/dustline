extends SceneTree
const Profile = preload("res://economy_profile.gd")
var game: Node3D
var failures: Array[String]=[]
var checks := 0
var save_path := "/tmp/dustline-economy-integrated-"+str(OS.get_process_id())+".json"
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if ok: print("PASS: "+message)
	else:
		failures.append(message)
		push_error("FAIL: "+message)
func frames(count: int=3) -> void:
	for i in count: await physics_frame
	await process_frame
func click(button: Button) -> void:
	await frames(3)
	if game.hud._camp.visible and game.hud._camp.is_ancestor_of(button):
		game.hud._camp_center.get_parent().ensure_control_visible(button)
		await frames(3)
	var p := button.get_global_transform_with_canvas()*(button.size*.5)
	var motion := InputEventMouseMotion.new()
	motion.position=p
	motion.global_position=p
	root.push_input(motion,true)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=p
		event.global_position=p
		event.button_index=MOUSE_BUTTON_LEFT
		event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed=down
		root.push_input(event,true)
		await frames(1)
func tap(code: Key) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode=code
		event.physical_keycode=code
		event.pressed=down
		root.push_input(event,true)
		await frames(1)
func loot(kind: String) -> Area3D:
	for p in game.pickups:
		if p.get_meta("kind")==kind: return p
	return null
func run() -> void:
	OS.set_environment("DUSTLINE_PROFILE_PATH",save_path)
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(8)
	check(game.profile.assets==0 and game.profile.owned.is_empty(),"New camp starts without free assets or gun")
	check(game.expedition.valuable_count==40,"All 40 detailed valuables spawn")
	await click(game.hud._camp_entry)
	check(game.hud._camp.visible and game.hud._camp_upgrade.disabled,"Real camp entry click works and cannot spend missing funds")
	await click(game.hud._camp_back)
	await click(game.hud._mode_buttons[1])
	check(game.active and not game.expedition.id.is_empty(),"Real departure starts persisted expedition")
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	var coin := loot("coin")
	game._collect(coin)
	game._collect(coin)
	check(game.expedition.bag_value==15 and game.expedition.bag_items==1 and game.profile.assets==0,"Coin collected once into unsecured bag only")
	for kind in ["watch","chip","gold"]: game._collect(loot(kind))
	check(game.expedition.bag_value==350 and game.expedition.bag_items==4,"Distinct valuables have correct sale values")
	game.open_menu()
	game._purchase_equipment("repulsor")
	check(not game.profile.owned.has("repulsor") and game.profile.assets==0,"Unextracted loot cannot buy equipment while paused")
	await click(game.hud._camp_entry)
	check(game.hud._camp_upgrade.disabled,"Paused camp locks growth")
	game.resume_game()
	game.scrap=6
	game.player.global_position=game.extraction.global_position+Vector3(0,0,1.4)
	game.interact()
	check(game.round_over and game.won and game.profile.assets==350,"Real extraction interaction banks carried valuables")
	game._finish(true,"Duplicate","")
	check(game.profile.assets==350,"Repeated completion cannot bank twice")
	var reloaded=Profile.new(save_path)
	check(reloaded.assets==350 and reloaded.pending.is_empty(),"Extraction assets survive profile reload")
	await click(game.hud._result.find_child("ResultCamp",true,false))
	check(game.hud._camp.visible and not game.hud._camp_upgrade.disabled,"Result button returns to unlocked camp")
	var buy: Button=game.hud._camp_items.find_child("ItemAction_repulsor",true,false)
	await click(buy)
	check(game.profile.assets==50 and game.profile.equipped=="repulsor" and game.profile.ammo_stock==12,"Real shop click purchases and equips firearm with finite ammo")
	check(is_instance_valid(game.arsenal.weapon),"Purchased firearm actually appears on survivor hand")
	game.start_mode(1)
	check(game.round_ammo==12 and game.profile.ammo_stock==0,"Departure reserves twelve from persistent stock")
	await tap(KEY_V)
	check(game.round_ammo==11,"Real V key fires and consumes exactly one round")
	game.open_menu()
	await tap(KEY_V)
	check(game.round_ammo==11,"Paused V input cannot spend ammunition")
	game.resume_game()
	game._collect(loot("gold"))
	game._finish(false,"Failure","")
	check(game.profile.assets==50 and game.profile.ammo_stock==11,"Failed expedition loses loot and returns only unused ammo")
	game.start_mode(1)
	check(game.round_ammo==11,"Next expedition does not refill spent ammunition")
	game.arsenal.fire()
	game._collect(loot("gold"))
	game.start_mode(0)
	check(game.profile.assets==50 and game.expedition.bag_value==0 and game.round_ammo==10,"Restart discards carried valuables and preserves finite ammo")
	game._collect(loot("gold"))
	game._collect(loot("gold"))
	game._collect(loot("gold"))
	game.repaired=3
	game.player.global_position=game.base.global_position+Vector3(0,0,1.3)
	game.interact()
	check(game.won and game.profile.assets==590,"Explore camp completion also banks valuables")
	game.open_menu()
	game.hud.show_camp()
	await click(game.hud._camp_character_buttons[3])
	await click(game.hud._camp_upgrade)
	check(game.profile.level(3)==2 and game.profile.level(0)==1 and game.profile.assets==470,"Camp character picker upgrades only selected survivor")
	check(game.max_health==115.0 and is_equal_approx(game.profile.cooldown_multiplier(3),.93),"Character upgrade raises max health and shortens cooldown")
	game._purchase_equipment("armor")
	game._purchase_equipment("field_kit")
	check(game.profile.assets==130,"Armor and permanent medkit deduct published prices")
	game.start_mode(2)
	check(game.health==115.0 and game.medkits==3,"Upgraded health and medical gear apply to next expedition")
	game.health=114
	game.use_medkit()
	check(game.health==115,"Medical healing honors upgraded health cap")
	game.damage_grace=0
	game.take_damage(18,true)
	check(is_equal_approx(game.health,100.6),"Armor reduces wolf bite damage twenty percent")
	game.health=114
	game.skills.activate()
	check(is_equal_approx(game.skills.cooldowns[3],38*.93),"Real active skill uses upgraded cooldown")
	game.skills.tick(1)
	check(game.health==115,"Repair drone respects upgraded health cap")
	game.open_menu()
	var health_before: float=game.health
	game._on_character_selected(0)
	game._on_character_selected(3)
	check(game.health<=health_before,"Switching survivors does not grant free health")
	game.resume_game()
	game.elapsed=120
	game.repaired=2
	game.player.global_position=game.base.global_position+Vector3(0,0,1)
	game._collect(loot("watch"))
	game.interact()
	check(game.won and game.profile.assets==185,"Survival completion banks loot under original mission requirements")
	game.open_menu()
	game.hud.show_camp()
	await click(game.hud._camp_items.find_child("ItemAction_repulsor",true,false))
	check(game.profile.equipped.is_empty() and not is_instance_valid(game.arsenal.weapon),"Real camp action puts away visible gun without selling it")
	game.start_mode(0)
	game._collect(loot("gold"))
	game.open_menu()
	game.hud.show_camp()
	await click(game.hud._abandon)
	check(game.round_over and not game.won and game.profile.assets==185 and game.profile.pending.is_empty(),"Abandon action returns to camp without selling unextracted loot")
	game.queue_free()
	await frames(2)
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		DirAccess.remove_absolute(save_path+suffix)
	print("ECONOMY INTEGRATION: %s; %d checks; %d failures" % ["PASS" if failures.is_empty() else "FAIL",checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
