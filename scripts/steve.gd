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
@onready var _dryer_slot: Button = %DryerSlot
@onready var _drawer_slot: Button = %DrawerSlot
@onready var _size_small_button: Button = %SizeSmallButton
@onready var _size_medium_button: Button = %SizeMediumButton
@onready var _size_large_button: Button = %SizeLargeButton
@onready var _size_huge_button: Button = %SizeHugeButton
@onready var _pressure_button: Button = %PressureWashButton
@onready var _movie_button: Button = %MovieButton
@onready var _dinner_button: Button = %DinnerButton
@onready var _chat_button: Button = %ChatButton
@onready var _fortune_button: Button = %FortuneButton
@onready var _recharge_button: Button = %RechargeButton
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
@onready var _dryer_hint_button: Button = %DryerHintButton
@onready var _inventory_close_button: Button = %InventoryCloseButton
@onready var _tidy_button: Button = %TidyButton
@onready var _tidy_panel: Control = %TidyPanel
@onready var _tidy_quality_box: Container = %TidyQualityBox
@onready var _tidy_wear_box: Container = %TidyWearBox
@onready var _tidy_delete_button: Button = %TidyDeleteButton
@onready var _tidy_cancel_button: Button = %TidyCancelButton
@onready var _inventory_grid: GridContainer = %InventoryGrid
@onready var _inventory_scroll: ScrollContainer = %InventoryScroll
@onready var _inventory_empty: Label = %InventoryEmpty
@onready var _inventory_bg: TextureRect = %InventoryBg
@onready var _hover_hud: Control = %HoverHud
@onready var _water_bar: ProgressBar = %WaterBar
@onready var _wash_label: Label = %WashLabel
@onready var _chat_popup: Control = %ChatPopup
@onready var _chat_chrome: Panel = %ChatChrome
@onready var _chat_headline: PanelContainer = %ChatHeadline
@onready var _chat_title: Label = %ChatTitle
@onready var _chat_close_button: Button = %ChatCloseButton
@onready var _chat_scroll: ScrollContainer = %ChatScroll
@onready var _chat_list: VBoxContainer = %ChatList
@onready var _chat_input: LineEdit = %ChatInput
@onready var _chat_send_button: Button = %ChatSendButton
@onready var _menu_scroll: ScrollContainer = %MenuScroll

var _fortune_popup: Control
var _fortune_chrome: Panel
var _fortune_title: Label
var _fortune_hint: Label
var _fortune_readout: Label
var _fortune_result: Label
var _fortune_ask_button: Button
var _fortune_close_button: Button
var _fortune_year: OptionButton
var _fortune_month: OptionButton
var _fortune_day: OptionButton
var _fortune_hour: OptionButton
var _fortune_scroll: ScrollContainer
var _fortune_client: HTTPRequest
var _fortune_busy: bool = false
var _fortune_filling: bool = false

var _movie_popup: Control
var _movie_chrome: Panel
var _movie_title: Label
var _movie_player: VideoStreamPlayer
var _movie_mute_button: Button
var _movie_max_button: Button
var _movie_close_button: Button
var _movie_skip_button: Button
var _movie_volume: HSlider
var _movie_seek: HSlider
var _movie_speed_box: HBoxContainer
var _movie_client: HTTPRequest
var _movie_loading: bool = false
var _movie_muted: bool = false
var _movie_seeking: bool = false
var _movie_volume_linear: float = GameData.MOVIE_VOLUME_DEFAULT
var _movie_speed: float = 1.0
var _movie_maximized: bool = false
var _movie_restore_size: Vector2i = GameData.MOVIE_WINDOW_SIZE
var _movie_restore_pos: Vector2i = Vector2i.ZERO
var _movie_resizing: bool = false
var _movie_resize_edge: Vector2i = Vector2i.ZERO
var _movie_resize_start_mouse: Vector2i = Vector2i.ZERO
var _movie_resize_start_pos: Vector2i = Vector2i.ZERO
var _movie_resize_start_size: Vector2i = Vector2i.ZERO
var _movie_path: String = ""
var _movie_id: String = ""
var _movie_expected_bytes: int = 0
var _movie_reload_cd: float = 0.0
var _movie_last_bytes: int = 0
var _movie_genre: String = GameData.MOVIE_GENRE_ALL
var _movie_pick_popup: Control
var _movie_pick_chrome: Panel
var _chat_scroll_token: int = 0
var _dryer_hint_bubble: PanelContainer
var _dryer_hint_label: Label
var _dryer_hint_wired: bool = false
var _recharge_popup: Control
var _recharge_chrome: Panel
var _recharge_status: Label
var _recharge_notes: Label
var _recharge_sku_box: HBoxContainer
var _recharge_region_box: HBoxContainer
var _recharge_region: String = GameData.RECHARGE_REGION_US
var _recharge_client: RefCounted

var _state: int = State.WASHING
var _wash_remaining: float = 0.0
var _cooldown_remaining: float = 0.0
var _tap_speedup_cd: float = 0.0
var _chat_send_cd: float = 0.0
var _chat_client: HTTPRequest

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
var _container_texture: Texture2D
var _layout_area: Rect2 = GameData.PET_AREA
var _pressure_cd: float = 0.0
var _pressure_cd_text: String = ""
var _notice_panel: PanelContainer
var _notice_label: Label
var _notice_tween: Tween
var _flash_panel: PanelContainer
var _flash_label: Label
var _flash_tween: Tween
var _pending_steve_notice: String = ""
var _speech_target: String = ""
var _notice_wired: bool = false
var _chat_thread_wrapped: bool = false


func _ready() -> void:
	get_tree().root.gui_embed_subwindows = false
	_debug_log = OS.get_cmdline_user_args().has("--petlog")
	print("%s build=qualities-wear-dryer-drawer  scene=%s  menu=emoji+50cutouts" % [
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
	UnderwearArt.texture_for({"id": 1, "art_index": 0, "quality": 0})
	_apply_round_chrome()
	_apply_video_key()
	_apply_menu_icons()
	_setup_chat_client()
	_setup_fortune_ui()
	_setup_movie_ui()
	_setup_recharge_ui()
	_ensure_notice_nodes()
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
		_inventory_title, _inventory_empty,
		_inventory_chrome, _inventory_mask,
		_hover_hud, _water_bar, _wash_label,
	]
	if is_instance_valid(_inventory_bg):
		_inventory_bg.visible = false
		_inventory_bg.texture = null
		_inventory_bg.material = null
		ignore_nodes.append(_inventory_bg)
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
	var container_path: String = GameData.first_existing_file(GameData.USER_CONTAINER_FILE)
	if not container_path.is_empty() and not container_path.begins_with("res://assets/images/"):
		GameData.copy_file(container_path, "res://assets/images/container.jpg")
	_container_texture = GameData.load_image_texture(GameData.USER_CONTAINER_FILE)
	if _container_texture != null and is_instance_valid(_basin_frame):
		_basin_frame.texture = _container_texture
		print("%s basin <- %s" % [VIDEO_LOG_PREFIX, container_path])
	var steve2_path: String = GameData.first_existing_named(GameData.USER_STEVE2_ALIASES)
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
		"PinkButton",
		"OptionButton",
	]
	var white: Color = GameData.UI_FONT_COLOR
	var outline: Color = GameData.UI_FONT_OUTLINE_COLOR
	var outline_size: int = GameData.UI_FONT_OUTLINE_SIZE
	var size: int = GameData.UI_FONT_SIZE
	for type_name: String in types:
		target.set_font("font", type_name, font)
		target.set_font_size("font_size", type_name, size)
		target.set_color("font_color", type_name, white)
		target.set_color("font_outline_color", type_name, outline)
		target.set_constant("outline_size", type_name, outline_size)
		target.set_color("font_shadow_color", type_name, Color(0, 0, 0, 0.85))
		if type_name.ends_with("Button") or type_name == "Button":
			target.set_color("font_disabled_color", type_name, white)
			target.set_color("font_focus_color", type_name, white)
			target.set_color("font_hover_color", type_name, white)
			target.set_color("font_pressed_color", type_name, white)
			target.set_color("font_hover_pressed_color", type_name, white)
			target.set_color("font_outline_color", type_name, outline)
			target.set_constant("outline_size", type_name, outline_size)
	for line_type: String in ["LineEdit", "TextEdit"]:
		target.set_font("font", line_type, font)
		target.set_font_size("font_size", line_type, size)
		target.set_color("font_color", line_type, white)
		target.set_color("font_placeholder_color", line_type, Color(1.0, 1.0, 1.0, 0.72))
		target.set_color("caret_color", line_type, white)
		target.set_color("font_outline_color", line_type, outline)
		target.set_constant("outline_size", line_type, outline_size)


func _unify_control_text(node: Node, font: FontFile) -> void:
	if node is Control:
		var control: Control = node as Control
		if control is Label or control is Button or control is ProgressBar or control is LineEdit:
			control.add_theme_font_override("font", font)
			control.add_theme_font_size_override("font_size", GameData.UI_FONT_SIZE)
			control.add_theme_color_override("font_color", GameData.UI_FONT_COLOR)
			control.add_theme_color_override("font_outline_color", GameData.UI_FONT_OUTLINE_COLOR)
			control.add_theme_constant_override("outline_size", GameData.UI_FONT_OUTLINE_SIZE)
			if control is Button:
				var button: Button = control as Button
				button.add_theme_color_override("font_disabled_color", GameData.UI_FONT_COLOR)
				button.add_theme_color_override("font_focus_color", GameData.UI_FONT_COLOR)
				button.add_theme_color_override("font_hover_color", GameData.UI_FONT_COLOR)
				button.add_theme_color_override("font_pressed_color", GameData.UI_FONT_COLOR)
			if control is LineEdit:
				var line: LineEdit = control as LineEdit
				line.add_theme_color_override("font_placeholder_color", Color(1.0, 1.0, 1.0, 0.72))
				line.add_theme_color_override("caret_color", GameData.UI_FONT_COLOR)
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
		control.add_theme_color_override("font_outline_color", GameData.UI_FONT_OUTLINE_COLOR)
		control.add_theme_constant_override("outline_size", GameData.UI_FONT_OUTLINE_SIZE)
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
		_dryer_slot.text = GameData.DRYER_BUTTON_TEXT
	if is_instance_valid(_drawer_slot):
		_drawer_slot.custom_minimum_size.y = GameData.MENU_SLOT_HEIGHT
		_drawer_slot.text = GameData.DRAWER_BUTTON_TEXT
	if is_instance_valid(_pressure_button):
		_pressure_button.custom_minimum_size.y = GameData.MENU_ACTION_HEIGHT
	if is_instance_valid(_chat_button):
		_chat_button.custom_minimum_size.y = GameData.MENU_ACTION_HEIGHT
		_chat_button.text = GameData.CHAT_BUTTON_TEXT
	if is_instance_valid(_fortune_button):
		_fortune_button.custom_minimum_size.y = GameData.MENU_ACTION_HEIGHT
		_fortune_button.text = GameData.FORTUNE_BUTTON_TEXT
	if is_instance_valid(_movie_button):
		_movie_button.custom_minimum_size.y = GameData.MENU_ACTION_HEIGHT
		if not _movie_loading:
			_movie_button.text = GameData.MOVIE_BUTTON_TEXT
	if is_instance_valid(_dinner_button):
		_dinner_button.custom_minimum_size.y = GameData.MENU_ACTION_HEIGHT
		_dinner_button.text = GameData.DINNER_BUTTON_TEXT
		_style_dinner_button()
	if is_instance_valid(_recharge_button):
		_recharge_button.custom_minimum_size.y = GameData.MENU_ACTION_HEIGHT
		_recharge_button.text = GameData.RECHARGE_BUTTON_TEXT
	if is_instance_valid(_settings_button):
		_settings_button.custom_minimum_size.y = GameData.MENU_ACTION_HEIGHT
		_settings_button.text = GameData.SETTINGS_BUTTON_TEXT
	if is_instance_valid(_quit_app_button):
		_quit_app_button.custom_minimum_size.y = GameData.MENU_ACTION_HEIGHT
		_quit_app_button.text = GameData.QUIT_BUTTON_TEXT
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
	_movie_button.pressed.connect(func() -> void:
		_on_movie_pressed()
	)
	_dinner_button.pressed.connect(func() -> void:
		_on_demo_feature_pressed("dinner")
	)
	_chat_button.pressed.connect(func() -> void:
		_open_chat()
	)
	if is_instance_valid(_fortune_button):
		_fortune_button.pressed.connect(func() -> void:
			_open_fortune()
		)
	_recharge_button.pressed.connect(func() -> void:
		_open_recharge()
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
			_refresh_context_menu_window()
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
	_tidy_button.pressed.connect(func() -> void:
		_toggle_tidy_panel()
	)
	_tidy_delete_button.pressed.connect(func() -> void:
		_confirm_tidy_delete()
	)
	_tidy_cancel_button.pressed.connect(func() -> void:
		_set_tidy_panel_visible(false)
	)
	_build_tidy_filters()
	_chat_close_button.pressed.connect(func() -> void:
		_close_chat()
	)
	_chat_send_button.pressed.connect(func() -> void:
		_submit_chat()
	)
	_chat_input.text_submitted.connect(func(_text: String) -> void:
		_submit_chat()
	)
	_inventory_popup.gui_input.connect(func(event: InputEvent) -> void:
		_process_drag_input(event)
	)
	_chat_popup.gui_input.connect(func(event: InputEvent) -> void:
		_process_drag_input(event)
	)
	_exit_popup.gui_input.connect(func(event: InputEvent) -> void:
		_process_drag_input(event)
	)
	_inventory_popup.resized.connect(func() -> void:
		pass
	)
	_exit_popup.resized.connect(func() -> void:
		pass
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
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and mb.double_click:
			if (
				not _inventory_popup.visible
				and not _exit_popup.visible
				and not _chat_popup.visible
				and not _fortune_open()
				and not _movie_open()
				and not _speech_visible()
				and _is_pointer_on_pet(mb.position)
			):
				_try_tap_speedup()
				accept_event()
				return
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if _inventory_popup.visible:
				_close_inventory()
				accept_event()
				return
			if _chat_popup.visible:
				_close_chat()
				accept_event()
				return
			if _movie_pick_open():
				_close_movie_pick()
				accept_event()
				return
			if _recharge_open():
				_close_recharge()
				accept_event()
				return
			if _fortune_open():
				_close_fortune()
				accept_event()
				return
			if _movie_open():
				_close_movie()
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
			if _movie_open():
				_close_movie()
			elif _movie_pick_open():
				_close_movie_pick()
			elif _recharge_open():
				_close_recharge()
			elif _fortune_open():
				_close_fortune()
			elif _inventory_popup.visible:
				_close_inventory()
			elif _chat_popup.visible:
				_close_chat()
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
	if _texture_has_green_screen(texture):
		_apply_chroma_material(
			_pet_frame, chroma_key_similarity, chroma_key_smoothness, chroma_spill_suppression
		)
	else:
		_pet_frame.material = null


func _is_click_on_blocking_ui(global_pos: Vector2) -> bool:
	if _inventory_popup.visible and is_instance_valid(_inventory_close_button):
		if _inventory_close_button.get_global_rect().has_point(global_pos):
			return true
	if _chat_popup.visible:
		for control: Control in [_chat_close_button, _chat_send_button, _chat_input]:
			if is_instance_valid(control) and control.get_global_rect().has_point(global_pos):
				return true
	if _fortune_open():
		for control: Control in [
			_fortune_close_button, _fortune_ask_button,
			_fortune_year, _fortune_month, _fortune_day, _fortune_hour,
		]:
			if is_instance_valid(control) and control.get_global_rect().has_point(global_pos):
				return true
	if _speech_visible() and is_instance_valid(_notice_panel) and _notice_panel.get_global_rect().has_point(global_pos):
		return true
	if _movie_open():
		for control: Control in [
			_movie_close_button, _movie_max_button, _movie_mute_button,
			_movie_volume, _movie_seek, _movie_speed_box,
		]:
			if is_instance_valid(control) and control.get_global_rect().has_point(global_pos):
				return true
	if _exit_popup.visible:
		return _is_point_on_menu_button(global_pos)
	return false


func _is_point_on_menu_button(global_pos: Vector2) -> bool:
	var buttons: Array[Button] = [
		_dryer_slot, _drawer_slot, _pressure_button, _movie_button,
		_dinner_button, _chat_button, _fortune_button, _recharge_button, _settings_button,
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
			if _movie_resizing:
				return
			var overlay_open: bool = _any_overlay_open()
			if not overlay_open and not _is_pointer_on_pet(get_local_mouse_position()):
				return
			if not _can_move_window():
				return
			_dragging = true
			_drag_offset = DisplayServer.mouse_get_position() - DisplayServer.window_get_position()
		else:
			_dragging = false
			_movie_resizing = false
		return
	if event is InputEventMouseMotion:
		if _movie_resizing:
			_apply_movie_resize()
			return
		if _dragging:
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
	_tick_tap_speedup_cooldown(delta)
	if _chat_send_cd > 0.0:
		_chat_send_cd = maxf(_chat_send_cd - delta, 0.0)
	if _movie_client != null and _movie_client.has_method("poll"):
		if _movie_loading or (_movie_open() and _movie_client.is_busy()):
			_movie_client.poll(delta)
	_tick_movie_playback(delta)
	if _state != State.RUNAWAY:
		GameData.tick_work_presence(delta)
		if _can_show_speech_bubble() and GameData.consume_work_break():
			_show_notice(GameData.WORK_BREAK_TEXT)
	GameData.tick_companion(delta)
	_tick_dryer_hint_hover()
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


func _cancel_dry_timer(item_id: int) -> void:
	if not _dry_timers.has(item_id):
		return
	var timer: Timer = _dry_timers[item_id] as Timer
	_dry_timers.erase(item_id)
	if is_instance_valid(timer):
		timer.stop()
		timer.queue_free()


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


func _on_demo_feature_pressed(feature_id: String) -> void:
	print("%s demo feature=%s (placeholder)" % [VIDEO_LOG_PREFIX, feature_id])


func _try_tap_speedup() -> void:
	if _tap_speedup_cd > 0.0:
		return
	_tap_speedup_cd = GameData.TAP_SPEEDUP_COOLDOWN
	if _state != State.WASHING:
		return
	_wash_remaining = maxf(_wash_remaining - GameData.TAP_SPEEDUP_SECONDS, 0.0)
	_show_speed_flash()


func _tick_tap_speedup_cooldown(delta: float) -> void:
	if _tap_speedup_cd <= 0.0:
		return
	_tap_speedup_cd = maxf(_tap_speedup_cd - delta, 0.0)


func _setup_chat_client() -> void:
	_chat_client = preload("res://scripts/chat_client.gd").new()
	add_child(_chat_client)
	_chat_client.chat_replied.connect(func(text: String) -> void:
		_on_chat_replied(text)
	)
	_chat_client.chat_failed.connect(func(reason: String) -> void:
		_on_chat_replied(GameData.chat_fail_text(reason))
	)


func _open_chat() -> void:
	if _state == State.RUNAWAY:
		return
	_hide_speech_bubble()
	if is_instance_valid(_exit_popup):
		_exit_popup.visible = false
	if is_instance_valid(_settings_panel):
		_settings_panel.visible = false
	if is_instance_valid(_inventory_popup):
		_inventory_popup.visible = false
	_hide_fortune_and_movie()
	_inventory_kind = ""
	_set_pet_layer_visible(false)
	_expand_overlay_window(GameData.CHAT_WINDOW_SIZE)
	if is_instance_valid(_chat_title):
		_chat_title.text = GameData.CHAT_TITLE_TEXT
	if is_instance_valid(_chat_headline):
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = GameData.DRYER_HEADLINE_COLOR
		box.set_corner_radius_all(8)
		box.set_border_width_all(2)
		box.border_color = Color(1.0, 1.0, 1.0, 0.92)
		box.content_margin_left = GameData.INVENTORY_HEADLINE_PAD_X
		box.content_margin_right = GameData.INVENTORY_HEADLINE_PAD_X
		box.content_margin_top = 6.0
		box.content_margin_bottom = 6.0
		_chat_headline.add_theme_stylebox_override("panel", box)
	if is_instance_valid(_chat_input):
		_chat_input.max_length = GameData.CHAT_MAX_INPUT_CHARS
		_chat_input.placeholder_text = GameData.CHAT_INPUT_HINT
	if is_instance_valid(_chat_send_button):
		_chat_send_button.text = GameData.CHAT_SEND_TEXT
	_chat_popup.visible = true
	GameData.prune_chat_history()
	_rebuild_chat_list()
	_set_chat_composer_enabled(true)
	if is_instance_valid(_chat_input):
		if not GameData.chat_api_ready():
			_chat_input.placeholder_text = GameData.CHAT_UNCONFIGURED_HINT
		_chat_input.grab_focus()


func _close_chat() -> void:
	if is_instance_valid(_chat_popup):
		_chat_popup.visible = false
	_hide_speech_bubble()
	_restore_overlay_window_if_idle()
	if not _any_overlay_open() and _state != State.RUNAWAY:
		_set_pet_layer_visible(true)
	call_deferred("_try_show_speech")


func _submit_chat() -> void:
	if _chat_send_cd > 0.0:
		return
	if _chat_client != null and _chat_client.has_method("is_busy") and _chat_client.is_busy():
		return
	if not is_instance_valid(_chat_input):
		return
	var text: String = GameData.sanitize_chat_input(_chat_input.text)
	if text.is_empty():
		return
	_chat_send_cd = GameData.CHAT_SEND_COOLDOWN
	_chat_input.text = ""
	GameData.append_chat_message("user", text)
	_rebuild_chat_list()
	_set_chat_composer_enabled(false)
	if _chat_client != null and _chat_client.has_method("send_history"):
		_chat_client.send_history(GameData.chat_context_for_api())
	else:
		_on_chat_replied(GameData.CHAT_OFFLINE_REPLY)


func _on_chat_replied(text: String) -> void:
	var reply: String = GameData.sanitize_chat_output(text)
	if reply.is_empty():
		reply = GameData.CHAT_FAIL_TEXT
	GameData.append_chat_message("assistant", reply)
	_rebuild_chat_list()
	_queue_steve_notice(reply, "chat")
	_set_chat_composer_enabled(true)
	if is_instance_valid(_chat_input):
		_chat_input.grab_focus()


func _set_chat_composer_enabled(enabled: bool) -> void:
	if is_instance_valid(_chat_input):
		_chat_input.editable = enabled
		if not enabled:
			_chat_input.placeholder_text = GameData.CHAT_WAIT_TEXT
		else:
			_chat_input.placeholder_text = GameData.CHAT_INPUT_HINT
	if is_instance_valid(_chat_send_button):
		_chat_send_button.disabled = not enabled


func _rebuild_chat_list() -> void:
	if not is_instance_valid(_chat_list):
		return
	for child: Node in _chat_list.get_children():
		child.queue_free()
	for item: Dictionary in GameData.chat_messages:
		_chat_list.add_child(_make_chat_row(item))
	_chat_scroll_token += 1
	_scroll_chat_to_end(_chat_scroll_token)


func _make_chat_row(item: Dictionary) -> Control:
	var is_user: bool = String(item.get("role", "")) == "user"
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	var name_label: Label = Label.new()
	name_label.text = GameData.CHAT_USER_NAME if is_user else GameData.CHAT_STEVE_NAME
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if is_user else HORIZONTAL_ALIGNMENT_LEFT
	name_label.add_theme_font_size_override("font_size", GameData.UI_FONT_SIZE)
	name_label.add_theme_color_override("font_color", GameData.UI_FONT_COLOR)
	name_label.add_theme_color_override("font_outline_color", GameData.UI_FONT_OUTLINE_COLOR)
	name_label.add_theme_constant_override("outline_size", GameData.UI_FONT_OUTLINE_SIZE)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bubble: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = GameData.WHATSAPP_OUTGOING_COLOR if is_user else GameData.WHATSAPP_INCOMING_COLOR
	box.corner_radius_top_left = 12
	box.corner_radius_top_right = 12
	if is_user:
		box.corner_radius_bottom_left = 12
		box.corner_radius_bottom_right = 4
	else:
		box.corner_radius_bottom_left = 4
		box.corner_radius_bottom_right = 12
	box.set_content_margin_all(10.0)
	bubble.add_theme_stylebox_override("panel", box)
	var body: Label = Label.new()
	body.text = String(item.get("text", ""))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", GameData.UI_FONT_SIZE)
	body.add_theme_color_override("font_color", GameData.UI_FONT_COLOR)
	body.add_theme_color_override("font_outline_color", GameData.UI_FONT_OUTLINE_COLOR)
	body.add_theme_constant_override("outline_size", GameData.UI_FONT_OUTLINE_SIZE)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(body)
	col.add_child(name_label)
	col.add_child(bubble)
	if is_user:
		row.add_child(spacer)
		row.add_child(col)
	else:
		row.add_child(col)
		row.add_child(spacer)
	return row


func _scroll_chat_to_end(token: int = -1) -> void:
	if token < 0:
		token = _chat_scroll_token
	if not is_instance_valid(_chat_scroll) or not is_instance_valid(_chat_list):
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	for _i: int in 8:
		await tree.process_frame
		if token != _chat_scroll_token:
			return
		if not is_instance_valid(_chat_scroll) or not is_instance_valid(_chat_list):
			return
		var bar: ScrollBar = _chat_scroll.get_v_scroll_bar()
		_chat_scroll.scroll_vertical = int(bar.max_value)
		if _chat_list.get_child_count() <= 0:
			continue
		var last: Control = _chat_list.get_child(_chat_list.get_child_count() - 1) as Control
		if last != null:
			_chat_scroll.ensure_control_visible(last)
		_chat_scroll.scroll_vertical = int(bar.max_value)


func _trigger_runaway() -> void:
	_state = State.RUNAWAY
	_cooldown_remaining = GameData.get_calculated_cooldown()
	_dragging = false
	GameData.record_runaway()
	_close_exit_popup()
	_close_inventory()
	_close_chat()
	_close_fortune()
	_close_movie()
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
	if _is_usable_ogv(USER_CACHE_OGV):
		print("%s using user cache %s" % [VIDEO_LOG_PREFIX, USER_CACHE_OGV])
		return USER_CACHE_OGV
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
		print("%s user video not found. project=%s  USER_PROJECT_DIR=%s  file=%s" % [
			VIDEO_LOG_PREFIX,
			ProjectSettings.globalize_path("res://"),
			GameData.USER_PROJECT_DIR,
			GameData.USER_VIDEO_FILE,
		])
		_log_project_video_files()
		return ""
	print_rich("[color=#54d18c]%s找到本机素材：%s[/color]" % [VIDEO_LOG_PREFIX, source])
	if source.get_extension().to_lower() == "ogv":
		return source if _is_usable_ogv(source) else ""
	var dest_res: String = ProjectSettings.globalize_path(VIDEO_PATH)
	var dest_user: String = ProjectSettings.globalize_path(USER_CACHE_OGV)
	var src_mtime: int = FileAccess.get_modified_time(source)
	if _is_usable_ogv(VIDEO_PATH) and FileAccess.get_modified_time(VIDEO_PATH) >= src_mtime:
		print("%s project ogv is newer than %s" % [VIDEO_LOG_PREFIX, source])
		return VIDEO_PATH
	if _is_usable_ogv(USER_CACHE_OGV) and FileAccess.get_modified_time(USER_CACHE_OGV) >= src_mtime:
		print("%s chroma-ready cache hit: %s" % [VIDEO_LOG_PREFIX, USER_CACHE_OGV])
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
		"steve3.MP4",
		"steve 3.mp4",
		"steve.mp4",
		"Steve.mp4",
		"steve3.ogv",
		"Steve3.ogv",
	])
	for file_name: String in names:
		var path: String = GameData.first_existing_file(file_name)
		if not path.is_empty():
			print("%s named hit %s" % [VIDEO_LOG_PREFIX, path])
			return path
	var scanned: String = _scan_steve_video_file()
	if not scanned.is_empty():
		return scanned
	return _windows_dir_videos()


func _scan_steve_video_file() -> String:
	var dirs: PackedStringArray = GameData.runtime_asset_dirs()
	for dir_path: String in dirs:
		var found: String = _scan_dir_for_steve_video(dir_path, 0)
		if not found.is_empty():
			return found
	return ""


func _scan_dir_for_steve_video(dir_path: String, depth: int) -> String:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return ""
	var files: PackedStringArray = dir.get_files()
	var mp4_hit: String = ""
	var project_local: bool = dir_path.begins_with("res://") or _path_is_project(dir_path)
	for file_name: String in files:
		var low: String = file_name.to_lower()
		var named_steve: bool = "steve" in low or "sun" in low
		if not named_steve and not project_local:
			continue
		var full: String = "%s/%s" % [dir_path.rstrip("/").rstrip("\\"), file_name]
		if low.ends_with(".mp4") or low.ends_with(".mov") or low.ends_with(".mkv"):
			if GameData.file_byte_count(full) <= GameData.STUB_VIDEO_MAX_BYTES:
				continue
			print("%s scan hit %s" % [VIDEO_LOG_PREFIX, full])
			if mp4_hit.is_empty() or "steve3" in low:
				mp4_hit = full
		if low.ends_with(".ogv") and _is_usable_ogv(full):
			print("%s scan hit %s" % [VIDEO_LOG_PREFIX, full])
			return full
	if not mp4_hit.is_empty():
		return mp4_hit
	if depth >= 1:
		return ""
	for sub: String in dir.get_directories():
		if sub.begins_with("."):
			continue
		var low_sub: String = sub.to_lower()
		if low_sub in ["godot", "node_modules", ".git"]:
			continue
		var nested: String = _scan_dir_for_steve_video("%s/%s" % [dir_path.rstrip("/").rstrip("\\"), sub], depth + 1)
		if not nested.is_empty():
			return nested
	return ""


func _path_is_project(dir_path: String) -> bool:
	var root: String = ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/").to_lower()
	var clean: String = dir_path.replace("\\", "/").trim_suffix("/").to_lower()
	return clean == root or clean.begins_with(root + "/")


func _windows_dir_videos() -> String:
	if OS.get_name() != "Windows":
		return ""
	var roots: PackedStringArray = PackedStringArray([
		ProjectSettings.globalize_path("res://"),
		GameData.USER_PROJECT_DIR,
	])
	var profile: String = OS.get_environment("USERPROFILE")
	if not profile.is_empty():
		roots.append("%s/Desktop" % profile)
		roots.append("%s/Downloads" % profile)
		roots.append("%s/Videos" % profile)
		roots.append("%s/Documents" % profile)
	var best: String = ""
	var best_score: int = -1
	for root: String in roots:
		var output: Array = []
		var pattern: String = "%s\\*.mp4" % root.replace("/", "\\").rstrip("\\")
		var code: int = OS.execute("cmd.exe", PackedStringArray(["/c", "dir", "/s", "/b", pattern]), output, true)
		if code != 0:
			continue
		for line: Variant in output:
			for piece: String in String(line).split("\n"):
				var path: String = piece.strip_edges()
				if path.is_empty() or not FileAccess.file_exists(path):
					continue
				var low: String = path.replace("\\", "/").to_lower()
				if "/.git/" in low or "/.godot/" in low:
					continue
				var bytes: int = GameData.file_byte_count(path)
				if bytes <= GameData.STUB_VIDEO_MAX_BYTES:
					continue
				var score: int = bytes
				if "steve3" in low:
					score += 1 << 30
				elif "steve" in low:
					score += 1 << 29
				if score > best_score:
					best_score = score
					best = path
	if not best.is_empty():
		print("%s windows dir hit %s" % [VIDEO_LOG_PREFIX, best])
	return best


func _log_project_video_files() -> void:
	var root: String = ProjectSettings.globalize_path("res://")
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return
	var shown: PackedStringArray = PackedStringArray()
	for file_name: String in dir.get_files():
		var low: String = file_name.to_lower()
		if low.ends_with(".mp4") or low.ends_with(".mov") or low.ends_with(".mkv") or low.ends_with(".ogv"):
			shown.append("%s (%d)" % [file_name, GameData.file_byte_count("%s/%s" % [root.rstrip("/"), file_name])])
	print("%s project-root videos: %s" % [
		VIDEO_LOG_PREFIX, ", ".join(shown) if not shown.is_empty() else "(none)",
	])


func _ffmpeg_bin() -> String:
	var output: Array = []
	if OS.get_name() == "Windows":
		var where_code: int = OS.execute("where.exe", PackedStringArray(["ffmpeg"]), output, true)
		if where_code != 0:
			output.clear()
			where_code = OS.execute("cmd.exe", PackedStringArray(["/c", "where", "ffmpeg"]), output, true)
		if where_code == 0:
			for line: Variant in output:
				for piece: String in String(line).split("\n"):
					var path: String = piece.strip_edges().trim_prefix("\"").trim_suffix("\"")
					if path.to_lower().ends_with("ffmpeg.exe") and FileAccess.file_exists(path):
						return path
		for path: String in GameData.FFMPEG_GUESSES:
			if FileAccess.file_exists(path):
				return path
		for dir_path: String in GameData.runtime_asset_dirs():
			var guess: String = "%s/ffmpeg.exe" % dir_path
			if FileAccess.file_exists(guess):
				return guess
			var guess2: String = "%s/bin/ffmpeg.exe" % dir_path
			if FileAccess.file_exists(guess2):
				return guess2
	else:
		var code: int = OS.execute("which", PackedStringArray(["ffmpeg"]), output, true)
		if code == 0:
			for line: Variant in output:
				var path: String = String(line).strip_edges()
				if not path.is_empty() and FileAccess.file_exists(path):
					return path
	return "ffmpeg"


func _run_ffmpeg_theora(source: String, dest_os: String) -> bool:
	var ffmpeg: String = _ffmpeg_bin()
	print("%s ffmpeg=%s  src=%s  dest=%s" % [VIDEO_LOG_PREFIX, ffmpeg, source, dest_os])
	DirAccess.make_dir_recursive_absolute(dest_os.get_base_dir())
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
		var code: int = 0
		if ffmpeg.contains("/") or ffmpeg.contains("\\"):
			code = OS.execute(ffmpeg, args, output, true)
		elif OS.get_name() == "Windows":
			var cmd: PackedStringArray = PackedStringArray(["/c", "ffmpeg"])
			cmd.append_array(args)
			code = OS.execute("cmd.exe", cmd, output, true)
		else:
			code = OS.execute(ffmpeg, args, output, true)
		print("%s ffmpeg exit=%d dest=%s" % [VIDEO_LOG_PREFIX, code, dest_os])
		if code != 0:
			print("%s ffmpeg log: %s" % [VIDEO_LOG_PREFIX, str(output)])
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
		if file_name.get_extension().to_lower() in ["uid", "import", "remap", "md", "gdshader", "gitkeep"]:
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
	var still: Texture2D = null
	var steve2_name: String = GameData.first_existing_named(GameData.USER_STEVE2_ALIASES)
	if not steve2_name.is_empty():
		still = GameData.load_image_texture(steve2_name.get_file())
	if still == null:
		still = GameData.load_image_texture(GameData.USER_STEVE2_FILE)
	if still != null:
		_placeholder_from_still(still)
		print_rich("[color=#ff8b6a]%s未启用动态立绘，已回落到 Steve2 静帧。[/color]" % VIDEO_LOG_PREFIX)
	else:
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


func _texture_has_green_screen(texture: Texture2D) -> bool:
	if texture == null:
		return false
	var image: Image = texture.get_image()
	if image == null:
		return false
	var w: int = image.get_width()
	var h: int = image.get_height()
	if w < 4 or h < 4:
		return false
	var samples: Array[Color] = [
		image.get_pixel(1, 1),
		image.get_pixel(w - 2, 1),
		image.get_pixel(1, h - 2),
		image.get_pixel(w - 2, h - 2),
	]
	var hits: int = 0
	for color: Color in samples:
		if color.g > 0.55 and color.g > color.r + 0.18 and color.g > color.b + 0.18:
			hits += 1
	return hits >= 3


func _apply_smart_chroma(rect: TextureRect, similarity: float, smoothness: float, spill: float) -> void:
	if not is_instance_valid(rect):
		return
	if rect.texture != null and _texture_has_green_screen(rect.texture):
		_apply_chroma_material(rect, similarity, smoothness, spill)
	else:
		rect.material = null


func _apply_video_key() -> void:
	if not chroma_key_enabled:
		if is_instance_valid(_pet_frame):
			_pet_frame.material = null
		return
	if _video_enabled:
		_apply_chroma_material(_pet_frame, chroma_key_similarity, chroma_key_smoothness, chroma_spill_suppression)
	else:
		_apply_smart_chroma(_pet_frame, chroma_key_similarity, chroma_key_smoothness, chroma_spill_suppression)
	if is_instance_valid(_basin_frame) and _basin_frame.visible:
		_apply_smart_chroma(_basin_frame, chroma_key_similarity, chroma_key_smoothness, chroma_spill_suppression)


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
	if _any_overlay_open() or _speech_visible():
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
	if _speech_visible():
		_layout_speech_bubble()
		if is_instance_valid(_hover_hud):
			_hover_hud.modulate.a = 0.0
	var progress: int = _wash_progress_value()
	_water_bar.max_value = float(GameData.WASH_PROGRESS_MAX)
	_water_bar.value = float(progress)
	_wash_label.text = "洗涤进度（%d/%d）" % [progress, GameData.WASH_PROGRESS_MAX]


func _tick_hover_hud(delta: float) -> void:
	if _speech_visible():
		_hover_time = 0.0
		if _hover_hud_shown:
			_set_hover_hud_visible(false, false)
		return
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
	return _pet_hit_rect().has_point(local_pos)


func _pet_hit_rect() -> Rect2:
	var raw: Rect2 = _current_pet_rect()
	if _state == State.RUNAWAY:
		return raw
	return GameData.pet_hit_rect(raw)


func _open_exit_popup() -> void:
	_hide_speech_bubble()
	_refresh_pressure_button()
	_refresh_stat_bubbles()
	if is_instance_valid(_settings_panel):
		_settings_panel.visible = false
	_set_pet_layer_visible(false)
	_expand_overlay_window(GameData.context_menu_window_size(false))
	_exit_popup.visible = true
	_apply_menu_icons()
	print_verbose("%s context menu open" % VIDEO_LOG_PREFIX)


func _close_exit_popup() -> void:
	if is_instance_valid(_exit_popup):
		_exit_popup.visible = false
	if is_instance_valid(_settings_panel):
		_settings_panel.visible = false
	_cancel_pending_movie_fetch()
	_restore_overlay_window_if_idle()
	if not _any_content_overlay_open() and _state != State.RUNAWAY:
		_set_pet_layer_visible(true)
	call_deferred("_try_show_speech")


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
		_hide_speech_bubble()
		_show_runaway_basin(true)
		return
	if is_instance_valid(_pet_visual):
		_pet_visual.visible = shown
	_set_video_playing(shown)
	if not shown:
		_hide_speech_bubble()
		_hover_time = 0.0
		_set_hover_hud_visible(false, false)


func _apply_inventory_background(_kind: String) -> void:
	if is_instance_valid(_inventory_bg):
		_inventory_bg.texture = null
		_inventory_bg.material = null
		_inventory_bg.visible = false


func _apply_inventory_headline(kind: String) -> void:
	if not is_instance_valid(_inventory_headline) or not is_instance_valid(_inventory_title):
		return
	_refresh_inventory_count_title()
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
	_style_inventory_header_buttons()
	_style_dryer_hint_button(kind == "dryer")
	_set_tidy_panel_visible(false)


func _refresh_inventory_count_title() -> void:
	if not is_instance_valid(_inventory_title):
		return
	var items: Array[Dictionary] = (
		GameData.wet_warehouse if _inventory_kind == "dryer" else GameData.dry_collection
	)
	_inventory_title.text = GameData.inventory_count_title(items.size())


func _style_dryer_hint_button(show_hint: bool) -> void:
	if not is_instance_valid(_dryer_hint_button):
		return
	_dryer_hint_button.visible = show_hint
	_dryer_hint_button.text = "?"
	_dryer_hint_button.tooltip_text = ""
	_dryer_hint_button.focus_mode = Control.FOCUS_NONE
	_dryer_hint_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_dryer_hint_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_dryer_hint_button.z_index = 24
	_dryer_hint_button.custom_minimum_size = Vector2(GameData.DRYER_HINT_SIZE, GameData.DRYER_HINT_SIZE)
	var radius: int = 8
	var slots: Dictionary = {
		"normal": Color(0.18, 0.18, 0.22, 1.0),
		"hover": Color(0.32, 0.32, 0.38, 1.0),
		"pressed": Color(0.12, 0.12, 0.16, 1.0),
		"disabled": Color(0.18, 0.18, 0.22, 1.0),
		"focus": Color(0.32, 0.32, 0.38, 1.0),
	}
	for slot: String in slots.keys():
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = slots[slot]
		box.set_corner_radius_all(radius)
		box.set_border_width_all(2)
		box.border_color = Color(1.0, 1.0, 1.0, 0.90)
		box.set_content_margin_all(0.0)
		_dryer_hint_button.add_theme_stylebox_override(slot, box)
	_dryer_hint_button.add_theme_font_size_override("font_size", GameData.UI_FONT_SIZE)
	_dryer_hint_button.add_theme_color_override("font_color", GameData.UI_FONT_COLOR)
	_dryer_hint_button.add_theme_color_override("font_hover_color", GameData.UI_FONT_COLOR)
	_dryer_hint_button.add_theme_color_override("font_pressed_color", GameData.UI_FONT_COLOR)
	_dryer_hint_button.add_theme_color_override("font_outline_color", GameData.UI_FONT_OUTLINE_COLOR)
	_dryer_hint_button.add_theme_constant_override("outline_size", GameData.UI_FONT_OUTLINE_SIZE)
	_ensure_dryer_hint_bubble()
	if not _dryer_hint_wired:
		_dryer_hint_wired = true
		_dryer_hint_button.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton:
				var mb: InputEventMouseButton = event
				if mb.button_index == MOUSE_BUTTON_LEFT:
					_dryer_hint_button.accept_event()
		)
	if not show_hint:
		_show_dryer_hint_bubble(false)


func _ensure_dryer_hint_bubble() -> void:
	if is_instance_valid(_dryer_hint_bubble):
		return
	_dryer_hint_bubble = PanelContainer.new()
	_dryer_hint_bubble.name = "DryerHintBubble"
	_dryer_hint_bubble.visible = false
	_dryer_hint_bubble.z_index = 80
	_dryer_hint_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dryer_hint_bubble.custom_minimum_size = Vector2(260.0, 0.0)
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(0.10, 0.11, 0.16, 1.0)
	box.set_corner_radius_all(10)
	box.set_border_width_all(2)
	box.border_color = Color(1.0, 1.0, 1.0, 0.88)
	box.set_content_margin_all(10.0)
	_dryer_hint_bubble.add_theme_stylebox_override("panel", box)
	_dryer_hint_label = Label.new()
	_dryer_hint_label.text = GameData.DRYER_HINT_TEXT
	_dryer_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dryer_hint_label.custom_minimum_size.x = 240.0
	_dryer_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dryer_hint_label.add_theme_font_size_override("font_size", GameData.UI_FONT_SIZE)
	_dryer_hint_label.add_theme_color_override("font_color", GameData.UI_FONT_COLOR)
	_dryer_hint_label.add_theme_color_override("font_outline_color", GameData.UI_FONT_OUTLINE_COLOR)
	_dryer_hint_label.add_theme_constant_override("outline_size", GameData.UI_FONT_OUTLINE_SIZE)
	_dryer_hint_bubble.add_child(_dryer_hint_label)
	if is_instance_valid(_inventory_popup):
		_inventory_popup.add_child(_dryer_hint_bubble)


func _show_dryer_hint_bubble(shown: bool) -> void:
	_ensure_dryer_hint_bubble()
	if not is_instance_valid(_dryer_hint_bubble):
		return
	if not shown or not is_instance_valid(_dryer_hint_button) or not _dryer_hint_button.visible:
		_dryer_hint_bubble.visible = false
		return
	var button_rect: Rect2 = _dryer_hint_button.get_global_rect()
	var popup_origin: Vector2 = Vector2.ZERO
	if is_instance_valid(_inventory_popup):
		popup_origin = _inventory_popup.get_global_rect().position
	_dryer_hint_bubble.position = button_rect.position - popup_origin + Vector2(-8.0, button_rect.size.y + 6.0)
	_dryer_hint_bubble.visible = true


func _tick_dryer_hint_hover() -> void:
	if not is_instance_valid(_dryer_hint_button) or not _dryer_hint_button.visible:
		if is_instance_valid(_dryer_hint_bubble):
			_dryer_hint_bubble.visible = false
		return
	if not is_instance_valid(_inventory_popup) or not _inventory_popup.visible or _inventory_kind != "dryer":
		if is_instance_valid(_dryer_hint_bubble):
			_dryer_hint_bubble.visible = false
		return
	var mouse_screen: Vector2i = DisplayServer.mouse_get_position()
	var win_pos: Vector2i = DisplayServer.window_get_position()
	var local: Vector2 = Vector2(mouse_screen - win_pos)
	var hovered: bool = _dryer_hint_button.get_global_rect().grow(4.0).has_point(local)
	_show_dryer_hint_bubble(hovered)


func _style_inventory_header_buttons() -> void:
	if is_instance_valid(_tidy_button):
		_tidy_button.theme_type_variation = &"EquipButton"
		_tidy_button.custom_minimum_size = Vector2(96.0, GameData.INVENTORY_HEADLINE_HEIGHT)
		_tidy_button.visible = true
		_apply_header_button_colors(_tidy_button)
	if is_instance_valid(_inventory_close_button):
		_inventory_close_button.theme_type_variation = &"CloseButton"
		_inventory_close_button.custom_minimum_size = Vector2(
			GameData.INVENTORY_CLOSE_BUTTON_WIDTH, GameData.INVENTORY_HEADLINE_HEIGHT
		)
		_apply_header_button_colors(_inventory_close_button)


func _apply_header_button_colors(button: Button) -> void:
	button.add_theme_font_size_override("font_size", GameData.UI_FONT_SIZE)
	button.add_theme_color_override("font_color", GameData.UI_FONT_COLOR)
	button.add_theme_color_override("font_hover_color", GameData.UI_FONT_COLOR)
	button.add_theme_color_override("font_pressed_color", GameData.UI_FONT_COLOR)
	button.add_theme_color_override("font_focus_color", GameData.UI_FONT_COLOR)


func _style_dinner_button() -> void:
	if not is_instance_valid(_dinner_button):
		return
	var slots: Dictionary = {
		"normal": GameData.DINNER_BUTTON_COLOR,
		"hover": GameData.DINNER_BUTTON_HOVER,
		"focus": GameData.DINNER_BUTTON_HOVER,
		"pressed": GameData.DINNER_BUTTON_PRESSED,
		"disabled": GameData.DINNER_BUTTON_COLOR,
	}
	for slot: String in slots.keys():
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = slots[slot]
		box.set_corner_radius_all(8)
		box.set_content_margin_all(10.0)
		box.set_border_width_all(2)
		box.border_color = Color(1.0, 1.0, 1.0, 0.55)
		_dinner_button.add_theme_stylebox_override(slot, box)
	_dinner_button.add_theme_color_override("font_color", GameData.UI_FONT_COLOR)
	_dinner_button.add_theme_color_override("font_hover_color", GameData.UI_FONT_COLOR)
	_dinner_button.add_theme_color_override("font_pressed_color", GameData.UI_FONT_COLOR)


func _refresh_context_menu_window() -> void:
	if not is_instance_valid(_exit_popup) or not _exit_popup.visible:
		return
	var settings_open: bool = is_instance_valid(_settings_panel) and _settings_panel.visible
	_expand_overlay_window(GameData.context_menu_window_size(settings_open))


func _open_inventory(kind: String) -> void:
	if _state == State.RUNAWAY:
		return
	_hide_speech_bubble()
	_inventory_kind = kind
	if is_instance_valid(_exit_popup):
		_exit_popup.visible = false
	if is_instance_valid(_settings_panel):
		_settings_panel.visible = false
	if is_instance_valid(_chat_popup):
		_chat_popup.visible = false
	_hide_fortune_and_movie()
	_set_pet_layer_visible(false)
	_expand_overlay_window(_inventory_window_size())
	_apply_inventory_background(kind)
	_apply_inventory_headline(kind)
	_apply_inventory_grid_metrics()
	_inventory_popup.visible = true
	_fill_inventory_grid()


func _close_inventory() -> void:
	_show_dryer_hint_bubble(false)
	if is_instance_valid(_inventory_popup):
		_inventory_popup.visible = false
	_inventory_kind = ""
	_set_tidy_panel_visible(false)
	_restore_overlay_window_if_idle()
	if not _any_content_overlay_open() and not _exit_popup.visible and _state != State.RUNAWAY:
		_set_pet_layer_visible(true)
	call_deferred("_try_show_speech")


func _inventory_window_size() -> Vector2i:
	var tidy_open: bool = is_instance_valid(_tidy_panel) and _tidy_panel.visible
	return GameData.inventory_window_size(tidy_open)


func _apply_inventory_grid_metrics() -> void:
	if is_instance_valid(_inventory_grid):
		_inventory_grid.columns = GameData.GRID_COLUMNS
		_inventory_grid.add_theme_constant_override("h_separation", GameData.GRID_H_SEP)
		_inventory_grid.add_theme_constant_override("v_separation", GameData.GRID_V_SEP)
		_inventory_grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_inventory_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if is_instance_valid(_inventory_scroll):
		_inventory_scroll.custom_minimum_size = GameData.inventory_grid_size()
		_inventory_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_inventory_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER


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
	if _any_overlay_open():
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
	_refresh_inventory_count_title()
	for item: Dictionary in items:
		_inventory_grid.add_child(_make_item_card(item))


func _make_item_card(item: Dictionary) -> Control:
	var quality: int = int(item.get("quality", 0))
	var wear: String = String(item.get("wear", item.get("wear_modifier", "")))
	var quality_name: String = GameData.quality_item_label(quality)
	var card_color: Color = GameData.quality_card_color(quality)
	var accent: Color = GameData.QUALITY_COLORS.get(quality, Color(0.7, 0.4, 0.9))

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = GameData.ITEM_CARD_SIZE
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.tooltip_text = String(item.get("display_name", GameData.make_display_name(wear, quality)))

	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = card_color
	box.border_color = card_color.lightened(0.28)
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", box)

	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)

	var icon: TextureRect = TextureRect.new()
	icon.custom_minimum_size = Vector2(0.0, GameData.ITEM_CARD_SWATCH_H)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = UnderwearArt.texture_for(item)
	icon.modulate = Color(1.0, 1.0, 1.0, 1.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(icon)
	if icon.texture == null:
		var fallback: ColorRect = ColorRect.new()
		fallback.custom_minimum_size = Vector2(0.0, GameData.ITEM_CARD_SWATCH_H)
		fallback.color = Color(accent.r, accent.g, accent.b, 0.85)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(fallback)

	var wear_label: Label = Label.new()
	wear_label.text = wear
	wear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wear_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	wear_label.clip_text = true
	wear_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	wear_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wear_label.add_theme_font_size_override("font_size", GameData.UI_FONT_SIZE)
	wear_label.add_theme_color_override("font_color", GameData.UI_FONT_COLOR)
	col.add_child(wear_label)

	var quality_label: Label = Label.new()
	quality_label.text = quality_name
	quality_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quality_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	quality_label.clip_text = true
	quality_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
	inv_box.bg_color = GameData.OVERLAY_CHROME_COLOR
	inv_box.set_corner_radius_all(radius)
	inv_box.set_border_width_all(3)
	inv_box.border_color = Color(1.0, 1.0, 1.0, 0.55)
	if is_instance_valid(_inventory_chrome):
		_inventory_chrome.add_theme_stylebox_override("panel", inv_box)
	if is_instance_valid(_chat_chrome):
		_chat_chrome.add_theme_stylebox_override("panel", inv_box)
	_style_chat_thread()
	if is_instance_valid(_fortune_chrome):
		_fortune_chrome.add_theme_stylebox_override("panel", inv_box)
	if is_instance_valid(_movie_chrome):
		_movie_chrome.add_theme_stylebox_override("panel", inv_box)
	if is_instance_valid(_movie_pick_chrome):
		_movie_pick_chrome.add_theme_stylebox_override("panel", inv_box)
	if is_instance_valid(_recharge_chrome):
		_recharge_chrome.add_theme_stylebox_override("panel", inv_box)
	if is_instance_valid(_inventory_mask):
		_inventory_mask.visible = false
	_apply_menu_control_heights()
	_style_stat_bubbles()
	_style_scrollbars()


func _style_chat_thread() -> void:
	if not is_instance_valid(_chat_scroll):
		return
	if is_instance_valid(_chat_list):
		_chat_list.add_theme_constant_override("separation", 8)
	if _chat_thread_wrapped:
		return
	var parent: Node = _chat_scroll.get_parent()
	if parent == null:
		return
	var wrap: PanelContainer = PanelContainer.new()
	wrap.name = "ChatThread"
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = GameData.WHATSAPP_THREAD_BG
	box.set_corner_radius_all(8)
	box.set_content_margin_all(6.0)
	wrap.add_theme_stylebox_override("panel", box)
	var idx: int = _chat_scroll.get_index()
	parent.remove_child(_chat_scroll)
	_chat_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_child(_chat_scroll)
	parent.add_child(wrap)
	parent.move_child(wrap, idx)
	_chat_thread_wrapped = true


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
	if is_instance_valid(_dryer_slot):
		_dryer_slot.text = GameData.DRYER_BUTTON_TEXT
	if is_instance_valid(_drawer_slot):
		_drawer_slot.text = GameData.DRAWER_BUTTON_TEXT


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


func _build_tidy_filters() -> void:
	if not is_instance_valid(_tidy_quality_box) or not is_instance_valid(_tidy_wear_box):
		return
	if _tidy_quality_box.get_child_count() > 0:
		return
	for quality: int in GameData.QUALITY_TIDY_ORDER:
		var button: Button = Button.new()
		button.toggle_mode = true
		button.text = GameData.quality_display_name(quality)
		button.set_meta("quality", quality)
		_style_tidy_toggle(button)
		_tidy_quality_box.add_child(button)
	for wear: String in GameData.WEAR_PREFIXES:
		var button: Button = Button.new()
		button.toggle_mode = true
		button.text = wear
		button.set_meta("wear", wear)
		_style_tidy_toggle(button)
		_tidy_wear_box.add_child(button)


func _style_tidy_toggle(button: Button) -> void:
	button.add_theme_font_size_override("font_size", GameData.UI_FONT_SIZE)
	button.add_theme_color_override("font_color", GameData.UI_FONT_COLOR)
	button.add_theme_color_override("font_hover_color", GameData.UI_FONT_COLOR)
	button.add_theme_color_override("font_pressed_color", GameData.UI_FONT_COLOR)
	button.add_theme_color_override("font_focus_color", GameData.UI_FONT_COLOR)
	_apply_tidy_toggle_style(button, button.button_pressed)
	button.toggled.connect(func(pressed: bool) -> void:
		_apply_tidy_toggle_style(button, pressed)
	)


func _apply_tidy_toggle_style(button: Button, selected: bool) -> void:
	if not is_instance_valid(button):
		return
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = GameData.TIDY_SELECTED_COLOR if selected else GameData.TIDY_IDLE_COLOR
	box.set_corner_radius_all(8)
	box.set_content_margin_all(8.0)
	box.set_border_width_all(2)
	box.border_color = Color(1.0, 1.0, 1.0, 0.85 if selected else 0.35)
	for slot: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(slot, box)


func _toggle_tidy_panel() -> void:
	if _inventory_kind != "drawer" and _inventory_kind != "dryer":
		return
	if not is_instance_valid(_tidy_panel):
		return
	_set_tidy_panel_visible(not _tidy_panel.visible)


func _set_tidy_panel_visible(shown: bool) -> void:
	if is_instance_valid(_tidy_panel):
		_tidy_panel.visible = shown
	if not shown:
		_clear_tidy_toggles()
	if _inventory_popup.visible:
		_expand_overlay_window(_inventory_window_size())


func _clear_tidy_toggles() -> void:
	for box: Container in [_tidy_quality_box, _tidy_wear_box]:
		if not is_instance_valid(box):
			continue
		for child: Node in box.get_children():
			var button: Button = child as Button
			if button != null:
				button.button_pressed = false


func _collect_tidy_filters() -> Dictionary:
	var qualities: Array[int] = []
	var wears: PackedStringArray = PackedStringArray()
	if is_instance_valid(_tidy_quality_box):
		for child: Node in _tidy_quality_box.get_children():
			var button: Button = child as Button
			if button == null or not button.button_pressed:
				continue
			qualities.append(int(button.get_meta("quality", -1)))
	if is_instance_valid(_tidy_wear_box):
		for child: Node in _tidy_wear_box.get_children():
			var button: Button = child as Button
			if button == null or not button.button_pressed:
				continue
			wears.append(String(button.get_meta("wear", "")).strip_edges())
	return {"qualities": qualities, "wears": wears}


func _confirm_tidy_delete() -> void:
	var filters: Dictionary = _collect_tidy_filters()
	var qualities: Array[int] = []
	for q: int in filters["qualities"]:
		qualities.append(int(q))
	var wears: PackedStringArray = PackedStringArray()
	for wear: String in filters["wears"]:
		wears.append(String(wear))
	if qualities.is_empty() and wears.is_empty():
		print("%s tidy skipped: no filters" % VIDEO_LOG_PREFIX)
		return
	var removed: int = 0
	if _inventory_kind == "dryer":
		var ids: Array[int] = GameData.delete_wet_matching(qualities, wears)
		for item_id: int in ids:
			_cancel_dry_timer(item_id)
		removed = ids.size()
	else:
		removed = GameData.delete_dry_matching(qualities, wears)
	print("%s tidy kind=%s removed=%d q=%s w=%s" % [
		VIDEO_LOG_PREFIX, _inventory_kind, removed, str(qualities), str(wears),
	])
	_fill_inventory_grid()
	_set_tidy_panel_visible(false)


func _refresh_stat_bubbles() -> void:
	if is_instance_valid(_bubble_affinity):
		_bubble_affinity.text = "❤  好感度  %d" % int(round(GameData.affinity_score()))
	if is_instance_valid(_bubble_underwear):
		_bubble_underwear.text = "%s  洗了 %d 条 内裤" % [
			GameData.UNDERWEAR_EMOJI, GameData.underwear_total,
		]
	if is_instance_valid(_bubble_companion):
		_bubble_companion.text = "⏰  陪伴时长  %s" % GameData.format_companion_clock()
	if is_instance_valid(_bubble_runaway):
		_bubble_runaway.text = "🏃  跑路次数  %d" % GameData.runaway_count


func _ensure_notice_nodes() -> void:
	if _notice_panel == null:
		_notice_panel = PanelContainer.new()
		_notice_panel.visible = false
		_notice_panel.z_index = 40
		_notice_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		_notice_label = Label.new()
		_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_notice_label.max_lines_visible = 2
		_notice_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_notice_label.clip_text = true
		_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_notice_label.add_theme_font_size_override("font_size", GameData.UI_FONT_SIZE)
		_notice_label.add_theme_color_override("font_color", GameData.UI_FONT_COLOR)
		_notice_label.add_theme_color_override("font_outline_color", GameData.UI_FONT_OUTLINE_COLOR)
		_notice_label.add_theme_constant_override("outline_size", GameData.UI_FONT_OUTLINE_SIZE)
		_notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_notice_panel.add_child(_notice_label)
		add_child(_notice_panel)
		_style_notice_panel(
			_notice_panel, GameData.WHATSAPP_INCOMING_COLOR, Color(0.82, 0.82, 0.82, 0.95)
		)
	if _flash_panel == null:
		_flash_panel = PanelContainer.new()
		_flash_panel.visible = false
		_flash_panel.z_index = 18
		_flash_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_flash_label = Label.new()
		_flash_label.text = GameData.TAP_FLASH_TEXT
		_flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_flash_label.add_theme_font_size_override("font_size", GameData.UI_FONT_SIZE)
		_flash_label.add_theme_color_override("font_color", GameData.UI_FONT_COLOR)
		_flash_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_flash_panel.add_child(_flash_label)
		add_child(_flash_panel)
		_style_notice_panel(_flash_panel, GameData.TAP_FLASH_COLOR, Color(0.75, 0.95, 1.0, 0.85))
	if not _notice_wired and is_instance_valid(_notice_panel):
		_notice_wired = true
		_notice_panel.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton:
				var mb: InputEventMouseButton = event
				if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
					_on_speech_clicked()
					_notice_panel.accept_event()
		)


func _style_notice_panel(panel: PanelContainer, fill: Color, border: Color) -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(GameData.BUBBLE_CORNER_RADIUS)
	box.set_content_margin_all(12.0)
	box.set_border_width_all(2)
	box.border_color = border
	panel.add_theme_stylebox_override("panel", box)


func _style_speech_panel() -> void:
	if not is_instance_valid(_notice_panel):
		return
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = GameData.WHATSAPP_INCOMING_COLOR
	box.corner_radius_top_left = 16
	box.corner_radius_top_right = 16
	box.corner_radius_bottom_right = 16
	box.corner_radius_bottom_left = 4
	box.set_content_margin_all(10.0)
	box.set_border_width_all(1)
	box.border_color = Color(0.82, 0.82, 0.82, 0.95)
	_notice_panel.add_theme_stylebox_override("panel", box)


func _style_scrollbars() -> void:
	var scrolls: Array[ScrollContainer] = [_menu_scroll, _inventory_scroll, _chat_scroll, _fortune_scroll]
	for scroll: ScrollContainer in scrolls:
		if not is_instance_valid(scroll):
			continue
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		_hide_scroll_bar(scroll.get_v_scroll_bar())
		_hide_scroll_bar(scroll.get_h_scroll_bar())


func _hide_scroll_bar(bar: ScrollBar) -> void:
	if bar == null:
		return
	bar.visible = false
	bar.modulate.a = 0.0
	bar.custom_minimum_size = Vector2.ZERO
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _queue_steve_notice(text: String, target: String = "chat") -> void:
	var excerpt: String = GameData.notice_excerpt(text)
	if excerpt.is_empty():
		return
	if target == "chat" and is_instance_valid(_chat_popup) and _chat_popup.visible:
		return
	if target == "fortune" and _fortune_open():
		return
	_pending_steve_notice = excerpt
	_speech_target = target
	if _can_show_speech_bubble():
		_show_speech_bubble()


func _can_show_speech_bubble() -> bool:
	if _state == State.RUNAWAY:
		return false
	if _any_overlay_open():
		return false
	if is_instance_valid(_pet_visual) and not _pet_visual.visible:
		return false
	return true


func _speech_visible() -> bool:
	return is_instance_valid(_notice_panel) and _notice_panel.visible


func _speech_rect() -> Rect2:
	var pet: Rect2 = _current_pet_rect()
	var bar_w: float = clampf(pet.size.x * 0.78, 72.0, pet.size.x)
	var hud_h: float = clampf(pet.size.x * 0.22, HOVER_HUD_HEIGHT + 8.0, 72.0)
	var x: float = pet.position.x + (pet.size.x - bar_w) * 0.5
	var y: float = pet.position.y - hud_h - HOVER_GAP
	if y < 2.0:
		y = pet.position.y + HOVER_GAP
	y += GameData.WASH_BAR_SHIFT_Y
	return Rect2(x, y, bar_w, hud_h)


func _layout_speech_bubble() -> void:
	if not _speech_visible():
		return
	var area: Rect2 = _speech_rect()
	_notice_panel.position = area.position
	_notice_panel.size = area.size


func _try_show_speech() -> void:
	if not _can_show_speech_bubble():
		_hide_speech_bubble()
		return
	if _pending_steve_notice.is_empty():
		return
	_show_speech_bubble()


func _hide_speech_bubble() -> void:
	if is_instance_valid(_notice_tween):
		_notice_tween.kill()
	if is_instance_valid(_notice_panel):
		_notice_panel.visible = false
		_notice_panel.modulate.a = 0.0


func _show_speech_bubble() -> void:
	if not _can_show_speech_bubble():
		return
	if _pending_steve_notice.is_empty():
		return
	_ensure_notice_nodes()
	if not is_instance_valid(_notice_panel) or not is_instance_valid(_notice_label):
		return
	_set_hover_hud_visible(false, false)
	_notice_label.text = _pending_steve_notice
	_notice_label.add_theme_color_override("font_color", GameData.UI_FONT_COLOR)
	_notice_label.add_theme_color_override("font_outline_color", GameData.UI_FONT_OUTLINE_COLOR)
	_notice_label.add_theme_constant_override("outline_size", GameData.UI_FONT_OUTLINE_SIZE)
	_style_speech_panel()
	_notice_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_notice_panel.visible = true
	_notice_panel.modulate.a = 0.0
	_layout_speech_bubble()
	if is_instance_valid(_notice_tween):
		_notice_tween.kill()
	_notice_tween = create_tween()
	_notice_tween.tween_property(_notice_panel, "modulate:a", 1.0, 0.18)
	_notice_tween.tween_interval(GameData.NOTICE_SECONDS)
	_notice_tween.tween_property(_notice_panel, "modulate:a", 0.0, 0.25)
	_notice_tween.finished.connect(func() -> void:
		if is_instance_valid(_notice_panel):
			_notice_panel.visible = false
		_pending_steve_notice = ""
		_speech_target = ""
	)


func _on_speech_clicked() -> void:
	var target: String = _speech_target
	_pending_steve_notice = ""
	_speech_target = ""
	_hide_speech_bubble()
	if target == "fortune":
		_open_fortune()
	elif target == "chat":
		_open_chat()


func _show_notice(text: String) -> void:
	_pending_steve_notice = GameData.notice_excerpt(text)
	_speech_target = ""
	if not _can_show_speech_bubble():
		return
	_show_speech_bubble()
	if is_instance_valid(_notice_panel):
		_notice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _show_speed_flash() -> void:
	_ensure_notice_nodes()
	if not is_instance_valid(_flash_panel) or not is_instance_valid(_flash_label):
		return
	_flash_label.text = GameData.TAP_FLASH_TEXT
	var hit: Rect2 = _pet_hit_rect()
	var width: float = clampf(hit.size.x * 0.72, 88.0, 180.0)
	_flash_panel.visible = true
	_flash_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_flash_panel.position = Vector2(
		hit.position.x + (hit.size.x - width) * 0.5,
		hit.position.y + hit.size.y * 0.28
	)
	_flash_panel.size = Vector2(width, 36.0)
	if is_instance_valid(_flash_tween):
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash_panel, "modulate:a", 1.0, 0.08)
	_flash_tween.tween_interval(GameData.TAP_FLASH_SECONDS)
	_flash_tween.tween_property(_flash_panel, "modulate:a", 0.0, 0.2)
	_flash_tween.finished.connect(func() -> void:
		if is_instance_valid(_flash_panel):
			_flash_panel.visible = false
	)


func _log(message: String) -> void:
	if _debug_log:
		print("[Steve] ", message)


func _any_overlay_open() -> bool:
	return (
		(is_instance_valid(_exit_popup) and _exit_popup.visible)
		or (is_instance_valid(_inventory_popup) and _inventory_popup.visible)
		or (is_instance_valid(_chat_popup) and _chat_popup.visible)
		or _fortune_open()
		or _movie_open()
		or _movie_pick_open()
		or _recharge_open()
	)


func _any_content_overlay_open() -> bool:
	return (
		(is_instance_valid(_inventory_popup) and _inventory_popup.visible)
		or (is_instance_valid(_chat_popup) and _chat_popup.visible)
		or _fortune_open()
		or _movie_open()
		or _movie_pick_open()
		or _recharge_open()
	)


func _fortune_open() -> bool:
	return is_instance_valid(_fortune_popup) and _fortune_popup.visible


func _movie_open() -> bool:
	return is_instance_valid(_movie_popup) and _movie_popup.visible


func _movie_pick_open() -> bool:
	return is_instance_valid(_movie_pick_popup) and _movie_pick_popup.visible


func _recharge_open() -> bool:
	return is_instance_valid(_recharge_popup) and _recharge_popup.visible


func _hide_fortune_and_movie() -> void:
	if is_instance_valid(_fortune_popup):
		_fortune_popup.visible = false
	if is_instance_valid(_movie_pick_popup):
		_movie_pick_popup.visible = false
	if is_instance_valid(_recharge_popup):
		_recharge_popup.visible = false
	if is_instance_valid(_movie_popup) and _movie_popup.visible:
		if _movie_client != null and _movie_client.has_method("cancel_fetch"):
			_movie_client.cancel_fetch()
		_stop_movie_player()
		_movie_popup.visible = false
		_movie_maximized = false
		_reset_movie_button()


func _headline_box(color: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(8)
	box.set_border_width_all(2)
	box.border_color = Color(1.0, 1.0, 1.0, 0.92)
	box.content_margin_left = GameData.INVENTORY_HEADLINE_PAD_X
	box.content_margin_right = GameData.INVENTORY_HEADLINE_PAD_X
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	return box


func _setup_fortune_ui() -> void:
	_fortune_client = preload("res://scripts/chat_client.gd").new()
	add_child(_fortune_client)
	_fortune_client.chat_replied.connect(func(text: String) -> void:
		_on_fortune_replied(text)
	)
	_fortune_client.chat_failed.connect(func(reason: String) -> void:
		_on_fortune_replied(GameData.chat_fail_text(reason))
	)
	_fortune_popup = Control.new()
	_fortune_popup.name = "FortunePopup"
	_fortune_popup.visible = false
	_fortune_popup.z_index = 22
	_fortune_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fortune_popup)
	_fortune_chrome = Panel.new()
	_fortune_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fortune_chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fortune_popup.add_child(_fortune_chrome)
	var body: VBoxContainer = VBoxContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 16.0
	body.offset_top = 12.0
	body.offset_right = -16.0
	body.offset_bottom = -12.0
	body.add_theme_constant_override("separation", 10)
	_fortune_popup.add_child(body)
	var header: HBoxContainer = HBoxContainer.new()
	header.custom_minimum_size.y = GameData.INVENTORY_HEADLINE_HEIGHT
	header.add_theme_constant_override("separation", 8)
	body.add_child(header)
	var headline: PanelContainer = PanelContainer.new()
	headline.add_theme_stylebox_override("panel", _headline_box(GameData.DRAWER_HEADLINE_COLOR))
	_fortune_title = Label.new()
	_fortune_title.text = GameData.FORTUNE_TITLE_TEXT
	_fortune_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	headline.add_child(_fortune_title)
	header.add_child(headline)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)
	_fortune_close_button = Button.new()
	_fortune_close_button.text = "关闭"
	_fortune_close_button.theme_type_variation = &"CloseButton"
	_fortune_close_button.custom_minimum_size = Vector2(72.0, GameData.INVENTORY_HEADLINE_HEIGHT)
	header.add_child(_fortune_close_button)
	_fortune_hint = Label.new()
	_fortune_hint.text = GameData.FORTUNE_HINT_TEXT
	_fortune_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fortune_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_fortune_hint)
	var pickers: HBoxContainer = HBoxContainer.new()
	pickers.add_theme_constant_override("separation", 6)
	body.add_child(pickers)
	_fortune_year = OptionButton.new()
	_fortune_month = OptionButton.new()
	_fortune_day = OptionButton.new()
	_fortune_hour = OptionButton.new()
	for box: OptionButton in [_fortune_year, _fortune_month, _fortune_day, _fortune_hour]:
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.fit_to_longest_item = false
		pickers.add_child(box)
	_fortune_readout = Label.new()
	_fortune_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fortune_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_fortune_readout)
	_fortune_ask_button = Button.new()
	_fortune_ask_button.text = GameData.FORTUNE_ASK_TEXT
	_fortune_ask_button.theme_type_variation = &"EquipButton"
	_fortune_ask_button.custom_minimum_size.y = 40.0
	body.add_child(_fortune_ask_button)
	_fortune_scroll = ScrollContainer.new()
	_fortune_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fortune_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_fortune_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	body.add_child(_fortune_scroll)
	_fortune_result = Label.new()
	_fortune_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fortune_result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fortune_result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fortune_result.add_theme_color_override("font_color", GameData.UI_FONT_COLOR)
	_fortune_result.add_theme_color_override("font_outline_color", GameData.UI_FONT_OUTLINE_COLOR)
	_fortune_result.add_theme_constant_override("outline_size", GameData.UI_FONT_OUTLINE_SIZE)
	var result_panel: PanelContainer = PanelContainer.new()
	var result_box: StyleBoxFlat = StyleBoxFlat.new()
	result_box.bg_color = GameData.WHATSAPP_INCOMING_COLOR
	result_box.corner_radius_top_left = 12
	result_box.corner_radius_top_right = 12
	result_box.corner_radius_bottom_left = 4
	result_box.corner_radius_bottom_right = 12
	result_box.set_content_margin_all(10.0)
	result_panel.add_theme_stylebox_override("panel", result_box)
	result_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_panel.add_child(_fortune_result)
	_fortune_scroll.add_child(result_panel)
	_fill_fortune_pickers()
	_fortune_year.item_selected.connect(func(_i: int) -> void:
		_on_fortune_date_changed(true)
	)
	_fortune_month.item_selected.connect(func(_i: int) -> void:
		_on_fortune_date_changed(true)
	)
	_fortune_day.item_selected.connect(func(_i: int) -> void:
		_on_fortune_date_changed(false)
	)
	_fortune_hour.item_selected.connect(func(_i: int) -> void:
		_on_fortune_date_changed(false)
	)
	_fortune_close_button.pressed.connect(func() -> void:
		_close_fortune()
	)
	_fortune_ask_button.pressed.connect(func() -> void:
		_submit_fortune()
	)
	_fortune_popup.gui_input.connect(func(event: InputEvent) -> void:
		_process_drag_input(event)
	)
	_restyle_new_overlay(_fortune_popup)


func _fill_fortune_pickers() -> void:
	_fortune_filling = true
	var year_max: int = GameData.fortune_year_max()
	_fortune_year.clear()
	for year: int in range(GameData.FORTUNE_YEAR_MIN, year_max + 1):
		_fortune_year.add_item(str(year), year)
	_fortune_month.clear()
	for month: int in range(1, 13):
		_fortune_month.add_item("%02d" % month, month)
	_fortune_hour.clear()
	for hour: int in range(0, 24):
		_fortune_hour.add_item("%02d %s" % [hour, GameData.shichen_label(hour)], hour)
	_select_option_id(_fortune_year, GameData.fortune_year)
	_select_option_id(_fortune_month, GameData.fortune_month)
	_select_option_id(_fortune_hour, GameData.fortune_hour)
	_rebuild_fortune_days()
	_fortune_filling = false
	_refresh_fortune_readout()


func _select_option_id(box: OptionButton, id: int) -> void:
	var idx: int = box.get_item_index(id)
	if idx >= 0:
		box.select(idx)


func _rebuild_fortune_days() -> void:
	var year: int = _fortune_year.get_selected_id() if _fortune_year.selected >= 0 else GameData.fortune_year
	var month: int = _fortune_month.get_selected_id() if _fortune_month.selected >= 0 else GameData.fortune_month
	var keep: int = _fortune_day.get_selected_id() if _fortune_day.selected >= 0 else GameData.fortune_day
	var max_day: int = GameData.days_in_month(year, month)
	_fortune_day.clear()
	for day: int in range(1, max_day + 1):
		_fortune_day.add_item("%02d" % day, day)
	_select_option_id(_fortune_day, mini(keep, max_day))


func _on_fortune_date_changed(rebuild_days: bool) -> void:
	if _fortune_filling:
		return
	if rebuild_days:
		_rebuild_fortune_days()
	_commit_fortune_pickers()
	_refresh_fortune_readout()


func _commit_fortune_pickers() -> void:
	GameData.set_fortune_birth(
		_fortune_year.get_selected_id(),
		_fortune_month.get_selected_id(),
		_fortune_day.get_selected_id(),
		_fortune_hour.get_selected_id()
	)


func _refresh_fortune_readout() -> void:
	if is_instance_valid(_fortune_readout):
		_fortune_readout.text = "将按：%s" % GameData.fortune_birth_label()


func _open_fortune() -> void:
	if _state == State.RUNAWAY:
		return
	_hide_speech_bubble()
	if is_instance_valid(_exit_popup):
		_exit_popup.visible = false
	if is_instance_valid(_settings_panel):
		_settings_panel.visible = false
	if is_instance_valid(_inventory_popup):
		_inventory_popup.visible = false
	if is_instance_valid(_chat_popup):
		_chat_popup.visible = false
	if is_instance_valid(_movie_pick_popup):
		_movie_pick_popup.visible = false
	if is_instance_valid(_recharge_popup):
		_recharge_popup.visible = false
	if _movie_open():
		_hide_fortune_and_movie()
	_inventory_kind = ""
	_set_pet_layer_visible(false)
	_expand_overlay_window(GameData.FORTUNE_WINDOW_SIZE)
	_fill_fortune_pickers()
	if is_instance_valid(_fortune_result) and _fortune_result.text.is_empty():
		_fortune_result.text = GameData.FORTUNE_HINT_TEXT
	_fortune_popup.visible = true
	_set_fortune_busy(false)


func _close_fortune() -> void:
	if is_instance_valid(_fortune_popup):
		_fortune_popup.visible = false
	_hide_speech_bubble()
	_restore_overlay_window_if_idle()
	if not _any_overlay_open() and _state != State.RUNAWAY:
		_set_pet_layer_visible(true)
	call_deferred("_try_show_speech")


func _set_fortune_busy(busy: bool) -> void:
	_fortune_busy = busy
	if is_instance_valid(_fortune_ask_button):
		_fortune_ask_button.disabled = busy
		_fortune_ask_button.text = GameData.FORTUNE_WAIT_TEXT if busy else GameData.FORTUNE_ASK_TEXT
	for box: OptionButton in [_fortune_year, _fortune_month, _fortune_day, _fortune_hour]:
		if is_instance_valid(box):
			box.disabled = busy


func _submit_fortune() -> void:
	if _fortune_busy:
		return
	_commit_fortune_pickers()
	_refresh_fortune_readout()
	_set_fortune_busy(true)
	if is_instance_valid(_fortune_result):
		_fortune_result.text = GameData.FORTUNE_WAIT_TEXT
	var history: Array[Dictionary] = [{
		"role": "user",
		"content": GameData.fortune_user_prompt(),
	}]
	if _fortune_client != null and _fortune_client.has_method("send_history"):
		_fortune_client.send_history(
			history, GameData.FORTUNE_SYSTEM_PROMPT, GameData.fortune_offline_reply()
		)
	else:
		_on_fortune_replied(GameData.fortune_offline_reply())


func _on_fortune_replied(text: String) -> void:
	var reply: String = GameData.sanitize_chat_output(text)
	if reply.is_empty():
		reply = GameData.CHAT_FAIL_TEXT
	if is_instance_valid(_fortune_result):
		_fortune_result.text = reply
	_queue_steve_notice(reply, "fortune")
	_set_fortune_busy(false)


func _setup_movie_ui() -> void:
	_movie_client = preload("res://scripts/movie_client.gd").new()
	add_child(_movie_client)
	_movie_client.movie_ready.connect(func(path: String, title: String) -> void:
		_on_movie_ready(path, title)
	)
	_movie_client.movie_failed.connect(func(reason: String) -> void:
		_on_movie_failed(reason)
	)
	_movie_client.movie_progress.connect(func(text: String) -> void:
		if _movie_loading and is_instance_valid(_movie_button):
			_movie_button.text = text
	)
	_movie_popup = Control.new()
	_movie_popup.name = "MoviePopup"
	_movie_popup.visible = false
	_movie_popup.z_index = 24
	_movie_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_movie_popup)
	_movie_chrome = Panel.new()
	_movie_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_movie_chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_movie_popup.add_child(_movie_chrome)
	var body: VBoxContainer = VBoxContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 12.0
	body.offset_top = 10.0
	body.offset_right = -12.0
	body.offset_bottom = -12.0
	body.add_theme_constant_override("separation", 8)
	_movie_popup.add_child(body)
	var header: HBoxContainer = HBoxContainer.new()
	header.custom_minimum_size.y = GameData.INVENTORY_HEADLINE_HEIGHT
	header.add_theme_constant_override("separation", 8)
	body.add_child(header)
	var headline: PanelContainer = PanelContainer.new()
	headline.add_theme_stylebox_override("panel", _headline_box(GameData.DRYER_HEADLINE_COLOR))
	_movie_title = Label.new()
	_movie_title.text = GameData.MOVIE_BUTTON_TEXT
	_movie_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	headline.add_child(_movie_title)
	header.add_child(headline)
	_movie_skip_button = Button.new()
	_movie_skip_button.text = GameData.MOVIE_SKIP_TEXT
	_movie_skip_button.theme_type_variation = &"EquipButton"
	_movie_skip_button.custom_minimum_size = Vector2(160.0, GameData.INVENTORY_HEADLINE_HEIGHT)
	_movie_skip_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_movie_skip_button.clip_text = true
	header.add_child(_movie_skip_button)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)
	_movie_max_button = Button.new()
	_movie_max_button.text = GameData.MOVIE_MAX_TEXT
	_movie_max_button.theme_type_variation = &"EquipButton"
	_movie_max_button.custom_minimum_size = Vector2(88.0, GameData.INVENTORY_HEADLINE_HEIGHT)
	header.add_child(_movie_max_button)
	_movie_close_button = Button.new()
	_movie_close_button.text = "关闭"
	_movie_close_button.theme_type_variation = &"CloseButton"
	_movie_close_button.custom_minimum_size = Vector2(72.0, GameData.INVENTORY_HEADLINE_HEIGHT)
	header.add_child(_movie_close_button)
	_movie_player = VideoStreamPlayer.new()
	_movie_player.name = "MoviePlayer"
	_movie_player.expand = true
	_movie_player.loop = false
	_movie_player.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_movie_player.custom_minimum_size = Vector2(320.0, 180.0)
	body.add_child(_movie_player)
	var bar: HBoxContainer = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	body.add_child(bar)
	_movie_seek = HSlider.new()
	_movie_seek.min_value = 0.0
	_movie_seek.max_value = 1.0
	_movie_seek.step = 0.05
	_movie_seek.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_movie_seek.custom_minimum_size = Vector2(160.0, 28.0)
	bar.add_child(_movie_seek)
	_movie_mute_button = Button.new()
	_movie_mute_button.text = GameData.MOVIE_MUTE_TEXT
	_movie_mute_button.theme_type_variation = &"CodexButton"
	_movie_mute_button.custom_minimum_size = Vector2(44.0, 36.0)
	bar.add_child(_movie_mute_button)
	_movie_volume = HSlider.new()
	_movie_volume.min_value = 0.0
	_movie_volume.max_value = 1.0
	_movie_volume.step = 0.01
	_movie_volume.value = _movie_volume_linear
	_movie_volume.custom_minimum_size = Vector2(88.0, 28.0)
	bar.add_child(_movie_volume)
	_movie_speed_box = HBoxContainer.new()
	_movie_speed_box.add_theme_constant_override("separation", 4)
	bar.add_child(_movie_speed_box)
	for speed: float in GameData.MOVIE_SPEEDS:
		var speed_button: Button = Button.new()
		speed_button.toggle_mode = true
		speed_button.text = "%s×" % str(speed)
		speed_button.set_meta("speed", speed)
		speed_button.custom_minimum_size = Vector2(52.0, 36.0)
		speed_button.theme_type_variation = &"CoinButton"
		var captured: float = speed
		speed_button.pressed.connect(func() -> void:
			_set_movie_speed(captured)
		)
		_movie_speed_box.add_child(speed_button)
	_add_movie_resize_handle(Vector2i(0, -1), Control.CURSOR_VSIZE, 0.0, 0.0, 1.0, 0.0)
	_add_movie_resize_handle(Vector2i(0, 1), Control.CURSOR_VSIZE, 0.0, 1.0, 1.0, 1.0)
	_add_movie_resize_handle(Vector2i(-1, 0), Control.CURSOR_HSIZE, 0.0, 0.0, 0.0, 1.0)
	_add_movie_resize_handle(Vector2i(1, 0), Control.CURSOR_HSIZE, 1.0, 0.0, 1.0, 1.0)
	_add_movie_resize_handle(Vector2i(-1, -1), Control.CURSOR_FDIAGSIZE, 0.0, 0.0, 0.0, 0.0)
	_add_movie_resize_handle(Vector2i(1, -1), Control.CURSOR_BDIAGSIZE, 1.0, 0.0, 1.0, 0.0)
	_add_movie_resize_handle(Vector2i(-1, 1), Control.CURSOR_BDIAGSIZE, 0.0, 1.0, 0.0, 1.0)
	_add_movie_resize_handle(Vector2i(1, 1), Control.CURSOR_FDIAGSIZE, 1.0, 1.0, 1.0, 1.0)
	_movie_close_button.pressed.connect(func() -> void:
		_close_movie()
	)
	_movie_skip_button.pressed.connect(func() -> void:
		_skip_current_movie()
	)
	_movie_max_button.pressed.connect(func() -> void:
		_toggle_movie_maximize()
	)
	_movie_mute_button.pressed.connect(func() -> void:
		_movie_muted = not _movie_muted
		_apply_movie_audio()
	)
	_movie_volume.value_changed.connect(func(value: float) -> void:
		_movie_volume_linear = value
		if value > 0.001:
			_movie_muted = false
		_apply_movie_audio()
	)
	_movie_seek.drag_started.connect(func() -> void:
		_movie_seeking = true
	)
	_movie_seek.drag_ended.connect(func(_changed: bool) -> void:
		_seek_movie_to(_movie_seek.value)
		_movie_seeking = false
	)
	_movie_seek.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_movie_seeking = true
	)
	_movie_popup.gui_input.connect(func(event: InputEvent) -> void:
		_process_drag_input(event)
	)
	_set_movie_speed(1.0)
	_apply_movie_audio()
	_restyle_new_overlay(_movie_popup)
	_setup_movie_pick_ui()


func _restyle_new_overlay(root: Control) -> void:
	_apply_round_chrome()
	_style_scrollbars()
	if theme != null and theme.default_font is FontFile:
		_unify_control_text(root, theme.default_font as FontFile)


func _add_movie_resize_handle(
	edge: Vector2i, cursor: int, left: float, top: float, right: float, bottom: float
) -> void:
	var handle: ColorRect = ColorRect.new()
	handle.color = Color(1.0, 1.0, 1.0, 0.0)
	handle.mouse_default_cursor_shape = cursor
	handle.z_index = 30
	handle.anchor_left = left
	handle.anchor_top = top
	handle.anchor_right = right
	handle.anchor_bottom = bottom
	var edge_px: float = float(GameData.MOVIE_RESIZE_EDGE)
	var corner: bool = edge.x != 0 and edge.y != 0
	var thick: float = edge_px * (1.6 if corner else 1.0)
	if edge.x < 0:
		handle.offset_left = 0.0
		handle.offset_right = thick
	elif edge.x > 0:
		handle.offset_left = -thick
		handle.offset_right = 0.0
	else:
		handle.offset_left = thick
		handle.offset_right = -thick
	if edge.y < 0:
		handle.offset_top = 0.0
		handle.offset_bottom = thick
	elif edge.y > 0:
		handle.offset_top = -thick
		handle.offset_bottom = 0.0
	else:
		handle.offset_top = thick
		handle.offset_bottom = -thick
	var captured: Vector2i = edge
	handle.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			if mb.button_index != DRAG_BUTTON:
				return
			if mb.pressed:
				if _movie_maximized:
					return
				_begin_movie_resize(captured)
				handle.accept_event()
			else:
				_movie_resizing = false
	)
	_movie_popup.add_child(handle)


func _setup_movie_pick_ui() -> void:
	_movie_pick_popup = Control.new()
	_movie_pick_popup.name = "MoviePickPopup"
	_movie_pick_popup.visible = false
	_movie_pick_popup.z_index = 23
	_movie_pick_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_movie_pick_popup)
	_movie_pick_chrome = Panel.new()
	_movie_pick_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_movie_pick_chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_movie_pick_popup.add_child(_movie_pick_chrome)
	var body: VBoxContainer = VBoxContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 16.0
	body.offset_top = 12.0
	body.offset_right = -16.0
	body.offset_bottom = -12.0
	body.add_theme_constant_override("separation", 10)
	_movie_pick_popup.add_child(body)
	var header: HBoxContainer = HBoxContainer.new()
	header.custom_minimum_size.y = GameData.INVENTORY_HEADLINE_HEIGHT
	header.add_theme_constant_override("separation", 8)
	body.add_child(header)
	var headline: PanelContainer = PanelContainer.new()
	headline.add_theme_stylebox_override("panel", _headline_box(GameData.DRYER_HEADLINE_COLOR))
	var title: Label = Label.new()
	title.text = GameData.MOVIE_PICK_TITLE
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	headline.add_child(title)
	header.add_child(headline)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)
	var close_button: Button = Button.new()
	close_button.text = "关闭"
	close_button.theme_type_variation = &"CloseButton"
	close_button.custom_minimum_size = Vector2(72.0, GameData.INVENTORY_HEADLINE_HEIGHT)
	close_button.pressed.connect(func() -> void:
		_close_movie_pick()
	)
	header.add_child(close_button)
	var hint: Label = Label.new()
	hint.text = GameData.MOVIE_PICK_HINT
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(hint)
	var grid: HFlowContainer = HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	for entry: Dictionary in GameData.MOVIE_GENRES:
		var genre_id: String = String(entry.get("id", GameData.MOVIE_GENRE_ALL))
		var button: Button = Button.new()
		button.text = String(entry.get("label", genre_id))
		button.theme_type_variation = &"CodexButton"
		button.custom_minimum_size = Vector2(140.0, 48.0)
		var captured: String = genre_id
		button.pressed.connect(func() -> void:
			_start_movie_for_genre(captured)
		)
		grid.add_child(button)
	_movie_pick_popup.gui_input.connect(func(event: InputEvent) -> void:
		_process_drag_input(event)
	)
	_restyle_new_overlay(_movie_pick_popup)


func _open_movie_pick() -> void:
	if _state == State.RUNAWAY:
		return
	if _movie_loading or _movie_open():
		return
	_hide_speech_bubble()
	if is_instance_valid(_exit_popup):
		_exit_popup.visible = false
	if is_instance_valid(_settings_panel):
		_settings_panel.visible = false
	if is_instance_valid(_inventory_popup):
		_inventory_popup.visible = false
	if is_instance_valid(_chat_popup):
		_chat_popup.visible = false
	if is_instance_valid(_fortune_popup):
		_fortune_popup.visible = false
	if is_instance_valid(_recharge_popup):
		_recharge_popup.visible = false
	_inventory_kind = ""
	_set_pet_layer_visible(false)
	_expand_overlay_window(GameData.MOVIE_PICK_WINDOW_SIZE)
	if is_instance_valid(_movie_pick_popup):
		_movie_pick_popup.visible = true


func _close_movie_pick() -> void:
	if is_instance_valid(_movie_pick_popup):
		_movie_pick_popup.visible = false
	_hide_speech_bubble()
	_restore_overlay_window_if_idle()
	if not _any_overlay_open() and _state != State.RUNAWAY:
		_set_pet_layer_visible(true)
	call_deferred("_try_show_speech")


func _start_movie_for_genre(genre: String) -> void:
	if _movie_loading or (_movie_client != null and _movie_client.has_method("is_busy") and _movie_client.is_busy()):
		return
	if _movie_open():
		return
	_movie_genre = genre.strip_edges()
	if _movie_genre.is_empty():
		_movie_genre = GameData.MOVIE_GENRE_ALL
	if GameData.shuffled_movie_catalog("", _movie_genre).is_empty():
		var empty_text: String = (
			GameData.MOVIE_CN_EMPTY_TEXT if _movie_genre == "cn" else GameData.MOVIE_EMPTY_GENRE_TEXT
		)
		_show_notice(empty_text)
		return
	if is_instance_valid(_movie_pick_popup):
		_movie_pick_popup.visible = false
	_set_pet_layer_visible(false)
	_expand_overlay_window(GameData.MOVIE_WINDOW_SIZE)
	if is_instance_valid(_movie_popup):
		_movie_popup.visible = true
	if is_instance_valid(_movie_title):
		_movie_title.text = GameData.MOVIE_LOADING_TEXT
	if is_instance_valid(_movie_skip_button):
		_movie_skip_button.disabled = true
	_movie_loading = true
	if is_instance_valid(_movie_button):
		_movie_button.disabled = true
		_movie_button.text = GameData.MOVIE_LOADING_TEXT
	if _movie_client != null and _movie_client.has_method("fetch_random"):
		_movie_client.fetch_random("", _movie_genre)
	else:
		_on_movie_failed("no_client")


func _on_movie_pressed() -> void:
	if _movie_loading or (_movie_client != null and _movie_client.has_method("is_busy") and _movie_client.is_busy()):
		return
	if _movie_open():
		return
	_open_movie_pick()


func _reset_movie_button() -> void:
	_movie_loading = false
	if is_instance_valid(_movie_button):
		_movie_button.disabled = false
		_movie_button.text = GameData.MOVIE_BUTTON_TEXT


func _cancel_pending_movie_fetch() -> void:
	if _movie_open():
		return
	if not _movie_loading and (_movie_client == null or not _movie_client.is_busy()):
		return
	if _movie_client != null and _movie_client.has_method("cancel_fetch"):
		_movie_client.cancel_fetch()
	_reset_movie_button()


func _on_movie_ready(path: String, title: String) -> void:
	_reset_movie_button()
	if is_instance_valid(_movie_skip_button):
		_movie_skip_button.disabled = false
	if _state == State.RUNAWAY:
		return
	var same_file: bool = _movie_open() and not _movie_path.is_empty() and path == _movie_path
	if same_file:
		if is_instance_valid(_movie_title) and not title.is_empty():
			_movie_title.text = title
		_refresh_movie_stream(true)
		return
	_hide_speech_bubble()
	if not _movie_open():
		if is_instance_valid(_exit_popup):
			_exit_popup.visible = false
		if is_instance_valid(_settings_panel):
			_settings_panel.visible = false
		if is_instance_valid(_inventory_popup):
			_inventory_popup.visible = false
		if is_instance_valid(_chat_popup):
			_chat_popup.visible = false
		if is_instance_valid(_fortune_popup):
			_fortune_popup.visible = false
		_inventory_kind = ""
		_set_pet_layer_visible(false)
		_movie_maximized = false
		_expand_overlay_window(GameData.MOVIE_WINDOW_SIZE)
		_movie_popup.visible = true
	if is_instance_valid(_movie_title):
		_movie_title.text = title
	_play_movie_file(path)
	print("%s movie play title=%s path=%s" % [VIDEO_LOG_PREFIX, title, path])


func _on_movie_failed(reason: String) -> void:
	_reset_movie_button()
	if is_instance_valid(_movie_skip_button):
		_movie_skip_button.disabled = false
	print("%s movie failed=%s" % [VIDEO_LOG_PREFIX, reason])
	var fail_text: String = GameData.MOVIE_FAIL_TEXT
	if reason == "empty_genre":
		fail_text = (
			GameData.MOVIE_CN_EMPTY_TEXT if _movie_genre == "cn" else GameData.MOVIE_EMPTY_GENRE_TEXT
		)
	if _movie_open() and is_instance_valid(_movie_title):
		_movie_title.text = fail_text
	_show_notice(fail_text)


func _skip_current_movie() -> void:
	if not _movie_open():
		return
	if is_instance_valid(_movie_skip_button) and _movie_skip_button.disabled:
		return
	var exclude_id: String = _movie_id
	if exclude_id.is_empty():
		exclude_id = GameData.movie_id_from_path(_movie_path)
	if _movie_client != null and _movie_client.has_method("cancel_fetch"):
		_movie_client.cancel_fetch()
	_stop_movie_player()
	_movie_path = ""
	_movie_id = ""
	_movie_expected_bytes = 0
	_movie_last_bytes = 0
	_movie_loading = true
	if is_instance_valid(_movie_skip_button):
		_movie_skip_button.disabled = true
	if is_instance_valid(_movie_title):
		_movie_title.text = GameData.MOVIE_LOADING_TEXT
	if is_instance_valid(_movie_seek):
		_movie_seek.value = 0.0
		_movie_seek.max_value = 1.0
	if _movie_client != null and _movie_client.has_method("fetch_random"):
		var captured: String = exclude_id
		call_deferred("_start_skipped_movie_fetch", captured)
	else:
		_on_movie_failed("no_client")


func _start_skipped_movie_fetch(exclude_id: String) -> void:
	if not _movie_open():
		_reset_movie_button()
		if is_instance_valid(_movie_skip_button):
			_movie_skip_button.disabled = false
		return
	if _movie_client != null and _movie_client.has_method("fetch_random"):
		_movie_client.fetch_random(exclude_id, _movie_genre)
	else:
		_on_movie_failed("no_client")


func _play_movie_file(path: String) -> void:
	if not is_instance_valid(_movie_player):
		return
	if not GameData.movie_file_is_theora(path):
		print("%s movie file rejected path=%s" % [VIDEO_LOG_PREFIX, path])
		_close_movie()
		_on_movie_failed("not_theora")
		return
	_movie_path = path
	_movie_id = GameData.movie_id_from_path(path)
	_movie_expected_bytes = GameData.movie_expected_bytes(_movie_id)
	_movie_last_bytes = GameData.file_byte_count(path)
	_movie_reload_cd = GameData.MOVIE_DURATION_RELOAD_SECONDS
	var play_path: String = path
	if path.begins_with("user://") or path.begins_with("res://"):
		play_path = ProjectSettings.globalize_path(path)
	var stream: VideoStreamTheora = VideoStreamTheora.new()
	stream.file = play_path
	_movie_player.stream = stream
	_movie_speed = 1.0
	_set_movie_speed(1.0)
	_apply_movie_audio()
	_movie_player.play()
	_movie_seeking = false
	_sync_movie_seek_range(0.0)
	if _movie_player.get_stream_length() <= 0.0 and not _movie_player.is_playing():
		print("%s movie player did not start path=%s" % [VIDEO_LOG_PREFIX, play_path])


func _stop_movie_player() -> void:
	if is_instance_valid(_movie_player):
		_movie_player.stop()
		_movie_player.stream = null
	_movie_path = ""
	_movie_id = ""
	_movie_expected_bytes = 0
	_movie_last_bytes = 0


func _close_movie() -> void:
	_stop_movie_player()
	_movie_maximized = false
	if _movie_client != null and _movie_client.has_method("cancel_fetch"):
		_movie_client.cancel_fetch()
	_reset_movie_button()
	if is_instance_valid(_movie_skip_button):
		_movie_skip_button.disabled = false
	if is_instance_valid(_movie_popup):
		_movie_popup.visible = false
	_hide_speech_bubble()
	_restore_overlay_window_if_idle()
	if not _any_overlay_open() and _state != State.RUNAWAY:
		_set_pet_layer_visible(true)
	call_deferred("_try_show_speech")


func _toggle_movie_maximize() -> void:
	if not _movie_open() or not _can_move_window():
		return
	if _movie_maximized:
		_movie_maximized = false
		DisplayServer.window_set_size(_movie_restore_size)
		DisplayServer.window_set_position(_clamp_to_screen(_movie_restore_pos))
		if is_instance_valid(_movie_max_button):
			_movie_max_button.text = GameData.MOVIE_MAX_TEXT
		return
	_movie_restore_size = DisplayServer.window_get_size()
	_movie_restore_pos = DisplayServer.window_get_position()
	_movie_maximized = true
	var usable: Rect2i = DisplayServer.screen_get_usable_rect()
	DisplayServer.window_set_size(usable.size)
	DisplayServer.window_set_position(usable.position)
	if is_instance_valid(_movie_max_button):
		_movie_max_button.text = GameData.MOVIE_RESTORE_TEXT


func _begin_movie_resize(edge: Vector2i) -> void:
	if _movie_maximized or not _can_move_window():
		return
	_dragging = false
	_movie_resizing = true
	_movie_resize_edge = edge
	_movie_resize_start_mouse = DisplayServer.mouse_get_position()
	_movie_resize_start_pos = DisplayServer.window_get_position()
	_movie_resize_start_size = DisplayServer.window_get_size()


func _apply_movie_resize() -> void:
	if not _movie_resizing or not _can_move_window():
		return
	var mouse: Vector2i = DisplayServer.mouse_get_position()
	var delta: Vector2i = mouse - _movie_resize_start_mouse
	var pos: Vector2i = _movie_resize_start_pos
	var new_size: Vector2i = _movie_resize_start_size
	if _movie_resize_edge.x < 0:
		new_size.x = _movie_resize_start_size.x - delta.x
		pos.x = _movie_resize_start_pos.x + delta.x
	elif _movie_resize_edge.x > 0:
		new_size.x = _movie_resize_start_size.x + delta.x
	if _movie_resize_edge.y < 0:
		new_size.y = _movie_resize_start_size.y - delta.y
		pos.y = _movie_resize_start_pos.y + delta.y
	elif _movie_resize_edge.y > 0:
		new_size.y = _movie_resize_start_size.y + delta.y
	new_size.x = maxi(new_size.x, GameData.MOVIE_WINDOW_MIN.x)
	new_size.y = maxi(new_size.y, GameData.MOVIE_WINDOW_MIN.y)
	if _movie_resize_edge.x < 0:
		pos.x = _movie_resize_start_pos.x + (_movie_resize_start_size.x - new_size.x)
	if _movie_resize_edge.y < 0:
		pos.y = _movie_resize_start_pos.y + (_movie_resize_start_size.y - new_size.y)
	DisplayServer.window_set_size(new_size)
	DisplayServer.window_set_position(_clamp_to_screen(pos))


func _set_movie_speed(speed: float) -> void:
	_movie_speed = speed
	if not is_instance_valid(_movie_speed_box):
		return
	for child: Node in _movie_speed_box.get_children():
		var button: Button = child as Button
		if button == null:
			continue
		button.button_pressed = is_equal_approx(float(button.get_meta("speed", 1.0)), speed)
	if is_instance_valid(_movie_player):
		if is_equal_approx(speed, 1.0):
			_movie_player.paused = false
		else:
			_movie_player.paused = true
	_apply_movie_audio()


func _seek_movie_to(seconds: float) -> void:
	if not is_instance_valid(_movie_player) or _movie_player.stream == null:
		return
	var length: float = _movie_seek_length()
	if length <= 0.0:
		return
	_movie_player.stream_position = clampf(seconds, 0.0, length)


func _movie_seek_length() -> float:
	var stream_len: float = 0.0
	if is_instance_valid(_movie_player):
		stream_len = _movie_player.get_stream_length()
	var bytes: int = GameData.file_byte_count(_movie_path)
	if _movie_expected_bytes > 0 and bytes > 0 and bytes < _movie_expected_bytes and stream_len > 0.0:
		return maxf(stream_len, stream_len * float(_movie_expected_bytes) / float(bytes))
	return maxf(stream_len, 1.0)


func _sync_movie_seek_range(position: float = -1.0) -> void:
	if not is_instance_valid(_movie_seek):
		return
	var length: float = _movie_seek_length()
	_movie_seek.max_value = length
	if position >= 0.0:
		_movie_seek.value = clampf(position, 0.0, length)


func _refresh_movie_stream(keep_position: bool) -> void:
	if not is_instance_valid(_movie_player) or _movie_path.is_empty():
		return
	if not GameData.movie_file_is_theora(_movie_path):
		return
	var pos: float = _movie_player.stream_position if keep_position else 0.0
	var play_path: String = _movie_path
	if play_path.begins_with("user://") or play_path.begins_with("res://"):
		play_path = ProjectSettings.globalize_path(play_path)
	var stream: VideoStreamTheora = VideoStreamTheora.new()
	stream.file = play_path
	_movie_player.stream = stream
	_movie_player.play()
	if keep_position:
		_movie_player.stream_position = pos
	_set_movie_speed(_movie_speed)
	_apply_movie_audio()
	_sync_movie_seek_range(pos if keep_position else 0.0)


func _apply_movie_audio() -> void:
	if not is_instance_valid(_movie_player):
		return
	var muted: bool = _movie_muted or not is_equal_approx(_movie_speed, 1.0)
	if is_instance_valid(_movie_mute_button):
		_movie_mute_button.text = GameData.MOVIE_UNMUTE_TEXT if _movie_muted else GameData.MOVIE_MUTE_TEXT
	if muted or _movie_volume_linear <= 0.001:
		_movie_player.volume_db = -80.0
	else:
		_movie_player.volume_db = linear_to_db(_movie_volume_linear)


func _tick_movie_playback(delta: float) -> void:
	if not _movie_open() or not is_instance_valid(_movie_player):
		return
	if _movie_player.stream == null:
		return
	if not _movie_path.is_empty() and not _movie_seeking:
		_movie_reload_cd -= delta
		var bytes: int = GameData.file_byte_count(_movie_path)
		var still_loading: bool = (
			_movie_expected_bytes > 0 and bytes > 0 and bytes < int(float(_movie_expected_bytes) * 0.98)
		)
		if still_loading and _movie_reload_cd <= 0.0 and bytes > _movie_last_bytes:
			_movie_last_bytes = bytes
			_movie_reload_cd = GameData.MOVIE_DURATION_RELOAD_SECONDS
			_refresh_movie_stream(true)
		elif _movie_reload_cd <= 0.0:
			_movie_reload_cd = GameData.MOVIE_DURATION_RELOAD_SECONDS
	if is_instance_valid(_movie_seek) and not _movie_seeking:
		_sync_movie_seek_range(_movie_player.stream_position)
	if is_equal_approx(_movie_speed, 1.0):
		return
	_movie_player.paused = true
	_movie_player.stream_position = _movie_player.stream_position + delta * _movie_speed


func _setup_recharge_ui() -> void:
	_recharge_client = preload("res://scripts/recharge_client.gd").new()
	_recharge_popup = Control.new()
	_recharge_popup.name = "RechargePopup"
	_recharge_popup.visible = false
	_recharge_popup.z_index = 23
	_recharge_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_recharge_popup)
	_recharge_chrome = Panel.new()
	_recharge_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_recharge_chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_recharge_popup.add_child(_recharge_chrome)
	var body: VBoxContainer = VBoxContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 16.0
	body.offset_top = 12.0
	body.offset_right = -16.0
	body.offset_bottom = -12.0
	body.add_theme_constant_override("separation", 10)
	_recharge_popup.add_child(body)
	var header: HBoxContainer = HBoxContainer.new()
	header.custom_minimum_size.y = GameData.INVENTORY_HEADLINE_HEIGHT
	header.add_theme_constant_override("separation", 8)
	body.add_child(header)
	var headline: PanelContainer = PanelContainer.new()
	headline.add_theme_stylebox_override("panel", _headline_box(GameData.DRAWER_HEADLINE_COLOR))
	var title: Label = Label.new()
	title.text = GameData.RECHARGE_TITLE_TEXT
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	headline.add_child(title)
	header.add_child(headline)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)
	var close_button: Button = Button.new()
	close_button.text = "关闭"
	close_button.theme_type_variation = &"CloseButton"
	close_button.custom_minimum_size = Vector2(72.0, GameData.INVENTORY_HEADLINE_HEIGHT)
	close_button.pressed.connect(func() -> void:
		_close_recharge()
	)
	header.add_child(close_button)
	_recharge_status = Label.new()
	_recharge_status.text = GameData.RECHARGE_STATUS_TEXT
	_recharge_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recharge_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_recharge_status)
	_recharge_region_box = HBoxContainer.new()
	_recharge_region_box.add_theme_constant_override("separation", 8)
	body.add_child(_recharge_region_box)
	for entry: Dictionary in GameData.RECHARGE_REGIONS:
		var region_id: String = String(entry.get("id", GameData.RECHARGE_REGION_US))
		var region_button: Button = Button.new()
		region_button.toggle_mode = true
		region_button.text = String(entry.get("label", region_id))
		region_button.set_meta("region", region_id)
		region_button.custom_minimum_size = Vector2(120.0, 40.0)
		region_button.theme_type_variation = &"CoinButton"
		var captured: String = region_id
		region_button.pressed.connect(func() -> void:
			_set_recharge_region(captured)
		)
		_recharge_region_box.add_child(region_button)
	_recharge_sku_box = HBoxContainer.new()
	_recharge_sku_box.add_theme_constant_override("separation", 8)
	body.add_child(_recharge_sku_box)
	var notes_scroll: ScrollContainer = ScrollContainer.new()
	notes_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notes_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	notes_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	body.add_child(notes_scroll)
	_recharge_notes = Label.new()
	_recharge_notes.text = GameData.RECHARGE_NOTES
	_recharge_notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recharge_notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recharge_notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notes_scroll.add_child(_recharge_notes)
	_recharge_popup.gui_input.connect(func(event: InputEvent) -> void:
		_process_drag_input(event)
	)
	_rebuild_recharge_skus()
	_refresh_recharge_region_buttons()
	_restyle_new_overlay(_recharge_popup)


func _set_recharge_region(region: String) -> void:
	if region != GameData.RECHARGE_REGION_US and region != GameData.RECHARGE_REGION_CN:
		return
	_recharge_region = region
	_rebuild_recharge_skus()
	_refresh_recharge_region_buttons()


func _refresh_recharge_region_buttons() -> void:
	if not is_instance_valid(_recharge_region_box):
		return
	for child: Node in _recharge_region_box.get_children():
		var button: Button = child as Button
		if button == null:
			continue
		button.button_pressed = String(button.get_meta("region", "")) == _recharge_region


func _rebuild_recharge_skus() -> void:
	if not is_instance_valid(_recharge_sku_box) or _recharge_client == null:
		return
	while _recharge_sku_box.get_child_count() > 0:
		var child: Node = _recharge_sku_box.get_child(0)
		_recharge_sku_box.remove_child(child)
		child.free()
	for entry: Dictionary in GameData.RECHARGE_SKUS:
		var sku_id: String = String(entry.get("id", ""))
		var coins: int = int(entry.get("coins", 0))
		var price: String = String(_recharge_client.price_label(entry, _recharge_region))
		var sku_button: Button = Button.new()
		sku_button.text = "%d  %s" % [coins, price]
		sku_button.theme_type_variation = &"EquipButton"
		sku_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sku_button.custom_minimum_size = Vector2(0.0, 48.0)
		var captured: String = sku_id
		sku_button.pressed.connect(func() -> void:
			_try_recharge_sku(captured)
		)
		_recharge_sku_box.add_child(sku_button)


func _try_recharge_sku(sku_id: String) -> void:
	if _recharge_client == null:
		if is_instance_valid(_recharge_status):
			_recharge_status.text = GameData.RECHARGE_STATUS_TEXT
		return
	var result: Dictionary = _recharge_client.create_order(sku_id, _recharge_region)
	var reason: String = String(result.get("reason", "not_connected"))
	if is_instance_valid(_recharge_status):
		if reason == "unsupported_region":
			_recharge_status.text = "这个地区还没接通。"
		elif reason == "unknown_sku":
			_recharge_status.text = "没有这个档位。"
		else:
			_recharge_status.text = GameData.RECHARGE_STATUS_TEXT
	print("%s recharge stub sku=%s region=%s reason=%s" % [
		VIDEO_LOG_PREFIX, sku_id, _recharge_region, reason,
	])


func _open_recharge() -> void:
	if _state == State.RUNAWAY:
		return
	_hide_speech_bubble()
	if is_instance_valid(_exit_popup):
		_exit_popup.visible = false
	if is_instance_valid(_settings_panel):
		_settings_panel.visible = false
	if is_instance_valid(_inventory_popup):
		_inventory_popup.visible = false
	if is_instance_valid(_chat_popup):
		_chat_popup.visible = false
	if is_instance_valid(_fortune_popup):
		_fortune_popup.visible = false
	if is_instance_valid(_movie_pick_popup):
		_movie_pick_popup.visible = false
	if _movie_open():
		_hide_fortune_and_movie()
	_inventory_kind = ""
	_set_pet_layer_visible(false)
	_expand_overlay_window(GameData.RECHARGE_WINDOW_SIZE)
	if is_instance_valid(_recharge_status):
		_recharge_status.text = GameData.RECHARGE_STATUS_TEXT
	_rebuild_recharge_skus()
	_refresh_recharge_region_buttons()
	if is_instance_valid(_recharge_popup):
		_recharge_popup.visible = true


func _close_recharge() -> void:
	if is_instance_valid(_recharge_popup):
		_recharge_popup.visible = false
	_hide_speech_bubble()
	_restore_overlay_window_if_idle()
	if not _any_overlay_open() and _state != State.RUNAWAY:
		_set_pet_layer_visible(true)
	call_deferred("_try_show_speech")
