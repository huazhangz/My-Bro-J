extends Control

## 孙哥桌宠主脚本
##
## 职责：
##   1. 透明无边框窗口的初始化与「全局鼠标坐标」拖拽（Day 1）
##   2. 洗涤 / 晾干 / 仓库满暂停 / 跑路冷却 的核心状态机（Day 2）
##
## 窗口移动一律走 DisplayServer，不用 Window.position，
## 否则在编辑器内嵌运行时会报 "Embedded windows can't be moved"。

enum State {
	WASHING,     # 正在洗涤
	PAUSED_FULL, # 仓库已满，暂停洗涤
	RUNAWAY,     # 孙哥跑路中，窗口隐藏 + 冷却倒计时
}

const DRAG_BUTTON: int = MOUSE_BUTTON_LEFT
## 拖拽时窗口至少要留在屏幕内的边距。
const SCREEN_MARGIN: int = 24

@onready var _pet_visual: Control = %PetVisual
@onready var _status_label: Label = %StatusLabel
@onready var _quality_flash: ColorRect = %QualityFlash

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


func _ready() -> void:
	_debug_log = OS.get_cmdline_user_args().has("--petlog")
	_apply_window_setup()
	_connect_game_data()
	_start_wash_cycle()
	_refresh_status()


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
	# 只在桌宠自身区域内按下才开始拖拽。
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
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			# 无边框窗口没有关闭按钮，右键退出（Day 3 会换成正式菜单）。
			get_tree().quit()
	elif event is InputEventKey:
		var key: InputEventKey = event
		if not key.pressed:
			return
		match key.keycode:
			KEY_ESCAPE:
				get_tree().quit()
			KEY_SPACE:
				# 调试用：手动触发一次免费加速（带跑路概率）。
				trigger_free_speedup()


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
		_refresh_status()
	)
	GameData.item_dried.connect(func(item: Dictionary) -> void:
		_flash_quality(int(item["quality"]))
		_log("dried #%d %s -> collection=%d coins=%d" % [
			int(item["id"]),
			String(GameData.QUALITY_NAMES[int(item["quality"])]),
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

	_refresh_status()


func _start_wash_cycle() -> void:
	if GameData.is_warehouse_full():
		_state = State.PAUSED_FULL
		_log("warehouse full (%d) -> wash paused" % GameData.wet_warehouse.size())
		return
	_wash_remaining = GameData.WASH_DURATION
	_state = State.WASHING


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
		return

	_start_dry_timer(int(item["id"]))
	_flash_quality(int(item["quality"]))
	_log("washed #%d %s -> wet=%d/%d" % [
		int(item["id"]),
		String(GameData.QUALITY_NAMES[int(item["quality"])]),
		GameData.wet_warehouse.size(),
		GameData.WAREHOUSE_CAPACITY,
	])
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


## 付费加速：消耗代币，无跑路风险。
func trigger_paid_speedup() -> bool:
	if _state != State.WASHING:
		return false
	if not GameData.try_spend_coins(GameData.PAID_SPEEDUP_COST):
		return false
	_wash_remaining = maxf(_wash_remaining - GameData.PAID_SPEEDUP_SECONDS, 0.0)
	return true


## 孙哥跑路：隐藏桌宠 + 按品质缩减后的冷却时间倒计时。
func _trigger_runaway() -> void:
	_state = State.RUNAWAY
	_cooldown_remaining = GameData.get_calculated_cooldown()
	_dragging = false
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
	_start_wash_cycle()


## 跑路期间「隐藏窗口」：藏掉全部可见内容，并开启鼠标穿透，
## 使窗口在视觉与交互上都等于消失（不用 minimize，避免抢占任务栏焦点）。
func _set_pet_hidden(hidden: bool) -> void:
	_pet_visual.visible = not hidden
	_status_label.visible = not hidden
	_quality_flash.visible = false
	# WINDOW_FLAG_MOUSE_PASSTHROUGH 为 true 时整窗鼠标事件全部穿透，无需设置多边形。
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH, hidden)


# =========================================================================
# 展示（Day 3 会换成正式 UI，这里先给可读的调试文本）
# =========================================================================

func _refresh_status() -> void:
	if not _status_label.visible:
		return
	var lines: PackedStringArray = PackedStringArray()
	match _state:
		State.WASHING:
			lines.append("WASHING %.1fs" % _wash_remaining)
		State.PAUSED_FULL:
			lines.append("FULL - PAUSED")
		State.RUNAWAY:
			lines.append("RUNAWAY %.1fs" % _cooldown_remaining)
	lines.append("Wet %d/%d" % [GameData.wet_warehouse.size(), GameData.WAREHOUSE_CAPACITY])
	lines.append("Dry %d  Coin %d" % [GameData.dry_collection.size(), GameData.coins])
	_status_label.text = "\n".join(lines)


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
