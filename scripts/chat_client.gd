extends HTTPRequest

## 聊聊天外部 LLM 接入。URL / Key 未配置时走本地占位回复，不发起网络请求。
## 不打印 API Key，也不把 Key 写入存档。

signal chat_replied(text: String)
signal chat_failed(reason: String)

var _pending: bool = false


func _ready() -> void:
	timeout = GameData.CHAT_REQUEST_TIMEOUT
	request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		_on_completed(result, code, body)
	)


func is_busy() -> bool:
	return _pending


func send_history(
	history: Array[Dictionary],
	system_prompt: String = "",
	offline_reply: String = ""
) -> void:
	if _pending:
		chat_failed.emit("busy")
		return
	var url: String = GameData.resolved_chat_api_url()
	if url.is_empty():
		var fallback: String = offline_reply.strip_edges()
		if fallback.is_empty():
			fallback = GameData.CHAT_OFFLINE_REPLY
		chat_replied.emit(fallback)
		return
	if not GameData.chat_url_is_safe(url):
		chat_failed.emit("unsafe_url")
		return
	var headers: PackedStringArray = PackedStringArray(["Content-Type: application/json"])
	var key: String = GameData.resolved_chat_api_key()
	if not key.is_empty():
		headers.append("Authorization: Bearer %s" % key)
	_pending = true
	var err: Error = request(
		url, headers, HTTPClient.METHOD_POST, GameData.build_chat_payload(history, system_prompt)
	)
	if err != OK:
		_pending = false
		chat_failed.emit("request_error")


func _on_completed(result: int, code: int, body: PackedByteArray) -> void:
	_pending = false
	if result != RESULT_SUCCESS or code < 200 or code >= 300:
		chat_failed.emit("http_%d" % code)
		return
	var reply: String = GameData.parse_chat_reply(body)
	if reply.is_empty():
		chat_failed.emit("empty_reply")
		return
	chat_replied.emit(reply)
