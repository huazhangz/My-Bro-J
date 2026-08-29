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

## 视频抠像模式。Ogg Theora **不带 Alpha 通道**，视频会画成一块不透明矩形，
## 想保住桌宠的透明背景就得靠抠像。具体实现见 assets/videos/video_key.gdshader。
enum VideoKeyMode {
	OFF,     # 不抠像，视频原样显示（背景不透明）
	CHROMA,  # 色度键：抠掉接近 video_key_color 的像素（绿幕 / 纯色背景）
	DARK,    # 抠掉暗于阈值的像素（黑底视频）
	BRIGHT,  # 抠掉亮于阈值的像素（白底视频）
}

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

@export_group("视频立绘")
## 抠像模式，用来还原透明背景（Theora 没有 Alpha 通道）。
@export var video_key_mode: VideoKeyMode = VideoKeyMode.OFF
## CHROMA 模式要抠掉的背景色。
@export var video_key_color: Color = Color(0.0, 1.0, 0.0)
## 抠像阈值：CHROMA 是与背景色的色差，DARK / BRIGHT 是亮度分界。
@export_range(0.0, 1.0, 0.01) var video_key_threshold: float = 0.28
## 抠像边缘羽化宽度，太小会有锯齿，太大会把主体啃掉。
@export_range(0.001, 1.0, 0.01) var video_key_softness: float = 0.12

@onready var _pet_visual: Control = %PetVisual
@onready var _pet_video: VideoStreamPlayer = %PetVideo
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
	var usable: Rect2i = DisplayServer.screen_get_usable_rect()
	var size: Vector2i = DisplayServer.window_get_size()
	var target: Vector2i = Vector2i(
		usable.position.x + usable.size.x - size.x - 80,
		usable.position.y + usable.size.y - size.y - 80
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
	var size: Vector2i = DisplayServer.window_get_size()
	var min_x: int = usable.position.x - size.x + SCREEN_MARGIN
	var max_x: int = usable.position.x + usable.size.x - SCREEN_MARGIN
	var min_y: int = usable.position.y - size.y + SCREEN_MARGIN
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

	# 视频宽高只有解出第一帧后才拿得到，成功摆好一次就不再重算。
	if _video_enabled and not _video_fitted:
		_video_fitted = _fit_video_rect()

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
func _set_pet_hidden(hidden: bool) -> void:
	_pet_visual.visible = not hidden
	_set_video_playing(not hidden)
	_hud_panel.visible = not hidden
	_button_bar.visible = not hidden
	_toast_label.visible = not hidden
	_quality_flash.visible = false
	_runaway_banner.visible = hidden
	# WINDOW_FLAG_MOUSE_PASSTHROUGH 为 true 时整窗鼠标事件全部穿透，无需设置多边形。
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH, hidden)


# =========================================================================
# Day 4：动态立绘（VideoStreamPlayer）
# =========================================================================

## 找得到 .ogv 就用视频立绘，找不到就回落到几何占位，保证缺资源时项目照样能跑。
func _setup_pet_video() -> void:
	_mark_default_rect = Rect2(_equipped_mark.position, _equipped_mark.size)
	_apply_video_key()

	# 场景里手动指定过 stream 就直接用，否则按约定路径去找。
	if _pet_video.stream == null:
		var path: String = _find_video_path()
		if path.is_empty():
			_use_video_visual(false)
			push_warning("未找到动态立绘视频，已回落到几何占位。把 Ogg Theora（.ogv）放到 %s 即可启用，转换命令见 assets/videos/README.md。" % VIDEO_PATH)
			return
		_pet_video.stream = load(path)

	if _pet_video.stream == null:
		_use_video_visual(false)
		return

	_use_video_visual(true)
	# loop = true 已在场景里设好；这里再兜一层，防止某些流跑到结尾直接停住。
	_pet_video.finished.connect(func() -> void:
		if _video_enabled and not _pet_video.is_playing():
			_pet_video.play()
	)
	_pet_video.play()
	_log("video visual: %s" % _pet_video.stream.resource_path)


## 优先用约定文件名，其次取目录下第一个 .ogv，方便直接把文件拖进来而不用改代码。
func _find_video_path() -> String:
	if ResourceLoader.exists(VIDEO_PATH):
		return VIDEO_PATH
	var dir: DirAccess = DirAccess.open(VIDEO_DIR)
	if dir == null:
		return ""
	for file_name: String in dir.get_files():
		# 导出后资源会带 .remap 后缀，去掉再判断扩展名。
		var clean: String = file_name.trim_suffix(".remap")
		if clean.get_extension().to_lower() == "ogv":
			return "%s/%s" % [VIDEO_DIR, clean]
	return ""


func _use_video_visual(enabled: bool) -> void:
	_video_enabled = enabled
	_pet_video.visible = enabled
	_placeholder_visual.visible = not enabled
	if not enabled:
		# 回落到几何占位：换装色块回到孙哥身上的原始位置。
		_pet_video.stop()
		_equipped_mark.position = _mark_default_rect.position
		_equipped_mark.size = _mark_default_rect.size


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
	return true


## 跑路时隐藏并暂停视频（停止解码省 CPU），冷却结束后原地续播。
func _set_video_playing(playing: bool) -> void:
	if not _video_enabled:
		return
	_pet_video.visible = playing
	if playing:
		if not _pet_video.is_playing():
			_pet_video.play()
		_pet_video.paused = false
	else:
		_pet_video.paused = true


func _apply_video_key() -> void:
	var material: ShaderMaterial = _pet_video.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("key_mode", int(video_key_mode))
	material.set_shader_parameter("key_color",
		Vector3(video_key_color.r, video_key_color.g, video_key_color.b))
	material.set_shader_parameter("key_threshold", video_key_threshold)
	material.set_shader_parameter("key_softness", maxf(video_key_softness, 0.001))


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
