extends Node

## 全局数据单例（Autoload 名称：GameData）
##
## 集中存放《Steve 桌宠小游戏》的所有数值常量与运行时数据：
## 洗涤/晾干时长、仓库上限、品质枚举与掉率、品质 CD 缩减系数、代币、图鉴。
## 业务脚本（steve.gd 等）不得自行硬编码这些数值。

# --- 品质 -----------------------------------------------------------------

enum Quality {
	NORMAL,   # 普通
	RARE,     # 稀有
	EPIC,     # 史诗
	RED_GOLD, # 大红 / 传说（带特效）
}

## 英文名，仅用于调试日志。
const QUALITY_NAMES: Dictionary = {
	Quality.NORMAL: "Normal",
	Quality.RARE: "Rare",
	Quality.EPIC: "Epic",
	Quality.RED_GOLD: "RedGold",
}

## 中文名，UI 展示用（Day 3 起场景已接入中文字体）。
const QUALITY_NAMES_CN: Dictionary = {
	Quality.NORMAL: "普通",
	Quality.RARE: "稀有",
	Quality.EPIC: "史诗",
	Quality.RED_GOLD: "大红",
}

const QUALITY_COLORS: Dictionary = {
	Quality.NORMAL: Color(0.82, 0.82, 0.82),
	Quality.RARE: Color(0.30, 0.62, 1.00),
	Quality.EPIC: Color(0.72, 0.40, 0.95),
	Quality.RED_GOLD: Color(1.00, 0.27, 0.20),
}

## 掉率权重（相对值，不必凑成 100）。
const QUALITY_WEIGHTS: Dictionary = {
	Quality.NORMAL: 70.0,
	Quality.RARE: 20.0,
	Quality.EPIC: 8.0,
	Quality.RED_GOLD: 2.0,
}

## 穿戴对应品质内裤时，跑路冷却的缩减比例。品质越高缩减越多。
const QUALITY_CD_REDUCTION: Dictionary = {
	Quality.NORMAL: 0.00,
	Quality.RARE: 0.15,
	Quality.EPIC: 0.30,
	Quality.RED_GOLD: 0.50,
}

# --- 核心数值 -------------------------------------------------------------

## 洗完一条内裤需要的秒数（正常速度）。
const WASH_DURATION: float = 45.0
## 洗完后自动晾干需要的秒数。
const DRY_DURATION: float = 60.0
## 未晾干仓库容量上限，满后暂停洗涤。
const WAREHOUSE_CAPACITY: int = 10

## 跑路冷却基础秒数（未穿戴任何内裤时的冷却）。
const RUNAWAY_BASE_COOLDOWN: float = 120.0
## 免费加速触发「Steve 跑路」的概率。
const FREE_SPEEDUP_RUNAWAY_CHANCE: float = 0.25
## 免费加速成功时直接扣掉的洗涤秒数。
const FREE_SPEEDUP_SECONDS: float = 15.0
## 付费加速：消耗这么多代币，直接强行洗完当前这一条（无跑路风险）。
const PAID_SPEEDUP_COST: int = 10

## 图鉴收藏带来的额外 CD 缩减：每收藏一条 +0.5%，最多 10%。
const COLLECTION_CD_REDUCTION_PER_ITEM: float = 0.005
const COLLECTION_CD_REDUCTION_CAP: float = 0.10
## 总缩减比例上限，以及冷却时间的绝对下限（防止被缩减到 0）。
const MAX_CD_REDUCTION: float = 0.80
const MIN_COOLDOWN_SECONDS: float = 10.0

## 晾干一条内裤的代币奖励（按品质递增）。
const COIN_REWARD: Dictionary = {
	Quality.NORMAL: 1,
	Quality.RARE: 3,
	Quality.EPIC: 8,
	Quality.RED_GOLD: 25,
}

# --- 信号 -----------------------------------------------------------------

signal warehouse_changed(current: int, capacity: int)
signal collection_changed(total: int)
signal coins_changed(coins: int)
signal item_washed(item: Dictionary)
signal item_dried(item: Dictionary)
signal equipped_changed(quality: int)

# --- 运行时数据 -----------------------------------------------------------

## 代币余额。
var coins: int = 0

## 未晾干仓库（上限 WAREHOUSE_CAPACITY）。元素为 Dictionary：
## { "id": int, "quality": int, "washed_at": float, "dry_deadline": float }
var wet_warehouse: Array[Dictionary] = []

## 已晾干收藏 / 图鉴条目。
var dry_collection: Array[Dictionary] = []

## 当前穿戴的品质，-1 表示未穿戴。
var equipped_quality: int = -1

## 各品质累计获得数量，用于图鉴展示。
var codex_counts: Dictionary = {}

var _next_item_id: int = 1


func _ready() -> void:
	for q: int in Quality.values():
		codex_counts[q] = 0


# --- 仓库操作 -------------------------------------------------------------

func is_warehouse_full() -> bool:
	return wet_warehouse.size() >= WAREHOUSE_CAPACITY


func warehouse_free_slots() -> int:
	return maxi(WAREHOUSE_CAPACITY - wet_warehouse.size(), 0)


## 按权重随机抽取一个品质。
func roll_quality() -> int:
	var total: float = 0.0
	for weight: float in QUALITY_WEIGHTS.values():
		total += weight
	var roll: float = randf() * total
	for q: int in Quality.values():
		roll -= float(QUALITY_WEIGHTS[q])
		if roll <= 0.0:
			return q
	return Quality.NORMAL


## 洗完一条内裤，放入未晾干仓库。仓库已满时返回空字典。
func add_wet_item(quality: int = -1) -> Dictionary:
	if is_warehouse_full():
		return {}
	var q: int = quality if quality >= 0 else roll_quality()
	var now: float = Time.get_unix_time_from_system()
	var item: Dictionary = {
		"id": _next_item_id,
		"quality": q,
		"washed_at": now,
		"dry_deadline": now + DRY_DURATION,
	}
	_next_item_id += 1
	wet_warehouse.append(item)
	codex_counts[q] = int(codex_counts.get(q, 0)) + 1
	item_washed.emit(item)
	warehouse_changed.emit(wet_warehouse.size(), WAREHOUSE_CAPACITY)
	return item


## 把一条内裤从未晾干仓库移入已晾干收藏，并结算代币。
func dry_item(item_id: int) -> bool:
	var index: int = -1
	for i: int in wet_warehouse.size():
		if int(wet_warehouse[i]["id"]) == item_id:
			index = i
			break
	if index < 0:
		return false
	var item: Dictionary = wet_warehouse[index]
	wet_warehouse.remove_at(index)
	item["dried_at"] = Time.get_unix_time_from_system()
	dry_collection.append(item)
	add_coins(int(COIN_REWARD.get(int(item["quality"]), 1)))
	item_dried.emit(item)
	warehouse_changed.emit(wet_warehouse.size(), WAREHOUSE_CAPACITY)
	collection_changed.emit(dry_collection.size())
	return true


func find_wet_item(item_id: int) -> Dictionary:
	for item: Dictionary in wet_warehouse:
		if int(item["id"]) == item_id:
			return item
	return {}


# --- 代币 -----------------------------------------------------------------

func add_coins(amount: int) -> void:
	if amount == 0:
		return
	coins = maxi(coins + amount, 0)
	coins_changed.emit(coins)


func try_spend_coins(amount: int) -> bool:
	if amount <= 0 or coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true


# --- 换装 -----------------------------------------------------------------

## 只有收藏里存在该品质才允许穿戴。传入 -1 表示脱下。
func equip_quality(quality: int) -> bool:
	if quality < 0:
		equipped_quality = -1
		equipped_changed.emit(equipped_quality)
		return true
	if not has_collected(quality):
		return false
	equipped_quality = quality
	equipped_changed.emit(equipped_quality)
	return true


func has_collected(quality: int) -> bool:
	for item: Dictionary in dry_collection:
		if int(item["quality"]) == quality:
			return true
	return false


## 已晾干收藏里该品质的条数（图鉴 UI 用）。
func count_collected(quality: int) -> int:
	var total: int = 0
	for item: Dictionary in dry_collection:
		if int(item["quality"]) == quality:
			total += 1
	return total


# --- 品质 CD 缩减算法 -----------------------------------------------------

## 图鉴收藏带来的附加缩减比例。
func get_collection_cd_reduction() -> float:
	return minf(dry_collection.size() * COLLECTION_CD_REDUCTION_PER_ITEM, COLLECTION_CD_REDUCTION_CAP)


## 当前（或指定品质）的总 CD 缩减比例，已 clamp 到 MAX_CD_REDUCTION。
func get_cd_reduction(quality: int = -2) -> float:
	var q: int = quality if quality > -2 else equipped_quality
	var reduction: float = 0.0
	if q >= 0 and QUALITY_CD_REDUCTION.has(q):
		reduction = float(QUALITY_CD_REDUCTION[q])
	reduction += get_collection_cd_reduction()
	return clampf(reduction, 0.0, MAX_CD_REDUCTION)


## 核心算法：跑路冷却时间 = 基础冷却 * (1 - 品质缩减 - 图鉴缩减)，并有绝对下限。
## quality 省略时使用当前穿戴品质；base_seconds 省略时使用 RUNAWAY_BASE_COOLDOWN。
func get_calculated_cooldown(base_seconds: float = RUNAWAY_BASE_COOLDOWN, quality: int = -2) -> float:
	var reduced: float = base_seconds * (1.0 - get_cd_reduction(quality))
	return maxf(reduced, MIN_COOLDOWN_SECONDS)


# --- 存档（Day 5 预留） ---------------------------------------------------

func to_save_dict() -> Dictionary:
	return {
		"coins": coins,
		"wet_warehouse": wet_warehouse.duplicate(true),
		"dry_collection": dry_collection.duplicate(true),
		"equipped_quality": equipped_quality,
		"codex_counts": codex_counts.duplicate(true),
		"next_item_id": _next_item_id,
	}


func load_from_dict(data: Dictionary) -> void:
	coins = int(data.get("coins", 0))
	equipped_quality = int(data.get("equipped_quality", -1))
	_next_item_id = int(data.get("next_item_id", 1))
	codex_counts = data.get("codex_counts", {}).duplicate(true)
	wet_warehouse.clear()
	for entry: Dictionary in data.get("wet_warehouse", []):
		wet_warehouse.append(entry.duplicate(true))
	dry_collection.clear()
	for entry: Dictionary in data.get("dry_collection", []):
		dry_collection.append(entry.duplicate(true))
	warehouse_changed.emit(wet_warehouse.size(), WAREHOUSE_CAPACITY)
	collection_changed.emit(dry_collection.size())
	coins_changed.emit(coins)
	equipped_changed.emit(equipped_quality)
