extends SceneTree
const Firearm = preload("res://salvage_firearm.gd")
const Player = preload("res://player.gd")
const Mutant = preload("res://mutant_controller.gd")
class Profile extends RefCounted:
	var owned: Array[String] = ["repulsor"]
	var equipped := "repulsor"
class Fixture extends Node3D:
	var active := true
	var round_over := false
	var profile := Profile.new()
	var round_ammo := 12
	var player: CharacterBody3D
	var mutants: Array[Node3D] = []
var checks := 0
var failures: Array[String] = []
var game: Fixture
var gun: Node3D
var wolf: CharacterBody3D
var packmate: CharacterBody3D
var bites := 0
func _initialize() -> void: call_deferred("run")
func check(condition: bool,message: String) -> void:
	checks += 1
	if condition: print("PASS: "+message)
	else:
		failures.append(message)
		push_error(message)
func frames(count: int) -> void:
	for i in count: await physics_frame
func wall_at(pos: Vector3,size: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	wall.add_child(shape)
	wall.position = pos
	game.add_child(wall)
	return wall
func place_wolves(at: Vector3,other: Vector3) -> void:
	wolf.position = at
	packmate.position = other
	for mutant in game.mutants:
		mutant.velocity = Vector3.ZERO
		mutant.stun_remaining = 0
		mutant.projectile_fear_remaining = 0
		mutant._set_state("windup")
	gun.cooldown = 0
	await frames(3)
func run() -> void:
	game = Fixture.new()
	root.add_child(game)
	wall_at(Vector3(0,-.5,0),Vector3(160,1,160))
	game.player = Player.new()
	game.player.name = "Player"
	var body := Node3D.new()
	body.name = "Body"
	game.player.add_child(body)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	game.player.add_child(camera)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .3
	capsule.height = 1.86
	collision.shape = capsule
	collision.position.y = .93
	game.player.add_child(collision)
	game.add_child(game.player)
	game.player.set_physics_process(false)
	for i in 2:
		var beast := Mutant.new()
		beast.position = Vector3(i*3,0,-10-i*2)
		game.add_child(beast)
		beast.attack_landed.connect(func(_damage): bites += 1)
		game.mutants.append(beast)
	wolf = game.mutants[0]
	packmate = game.mutants[1]
	gun = Firearm.new()
	gun.game = game
	game.add_child(gun)
	gun.reset_round()
	await frames(3)
	check(is_instance_valid(gun.weapon) and gun.weapon.get_parent() == game.player.character.elbows[1].get_node("Hand"),"Owned equipped gun mounts to the right hand")
	game.active = false
	check(not gun.fire() and game.round_ammo == 12,"Menu pause rejects shots without spending ammunition")
	game.active = true
	game.profile.equipped = ""
	check(not gun.fire() and game.round_ammo == 12,"An unequipped firearm cannot shoot")
	game.profile.equipped = "repulsor"
	game.profile.owned.clear()
	check(not gun.fire() and game.round_ammo == 12,"An unowned firearm cannot shoot even with an equipped id")
	game.profile.owned.append("repulsor")
	game.round_ammo = 0
	check(not gun.fire(),"An empty magazine rejects the shot")
	game.round_ammo = 8
	check(gun.fire() and game.round_ammo == 7,"One accepted shot consumes exactly one round")
	check(gun.last_hit == wolf and wolf.stun_remaining == 1.0,"Raycast strikes the visible wolf and interrupts its bite")
	check(wolf.projectile_fear_remaining == 5.0 and packmate.projectile_fear_remaining == 4.0,"A hit makes the struck wolf and nearby pack retreat")
	check(gun.flash.visible and gun._tracers.size() == 1,"A shot produces a muzzle flash and finite tracer")
	var muzzle_direction: Vector3 = -gun.muzzle.global_basis.z
	check(muzzle_direction.dot(Vector3.FORWARD) > .97,"Firing pose aims the visible barrel along the camera direction")
	check(not gun.fire() and game.round_ammo == 7,"Fire interval prevents duplicate shots and ammo consumption")
	var initial: Vector3 = wolf.position
	for i in 75:
		wolf.tick(1.0/60.0,game.player,false,false)
		gun.tick(1.0/60.0)
		await frames(1)
	check(wolf.position.z < initial.z-1.0,"Projectile impact physically pushes the wolf away")
	check(wolf.state == "flee" and wolf.projectile_fear_remaining > 4.0 and bites == 0,"After its short stun a wolf flees without finishing its cancelled bite")
	check(not gun.flash.visible and gun._tracers.is_empty(),"Flash and tracer expire and release their visual nodes")
	gun.cooldown = .5
	game.active = false
	gun.tick(1.0)
	check(gun.cooldown == .5,"A paused round does not advance the firearm cooldown")
	game.active = true
	await place_wolves(Vector3(0,0,-12),Vector3(20,0,-12))
	var wall := wall_at(Vector3(0,1.5,-5),Vector3(4,3,.6))
	await frames(3)
	var ammo_before: int = game.round_ammo
	check(gun.fire() and gun.last_hit == null and game.round_ammo == ammo_before-1,"A wall blocks a fired shot while still consuming ammunition")
	check(wolf.stun_remaining == 0 and gun.last_impact.z > -5.4,"Tracer and hit stop at the first obstacle")
	wall.queue_free()
	await place_wolves(Vector3(1.1,0,-12),Vector3(20,0,-12))
	check(gun.fire() and gun.last_hit == wolf,"Narrow aim assist can hit a visible wolf near the camera direction")
	await place_wolves(Vector3(3,0,-12),Vector3(20,0,-12))
	check(gun.fire() and gun.last_hit == null,"Aim assist does not hit wolves outside its eight degree cone")
	await place_wolves(Vector3(0,0,-37),Vector3(20,0,-37))
	check(gun.fire() and gun.last_hit == null,"Wolves beyond the weapon's 32 metre range cannot be hit")
	await place_wolves(Vector3(-10,0,0),Vector3(-12,0,3))
	game.player.camera_yaw = PI/2
	check(gun.fire() and gun.last_hit == wolf,"Rotating the camera rotates the actual firing direction")
	check(is_equal_approx(game.player.get_node("Body").rotation.y,PI/2),"The character visibly turns to face the shot")
	wolf.apply_shock(game.player.position)
	wolf.apply_projectile_hit(game.player.position)
	check(wolf.stun_remaining == 3.0,"A gun hit preserves a longer active character-skill stun")
	for id in 4:
		game.player.select_character(id)
		gun.refresh_loadout()
		check(is_instance_valid(gun.weapon) and gun.weapon.get_parent() == game.player.character.elbows[1].get_node("Hand"),"Character %d has its own correctly mounted gun"%id)
	game.profile.equipped = ""
	gun.refresh_loadout()
	check(not is_instance_valid(gun.weapon),"Unequipping removes the visible held weapon")
	game.profile.equipped = "repulsor"
	gun.reset_round()
	check(game.round_ammo == 2,"Resetting visuals does not manufacture free ammunition")
	print("FIREARM REGRESSION: %s; %d checks"%["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
