extends Node
## Bound 3D pixel cost on Retina/fullscreen displays. Canvas UI stays at native resolution.
const MAX_RENDER_SIZE := Vector2(1920,1080)
var _viewport: Viewport

func _ready() -> void:
	_viewport=get_viewport()
	_viewport.size_changed.connect(_fit_resolution)
	_fit_resolution()

func _fit_resolution() -> void:
	var size := Vector2(_viewport.get_visible_rect().size)
	if _viewport is Window:
		size=Vector2((_viewport as Window).size)
	elif _viewport is SubViewport:
		size=Vector2((_viewport as SubViewport).size)
	_viewport.scaling_3d_mode=Viewport.SCALING_3D_MODE_FSR
	_viewport.scaling_3d_scale=clampf(minf(MAX_RENDER_SIZE.x/maxf(size.x,1.0),MAX_RENDER_SIZE.y/maxf(size.y,1.0)),.25,1.0)
	_viewport.mesh_lod_threshold=2.0
