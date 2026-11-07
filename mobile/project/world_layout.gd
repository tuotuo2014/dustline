extends RefCounted
## Shared world dimensions keep traversal, creatures and expedition placement aligned.
const EXTENT := 210.0
const BUILD_EXTENT := EXTENT - 5.0
const TERRAIN_SIZE := 640.0
const BASE := Vector3(0,0,18)
const EXIT := Vector3(6,0,-176)
const RELAYS := [Vector3(-76,0,-70),Vector3(105,0,-84),Vector3(-82,0,106)]
const DISTRICTS := [
	{"id":"service_station","name":"落日加油站","position":Vector3(-90,0,-56),"radius":27.0},
	{"id":"foundry","name":"旧熔炼厂","position":Vector3(99,0,-80),"radius":30.0},
	{"id":"settlement","name":"南部废城","position":Vector3(-87,0,100),"radius":29.0},
	{"id":"checkpoint","name":"北线检查站","position":Vector3(10,0,-155),"radius":28.0},
	{"id":"scrapyard","name":"东部拆解场","position":Vector3(118,0,118),"radius":31.0}
]

const REGIONS := [
	{"id":"overpass","name":"断桥荒原","position":Vector3.ZERO,"scene":"res://maps/overpass.tscn","extent":210.0,"description":"独立地图 · 断桥营地与五处废土聚落"},
	{"id":"rustworks","name":"锈海工业区","position":Vector3.ZERO,"scene":"res://maps/rustworks.tscn","extent":105.0,"description":"独立地图 · 锈蚀反应罐、冷却塔与管线迷宫"},
	{"id":"buried_city","name":"沙埋旧都","position":Vector3.ZERO,"scene":"res://maps/buried_city.tscn","extent":105.0,"description":"独立地图 · 高层残楼、埋沙公交与城市大道"},
	{"id":"dusk_settlement","name":"暮火聚落","position":Vector3.ZERO,"scene":"res://maps/dusk_settlement.tscn","extent":105.0,"description":"独立地图 · 黄昏棚屋、篝火与废车"}
]
const REGION_RELAYS := [Vector3(-42,0,-45),Vector3(42,0,-34),Vector3(-42,0,32)]
const REGION_LOOT := [
	Vector3(-4,0,58),Vector3(4,0,53),Vector3(-6,0,46),Vector3(5,0,39),
	Vector3(-5,0,30),Vector3(5,0,21),Vector3(-6,0,12),Vector3(5,0,3),
	Vector3(-4,0,-7),Vector3(5,0,-16),Vector3(-5,0,-27),Vector3(4,0,-38),
	Vector3(-5,0,-48),Vector3(4,0,-58),Vector3(-4,0,-68),Vector3(4,0,-78),
	Vector3(-20,0,45),Vector3(-32,0,34),Vector3(-43,0,27),Vector3(-40,0,37),
	Vector3(-54,0,18),Vector3(-57,0,-2),Vector3(-43,0,-18),Vector3(-44,0,-40),
	Vector3(-47,0,-49),Vector3(-34,0,-52),Vector3(-22,0,-43),Vector3(23,0,-46),
	Vector3(40,0,-29),Vector3(46,0,-40),Vector3(50,0,-24),Vector3(55,0,-7),
	Vector3(46,0,20),Vector3(37,0,38),Vector3(20,0,49),Vector3(24,0,13)
]

static func expedition(id: int) -> Dictionary:
	id=clampi(id,0,REGIONS.size()-1)
	var info: Dictionary=REGIONS[id].duplicate(true)
	var center: Vector3=info.position
	info["base"]=BASE if id==0 else center+Vector3(0,0,65)
	info["exit"]=EXIT if id==0 else center+Vector3(0,0,-82)
	var markers: Array[Vector3]=[]
	var locations: Array=RELAYS if id==0 else REGION_RELAYS
	if id==1: locations=[Vector3(-21,0,-62),Vector3(68,0,-17),Vector3(-18,0,44)]
	if id==2: locations=[Vector3(-72,0,-33),Vector3(72,0,14),Vector3(-73,0,61)]
	for point in locations: markers.append(point if id==0 else center+point)
	info["relays"]=markers
	return info

static func district_name(position: Vector3, region_id: int = 0) -> String:
	if region_id>0: return REGIONS[clampi(region_id,0,REGIONS.size()-1)].name
	for district in DISTRICTS:
		var offset: Vector3=position-district.position
		if Vector2(offset.x,offset.z).length()<district.radius:
			return district.name
	return "断桥营地" if Vector2(position.x,position.z-18).length()<34.0 else "灰烬荒原"

static func inside_playable(position: Vector3, margin := 0.0, region_id: int = 0) -> bool:
	var extent: float=REGIONS[clampi(region_id,0,REGIONS.size()-1)].extent
	return absf(position.x)<=extent-margin and absf(position.z)<=extent-margin
