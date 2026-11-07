extends RefCounted
## Valuable trails lead through all five districts; mission scrap stays separate.
const Props = preload("res://economy_props.gd")
const TRAIL := [
	Vector3(-2.7,0,18.0),Vector3(-9.7,0,24.6),Vector3(-17.8,0,1.7),Vector3(-19.6,0,-4.2),
	Vector3(-34.3,0,-25.4),Vector3(-17.1,0,-31.2),Vector3(-0.6,0,-40.8),Vector3(5.9,0,-53.0),
	Vector3(25.2,0,-35.2),Vector3(27.9,0,-27.1),Vector3(38.0,0,-11.1),Vector3(33.7,0,7.2),
	Vector3(20.0,0,28.9),Vector3(-3.8,0,39.5),Vector3(-19.3,0,37.9),Vector3(-36.3,0,19.7),
	Vector3(-36.2,0,7.5),Vector3(-1.3,0,-11.9),Vector3(-44.4,0,-31.7),Vector3(-68.1,0,-55.7),
	Vector3(-78.5,0,-75.7),Vector3(-76.7,0,-67.7),Vector3(47.1,0,-37.6),Vector3(81.5,0,-63.3),
	Vector3(103.2,0,-86.0),Vector3(106.8,0,-82.6),Vector3(-56.9,0,67.0),Vector3(-60.8,0,92.1),
	Vector3(-81.8,0,107.9),Vector3(-75.9,0,105.0),Vector3(1.8,0,-86.3),Vector3(-1.8,0,-110.0),
	Vector3(2.5,0,-172.7),Vector3(8.1,0,-179.3),Vector3(65.3,0,64.7),Vector3(80.5,0,83.7),
	Vector3(118.9,0,140.7),Vector3(126.6,0,143.6),Vector3(-130.3,0,123.9),Vector3(143.8,0,-126.5),
]
var id := ""
var bag_value := 0
var bag_items := 0
var valuable_count := 0

func reset(round_id: String = "") -> void:
	id=round_id
	bag_value=0
	bag_items=0
	valuable_count=0

func spawn(game: Node3D) -> void:
	var positions: Array=[]
	positions.assign(TRAIL)
	if game.region_id>0:
		positions.clear()
		var center: Vector3=game.region.position
		for local in game.Layout.REGION_LOOT: positions.append(center+local+Vector3(1.8,0,.3))
	for i in positions.size():
		var kind := "coin"
		if i%4==1: kind="watch"
		if i%4==2 and i>=16: kind="chip"
		if i in [20,24,28,33,36,38,39]: kind="gold"
		var pickup: Area3D=Props.pickup(kind)
		pickup.position=game._safe_resource_position(positions[i])
		pickup.set_meta("taken",false)
		game.round_root.add_child(pickup)
		game.pickups.append(pickup)
		valuable_count+=1

func collect(pickup: Area3D) -> String:
	bag_value+=int(pickup.get_meta("value",0))
	bag_items+=1
	return "%s +1 · 待带回 %d G · 成功撤离后入账" % [pickup.get_meta("display_name","贵重物品"),bag_value]
