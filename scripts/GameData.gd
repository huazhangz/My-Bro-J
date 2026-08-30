extends Node

## 全局数据单例（Autoload 名称：GameData）
##
## 集中存放《Steve 桌宠小游戏》的所有数值常量与运行时数据：
## 洗涤/晾干时长、仓库上限、品质枚举与掉率、品质 CD 缩减系数、代币、图鉴。
## 业务脚本（steve.gd 等）不得自行硬编码这些数值。

# --- 品质 -----------------------------------------------------------------

enum Quality {
	ONEOFF,     # 一次性
	POLYESTER,  # 涤纶
	COTTON,     # 纯棉
	SILK,       # 真丝
	LUXURY,     # 奢华
	MARTIAN,    # 火星科技
}

## 英文名，仅用于调试日志。
const QUALITY_NAMES: Dictionary = {
	Quality.ONEOFF: "OneOff",
	Quality.POLYESTER: "Polyester",
	Quality.COTTON: "Cotton",
	Quality.SILK: "Silk",
	Quality.LUXURY: "Luxury",
	Quality.MARTIAN: "Martian",
}

## 中文名，UI 展示用。
const QUALITY_NAMES_CN: Dictionary = {
	Quality.ONEOFF: "一次性",
	Quality.POLYESTER: "涤纶",
	Quality.COTTON: "纯棉",
	Quality.SILK: "真丝",
	Quality.LUXURY: "奢华",
	Quality.MARTIAN: "火星科技",
}

const QUALITY_COLORS: Dictionary = {
	Quality.ONEOFF: Color(0.78, 0.78, 0.80),
	Quality.POLYESTER: Color(0.45, 0.72, 0.88),
	Quality.COTTON: Color(0.92, 0.84, 0.62),
	Quality.SILK: Color(0.86, 0.62, 0.92),
	Quality.LUXURY: Color(0.95, 0.72, 0.28),
	Quality.MARTIAN: Color(0.35, 0.95, 0.55),
}

## 掉率权重（相对值，不必凑成 100）。
const QUALITY_WEIGHTS: Dictionary = {
	Quality.ONEOFF: 36.0,
	Quality.POLYESTER: 24.0,
	Quality.COTTON: 18.0,
	Quality.SILK: 12.0,
	Quality.LUXURY: 7.0,
	Quality.MARTIAN: 3.0,
}

## 穿戴对应品质内裤时，跑路冷却的缩减比例。品质越高缩减越多。
const QUALITY_CD_REDUCTION: Dictionary = {
	Quality.ONEOFF: 0.00,
	Quality.POLYESTER: 0.10,
	Quality.COTTON: 0.20,
	Quality.SILK: 0.30,
	Quality.LUXURY: 0.45,
	Quality.MARTIAN: 0.60,
}

## 磨损前缀：wear_roll ∈ [0, 100]，每 12.5 一档，共 8 档。
const WEAR_BUCKET: float = 12.5
const WEAR_PREFIXES: PackedStringArray = [
	"古神穿过的",
	"香甜的",
	"美味的",
	"瑕疵的",
	"二手的",
	"破洞的",
	"开裂的",
	"臭的",
]

## 烘干机 / 抽屉弹层相对立绘的放大倍数。
const INVENTORY_SCALE: float = 2.5
const GRID_COLUMNS: int = 5
const ITEM_CARD_SIZE: Vector2 = Vector2(100.0, 118.0)

## 本机素材目录（用户把 jpg / mp4 放在仓库根目录，不再使用桌面路径）。
const USER_PROJECT_DIR: String = "C:/Users/ASUS/My-Bro-J"
const USER_PROJECT_DIR_WSL: String = "/mnt/c/Users/ASUS/My-Bro-J"
const USER_DESKTOP_DIR: String = "C:/Users/ASUS/Desktop"
const USER_VIDEO_FILE: String = "steve3.mp4"
const USER_DRYER_FILE: String = "dryer.jpg"
const USER_DRAWER_FILE: String = "drawer.jpg"
const USER_STEVE2_FILE: String = "Steve2.jpg"
const USER_UI_FONT_FILE: String = "YuanRou-P-Bold.ttf"
const USER_UI_FONT_ZIP: String = "YuanRou-P-Bold.zip"
const RES_UI_FONT_PATH: String = "res://assets/fonts/YuanRou-P-Bold.ttf"
## 必须用字面量数组。PackedStringArray(...) 构造不是常量表达式（Godot 报错 98）。
const USER_UI_FONT_ALIASES: PackedStringArray = [
	"YuanRou-P-Bold.ttf",
	"YuanRou-P-Bold.otf",
	"GenJyuuGothic-P-Bold.ttf",
	"YuanRou-P-Bold.zip",
]
## 仓库里 70KB / 4 秒的 steve.ogv 是测试占位片，不能当人物动画。
const STUB_VIDEO_MAX_BYTES: int = 80000
const ALWAYS_ON_TOP_DEFAULT: bool = true
## 与 scenes/steve.tscn 里当前 Steve 立绘框 / 扣色导出值一致，作为唯一默认。
const PET_AREA: Rect2 = Rect2(5.0, 5.0, 240.0, 340.0)
const CHROMA_KEY_ENABLED: bool = true
const CHROMA_KEY_COLOR: Color = Color(0.0, 1.0, 0.0, 1.0)
const CHROMA_KEY_SIMILARITY: float = 0.40
const CHROMA_KEY_SMOOTHNESS: float = 0.10
const CHROMA_SPILL_SUPPRESSION: float = 0.30
const USER_ASSET_DIRS: PackedStringArray = [
	USER_PROJECT_DIR,
	USER_PROJECT_DIR_WSL,
	"res://",
	"res://assets/images",
	"res://assets/fonts",
	"res://assets/videos",
	USER_DESKTOP_DIR,
	"/mnt/c/Users/ASUS/Desktop",
	"C:/Windows/Fonts",
	"/mnt/c/Windows/Fonts",
]

# --- 核心数值 -------------------------------------------------------------

## 洗完一条内裤需要的秒数（正常速度）。
const WASH_DURATION: float = 45.0
## 烘干基础秒数；品质每高一级再加 DRY_DURATION_PER_QUALITY（与磨损无关）。
const DRY_DURATION_BASE: float = 90.0
const DRY_DURATION_PER_QUALITY: float = 10.0
## 兼容旧引用：等于基础烘干时长。
const DRY_DURATION: float = DRY_DURATION_BASE
## 未晾干仓库容量上限，满后暂停洗涤。
const WAREHOUSE_CAPACITY: int = 10

## 鼠标在立绘上停留这么久才弹出洗涤进度条。
const HOVER_SHOW_DELAY: float = 1.5
## 进度条淡入 / 淡出时长。
const HOVER_FADE_SECONDS: float = 0.35
const WASH_PROGRESS_MAX: int = 100

## 跑路冷却基础秒数（未穿戴任何内裤时的冷却）。
const RUNAWAY_BASE_COOLDOWN: float = 120.0
## 免费加速触发「Steve 跑路」的概率。
const FREE_SPEEDUP_RUNAWAY_CHANCE: float = 0.075
## 免费加速成功时直接扣掉的洗涤秒数。
const FREE_SPEEDUP_SECONDS: float = 20.0
## 付费加速 / 图鉴换装已下线（无 UI 入口）。常量保留给存档兼容。
const PAID_SPEEDUP_ENABLED: bool = false
const CODEX_ENABLED: bool = false
const PAID_SPEEDUP_COST: int = 10

## 图鉴收藏带来的额外 CD 缩减：每收藏一条 +0.5%，最多 10%。
const COLLECTION_CD_REDUCTION_PER_ITEM: float = 0.005
const COLLECTION_CD_REDUCTION_CAP: float = 0.10
## 总缩减比例上限，以及冷却时间的绝对下限（防止被缩减到 0）。
const MAX_CD_REDUCTION: float = 0.80
const MIN_COOLDOWN_SECONDS: float = 10.0

## 晾干一条内裤的代币奖励（按品质递增）。
const COIN_REWARD: Dictionary = {
	Quality.ONEOFF: 1,
	Quality.POLYESTER: 2,
	Quality.COTTON: 4,
	Quality.SILK: 8,
	Quality.LUXURY: 16,
	Quality.MARTIAN: 32,
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
## { "id", "quality", "wear" / "wear_modifier", "wear_roll", "display_name",
##   "washed_at", "dry_deadline" }
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
	return Quality.ONEOFF


func wear_from_roll(wear_roll: float) -> String:
	var idx: int = clampi(int(floor(wear_roll / WEAR_BUCKET)), 0, WEAR_PREFIXES.size() - 1)
	return WEAR_PREFIXES[idx]


func roll_wear() -> Dictionary:
	var wear_roll: float = randf_range(0.0, 100.0)
	var wear: String = wear_from_roll(wear_roll)
	return {"wear_roll": wear_roll, "wear": wear}


func quality_display_name(quality: int) -> String:
	return String(QUALITY_NAMES_CN.get(quality, "未知"))


func make_display_name(wear: String, quality: int) -> String:
	return "%s·%s" % [wear, quality_display_name(quality)]


## 烘干秒数 = 90 + 品质等级 × 10。ONEOFF=0 … MARTIAN=5。
func dry_duration_for(quality: int) -> float:
	var level: int = clampi(quality, 0, int(Quality.MARTIAN))
	return DRY_DURATION_BASE + float(level) * DRY_DURATION_PER_QUALITY


## 洗完一条内裤，放入未晾干仓库。仓库已满时返回空字典。
func add_wet_item(quality: int = -1) -> Dictionary:
	if is_warehouse_full():
		return {}
	var q: int = quality if quality >= 0 else roll_quality()
	var wear_info: Dictionary = roll_wear()
	var wear: String = String(wear_info["wear"])
	var now: float = Time.get_unix_time_from_system()
	var dry_seconds: float = dry_duration_for(q)
	var item: Dictionary = {
		"id": _next_item_id,
		"quality": q,
		"wear_roll": float(wear_info["wear_roll"]),
		"wear": wear,
		"wear_modifier": wear,
		"display_name": make_display_name(wear, q),
		"washed_at": now,
		"dry_seconds": dry_seconds,
		"dry_deadline": now + dry_seconds,
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
	if not PAID_SPEEDUP_ENABLED:
		return false
	if amount <= 0 or coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true


# --- 换装 -----------------------------------------------------------------

## 只有收藏里存在该品质才允许穿戴。传入 -1 表示脱下。
func equip_quality(quality: int) -> bool:
	if not CODEX_ENABLED:
		return false
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
		wet_warehouse.append(_normalize_item(entry))
	dry_collection.clear()
	for entry: Dictionary in data.get("dry_collection", []):
		dry_collection.append(_normalize_item(entry))
	warehouse_changed.emit(wet_warehouse.size(), WAREHOUSE_CAPACITY)
	collection_changed.emit(dry_collection.size())
	coins_changed.emit(coins)
	equipped_changed.emit(equipped_quality)


## 按「仓库根目录 → res:// → assets → 桌面兜底」查找用户拖进来的文件。
func user_file_candidates(file_name: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for dir: String in USER_ASSET_DIRS:
		if dir == "res://":
			out.append("res://%s" % file_name)
		else:
			out.append("%s/%s" % [dir.rstrip("/"), file_name])
	return out


func first_existing_file(file_name: String) -> String:
	for path: String in user_file_candidates(file_name):
		if FileAccess.file_exists(path):
			return path
	return ""


func first_existing_named(names: PackedStringArray) -> String:
	for file_name: String in names:
		var path: String = first_existing_file(file_name)
		if not path.is_empty():
			return path
	return ""


func extract_font_from_zip(zip_path: String, dest: String) -> String:
	var reader: ZIPReader = ZIPReader.new()
	if reader.open(zip_path) != OK:
		return ""
	var picked: String = ""
	for file_name: String in reader.get_files():
		var ext: String = file_name.get_extension().to_lower()
		if ext != "ttf" and ext != "otf":
			continue
		var base: String = file_name.get_file().to_lower()
		if picked.is_empty() or base.contains("bold"):
			picked = file_name
		if base.contains("p-bold") or base.contains("yuanrou"):
			picked = file_name
			break
	if picked.is_empty():
		return ""
	var bytes: PackedByteArray = reader.read_file(picked)
	if bytes.is_empty():
		return ""
	var dest_os: String = dest
	if dest.begins_with("res://") or dest.begins_with("user://"):
		dest_os = ProjectSettings.globalize_path(dest)
	var out: FileAccess = FileAccess.open(dest, FileAccess.WRITE)
	if out == null:
		out = FileAccess.open(dest_os, FileAccess.WRITE)
	if out == null:
		return ""
	out.store_buffer(bytes)
	out.close()
	if FileAccess.file_exists(dest):
		return dest
	if FileAccess.file_exists(dest_os):
		return dest_os
	return ""


func file_byte_count(path: String) -> int:
	if path.is_empty() or not FileAccess.file_exists(path):
		return -1
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var byte_count: int = file.get_length()
	file.close()
	return byte_count


func is_stub_ogv(path: String) -> bool:
	var byte_count: int = file_byte_count(path)
	return byte_count >= 0 and byte_count <= STUB_VIDEO_MAX_BYTES


func copy_file(src: String, dest: String) -> bool:
	if src.is_empty() or dest.is_empty() or src == dest:
		return false
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(src)
	if bytes.is_empty():
		return false
	var dest_os: String = dest
	if dest.begins_with("res://") or dest.begins_with("user://"):
		dest_os = ProjectSettings.globalize_path(dest)
	var out: FileAccess = FileAccess.open(dest, FileAccess.WRITE)
	if out == null:
		out = FileAccess.open(dest_os, FileAccess.WRITE)
	if out == null:
		return false
	out.store_buffer(bytes)
	out.close()
	return FileAccess.file_exists(dest) or FileAccess.file_exists(dest_os)


func load_image_texture(file_name: String) -> Texture2D:
	var path: String = first_existing_file(file_name)
	if path.is_empty():
		return null
	if path.begins_with("res://") and ResourceLoader.exists(path, "Texture2D"):
		var loaded: Resource = ResourceLoader.load(path, "Texture2D")
		var as_tex: Texture2D = loaded as Texture2D
		if as_tex != null:
			return as_tex
	var image: Image = Image.new()
	if image.load(path) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _normalize_item(entry: Dictionary) -> Dictionary:
	var item: Dictionary = entry.duplicate(true)
	var quality: int = int(item.get("quality", Quality.ONEOFF))
	var wear: String = String(item.get("wear", item.get("wear_modifier", "")))
	if wear.is_empty():
		var wear_roll: float = float(item.get("wear_roll", 0.0))
		wear = wear_from_roll(wear_roll)
	item["quality"] = quality
	item["wear"] = wear
	item["wear_modifier"] = wear
	if String(item.get("display_name", "")).is_empty():
		item["display_name"] = make_display_name(wear, quality)
	return item
