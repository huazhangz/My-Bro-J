extends HTTPRequest

## 从 Internet Archive 抓取白名单内的免费非限制级 Theora 影片。
## 仅使用 GameData.MOVIE_CATALOG，不搜成人/限制级片源。

signal movie_ready(path: String, title: String)
signal movie_failed(reason: String)

var _queue: Array = []
var _current: Dictionary = {}
var _busy: bool = false


func _ready() -> void:
	timeout = GameData.MOVIE_REQUEST_TIMEOUT
	use_threads = true
	request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		_on_completed(result, code, body)
	)


func is_busy() -> bool:
	return _busy


func fetch_random() -> void:
	if _busy:
		return
	_queue = GameData.shuffled_movie_catalog()
	_try_next()


func cancel_fetch() -> void:
	if _busy:
		cancel_request()
	_busy = false
	_queue.clear()
	_current = {}
	download_file = ""


func _try_next() -> void:
	if _queue.is_empty():
		_busy = false
		download_file = ""
		movie_failed.emit("empty_catalog")
		return
	_current = _queue.pop_front()
	var movie_id: String = String(_current.get("id", ""))
	var title: String = String(_current.get("title", movie_id))
	if GameData.movie_is_cached(movie_id):
		_busy = false
		movie_ready.emit(GameData.movie_cache_path(movie_id), title)
		return
	var archive_id: String = String(_current.get("archive_id", ""))
	var file_name: String = String(_current.get("file", ""))
	if archive_id.is_empty() or file_name.is_empty():
		_try_next()
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GameData.MOVIE_CACHE_DIR))
	var dest: String = GameData.movie_cache_path(movie_id)
	download_file = dest
	_busy = true
	var url: String = GameData.archive_download_url(archive_id, file_name)
	var headers: PackedStringArray = PackedStringArray([
		"User-Agent: SteveDesktopPet/1.0",
		"Accept: */*",
	])
	var err: Error = request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		_cleanup_partial(dest)
		call_deferred("_try_next")


func _on_completed(result: int, code: int, _body: PackedByteArray) -> void:
	var dest: String = GameData.movie_cache_path(String(_current.get("id", "")))
	var title: String = String(_current.get("title", ""))
	download_file = ""
	if result != RESULT_SUCCESS or code < 200 or code >= 300:
		_cleanup_partial(dest)
		call_deferred("_try_next")
		return
	if not GameData.movie_is_cached(String(_current.get("id", ""))):
		_cleanup_partial(dest)
		call_deferred("_try_next")
		return
	_busy = false
	_queue.clear()
	movie_ready.emit(dest, title)


func _cleanup_partial(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
