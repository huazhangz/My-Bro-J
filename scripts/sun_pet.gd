extends Control

## 孙哥桌宠主脚本
##
## 职责：
##   1. 透明无边框窗口的初始化与「全局鼠标坐标」拖拽（Day 1）
##   2. 洗涤 / 晾干 / 仓库满暂停 / 跑路冷却 的核心状态机（Day 2）
##   3. 悬浮中文 UI：代币 / 状态倒计时 / 仓库挂起 / 加速按钮 / 图鉴换装（Day 3）
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
## 飘字提示的停留与淡出时长（纯表现，不影响玩法数值）。
const TOAST_HOLD: float = 1.1
const TOAST_FADE: float = 0.5
## 图鉴一行里品质名 / 穿戴按钮的最小宽度。
const CODEX_NAME_WIDTH: int = 54
const CODEX_BUTTON_WIDTH: int = 56

@onready var _pet_visual: Control = %PetVisual
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


func _ready() -> void:
	_debug_log = OS.get_cmdline_user_args().has("--petlog")
	_apply_window_setup()
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
	_hud_panel.visible = not hide_pet
	_button_bar.visible = not hide_pet
	_toast_label.visible = not hide_pet
	_quality_flash.visible = false
	_runaway_banner.visible = hide_pet
	# WINDOW_FLAG_MOUSE_PASSTHROUGH 为 true 时整窗鼠标事件全部穿透，无需设置多边形。
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH, hide_pet)


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
