extends Control
## Surface wear stays beneath text and never intercepts clicks.
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	clip_contents=true
	resized.connect(queue_redraw)
func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed=5904
	for i in 440:
		var p := Vector2(rng.randf()*size.x,rng.randf()*size.y)
		draw_line(p,p+Vector2(rng.randf_range(.5,3.5),0),Color(.12,.07,.02,.09),1)
	for i in 30:
		var p := Vector2(rng.randf()*size.x,rng.randf_range(0,6))
		if i%2: p.y=size.y-p.y
		draw_line(p,p+Vector2(rng.randf_range(3,24),rng.randf_range(-2,2)),Color(.1,.06,.02,.22),1)
	for p in [Vector2(2,2),Vector2(size.x-2,2),Vector2(2,size.y-2),size-Vector2(2,2)]:
		draw_circle(p,2,Color(.07,.05,.025,.35))
