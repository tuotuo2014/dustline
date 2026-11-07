extends SceneTree
const Firearm = preload("res://salvage_firearm.gd")
const Player = preload("res://player.gd")
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
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1200,760)
	var view := SubViewport.new()
	view.size=Vector2i(1600,1000)
	view.own_world_3d=true
	view.msaa_3d=Viewport.MSAA_4X
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var game := Fixture.new()
	view.add_child(game)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color("242b2b")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("a5bccc")
	environment.ambient_light_energy=.6
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled=true
	env.environment=environment
	game.add_child(env)
	var sunlight:=DirectionalLight3D.new()
	sunlight.rotation_degrees=Vector3(-32,-35,0)
	sunlight.light_color=Color("ffd2a0")
	sunlight.light_energy=2.3
	sunlight.shadow_enabled=true
	game.add_child(sunlight)
	var rim:=DirectionalLight3D.new()
	rim.rotation_degrees=Vector3(-20,145,0)
	rim.light_color=Color("8dc4e0")
	rim.light_energy=1.3
	game.add_child(rim)
	game.player = Player.new()
	var body:=Node3D.new()
	body.name="Body"
	game.player.add_child(body)
	var cam:=Camera3D.new()
	cam.name="Camera3D"
	game.player.add_child(cam)
	game.add_child(game.player)
	game.player.set_physics_process(false)
	var camera := Camera3D.new()
	camera.fov=34
	camera.current=true
	game.add_child(camera)
	var gun:=Firearm.new()
	gun.game=game
	game.add_child(gun)
	gun.reset_round()
	for id in 4:
		game.player.select_character(id)
		gun.reset_round()
		gun.fire()
		gun.flash.visible=false
		gun.flash_light.visible=false
		for tracer in gun._tracers:
			tracer.node.visible=false
		camera.position=Vector3(2.0,1.65,-2.7)
		camera.look_at(Vector3(0,1.05,-.15))
		for i in 12: await process_frame
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png("res://previews/character-firearm-%d.png"%id)
	print("FIREARM GPU PREVIEW: PASS")
	quit()
