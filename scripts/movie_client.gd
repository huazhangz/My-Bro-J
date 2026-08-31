extends HTTPRequest

## 从 Internet Archive 抓取白名单内的免费非限制级 Theora 影片。
## 先读 metadata 拿直链（d1/dir），避免 archive.org/download 跳转把请求挂死。
## 文件阶段写到磁盘后，先达到可播阈值就开播，剩余继续写入同一文件。
## 关闭右键菜单会 cancel_fetch()，未开播的下载立刻停掉。

signal movie_ready(path: String, title: String)
signal movie_failed(reason: String)
signal movie_progress(text: String)

const BROWSER_UA: String = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) SteveDesktopPet/1.0"

var _queue: Array = []
var _url_queue: PackedStringArray = PackedStringArray()
var _current: Dictionary = {}
var _busy: bool = false
var _phase: String = ""
var _stall: float = 0.0
var _last_bytes: int = -1
var _token: int = 0
var _early_ready: bool = false
var _cancelled: bool = false


func _ready() -> void:
	timeout = GameData.MOVIE_META_TIMEOUT
	use_threads = false
	accept_gzip = false
	max_redirects = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		_on_completed(result, code, body)
	)


func is_busy() -> bool:
	return _busy


func fetch_random() -> void:
	if _busy:
		return
	_cancelled = false
	_queue = GameData.shuffled_movie_catalog()
	print("%s start catalog=%d" % [GameData.MOVIE_LOG_PREFIX, _queue.size()])
	_try_next_movie()


func cancel_fetch() -> void:
	_cancelled = true
	_token += 1
	if _busy:
		cancel_request()
	_busy = false
	_phase = "idle"
	_early_ready = false
	_queue.clear()
	_url_queue.clear()
	_current = {}
	download_file = ""


func poll(delta: float) -> void:
	if not _busy or _phase == "idle" or _phase.is_empty():
		return
	var n: int = _progress_bytes()
	if n != _last_bytes:
		_last_bytes = n
		_stall = 0.0
	else:
		_stall += delta
		if _stall >= GameData.MOVIE_STALL_SECONDS:
			print("%s stall phase=%s bytes=%d, skip" % [GameData.MOVIE_LOG_PREFIX, _phase, n])
			if _early_ready:
				return
			movie_progress.emit(GameData.MOVIE_SWITCH_TEXT)
			_abandon_current("stall")
			return
	if _phase != "file":
		return
	_maybe_emit_early_ready(n)
	var total: int = get_body_size()
	if total > 0:
		var pct: int = clampi(int(round(100.0 * float(n) / float(total))), 0, 99)
		movie_progress.emit("%s %d%%" % [GameData.MOVIE_LOADING_TEXT, pct])
	elif n > 0:
		var mb: float = float(n) / 1048576.0
		movie_progress.emit("%s %.1fMB" % [GameData.MOVIE_LOADING_TEXT, mb])
	else:
		movie_progress.emit(GameData.MOVIE_LOADING_TEXT)


func _progress_bytes() -> int:
	var n: int = get_downloaded_bytes()
	if download_file.is_empty() or not FileAccess.file_exists(download_file):
		return n
	var file: FileAccess = FileAccess.open(download_file, FileAccess.READ)
	if file == null:
		return n
	var on_disk: int = file.get_length()
	file.close()
	return maxi(n, on_disk)


func _maybe_emit_early_ready(n: int) -> void:
	if _early_ready or _phase != "file":
		return
	var dest: String = GameData.movie_cache_path(String(_current.get("id", "")))
	if n < GameData.MOVIE_PLAY_AFTER_BYTES:
		return
	if not GameData.movie_file_is_playable(dest):
		return
	_early_ready = true
	var title: String = String(_current.get("title", ""))
	print("%s early play %s bytes=%d" % [GameData.MOVIE_LOG_PREFIX, title, n])
	movie_ready.emit(dest, title)


func _try_next_movie() -> void:
	if _cancelled:
		return
	download_file = ""
	_url_queue.clear()
	_early_ready = false
	if _queue.is_empty():
		_busy = false
		_phase = ""
		movie_failed.emit("empty_catalog")
		return
	_busy = true
	_current = _queue.pop_front()
	var movie_id: String = String(_current.get("id", ""))
	var title: String = String(_current.get("title", movie_id))
	if GameData.movie_is_cached(movie_id):
		print("%s cache hit %s" % [GameData.MOVIE_LOG_PREFIX, movie_id])
		_busy = false
		_phase = ""
		movie_ready.emit(GameData.movie_cache_path(movie_id), title)
		return
	var archive_id: String = String(_current.get("archive_id", ""))
	var direct: String = String(_current.get("direct_url", "")).strip_edges()
	if archive_id.is_empty() and direct.is_empty():
		call_deferred("_try_next_movie")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GameData.MOVIE_CACHE_DIR))
	if not direct.is_empty():
		_url_queue.append(direct)
	if archive_id.is_empty():
		call_deferred("_try_next_url")
		return
	_phase = "meta"
	_stall = 0.0
	_last_bytes = -1
	timeout = GameData.MOVIE_META_TIMEOUT
	var meta_url: String = GameData.archive_metadata_url(archive_id)
	print("%s meta %s" % [GameData.MOVIE_LOG_PREFIX, meta_url])
	movie_progress.emit(GameData.MOVIE_LOADING_TEXT)
	if not _get_url(meta_url):
		_fallback_direct_urls()
		call_deferred("_try_next_url")


func _try_next_url() -> void:
	if _cancelled:
		return
	download_file = ""
	_early_ready = false
	if _url_queue.is_empty():
		call_deferred("_try_next_movie")
		return
	var url: String = _url_queue[0]
	_url_queue.remove_at(0)
	var dest: String = GameData.movie_cache_path(String(_current.get("id", "")))
	_cleanup_partial(dest)
	download_file = dest
	_phase = "file"
	_stall = 0.0
	_last_bytes = -1
	_busy = true
	timeout = GameData.MOVIE_REQUEST_TIMEOUT
	print("%s GET %s -> %s" % [GameData.MOVIE_LOG_PREFIX, url, dest])
	movie_progress.emit(GameData.MOVIE_LOADING_TEXT)
	if not _get_url(url):
		_cleanup_partial(dest)
		call_deferred("_try_next_url")


func _get_url(url: String) -> bool:
	_token += 1
	var headers: PackedStringArray = PackedStringArray([
		"User-Agent: %s" % BROWSER_UA,
		"Accept: */*",
	])
	var err: Error = request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		print("%s request error=%d url=%s" % [GameData.MOVIE_LOG_PREFIX, err, url])
		return false
	return true


func _abandon_current(reason: String) -> void:
	if _cancelled:
		return
	var phase: String = _phase
	print("%s abandon phase=%s reason=%s" % [GameData.MOVIE_LOG_PREFIX, phase, reason])
	_token += 1
	_phase = "idle"
	cancel_request()
	download_file = ""
	var dest: String = GameData.movie_cache_path(String(_current.get("id", "")))
	if not _early_ready:
		_cleanup_partial(dest)
	_early_ready = false
	if phase == "file":
		call_deferred("_try_next_url")
	elif phase == "meta":
		_fallback_direct_urls()
		if _url_queue.is_empty():
			call_deferred("_try_next_movie")
		else:
			call_deferred("_try_next_url")
	else:
		call_deferred("_try_next_movie")


func _on_completed(result: int, code: int, body: PackedByteArray) -> void:
	if _cancelled or _phase == "idle" or _phase.is_empty():
		return
	var dest: String = GameData.movie_cache_path(String(_current.get("id", "")))
	var title: String = String(_current.get("title", ""))
	var phase: String = _phase
	download_file = ""
	if result != RESULT_SUCCESS or code < 200 or code >= 300:
		print("%s http fail phase=%s result=%d code=%d" % [GameData.MOVIE_LOG_PREFIX, phase, result, code])
		if _early_ready:
			_busy = false
			_phase = ""
			return
		_cleanup_partial(dest)
		if phase == "file":
			call_deferred("_try_next_url")
		else:
			_fallback_direct_urls()
			if _url_queue.is_empty():
				call_deferred("_try_next_movie")
			else:
				call_deferred("_try_next_url")
		return
	if phase == "meta":
		var parsed: PackedStringArray = GameData.parse_archive_download_urls(
			body,
			String(_current.get("archive_id", "")),
			String(_current.get("file", ""))
		)
		for url: String in parsed:
			if not _url_queue.has(url):
				_url_queue.append(url)
		print("%s urls=%d for %s" % [GameData.MOVIE_LOG_PREFIX, _url_queue.size(), title])
		if _url_queue.is_empty():
			_fallback_direct_urls()
		call_deferred("_try_next_url")
		return
	if not GameData.movie_file_has_ogg_header(dest):
		print("%s not theora %s" % [GameData.MOVIE_LOG_PREFIX, dest])
		if _early_ready:
			_busy = false
			_phase = ""
			return
		_cleanup_partial(dest)
		call_deferred("_try_next_url")
		return
	_busy = false
	_phase = ""
	_queue.clear()
	_url_queue.clear()
	print("%s ready %s" % [GameData.MOVIE_LOG_PREFIX, title])
	movie_ready.emit(dest, title)


func _fallback_direct_urls() -> void:
	var archive_id: String = String(_current.get("archive_id", ""))
	var file_name: String = String(_current.get("file", ""))
	if archive_id.is_empty() or file_name.is_empty():
		return
	var url: String = GameData.archive_download_url(archive_id, file_name)
	if not _url_queue.has(url):
		_url_queue.append(url)


func _cleanup_partial(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
