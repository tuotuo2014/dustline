extends RefCounted
## Playable wasteland survivor roster shared by the menu and player controller.

const CHARACTERS := [
	{"id": 0, "name": "荒原·行者", "subtitle": "沉默的长途拾荒者", "detail": "熟悉断桥与沙暴的老练独行者。随身携带拾荒背包与防护披风。", "accent": Color("c99459")},
	{"id": 1, "name": "赤砂·林烬", "subtitle": "锈红机械臂的沙地猎手", "detail": "棕黑低马尾、沙色围巾、分片长衣和锈红机械左臂。", "accent": Color("d77b53")},
	{"id": 2, "name": "夜巡·零鸦", "subtitle": "蓝衣义眼的夜行者", "detail": "不对称黑色短发、蓝色短夹克、红色义眼与轻便战术装备。", "accent": Color("83a9c9")},
	{"id": 3, "name": "铸火·老莫", "subtitle": "白须铸造师", "detail": "卡其旧长衣、齿轮徽章与金属双手，靠经验和耐力活过了旧世界。", "accent": Color("d3a768")},
]

static func get_info(id: int) -> Dictionary:
	return CHARACTERS[clampi(id, 0, CHARACTERS.size() - 1)]

static func all() -> Array:
	return CHARACTERS.duplicate(true)

const SKILLS := [
	{"name":"拾荒直觉","cooldown":22.0,"duration":10.0,"description":"标记 65 米内最近的 16 处物资 / 信标，持续 10 秒。","accent":Color("e9bd6e")},
	{"name":"磁能震荡","cooldown":20.0,"duration":.65,"description":"机械臂释放震波，击退视线内 12 米的狼兽并眩晕 3 秒。","accent":Color("f19a66")},
	{"name":"疾影突进","cooldown":12.0,"duration":.38,"description":"在地面向角色朝向突进约 7 米，途中躲避扑咬；墙壁会阻挡。","accent":Color("82cde6")},
	{"name":"维修无人机","cooldown":38.0,"duration":12.0,"description":"召唤随行维修机，12 秒内每秒恢复 3 点生命，最多恢复 36 点。","accent":Color("9ed4b4")}
]

static func skill(id: int) -> Dictionary:
	return SKILLS[clampi(id,0,3)]
