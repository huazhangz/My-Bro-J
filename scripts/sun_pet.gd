extends Control

## Steve 桌宠主脚本
##
## 默认只显示角色立绘。左键拖拽窗口，右键在角色上打开退出确认。
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
const USER_SOURCE_MP4: String = "C:/Users/ASUS/Desktop/Steve1.mp4"
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
@onready var _pet_video: VideoStreamPlayer = %PetVideo
@onready var _pet_frame: TextureRect = %PetFrame
@onready var _placeholder_visual: Control = %PlaceholderVisual
@onready var _exit_popup: PanelContainer = %ExitPopup
@onready var _quit_app_button: Button = %QuitAppButton
@onready var _cancel_exit_button: Button = %CancelExitButton

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


func _ready() -> void:
	_debug_log = OS.get_cmdline_user_args().has("--petlog")
	_apply_window_setup()
	_connect_exit_popup()
	_setup_pet_video()
	_connect_game_data()
	_start_wash_cycle()


func _is_embedded_in_editor() -> bool:
	return OS.get_cmdline_args().has("--wid")


func _apply_window_setup() -> void:
	var win: Window = get_window()
	win.transparent_bg = true

	_embedded = _is_embedded_in_editor()
	if _embedded:
		push_warning("窗口被编辑器内嵌运行，无法拖拽。请在 Game 面板关闭 Embed Game on Play。")
		return

	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)

	var usable: Rect2i = DisplayServer.screen_get_usable_rect()
	var window_size: Vector2i = DisplayServer.window_get_size()
	var target: Vector2i = Vector2i(
		usable.position.x + usable.size.x - window_size.x - 80,
		usable.position.y + usable.size.y - window_size.y - 80
	)
	DisplayServer.window_set_position(target)


func _connect_exit_popup() -> void:
	_quit_app_button.pressed.connect(func() -> void:
		get_tree().quit()
	)
	_cancel_exit_button.pressed.connect(func() -> void:
		_close_exit_popup()
	)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if _state != State.RUNAWAY and _is_pointer_on_pet(mb.position):
				_open_exit_popup()
			else:
				_close_exit_popup()
			accept_event()
			return
		if mb.button_index == DRAG_BUTTON and mb.pressed:
			if _exit_popup.visible:
				if _exit_popup.get_global_rect().has_point(mb.global_position):
					return
				_close_exit_popup()
				accept_event()
				return
			_begin_drag()
			accept_event()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == DRAG_BUTTON and not mb.pressed:
			_dragging = false
		elif mb.pressed and _exit_popup.visible:
			if not _exit_popup.get_global_rect().has_point(mb.global_position):
				_close_exit_popup()
	elif event is InputEventKey:
		var key: InputEventKey = event
		if not key.pressed:
			return
		if key.keycode == KEY_ESCAPE:
			if _exit_popup.visible:
				_close_exit_popup()
			else:
				get_tree().quit()


func _begin_drag() -> void:
	if _embedded:
		return
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


func _connect_game_data() -> void:
	GameData.warehouse_changed.connect(func(_current: int, _capacity: int) -> void:
		_try_resume_wash()
	)
	GameData.item_washed.connect(func(item: Dictionary) -> void:
		var quality: int = int(item["quality"])
		_log("washed #%d %s -> wet=%d/%d" % [
			int(item["id"]),
			String(GameData.QUALITY_NAMES[quality]),
			GameData.wet_warehouse.size(),
			GameData.WAREHOUSE_CAPACITY,
		])
	)
	GameData.item_dried.connect(func(item: Dictionary) -> void:
		var quality: int = int(item["quality"])
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

	if _video_enabled and not _video_fitted:
		_tick_video_probe()
	elif _video_enabled and chroma_key_enabled:
		_feed_pet_frame_texture()


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
	var timer: Timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = GameData.DRY_DURATION
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
	_close_exit_popup()
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH, hide_pet)


func _setup_pet_video() -> void:
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
	var from_stream: String = _stream_file_path(_pet_video.stream)
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
		print_verbose("%s desktop source not found: %s" % [VIDEO_LOG_PREFIX, USER_SOURCE_MP4])
		return ""
	print_rich("[color=#54d18c]%s找到桌面素材：%s[/color]" % [VIDEO_LOG_PREFIX, source])
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
	var candidates: PackedStringArray = PackedStringArray([
		USER_SOURCE_MP4,
		"C:/Users/ASUS/Desktop/Steve1.ogv",
		"/mnt/c/Users/ASUS/Desktop/Steve1.mp4",
		"/mnt/c/Users/ASUS/Desktop/Steve1.ogv",
	])
	for path: String in candidates:
		if FileAccess.file_exists(path):
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
	return USER_SOURCE_MP4


func _convert_hint(source_path: String) -> String:
	var target: String = ProjectSettings.globalize_path(VIDEO_PATH)
	var source: String = USER_SOURCE_MP4
	var lead: String = "Godot 4 只能播 Ogg Theora（.ogv），用 FFmpeg 把绿幕 mp4 转一次："
	if source_path == VIDEO_PATH:
		source = USER_SOURCE_MP4
		lead = "Godot 4 只能播 Ogg Theora（.ogv）。请把桌面上的 Steve1.mp4 转成 steve.ogv："
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
	_pet_video.stop()
	_pet_video.stream = null
	_refresh_visual_swap()
	print_rich("[color=#ff8b6a]%s未启用动态立绘，已回落到几何占位。[/color]" % VIDEO_LOG_PREFIX)
	print_rich("[color=#ff8b6a]%s  原因：%s[/color]" % [VIDEO_LOG_PREFIX, reason])
	if not hint.is_empty():
		print_rich("[color=#ffcc66]%s  怎么修：%s[/color]" % [VIDEO_LOG_PREFIX, hint])
	push_warning("动态立绘未启用：%s" % reason)


func _refresh_visual_swap() -> void:
	_placeholder_visual.visible = not _video_enabled
	_sync_video_display()


func _sync_video_display() -> void:
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
	print_rich("[color=#ffcc66]%s  当前播的是仓库自带的彩色测试片（%d 字节），不是 Steve 正片。[/color]" % [
		VIDEO_LOG_PREFIX, byte_count,
	])
	print_rich("[color=#ffcc66]%s  把转好的 .ogv 覆盖到 %s 后再按 F5。[/color]" % [
		VIDEO_LOG_PREFIX, ProjectSettings.globalize_path(VIDEO_PATH),
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


func _apply_video_key() -> void:
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
	else:
		print_verbose("%s chroma key OFF — showing VideoStreamPlayer directly" % VIDEO_LOG_PREFIX)


func set_chroma_key_enabled(enabled: bool) -> void:
	chroma_key_enabled = enabled


func apply_chroma_key(color: Color, similarity: float = 0.35, smoothness: float = 0.10) -> void:
	chroma_key_color = color
	chroma_key_similarity = similarity
	chroma_key_smoothness = smoothness
	chroma_key_enabled = true


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
	print_verbose("%s exit popup open" % VIDEO_LOG_PREFIX)


func _close_exit_popup() -> void:
	if is_instance_valid(_exit_popup):
		_exit_popup.visible = false


func _log(message: String) -> void:
	if _debug_log:
		print("[Steve] ", message)
