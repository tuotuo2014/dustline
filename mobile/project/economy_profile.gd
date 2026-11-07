extends RefCounted
## One atomic transaction covers currency, equipment and each completed outing.
const MAX_LEVEL := 5
const CHARACTER_COUNT := 8
const ITEMS := [
	{"id":"repulsor","name":"荒原驱狼枪","description":"命中击退并震慑狼兽。含 12 发弹药；右键开火，K 倍镜。死亡后丢失，需重新购买。","price":300,"consumable":false},
	{"id":"ammo_pack","name":"驱狼弹药 ×12","description":"每次出发最多携带 12 发，生还结算返还余弹。死亡后随身和库存弹药全部清空。","price":90,"consumable":true},
	{"id":"armor","name":"加固废土护甲","description":"狼兽扑咬伤害降低 20%。成功完成后保留；死亡后丢失，需重新购买。","price":220,"consumable":false},
	{"id":"field_kit","name":"野战医疗组件","description":"每次行动额外携带 1 个医疗包。成功完成后保留；死亡后丢失，需重新购买。","price":120,"consumable":false}
]
var assets := 0
var levels: Array[int] = [1,1,1,1,1,1,1,1]
var owned: Array[String] = []
var equipped := ""
var ammo_stock := 0
var pending: Dictionary = {}
var completed: Array[String] = []
var load_message := ""
var read_only := false
var save_path := ""
var _main_valid := false

func _init(path: String = "") -> void:
	save_path = path if not path.is_empty() else OS.get_environment("DUSTLINE_PROFILE_PATH")
	if save_path.is_empty(): save_path = "user://expedition_profile_v1.json"
	_load()

func level(id: int) -> int:
	return levels[clampi(id,0,CHARACTER_COUNT-1)]

func max_health(id: int) -> float:
	return 100.0 + 15.0 * (level(id)-1)

func cooldown_multiplier(id: int) -> float:
	return 1.0 - .07 * (level(id)-1)

func upgrade_cost(id: int) -> int:
	return 120 * level(id) if level(id)<MAX_LEVEL else 0

func upgrade(id: int) -> Dictionary:
	if id<0 or id>=CHARACTER_COUNT: return _error("无法找到这位角色。")
	if not pending.is_empty(): return _error("请完成本次行动，再回营地升级。")
	if level(id)>=MAX_LEVEL: return _error("该角色已达到最高等级。")
	var cost := upgrade_cost(id)
	if assets<cost: return _error("资产不足，还需要 %d。" % (cost-assets))
	var before := _snapshot()
	assets -= cost
	levels[id] += 1
	return _commit(before,"升级成功：Lv.%d · 生命上限 +15 · 技能冷却再缩短 7%%" % level(id))

func purchase(item_id: String) -> Dictionary:
	if not pending.is_empty(): return _error("请完成本次行动，再回营地购买。")
	var item: Dictionary = {}
	for entry in ITEMS:
		if entry.id==item_id: item=entry
	if item.is_empty(): return _error("没有找到这件装备。")
	if not item.consumable and item_id in owned: return _error("已经拥有这件装备，无需重复购买。")
	if item_id=="ammo_pack" and not "repulsor" in owned: return _error("先购买驱狼枪，再补充弹药。")
	if assets<int(item.price): return _error("资产不足，还需要 %d。" % (int(item.price)-assets))
	var before := _snapshot()
	assets -= int(item.price)
	if not item.consumable: owned.append(item_id)
	if item_id in ["repulsor","ammo_pack"]: ammo_stock += 12
	if item_id=="repulsor": equipped="repulsor"
	return _commit(before,"已购买%s。%s" % [item.name,"已自动装备，出发后右键开火，K 切换倍镜。" if item_id=="repulsor" else "下次出发即可使用。"])

func equip(item_id: String) -> Dictionary:
	if not pending.is_empty(): return _error("行动中无法更换装备，请回营地后操作。")
	if item_id!="" and (item_id!="repulsor" or not item_id in owned): return _error("请先购买这件装备。")
	var before := _snapshot()
	equipped=item_id
	return _commit(before,"已装备驱狼枪。" if not item_id.is_empty() else "已收起驱狼枪。")

func begin_expedition() -> Dictionary:
	if not pending.is_empty(): return _error("上次行动尚未结算，请先返回营地。")
	var before := _snapshot()
	var id := Crypto.new().generate_random_bytes(16).hex_encode()
	var ammo := mini(12,ammo_stock) if equipped=="repulsor" else 0
	ammo_stock -= ammo
	pending={"id":id,"ammo":ammo}
	var result := _commit(before,"")
	if result.ok: result.merge({"id":id,"ammo":ammo})
	return result

func settle(round_id: String, value: int) -> Dictionary:
	return finish_expedition(round_id,true,value,0)

func finish_expedition(round_id: String, success: bool, value: int, unused_ammo: int, died := false) -> Dictionary:
	if round_id in completed: return {"ok":true,"message":"这次行动已经结算。","banked":0,"duplicate":true}
	if pending.is_empty() or str(pending.id)!=round_id: return _error("无法确认本次行动，资产未发生变化。")
	if value<0 or value>1000000: return _error("战利品金额无效，资产未发生变化。")
	var before := _snapshot()
	var banked := value if success else 0
	assets += banked
	var returned_ammo := clampi(unused_ammo,0,int(pending.ammo))
	var lost_equipment: Array[String]=[]
	var lost_ammo := 0
	if died and not success:
		lost_equipment.assign(owned)
		lost_ammo=ammo_stock+returned_ammo
		owned.clear()
		equipped=""
		ammo_stock=0
		returned_ammo=0
	else:
		ammo_stock+=returned_ammo
	completed.append(round_id)
	if completed.size()>256: completed.pop_front()
	pending={}
	var message := "安全带回 +%d 资产" % banked if success else ("死亡结算：购买的装备及弹药已清空，需重新购买；营地资产与角色等级保留。" if died else "本次战利品遗失，营地资产保留。")
	var result := _commit(before,message)
	if result.ok: result.merge({"banked":banked,"lost_equipment":lost_equipment,"lost_ammo":lost_ammo,"returned_ammo":returned_ammo})
	return result

func ui_data(id: int, camp_available: bool, message: String = "") -> Dictionary:
	var entries: Array[Dictionary] = []
	for original in ITEMS:
		var entry: Dictionary=original.duplicate(true)
		entry["owned"]=str(entry.id) in owned
		entry["equipped"]=(equipped==entry.id) if entry.id=="repulsor" else entry.owned
		if entry.id=="ammo_pack": entry.description += " 库存：%d 发。" % ammo_stock
		entries.append(entry)
	return {"assets":assets,"level":level(id),"max_level":MAX_LEVEL,"upgrade_cost":upgrade_cost(id),"max_health":max_health(id),"cooldown_multiplier":cooldown_multiplier(id),"items":entries,"message":message if not message.is_empty() else load_message,"camp_available":camp_available and not read_only and pending.is_empty(),"ammo_stock":ammo_stock}

func _snapshot() -> Dictionary:
	return {"version":1,"assets":assets,"levels":levels.duplicate(),"owned":owned.duplicate(),"equipped":equipped,"ammo_stock":ammo_stock,"pending":pending.duplicate(true),"completed":completed.duplicate()}

func _restore(data: Dictionary) -> void:
	assets=int(data.assets)
	levels.assign(data.levels)
	while levels.size()<CHARACTER_COUNT: levels.append(1)
	owned.assign(data.owned)
	equipped=str(data.equipped)
	ammo_stock=int(data.ammo_stock)
	pending=data.pending.duplicate(true)
	completed.assign(data.completed)

func _error(message: String) -> Dictionary:
	return {"ok":false,"message":message}

func _commit(before: Dictionary, message: String) -> Dictionary:
	if read_only or not _save():
		_restore(before)
		return _error("保存失败，未扣款也未更改资产。请检查存储空间；本次结算可返回营地重试。" if not read_only else load_message)
	return {"ok":true,"message":message}

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK: return {}
	var parsed: Variant=parser.data
	if not parsed is Dictionary or not _valid(parsed): return {}
	return parsed

func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=minimum and value<=maximum

func _valid(data: Dictionary) -> bool:
	for key in ["version","assets","levels","owned","equipped","ammo_stock","pending","completed"]:
		if not data.has(key): return false
	if data.version!=1 or not _whole(data.assets,0,2000000000) or not _whole(data.ammo_stock,0,2000000000): return false
	if not data.levels is Array or not data.levels.size() in [4,CHARACTER_COUNT]: return false
	for rank in data.levels:
		if not _whole(rank,1,MAX_LEVEL): return false
	if not data.owned is Array or not data.completed is Array or not data.pending is Dictionary or not data.equipped is String: return false
	var seen: Array=[]
	for item in data.owned:
		if not item is String or not item in ["repulsor","armor","field_kit"] or item in seen: return false
		seen.append(item)
	if data.equipped!="" and (data.equipped!="repulsor" or not "repulsor" in data.owned): return false
	if data.completed.size()>256: return false
	for id in data.completed:
		if not id is String or id.length()!=32: return false
	if not data.pending.is_empty():
		if not data.pending.has("id") or not data.pending.has("ammo"): return false
		if not data.pending.id is String or data.pending.id.length()!=32 or not _whole(data.pending.ammo,0,12): return false
	return true

func _load() -> void:
	var data := _read(save_path)
	_main_valid=not data.is_empty()
	if data.is_empty() and (FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path+".bak")):
		data=_read(save_path+".bak")
		if data.is_empty():
			read_only=true
			load_message="资产存档无法读取，原文件已保留，暂时关闭资产交易。"
			return
		load_message="已从备份恢复资产。"
		if FileAccess.file_exists(save_path):
			var preserved := save_path+".corrupt-"+str(Time.get_unix_time_from_system())
			if DirAccess.copy_absolute(save_path,preserved)!=OK:
				read_only=true
				load_message="存档损坏，无法保留原文件，暂时关闭资产交易。"
				return
	if data.is_empty(): return
	_restore(data)
	if not pending.is_empty():
		# An interrupted application never pays out carried loot or restores fired ammo.
		var before := _snapshot()
		completed.append(str(pending.id))
		if completed.size()>256: completed.pop_front()
		pending={}
		var result := _commit(before,"")
		if not result.ok:
			read_only=true
			load_message=result.message
		else:
			load_message+="上次未完成的行动已结束：背包与已领弹药遗失，营地资产保留。"

func _save() -> bool:
	var data := _snapshot()
	if not _valid(data): return false
	var file := FileAccess.open(save_path+".tmp",FileAccess.WRITE)
	if file==null: return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error!=OK or _read(save_path+".tmp").is_empty(): return false
	if _main_valid and FileAccess.file_exists(save_path):
		if DirAccess.copy_absolute(save_path,save_path+".bak.tmp")!=OK: return false
		if DirAccess.rename_absolute(save_path+".bak.tmp",save_path+".bak")!=OK: return false
	if DirAccess.rename_absolute(save_path+".tmp",save_path)!=OK: return false
	_main_valid=true
	return true
