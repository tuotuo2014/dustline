extends "res://player.gd"
## A network teammate uses the same survivor model, without local input/camera processing.
var target_position := Vector3.ZERO
var target_yaw := 0.0
var grounded := true
var peer_id := 0
var nickname := "队友"
var label: Label3D
var initialized := false
func _ready() -> void:
	var body := Node3D.new()
	body.name="Body"
	add_child(body)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius=.3
	capsule.height=1.86
	shape.shape=capsule
	shape.position.y=.93
	add_child(shape)
	collision_layer=0
	collision_mask=1
	super._ready()
	label=Label3D.new()
	label.font=load("res://assets/fonts/NotoSansSC.ttf")
	label.font_size=24
	label.pixel_size=.0035
	label.outline_size=3
	label.position.y=2.25
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate=Color("77e4dd")
	label.text=nickname
	add_child(label)
func _input(_event: InputEvent) -> void: pass
func _unhandled_input(_event: InputEvent) -> void: pass
func _physics_process(delta: float) -> void:
	if not initialized: return
	global_position=global_position.lerp(target_position,1.0-exp(-delta*18))
	$Body.rotation.y=lerp_angle($Body.rotation.y,target_yaw,1.0-exp(-delta*18))
	dash_remaining=maxf(0,dash_remaining-delta)
	character.animate(delta,Vector2(velocity.x,velocity.z).length(),grounded,velocity.y)
func set_pose(pos: Vector3, yaw: float, motion: Vector3, floor_contact: bool, snap := false) -> void:
	target_position=pos
	target_yaw=yaw
	velocity=motion
	grounded=floor_contact
	if not initialized or snap: global_position=pos
	initialized=true
func begin_dash() -> bool:
	if not grounded or dash_remaining>0: return false
	dash_remaining=.38
	return true
