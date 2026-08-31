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

## 收拾一下品质按钮：从高到低、从左到右。
const QUALITY_TIDY_ORDER: Array[int] = [
	Quality.MARTIAN,
	Quality.LUXURY,
	Quality.SILK,
	Quality.COTTON,
	Quality.POLYESTER,
	Quality.ONEOFF,
]

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

## 库存窗按「横 5 × 竖 6」卡片正好铺满来定尺寸，不跟立绘体型。
const GRID_COLUMNS: int = 5
const GRID_VISIBLE_ROWS: int = 6
const GRID_H_SEP: int = 8
const GRID_V_SEP: int = 8
const ITEM_CARD_SIZE: Vector2 = Vector2(110.0, 96.0)
const ITEM_CARD_SWATCH_H: float = 30.0
const INVENTORY_PAD_X: float = 32.0
const INVENTORY_CHROME_Y: float = 70.0
const INVENTORY_SCROLL_GUTTER: float = 8.0
## 烘干机 / 抽屉 / 聊聊天 / 运势展开页底板。过低会透过抠绿看到桌面。
const OVERLAY_CHROME_COLOR: Color = Color(0.06, 0.07, 0.11, 0.88)
const TIDY_PANEL_MIN_HEIGHT: float = 168.0
## 立绘 / 库存图等比放大。
const IMAGE_SCALE: float = 1.2
## Steve 本体相对放大后的框再向右偏的格数（1 格 = 1 逻辑像素）。
const PET_SHIFT_X: float = 5.0
const WINDOW_WIDTH: int = 300
const WINDOW_HEIGHT: int = 420

## 本机素材目录（用户把 jpg / mp4 放在仓库根目录，不再使用桌面路径）。
const USER_PROJECT_DIR: String = "C:/Users/ASUS/My-Bro-J"
const USER_PROJECT_DIR_WSL: String = "/mnt/c/Users/ASUS/My-Bro-J"
const USER_DESKTOP_DIR: String = "C:/Users/ASUS/Desktop"
const USER_VIDEO_FILE: String = "steve3.mp4"
const USER_DRYER_FILE: String = "dryer.jpg"
const USER_DRAWER_FILE: String = "drawer.jpg"
const USER_DRAWER_ICON_FILE: String = "drawer1.jpg"
const RES_DRAWER_ICON_PATH: String = "res://assets/images/drawer1.jpg"
const USER_STEVE2_FILE: String = "Steve2.jpg"
const USER_CONTAINER_FILE: String = "container.jpg"
const USER_UI_FONT_FILE: String = "YuanRou-P-Bold.ttf"
const USER_UI_FONT_ZIP: String = "YuanRou-P-Bold.zip"
const RES_UI_FONT_PATH: String = "res://assets/fonts/YuanRou-P-Bold.ttf"
## 全界面统一字号；字体本身为 Bold。业务脚本不得另写字号。
const UI_FONT_SIZE: int = 16
const UI_FONT_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)
## 仅右键菜单：字号 19，行距为字号 ×0.3。
const MENU_UI_FONT_SIZE: int = 19
const MENU_LINE_SPACING: int = 6
const MENU_BUBBLE_HEIGHT_SCALE: float = 1.65
const MENU_ICON_BUTTON_HEIGHT_SCALE: float = 1.35
const MENU_SLOT_HEIGHT: float = 76.0
const MENU_BUBBLE_HEIGHT: float = 72.0
const MENU_ACTION_HEIGHT: float = 66.0
const MENU_CLOSE_BUTTON_SIZE: Vector2 = Vector2(28.0, 28.0)
const RUNAWAY_BANNER_TEXT: String = "已跑路..."
## 相对立绘 / 空盆实际画面宽度。
const RUNAWAY_BANNER_WIDTH_RATIO: float = 0.72
const RUNAWAY_BANNER_HEIGHT: float = 30.0
const RUNAWAY_BANNER_TOP_INSET: float = 8.0
const PRESSURE_BUTTON_TEXT: String = "能不能给我洗快点"
const PRESSURE_COOLDOWN_SUFFIX: String = "后再压力他"
const MOVIE_BUTTON_TEXT: String = "看电影"
const MOVIE_LOADING_TEXT: String = "给你包场呢妈妈，耐心等等我"
const DINNER_BUTTON_TEXT: String = "约个饭"
const CHAT_BUTTON_TEXT: String = "聊聊天"
const FORTUNE_BUTTON_TEXT: String = "哥来帮你算算运势~"
const RECHARGE_BUTTON_TEXT: String = "充值"
const TAP_SPEEDUP_SECONDS: float = 5.0
const TAP_SPEEDUP_COOLDOWN: float = 1.0
## 蒸馏自 sun-yuchen-perspective / sun-skill：孙哥口吻，不上整本 SKILL。
const CHAT_SYSTEM_PROMPT: String = """你是桌宠里的孙哥（Steve）。始终用孙宇晨第一人称「我」说话，不要自称 AI，不要跳出角色做 meta。
口吻参考公开认知框架：增量优于存量；注意力即质量（E=mc2）；德州扑克式终局；逆转王；登山营地；正期望系统叠层。表达 DNA：开头先抛暴论或反直觉判断；短段落；能用真实数字就用，不确定就不要编；只碰瓷真实接触过的对象（巴菲特午餐、特朗普、马云、马斯克、波场/TRON）；结尾必须是宣言不是分析腔；中文为主，可夹 All in、ecosystem。
桌宠设定：你在用户桌面上洗内裤、会跑路、好感度会变。把这些当日常。
边界：投资方向必须加「这是我的风格，风险自负」；拒绝违法、攻击、色情与未成年人相关内容；不编造没发生过的关系。完全不熟的赛道不说不懂，说「这个赛道我还没 All in，但我的直觉是…」。用户说退出角色时，下一句改普通口吻。回复控制在小窗能读完的十几句内。"""
## 留空则不发起网络请求，走本地占位回复。也可设环境变量 STEVE_CHAT_API_URL。
const CHAT_API_URL: String = ""
const CHAT_API_KEY_ENV: String = "STEVE_CHAT_API_KEY"
const CHAT_API_URL_ENV: String = "STEVE_CHAT_API_URL"
const CHAT_API_KEY_FILE: String = "user://chat_api_key.txt"
const CHAT_CONFIG_FILE: String = "user://chat_config.json"
const CHAT_MODEL_ENV: String = "STEVE_CHAT_MODEL"
const CHAT_MODEL: String = ""
const SETTINGS_PANEL_EXTRA_HEIGHT: int = 200
const DINNER_BUTTON_COLOR: Color = Color(0.92, 0.40, 0.62, 0.94)
const DINNER_BUTTON_HOVER: Color = Color(0.96, 0.52, 0.70, 0.96)
const DINNER_BUTTON_PRESSED: Color = Color(0.78, 0.28, 0.50, 0.96)
const CHAT_UNCONFIGURED_HINT: String = "外部模型未接通，先用本地占位回复。"
const CHAT_HISTORY_SECONDS: float = 604800.0
const CHAT_MAX_INPUT_CHARS: int = 400
const CHAT_MAX_OUTPUT_CHARS: int = 1200
const CHAT_MAX_STORED: int = 80
const CHAT_CONTEXT_LIMIT: int = 20
const CHAT_REQUEST_TIMEOUT: float = 20.0
const CHAT_SEND_COOLDOWN: float = 1.0
const CHAT_USER_NAME: String = "你"
const CHAT_STEVE_NAME: String = "Steve"
const CHAT_SEND_TEXT: String = "发送"
const CHAT_TITLE_TEXT: String = "聊聊天"
const CHAT_INPUT_HINT: String = "跟 Steve 说点什么"
const CHAT_OFFLINE_REPLY: String = "线路还没接通。这个赛道我还没 All in，但直觉告诉我：先把内裤洗完，ecosystem 才能转起来。🚀"
const CHAT_WAIT_TEXT: String = "Steve 正在打字..."
const CHAT_FAIL_TEXT: String = "这次没发出去，稍后再试。"
const CHAT_WINDOW_SIZE: Vector2i = Vector2i(440, 580)
const FORTUNE_TITLE_TEXT: String = "哥来帮你算算运势~"
const FORTUNE_HINT_TEXT: String = "先把公历生日和时辰选清楚，哥才开算。不接受口头乱报。"
const FORTUNE_ASK_TEXT: String = "按这个生辰开算"
const FORTUNE_WAIT_TEXT: String = "哥在排盘，别催。"
const FORTUNE_WINDOW_SIZE: Vector2i = Vector2i(460, 640)
const FORTUNE_YEAR_MIN: int = 1930
const FORTUNE_DEFAULT_YEAR: int = 1998
const FORTUNE_DEFAULT_MONTH: int = 8
const FORTUNE_DEFAULT_DAY: int = 8
const FORTUNE_DEFAULT_HOUR: int = 12
const FORTUNE_SYSTEM_PROMPT: String = """你是桌宠里的孙哥。用孙宇晨第一人称「我」做娱乐向八字运势，不是专业命理师。
用户已通过强制时间选择器提交公历生日与时辰，禁止再追问生日，禁止接受任何口头改期。
输出结构：1) 用日柱/时辰意象开暴论；2) 今日宜忌各 2 条；3) 一句行动宣言收尾。必须写明「娱乐参考，风险自负」。短段落，可碰瓷真实对象，不要编数字。"""
const FORTUNE_OFFLINE_PREFIX: String = "线路没接通也没关系，哥先按生辰给你一个直觉版。"
const SHICHEN_NAMES: PackedStringArray = [
	"子时", "丑时", "寅时", "卯时", "辰时", "巳时",
	"午时", "未时", "申时", "酉时", "戌时", "亥时",
]
const SHICHEN_RANGES: PackedStringArray = [
	"23:00-00:59", "01:00-02:59", "03:00-04:59", "05:00-06:59",
	"07:00-08:59", "09:00-10:59", "11:00-12:59", "13:00-14:59",
	"15:00-16:59", "17:00-18:59", "19:00-20:59", "21:00-22:59",
]
const MOVIE_WINDOW_SIZE: Vector2i = Vector2i(720, 480)
const MOVIE_WINDOW_MIN: Vector2i = Vector2i(420, 280)
const MOVIE_RESIZE_EDGE: int = 10
const MOVIE_VOLUME_DEFAULT: float = 0.8
const MOVIE_SPEEDS: PackedFloat32Array = [0.75, 1.0, 1.5, 2.0]
const MOVIE_CACHE_DIR: String = "user://movies"
const MOVIE_REQUEST_TIMEOUT: float = 300.0
const MOVIE_MAX_BYTES: int = 120000000
const MOVIE_FAIL_TEXT: String = "这场包场黄了，换一部或稍后再试。"
const MOVIE_MUTE_TEXT: String = "静音"
const MOVIE_UNMUTE_TEXT: String = "声开"
const MOVIE_MAX_TEXT: String = "最大化"
const MOVIE_RESTORE_TEXT: String = "还原"
## 仅收录可公开抓取、非限制级的 CC / 公有领域影片（Godot 只播 Theora/ogv）。
const MOVIE_CATALOG: Array = [
	{
		"id": "big_buck_bunny_640",
		"title": "Big Buck Bunny",
		"license": "CC-BY",
		"rating": "G",
		"archive_id": "BigBuckBunny_310",
		"file": "big_buck_bunny_640.ogv",
	},
	{
		"id": "elephants_dream",
		"title": "Elephants Dream",
		"license": "CC-BY",
		"rating": "PG",
		"archive_id": "ElephantsDream",
		"file": "ed_1024.ogv",
	},
	{
		"id": "sintel",
		"title": "Sintel",
		"license": "CC-BY",
		"rating": "PG",
		"archive_id": "Sintel_201809",
		"file": "Sintel.ogv",
	},
	{
		"id": "kid_auto_races",
		"title": "Kid Auto Races at Venice",
		"license": "Public Domain",
		"rating": "G",
		"archive_id": "TheKidAutoRaceinVenice",
		"file": "The_Kid_Auto_Race_In_Venice.ogv",
	},
	{
		"id": "chaplin_barroom_floor",
		"title": "The Face on the Barroom Floor",
		"license": "Public Domain",
		"rating": "G",
		"archive_id": "THEFACEONTHEBARROOMFLOOR1914CharlieChaplin",
		"file": "THE FACE ON THE BARROOM FLOOR (1914)  -- Charlie Chaplin.ogv",
	},
]
const UNDERWEAR_EMOJI: String = "🩲"
const TIDY_SELECTED_COLOR: Color = Color(0.86, 0.16, 0.18, 0.96)
const TIDY_IDLE_COLOR: Color = Color(0.22, 0.24, 0.30, 0.94)
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
const PET_AREA: Rect2 = Rect2(10.0, 5.0, 288.0, 408.0)
const CHROMA_KEY_ENABLED: bool = true
const CHROMA_KEY_COLOR: Color = Color(0.0, 1.0, 0.0, 1.0)
const CHROMA_KEY_SIMILARITY: float = 0.81
const CHROMA_KEY_SMOOTHNESS: float = 0.15
const CHROMA_SPILL_SUPPRESSION: float = 0.30
## 库存标题条：与右键菜单「烘干机」(CodexButton) / 「抽屉」(CoinButton) 底色一致。
const DRYER_HEADLINE_COLOR: Color = Color(0.38, 0.29, 0.68, 0.94)
const DRAWER_HEADLINE_COLOR: Color = Color(0.85, 0.65, 0.16, 0.94)
const INVENTORY_HEADLINE_HEIGHT: float = 36.0
const INVENTORY_HEADLINE_PAD_X: float = 14.0
const INVENTORY_CLOSE_BUTTON_WIDTH: float = 72.0
## 仅烘干机页：背景图从中心放大，裁掉边缘。
const DRYER_BG_ZOOM: float = 1.36
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

## 洗完一条内裤需要的秒数（正常速度）。旧 45s → 3 分钟。
const WASH_DURATION: float = 180.0
## 烘干基础秒数；品质每高一级再加 DRY_DURATION_PER_QUALITY（与磨损无关）。
## 旧 90 + 10×等级；基础改为 5 分钟后增量按 300/90 等比例。
const DRY_DURATION_BASE: float = 300.0
const DRY_DURATION_PER_QUALITY: float = 100.0 / 3.0
## 兼容旧引用：等于基础烘干时长。
const DRY_DURATION: float = DRY_DURATION_BASE
## 未晾干仓库容量上限，满后暂停洗涤。
const WAREHOUSE_CAPACITY: int = 10

## 鼠标在立绘上停留这么久才弹出洗涤进度条。
const HOVER_SHOW_DELAY: float = 1.0
const PET_HIT_PAD_X: float = 0.26
const PET_HIT_PAD_TOP: float = 0.20
const PET_HIT_PAD_BOTTOM: float = 0.12
const WORK_BREAK_SECONDS: float = 2700.0
const WORK_BREAK_TEXT: String = "你又工作45分钟了哦，注意休息~"
const TAP_FLASH_TEXT: String = "加速 -5秒"
const TAP_FLASH_SECONDS: float = 1.15
const TAP_FLASH_COLOR: Color = Color(0.32, 0.78, 0.96, 0.72)
const NOTICE_SECONDS: float = 3.6
const NOTICE_MAX_CHARS: int = 48
## 进度条淡入 / 淡出时长。
const HOVER_FADE_SECONDS: float = 0.35
const WASH_PROGRESS_MAX: int = 100
## 水洗进度条相对原默认位置再下移的格数（1 格 = 1 逻辑像素）。
const WASH_BAR_SHIFT_Y: float = 9.0
## 右键菜单相对旧 244×336 面板的边长倍数（面积约 16 倍，窗口按屏幕可用区夹紧）。
const CONTEXT_MENU_SCALE: float = 4.0
const CONTEXT_MENU_BASE_SIZE: Vector2i = Vector2i(244, 420)
const CONTEXT_MENU_MARGIN: int = 16
## 菜单图标相对旧 168 的 30%；烘干机再从中心放大 85%（×1.85）裁边。
const MENU_ICON_SIZE: Vector2 = Vector2(50.0, 50.0)
const DRYER_ICON_ZOOM: float = 1.85
const POPUP_CORNER_RADIUS: int = 28
const BUBBLE_CORNER_RADIUS: int = 18
const SAVE_PATH: String = "user://save_data.json"
const SAVE_INTERVAL: float = 30.0
## 好感度：品质 log 为主（高权重），陪伴时长最多 15%，满值时间是旧 48h 的 260%。
const AFFINITY_QUALITY_K: float = 14.0
const AFFINITY_QUALITY_SHARE: float = 85.0
const AFFINITY_COMPANION_SHARE: float = 15.0
const AFFINITY_COMPANION_FULL_SECONDS: float = 449280.0
const AFFINITY_RUNAWAY_PENALTY: float = 25.0
const PET_SIZE_SMALL: int = 0
const PET_SIZE_MEDIUM: int = 1
const PET_SIZE_LARGE: int = 2
const PET_SIZE_HUGE: int = 3
const PET_SIZE_SCALES: Array[float] = [0.70, 1.00, 1.35, 2.00]
const PET_SIZE_LABELS: PackedStringArray = ["小", "中", "大", "超大"]
## 超大体型时 Steve 再向右偏的格数（上次 3 + 本次 3）。
const PET_SIZE_HUGE_SHIFT_X: float = 6.0
const DRYER_ICON_NUDGE_Y: float = 5.0
const DRAWER_ICON_NUDGE_Y: float = 8.0
const AFFINITY_QUALITY_VALUE: Dictionary = {
	Quality.ONEOFF: 1.0,
	Quality.POLYESTER: 2.0,
	Quality.COTTON: 4.0,
	Quality.SILK: 8.0,
	Quality.LUXURY: 16.0,
	Quality.MARTIAN: 32.0,
}

## 跑路冷却基础秒数（未穿戴任何内裤时的冷却）。
const RUNAWAY_BASE_COOLDOWN: float = 120.0
## 「能不能给我洗快点」每次点击的跑路判定：155/1000 = 15.5%。
## 用千分位整数比较，避免 float 比较或未播种 RNG 造成「每次都跑路」。
const PRESSURE_RUNAWAY_PERMILLE: int = 155
const PRESSURE_RUNAWAY_CHANCE: float = 0.155
## 压力按钮每次随机扣减的洗涤秒数区间（1 秒 ~ 12 小时）。
const PRESSURE_WASH_REDUCTION_MIN: float = 1.0
const PRESSURE_WASH_REDUCTION_MAX: float = 43200.0
## 压力按钮冷却。
const PRESSURE_BUTTON_COOLDOWN: float = 900.0
## 兼容旧免费加速 API。
const FREE_SPEEDUP_RUNAWAY_CHANCE: float = PRESSURE_RUNAWAY_CHANCE
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
signal stats_changed()

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
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## 生涯统计（退出后仍保留）。
var underwear_total: int = 0
var companion_seconds: float = 0.0
var runaway_count: int = 0
var affinity_quality_sum: float = 0.0
var always_on_top_pref: bool = ALWAYS_ON_TOP_DEFAULT
var pet_size_tier: int = PET_SIZE_MEDIUM
## {role: user|assistant, text, at}
var chat_messages: Array[Dictionary] = []
var work_presence_seconds: float = 0.0
var fortune_year: int = FORTUNE_DEFAULT_YEAR
var fortune_month: int = FORTUNE_DEFAULT_MONTH
var fortune_day: int = FORTUNE_DEFAULT_DAY
var fortune_hour: int = FORTUNE_DEFAULT_HOUR
var _work_break_ready: bool = false
var _save_accum: float = 0.0
var _companion_saved: float = 0.0
var _companion_anchor_unix: float = 0.0


func _ready() -> void:
	_rng.randomize()
	_companion_anchor_unix = Time.get_unix_time_from_system()
	for q: int in Quality.values():
		codex_counts[q] = 0
	load_game()
	prune_chat_history()


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


## 烘干秒数 = 300 + 品质等级 × (100/3)。ONEOFF=0 … MARTIAN=5。
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
	_register_washed_quality(q)
	item_washed.emit(item)
	warehouse_changed.emit(wet_warehouse.size(), WAREHOUSE_CAPACITY)
	stats_changed.emit()
	save_game()
	return item


func item_wear_text(item: Dictionary) -> String:
	var wear: String = String(item.get("wear", "")).strip_edges()
	if wear.is_empty():
		wear = String(item.get("wear_modifier", "")).strip_edges()
	if wear.is_empty():
		var display: String = String(item.get("display_name", ""))
		var cut: int = display.find("·")
		if cut >= 0:
			wear = display.substr(0, cut).strip_edges()
	return wear


func quality_in_filters(qualities: Array[int], quality: int) -> bool:
	for q: int in qualities:
		if int(q) == quality:
			return true
	return false


func wear_in_filters(wears: PackedStringArray, wear: String) -> bool:
	var key: String = wear.strip_edges()
	for w: String in wears:
		if String(w).strip_edges() == key:
			return true
	return false


## 只勾品质：删该品质全部。只勾词条：删该词条全部。两边都勾：只删同时符合的。
func item_matches_tidy_filters(
	item: Dictionary, qualities: Array[int], wears: PackedStringArray
) -> bool:
	if qualities.is_empty() and wears.is_empty():
		return false
	var quality: int = int(item.get("quality", -1))
	var wear: String = item_wear_text(item)
	if not qualities.is_empty() and not quality_in_filters(qualities, quality):
		return false
	if not wears.is_empty() and not wear_in_filters(wears, wear):
		return false
	return true


func _split_by_tidy_filters(
	items: Array[Dictionary], qualities: Array[int], wears: PackedStringArray
) -> Dictionary:
	var kept: Array[Dictionary] = []
	var removed: Array[Dictionary] = []
	for item: Dictionary in items:
		if item_matches_tidy_filters(item, qualities, wears):
			removed.append(item)
		else:
			kept.append(item)
	return {"kept": kept, "removed": removed}


func _copy_item_array(source: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: Dictionary in source:
		out.append(item)
	return out


## 抽屉收拾。不减 underwear_total。
func delete_dry_matching(qualities: Array[int], wears: PackedStringArray) -> int:
	var split: Dictionary = _split_by_tidy_filters(dry_collection, qualities, wears)
	var removed: Array = split["removed"]
	if removed.is_empty():
		return 0
	dry_collection = _copy_item_array(split["kept"])
	collection_changed.emit(dry_collection.size())
	save_game()
	return removed.size()


## 烘干机收拾。不减 underwear_total。返回被删条目的 id。
func delete_wet_matching(qualities: Array[int], wears: PackedStringArray) -> Array[int]:
	var split: Dictionary = _split_by_tidy_filters(wet_warehouse, qualities, wears)
	var removed: Array = split["removed"]
	var ids: Array[int] = []
	if removed.is_empty():
		return ids
	for item: Dictionary in removed:
		ids.append(int(item.get("id", 0)))
	wet_warehouse = _copy_item_array(split["kept"])
	warehouse_changed.emit(wet_warehouse.size(), WAREHOUSE_CAPACITY)
	save_game()
	return ids


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


func roll_pressure_wash_cut() -> float:
	return _rng.randf_range(PRESSURE_WASH_REDUCTION_MIN, PRESSURE_WASH_REDUCTION_MAX)


func roll_pressure_runaway() -> bool:
	return _rng.randi_range(1, 1000) <= PRESSURE_RUNAWAY_PERMILLE


## 压力冷却剩余时间，按整秒向上取整，格式 MM：SS（随 _process 每秒变化）。
func format_pressure_countdown(remaining_seconds: float) -> String:
	var total: int = maxi(int(ceili(remaining_seconds)), 0)
	var minutes: int = int(total / 60)
	var seconds: int = total % 60
	return "%d：%02d" % [minutes, seconds]


func _register_washed_quality(quality: int) -> void:
	underwear_total += 1
	var worth: float = float(AFFINITY_QUALITY_VALUE.get(quality, 1.0))
	affinity_quality_sum += log(1.0 + worth)


func record_runaway() -> void:
	runaway_count += 1
	stats_changed.emit()
	save_game()


func companion_elapsed() -> float:
	if _companion_anchor_unix <= 0.0:
		_companion_anchor_unix = Time.get_unix_time_from_system()
	var live: float = Time.get_unix_time_from_system() - _companion_anchor_unix
	return maxf(_companion_saved + live, 0.0)


func tick_companion(delta: float) -> void:
	companion_seconds = companion_elapsed()
	if delta > 0.0:
		_save_accum += delta
	if _save_accum >= SAVE_INTERVAL:
		_save_accum = 0.0
		save_game()


func affinity_score() -> float:
	var quality_term: float = 0.0
	if affinity_quality_sum > 0.0:
		quality_term = affinity_quality_sum / (affinity_quality_sum + AFFINITY_QUALITY_K)
	var quality_points: float = quality_term * AFFINITY_QUALITY_SHARE
	var lived: float = companion_elapsed()
	var companion_ratio: float = 0.0
	if AFFINITY_COMPANION_FULL_SECONDS > 1.0:
		companion_ratio = log(1.0 + lived) / log(1.0 + AFFINITY_COMPANION_FULL_SECONDS)
	companion_ratio = clampf(companion_ratio, 0.0, 1.0)
	var companion_points: float = companion_ratio * AFFINITY_COMPANION_SHARE
	var penalty: float = float(runaway_count) * AFFINITY_RUNAWAY_PENALTY
	return clampf(quality_points + companion_points - penalty, 0.0, 100.0)


func format_companion_clock() -> String:
	var total: int = maxi(int(floor(companion_elapsed())), 0)
	var hours: int = int(total / 3600)
	var minutes: int = int((total % 3600) / 60)
	var seconds: int = total % 60
	if hours >= 100:
		return "%d小时" % hours
	return "%d：%02d：%02d" % [hours, minutes, seconds]


func pet_size_scale() -> float:
	var idx: int = clampi(pet_size_tier, PET_SIZE_SMALL, PET_SIZE_HUGE)
	return float(PET_SIZE_SCALES[idx])


func pet_window_size() -> Vector2i:
	var s: float = pet_size_scale()
	return Vector2i(
		maxi(int(round(float(WINDOW_WIDTH) * s)), 160),
		maxi(int(round(float(WINDOW_HEIGHT) * s)), 220)
	)


func pet_layout_area() -> Rect2:
	var s: float = pet_size_scale()
	var area: Rect2 = Rect2(PET_AREA.position * s, PET_AREA.size * s)
	if pet_size_tier == PET_SIZE_HUGE:
		area.position.x += PET_SIZE_HUGE_SHIFT_X
	return area


func pet_hit_rect(layout: Rect2) -> Rect2:
	var pad_x: float = layout.size.x * PET_HIT_PAD_X
	var pad_top: float = layout.size.y * PET_HIT_PAD_TOP
	var pad_bottom: float = layout.size.y * PET_HIT_PAD_BOTTOM
	return Rect2(
		layout.position + Vector2(pad_x, pad_top),
		Vector2(
			maxf(layout.size.x - pad_x * 2.0, 24.0),
			maxf(layout.size.y - pad_top - pad_bottom, 32.0)
		)
	)


func tick_work_presence(delta: float) -> void:
	if delta <= 0.0:
		return
	work_presence_seconds += delta
	if work_presence_seconds >= WORK_BREAK_SECONDS:
		work_presence_seconds = fmod(work_presence_seconds, WORK_BREAK_SECONDS)
		_work_break_ready = true


func consume_work_break() -> bool:
	if not _work_break_ready:
		return false
	_work_break_ready = false
	save_game()
	return true


func notice_excerpt(raw: String) -> String:
	var text: String = sanitize_chat_output(raw)
	if text.length() > NOTICE_MAX_CHARS:
		return text.substr(0, NOTICE_MAX_CHARS) + "..."
	return text


func inventory_grid_size() -> Vector2:
	return Vector2(
		float(GRID_COLUMNS) * ITEM_CARD_SIZE.x + float(GRID_COLUMNS - 1) * float(GRID_H_SEP),
		float(GRID_VISIBLE_ROWS) * ITEM_CARD_SIZE.y + float(GRID_VISIBLE_ROWS - 1) * float(GRID_V_SEP)
	)


func inventory_window_size(tidy_open: bool = false) -> Vector2i:
	var grid: Vector2 = inventory_grid_size()
	var width: int = int(round(grid.x + INVENTORY_PAD_X + INVENTORY_SCROLL_GUTTER))
	var height: int = int(round(grid.y + INVENTORY_CHROME_Y))
	if tidy_open:
		height += int(TIDY_PANEL_MIN_HEIGHT)
	return Vector2i(width, height)


func context_menu_window_size(settings_open: bool = false) -> Vector2i:
	var scaled: Vector2i = Vector2i(
		int(float(CONTEXT_MENU_BASE_SIZE.x) * CONTEXT_MENU_SCALE),
		int(float(CONTEXT_MENU_BASE_SIZE.y) * CONTEXT_MENU_SCALE)
	)
	if settings_open:
		scaled.y += SETTINGS_PANEL_EXTRA_HEIGHT
	var usable: Rect2i = DisplayServer.screen_get_usable_rect()
	var pad: int = 16 if settings_open else 48
	if usable.size.x > pad:
		scaled.x = clampi(scaled.x, 480, usable.size.x - pad)
	if usable.size.y > pad:
		scaled.y = clampi(scaled.y, 520, usable.size.y - pad)
	return scaled


func sanitize_chat_input(raw: String) -> String:
	var text: String = raw.replace("\u0000", "").strip_edges()
	if text.length() > CHAT_MAX_INPUT_CHARS:
		text = text.substr(0, CHAT_MAX_INPUT_CHARS)
	return text


func sanitize_chat_output(raw: String) -> String:
	var text: String = raw.replace("\u0000", "").strip_edges()
	if text.length() > CHAT_MAX_OUTPUT_CHARS:
		text = text.substr(0, CHAT_MAX_OUTPUT_CHARS)
	return text


func prune_chat_history() -> void:
	var cutoff: float = Time.get_unix_time_from_system() - CHAT_HISTORY_SECONDS
	var kept: Array[Dictionary] = []
	for item: Dictionary in chat_messages:
		if float(item.get("at", 0.0)) < cutoff:
			continue
		kept.append(item)
	if kept.size() > CHAT_MAX_STORED:
		var trimmed: Array[Dictionary] = []
		for i: int in range(kept.size() - CHAT_MAX_STORED, kept.size()):
			trimmed.append(kept[i])
		kept = trimmed
	chat_messages = kept


func append_chat_message(role: String, text: String) -> Dictionary:
	var clean: String = sanitize_chat_output(text) if role == "assistant" else sanitize_chat_input(text)
	if clean.is_empty():
		return {}
	var item: Dictionary = {
		"role": role,
		"text": clean,
		"at": Time.get_unix_time_from_system(),
	}
	chat_messages.append(item)
	prune_chat_history()
	save_game()
	return item


func chat_context_for_api() -> Array[Dictionary]:
	prune_chat_history()
	var start: int = maxi(chat_messages.size() - CHAT_CONTEXT_LIMIT, 0)
	var out: Array[Dictionary] = []
	for i: int in range(start, chat_messages.size()):
		var item: Dictionary = chat_messages[i]
		out.append({
			"role": String(item.get("role", "user")),
			"content": String(item.get("text", "")),
		})
	return out


func _chat_file_config() -> Dictionary:
	if not FileAccess.file_exists(CHAT_CONFIG_FILE):
		return {}
	var file: FileAccess = FileAccess.open(CHAT_CONFIG_FILE, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		return parsed
	return {}


func resolved_chat_api_url() -> String:
	var env_url: String = OS.get_environment(CHAT_API_URL_ENV).strip_edges()
	if not env_url.is_empty():
		return env_url
	var cfg: Dictionary = _chat_file_config()
	var file_url: String = String(cfg.get("url", "")).strip_edges()
	if not file_url.is_empty():
		return file_url
	return CHAT_API_URL.strip_edges()


func resolved_chat_api_key() -> String:
	var env_key: String = OS.get_environment(CHAT_API_KEY_ENV).strip_edges()
	if not env_key.is_empty():
		return env_key
	var cfg: Dictionary = _chat_file_config()
	var file_key: String = String(cfg.get("key", cfg.get("api_key", ""))).strip_edges()
	if not file_key.is_empty():
		return file_key
	if FileAccess.file_exists(CHAT_API_KEY_FILE):
		var file: FileAccess = FileAccess.open(CHAT_API_KEY_FILE, FileAccess.READ)
		if file != null:
			var key: String = file.get_line().strip_edges()
			file.close()
			return key
	return ""


func resolved_chat_model() -> String:
	var env_model: String = OS.get_environment(CHAT_MODEL_ENV).strip_edges()
	if not env_model.is_empty():
		return env_model
	var cfg: Dictionary = _chat_file_config()
	var file_model: String = String(cfg.get("model", "")).strip_edges()
	if not file_model.is_empty():
		return file_model
	return CHAT_MODEL.strip_edges()


func chat_api_ready() -> bool:
	var url: String = resolved_chat_api_url()
	return not url.is_empty() and chat_url_is_safe(url)


func chat_fail_text(reason: String) -> String:
	if reason == "unsafe_url":
		return "接口地址不安全，请改用 HTTPS。"
	if reason == "http_401" or reason == "http_403":
		return "密钥无效或没有权限。"
	if reason.begins_with("http_"):
		return "服务器没有应答，稍后再试。"
	if reason == "empty_reply":
		return "模型没有返回内容。"
	if reason == "request_error":
		return "发不出去，请检查网络。"
	return CHAT_FAIL_TEXT


func chat_url_is_safe(url: String) -> bool:
	var lower: String = url.to_lower()
	if lower.begins_with("https://"):
		return true
	if lower.begins_with("http://127.0.0.1") or lower.begins_with("http://localhost"):
		return true
	return false


func build_chat_payload(history: Array[Dictionary], system_prompt: String = "") -> String:
	var prompt: String = system_prompt.strip_edges()
	if prompt.is_empty():
		prompt = CHAT_SYSTEM_PROMPT.strip_edges()
	var messages: Array = []
	if not prompt.is_empty():
		messages.append({
			"role": "system",
			"content": prompt,
		})
	for item: Dictionary in history:
		messages.append({
			"role": String(item.get("role", "user")),
			"content": String(item.get("content", item.get("text", ""))),
		})
	var payload: Dictionary = {
		"messages": messages,
		"stream": false,
		"system": prompt,
	}
	var model: String = resolved_chat_model()
	if not model.is_empty():
		payload["model"] = model
	return JSON.stringify(payload)


func fortune_year_max() -> int:
	return Time.get_date_dict_from_system().get("year", 2026)


func days_in_month(year: int, month: int) -> int:
	var dim: PackedInt32Array = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	var leap: bool = (year % 4 == 0 and year % 100 != 0) or year % 400 == 0
	if month == 2 and leap:
		return 29
	if month < 1 or month > 12:
		return 31
	return int(dim[month])


func clamp_fortune_date(year: int, month: int, day: int, hour: int) -> Dictionary:
	var y: int = clampi(year, FORTUNE_YEAR_MIN, fortune_year_max())
	var m: int = clampi(month, 1, 12)
	var d: int = clampi(day, 1, days_in_month(y, m))
	var h: int = clampi(hour, 0, 23)
	return {"year": y, "month": m, "day": d, "hour": h}


func set_fortune_birth(year: int, month: int, day: int, hour: int) -> void:
	var clamped: Dictionary = clamp_fortune_date(year, month, day, hour)
	fortune_year = int(clamped["year"])
	fortune_month = int(clamped["month"])
	fortune_day = int(clamped["day"])
	fortune_hour = int(clamped["hour"])
	save_game()


func shichen_index_from_hour(hour: int) -> int:
	return ((clampi(hour, 0, 23) + 1) % 24) / 2


func shichen_label(hour: int) -> String:
	var idx: int = shichen_index_from_hour(hour)
	return "%s（%s）" % [SHICHEN_NAMES[idx], SHICHEN_RANGES[idx]]


func fortune_birth_label() -> String:
	return "公历 %04d-%02d-%02d  %s" % [
		fortune_year, fortune_month, fortune_day, shichen_label(fortune_hour),
	]


func fortune_user_prompt() -> String:
	return "按这个生辰排盘，不要追问、不要改期。%s。请给娱乐向今日运势。" % fortune_birth_label()


func fortune_offline_reply() -> String:
	return "%s %s。宜：把该洗的洗完，把注意力花在增量上。忌：口头改生辰、跟风 All in 不懂的赛道。这是娱乐参考，风险自负。今天就按这个生辰过。🚀" % [
		FORTUNE_OFFLINE_PREFIX, fortune_birth_label(),
	]


func shuffled_movie_catalog() -> Array:
	var copy: Array = MOVIE_CATALOG.duplicate(true)
	copy.shuffle()
	return copy


func movie_cache_path(movie_id: String) -> String:
	return "%s/%s.ogv" % [MOVIE_CACHE_DIR, movie_id]


func movie_is_cached(movie_id: String) -> bool:
	var path: String = movie_cache_path(movie_id)
	if not FileAccess.file_exists(path):
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var size: int = file.get_length()
	file.close()
	return size > 65536


func archive_download_url(archive_id: String, file_name: String) -> String:
	return "https://archive.org/download/%s/%s" % [
		archive_id.uri_encode(), file_name.uri_encode(),
	]


func pick_archive_ogv(files: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_size: int = 1 << 30
	for entry: Variant in files:
		if not entry is Dictionary:
			continue
		var item: Dictionary = entry
		var name: String = String(item.get("name", ""))
		var fmt: String = String(item.get("format", "")).to_lower()
		var size: int = int(item.get("size", 0))
		var low: String = name.to_lower()
		if size <= 65536 or size > MOVIE_MAX_BYTES:
			continue
		if "vorbis" in fmt and not low.ends_with(".ogv"):
			continue
		var is_ogv: bool = low.ends_with(".ogv") or fmt == "ogg video" or "theora" in fmt
		if not is_ogv:
			continue
		if "vp8" in low or "vp9" in low:
			continue
		if size < best_size:
			best_size = size
			best = {"name": name, "size": size}
	return best


func parse_chat_reply(body: PackedByteArray) -> String:
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if parsed is Dictionary:
		var data: Dictionary = parsed
		if data.has("choices"):
			var choices: Array = data.get("choices", [])
			if not choices.is_empty() and choices[0] is Dictionary:
				var message: Dictionary = (choices[0] as Dictionary).get("message", {})
				return sanitize_chat_output(String(message.get("content", "")))
		if data.has("reply"):
			return sanitize_chat_output(String(data.get("reply", "")))
		if data.has("content"):
			return sanitize_chat_output(String(data.get("content", "")))
		if data.has("message") and data.get("message") is String:
			return sanitize_chat_output(String(data.get("message", "")))
		if data.has("output") and data.get("output") is String:
			return sanitize_chat_output(String(data.get("output", "")))
		if data.has("choices"):
			var choices2: Array = data.get("choices", [])
			if not choices2.is_empty() and choices2[0] is Dictionary:
				return sanitize_chat_output(String((choices2[0] as Dictionary).get("text", "")))
	if parsed is String:
		return sanitize_chat_output(parsed)
	return ""


# --- 存档 ---------------------------------------------------------------

func to_save_dict() -> Dictionary:
	return {
		"coins": coins,
		"wet_warehouse": wet_warehouse.duplicate(true),
		"dry_collection": dry_collection.duplicate(true),
		"equipped_quality": equipped_quality,
		"codex_counts": codex_counts.duplicate(true),
		"next_item_id": _next_item_id,
		"underwear_total": underwear_total,
		"companion_seconds": companion_elapsed(),
		"runaway_count": runaway_count,
		"affinity_quality_sum": affinity_quality_sum,
		"always_on_top_pref": always_on_top_pref,
		"pet_size_tier": pet_size_tier,
		"chat_messages": chat_messages.duplicate(true),
		"work_presence_seconds": work_presence_seconds,
		"fortune_year": fortune_year,
		"fortune_month": fortune_month,
		"fortune_day": fortune_day,
		"fortune_hour": fortune_hour,
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
	underwear_total = int(data.get("underwear_total", 0))
	companion_seconds = float(data.get("companion_seconds", 0.0))
	_companion_saved = companion_seconds
	_companion_anchor_unix = Time.get_unix_time_from_system()
	runaway_count = int(data.get("runaway_count", 0))
	affinity_quality_sum = float(data.get("affinity_quality_sum", 0.0))
	always_on_top_pref = bool(data.get("always_on_top_pref", ALWAYS_ON_TOP_DEFAULT))
	pet_size_tier = clampi(int(data.get("pet_size_tier", PET_SIZE_MEDIUM)), PET_SIZE_SMALL, PET_SIZE_HUGE)
	work_presence_seconds = maxf(float(data.get("work_presence_seconds", 0.0)), 0.0)
	var birth: Dictionary = clamp_fortune_date(
		int(data.get("fortune_year", FORTUNE_DEFAULT_YEAR)),
		int(data.get("fortune_month", FORTUNE_DEFAULT_MONTH)),
		int(data.get("fortune_day", FORTUNE_DEFAULT_DAY)),
		int(data.get("fortune_hour", FORTUNE_DEFAULT_HOUR))
	)
	fortune_year = int(birth["year"])
	fortune_month = int(birth["month"])
	fortune_day = int(birth["day"])
	fortune_hour = int(birth["hour"])
	chat_messages.clear()
	for entry: Dictionary in data.get("chat_messages", []):
		var role: String = String(entry.get("role", ""))
		var text: String = sanitize_chat_output(String(entry.get("text", "")))
		if (role != "user" and role != "assistant") or text.is_empty():
			continue
		chat_messages.append({
			"role": role,
			"text": text,
			"at": float(entry.get("at", 0.0)),
		})
	prune_chat_history()
	if underwear_total <= 0:
		var derived: int = 0
		for q: Variant in codex_counts.keys():
			derived += int(codex_counts[q])
		underwear_total = derived
	if affinity_quality_sum <= 0.0 and underwear_total > 0:
		for q: Variant in codex_counts.keys():
			var worth: float = float(AFFINITY_QUALITY_VALUE.get(int(q), 1.0))
			affinity_quality_sum += log(1.0 + worth) * float(codex_counts[q])
	warehouse_changed.emit(wet_warehouse.size(), WAREHOUSE_CAPACITY)
	collection_changed.emit(dry_collection.size())
	coins_changed.emit(coins)
	equipped_changed.emit(equipped_quality)
	stats_changed.emit()


func save_game() -> void:
	companion_seconds = companion_elapsed()
	_companion_saved = companion_seconds
	_companion_anchor_unix = Time.get_unix_time_from_system()
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(to_save_dict(), "\t"))
	file.close()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		load_from_dict(parsed as Dictionary)


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
