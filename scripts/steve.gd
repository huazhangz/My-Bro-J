extends Control

## Steve 桌宠主脚本
##
## 默认只显示角色立绘。左键拖拽窗口，右键打开烘干机 / 抽屉 / 退出菜单。
## 窗口移动一律走 DisplayServer，不用 Window.position。

enum State {
	WASHING,
	PAUSED_FULL,
	RUNAWAY,
}

const DRAG_BUTTON: int = MOUSE_BUTTON_LEFT
const SCREEN_MARGIN: int = 24

const VIDEO_DIR: String = "res://assets/videos"
const VIDEO_PATH: String = "res://assets/videos/steve.ogv"
const USER_CACHE_OGV: String = "user://steve.ogv"
## 无 HUD 后立绘铺满窗口，按宽高比居中内接。
## 包围盒默认来自 GameData.PET_AREA；进树时改用场景里已微调的 PetVideo 矩形。
const HOVER_HUD_HEIGHT: float = 40.0
const HOVER_BAR_HEIGHT: float = 12.0
const HOVER_GAP: float = 6.0
const VIDEO_PROBE_FRAMES: int = 45
const VIDEO_LOG_PREFIX: String = "[Steve/Video] "
const CHROMA_SHADER_PATH: String = "res://assets/shaders/chroma_key.gdshader"

@export_group("视频立绘 / 色度键")
@export var chroma_key_enabled: bool = true:
	set(value):
		chroma_key_enabled = value
		if is_node_ready():
			_apply_video_key()
			_sync_video_display()
			_log_chroma_key_state()
@export var chroma_key_color: Color = Color(0.0, 1.0, 0.0):
	set(value):
		chroma_key_color = value
		if is_node_ready():
			_apply_video_key()
@export_range(0.0, 1.0, 0.01) var chroma_key_similarity: float = 0.81:
	set(value):
		chroma_key_similarity = value
		if is_node_ready():
			_apply_video_key()
@export_range(0.0, 1.0, 0.01) var chroma_key_smoothness: float = 0.15:
	set(value):
		chroma_key_smoothness = value
		if is_node_ready():
			_apply_video_key()
@export_range(0.0, 1.0, 0.01) var chroma_spill_suppression: float = 0.30:
	set(value):
		chroma_spill_suppression = value
		if is_node_ready():
			_apply_video_key()

@onready var _pet_visual: Control = %PetVisual
## 不用 `%PetVideo` 的 @onready：节点缺失时 Godot 会在进树时直接报错并留下 null。
var _pet_video: VideoStreamPlayer
@onready var _pet_frame: TextureRect = %PetFrame
@onready var _placeholder_visual: Control = %PlaceholderVisual
@onready var _exit_popup: PanelContainer = %ExitPopup
@onready var _dryer_icon: TextureRect = %DryerIcon
@onready var _drawer_icon: TextureRect = %DrawerIcon
@onready var _dryer_icon_clip: Control = %DryerIconClip
@onready var _drawer_icon_clip: Control = %DrawerIconClip
@onready var _dryer_slot: Button = %DryerSlot
@onready var _drawer_slot: Button = %DrawerSlot
@onready var _size_small_button: Button = %SizeSmallButton
@onready var _size_medium_button: Button = %SizeMediumButton
@onready var _size_large_button: Button = %SizeLargeButton
@onready var _size_huge_button: Button = %SizeHugeButton
@onready var _pressure_button: Button = %PressureWashButton
@onready var _pin_top_button: Button = %PinTopButton
@onready var _quit_app_button: Button = %QuitAppButton
@onready var _menu_close_button: Button = %MenuCloseButton
@onready var _settings_button: Button = %SettingsButton
@onready var _settings_panel: Control = %SettingsPanel
@onready var _bubble_affinity: Label = %BubbleAffinity
@onready var _bubble_underwear: Label = %BubbleUnderwear
@onready var _bubble_companion: Label = %BubbleCompanion
@onready var _bubble_runaway: Label = %BubbleRunaway
@onready var _inventory_chrome: Panel = %InventoryChrome
@onready var _inventory_mask: Panel = %InventoryMask
@onready var _basin_frame: TextureRect = %BasinFrame
@onready var _runaway_banner: PanelContainer = %RunawayBanner
@onready var _inventory_popup: Control = %InventoryPopup
@onready var _inventory_headline: PanelContainer = %InventoryHeadline
@onready var _inventory_title: Label = %InventoryTitle
@onready var _inventory_close_button: Button = %InventoryCloseButton
@onready var _inventory_grid: GridContainer = %InventoryGrid
@onready var _inventory_empty: Label = %InventoryEmpty
@onready var _inventory_bg: TextureRect = %InventoryBg
@onready var _hover_hud: Control = %HoverHud
@onready var _water_bar: ProgressBar = %WaterBar
@onready var _wash_label: Label = %WashLabel

var _state: int = State.WASHING
var _wash_remaining: float = 0.0
var _cooldown_remaining: float = 0.0

var _dragging: bool = false
var _drag_offset: Vector2i = Vector2i.ZERO
var _embedded: bool = false
var _debug_log: bool = false

var _dry_timers: Dictionary = {}

var _video_enabled: bool = false
var _video_confirmed: bool = false
var _video_probe_left: int = 0
var _video_fitted: bool = false
var _inventory_kind: String = ""
var _overlay_window_open: bool = false
var _base_window_size: Vector2i = Vector2i.ZERO
var _base_window_pos: Vector2i = Vector2i.ZERO
var _hover_time: float = 0.0
var _hover_hud_shown: bool = false
var _hover_tween: Tween
var _always_on_top: bool = true
var _dryer_texture: Texture2D
var _drawer_texture: Texture2D
var _drawer_icon_texture: Texture2D
var _container_texture: Texture2D
var _layout_area: Rect2 = GameData.PET_AREA
var _pressure_cd: float = 0.0
var _pressure_cd_text: String = ""


func _ready() -> void:
	get_tree().root.gui_embed_subwindows = false
	_debug_log = OS.get_cmdline_user_args().has("--petlog")
	print("%s build=qualities-wear-dryer-drawer  scene=%s  menu=4x icons+stats" % [
		VIDEO_LOG_PREFIX, scene_file_path,
	])
	_ensure_pet_video_node()
	_capture_layout_area()
	_always_on_top = GameData.always_on_top_pref
	_apply_mouse_filters()
	_apply_ui_font()
	_apply_window_setup()
	_apply_pet_size()
	_ingest_user_images()
	_apply_round_chrome()
	_apply_video_key()
	_apply_menu_icons()
	_connect_exit_popup()
	_refresh_pressure_button()
	_refresh_stat_bubbles()
	_setup_pet_video()
	_connect_game_data()
	_resume_saved_dry_timers()
	_start_wash_cycle()
	get_tree().auto_accept_quit = false


func _is_embedded_in_editor() -> bool:
	var win: Window = get_window()
	if win.is_embedded():
		return true
	var args: PackedStringArray = OS.get_cmdline_args()
	if args.has("--wid") or args.has("--embed"):
		return true
	for arg: String in args:
		if arg.begins_with("--wid="):
			return true
	return false


func _can_move_window() -> bool:
	return not _embedded and not get_window().is_embedded()


func _apply_mouse_filters() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var ignore_nodes: Array[Control] = [
		_pet_visual, _pet_video, _pet_frame, _placeholder_visual,
		_inventory_bg, _inventory_title, _inventory_empty,
		_inventory_chrome, _inventory_mask,
		_hover_hud, _water_bar, _wash_label,
	]
	for node: Control in ignore_nodes:
		if is_instance_valid(node):
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in _placeholder_visual.get_children():
		var as_control: Control = child as Control
		if as_control != null:
			as_control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _apply_window_setup() -> void:
	get_tree().root.gui_embed_subwindows = false
	var win: Window = get_window()
	win.transparent_bg = true
	_embedded = _is_embedded_in_editor()

	## 内嵌时调用置顶/移动会刷 Embedded window 警告，且 DisplayServer 无效。
	if not _can_move_window():
		_embedded = true
		push_warning("窗口被编辑器内嵌运行，无法置顶/拖拽。请在 Game 面板确认 Embed Game on Play 为关闭，然后 F5。")
		print("%s embedded=true cmdline=%s" % [VIDEO_LOG_PREFIX, OS.get_cmdline_args()])
		return

	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true, 0)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, _always_on_top, 0)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true, 0)

	var usable: Rect2i = DisplayServer.screen_get_usable_rect()
	var window_size: Vector2i = DisplayServer.window_get_size()
	var target: Vector2i = Vector2i(
		usable.position.x + usable.size.x - window_size.x - 80,
		usable.position.y + usable.size.y - window_size.y - 80
	)
	DisplayServer.window_set_position(target)


func _ingest_user_images() -> void:
	_dryer_texture = GameData.load_image_texture(GameData.USER_DRYER_FILE)
	if _dryer_texture == null and is_instance_valid(_inventory_bg):
		_dryer_texture = _inventory_bg.texture
	_drawer_texture = GameData.load_image_texture(GameData.USER_DRAWER_FILE)
	var drawer_icon_path: String = GameData.first_existing_file(GameData.USER_DRAWER_ICON_FILE)
	if not drawer_icon_path.is_empty() and not drawer_icon_path.begins_with("res://assets/images/"):
		GameData.copy_file(drawer_icon_path, GameData.RES_DRAWER_ICON_PATH)
	_drawer_icon_texture = GameData.load_image_texture(GameData.USER_DRAWER_ICON_FILE)
	if _drawer_icon_texture == null:
		_drawer_icon_texture = _drawer_texture
	if _dryer_texture != null:
		print("%s dryer bg <- %s" % [VIDEO_LOG_PREFIX, GameData.first_existing_file(GameData.USER_DRYER_FILE)])
	if _drawer_texture != null:
		print("%s drawer bg <- %s" % [VIDEO_LOG_PREFIX, GameData.first_existing_file(GameData.USER_DRAWER_FILE)])
	if _drawer_icon_texture != null:
		print("%s drawer icon <- %s" % [VIDEO_LOG_PREFIX, drawer_icon_path])
	var container_path: String = GameData.first_existing_file(GameData.USER_CONTAINER_FILE)
	if not container_path.is_empty() and not container_path.begins_with("res://assets/images/"):
		GameData.copy_file(container_path, "res://assets/images/container.jpg")
	_container_texture = GameData.load_image_texture(GameData.USER_CONTAINER_FILE)
	if _container_texture != null and is_instance_valid(_basin_frame):
		_basin_frame.texture = _container_texture
		print("%s basin <- %s" % [VIDEO_LOG_PREFIX, container_path])
	var steve2_path: String = GameData.first_existing_file(GameData.USER_STEVE2_FILE)
	if not steve2_path.is_empty():
		print("%s Steve2.jpg found: %s" % [VIDEO_LOG_PREFIX, steve2_path])


func _apply_ui_font() -> void:
	var path: String = GameData.first_existing_named(GameData.USER_UI_FONT_ALIASES)
	if path.is_empty():
		print("%s UI font missing: %s" % [VIDEO_LOG_PREFIX, GameData.RES_UI_FONT_PATH])
		return
	if path.get_extension().to_lower() == "zip":
		var extracted: String = GameData.extract_font_from_zip(path, GameData.RES_UI_FONT_PATH)
		if extracted.is_empty():
			print("%s failed to unpack %s" % [VIDEO_LOG_PREFIX, path])
			return
		print("%s unpacked %s -> %s" % [VIDEO_LOG_PREFIX, path, extracted])
		path = extracted
	elif path != GameData.RES_UI_FONT_PATH and GameData.copy_file(path, GameData.RES_UI_FONT_PATH):
		path = GameData.RES_UI_FONT_PATH
	var font: FontFile = null
	if path.begins_with("res://") and ResourceLoader.exists(path, "FontFile"):
		font = ResourceLoader.load(path, "FontFile") as FontFile
	if font == null:
		font = FontFile.new()
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		if bytes.is_empty():
			return
		font.data = bytes
	var next_theme: Theme = theme.duplicate() if theme != null else Theme.new()
	next_theme.default_font = font
	next_theme.default_font_size = GameData.UI_FONT_SIZE
	_unify_theme_text(next_theme, font)
	theme = next_theme
	_unify_control_text(self, font)
	_apply_menu_text_style(font)
	print("%s UI font <- %s size=%d" % [VIDEO_LOG_PREFIX, path, GameData.UI_FONT_SIZE])


func _unify_theme_text(target: Theme, font: FontFile) -> void:
	var types: PackedStringArray = [
		"Label",
		"Button",
		"ProgressBar",
		"TitleLabel",
		"SmallLabel",
		"CoinLabel",
		"FloatLabel",
		"TooltipLabel",
		"CloseButton",
		"CodexButton",
		"CoinButton",
		"EquipButton",
		"RiskButton",
	]
	var white: Color = GameData.UI_FONT_COLOR
	var size: int = GameData.UI_FONT_SIZE
	for type_name: String in types:
		target.set_font("font", type_name, font)
		target.set_font_size("font_size", type_name, size)
		target.set_color("font_color", type_name, white)
		target.set_color("font_shadow_color", type_name, Color(0, 0, 0, 0.85))
		if type_name.ends_with("Button") or type_name == "Button":
			target.set_color("font_disabled_color", type_name, white)
			target.set_color("font_focus_color", type_name, white)
			target.set_color("font_hover_color", type_name, white)
			target.set_color("font_pressed_color", type_name, white)
			target.set_color("font_hover_pressed_color", type_name, white)


func _unify_control_text(node: Node, font: FontFile) -> void:
	if node is Control:
		var control: Control = node as Control
		if control is Label or control is Button or control is ProgressBar:
			control.add_theme_font_override("font", font)
			control.add_theme_font_size_override("font_size", GameData.UI_FONT_SIZE)
			control.add_theme_color_override("font_color", GameData.UI_FONT_COLOR)
			if control is Button:
				var button: Button = control as Button
				button.add_theme_color_override("font_disabled_color", GameData.UI_FONT_COLOR)
				button.add_theme_color_override("font_focus_color", GameData.UI_FONT_COLOR)
				button.add_theme_color_override("font_hover_color", GameData.UI_FONT_COLOR)
				button.add_theme_color_override("font_pressed_color", GameData.UI_FONT_COLOR)
	for child: Node in node.get_children():
		_unify_control_text(child, font)


func _apply_menu_text_style(font: FontFile) -> void:
	if not is_instance_valid(_exit_popup):
		return
	_style_menu_text_tree(_exit_popup, font)
	_apply_menu_control_heights()


func _style_menu_text_tree(node: Node, font: FontFile) -> void:
	if node is Label or node is Button:
		var control: Control = node as Control
		control.add_theme_font_override("font", font)
		control.add_theme_font_size_override("font_size", GameData.MENU_UI_FONT_SIZE)
		control.add_theme_color_override("font_color", GameData.UI_FONT_COLOR)
		control.add_theme_constant_override("line_spacing", GameData.MENU_LINE_SPACING)
		if control is Button:
			var button: Button = control as Button
			button.add_theme_color_override("font_disabled_color", GameData.UI_FONT_COLOR)
			button.add_theme_color_override("font_focus_color", GameData.UI_FONT_COLOR)
			button.add_theme_color_override("font_hover_color", GameData.UI_FONT_COLOR)
			button.add_theme_color_override("font_pressed_color", GameData.UI_FONT_COLOR)
	for child: Node in node.get_children():
		_style_menu_text_tree(child, font)


func _apply_menu_control_heights() -> void:
	if is_instance_valid(_dryer_slot):
		_dryer_slot.custom_minimum_size.y = GameData.MENU_SLOT_HEIGHT
	if is_instance_valid(_drawer_slot):
		_drawer_slot.custom_minimum_size.y = GameData.MENU_SLOT_HEIGHT
	if is_instance_valid(_pressure_button):
		_pressure_button.custom_minimum_size.y = GameData.MENU_ACTION_HEIGHT
	if is_instance_valid(_settings_button):
		_settings_button.custom_minimum_size.y = GameData.MENU_ACTION_HEIGHT
	if is_instance_valid(_quit_app_button):
		_quit_app_button.custom_minimum_size.y = GameData.MENU_ACTION_HEIGHT
	if is_instance_valid(_pin_top_button):
		_pin_top_button.custom_minimum_size.y = GameData.MENU_ACTION_HEIGHT
	if is_instance_valid(_menu_close_button):
		_menu_close_button.custom_minimum_size = Vector2(
			GameData.MENU_CLOSE_BUTTON_SIZE.x * GameData.MENU_BUBBLE_HEIGHT_SCALE,
			GameData.MENU_CLOSE_BUTTON_SIZE.y * GameData.MENU_BUBBLE_HEIGHT_SCALE
		)
	var size_buttons: Array[Button] = [
		_size_small_button, _size_medium_button, _size_large_button, _size_huge_button,
	]
	for size_button: Button in size_buttons:
		if is_instance_valid(size_button):
			size_button.custom_minimum_size.y = GameData.MENU_ACTION_HEIGHT


func _connect_exit_popup() -> void:
	_wire_menu_icon(_dryer_slot, "dryer")
	_wire_menu_icon(_drawer_slot, "drawer")
	_pin_top_button.pressed.connect(func() -> void:
		_toggle_always_on_top()
	)
	_pressure_button.pressed.connect(func() -> void:
		_on_pressure_wash_pressed()
	)
	_quit_app_button.pressed.connect(func() -> void:
		GameData.save_game()
		get_tree().quit()
	)
	_menu_close_button.pressed.connect(func() -> void:
		_close_exit_popup()
	)
	_settings_button.pressed.connect(func() -> void:
		if is_instance_valid(_settings_panel):
			_settings_panel.visible = not _settings_panel.visible
	)
	_size_small_button.pressed.connect(func() -> void:
		_set_pet_size_tier(GameData.PET_SIZE_SMALL)
	)
	_size_medium_button.pressed.connect(func() -> void:
		_set_pet_size_tier(GameData.PET_SIZE_MEDIUM)
	)
	_size_large_button.pressed.connect(func() -> void:
		_set_pet_size_tier(GameData.PET_SIZE_LARGE)
	)
	_size_huge_button.pressed.connect(func() -> void:
		_set_pet_size_tier(GameData.PET_SIZE_HUGE)
	)
	_refresh_pin_button()
	_refresh_size_buttons()
	_inventory_close_button.pressed.connect(func() -> void:
		_close_inventory()
	)
	_inventory_popup.gui_input.connect(func(event: InputEvent) -> void:
		_process_drag_input(event)
	)
	_exit_popup.gui_input.connect(func(event: InputEvent) -> void:
		_process_drag_input(event)
	)
	_inventory_popup.resized.connect(func() -> void:
		if _inventory_popup.visible:
			_layout_inventory_bg()
	)
	_exit_popup.resized.connect(func() -> void:
		if _exit_popup.visible:
			_layout_menu_icons()
	)
	GameData.stats_changed.connect(func() -> void:
		_refresh_stat_bubbles()
	)


func _wire_menu_icon(slot: Button, kind: String) -> void:
	if not is_instance_valid(slot):
		return
	slot.pressed.connect(func() -> void:
		_open_inventory(kind)
	)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if _inventory_popup.visible:
				_close_inventory()
				accept_event()
				return
			if _is_pointer_on_pet(mb.position):
				_open_exit_popup()
			else:
				_close_exit_popup()
			accept_event()
			return
	_process_drag_input(event)


func _input(event: InputEvent) -> void:
	_process_drag_input(event)
	if event is InputEventKey:
		var key: InputEventKey = event
		if not key.pressed:
			return
		if key.keycode == KEY_ESCAPE:
			if _inventory_popup.visible:
				_close_inventory()
			elif _exit_popup.visible:
				_close_exit_popup()
			else:
				GameData.save_game()
				get_tree().quit()


func _placeholder_from_still(texture: Texture2D) -> void:
	if _video_enabled:
		return
	_placeholder_visual.visible = false
	_pet_frame.texture = texture
	_pet_frame.visible = true
	_pet_frame.material = null


func _is_click_on_blocking_ui(global_pos: Vector2) -> bool:
	if _inventory_popup.visible and is_instance_valid(_inventory_close_button):
		if _inventory_close_button.get_global_rect().has_point(global_pos):
			return true
	if _exit_popup.visible:
		return _is_point_on_menu_button(global_pos)
	return false


func _is_point_on_menu_button(global_pos: Vector2) -> bool:
	var buttons: Array[Button] = [
		_dryer_slot, _drawer_slot, _pressure_button, _settings_button,
		_quit_app_button, _menu_close_button, _pin_top_button,
		_size_small_button, _size_medium_button, _size_large_button, _size_huge_button,
	]
	for button: Button in buttons:
		if not is_instance_valid(button) or not button.visible:
			continue
		var parent_vis: bool = true
		var walk: Node = button.get_parent()
		while walk != null and walk != _exit_popup:
			if walk is CanvasItem and not (walk as CanvasItem).visible:
				parent_vis = false
				break
			walk = walk.get_parent()
		if parent_vis and button.get_global_rect().has_point(global_pos):
			return true
	return false


func _process_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != DRAG_BUTTON:
			return
		if mb.pressed:
			if _is_click_on_blocking_ui(mb.global_position):
				return
			if _inventory_popup.visible:
				pass
			elif _exit_popup.visible:
				pass
			if not _can_move_window():
				return
			_dragging = true
			_drag_offset = DisplayServer.mouse_get_position() - DisplayServer.window_get_position()
		else:
			_dragging = false
		return
	if event is InputEventMouseMotion and _dragging:
		if not _can_move_window():
			_dragging = false
			return
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


func _connect_game_data() -> void:
	GameData.warehouse_changed.connect(func(_current: int, _capacity: int) -> void:
		_try_resume_wash()
		if _inventory_popup.visible and _inventory_kind == "dryer":
			_fill_inventory_grid()
	)
	GameData.collection_changed.connect(func(_total: int) -> void:
		if _inventory_popup.visible and _inventory_kind == "drawer":
			_fill_inventory_grid()
	)
	GameData.item_washed.connect(func(item: Dictionary) -> void:
		var quality: int = int(item["quality"])
		_log("washed #%d %s -> wet=%d/%d" % [
			int(item["id"]),
			String(item.get("display_name", GameData.QUALITY_NAMES[quality])),
			GameData.wet_warehouse.size(),
			GameData.WAREHOUSE_CAPACITY,
		])
	)
	GameData.item_dried.connect(func(item: Dictionary) -> void:
		var quality: int = int(item["quality"])
		_log("dried #%d %s -> collection=%d coins=%d" % [
			int(item["id"]),
			String(item.get("display_name", GameData.QUALITY_NAMES[quality])),
			GameData.dry_collection.size(),
			GameData.coins,
		])
	)


func _process(delta: float) -> void:
	match _state:
		State.WASHING:
			_tick_wash(delta)
		State.RUNAWAY:
			_tick_runaway(delta)
		State.PAUSED_FULL:
			pass

	if _video_enabled and not _video_fitted:
		_tick_video_probe()
	elif _video_enabled and chroma_key_enabled:
		_feed_pet_frame_texture()

	_tick_hover_hud(delta)
	_refresh_wash_progress()
	_tick_pressure_cooldown(delta)
	GameData.tick_companion(delta)
	if _exit_popup.visible:
		_refresh_stat_bubbles()
	if _state == State.RUNAWAY:
		_layout_runaway_banner()


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


func _finish_wash() -> void:
	var item: Dictionary = GameData.add_wet_item()
	if item.is_empty():
		_state = State.PAUSED_FULL
		return
	_start_dry_timer(int(item["id"]))
	_start_wash_cycle()


func _start_dry_timer(item_id: int) -> void:
	var item: Dictionary = GameData.find_wet_item(item_id)
	var dry_seconds: float = GameData.DRY_DURATION_BASE
	if not item.is_empty():
		dry_seconds = float(item.get("dry_seconds", GameData.dry_duration_for(int(item.get("quality", 0)))))
		var deadline: float = float(item.get("dry_deadline", 0.0))
		if deadline > 0.0:
			dry_seconds = maxf(deadline - Time.get_unix_time_from_system(), 0.2)
	var timer: Timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = dry_seconds
	add_child(timer)
	_dry_timers[item_id] = timer
	timer.timeout.connect(func() -> void:
		GameData.dry_item(item_id)
		_dry_timers.erase(item_id)
		timer.queue_free()
	)
	timer.start()


func _try_resume_wash() -> void:
	if _state == State.PAUSED_FULL and not GameData.is_warehouse_full():
		_log("slot freed -> wash resumed")
		_start_wash_cycle()


## 免费加速（无 UI 入口，供脚本 / 后续功能调用）。
func trigger_free_speedup() -> bool:
	if _state != State.WASHING:
		return false
	if randf() < GameData.FREE_SPEEDUP_RUNAWAY_CHANCE:
		_trigger_runaway()
		return false
	_wash_remaining = maxf(_wash_remaining - GameData.FREE_SPEEDUP_SECONDS, 0.0)
	return true


func _on_pressure_wash_pressed() -> void:
	if _pressure_cd > 0.0:
		return
	_pressure_cd = GameData.PRESSURE_BUTTON_COOLDOWN
	_refresh_pressure_button()
	var cut: float = GameData.roll_pressure_wash_cut()
	if _state == State.WASHING:
		_wash_remaining = maxf(_wash_remaining - cut, 0.0)
		print("%s pressure cut=%.1fs remaining=%.1fs" % [VIDEO_LOG_PREFIX, cut, _wash_remaining])
		_refresh_wash_progress()
		if _wash_remaining <= 0.0:
			_finish_wash()
	else:
		print("%s pressure cut=%.1fs (not washing, skipped)" % [VIDEO_LOG_PREFIX, cut])
	## 扣时完成 ≠ 跑路。跑路只走独立的 15.5% 千分位掷骰。
	var runaway: bool = GameData.roll_pressure_runaway()
	print("%s pressure runaway=%s (15.5%%)" % [VIDEO_LOG_PREFIX, str(runaway)])
	if runaway:
		_trigger_runaway()


func _tick_pressure_cooldown(delta: float) -> void:
	if _pressure_cd <= 0.0:
		return
	_pressure_cd = maxf(_pressure_cd - delta, 0.0)
	_refresh_pressure_button()


func _refresh_pressure_button() -> void:
	if not is_instance_valid(_pressure_button):
		return
	var cooling: bool = _pressure_cd > 0.0
	_pressure_button.disabled = cooling
	var next_text: String = GameData.PRESSURE_BUTTON_TEXT
	if cooling:
		next_text = "%s%s" % [
			GameData.format_pressure_countdown(_pressure_cd),
			GameData.PRESSURE_COOLDOWN_SUFFIX,
		]
	if next_text == _pressure_cd_text and _pressure_button.text == next_text:
		return
	_pressure_cd_text = next_text
	_pressure_button.text = next_text


func _trigger_runaway() -> void:
	_state = State.RUNAWAY
	_cooldown_remaining = GameData.get_calculated_cooldown()
	_dragging = false
	GameData.record_runaway()
	_close_exit_popup()
	_close_inventory()
	_show_runaway_basin(true)
	_log("RUNAWAY! basin left, cooldown=%.1fs (reduction=%.0f%%)" % [
		_cooldown_remaining,
		GameData.get_cd_reduction() * 100.0,
	])


func _tick_runaway(delta: float) -> void:
	_cooldown_remaining -= delta
	if _cooldown_remaining > 0.0:
		return
	_cooldown_remaining = 0.0
	_show_runaway_basin(false)
	_log("cooldown over -> pet is back")
	_start_wash_cycle()


func _show_runaway_basin(active: bool) -> void:
	_hover_time = 0.0
	_set_hover_hud_visible(false, false)
	if active:
		_set_video_playing(false)
		if is_instance_valid(_pet_frame):
			_pet_frame.visible = false
		if is_instance_valid(_placeholder_visual):
			_placeholder_visual.visible = false
		if is_instance_valid(_basin_frame):
			if _container_texture != null:
				_basin_frame.texture = _container_texture
			_fit_rect_to_area(_basin_frame, _container_texture, _pet_area())
			_basin_frame.visible = true
			_apply_chroma_material(
				_basin_frame,
				chroma_key_similarity,
				chroma_key_smoothness,
				chroma_spill_suppression
			)
		if is_instance_valid(_pet_visual):
			_pet_visual.visible = true
		if is_instance_valid(_runaway_banner):
			if _runaway_banner.get_child_count() > 0:
				var banner_label: Label = _runaway_banner.get_child(0) as Label
				if banner_label != null:
					banner_label.text = GameData.RUNAWAY_BANNER_TEXT
			_runaway_banner.visible = true
			_layout_runaway_banner()
	else:
		if is_instance_valid(_basin_frame):
			_basin_frame.visible = false
		if is_instance_valid(_runaway_banner):
			_runaway_banner.visible = false
		if is_instance_valid(_pet_visual):
			_pet_visual.visible = true
		_set_video_playing(_video_enabled)


func _set_pet_hidden(hide_pet: bool) -> void:
	_pet_visual.visible = not hide_pet
	_set_video_playing(not hide_pet)
	if hide_pet:
		_hover_time = 0.0
		_set_hover_hud_visible(false, false)
	_close_exit_popup()
	_close_inventory()
	if _can_move_window():
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH, hide_pet)


func _ensure_pet_video_node() -> void:
	_pet_video = get_node_or_null("%PetVideo") as VideoStreamPlayer
	if _pet_video == null:
		_pet_video = get_node_or_null("PetVisual/PetVideo") as VideoStreamPlayer
	if _pet_video == null:
		_pet_video = find_child("PetVideo", true, false) as VideoStreamPlayer
	if _pet_video != null:
		_pet_video.unique_name_in_owner = true
		_pet_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	var visual: Control = _pet_visual
	if visual == null:
		visual = get_node_or_null("%PetVisual") as Control
	if visual == null:
		visual = get_node_or_null("PetVisual") as Control
	if visual == null:
		push_error("PetVideo node is missing or null! PetVisual is also missing.")
		return
	_pet_video = VideoStreamPlayer.new()
	_pet_video.name = "PetVideo"
	_pet_video.unique_name_in_owner = true
	_pet_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pet_video.volume_db = -80.0
	_pet_video.autoplay = true
	_pet_video.expand = true
	_pet_video.loop = true
	_pet_video.position = GameData.PET_AREA.position
	_pet_video.size = GameData.PET_AREA.size
	visual.add_child(_pet_video)
	visual.move_child(_pet_video, 0)
	print("%s restored missing PetVideo under %s" % [VIDEO_LOG_PREFIX, visual.get_path()])


func _setup_pet_video() -> void:
	if not is_instance_valid(_pet_video):
		_ensure_pet_video_node()
	if not is_instance_valid(_pet_video):
		push_error("PetVideo node is missing or null!")
		_fail_video("场景里没有 PetVideo（VideoStreamPlayer）。")
		return
	_apply_video_key()

	var path: String = _resolve_video_path()
	if path.is_empty():
		_fail_video(
			"没有可用的人物动画。仓库里的 steve.ogv 仍是测试占位片（<%d bytes），不会再当立绘播放。%s" % [
				GameData.STUB_VIDEO_MAX_BYTES, _describe_video_dir(),
			],
			_convert_hint(_find_unplayable_source())
		)
		return

	var container_problem: String = _diagnose_container(path)
	if not container_problem.is_empty():
		_fail_video("%s —— %s" % [path, container_problem], _convert_hint(path))
		return

	var stream: VideoStream = _load_video_stream(path)
	if stream == null:
		_fail_video("%s 存在，但 ResourceLoader 没能把它加载成 VideoStream 资源。" % path,
			_convert_hint(path))
		return

	if _pet_video.stream != stream:
		_pet_video.stream = stream
	_pet_video.autoplay = true
	_pet_video.loop = true
	_pet_video.expand = true
	if not _pet_video.finished.is_connected(_on_video_finished):
		_pet_video.finished.connect(_on_video_finished)

	_video_enabled = true
	_video_fitted = false
	_pet_video.play()
	_sync_video_display()

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
	_log_chroma_key_state()


func _on_video_finished() -> void:
	if _video_enabled and is_instance_valid(_pet_video) and not _pet_video.is_playing():
		_pet_video.play()


func _resolve_video_path() -> String:
	var ingested: String = _ingest_desktop_source()
	if _is_usable_ogv(ingested):
		return ingested
	if _is_usable_ogv(VIDEO_PATH):
		return VIDEO_PATH
	var from_stream: String = _stream_file_path(_pet_video.stream if is_instance_valid(_pet_video) else null)
	if _is_usable_ogv(from_stream):
		return from_stream
	for file_name: String in _video_dir_files():
		var clean: String = file_name.trim_suffix(".remap")
		if clean.get_extension().to_lower() != "ogv":
			continue
		var candidate: String = "%s/%s" % [VIDEO_DIR, clean]
		if _is_usable_ogv(candidate):
			return candidate
	return ""


func _is_usable_ogv(path: String) -> bool:
	if path.is_empty() or not FileAccess.file_exists(path):
		return false
	if GameData.is_stub_ogv(path):
		print_rich("[color=#ffcc66]%s拒绝占位片：%s（%d bytes ≤ %d）[/color]" % [
			VIDEO_LOG_PREFIX, path, GameData.file_byte_count(path), GameData.STUB_VIDEO_MAX_BYTES,
		])
		return false
	var container_problem: String = _diagnose_container(path)
	if not container_problem.is_empty():
		print_rich("[color=#ffcc66]%s拒绝坏容器：%s — %s[/color]" % [VIDEO_LOG_PREFIX, path, container_problem])
		return false
	return true


func _ingest_desktop_source() -> String:
	var source: String = _find_desktop_source()
	if source.is_empty():
		print_verbose("%s user video not found: %s/%s" % [
			VIDEO_LOG_PREFIX, GameData.USER_PROJECT_DIR, GameData.USER_VIDEO_FILE,
		])
		return ""
	print_rich("[color=#54d18c]%s找到本机素材：%s[/color]" % [VIDEO_LOG_PREFIX, source])
	if source.get_extension().to_lower() == "ogv":
		return source if _is_usable_ogv(source) else ""
	var dest_res: String = ProjectSettings.globalize_path(VIDEO_PATH)
	var dest_user: String = ProjectSettings.globalize_path(USER_CACHE_OGV)
	var src_mtime: int = FileAccess.get_modified_time(source)
	if _is_usable_ogv(VIDEO_PATH) and FileAccess.get_modified_time(VIDEO_PATH) >= src_mtime:
		print_verbose("%s project ogv is newer than %s" % [VIDEO_LOG_PREFIX, source])
		return VIDEO_PATH
	if _is_usable_ogv(USER_CACHE_OGV) and FileAccess.get_modified_time(USER_CACHE_OGV) >= src_mtime:
		print_verbose("%s chroma-ready cache hit: %s" % [VIDEO_LOG_PREFIX, USER_CACHE_OGV])
		return USER_CACHE_OGV
	if _run_ffmpeg_theora(source, dest_res) and _is_usable_ogv(VIDEO_PATH):
		print_rich("[color=#54d18c]%s已转码 steve3 -> %s[/color]" % [VIDEO_LOG_PREFIX, VIDEO_PATH])
		return VIDEO_PATH
	if _run_ffmpeg_theora(source, dest_user) and _is_usable_ogv(USER_CACHE_OGV):
		print_rich("[color=#54d18c]%s已转码绿幕视频 -> %s[/color]" % [VIDEO_LOG_PREFIX, USER_CACHE_OGV])
		return USER_CACHE_OGV
	print_rich("[color=#ff8b6a]%sFFmpeg 转码失败，不会回落到占位片。请双击 convert_video.bat。[/color]" % VIDEO_LOG_PREFIX)
	return ""


func _find_desktop_source() -> String:
	var names: PackedStringArray = PackedStringArray([
		GameData.USER_VIDEO_FILE,
		"Steve3.mp4",
		"steve3.ogv",
		"Steve3.ogv",
	])
	for file_name: String in names:
		var path: String = GameData.first_existing_file(file_name)
		if not path.is_empty():
			return path
	return ""


func _run_ffmpeg_theora(source: String, dest_os: String) -> bool:
	var attempts: Array = [
		PackedStringArray([
			"-y", "-i", source,
			"-vf", "fps=24,scale=460:-2",
			"-c:v", "libtheora", "-q:v", "8", "-an", dest_os,
		]),
		PackedStringArray([
			"-y", "-i", source,
			"-vf", "fps=24,scale=460:-2",
			"-c:v", "theora", "-qscale:v", "7", "-an", dest_os,
		]),
	]
	for args: PackedStringArray in attempts:
		var output: Array = []
		var code: int = OS.execute("ffmpeg", args, output, true)
		if code != 0:
			print_verbose("%s ffmpeg exit=%d  dest=%s  %s" % [VIDEO_LOG_PREFIX, code, dest_os, str(output)])
			continue
		if FileAccess.file_exists(dest_os) and not GameData.is_stub_ogv(dest_os):
			return true
		if dest_os == ProjectSettings.globalize_path(VIDEO_PATH) and _is_usable_ogv(VIDEO_PATH):
			return true
		if dest_os == ProjectSettings.globalize_path(USER_CACHE_OGV) and _is_usable_ogv(USER_CACHE_OGV):
			return true
	return false


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


func _find_unplayable_source() -> String:
	var desktop: String = _find_desktop_source()
	if not desktop.is_empty() and desktop.get_extension().to_lower() != "ogv":
		return desktop
	for file_name: String in _video_dir_files():
		if file_name.get_extension().to_lower() in ["mp4", "webm", "mov", "mkv", "avi", "m4v", "flv"]:
			return "%s/%s" % [VIDEO_DIR, file_name]
	return "%s/%s" % [GameData.USER_PROJECT_DIR, GameData.USER_VIDEO_FILE]


func _convert_hint(source_path: String) -> String:
	var target: String = ProjectSettings.globalize_path(VIDEO_PATH)
	var source: String = "%s/%s" % [GameData.USER_PROJECT_DIR, GameData.USER_VIDEO_FILE]
	var lead: String = "Godot 4 只能播 Ogg Theora（.ogv），用 FFmpeg 把绿幕 mp4 转一次："
	if source_path == VIDEO_PATH:
		lead = "Godot 4 只能播 Ogg Theora（.ogv）。请把仓库根目录的 steve3.mp4 转成 steve.ogv："
	elif not source_path.is_empty():
		source = source_path
		if source.begins_with("res://") or source.begins_with("user://"):
			source = ProjectSettings.globalize_path(source)
	return "%s\n%s  ffmpeg -i \"%s\" -vf \"fps=24,scale=460:-2\" -c:v libtheora -q:v 8 -an \"%s\"" % [
		lead, VIDEO_LOG_PREFIX, source, target,
	]


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
	if head.slice(4, 8).get_string_from_ascii() == "ftyp":
		return "这其实是 MP4/MOV 容器，只是文件名改成了 .ogv"
	if head.slice(0, 4) == PackedByteArray([0x1A, 0x45, 0xDF, 0xA3]):
		return "这其实是 Matroska/WebM 容器，只是文件名改成了 .ogv"
	if head.slice(0, 4).get_string_from_ascii() == "RIFF":
		return "这其实是 AVI/WAV 容器，只是文件名改成了 .ogv"
	if head.slice(0, 3).get_string_from_ascii() == "FLV":
		return "这其实是 FLV 容器，只是文件名改成了 .ogv"
	return "文件头不是 Ogg（前 4 字节 = %s），不是合法的 .ogv" % head.slice(0, 4).hex_encode()


func _load_video_stream(path: String) -> VideoStream:
	if ResourceLoader.exists(path, "VideoStream"):
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


func _fail_video(reason: String, hint: String = "") -> void:
	_video_enabled = false
	_video_confirmed = false
	_video_probe_left = 0
	if is_instance_valid(_pet_video):
		_pet_video.stop()
		_pet_video.stream = null
	_refresh_visual_swap()
	var still: Texture2D = GameData.load_image_texture(GameData.USER_STEVE2_FILE)
	if still != null:
		_placeholder_from_still(still)
	print_rich("[color=#ff8b6a]%s未启用动态立绘，已回落到几何占位。[/color]" % VIDEO_LOG_PREFIX)
	print_rich("[color=#ff8b6a]%s  原因：%s[/color]" % [VIDEO_LOG_PREFIX, reason])
	if not hint.is_empty():
		print_rich("[color=#ffcc66]%s  怎么修：%s[/color]" % [VIDEO_LOG_PREFIX, hint])
	push_warning("动态立绘未启用：%s" % reason)


func _refresh_visual_swap() -> void:
	_placeholder_visual.visible = not _video_enabled
	_sync_video_display()


func _sync_video_display() -> void:
	if not is_instance_valid(_pet_video):
		if is_instance_valid(_pet_frame):
			_pet_frame.visible = false
		return
	if not _video_enabled:
		_pet_video.visible = false
		_pet_frame.visible = false
		return
	if chroma_key_enabled:
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
		_video_fitted = true
		return

	_fail_video("视频能加载，但连续 %d 帧解不出任何画面（文件损坏，或者 Ogg 容器里根本没有 Theora 视频轨）。" % VIDEO_PROBE_FRAMES,
		_convert_hint(_pet_video.stream.resource_path if _pet_video.stream != null else ""))


func _fit_video_rect() -> bool:
	var texture: Texture2D = _pet_video.get_video_texture()
	if texture == null:
		return false
	var source: Vector2 = texture.get_size()
	if source.x <= 0.0 or source.y <= 0.0:
		return false

	var area: Rect2 = _pet_area()
	var ratio: float = minf(area.size.x / source.x, area.size.y / source.y)
	var fitted: Vector2 = source * ratio
	_pet_video.position = area.position + (area.size - fitted) * 0.5
	_pet_video.size = fitted
	_sync_video_display()
	return true


func _set_video_playing(playing: bool) -> void:
	if not _video_enabled or not is_instance_valid(_pet_video):
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


func _apply_chroma_material(rect: TextureRect, similarity: float, smoothness: float, spill: float) -> void:
	if not is_instance_valid(rect):
		return
	var shader: Shader = load(CHROMA_SHADER_PATH) as Shader
	if shader == null:
		push_error("%s failed to load %s" % [VIDEO_LOG_PREFIX, CHROMA_SHADER_PATH])
		return
	var key_material: ShaderMaterial = rect.material as ShaderMaterial
	if key_material == null:
		key_material = ShaderMaterial.new()
	if key_material.shader != shader:
		key_material.shader = shader
	rect.material = key_material
	key_material.set_shader_parameter("key_color", chroma_key_color)
	key_material.set_shader_parameter("similarity", similarity)
	key_material.set_shader_parameter("smoothness", maxf(smoothness, 0.001))
	key_material.set_shader_parameter("spill_suppression", clampf(spill, 0.0, 1.0))


func _apply_video_key() -> void:
	if not chroma_key_enabled:
		return
	_apply_chroma_material(_pet_frame, chroma_key_similarity, chroma_key_smoothness, chroma_spill_suppression)
	_apply_chroma_material(_inventory_bg, chroma_key_similarity, chroma_key_smoothness, chroma_spill_suppression)
	_apply_chroma_material(_dryer_icon, chroma_key_similarity, chroma_key_smoothness, chroma_spill_suppression)
	_apply_chroma_material(_drawer_icon, chroma_key_similarity, chroma_key_smoothness, chroma_spill_suppression)
	if is_instance_valid(_basin_frame) and _basin_frame.visible:
		_apply_chroma_material(_basin_frame, chroma_key_similarity, chroma_key_smoothness, chroma_spill_suppression)


func _log_chroma_key_state() -> void:
	if chroma_key_enabled:
		print_verbose("%s chroma key ON  color=#%s  similarity=%.2f  smoothness=%.2f  spill=%.2f  frame_visible=%s" % [
			VIDEO_LOG_PREFIX,
			chroma_key_color.to_html(false),
			chroma_key_similarity,
			chroma_key_smoothness,
			chroma_spill_suppression,
			_pet_frame.visible if is_instance_valid(_pet_frame) else false,
		])
	else:
		print_verbose("%s chroma key OFF — showing VideoStreamPlayer directly" % VIDEO_LOG_PREFIX)


func set_chroma_key_enabled(enabled: bool) -> void:
	chroma_key_enabled = enabled


func apply_chroma_key(
	color: Color = GameData.CHROMA_KEY_COLOR,
	similarity: float = GameData.CHROMA_KEY_SIMILARITY,
	smoothness: float = GameData.CHROMA_KEY_SMOOTHNESS,
	spill: float = GameData.CHROMA_SPILL_SUPPRESSION
) -> void:
	chroma_key_color = color
	chroma_key_similarity = similarity
	chroma_key_smoothness = smoothness
	chroma_spill_suppression = spill
	chroma_key_enabled = true


func _is_hovering_pet() -> bool:
	if _state == State.RUNAWAY:
		return false
	if _inventory_popup.visible:
		return false
	var local_pos: Vector2 = get_local_mouse_position()
	if not Rect2(Vector2.ZERO, size).has_point(local_pos):
		return false
	return _is_pointer_on_pet(local_pos)


func _wash_progress_value() -> int:
	if _state == State.PAUSED_FULL:
		return GameData.WASH_PROGRESS_MAX
	if GameData.WASH_DURATION <= 0.0:
		return 0
	var ratio: float = 1.0 - (_wash_remaining / GameData.WASH_DURATION)
	return clampi(int(round(ratio * float(GameData.WASH_PROGRESS_MAX))), 0, GameData.WASH_PROGRESS_MAX)


func _current_pet_rect() -> Rect2:
	if is_instance_valid(_basin_frame) and _basin_frame.visible and _basin_frame.size.x > 1.0:
		return Rect2(_basin_frame.position, _basin_frame.size)
	if is_instance_valid(_pet_frame) and _pet_frame.visible and _pet_frame.size.x > 1.0:
		return Rect2(_pet_frame.position, _pet_frame.size)
	if is_instance_valid(_pet_video) and _pet_video.size.x > 1.0:
		return Rect2(_pet_video.position, _pet_video.size)
	return _pet_area()


func _pet_area() -> Rect2:
	return _layout_area


func _capture_layout_area() -> void:
	if is_instance_valid(_pet_video) and _pet_video.size.x >= 8.0 and _pet_video.size.y >= 8.0:
		_layout_area = Rect2(_pet_video.position, _pet_video.size)
	else:
		_layout_area = GameData.PET_AREA
	print("%s default layout=%s  chroma=#%s sim=%.2f smooth=%.2f spill=%.2f" % [
		VIDEO_LOG_PREFIX,
		str(_layout_area),
		chroma_key_color.to_html(false),
		chroma_key_similarity,
		chroma_key_smoothness,
		chroma_spill_suppression,
	])


func _fit_rect_to_area(rect: TextureRect, texture: Texture2D, area: Rect2) -> Rect2:
	if not is_instance_valid(rect):
		return area
	var fitted: Vector2 = area.size
	if texture != null:
		var source: Vector2 = texture.get_size()
		if source.x > 0.0 and source.y > 0.0:
			var ratio: float = minf(area.size.x / source.x, area.size.y / source.y)
			fitted = source * ratio
	rect.position = area.position + (area.size - fitted) * 0.5
	rect.size = fitted
	return Rect2(rect.position, rect.size)


func _layout_runaway_banner() -> void:
	if not is_instance_valid(_runaway_banner) or not _runaway_banner.visible:
		return
	var image_rect: Rect2 = _current_pet_rect()
	var width: float = clampf(
		image_rect.size.x * GameData.RUNAWAY_BANNER_WIDTH_RATIO,
		96.0,
		image_rect.size.x
	)
	var height: float = GameData.RUNAWAY_BANNER_HEIGHT
	var x: float = image_rect.position.x + (image_rect.size.x - width) * 0.5
	var y: float = image_rect.position.y + GameData.RUNAWAY_BANNER_TOP_INSET
	_runaway_banner.position = Vector2(x, y)
	_runaway_banner.size = Vector2(width, height)
	_runaway_banner.z_index = 12


func _layout_hover_hud() -> void:
	if not is_instance_valid(_hover_hud):
		return
	var pet: Rect2 = _current_pet_rect()
	var bar_w: float = clampf(pet.size.x * 0.78, 72.0, pet.size.x)
	var hud_h: float = HOVER_HUD_HEIGHT
	var x: float = pet.position.x + (pet.size.x - bar_w) * 0.5
	var y: float = pet.position.y - hud_h - HOVER_GAP
	if y < 2.0:
		y = pet.position.y + HOVER_GAP
	y += GameData.WASH_BAR_SHIFT_Y
	_hover_hud.position = Vector2(x, y)
	_hover_hud.size = Vector2(bar_w, hud_h)
	_water_bar.position = Vector2.ZERO
	_water_bar.size = Vector2(bar_w, HOVER_BAR_HEIGHT)
	_wash_label.position = Vector2(0.0, HOVER_BAR_HEIGHT + 2.0)
	_wash_label.size = Vector2(bar_w, 24.0)
	_wash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _refresh_wash_progress() -> void:
	_layout_hover_hud()
	var progress: int = _wash_progress_value()
	_water_bar.max_value = float(GameData.WASH_PROGRESS_MAX)
	_water_bar.value = float(progress)
	_wash_label.text = "洗涤进度（%d/%d）" % [progress, GameData.WASH_PROGRESS_MAX]


func _tick_hover_hud(delta: float) -> void:
	if _is_hovering_pet():
		_hover_time += delta
		if _hover_time >= GameData.HOVER_SHOW_DELAY and not _hover_hud_shown:
			_set_hover_hud_visible(true, true)
	else:
		_hover_time = 0.0
		if _hover_hud_shown:
			_set_hover_hud_visible(false, true)


func _set_hover_hud_visible(show_hud: bool, animate: bool) -> void:
	_hover_hud_shown = show_hud
	_layout_hover_hud()
	if is_instance_valid(_hover_tween):
		_hover_tween.kill()
	var end_alpha: float = 1.0 if show_hud else 0.0
	if not animate:
		_hover_hud.modulate.a = end_alpha
		return
	_hover_tween = create_tween()
	_hover_tween.set_trans(Tween.TRANS_CUBIC)
	_hover_tween.set_ease(Tween.EASE_OUT if show_hud else Tween.EASE_IN)
	_hover_tween.tween_property(_hover_hud, "modulate:a", end_alpha, GameData.HOVER_FADE_SECONDS)


func _is_pointer_on_pet(local_pos: Vector2) -> bool:
	return _current_pet_rect().has_point(local_pos)


func _open_exit_popup() -> void:
	_refresh_pressure_button()
	_refresh_stat_bubbles()
	if is_instance_valid(_settings_panel):
		_settings_panel.visible = false
	_set_pet_layer_visible(false)
	_expand_overlay_window(GameData.context_menu_window_size())
	_exit_popup.visible = true
	_apply_menu_icons()
	call_deferred("_layout_menu_icons")
	print_verbose("%s context menu open" % VIDEO_LOG_PREFIX)


func _close_exit_popup() -> void:
	if is_instance_valid(_exit_popup):
		_exit_popup.visible = false
	if is_instance_valid(_settings_panel):
		_settings_panel.visible = false
	_restore_overlay_window_if_idle()
	if not _inventory_popup.visible and _state != State.RUNAWAY:
		_set_pet_layer_visible(true)


func _toggle_always_on_top() -> void:
	_always_on_top = not _always_on_top
	GameData.always_on_top_pref = _always_on_top
	GameData.save_game()
	if _can_move_window():
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, _always_on_top, 0)
	_refresh_pin_button()


func _refresh_pin_button() -> void:
	if is_instance_valid(_pin_top_button):
		_pin_top_button.text = "固定上层：开" if _always_on_top else "固定上层：关"


func _set_pet_layer_visible(shown: bool) -> void:
	if _state == State.RUNAWAY:
		_show_runaway_basin(true)
		return
	if is_instance_valid(_pet_visual):
		_pet_visual.visible = shown
	_set_video_playing(shown)
	if not shown:
		_hover_time = 0.0
		_set_hover_hud_visible(false, false)


func _apply_inventory_background(kind: String) -> void:
	var tex: Texture2D = _dryer_texture if kind == "dryer" else _drawer_texture
	if tex == null:
		tex = _dryer_texture
	if is_instance_valid(_inventory_bg) and tex != null:
		_inventory_bg.texture = tex
	_apply_video_key()
	_layout_inventory_bg()


func _layout_inventory_bg() -> void:
	if not is_instance_valid(_inventory_bg):
		return
	var host: Control = _inventory_bg.get_parent() as Control
	var area: Vector2 = host.size if is_instance_valid(host) else _inventory_popup.size
	if area.x < 2.0 or area.y < 2.0:
		area = Vector2(DisplayServer.window_get_size())
	var zoom: float = GameData.DRYER_BG_ZOOM if _inventory_kind == "dryer" else 1.0
	var fitted: Vector2 = area * zoom
	_inventory_bg.anchor_left = 0.5
	_inventory_bg.anchor_top = 0.5
	_inventory_bg.anchor_right = 0.5
	_inventory_bg.anchor_bottom = 0.5
	_inventory_bg.offset_left = -fitted.x * 0.5
	_inventory_bg.offset_top = -fitted.y * 0.5
	_inventory_bg.offset_right = fitted.x * 0.5
	_inventory_bg.offset_bottom = fitted.y * 0.5


func _apply_inventory_headline(kind: String) -> void:
	if not is_instance_valid(_inventory_headline) or not is_instance_valid(_inventory_title):
		return
	_inventory_title.text = "烘干机" if kind == "dryer" else "抽屉"
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = (
		GameData.DRYER_HEADLINE_COLOR if kind == "dryer" else GameData.DRAWER_HEADLINE_COLOR
	)
	box.set_corner_radius_all(8)
	box.set_border_width_all(2)
	box.border_color = Color(1.0, 1.0, 1.0, 0.92)
	box.content_margin_left = GameData.INVENTORY_HEADLINE_PAD_X
	box.content_margin_right = GameData.INVENTORY_HEADLINE_PAD_X
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	_inventory_headline.add_theme_stylebox_override("panel", box)
	_inventory_headline.custom_minimum_size.y = GameData.INVENTORY_HEADLINE_HEIGHT
	if is_instance_valid(_inventory_close_button):
		_inventory_close_button.custom_minimum_size = Vector2(
			GameData.INVENTORY_CLOSE_BUTTON_WIDTH,
			GameData.INVENTORY_HEADLINE_HEIGHT
		)


func _open_inventory(kind: String) -> void:
	if _state == State.RUNAWAY:
		return
	_inventory_kind = kind
	if is_instance_valid(_exit_popup):
		_exit_popup.visible = false
	if is_instance_valid(_settings_panel):
		_settings_panel.visible = false
	_set_pet_layer_visible(false)
	_expand_overlay_window(_inventory_window_size())
	_apply_inventory_background(kind)
	_apply_inventory_headline(kind)
	_inventory_grid.columns = GameData.GRID_COLUMNS
	_inventory_popup.visible = true
	_fill_inventory_grid()
	call_deferred("_layout_inventory_bg")


func _close_inventory() -> void:
	if is_instance_valid(_inventory_popup):
		_inventory_popup.visible = false
	_inventory_kind = ""
	_restore_overlay_window_if_idle()
	if not _exit_popup.visible and _state != State.RUNAWAY:
		_set_pet_layer_visible(true)


func _inventory_window_size() -> Vector2i:
	var pet: Rect2 = _current_pet_rect()
	return Vector2i(
		maxi(int(pet.size.x * GameData.INVENTORY_SCALE), 400),
		maxi(int(pet.size.y * GameData.INVENTORY_SCALE), 500)
	)


func _expand_overlay_window(new_size: Vector2i) -> void:
	if not _can_move_window():
		return
	if not _overlay_window_open:
		_base_window_size = DisplayServer.window_get_size()
		_base_window_pos = DisplayServer.window_get_position()
		_overlay_window_open = true
	DisplayServer.window_set_size(new_size)
	DisplayServer.window_set_position(_adaptive_inventory_position(new_size))


func _adaptive_inventory_position(new_size: Vector2i) -> Vector2i:
	var usable: Rect2i = DisplayServer.screen_get_usable_rect()
	var cur_pos: Vector2i = DisplayServer.window_get_position() if _overlay_window_open else _base_window_pos
	var cur_size: Vector2i = DisplayServer.window_get_size() if _overlay_window_open else _base_window_size
	var center: Vector2i = cur_pos + cur_size / 2
	var rel_x: float = 0.5
	var rel_y: float = 0.5
	if usable.size.x > 0:
		rel_x = float(center.x - usable.position.x) / float(usable.size.x)
	if usable.size.y > 0:
		rel_y = float(center.y - usable.position.y) / float(usable.size.y)
	var pos: Vector2i = center - new_size / 2
	if rel_x > 0.66:
		pos.x = cur_pos.x + cur_size.x - new_size.x
	elif rel_x < 0.34:
		pos.x = cur_pos.x
	if rel_y > 0.66:
		pos.y = cur_pos.y + cur_size.y - new_size.y
	elif rel_y < 0.34:
		pos.y = cur_pos.y
	var min_x: int = usable.position.x
	var min_y: int = usable.position.y
	var max_x: int = usable.position.x + usable.size.x - new_size.x
	var max_y: int = usable.position.y + usable.size.y - new_size.y
	return Vector2i(clampi(pos.x, min_x, maxi(min_x, max_x)), clampi(pos.y, min_y, maxi(min_y, max_y)))


func _restore_overlay_window_if_idle() -> void:
	if _inventory_popup.visible or _exit_popup.visible:
		return
	if not _overlay_window_open:
		return
	if _can_move_window():
		var cur_pos: Vector2i = DisplayServer.window_get_position()
		var cur_size: Vector2i = DisplayServer.window_get_size()
		var center: Vector2i = cur_pos + cur_size / 2
		var pos: Vector2i = center - _base_window_size / 2
		DisplayServer.window_set_size(_base_window_size)
		DisplayServer.window_set_position(_clamp_to_screen(pos))
	_overlay_window_open = false


func _fill_inventory_grid() -> void:
	for child: Node in _inventory_grid.get_children():
		child.queue_free()
	var items: Array[Dictionary] = (
		GameData.wet_warehouse if _inventory_kind == "dryer" else GameData.dry_collection
	)
	_inventory_empty.visible = items.is_empty()
	for item: Dictionary in items:
		_inventory_grid.add_child(_make_item_card(item))


func _make_item_card(item: Dictionary) -> Control:
	var quality: int = int(item.get("quality", 0))
	var wear: String = String(item.get("wear", item.get("wear_modifier", "")))
	var quality_name: String = GameData.quality_display_name(quality)
	var accent: Color = GameData.QUALITY_COLORS.get(quality, Color(0.7, 0.4, 0.9))

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = GameData.ITEM_CARD_SIZE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(0.42, 0.18, 0.62, 0.88)
	box.border_color = Color(0.78, 0.42, 1.0, 1.0)
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", box)

	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)

	var icon: ColorRect = ColorRect.new()
	icon.custom_minimum_size = Vector2(0.0, 44.0)
	icon.color = Color(accent.r, accent.g, accent.b, 0.85)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(icon)

	var wear_label: Label = Label.new()
	wear_label.text = wear
	wear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wear_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	wear_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wear_label.add_theme_font_size_override("font_size", GameData.UI_FONT_SIZE)
	wear_label.add_theme_color_override("font_color", GameData.UI_FONT_COLOR)
	col.add_child(wear_label)

	var quality_label: Label = Label.new()
	quality_label.text = quality_name
	quality_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quality_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quality_label.add_theme_font_size_override("font_size", GameData.UI_FONT_SIZE)
	quality_label.add_theme_color_override("font_color", GameData.UI_FONT_COLOR)
	col.add_child(quality_label)
	return card


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameData.save_game()
		get_tree().quit()


func _resume_saved_dry_timers() -> void:
	for item: Dictionary in GameData.wet_warehouse:
		var item_id: int = int(item.get("id", 0))
		if item_id <= 0 or _dry_timers.has(item_id):
			continue
		_start_dry_timer(item_id)


func _apply_round_chrome() -> void:
	var radius: int = GameData.POPUP_CORNER_RADIUS
	if is_instance_valid(_exit_popup):
		var menu_box: StyleBoxFlat = StyleBoxFlat.new()
		menu_box.bg_color = Color(0.05, 0.06, 0.1, 0.96)
		menu_box.set_corner_radius_all(radius)
		menu_box.set_border_width_all(3)
		menu_box.border_color = Color(1.0, 0.85, 0.42, 0.94)
		menu_box.set_content_margin_all(18.0)
		_exit_popup.add_theme_stylebox_override("panel", menu_box)
	var inv_box: StyleBoxFlat = StyleBoxFlat.new()
	inv_box.bg_color = Color(0.0, 0.0, 0.0, 0.22)
	inv_box.set_corner_radius_all(radius)
	inv_box.set_border_width_all(3)
	inv_box.border_color = Color(1.0, 1.0, 1.0, 0.55)
	if is_instance_valid(_inventory_chrome):
		_inventory_chrome.add_theme_stylebox_override("panel", inv_box)
	if is_instance_valid(_inventory_mask):
		_inventory_mask.visible = false
	_apply_menu_control_heights()
	_style_stat_bubbles()


func _style_stat_bubbles() -> void:
	var labels: Array[Label] = [
		_bubble_affinity, _bubble_underwear, _bubble_companion, _bubble_runaway,
	]
	for label: Label in labels:
		if not is_instance_valid(label):
			continue
		var panel: PanelContainer = label.get_parent() as PanelContainer
		if panel == null:
			continue
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = Color(0.14, 0.16, 0.22, 0.92)
		box.set_corner_radius_all(GameData.BUBBLE_CORNER_RADIUS)
		box.set_content_margin_all(14.0)
		box.set_border_width_all(2)
		box.border_color = Color(1.0, 1.0, 1.0, 0.5)
		panel.add_theme_stylebox_override("panel", box)
		panel.custom_minimum_size.y = GameData.MENU_BUBBLE_HEIGHT


func _apply_menu_icons() -> void:
	if is_instance_valid(_dryer_icon) and _dryer_texture != null:
		_dryer_icon.texture = _dryer_texture
	if is_instance_valid(_drawer_icon) and _drawer_icon_texture != null:
		_drawer_icon.texture = _drawer_icon_texture
	_apply_video_key()
	_layout_menu_icons()


func _layout_menu_icons() -> void:
	_fit_menu_icon(_dryer_icon_clip, _dryer_icon, GameData.DRYER_ICON_ZOOM)
	_fit_menu_icon(_drawer_icon_clip, _drawer_icon, 1.0)


func _fit_menu_icon(clip: Control, icon: TextureRect, zoom: float) -> void:
	var box: Vector2 = GameData.MENU_ICON_SIZE
	if is_instance_valid(clip):
		clip.custom_minimum_size = box
		clip.clip_contents = true
	if not is_instance_valid(icon):
		return
	var drawn: Vector2 = box * maxf(zoom, 1.0)
	icon.position = (box - drawn) * 0.5
	icon.size = drawn


func _set_pet_size_tier(tier: int) -> void:
	GameData.pet_size_tier = clampi(tier, GameData.PET_SIZE_SMALL, GameData.PET_SIZE_HUGE)
	_apply_pet_size()
	GameData.save_game()


func _apply_pet_size() -> void:
	_layout_area = GameData.pet_layout_area()
	_sync_pet_visual_rects()
	var win: Vector2i = GameData.pet_window_size()
	if not _overlay_window_open:
		_base_window_size = win
		if _can_move_window():
			_place_pet_window(win)
	else:
		_base_window_size = win
	_video_fitted = false
	_refresh_size_buttons()


func _sync_pet_visual_rects() -> void:
	var area: Rect2 = _layout_area
	if is_instance_valid(_pet_video):
		_pet_video.position = area.position
		_pet_video.size = area.size
	if is_instance_valid(_pet_frame):
		_pet_frame.position = area.position
		_pet_frame.size = area.size
	if is_instance_valid(_basin_frame):
		_basin_frame.position = area.position
		_basin_frame.size = area.size


func _place_pet_window(new_size: Vector2i) -> void:
	var old_size: Vector2i = DisplayServer.window_get_size()
	var old_pos: Vector2i = DisplayServer.window_get_position()
	var usable: Rect2i = DisplayServer.screen_get_usable_rect()
	var pos: Vector2i = old_pos + (old_size - new_size)
	var min_x: int = usable.position.x
	var min_y: int = usable.position.y
	var max_x: int = usable.position.x + usable.size.x - new_size.x
	var max_y: int = usable.position.y + usable.size.y - new_size.y
	pos.x = clampi(pos.x, min_x, maxi(min_x, max_x))
	pos.y = clampi(pos.y, min_y, maxi(min_y, max_y))
	DisplayServer.window_set_size(new_size)
	DisplayServer.window_set_position(pos)


func _refresh_size_buttons() -> void:
	var tier: int = GameData.pet_size_tier
	if is_instance_valid(_size_small_button):
		_size_small_button.disabled = tier == GameData.PET_SIZE_SMALL
	if is_instance_valid(_size_medium_button):
		_size_medium_button.disabled = tier == GameData.PET_SIZE_MEDIUM
	if is_instance_valid(_size_large_button):
		_size_large_button.disabled = tier == GameData.PET_SIZE_LARGE
	if is_instance_valid(_size_huge_button):
		_size_huge_button.disabled = tier == GameData.PET_SIZE_HUGE


func _refresh_stat_bubbles() -> void:
	if is_instance_valid(_bubble_affinity):
		_bubble_affinity.text = "❤  好感度  %d" % int(round(GameData.affinity_score()))
	if is_instance_valid(_bubble_underwear):
		_bubble_underwear.text = "🩲  内裤总计  %d条" % GameData.underwear_total
	if is_instance_valid(_bubble_companion):
		_bubble_companion.text = "⏰  陪伴时长  %s" % GameData.format_companion_clock()
	if is_instance_valid(_bubble_runaway):
		_bubble_runaway.text = "🏃  跑路次数  %d" % GameData.runaway_count


func _log(message: String) -> void:
	if _debug_log:
		print("[Steve] ", message)
