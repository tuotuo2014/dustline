extends SceneTree
var failed := 0

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
	if not value:
		failed+=1
		push_error(label)

func run() -> void:
	var viewport := SubViewport.new()
	root.add_child(viewport)
	var budget := preload("res://render_budget.gd").new()
	viewport.add_child(budget)
	for size in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2940,1846),Vector2i(3840,2160),Vector2i(1080,1920)]:
		viewport.size=size
		await process_frame
		var internal := Vector2(size)*viewport.scaling_3d_scale
		check(internal.x<=1280.01 and internal.y<=720.01,"Fullscreen 3D pixel budget respected at "+str(size))
		check(viewport.size==size,"UI/output size is preserved at "+str(size))
		if size.x<=1280 and size.y<=720:
			check(is_equal_approx(viewport.scaling_3d_scale,1.0),"No unnecessary downscaling on smaller screens")
	viewport.size=Vector2i(1280,720)
	await process_frame
	check(is_equal_approx(viewport.scaling_3d_scale,1.0),"Native sharpness restored after resizing from a large display")
	viewport.free()
	print("RENDER BUDGET REGRESSION: ",failed," failures")
	quit(1 if failed else 0)
