class_name WebMovieEmbed
extends Node

## Windows：把 Edge/Chrome --app 窗口嵌进桌宠 HWND。
## 其它平台或 10 秒内嵌失败：由 UI 给出「用系统浏览器打开」。

signal embedding_ready
signal embedding_failed

var _pid: int = -1
var _active: bool = false
var _ready: bool = false
var _url: String = ""
var _last_cmd: String = ""
var _session: int = 0


func is_active() -> bool:
	return _active


func is_embedded() -> bool:
	return _ready


func current_url() -> String:
	return _url


func start(url: String, parent_hwnd: int, rect: Rect2i, volume: float, mute: bool) -> void:
	stop()
	_session += 1
	_url = url.strip_edges()
	_active = true
	_ready = false
	_write_cmd(parent_hwnd, rect, volume, mute, false)
	if OS.get_name() != "Windows":
		print("%s web embed needs Windows Edge/Chrome" % GameData.MOVIE_LOG_PREFIX)
		_fail()
		return
	if parent_hwnd <= 0:
		print("%s web embed missing HWND" % GameData.MOVIE_LOG_PREFIX)
		_fail()
		return
	var script_path: String = _copy_host_script()
	if script_path.is_empty():
		print("%s web host script missing" % GameData.MOVIE_LOG_PREFIX)
		_fail()
		return
	var cmd_path: String = ProjectSettings.globalize_path(GameData.MOVIE_WEB_CMD_PATH)
	var args: PackedStringArray = PackedStringArray([
		"-NoProfile",
		"-WindowStyle",
		"Hidden",
		"-ExecutionPolicy",
		"Bypass",
		"-File",
		script_path,
		"-CmdPath",
		cmd_path,
	])
	_pid = OS.create_process("powershell.exe", args)
	print("%s web host pid=%d url=%s" % [GameData.MOVIE_LOG_PREFIX, _pid, _url])
	if _pid <= 0:
		_fail()


func update_placement(parent_hwnd: int, rect: Rect2i, volume: float, mute: bool) -> void:
	if not _active:
		return
	_write_cmd(parent_hwnd, rect, volume, mute, false)
	_poll_status()


func set_audio(volume: float, mute: bool) -> void:
	if not _active:
		return
	_patch_cmd_audio(volume, mute)


func stop() -> void:
	if _active:
		_write_close()
	if _pid > 0:
		if OS.get_name() == "Windows":
			OS.create_process("taskkill.exe", PackedStringArray([
				"/PID", str(_pid), "/T", "/F",
			]))
		else:
			OS.kill(_pid)
	_pid = -1
	_active = false
	_ready = false
	_url = ""
	_last_cmd = ""
	_session += 1
	_remove_file(GameData.MOVIE_WEB_CMD_PATH)
	_remove_file(GameData.MOVIE_WEB_STATUS_PATH)


func poll_status() -> void:
	if _active:
		_poll_status()


func _poll_status() -> void:
	if not FileAccess.file_exists(GameData.MOVIE_WEB_STATUS_PATH):
		return
	var file: FileAccess = FileAccess.open(GameData.MOVIE_WEB_STATUS_PATH, FileAccess.READ)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return
	var data: Dictionary = parsed
	if int(data.get("session", 0)) != _session:
		return
	var state: String = String(data.get("state", ""))
	if state == "ready" and not _ready:
		_ready = true
		print("%s web embed ready" % GameData.MOVIE_LOG_PREFIX)
		embedding_ready.emit()
	elif state == "failed" and _active:
		_fail()


func _fail() -> void:
	if not _active:
		return
	_active = false
	_ready = false
	embedding_failed.emit()


func _write_cmd(parent_hwnd: int, rect: Rect2i, volume: float, mute: bool, close: bool) -> void:
	var payload: Dictionary = {
		"url": _url,
		"parent": str(parent_hwnd),
		"x": rect.position.x,
		"y": rect.position.y,
		"w": maxi(rect.size.x, 64),
		"h": maxi(rect.size.y, 64),
		"volume": volume,
		"mute": mute,
		"close": close,
		"session": _session,
	}
	var encoded: String = JSON.stringify(payload)
	if encoded == _last_cmd:
		return
	_last_cmd = encoded
	var file: FileAccess = FileAccess.open(GameData.MOVIE_WEB_CMD_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(encoded)
	file.close()


func _patch_cmd_audio(volume: float, mute: bool) -> void:
	if not FileAccess.file_exists(GameData.MOVIE_WEB_CMD_PATH):
		return
	var file: FileAccess = FileAccess.open(GameData.MOVIE_WEB_CMD_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return
	var data: Dictionary = parsed
	data["volume"] = volume
	data["mute"] = mute
	_last_cmd = ""
	var parent_hwnd: int = int(str(data.get("parent", "0")))
	var rect: Rect2i = Rect2i(
		int(data.get("x", 0)),
		int(data.get("y", 0)),
		int(data.get("w", 64)),
		int(data.get("h", 64))
	)
	_write_cmd(parent_hwnd, rect, volume, mute, false)


func _write_close() -> void:
	var payload: Dictionary = {"close": true, "url": _url}
	var file: FileAccess = FileAccess.open(GameData.MOVIE_WEB_CMD_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload))
	file.close()


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _copy_host_script() -> String:
	var dest: String = GameData.MOVIE_WEB_HOST_USER
	if FileAccess.file_exists(GameData.MOVIE_WEB_SCRIPT):
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(GameData.MOVIE_WEB_SCRIPT)
		if not bytes.is_empty():
			var out: FileAccess = FileAccess.open(dest, FileAccess.WRITE)
			if out != null:
				out.store_buffer(bytes)
				out.close()
	if not FileAccess.file_exists(dest):
		return ""
	return ProjectSettings.globalize_path(dest)
