extends RefCounted
## Reconstructed rustworks: a navigable plant of real shells, pipework and open steel decks.
var w: Node3D
var site: Node3D
var m: Dictionary = {}
var rng := RandomNumberGenerator.new()

static func build(world: Node3D, district: Node3D) -> void:
	var b := new()
	b.setup(world,district,824911)
	b._plant()

func setup(world: Node3D, district: Node3D, seed_value: int) -> void:
	w=world
	site=district
	rng.seed=seed_value
	m=w.materials.duplicate()
	m.rust=_aged_metal(Color("72442f"),.76)
	m.teal=_aged_metal(Color("65847e"),.47)
	m.steel=_aged_metal(Color("353b36"),.23)
	m.ochre=_aged_metal(Color("ab873f"),.44)
	m.plaster=w._material("b1a18a",1,.97)
	m.pale=w._material("c5b79b",1,.96)
	m.wood=w._material("78604b",9,.96)
	m.brick=w._material("88573f",8,.98)
	m.oil=w._material("272824",4,.2,.18)

func _aged_metal(color: Color, corrosion: float) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code="""shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 paint : source_color=vec4(.4,.5,.5,1.);
uniform float rust_amount=.5;
varying vec3 p;
varying vec3 wn;
float hash(vec3 a){a=fract(a*.3183099+vec3(.13,.32,.71));a*=17.;return fract(a.x*a.y*a.z*(a.x+a.y+a.z));}
float n(vec3 a){vec3 i=floor(a),f=fract(a);f=f*f*(3.-2.*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;wn=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 float field=n(p*.72)*.57+n(p*2.8)*.27+n(p*8.0)*.16;
 float oxide=smoothstep(.83-rust_amount*.58,.94-rust_amount*.58,field);
 float trail=n(vec3(p.x*3.8,p.y*.09,p.z*3.8));
 vec3 rust=mix(vec3(.10,.032,.011),vec3(.31,.102,.032),n(p*3.0));
 vec3 clean=paint.rgb*(.73+n(p*.29)*.28);
 vec3 surface=mix(clean,rust,oxide);
 surface*=.75+trail*.29;
 float dust=max(wn.y,0.)*.21*n(p*.6);
 ALBEDO=mix(surface,vec3(.43,.35,.24),dust);
 ROUGHNESS=mix(.76,.96,oxide);
 METALLIC=mix(.45,.14,oxide);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader=shader
	mat.set_shader_parameter("paint",color)
	mat.set_shader_parameter("rust_amount",corrosion)
	return mat

func node(p: Node3D, title: String, position: Vector3, yaw := 0.0) -> Node3D:
	var n := Node3D.new()
	n.name=title
	n.position=position
	n.rotation.y=yaw
	p.add_child(n)
	return n

func box(p: Node3D, title: String, pos: Vector3, size: Vector3, material: Material, collide := false) -> MeshInstance3D:
	return w._box(p,title,pos,size,material,collide)

func rod(p: Node3D, a: Vector3, b: Vector3, radius: float, material: Material = null) -> void:
	w._rod(p,a,b,radius,material if material else m.rust)

func cylinder(p: Node3D, title: String, pos: Vector3, radius: float, height: float, material: Material, rotation := Vector3.ZERO, collide := false) -> Node3D:
	var n := node(p,title,pos)
	n.rotation=rotation
	w._disc(n,title+"Shell",Vector3.ZERO,radius,height,material,Vector3.ZERO)
	if collide:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var c := CylinderShape3D.new()
		c.radius=radius
		c.height=height
		shape.shape=c
		body.add_child(shape)
		n.add_child(body)
	return n

func ring(p: Node3D, title: String, center: Vector3, radius: float, thickness: float, material: Material, rotation := Vector3.ZERO) -> void:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in 49:
		var a := float(i)*TAU/48.0
		for j in 7:
			var b := float(j)*TAU/6.0
			vertices.append(Vector3(cos(a)*(radius+cos(b)*thickness),sin(b)*thickness,sin(a)*(radius+cos(b)*thickness)))
	for i in 48:
		for j in 6:
			var k := i*7+j
			indices.append_array([k,k+7,k+8,k,k+8,k+1])
	var mesh: MeshInstance3D=w._surface(p,title,vertices,indices,material)
	mesh.position=center
	mesh.rotation=rotation

func rubble(p: Node3D, center: Vector3, spread: Vector2, count: int, scale := 1.0) -> void:
	for i in count:
		var pos := center+Vector3(rng.randf_range(-spread.x,spread.x),.01,rng.randf_range(-spread.y,spread.y))
		var world_local := p.position+pos
		if absf(world_local.x)<8.5: continue
		var size := rng.randf_range(.3,1.2)*scale
		w._chunk(p,pos,Vector3(size*1.6,size*.55,size),m.brick if i%3==0 else m.concrete,size>1.4)
		if i%9==0:
			rod(p,pos+Vector3(-size*.5,.2,0),pos+Vector3(size*.7,.42,.5),.024)

func label(p: Node3D, title: String, position: Vector3, size := 50, color := Color("ddc9a1")) -> void:
	var l := Label3D.new()
	l.name="WeatheredLettering"
	l.text=title
	l.font=load("res://assets/fonts/NotoSansSC.ttf")
	l.font_size=size
	l.pixel_size=.018
	l.position=position
	l.modulate=color
	l.outline_size=0
	l.shaded=true
	p.add_child(l)

func _plant() -> void:
	site.set_meta("landmark","锈海能源厂")
	site.set_meta("safe_loot_positions",[Vector3(-14,0,45),Vector3(-20,0,-40),Vector3(20,0,35),Vector3(14,0,-54),Vector3(58,0,-9)])
	box(site,"ErodedAccessRoad",Vector3(0,-.012,0),Vector3(14,.04,164),m.asphalt)
	for z in range(-77,78,10):
		box(site,"FadedRoadDash",Vector3(0,.013,z),Vector3(.12,.012,3.1),m.roadmark)
	for x in [-10.5,10.5]:
		for z in [-60.0,-35.0,0.0,35.0,62.0]:
			box(site,"RoadsideBrokenKerb",Vector3(x,.13,z),Vector3(.45,.26,5.3),m.concrete,true)
	_drum(node(site,"GiantCorrodedBoiler",Vector3(-39,0,13)))
	_cooling_tower(node(site,"FracturedCoolingTower",Vector3(39,0,-37)))
	_chimney(node(site,"RustedExhaustStack",Vector3(-66,0,-30)))
	_pipe_gallery(node(site,"PipeGallery",Vector3(-37,0,-42)))
	for x in [28.0,52.0]:
		var tank := node(site,"AbandonedAuxiliaryTank",Vector3(x,0,48),.10 if x<40 else -.20)
		box(tank,"TankConcreteFoundation",Vector3(0,.6,0),Vector3(16,1.2,11),m.concrete,true)
		cylinder(tank,"HorizontalOilTank",Vector3(0,4.1,0),2.8,13.0,m.rust,Vector3(0,0,PI*.5),true)
		for x_ring in [-5.5,0.0,5.5]: ring(tank,"TankReinforcingHoop",Vector3(x_ring,4.1,0),2.86,.10,m.steel,Vector3(0,0,PI*.5))
		for x_base in [-4.0,4.0]: box(tank,"Saddle",Vector3(x_base,1.8,0),Vector3(1.0,1.2,5.0),m.steel,true)
		rod(tank,Vector3(6.6,3.5,0),Vector3(9,3.5,0),.28)
		rod(tank,Vector3(9,3.5,0),Vector3(9,.6,0),.28)
		rubble(tank,Vector3(0,0,7),Vector2(9,3),30)
	for z in [-62.0,58.0]:
		for x in [-67.0,-20.0,20.0,69.0]:
			box(site,"BrokenBoundaryPier",Vector3(x,1.5,z),Vector3(.62,3,.62),m.concrete,true)
	for x in [-24.0,24.0]:
		var post := node(site,"EntranceWarningSign",Vector3(x,0,70))
		rod(post,Vector3(-1,0,0),Vector3(-1,3.2,0),.055)
		rod(post,Vector3(1,0,0),Vector3(1,3.2,0),.055)
		box(post,"RustedWarningPlate",Vector3(0,2.55,0),Vector3(3.8,1.3,.12),m.ochre)
		label(post,"07 / 禁区" if x<0 else "锈海能源厂",Vector3(0,2.55,.08),31)
	rubble(site,Vector3(-53,0,49),Vector2(19,14),80)
	rubble(site,Vector3(39,0,-69),Vector2(27,8),100)
	for i in 12:
		var x := rng.randf_range(-69,-21)
		var z := rng.randf_range(-64,63)
		var plate := box(site,"AbandonedSheetSteel",Vector3(x,.22,z),Vector3(rng.randf_range(1.8,3.3),.07,rng.randf_range(1.0,2.4)),m.rust)
		plate.rotation=Vector3(rng.randf_range(-.15,.15),rng.randf_range(-PI,PI),.12)
	# Convex collision is confined to actual objects, leaving the road and service alleys open.

func _drum(p: Node3D) -> void:
	box(p,"ConcreteEquipmentPad",Vector3(0,.09,0),Vector3(31,.18,45),m.concrete)
	for x in [-9.5,9.5]:
		for z in [-15.0,-7.5,0.0,7.5,15.0]:
			box(p,"CorrodedLoadBearingColumn",Vector3(x,3.1,z),Vector3(.56,6.2,.56),m.steel,true)
			box(p,"ColumnFooting",Vector3(x,.4,z),Vector3(1.1,.8,1.1),m.concrete,true)
			if z<15: rod(p,Vector3(x,.9,z),Vector3(x,5.8,z+7.5),.095)
	for z in [-14.0,-5.0,5.0,14.0]:
		box(p,"BoilerSaddleBeam",Vector3(0,6.7,z),Vector3(24,.54,.55),m.steel)
		for x in [-6.2,6.2]: box(p,"BoilerSaddleSupport",Vector3(x,8.5,z),Vector3(1.4,3.5,.8),m.rust,true)
	cylinder(p,"RivetedSteamVessel",Vector3(0,15,0),8.6,34.0,m.teal,Vector3(PI*.5,0,0),true)
	for z in [-16.8,-11.0,-5.6,0.0,5.6,11.0,16.8]:
		ring(p,"VesselRivetedSeam",Vector3(0,15,z),8.67,.09,m.rust,Vector3(PI*.5,0,0))
		for i in 20:
			var a := i*TAU/20.0
			cylinder(p,"BoilerRivet",Vector3(cos(a)*8.76,15+sin(a)*8.76,z),.055,.07,m.steel,Vector3(0,0,a-PI*.5))
	for z in [-17.09,17.09]:
		var facing := 1.0 if z>0 else -1.0
		cylinder(p,"DomedCircularEnd",Vector3(0,15,z),8.56,1.20,m.rust,Vector3(PI*.5,0,0))
		ring(p,"CircularEndFlange",Vector3(0,15,z+facing*.27),8.28,.15,m.steel,Vector3(PI*.5,0,0))
		ring(p,"InsetCircularSeam",Vector3(0,15,z+facing*.30),5.2,.09,m.teal,Vector3(PI*.5,0,0))
		cylinder(p,"CentralPressureHatch",Vector3(0,15,z+facing*.5),2.2,.35,m.steel,Vector3(PI*.5,0,0))
		ring(p,"HatchBoltRing",Vector3(0,15,z+facing*.72),1.77,.11,m.rust,Vector3(PI*.5,0,0))
		cylinder(p,"HatchCap",Vector3(0,15,z+facing*.8),1.23,.10,m.teal,Vector3(PI*.5,0,0))
		for i in 16:
			var a := i*TAU/16.0
			rod(p,Vector3(cos(a)*2.25,15+sin(a)*2.25,z+facing*.38),Vector3(cos(a)*8.1,15+sin(a)*8.1,z+facing*.38),.044,m.steel)
			cylinder(p,"HatchFastener",Vector3(cos(a)*1.78,15+sin(a)*1.78,z+facing*.84),.063,.12,m.ochre,Vector3(PI*.5,0,0))
	# Perforated side catwalks and their handrails cast fine structural shadows.
	for x in [-11.0,11.0]:
		var deck := box(p,"ServiceCatwalk",Vector3(x,6.05,0),Vector3(2.1,.16,39),m.steel,true)
		deck.mesh=null
		for edge_x in [-.98,.98]: box(p,"CatwalkEdgeChannel",Vector3(x+edge_x,6.05,0),Vector3(.12,.16,39),m.steel)
		for j in 130: box(p,"OpenGratingCrossTread",Vector3(x,6.07,-19.35+j*.30),Vector3(1.92,.10,.055),m.steel)
		for z in range(-19,20,3):
			rod(p,Vector3(x+signf(x)*.9,6.1,z),Vector3(x+signf(x)*.9,7.28,z),.032)
		for y in [6.67,7.28]: rod(p,Vector3(x+signf(x)*.9,y,-19),Vector3(x+signf(x)*.9,y,19),.035)
	box(p,"TopServicePlatform",Vector3(0,23.6,0),Vector3(3.8,.16,25),m.steel)
	for x in [-1.75,1.75]:
		for z in range(-12,13,3): rod(p,Vector3(x,23.6,z),Vector3(x,24.75,z),.03)
		rod(p,Vector3(x,24.75,-12),Vector3(x,24.75,12),.034)
	for z in [-8.0,4.0]:
		cylinder(p,"PressureVent",Vector3(0,24.5,z),.75,1.7,m.rust)
		ring(p,"PressureVentFlange",Vector3(0,25.37,z),.80,.1,m.steel)
	# Curving access ladder across the end dome, clearly visible from the road.
	for i in 28:
		var t := float(i)/27.0
		var a := -.28+t*1.65
		var c := Vector3(-cos(a)*8.9,15+sin(a)*8.9,17.7)
		rod(p,c+Vector3(0,0,-.05),c+Vector3(0,0,.88),.03,m.steel)
		if i<27:
			var a2 := -.28+float(i+1)/27.0*1.65
			var d := Vector3(-cos(a2)*8.9,15+sin(a2)*8.9,17.7)
			for dz in [-.05,.88]: rod(p,c+Vector3(0,0,dz),d+Vector3(0,0,dz),.036)
	for x in [-13.0,13.0]:
		rod(p,Vector3(x,5.0,-22),Vector3(x,5.0,22),.62,m.teal)
		for z in range(-21,22,6): ring(p,"MainPipeFlange",Vector3(x,5,z),.68,.10,m.rust,Vector3(PI*.5,0,0))
		rod(p,Vector3(x,5,22),Vector3(x,1.0,22),.62,m.teal)
		rod(p,Vector3(x,1,22),Vector3(x+signf(x)*3.0,1,22),.62,m.teal)
	for z in [-8.0,9.0]:
		rod(p,Vector3(8,13,z),Vector3(15,13,z),.42,m.rust)
		rod(p,Vector3(15,13,z),Vector3(15,5,z),.42,m.rust)
		_valve(p,Vector3(15,8,z),.8)
	label(p,"СТАНЦИЯ 07",Vector3(0,11.3,17.41),48)
	rubble(p,Vector3(-2,0,23),Vector2(11,3),44)

func _valve(p: Node3D, position: Vector3, radius: float) -> void:
	rod(p,position,position+Vector3(0,0,1.2),.10,m.steel)
	ring(p,"RedValveHandwheel",position+Vector3(0,0,1.3),radius,.055,m.rust,Vector3(PI*.5,0,0))
	for i in 5:
		var a := i*TAU/5.0
		rod(p,position+Vector3(0,0,1.3),position+Vector3(cos(a)*radius,sin(a)*radius,1.3),.036,m.steel)

const TOWER_SECTORS := 80
const TOWER_ROWS := 26

func _tower_radius(t: float) -> float:
	# Revolved engineering shell: flared base, contracted throat, rising crown.
	var height := t*46.5
	var throat_height := 29.4
	var profile := 10.5*sqrt(1.0+pow((height-throat_height)/22.0,2.0))
	var foundation_flare := 1.0-smoothstep(.0,.14,t)
	var crown_flare := smoothstep(.91,1.0,t)
	return profile+foundation_flare*.65+crown_flare*.36

func _tower_missing(row: int, sector: int) -> bool:
	var t := (row+.5)/float(TOWER_ROWS)
	var angle := posmod(sector,TOWER_SECTORS)*TAU/TOWER_SECTORS
	# Slanting connected fractures grow out of a crown collapse and a ground breach.
	var crown := t>.70 and angle>.57+(1.0-t)*.8 and angle<2.05+(t-.72)*1.15+sin(row*1.8)*.08
	var base_breach := t<.24 and angle>2.04-t*1.1 and angle<3.52+t*.6
	var impact := pow((t-.51)/.09,2.0)+pow((angle-4.91)/.24,2.0)<1.0
	return crown or base_breach or impact

func _cooling_tower(p: Node3D) -> void:
	var outer := PackedVector3Array()
	var outer_i := PackedInt32Array()
	var edge := PackedVector3Array()
	var edge_i := PackedInt32Array()
	# Indexed shared rings prevent cracks between plates; inner profile has its own
	# varying thickness rather than copying a constant inward offset.
	for inside in 2:
		for row in TOWER_ROWS+1:
			var t := row/float(TOWER_ROWS)
			for sector in TOWER_SECTORS:
				var a := sector*TAU/TOWER_SECTORS
				var radius := _tower_radius(t)
				var thickness := .23+.36*pow(1.0-t,3.0)+.10*smoothstep(.86,1.0,t)
				var boundary := _tower_missing(clampi(row-1,0,TOWER_ROWS-1),sector)!=_tower_missing(clampi(row,0,TOWER_ROWS-1),sector) or _tower_missing(clampi(row,0,TOWER_ROWS-1),sector-1)!=_tower_missing(clampi(row,0,TOWER_ROWS-1),sector)
				var height := 3.5+t*46.5
				if boundary:
					radius+=sin(sector*2.17+row*1.13)*.11
					height+=sin(sector*1.93-row*2.17)*.32
				if row==TOWER_ROWS: height-=.12+.38*(.5+.5*sin(sector*2.03))
				if inside==1: radius-=thickness
				outer.append(Vector3(cos(a)*radius,height,sin(a)*radius))
	var inner_offset := (TOWER_ROWS+1)*TOWER_SECTORS
	for row in TOWER_ROWS:
		for sector in TOWER_SECTORS:
			if _tower_missing(row,sector): continue
			var next := (sector+1)%TOWER_SECTORS
			var corners := [row*TOWER_SECTORS+sector,row*TOWER_SECTORS+next,(row+1)*TOWER_SECTORS+next,(row+1)*TOWER_SECTORS+sector]
			outer_i.append_array([corners[0],corners[1],corners[2],corners[0],corners[2],corners[3]])
			outer_i.append_array([corners[0]+inner_offset,corners[2]+inner_offset,corners[1]+inner_offset,corners[0]+inner_offset,corners[3]+inner_offset,corners[2]+inner_offset])
			var exposed := [row==0 or _tower_missing(row-1,sector),_tower_missing(row,sector+1),row==TOWER_ROWS-1 or _tower_missing(row+1,sector),_tower_missing(row,sector-1)]
			for e in 4:
				if not exposed[e]: continue
				var c: int=corners[e]
				var d: int=corners[(e+1)%4]
				var k := edge.size()
				# The fractured thickness is triangulated through an exposed aggregate ridge.
				var center := (outer[c]+outer[d]+outer[c+inner_offset]+outer[d+inner_offset])*.25
				center.y+=sin(c*.71)*.06
				edge.append_array([outer[c],outer[d],outer[d+inner_offset],outer[c+inner_offset],center])
				edge_i.append_array([k,k+1,k+4,k+1,k+2,k+4,k+2,k+3,k+4,k+3,k,k+4])
				if row>1 and (row+sector+e)%3==0:
					var mid := (outer[c]+outer[d])*.5
					var direction := (outer[d]-outer[c]).normalized()
					rod(p,mid-direction*.36,mid+direction*.65+Vector3(.12,.3,.08),.025,m.steel)
	# Omit vertices belonging entirely to missing shell panels.
	var used: Dictionary={}
	var welded := PackedVector3Array()
	for i in outer_i.size():
		var source := outer_i[i]
		if not used.has(source):
			used[source]=welded.size()
			welded.append(outer[source])
		outer_i[i]=used[source]
	var shell: MeshInstance3D=w._surface(p,"FracturedHyperboloidConcreteShell",welded,outer_i,m.plaster)
	shell.set_meta("shell_topology","welded_variable_thickness_hyperboloid")
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	collision.shape=shell.mesh.create_trimesh_shape()
	body.add_child(collision)
	shell.add_child(body)
	w._surface(p,"ExposedConcreteThickness",edge,edge_i,m.concrete,true)

	for i in 28:
		var a := i*TAU/28.0
		var a2 := (i+1)*TAU/28.0
		var foot := Vector3(cos(a)*19.5,0,sin(a)*19.5)
		var top := Vector3(cos(a+.06)*18.1,3.7,sin(a+.06)*18.1)
		rod(p,foot,top,.18,m.concrete)
		rod(p,foot,Vector3(cos(a2)*18.1,3.7,sin(a2)*18.1),.14,m.concrete)
		box(p,"TowerFooting",foot+Vector3(0,.3,0),Vector3(1.05,.6,1.05),m.concrete,true)
	ring(p,"BottomConcreteRing",Vector3(0,3.7,0),18.0,.24,m.concrete)
	for i in 5:
		var debris := box(p,"FallenCurvedShellFragment",Vector3(-16+i*7,.9,22+sin(i)*3),Vector3(5.0,.5,4.5),m.plaster,true)
		debris.rotation=Vector3(.3+i*.10,i*.6,-.3)
	rubble(p,Vector3(0,0,21),Vector2(19,8),70,1.5)

func _chimney(p: Node3D) -> void:
	cylinder(p,"StackConcretePlinth",Vector3(0,1.2,0),4.9,2.4,m.concrete,Vector3.ZERO,true)
	cylinder(p,"StripedSteelChimney",Vector3(0,27.8,0),2.45,52,m.rust,Vector3.ZERO,true)
	for h in [5.0,14.0,23.0,32.0,41.0,49.0]:
		cylinder(p,"PaleCorrodedStackBand",Vector3(0,h+1.6,0),2.467,3.3,m.teal)
		ring(p,"ChimneySeam",Vector3(0,h,0),2.49,.10,m.steel)
	for h in [14.0,31.0,48.0]:
		ring(p,"CircularInspectionDeck",Vector3(0,h,0),3.1,.43,m.steel)
		ring(p,"InspectionHandrail",Vector3(0,h+1.1,0),3.42,.035,m.rust)
		for i in 16:
			var a := i*TAU/16.0
			rod(p,Vector3(cos(a)*3.42,h,sin(a)*3.42),Vector3(cos(a)*3.42,h+1.1,sin(a)*3.42),.03)
	for h in range(3,53): rod(p,Vector3(-.42,h,2.66),Vector3(.42,h,2.66),.025,m.steel)
	for x in [-.44,.44]: rod(p,Vector3(x,2,2.66),Vector3(x,53,2.66),.035)
	cylinder(p,"DarkHollowStackOpening",Vector3(0,53.82,0),2.15,.018,m.black)

func _pipe_gallery(p: Node3D) -> void:
	for x in [-25.0,-13.0,0.0,13.0,25.0]:
		for z in [-5.0,5.0]: box(p,"PipeRackColumn",Vector3(x,4,z),Vector3(.25,8,.25),m.steel,true)
		box(p,"PipeRackCrossbar",Vector3(x,7.9,0),Vector3(.32,.26,11.4),m.steel)
		rod(p,Vector3(x,1,-5),Vector3(x,7.6,5),.06)
	for z in [-3.5,-1.2,1.2,3.5]:
		rod(p,Vector3(-27,8.45,z),Vector3(25.8,8.45,z),.37,m.teal if z<0 else m.rust)
		for x in range(-25,27,8): ring(p,"PipeRackJoint",Vector3(x,8.45,z),.42,.07,m.steel,Vector3(0,0,PI*.5))
		_pipe_bend(p,Vector3(25.8,8.45,z),Vector3(27,8.45,z),Vector3(27,7.25,z),.37,m.rust)
		rod(p,Vector3(27,7.25,z),Vector3(27,1.4,z),.37,m.rust)

func _pipe_bend(parent: Node3D, a: Vector3, corner: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var previous := a
	for i in range(1,9):
		var t := i/8.0
		var point := a*(1.0-t)*(1.0-t)+corner*2.0*t*(1.0-t)+b*t*t
		rod(parent,previous,point,radius,mat)
		previous=point
