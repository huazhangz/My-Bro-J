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
const VIDEO_AREA: Rect2 = Rect2(5.0, 5.0, 240.0, 340.0)
const VIDEO_PROBE_FRAMES: int = 45
const VIDEO_LOG_PREFIX: String = "[Steve/Video] "
const STUB_VIDEO_MAX_BYTES: int = 80000

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
@export_range(0.0, 1.0, 0.01) var chroma_key_similarity: float = 0.35:
	set(value):
		chroma_key_similarity = value
		if is_node_ready():
			_apply_video_key()
@export_range(0.0, 1.0, 0.01) var chroma_key_smoothness: float = 0.10:
	set(value):
		chroma_key_smoothness = value
		if is_node_ready():
			_apply_video_key()

@onready var _pet_visual: Control = %PetVisual
## 不用 `%PetVideo` 的 @onready：节点缺失时 Godot 会在进树时直接报错并留下 null。
var _pet_video: VideoStreamPlayer
@onready var _pet_frame: TextureRect = %PetFrame
@onready var _placeholder_visual: Control = %PlaceholderVisual
@onready var _exit_popup: PanelContainer = %ExitPopup
@onready var _dryer_button: Button = %DryerButton
@onready var _drawer_button: Button = %DrawerButton
@onready var _quit_app_button: Button = %QuitAppButton
@onready var _inventory_popup: Control = %InventoryPopup
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
var _inventory_window_open: bool = false
var _base_window_size: Vector2i = Vector2i.ZERO
var _base_window_pos: Vector2i = Vector2i.ZERO
var _hover_time: float = 0.0
var _hover_hud_shown: bool = false
var _hover_tween: Tween


func _ready() -> void:
	get_tree().root.gui_embed_subwindows = false
	_debug_log = OS.get_cmdline_user_args().has("--petlog")
	print("%s build=qualities-wear-dryer-drawer  scene=%s  menu=烘干机/抽屉/退出游戏" % [
		VIDEO_LOG_PREFIX, scene_file_path,
	])
	_ensure_pet_video_node()
	_apply_mouse_filters()
	_apply_window_setup()
	_ingest_user_images()
	_apply_video_key()
	_connect_exit_popup()
	_setup_pet_video()
	_connect_game_data()
	_start_wash_cycle()


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
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true, 0)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true, 0)

	var usable: Rect2i = DisplayServer.screen_get_usable_rect()
	var window_size: Vector2i = DisplayServer.window_get_size()
	var target: Vector2i = Vector2i(
		usable.position.x + usable.size.x - window_size.x - 80,
		usable.position.y + usable.size.y - window_size.y - 80
	)
	DisplayServer.window_set_position(target)


func _ingest_user_images() -> void:
	var dryer: Texture2D = GameData.load_image_texture(GameData.USER_DRYER_FILE)
	if dryer != null:
		_inventory_bg.texture = dryer
		print("%s dryer bg <- %s" % [VIDEO_LOG_PREFIX, GameData.first_existing_file(GameData.USER_DRYER_FILE)])
	var steve2_path: String = GameData.first_existing_file(GameData.USER_STEVE2_FILE)
	if not steve2_path.is_empty():
		print("%s Steve2.jpg found: %s" % [VIDEO_LOG_PREFIX, steve2_path])


func _connect_exit_popup() -> void:
	_dryer_button.pressed.connect(func() -> void:
		_open_inventory("dryer")
	)
	_drawer_button.pressed.connect(func() -> void:
		_open_inventory("drawer")
	)
	_quit_app_button.pressed.connect(func() -> void:
		get_tree().quit()
	)
	_inventory_close_button.pressed.connect(func() -> void:
		_close_inventory()
	)
	_inventory_popup.gui_input.connect(func(event: InputEvent) -> void:
		_process_drag_input(event)
	)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if _inventory_popup.visible:
				_close_inventory()
				accept_event()
				return
			if _state != State.RUNAWAY and _is_pointer_on_pet(mb.position):
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
				get_tree().quit()


func _placeholder_from_still(texture: Texture2D) -> void:
	if _video_enabled:
		return
	_placeholder_visual.visible = false
	_pet_frame.texture = texture
	_pet_frame.visible = true
	_pet_frame.material = null


func _is_click_on_blocking_ui(global_pos: Vector2) -> bool:
	if _exit_popup.visible and _exit_popup.get_global_rect().has_point(global_pos):
		return true
	if _inventory_popup.visible and _inventory_close_button.get_global_rect().has_point(global_pos):
		return true
	return false


func _process_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != DRAG_BUTTON:
			return
		if mb.pressed:
			if _state == State.RUNAWAY:
				return
			if _is_click_on_blocking_ui(mb.global_position):
				return
			if _exit_popup.visible:
				_close_exit_popup()
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


func _trigger_runaway() -> void:
	_state = State.RUNAWAY
	_cooldown_remaining = GameData.get_calculated_cooldown()
	_dragging = false
	_close_exit_popup()
	_close_inventory()
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
	_pet_video.position = VIDEO_AREA.position
	_pet_video.size = VIDEO_AREA.size
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
		_fail_video("在 %s 里没找到任何 .ogv 文件。%s" % [VIDEO_DIR, _describe_video_dir()],
			_convert_hint(_find_unplayable_source()))
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
	_warn_if_stub_video(path)
	_log_chroma_key_state()


func _on_video_finished() -> void:
	if _video_enabled and not _pet_video.is_playing():
		_pet_video.play()


func _resolve_video_path() -> String:
	var ingested: String = _ingest_desktop_source()
	if not ingested.is_empty():
		return ingested
	if FileAccess.file_exists(VIDEO_PATH):
		return VIDEO_PATH
	var from_stream: String = _stream_file_path(_pet_video.stream if is_instance_valid(_pet_video) else null)
	if not from_stream.is_empty() and FileAccess.file_exists(from_stream):
		return from_stream
	for file_name: String in _video_dir_files():
		var clean: String = file_name.trim_suffix(".remap")
		if clean.get_extension().to_lower() == "ogv":
			return "%s/%s" % [VIDEO_DIR, clean]
	return ""


func _ingest_desktop_source() -> String:
	var source: String = _find_desktop_source()
	if source.is_empty():
		print_verbose("%s user video not found: %s/%s" % [
			VIDEO_LOG_PREFIX, GameData.USER_PROJECT_DIR, GameData.USER_VIDEO_FILE,
		])
		return ""
	print_rich("[color=#54d18c]%s找到本机素材：%s[/color]" % [VIDEO_LOG_PREFIX, source])
	if source.get_extension().to_lower() == "ogv":
		return source
	var dest_os: String = ProjectSettings.globalize_path(USER_CACHE_OGV)
	if FileAccess.file_exists(USER_CACHE_OGV):
		var src_mtime: int = FileAccess.get_modified_time(source)
		var dst_mtime: int = FileAccess.get_modified_time(USER_CACHE_OGV)
		if dst_mtime >= src_mtime:
			print_verbose("%s chroma-ready cache hit: %s" % [VIDEO_LOG_PREFIX, USER_CACHE_OGV])
			return USER_CACHE_OGV
	if _run_ffmpeg_theora(source, dest_os):
		print_rich("[color=#54d18c]%s已转码绿幕视频 -> %s[/color]" % [VIDEO_LOG_PREFIX, USER_CACHE_OGV])
		return USER_CACHE_OGV
	print_rich("[color=#ffcc66]%sFFmpeg 转码失败，回落到仓库里的 .ogv。[/color]" % VIDEO_LOG_PREFIX)
	return ""


func _find_desktop_source() -> String:
	var names: PackedStringArray = PackedStringArray([
		GameData.USER_VIDEO_FILE,
		"steve1.mp4",
		"Steve1.ogv",
		"steve1.ogv",
	])
	for file_name: String in names:
		var path: String = GameData.first_existing_file(file_name)
		if not path.is_empty():
			return path
	return ""


func _run_ffmpeg_theora(source: String, dest_os: String) -> bool:
	var args: PackedStringArray = PackedStringArray([
		"-y", "-i", source,
		"-vf", "fps=24,scale=460:-2",
		"-c:v", "libtheora", "-q:v", "8", "-an", dest_os,
	])
	var output: Array = []
	var code: int = OS.execute("ffmpeg", args, output, true)
	if code != 0:
		print_verbose("%s ffmpeg exit=%d  %s" % [VIDEO_LOG_PREFIX, code, str(output)])
		return false
	return FileAccess.file_exists(USER_CACHE_OGV)


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
		lead = "Godot 4 只能播 Ogg Theora（.ogv）。请把仓库根目录的 Steve1.mp4 转成 steve.ogv："
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


func _warn_if_stub_video(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var byte_count: int = file.get_length()
	file.close()
	if byte_count <= 0 or byte_count > STUB_VIDEO_MAX_BYTES:
		return
	print_rich("[color=#ffcc66]%s  Detected placeholder video (%d bytes). Please double-click convert_video.bat in the project folder to convert your Steve1.mp4 to steve.ogv, then press F5 again.[/color]" % [
		VIDEO_LOG_PREFIX, byte_count,
	])


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

	var ratio: float = minf(VIDEO_AREA.size.x / source.x, VIDEO_AREA.size.y / source.y)
	var fitted: Vector2 = source * ratio
	_pet_video.position = VIDEO_AREA.position + (VIDEO_AREA.size - fitted) * 0.5
	_pet_video.size = fitted
	_sync_video_display()
	return true


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


func _apply_chroma_material(rect: TextureRect, similarity: float, smoothness: float) -> void:
	if not is_instance_valid(rect):
		return
	var key_material: ShaderMaterial = rect.material as ShaderMaterial
	if key_material == null:
		key_material = ShaderMaterial.new()
		key_material.shader = load("res://assets/videos/video_key.gdshader") as Shader
		rect.material = key_material
	key_material.set_shader_parameter("key_color",
		Vector3(chroma_key_color.r, chroma_key_color.g, chroma_key_color.b))
	key_material.set_shader_parameter("similarity", similarity)
	key_material.set_shader_parameter("smoothness", maxf(smoothness, 0.001))


func _apply_video_key() -> void:
	_apply_chroma_material(_pet_frame, chroma_key_similarity, chroma_key_smoothness)
	_apply_chroma_material(_inventory_bg, maxf(chroma_key_similarity, 0.42), maxf(chroma_key_smoothness, 0.12))


func _log_chroma_key_state() -> void:
	if chroma_key_enabled:
		print_verbose("%s chroma key ON  color=#%s  similarity=%.2f  smoothness=%.2f  frame_visible=%s" % [
			VIDEO_LOG_PREFIX,
			chroma_key_color.to_html(false),
			chroma_key_similarity,
			chroma_key_smoothness,
			_pet_frame.visible if is_instance_valid(_pet_frame) else false,
		])
	else:
		print_verbose("%s chroma key OFF — showing VideoStreamPlayer directly" % VIDEO_LOG_PREFIX)


func set_chroma_key_enabled(enabled: bool) -> void:
	chroma_key_enabled = enabled


func apply_chroma_key(color: Color, similarity: float = 0.35, smoothness: float = 0.10) -> void:
	chroma_key_color = color
	chroma_key_similarity = similarity
	chroma_key_smoothness = smoothness
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


func _refresh_wash_progress() -> void:
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
	if is_instance_valid(_hover_tween):
		_hover_tween.kill()
	var start_y: float = 14.0 if show_hud else 8.0
	var end_y: float = 8.0 if show_hud else 14.0
	var end_alpha: float = 1.0 if show_hud else 0.0
	if not animate:
		_hover_hud.modulate.a = end_alpha
		_hover_hud.position.y = end_y
		return
	_hover_hud.position.y = start_y
	_hover_tween = create_tween()
	_hover_tween.set_parallel(true)
	_hover_tween.set_trans(Tween.TRANS_CUBIC)
	_hover_tween.set_ease(Tween.EASE_OUT if show_hud else Tween.EASE_IN)
	_hover_tween.tween_property(_hover_hud, "modulate:a", end_alpha, GameData.HOVER_FADE_SECONDS)
	_hover_tween.tween_property(_hover_hud, "position:y", end_y, GameData.HOVER_FADE_SECONDS)


func _is_pointer_on_pet(local_pos: Vector2) -> bool:
	if _placeholder_visual.visible:
		return VIDEO_AREA.has_point(local_pos)
	var video_rect: Rect2 = Rect2(_pet_video.position, _pet_video.size)
	if video_rect.size.x <= 1.0 or video_rect.size.y <= 1.0:
		return VIDEO_AREA.has_point(local_pos)
	return video_rect.has_point(local_pos)


func _open_exit_popup() -> void:
	if _state == State.RUNAWAY:
		return
	_exit_popup.visible = true
	print_verbose("%s context menu open" % VIDEO_LOG_PREFIX)


func _close_exit_popup() -> void:
	if is_instance_valid(_exit_popup):
		_exit_popup.visible = false


func _open_inventory(kind: String) -> void:
	if _state == State.RUNAWAY:
		return
	_inventory_kind = kind
	_close_exit_popup()
	_expand_inventory_window()
	_inventory_title.text = "烘干机" if kind == "dryer" else "抽屉"
	_inventory_grid.columns = GameData.GRID_COLUMNS
	_inventory_popup.visible = true
	_fill_inventory_grid()


func _close_inventory() -> void:
	if is_instance_valid(_inventory_popup):
		_inventory_popup.visible = false
	_inventory_kind = ""
	_restore_inventory_window()


func _expand_inventory_window() -> void:
	if _inventory_window_open or not _can_move_window():
		return
	_base_window_size = DisplayServer.window_get_size()
	_base_window_pos = DisplayServer.window_get_position()
	var scaled: Vector2i = Vector2i(
		maxi(int(VIDEO_AREA.size.x * GameData.INVENTORY_SCALE), 400),
		maxi(int(VIDEO_AREA.size.y * GameData.INVENTORY_SCALE), 500)
	)
	DisplayServer.window_set_size(scaled)
	DisplayServer.window_set_position(_clamp_to_screen(_base_window_pos))
	_inventory_window_open = true


func _restore_inventory_window() -> void:
	if not _inventory_window_open:
		return
	if _can_move_window():
		DisplayServer.window_set_size(_base_window_size)
		DisplayServer.window_set_position(_base_window_pos)
	_inventory_window_open = false


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
	wear_label.theme_type_variation = &"SmallLabel"
	col.add_child(wear_label)

	var quality_label: Label = Label.new()
	quality_label.text = quality_name
	quality_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quality_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quality_label.add_theme_color_override("font_color", accent)
	col.add_child(quality_label)
	return card


func _log(message: String) -> void:
	if _debug_log:
		print("[Steve] ", message)
