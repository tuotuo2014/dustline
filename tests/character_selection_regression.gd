extends SceneTree
var game: Node3D
var hud: CanvasLayer
var player: CharacterBody3D
var failed := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:
		failed+=1
		push_error(label)
	else: print("PASS: "+label)
func frames(count: int) -> void:
	for i in count: await physics_frame
	await process_frame
func click(button: Button) -> void:
	await frames(2)
	var point := button.get_global_transform_with_canvas()*(button.size*.5)
	var motion := InputEventMouseMotion.new()
	motion.position=point
	motion.global_position=point
	root.push_input(motion,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=point
		event.global_position=point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(event,true)
		await frames(2)
func run() -> void:
	root.size=Vector2i(1920,1080)
	root.content_scale_size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	hud=game.get_node("UI")
	player=game.get_node("Player")
	await frames(6)
	var face_hashes: Array[int]=[]
	for id in [1,2,3,0]:
		game.open_menu()
		await click(hud._character_buttons[id])
		check(player.character_id==id and hud.selected_character_id==id,"Actual character card selects identity %d"%id)
		check(player.character.get_script()==hud._preview_model.get_script(),"Preview and player use identical model resource %d"%id)
		if id>0:
			check(player.character.archetype==id and hud._preview_model.archetype==id,"Identity configured before building player and preview %d"%id)
		var face: MeshInstance3D=player.character.head.get_node("Face")
		var signature: int=hash(face.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
		check(not face_hashes.has(signature),"Identity %d has unique facial geometry"%id)
		face_hashes.append(signature)
		await click(hud._mode_buttons[0])
		check(game.active and player.controls_enabled and not player.rotating_camera,"Selected character %d starts playable without camera input leak"%id)
		game.damage_grace=9999
		player.global_position=Vector3(0,.035,65)
		player.velocity=Vector3.ZERO
		await frames(12)
		var start := player.global_position
		Input.action_press("move_forward")
		Input.action_press("sprint")
		await frames(60)
		check(player.global_position.distance_to(start)>4.8 and player.character.run_blend>.80,"Character %d sprints with locomotion animation"%id)
		Input.action_press("jump")
		await frames(6)
		Input.action_release("jump")
		check(player.position.y>.35 and not player.is_on_floor(),"Character %d really jumps"%id)
		Input.action_release("move_forward")
		Input.action_release("sprint")
		await frames(55)
		check(player.is_on_floor(),"Character %d lands back on terrain"%id)
		game.scrap=4
		game.open_menu()
		await click(hud._resume)
		check(game.active and game.scrap==4 and player.character_id==id,"Continue preserves chosen character and progress %d"%id)
		game.restart_game()
		check(player.character_id==id and game.scrap==0,"Restart preserves identity and resets round %d"%id)
	game.open_menu()
	await click(hud._character_buttons[2])
	for mode in [1,2]:
		game.open_menu()
		await click(hud._mode_buttons[mode])
		check(game.mode==mode and game.active and player.character_id==2,"Selected character remains when entering mode %d"%mode)
	print("CHARACTER SELECTION REGRESSION: %d checks, %d failures"%[checks,failed])
	quit(1 if failed else 0)
