extends CanvasLayer
## Finger ownership keeps movement, camera, and action touches independent.
## This file exists only in the standalone mobile project.
const FONT = preload("res://assets/fonts/NotoSansSC.ttf")
var _label_font: FontVariation
const MOVE_ACTIONS := ["move_left", "move_right", "move_forward", "move_back"]
const BUTTON_LABELS := {
	"fire_weapon": "开火", "jump": "跳跃", "character_skill": "技能",
	"interact": "交互", "aim_scope": "瞄准", "sprint": "奔跑",
	"heal": "治疗", "repel": "驱赶", "build_shelter": "搭棚"
}
var player: CharacterBody3D
var game: Node
var movement_vector := Vector2.ZERO
var touch_input_started := false
var sprint_toggled := false
var controls_visible := false
var joystick_center := Vector2.ZERO
var joystick_radius := 76.0
var joystick_knob := Vector2.ZERO
var safe_rect := Rect2()
var button_regions: Dictionary = {}
var button_pressed: Dictionary = {}
var move_finger := -1
var look_finger := -1
var touch_roles: Dictionary = {}
var _surface: Control
var _scale := 1.0
var _last_viewport_size := Vector2.ZERO
var _held_actions: Dictionary = {}
var _fire_repeat := 0.0
var _input_epoch := 0

class TouchSurface extends Control:
	var controls: CanvasLayer
	func _draw() -> void:
		controls.draw_controls(self)

func _ready() -> void:
	name = "MobileControls"
	_label_font=FontVariation.new()
	_label_font.base_font=FONT
	_label_font.variation_opentype={2003265652:550.0}
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_surface = TouchSurface.new()
	_surface.controls = self
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_surface)
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_relayout()
	_surface.hide()

func available() -> bool:
	if not is_instance_valid(player) or not player.controls_enabled: return false
	if not is_instance_valid(game): return true # Isolated controller tests / preview.
	return bool(game.active) and not bool(game.round_over) and game.hud._hud.visible

func _process(delta: float) -> void:
	var next_visible := available()
	if not next_visible and controls_visible: release_all()
	controls_visible = next_visible
	_surface.visible = next_visible
	if get_viewport().get_visible_rect().size != _last_viewport_size: _relayout()
	if button_pressed.get("fire_weapon", false):
		_fire_repeat -= delta
		if _fire_repeat <= 0.0:
			_fire_repeat = .16
			_queue_action("fire_weapon", true)
			_queue_action("fire_weapon", false)
	_surface.queue_redraw()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		release_all()

func _exit_tree() -> void:
	release_all()

func _input(event: InputEvent) -> void:
	# Only already-owned fingers are handled here. New touches reach normal GUI
	# controls first, so menus, tutorial buttons, and the HUD stay tappable.
	if event is InputEventScreenTouch and not event.pressed and touch_roles.has(event.index):
		_release_finger(event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and touch_roles.has(event.index):
		if not available():
			release_all()
		else:
			_drag_finger(event.index, event.position, event.relative)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not available(): return
	if event is InputEventScreenTouch and event.pressed:
		if _press_finger(event.index, event.position):
			get_viewport().set_input_as_handled()

func _press_finger(index: int, position: Vector2) -> bool:
	if touch_roles.has(index) or not safe_rect.has_point(position): return false
	touch_input_started = true
	for action in button_regions:
		var region: Dictionary = button_regions[action]
		if position.distance_to(region.center) <= float(region.radius) + 7.0 * _scale:
			touch_roles[index] = action
			button_pressed[action] = true
			if action == "sprint":
				sprint_toggled = not sprint_toggled
				_set_held_action("sprint", sprint_toggled)
			elif action == "fire_weapon":
				_fire_repeat = .32
				_queue_action(action, true)
				_queue_action(action, false)
			else:
				_set_held_action(action, true)
			return true
	if move_finger == -1 and position.distance_to(joystick_center) < joystick_radius * 1.65:
		move_finger = index
		touch_roles[index] = "move"
		_set_joystick(position)
		return true
	# Keep the left side free of accidental camera changes while finding the stick.
	if look_finger == -1 and position.x > safe_rect.position.x + safe_rect.size.x * .43:
		look_finger = index
		touch_roles[index] = "look"
		player.touch_look_active = true
		return true
	return false

func _drag_finger(index: int, position: Vector2, relative: Vector2) -> void:
	var role: String = touch_roles.get(index, "")
	if role == "move": _set_joystick(position)
	elif role == "look": player.apply_touch_look(relative / _scale)

func _release_finger(index: int) -> void:
	var role: String = touch_roles.get(index, "")
	touch_roles.erase(index)
	if role == "move":
		move_finger = -1
		movement_vector = Vector2.ZERO
		joystick_knob = Vector2.ZERO
		_release_movement()
	elif role == "look":
		look_finger = -1
		if is_instance_valid(player): player.touch_look_active = false
	elif not role.is_empty():
		# Releasing one of two fingers on the same button cannot cancel the other.
		var still_held := touch_roles.values().has(role)
		button_pressed[role] = still_held
		if not still_held and role not in ["sprint", "fire_weapon"]:
			_set_held_action(role, false)

func _set_joystick(position: Vector2) -> void:
	joystick_knob = (position - joystick_center).limit_length(joystick_radius)
	var raw := joystick_knob / joystick_radius
	var magnitude := raw.length()
	movement_vector = Vector2.ZERO if magnitude < .12 else raw.normalized() * ((magnitude - .12) / .88)
	for action in MOVE_ACTIONS: Input.action_release(action)
	if movement_vector.x < 0: Input.action_press("move_left", -movement_vector.x)
	if movement_vector.x > 0: Input.action_press("move_right", movement_vector.x)
	if movement_vector.y < 0: Input.action_press("move_forward", -movement_vector.y)
	if movement_vector.y > 0: Input.action_press("move_back", movement_vector.y)

func _release_movement() -> void:
	for action in MOVE_ACTIONS: Input.action_release(action)

func _set_held_action(action: String, pressed: bool) -> void:
	if bool(_held_actions.get(action, false)) == pressed: return
	_held_actions[action] = pressed
	_queue_action(action, pressed)

func _queue_action(action: String, pressed: bool) -> void:
	# Deferred dispatch avoids replacing the original touch event mid-propagation.
	_dispatch_action.call_deferred(action, pressed, _input_epoch)

func _dispatch_action(action: String, pressed: bool, epoch: int) -> void:
	if epoch != _input_epoch: return
	if pressed and not available(): return
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)

func release_all() -> void:
	_input_epoch += 1
	var had_movement := move_finger != -1
	touch_roles.clear()
	move_finger = -1
	look_finger = -1
	movement_vector = Vector2.ZERO
	joystick_knob = Vector2.ZERO
	button_pressed.clear()
	sprint_toggled = false
	if had_movement: _release_movement()
	for action in _held_actions:
		if _held_actions[action]:
			Input.action_release(action)
	_held_actions.clear()
	if is_instance_valid(player): player.touch_look_active = false

func is_looking() -> bool:
	return look_finger != -1

func action_rect(action: String) -> Rect2:
	if not button_regions.has(action): return Rect2()
	var region: Dictionary = button_regions[action]
	return Rect2(region.center-Vector2.ONE*region.radius, Vector2.ONE*region.radius*2.0)

func safe_area_rect() -> Rect2:
	return safe_rect

func _relayout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	_last_viewport_size = viewport_size
	safe_rect = Rect2(Vector2.ZERO, viewport_size)
	if OS.has_feature("android") or OS.has_feature("ios"):
		var screen_safe := DisplayServer.get_display_safe_area()
		var window_size := Vector2(get_window().size)
		if screen_safe.size.x > 0 and screen_safe.size.y > 0 and window_size.x > 0 and window_size.y > 0:
			var window_safe := Rect2(Vector2(screen_safe.position - get_window().position), Vector2(screen_safe.size))
			window_safe = window_safe.intersection(Rect2(Vector2.ZERO, window_size))
			if window_safe.has_area():
				safe_rect = Rect2(window_safe.position / window_size * viewport_size, window_safe.size / window_size * viewport_size)
	_scale = clampf(minf(safe_rect.size.y / 720.0, safe_rect.size.x / 1280.0), .4, 2.5)
	var left := safe_rect.position.x
	var bottom := safe_rect.end.y
	var right := safe_rect.end.x
	joystick_radius = 76.0 * _scale
	joystick_center = Vector2(left + 130.0 * _scale, bottom - 130.0 * _scale)
	button_regions = {
		"fire_weapon": {"center": Vector2(right-95*_scale,bottom-170*_scale), "radius": 48*_scale},
		"jump": {"center": Vector2(right-95*_scale,bottom-65*_scale), "radius": 38*_scale},
		"character_skill": {"center": Vector2(right-205*_scale,bottom-155*_scale), "radius": 40*_scale},
		"interact": {"center": Vector2(right-205*_scale,bottom-62*_scale), "radius": 35*_scale},
		"aim_scope": {"center": Vector2(right-95*_scale,bottom-275*_scale), "radius": 32*_scale},
		"sprint": {"center": Vector2(left+265*_scale,bottom-75*_scale), "radius": 36*_scale},
		"heal": {"center": Vector2(right-305*_scale,bottom-62*_scale), "radius": 32*_scale},
		"repel": {"center": Vector2(right-305*_scale,bottom-155*_scale), "radius": 32*_scale},
		"build_shelter": {"center": Vector2(right-305*_scale,bottom-245*_scale), "radius": 32*_scale}
	}
	# A rotation/resize ends current gestures rather than moving controls under fingers.
	release_all()

func draw_controls(surface: Control) -> void:
	var sand := Color("ebc679")
	var dark := Color(.08, .065, .035, .74)
	surface.draw_circle(joystick_center, joystick_radius, dark)
	surface.draw_arc(joystick_center, joystick_radius, 0, TAU, 64, Color(.92,.77,.47,.65), 2*_scale, true)
	surface.draw_circle(joystick_center+joystick_knob, 31*_scale, Color(.82,.65,.35,.60))
	surface.draw_arc(joystick_center+joystick_knob, 31*_scale,0,TAU,40,sand,1.5*_scale,true)
	_draw_label(surface,"移动",joystick_center+Vector2(0,joystick_radius+25*_scale),16,sand)
	for action in button_regions:
		var region: Dictionary = button_regions[action]
		var center: Vector2 = region.center
		var radius: float = region.radius
		var held: bool = button_pressed.get(action, false) or (action=="sprint" and sprint_toggled) or (action=="aim_scope" and player.scope_enabled)
		surface.draw_circle(center, radius, Color(.50,.33,.10,.88) if held else dark)
		surface.draw_arc(center,radius,0,TAU,48, sand if held else Color(.77,.66,.43,.65),2*_scale,true)
		_draw_label(surface, "疾跑中" if action=="sprint" and sprint_toggled else str(BUTTON_LABELS[action]), center+Vector2(0,7*_scale), 20, Color("ffe3a6"))
	_draw_label(surface,"拖动右侧空白处转动视角",Vector2(safe_rect.end.x-220*_scale,safe_rect.end.y-340*_scale),14,Color(.92,.81,.60,.65))

func _draw_label(surface: Control, caption: String, center: Vector2, font_size: int, tint: Color) -> void:
	var scaled := maxi(10, roundi(font_size*_scale))
	var width := _label_font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,scaled).x
	surface.draw_string(_label_font,center-Vector2(width*.5,0),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,scaled,tint)
