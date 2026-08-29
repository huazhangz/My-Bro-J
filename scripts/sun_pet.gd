extends Control

## 孙哥桌宠主脚本
##
## 职责：
##   1. 透明无边框窗口的初始化与「全局鼠标坐标」拖拽（Day 1）
##   2. 洗涤 / 晾干 / 仓库满暂停 / 跑路冷却 的核心状态机（Day 2）
##   3. 悬浮中文 UI：代币 / 状态倒计时 / 仓库挂起 / 加速按钮 / 图鉴换装（Day 3）
##   4. 动态立绘：VideoStreamPlayer 循环播放，跑路时隐藏并暂停（Day 4）
##
## 窗口移动一律走 DisplayServer，不用 Window.position，
## 否则在编辑器内嵌运行时会报 "Embedded windows can't be moved"。

enum State {
	WASHING,     # 正在洗涤
	PAUSED_FULL, # 仓库已满，暂停洗涤
	RUNAWAY,     # 孙哥跑路中，窗口隐藏 + 冷却倒计时
}

## 视频抠像：Ogg Theora **不带 Alpha 通道**，视频会画成一块不透明矩形。
## 打开 chroma_key_enabled 后，PetFrame 用色度键把接近 chroma_key_color 的像素抠成透明。
## 白底填 Color(1,1,1)、绿幕填 Color(0,1,0)、黑底填 Color(0,0,0)。

const DRAG_BUTTON: int = MOUSE_BUTTON_LEFT
## 拖拽时窗口至少要留在屏幕内的边距。
const SCREEN_MARGIN: int = 24
## 飘字提示的停留与淡出时长（纯表现，不影响玩法数值）。
const TOAST_HOLD: float = 1.1
const TOAST_FADE: float = 0.5
## 图鉴一行里品质名 / 穿戴按钮的最小宽度。
const CODEX_NAME_WIDTH: int = 54
const CODEX_BUTTON_WIDTH: int = 56

## 动态立绘视频。Godot 4 只支持 Ogg Theora（`.ogv`），mp4 / webm 必须先转码，
## 转换命令见 assets/videos/README.md。把文件放到 VIDEO_PATH 就会自动接管几何占位；
## 文件不存在时回落到占位图形，项目照常能跑，不会报错。
const VIDEO_DIR: String = "res://assets/videos"
const VIDEO_PATH: String = "res://assets/videos/sun_pet.ogv"
## 立绘可用区域（顶部 HUD 与底部按钮栏之间）。视频按自身宽高比在这块区域里
## 居中内接，不会被拉伸变形，也不会盖住 UI。
const VIDEO_AREA: Rect2 = Rect2(10.0, 98.0, 230.0, 160.0)
## 视频有效性宽限帧数。坏流（比如容器合法但没有 Theora 视频轨）play() 之后
## is_playing() 照样是 true，只能靠「这么多帧还没解出画面」来判定它其实播不了。
const VIDEO_PROBE_FRAMES: int = 45
## 视频相关日志前缀。这些日志不受 --petlog 控制，F5 就能在输出面板看到。
const VIDEO_LOG_PREFIX: String = "[SunPet/Video] "
## 仓库自带的占位片很小。超过这个体积就当作用户自己的素材，不再弹「请覆盖」提示。
const STUB_VIDEO_MAX_BYTES: int = 80000

@export_group("视频立绘 / 色度键")
## 打开后把视频帧送到 PetFrame，用着色器抠掉 chroma_key_color。
@export var chroma_key_enabled: bool = false:
	set(value):
		chroma_key_enabled = value
		if is_node_ready():
			_apply_video_key()
			_sync_video_display()
			_log_chroma_key_state()
## 要抠掉的背景色。白底 #FFFFFF、绿幕 #00FF00、黑底 #000000。
@export var chroma_key_color: Color = Color(1.0, 1.0, 1.0):
	set(value):
		chroma_key_color = value
		if is_node_ready():
			_apply_video_key()
## 颜色容差，越大抠得越多。建议 0.3–0.4。
@export_range(0.0, 1.0, 0.01) var chroma_key_similarity: float = 0.35:
	set(value):
		chroma_key_similarity = value
		if is_node_ready():
			_apply_video_key()
## 边缘羽化，越大越软，避免锯齿。建议约 0.1。
@export_range(0.0, 1.0, 0.01) var chroma_key_smoothness: float = 0.10:
	set(value):
		chroma_key_smoothness = value
		if is_node_ready():
			_apply_video_key()

@onready var _pet_visual: Control = %PetVisual
@onready var _pet_video: VideoStreamPlayer = %PetVideo
@onready var _pet_frame: TextureRect = %PetFrame
@onready var _placeholder_visual: Control = %PlaceholderVisual
@onready var _equipped_mark: ColorRect = %EquippedMark
@onready var _quality_flash: ColorRect = %QualityFlash

@onready var _hud_panel: PanelContainer = %HudPanel
@onready var _coin_label: Label = %CoinLabel
@onready var _status_label: Label = %StatusLabel
@onready var _wash_bar: ProgressBar = %WashBar
@onready var _warehouse_label: Label = %WarehouseLabel
@onready var _equipped_label: Label = %EquippedLabel
@onready var _toast_label: Label = %ToastLabel

@onready var _button_bar: VBoxContainer = %ButtonBar
@onready var _free_button: Button = %FreeSpeedButton
@onready var _paid_button: Button = %PaidSpeedButton
@onready var _codex_open_button: Button = %CodexOpenButton
@onready var _quit_button: Button = %QuitButton

@onready var _runaway_banner: PanelContainer = %RunawayBanner
@onready var _runaway_label: Label = %RunawayLabel

@onready var _codex_panel: PanelContainer = %CodexPanel
@onready var _codex_list: VBoxContainer = %CodexList
@onready var _codex_cd_label: Label = %CodexCdLabel
@onready var _unequip_button: Button = %UnequipButton
@onready var _codex_close_button: Button = %CodexCloseButton

var _state: int = State.WASHING
var _wash_remaining: float = 0.0
var _cooldown_remaining: float = 0.0

var _dragging: bool = false
var _drag_offset: Vector2i = Vector2i.ZERO
var _embedded: bool = false
## 用 `godot -- --petlog` 启动时打印状态机日志，方便无 UI 时验证逻辑。
var _debug_log: bool = false

## item_id -> Timer，用于每条内裤各自的 60 秒晾干计时。
var _dry_timers: Dictionary = {}
## quality -> { "count": Label, "button": Button }，图鉴每一行的控件。
var _codex_rows: Dictionary = {}
var _toast_tween: Tween = null

## 是否用视频立绘（找不到 .ogv 时为 false，走几何占位）。
var _video_enabled: bool = false
## 是否确认视频真的能解出画面。确认前几何占位不撤，避免坏素材时中间一片空白。
var _video_confirmed: bool = false
## 等待第一帧的剩余宽限帧数，归零仍无画面就判定素材有问题。
var _video_probe_left: int = 0
## 视频尺寸要解出第一帧才知道，按宽高比摆好位置后置 true，不再每帧重算。
var _video_fitted: bool = false
## 几何占位模式下换装色块的原始位置，视频模式会把它挪到视频底部。
var _mark_default_rect: Rect2 = Rect2()


func _ready() -> void:
	_debug_log = OS.get_cmdline_user_args().has("--petlog")
	_apply_window_setup()
	_setup_pet_video()
	_build_codex_rows()
	_apply_static_ui_text()
	_connect_ui()
	_connect_game_data()
	_start_wash_cycle()
	_refresh_all()


# =========================================================================
# Day 1：窗口 + 拖拽
# =========================================================================

## 编辑器「内嵌运行游戏窗口」时，窗口由编辑器托管，无法自由移动。
## 内嵌启动会带 --wid 命令行参数，据此识别并给出提示。
func _is_embedded_in_editor() -> bool:
	return OS.get_cmdline_args().has("--wid")


func _apply_window_setup() -> void:
	# 视口透明背景：配合 project.godot 里的 per_pixel_transparency/allowed。
	var win: Window = get_window()
	win.transparent_bg = true

	_embedded = _is_embedded_in_editor()
	if _embedded:
		push_warning("窗口被编辑器内嵌运行，无法拖拽。请在 Game 面板关闭 Embed Game on Play。")
		return

	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)

	# 首次启动时把窗口挪到屏幕右下角，避免正好压在编辑器上。
	# 注意别把局部变量取名 size / position，会遮蔽 Control 自己的同名属性。
	var usable: Rect2i = DisplayServer.screen_get_usable_rect()
	var window_size: Vector2i = DisplayServer.window_get_size()
	var target: Vector2i = Vector2i(
		usable.position.x + usable.size.x - window_size.x - 80,
		usable.position.y + usable.size.y - window_size.y - 80
	)
	DisplayServer.window_set_position(target)


func _gui_input(event: InputEvent) -> void:
	# 只在桌宠自身区域内按下才开始拖拽（UI 按钮会先吃掉自己的点击）。
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == DRAG_BUTTON and mb.pressed:
			_begin_drag()
			accept_event()


func _input(event: InputEvent) -> void:
	# 松手可能发生在窗口外，所以放在全局 _input 里收。
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == DRAG_BUTTON and not mb.pressed:
			_dragging = false
	elif event is InputEventKey:
		var key: InputEventKey = event
		if not key.pressed:
			return
		match key.keycode:
			KEY_ESCAPE:
				# 图鉴开着时先关图鉴，再按一次才退出。
				if _codex_panel.visible:
					_set_codex_visible(false)
				else:
					get_tree().quit()
			KEY_SPACE:
				# 调试快捷键：等价于点一次「免费加速」。
				_on_free_speedup_pressed()


func _begin_drag() -> void:
	if _embedded:
		return
	# 记录「按下瞬间，鼠标相对窗口左上角的偏移」，之后始终用全局坐标减这个偏移，
	# 避免用 event.relative 累加导致的抖动/漂移。
	_drag_offset = DisplayServer.mouse_get_position() - DisplayServer.window_get_position()
	_dragging = true


func _update_drag() -> void:
	var target: Vector2i = DisplayServer.mouse_get_position() - _drag_offset
	DisplayServer.window_set_position(_clamp_to_screen(target))


func _clamp_to_screen(pos: Vector2i) -> Vector2i:
	var usable: Rect2i = DisplayServer.screen_get_usable_rect()
	var window_size: Vector2i = DisplayServer.window_get_size()
	var min_x: int = usable.position.x - window_size.x + SCREEN_MARGIN
	var max_x: int = usable.position.x + usable.size.x - SCREEN_MARGIN
	var min_y: int = usable.position.y - window_size.y + SCREEN_MARGIN
	var max_y: int = usable.position.y + usable.size.y - SCREEN_MARGIN
	return Vector2i(clampi(pos.x, min_x, max_x), clampi(pos.y, min_y, max_y))


# =========================================================================
# Day 2：洗涤 / 晾干 / 跑路 状态机
# =========================================================================

func _connect_game_data() -> void:
	GameData.warehouse_changed.connect(func(_current: int, _capacity: int) -> void:
		_try_resume_wash()
		_update_warehouse_label()
	)
	GameData.coins_changed.connect(func(coins: int) -> void:
		_update_coin_label(coins)
		_refresh_buttons()
	)
	GameData.collection_changed.connect(func(_total: int) -> void:
		_update_equipped_label()
		_refresh_codex()
	)
	GameData.equipped_changed.connect(func(quality: int) -> void:
		_update_equipped_label()
		_update_equipped_mark(quality)
		_refresh_codex()
	)
	GameData.item_washed.connect(func(item: Dictionary) -> void:
		var quality: int = int(item["quality"])
		_flash_quality(quality)
		_show_toast("洗出%s内裤" % _quality_tag(quality), GameData.QUALITY_COLORS.get(quality, Color.WHITE))
		_log("washed #%d %s -> wet=%d/%d" % [
			int(item["id"]),
			String(GameData.QUALITY_NAMES[quality]),
			GameData.wet_warehouse.size(),
			GameData.WAREHOUSE_CAPACITY,
		])
	)
	GameData.item_dried.connect(func(item: Dictionary) -> void:
		var quality: int = int(item["quality"])
		_flash_quality(quality)
		_show_toast("晾干%s +%d 金币" % [
			_quality_tag(quality),
			int(GameData.COIN_REWARD.get(quality, 0)),
		], GameData.QUALITY_COLORS.get(quality, Color.WHITE))
		_log("dried #%d %s -> collection=%d coins=%d" % [
			int(item["id"]),
			String(GameData.QUALITY_NAMES[quality]),
			GameData.dry_collection.size(),
			GameData.coins,
		])
	)


func _process(delta: float) -> void:
	if _dragging:
		_update_drag()

	match _state:
		State.WASHING:
			_tick_wash(delta)
		State.RUNAWAY:
			_tick_runaway(delta)
		State.PAUSED_FULL:
			pass

	# 视频宽高只有解出第一帧后才拿得到；顺便用它确认这个素材是不是真的能播。
	if _video_enabled and not _video_fitted:
		_tick_video_probe()
	elif _video_enabled and chroma_key_enabled:
		_feed_pet_frame_texture()

	# 每帧只刷新会跳秒的部分，其余文本由 GameData 信号驱动。
	_update_status_text()
	_update_wash_bar()


func _start_wash_cycle() -> void:
	if GameData.is_warehouse_full():
		_state = State.PAUSED_FULL
		_log("warehouse full (%d) -> wash paused" % GameData.wet_warehouse.size())
		_refresh_buttons()
		return
	_wash_remaining = GameData.WASH_DURATION
	_state = State.WASHING
	_refresh_buttons()


func _tick_wash(delta: float) -> void:
	_wash_remaining -= delta
	if _wash_remaining > 0.0:
		return
	_finish_wash()


## 洗完一条：进仓库 + 启动该条自己的 60 秒晾干 Timer。
func _finish_wash() -> void:
	var item: Dictionary = GameData.add_wet_item()
	if item.is_empty():
		# 理论上不会走到这里（满仓时已暂停），兜底切暂停。
		_state = State.PAUSED_FULL
		_refresh_buttons()
		return

	_start_dry_timer(int(item["id"]))
	_start_wash_cycle()


func _start_dry_timer(item_id: int) -> void:
	var timer: Timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = GameData.DRY_DURATION
	add_child(timer)
	_dry_timers[item_id] = timer
	# 闭包捕获局部拷贝的 item_id。
	timer.timeout.connect(func() -> void:
		GameData.dry_item(item_id)
		_dry_timers.erase(item_id)
		timer.queue_free()
	)
	timer.start()


## 有空位时自动恢复洗涤。
func _try_resume_wash() -> void:
	if _state == State.PAUSED_FULL and not GameData.is_warehouse_full():
		_log("slot freed -> wash resumed")
		_start_wash_cycle()


# =========================================================================
# 加速 / 跑路
# =========================================================================

## 免费加速：有概率触发「孙哥随机跑路」，否则直接减少洗涤倒计时。
## 返回 true 表示加速成功，false 表示触发了跑路（或当前不在洗涤中）。
func trigger_free_speedup() -> bool:
	if _state != State.WASHING:
		return false

	if randf() < GameData.FREE_SPEEDUP_RUNAWAY_CHANCE:
		_trigger_runaway()
		return false

	_wash_remaining = maxf(_wash_remaining - GameData.FREE_SPEEDUP_SECONDS, 0.0)
	return true


## 付费加速：消耗代币直接洗完当前这一条，无跑路风险。
## 返回 false 表示金币不足或当前不在洗涤中。
func trigger_paid_speedup() -> bool:
	if _state != State.WASHING:
		return false
	if not GameData.try_spend_coins(GameData.PAID_SPEEDUP_COST):
		return false
	_wash_remaining = 0.0
	_finish_wash()
	return true


## 孙哥跑路：隐藏桌宠 + 按品质缩减后的冷却时间倒计时。
func _trigger_runaway() -> void:
	_state = State.RUNAWAY
	_cooldown_remaining = GameData.get_calculated_cooldown()
	_dragging = false
	_set_codex_visible(false)
	_set_pet_hidden(true)
	_log("RUNAWAY! hidden, cooldown=%.1fs (reduction=%.0f%%)" % [
		_cooldown_remaining,
		GameData.get_cd_reduction() * 100.0,
	])


func _tick_runaway(delta: float) -> void:
	_cooldown_remaining -= delta
	if _cooldown_remaining > 0.0:
		return
	_cooldown_remaining = 0.0
	_set_pet_hidden(false)
	_log("cooldown over -> pet is back")
	_show_toast("孙哥回来了", Color(0.55, 1.0, 0.75))
	_start_wash_cycle()


## 跑路期间「隐藏窗口」：藏掉桌宠与全部可交互 UI，并开启鼠标穿透，
## 使窗口在视觉与交互上都等于消失（不用 minimize，避免抢占任务栏焦点）。
## 只保留一条半透明的冷却提示条，让玩家知道孙哥什么时候回来。
## 参数别叫 hidden：那是 CanvasItem 自带的信号名，会被 GDScript 判成遮蔽。
func _set_pet_hidden(hide_pet: bool) -> void:
	_pet_visual.visible = not hide_pet
	_set_video_playing(not hide_pet)
	_hud_panel.visible = not hide_pet
	_button_bar.visible = not hide_pet
	_toast_label.visible = not hide_pet
	_quality_flash.visible = false
	_runaway_banner.visible = hide_pet
	# WINDOW_FLAG_MOUSE_PASSTHROUGH 为 true 时整窗鼠标事件全部穿透，无需设置多边形。
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH, hide_pet)


# =========================================================================
# Day 4：动态立绘（VideoStreamPlayer）
# =========================================================================

## 启动时解析并播放动态立绘。任何一步失败都回落到几何占位，并在控制台打印
## 「为什么没播成」+「怎么修」，不需要加 --petlog 也能看到。
func _setup_pet_video() -> void:
	_mark_default_rect = Rect2(_equipped_mark.position, _equipped_mark.size)
	_apply_video_key()

	var path: String = _resolve_video_path()
	if path.is_empty():
		_fail_video("在 %s 里没找到任何 .ogv 文件。%s" % [VIDEO_DIR, _describe_video_dir()],
			_convert_hint(_find_unplayable_source()))
		return

	# 文件头体检：把「mp4 直接改名成 .ogv」这类问题在加载前就说清楚，
	# 否则引擎只会甩一句 "has no video stream" 然后画面一片空白。
	var container_problem: String = _diagnose_container(path)
	if not container_problem.is_empty():
		_fail_video("%s —— %s" % [path, container_problem], _convert_hint(path))
		return

	var stream: VideoStream = _load_video_stream(path)
	if stream == null:
		_fail_video("%s 存在，但 ResourceLoader 没能把它加载成 VideoStream 资源。" % path,
			_convert_hint(path))
		return

	# 场景里已经把 sun_pet.ogv 赋给 stream（编辑器预览用）。路径没变就沿用，
	# 避免 F5 时再 load 一次把播放器冲掉。
	if _pet_video.stream != stream:
		_pet_video.stream = stream
	# 这三项场景里已经设好，这里再显式兜一层，避免检查器被人手滑改掉。
	_pet_video.autoplay = true
	_pet_video.loop = true
	_pet_video.expand = true
	if not _pet_video.finished.is_connected(_on_video_finished):
		_pet_video.finished.connect(_on_video_finished)

	_video_enabled = true
	_video_fitted = false
	_pet_video.play()
	_sync_video_display()

	# 坏流（比如容器合法但没有 Theora 视频轨）play() 一样返回 is_playing() == true，
	# 唯一靠谱的区分信号是时长和视频贴图：时长 > 0 立刻确认，否则给若干帧宽限期等第一帧。
	var length: float = _pet_video.get_stream_length()
	_video_confirmed = length > 0.0
	_video_probe_left = VIDEO_PROBE_FRAMES
	_refresh_visual_swap()

	print_rich("[color=#54d18c]%s已加载动态立绘：%s[/color]" % [VIDEO_LOG_PREFIX, path])
	print("%s  资源类型=%s  时长=%.2fs  autoplay=%s  loop=%s  静音=%s" % [
		VIDEO_LOG_PREFIX,
		stream.get_class(),
		length,
		_pet_video.autoplay,
		_pet_video.loop,
		_pet_video.volume_db <= -60.0,
	])
	if not _video_confirmed:
		print_rich("[color=#ffcc66]%s  时长读出来是 0，正在等第一帧确认能不能解码……[/color]" % VIDEO_LOG_PREFIX)
	_warn_if_stub_video(path)
	_log_chroma_key_state()


func _on_video_finished() -> void:
	# loop = true 时正常不会触发；万一某些流跑到结尾停住就重开，保证循环不断。
	if _video_enabled and not _pet_video.is_playing():
		_pet_video.play()


## 优先用场景里挂好的 stream（编辑器预览那份），再退到约定文件名 / 目录扫描。
func _resolve_video_path() -> String:
	var from_stream: String = _stream_file_path(_pet_video.stream)
	if not from_stream.is_empty() and FileAccess.file_exists(from_stream):
		return from_stream
	# 用 FileAccess 而不是 ResourceLoader.exists() 来判断存在性：
	# 文件刚拷进来、编辑器还没重新扫描时，资源系统里可能还查不到它。
	if FileAccess.file_exists(VIDEO_PATH):
		return VIDEO_PATH
	for file_name: String in _video_dir_files():
		# 导出后资源会带 .remap 后缀，去掉再判断扩展名。
		var clean: String = file_name.trim_suffix(".remap")
		if clean.get_extension().to_lower() == "ogv":
			return "%s/%s" % [VIDEO_DIR, clean]
	return ""


## 从 VideoStream 上取出真正的 .ogv 路径。
## 场景里直接挂 ogv 时 resource_path 就是文件本身；
## 若是 VideoStreamTheora 子资源，路径在 file 属性上。
func _stream_file_path(stream: VideoStream) -> String:
	if stream == null:
		return ""
	var theora: VideoStreamTheora = stream as VideoStreamTheora
	if theora != null and not theora.file.is_empty():
		return theora.file
	var path: String = stream.resource_path
	if path.get_extension().to_lower() == "ogv":
		return path
	return ""


func _video_dir_files() -> PackedStringArray:
	var dir: DirAccess = DirAccess.open(VIDEO_DIR)
	if dir == null:
		return PackedStringArray()
	return dir.get_files()


## 列出视频目录里的内容，方便一眼看出「文件到底放没放对、是不是还没转码」。
func _describe_video_dir() -> String:
	var shown: PackedStringArray = PackedStringArray()
	for file_name: String in _video_dir_files():
		if file_name.get_extension().to_lower() in ["uid", "import", "remap", "md"]:
			continue
		if file_name.begins_with("."):
			continue
		shown.append(file_name)
	if shown.is_empty():
		return "该目录下没有任何素材文件。"
	return "目录里现在有：%s" % ", ".join(shown)


## 找出目录里放着的、Godot 播不了的视频源文件（多半是还没转码的 mp4）。
func _find_unplayable_source() -> String:
	for file_name: String in _video_dir_files():
		if file_name.get_extension().to_lower() in ["mp4", "webm", "mov", "mkv", "avi", "m4v", "flv"]:
			return "%s/%s" % [VIDEO_DIR, file_name]
	return ""


## 生成一条可以直接复制去跑的 ffmpeg 转码命令（打印真实的操作系统路径）。
func _convert_hint(source_path: String) -> String:
	var target: String = ProjectSettings.globalize_path(VIDEO_PATH)
	var source: String = "你的视频.mp4"
	var lead: String = "Godot 4 只能播 Ogg Theora（.ogv），用 FFmpeg 转一次："
	if source_path == VIDEO_PATH:
		# 源文件就是目标文件（比如 mp4 被改名成了 sun_pet.ogv），
		# 直接转会自己覆盖自己，得先改回真实扩展名。
		source = ProjectSettings.globalize_path("%s/sun_pet_src.mp4" % VIDEO_PATH.get_base_dir())
		lead = "Godot 4 只能播 Ogg Theora（.ogv）。先把它改回真实扩展名（例如 sun_pet_src.mp4），再用 FFmpeg 转："
	elif not source_path.is_empty():
		source = ProjectSettings.globalize_path(source_path)
	return "%s\n%s  ffmpeg -i \"%s\" -vf \"fps=24,scale=460:-2\" -c:v libtheora -q:v 8 -an \"%s\"" % [
		lead, VIDEO_LOG_PREFIX, source, target,
	]


## 读文件头判断容器类型。返回空串表示看着是正常的 Ogg 文件。
func _diagnose_container(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "打不开这个文件（FileAccess 错误码 %d）" % FileAccess.get_open_error()
	var head: PackedByteArray = file.get_buffer(12)
	var byte_count: int = file.get_length()
	file.close()

	if byte_count <= 0:
		return "文件是空的（0 字节）"
	if head.size() < 12:
		return "文件只有 %d 字节，明显不完整" % byte_count
	if head.slice(0, 4).get_string_from_ascii() == "OggS":
		return ""

	# 常见的「扩展名改了但没真转码」的情况，逐个点名，省得让人猜。
	if head.slice(4, 8).get_string_from_ascii() == "ftyp":
		return "这其实是 MP4/MOV 容器，只是文件名改成了 .ogv"
	if head.slice(0, 4) == PackedByteArray([0x1A, 0x45, 0xDF, 0xA3]):
		return "这其实是 Matroska/WebM 容器，只是文件名改成了 .ogv"
	if head.slice(0, 4).get_string_from_ascii() == "RIFF":
		return "这其实是 AVI/WAV 容器，只是文件名改成了 .ogv"
	if head.slice(0, 3).get_string_from_ascii() == "FLV":
		return "这其实是 FLV 容器，只是文件名改成了 .ogv"
	return "文件头不是 Ogg（前 4 字节 = %s），不是合法的 .ogv" % head.slice(0, 4).hex_encode()


## 加载视频资源。正常走 ResourceLoader；文件在但资源系统还没登记它时，
## 直接构造 VideoStreamTheora 并指定 file，绕开文件系统扫描。
func _load_video_stream(path: String) -> VideoStream:
	if ResourceLoader.exists(path, "VideoStream"):
		# CACHE_MODE_REPLACE：换了素材但编辑器还缓存着旧资源时，强制重新读盘。
		var loaded: Resource = ResourceLoader.load(path, "VideoStream", ResourceLoader.CACHE_MODE_REPLACE)
		var stream: VideoStream = loaded as VideoStream
		if stream != null:
			return stream
		if loaded != null:
			push_warning("%s 加载出来是 %s，不是 VideoStream。" % [path, loaded.get_class()])

	if not FileAccess.file_exists(path):
		return null
	print_rich("[color=#ffcc66]%sResourceLoader 里查不到这个资源，改用 VideoStreamTheora.file 直接读盘。[/color]" % VIDEO_LOG_PREFIX)
	var manual: VideoStreamTheora = VideoStreamTheora.new()
	manual.file = path
	return manual


## 判定视频不可用：回落几何占位并打印原因与修复建议。
func _fail_video(reason: String, hint: String = "") -> void:
	_video_enabled = false
	_video_confirmed = false
	_video_probe_left = 0
	_pet_video.stop()
	_pet_video.stream = null
	_refresh_visual_swap()
	# 换装色块回到孙哥身上的原始位置。
	_equipped_mark.position = _mark_default_rect.position
	_equipped_mark.size = _mark_default_rect.size

	print_rich("[color=#ff8b6a]%s未启用动态立绘，已回落到几何占位。[/color]" % VIDEO_LOG_PREFIX)
	print_rich("[color=#ff8b6a]%s  原因：%s[/color]" % [VIDEO_LOG_PREFIX, reason])
	if not hint.is_empty():
		print_rich("[color=#ffcc66]%s  怎么修：%s[/color]" % [VIDEO_LOG_PREFIX, hint])
	push_warning("动态立绘未启用：%s" % reason)


## 占位图只在校验失败时亮起。编辑器 / 正常播放都保持 PlaceholderVisual 隐藏。
func _refresh_visual_swap() -> void:
	_placeholder_visual.visible = not _video_enabled
	_sync_video_display()


## 默认直接显示 VideoStreamPlayer（不要把 canvas_item 着色器挂在播放器上）。
## 打开色度键后：把 get_video_texture() 喂给 PetFrame，打开可见性并套上抠像材质。
func _sync_video_display() -> void:
	if not _video_enabled:
		_pet_video.visible = false
		_pet_frame.visible = false
		return
	if chroma_key_enabled:
		# 播放器继续解码，但完全透明，避免不透明矩形盖住抠完的帧。
		_pet_video.visible = true
		_pet_video.modulate = Color(1.0, 1.0, 1.0, 0.0)
		_pet_frame.visible = true
		_pet_frame.position = _pet_video.position
		_pet_frame.size = _pet_video.size
		_feed_pet_frame_texture()
		_apply_video_key()
	else:
		_pet_video.visible = true
		_pet_video.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_pet_frame.visible = false
		_pet_frame.texture = null


func _feed_pet_frame_texture() -> void:
	var video_tex: Texture2D = _pet_video.get_video_texture()
	if video_tex != null:
		_pet_frame.texture = video_tex


func _warn_if_stub_video(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var byte_count: int = file.get_length()
	file.close()
	if byte_count <= 0 or byte_count > STUB_VIDEO_MAX_BYTES:
		return
	print_rich("[color=#ffcc66]%s  当前播的是仓库自带的彩色测试片（%d 字节），不是孙哥正片。[/color]" % [
		VIDEO_LOG_PREFIX, byte_count,
	])
	print_rich("[color=#ffcc66]%s  把转好的 .ogv 覆盖到 %s 后再按 F5。[/color]" % [
		VIDEO_LOG_PREFIX, ProjectSettings.globalize_path(VIDEO_PATH),
	])
	_show_toast("占位测试片：请覆盖 sun_pet.ogv", Color(1.0, 0.85, 0.35))


## 每帧轮询：拿到第一帧就算确认可播（顺便按宽高比摆好）；
## 宽限帧数用完还是没有画面，就判定素材有问题并回落。
func _tick_video_probe() -> void:
	if _fit_video_rect():
		_video_fitted = true
		if not _video_confirmed:
			_video_confirmed = true
			_refresh_visual_swap()
		var source: Vector2 = _pet_video.get_video_texture().get_size()
		print_rich("[color=#54d18c]%s  画面已就绪：源 %d×%d，按比例摆放为 %d×%d[/color]" % [
			VIDEO_LOG_PREFIX, int(source.x), int(source.y),
			int(_pet_video.size.x), int(_pet_video.size.y),
		])
		return

	_video_probe_left -= 1
	if _video_probe_left > 0:
		return

	if _video_confirmed:
		# 时长正常、只是拿不到贴图（例如 --headless 无渲染），别再每帧空转，
		# 直接沿用场景里的默认矩形。
		_video_fitted = true
		return

	_fail_video("视频能加载，但连续 %d 帧解不出任何画面（文件损坏，或者 Ogg 容器里根本没有 Theora 视频轨）。" % VIDEO_PROBE_FRAMES,
		_convert_hint(_pet_video.stream.resource_path if _pet_video.stream != null else ""))


## 按视频自身宽高比在 VIDEO_AREA 里居中内接，避免 expand 拉伸变形。
## 返回 false 表示第一帧还没解出来，下一帧继续试。
func _fit_video_rect() -> bool:
	var texture: Texture2D = _pet_video.get_video_texture()
	if texture == null:
		return false
	var source: Vector2 = texture.get_size()
	if source.x <= 0.0 or source.y <= 0.0:
		return false

	var ratio: float = minf(VIDEO_AREA.size.x / source.x, VIDEO_AREA.size.y / source.y)
	var fitted: Vector2 = source * ratio
	_pet_video.position = VIDEO_AREA.position + (VIDEO_AREA.size - fitted) * 0.5
	_pet_video.size = fitted

	# 视频模式下换装色块改成贴在立绘底部的一条品质色标记。
	_equipped_mark.size = Vector2(minf(fitted.x * 0.36, 60.0), 10.0)
	_equipped_mark.position = Vector2(
		_pet_video.position.x + (fitted.x - _equipped_mark.size.x) * 0.5,
		_pet_video.position.y + fitted.y - _equipped_mark.size.y - 2.0
	)
	_sync_video_display()
	return true


## 跑路时隐藏并暂停视频（停止解码省 CPU），冷却结束后原地续播。
func _set_video_playing(playing: bool) -> void:
	if not _video_enabled:
		return
	if playing:
		if not _pet_video.is_playing():
			_pet_video.play()
		_pet_video.paused = false
		_sync_video_display()
	else:
		_pet_video.paused = true
		_pet_video.visible = false
		_pet_frame.visible = false


func _apply_video_key() -> void:
	# 变量别叫 material：那是 CanvasItem 的属性名，会被判成遮蔽。
	# 着色器只挂在 PetFrame（TextureRect）上。
	var key_material: ShaderMaterial = _pet_frame.material as ShaderMaterial
	if key_material == null:
		print_verbose("%s chroma key material missing on PetFrame" % VIDEO_LOG_PREFIX)
		return
	key_material.set_shader_parameter("key_color",
		Vector3(chroma_key_color.r, chroma_key_color.g, chroma_key_color.b))
	key_material.set_shader_parameter("similarity", chroma_key_similarity)
	key_material.set_shader_parameter("smoothness", maxf(chroma_key_smoothness, 0.001))


func _log_chroma_key_state() -> void:
	if chroma_key_enabled:
		print_verbose("%s chroma key ON  color=#%s  similarity=%.2f  smoothness=%.2f  frame_visible=%s" % [
			VIDEO_LOG_PREFIX,
			chroma_key_color.to_html(false),
			chroma_key_similarity,
			chroma_key_smoothness,
			_pet_frame.visible if is_instance_valid(_pet_frame) else false,
		])
		print_rich("[color=#54d18c]%s色度键已开启：抠 #%s（similarity=%.2f smoothness=%.2f），PetFrame 显示抠完的帧[/color]" % [
			VIDEO_LOG_PREFIX,
			chroma_key_color.to_html(false),
			chroma_key_similarity,
			chroma_key_smoothness,
		])
	else:
		print_verbose("%s chroma key OFF — showing VideoStreamPlayer directly" % VIDEO_LOG_PREFIX)
		print_rich("[color=#9aa3b2]%s色度键关闭：直接显示 VideoStreamPlayer，背景不透明[/color]" % VIDEO_LOG_PREFIX)


## 运行时开关色度键。enabled 为 true 时把视频帧喂给 PetFrame 并套上着色器。
func set_chroma_key_enabled(enabled: bool) -> void:
	chroma_key_enabled = enabled


## 一次设好要抠的颜色和边缘参数，并打开色度键。
func apply_chroma_key(color: Color, similarity: float = 0.35, smoothness: float = 0.10) -> void:
	chroma_key_color = color
	chroma_key_similarity = similarity
	chroma_key_smoothness = smoothness
	chroma_key_enabled = true


# =========================================================================
# Day 3：中文悬浮 UI
# =========================================================================

## 带 GameData 数值的静态文案，统一在这里生成，避免场景里写死数字。
func _apply_static_ui_text() -> void:
	_paid_button.text = "付费加速 %d币" % GameData.PAID_SPEEDUP_COST
	_paid_button.tooltip_text = "花 %d 金币，立刻洗完当前这一条" % GameData.PAID_SPEEDUP_COST
	_free_button.tooltip_text = "立刻少洗 %d 秒，但有 %d%% 概率让孙哥跑路" % [
		int(GameData.FREE_SPEEDUP_SECONDS),
		int(GameData.FREE_SPEEDUP_RUNAWAY_CHANCE * 100.0),
	]
	_wash_bar.max_value = GameData.WASH_DURATION


func _connect_ui() -> void:
	_free_button.pressed.connect(_on_free_speedup_pressed)
	_paid_button.pressed.connect(_on_paid_speedup_pressed)
	_codex_open_button.pressed.connect(func() -> void: _set_codex_visible(not _codex_panel.visible))
	_codex_close_button.pressed.connect(func() -> void: _set_codex_visible(false))
	_quit_button.pressed.connect(func() -> void: get_tree().quit())
	_unequip_button.pressed.connect(func() -> void:
		if GameData.equipped_quality < 0:
			return
		GameData.equip_quality(-1)
		_show_toast("已脱下内裤")
	)


func _on_free_speedup_pressed() -> void:
	if _state != State.WASHING:
		return
	if trigger_free_speedup():
		_show_toast("加速成功 -%ds" % int(GameData.FREE_SPEEDUP_SECONDS), Color(0.6, 1.0, 0.7))
	else:
		_show_toast("孙哥跑路了！", Color(1.0, 0.45, 0.35))


func _on_paid_speedup_pressed() -> void:
	if _state != State.WASHING:
		return
	if GameData.coins < GameData.PAID_SPEEDUP_COST:
		_show_toast("金币不足，需要 %d 金币" % GameData.PAID_SPEEDUP_COST, Color(1.0, 0.6, 0.4))
		return
	if trigger_paid_speedup():
		_show_toast("付费加速，立刻洗完！", Color(1.0, 0.85, 0.35))


## 按 GameData.Quality 动态生成图鉴行，避免在场景里写死品质数量。
func _build_codex_rows() -> void:
	for quality: int in GameData.Quality.values():
		var q: int = quality
		var color: Color = GameData.QUALITY_COLORS.get(q, Color.WHITE)

		var row: HBoxContainer = HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 4)

		var name_label: Label = Label.new()
		name_label.text = "● %s" % String(GameData.QUALITY_NAMES_CN[q])
		name_label.custom_minimum_size = Vector2(CODEX_NAME_WIDTH, 0)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.theme_type_variation = &"SmallLabel"
		name_label.add_theme_color_override("font_color", color)
		row.add_child(name_label)

		var count_label: Label = Label.new()
		count_label.theme_type_variation = &"SmallLabel"
		count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(count_label)

		var equip_button: Button = Button.new()
		equip_button.theme_type_variation = &"EquipButton"
		equip_button.custom_minimum_size = Vector2(CODEX_BUTTON_WIDTH, 0)
		equip_button.pressed.connect(func() -> void: _on_equip_pressed(q))
		row.add_child(equip_button)

		_codex_list.add_child(row)
		_codex_rows[q] = {"count": count_label, "button": equip_button}


func _on_equip_pressed(quality: int) -> void:
	if not GameData.has_collected(quality):
		_show_toast("还没解锁%s内裤" % _quality_tag(quality), Color(1.0, 0.6, 0.4))
		return
	if GameData.equip_quality(quality):
		_show_toast("换上了%s内裤" % _quality_tag(quality), GameData.QUALITY_COLORS.get(quality, Color.WHITE))


func _set_codex_visible(shown: bool) -> void:
	_codex_panel.visible = shown
	if shown:
		_refresh_codex()


func _refresh_all() -> void:
	_update_coin_label(GameData.coins)
	_update_warehouse_label()
	_update_equipped_label()
	_update_equipped_mark(GameData.equipped_quality)
	_update_status_text()
	_update_wash_bar()
	_refresh_buttons()
	_refresh_codex()


func _update_coin_label(coins: int) -> void:
	_coin_label.text = "金币: %d" % coins


func _update_warehouse_label() -> void:
	_warehouse_label.text = "未晾干: %d/%d" % [
		GameData.wet_warehouse.size(),
		GameData.WAREHOUSE_CAPACITY,
	]


func _update_equipped_label() -> void:
	var equipped: String = "未穿戴"
	if GameData.equipped_quality >= 0:
		equipped = "已穿 %s" % String(GameData.QUALITY_NAMES_CN[GameData.equipped_quality])
	_equipped_label.text = "图鉴 %d · %s" % [GameData.dry_collection.size(), equipped]


## 换装的占位表现：在孙哥身上显示一块对应品质颜色的补丁（Day 4 换真实立绘）。
func _update_equipped_mark(quality: int) -> void:
	_equipped_mark.visible = quality >= 0
	if quality >= 0:
		_equipped_mark.color = GameData.QUALITY_COLORS.get(quality, Color.WHITE)


func _update_status_text() -> void:
	var text: String = ""
	match _state:
		State.WASHING:
			text = "正在洗涤 %ds" % int(ceil(_wash_remaining))
		State.PAUSED_FULL:
			text = "已暂停 - 仓库已满"
		State.RUNAWAY:
			text = "孙哥跑路中 CD: %ds" % int(ceil(_cooldown_remaining))
	if _status_label.text != text:
		_status_label.text = text
	if _runaway_label.text != text and _state == State.RUNAWAY:
		_runaway_label.text = text


func _update_wash_bar() -> void:
	# 跑路时进度条改显示冷却进度，其余时候显示当前这条洗到哪了。
	if _state == State.RUNAWAY:
		return
	_wash_bar.value = clampf(GameData.WASH_DURATION - _wash_remaining, 0.0, GameData.WASH_DURATION)


func _refresh_buttons() -> void:
	var washing: bool = _state == State.WASHING
	_free_button.disabled = not washing
	_paid_button.disabled = not washing or GameData.coins < GameData.PAID_SPEEDUP_COST


func _refresh_codex() -> void:
	for quality: int in _codex_rows:
		var row: Dictionary = _codex_rows[quality]
		var count_label: Label = row["count"]
		var equip_button: Button = row["button"]
		var collected: int = GameData.count_collected(quality)
		var total: int = int(GameData.codex_counts.get(quality, 0))
		count_label.text = "收藏 %d · 累计 %d" % [collected, total]

		if collected <= 0:
			equip_button.text = "未解锁"
			equip_button.disabled = true
		elif GameData.equipped_quality == quality:
			equip_button.text = "已穿戴"
			equip_button.disabled = true
		else:
			equip_button.text = "穿戴"
			equip_button.disabled = false

	_unequip_button.disabled = GameData.equipped_quality < 0
	_codex_cd_label.text = "当前跑路冷却: %ds（减免 %d%%）" % [
		int(round(GameData.get_calculated_cooldown())),
		int(round(GameData.get_cd_reduction() * 100.0)),
	]


func _quality_tag(quality: int) -> String:
	return "【%s】" % String(GameData.QUALITY_NAMES_CN.get(quality, "未知"))


## 底部飘字提示：停留一会儿后淡出。
func _show_toast(message: String, color: Color = Color(1, 1, 1)) -> void:
	if not _toast_label.visible:
		return
	if is_instance_valid(_toast_tween):
		_toast_tween.kill()
	_toast_label.text = message
	_toast_label.modulate = Color(color.r, color.g, color.b, 1.0)
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_HOLD)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, TOAST_FADE)


func _log(message: String) -> void:
	if _debug_log:
		print("[SunPet] ", message)


func _flash_quality(quality: int) -> void:
	# 跑路期间晾干仍在继续，但不能在「已隐藏」的窗口上闪光。
	if not _pet_visual.visible:
		return
	var color: Color = GameData.QUALITY_COLORS.get(quality, Color.WHITE)
	_quality_flash.color = Color(color.r, color.g, color.b, 0.55)
	_quality_flash.visible = true
	var tween: Tween = create_tween()
	tween.tween_property(_quality_flash, "color:a", 0.0, 0.6)
	tween.finished.connect(func() -> void:
		_quality_flash.visible = false
	)
