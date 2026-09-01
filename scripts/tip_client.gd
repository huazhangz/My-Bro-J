extends HTTPRequest

## 打赏：只打 HTTPS 到自有后端。商户密钥不得进桌宠，成功也不加币。

signal tip_created(order: Dictionary)
signal tip_paid(order_id: String)
signal tip_failed(reason: String)

var _pending: bool = false
var _order_id: String = ""
var _poll_accum: float = 0.0
var _waited: float = 0.0
var _phase: String = ""


func _ready() -> void:
	timeout = GameData.TIP_REQUEST_TIMEOUT
	request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		_on_completed(result, code, body)
	)


func is_busy() -> bool:
	return _pending or not _order_id.is_empty()


func current_order_id() -> String:
	return _order_id


func cancel() -> void:
	if _pending:
		cancel_request()
	_pending = false
	_order_id = ""
	_poll_accum = 0.0
	_waited = 0.0
	_phase = ""


func create_order(channel: String, amount_fen: int) -> void:
	cancel()
	if not GameData.tip_api_ready():
		tip_failed.emit("need_backend")
		return
	var url: String = GameData.tip_create_url()
	if not GameData.tip_url_is_safe(url):
		tip_failed.emit("unsafe_url")
		return
	if amount_fen <= 0:
		tip_failed.emit("bad_amount")
		return
	var pay_channel: String = channel.strip_edges().to_lower()
	if pay_channel != GameData.TIP_CHANNEL_ALIPAY and pay_channel != GameData.TIP_CHANNEL_WECHAT:
		tip_failed.emit("bad_channel")
		return
	_phase = "create"
	_pending = true
	var err: Error = request(
		url, _headers(), HTTPClient.METHOD_POST, GameData.build_tip_create_payload(pay_channel, amount_fen)
	)
	if err != OK:
		_pending = false
		_phase = ""
		tip_failed.emit("request_error")


func poll(delta: float) -> void:
	if _order_id.is_empty() or _pending:
		return
	_waited += delta
	if _waited >= GameData.TIP_TIMEOUT_SECONDS:
		var expired_id: String = _order_id
		cancel()
		print("%s order timeout id=%s" % [GameData.TIP_LOG_PREFIX, expired_id])
		tip_failed.emit("timeout")
		return
	_poll_accum += delta
	if _poll_accum < GameData.TIP_POLL_SECONDS:
		return
	_poll_accum = 0.0
	_query_status()


func _query_status() -> void:
	if _order_id.is_empty() or _pending:
		return
	var url: String = GameData.tip_status_url(_order_id)
	if not GameData.tip_url_is_safe(url):
		cancel()
		tip_failed.emit("unsafe_url")
		return
	_phase = "status"
	_pending = true
	var err: Error = request(url, _headers(), HTTPClient.METHOD_GET)
	if err != OK:
		_pending = false
		_phase = ""
		print("%s status request error" % GameData.TIP_LOG_PREFIX)


func _headers() -> PackedStringArray:
	var headers: PackedStringArray = PackedStringArray(["Content-Type: application/json"])
	var key: String = GameData.resolved_tip_api_key()
	if not key.is_empty():
		headers.append("Authorization: Bearer %s" % key)
	return headers


func _on_completed(result: int, code: int, body: PackedByteArray) -> void:
	var phase: String = _phase
	_pending = false
	_phase = ""
	if result != RESULT_SUCCESS or code < 200 or code >= 300:
		if phase == "create":
			cancel()
			tip_failed.emit("http_%d" % code)
		return
	if phase == "create":
		var order: Dictionary = GameData.parse_tip_create(body)
		if order.is_empty():
			cancel()
			tip_failed.emit("empty_reply")
			return
		_order_id = String(order.get("order_id", ""))
		_waited = 0.0
		_poll_accum = 0.0
		print("%s order created id=%s" % [GameData.TIP_LOG_PREFIX, _order_id])
		if String(order.get("status", "")) == "paid":
			var paid_id: String = _order_id
			cancel()
			tip_paid.emit(paid_id)
			return
		tip_created.emit(order)
		return
	if phase == "status":
		var status: Dictionary = GameData.parse_tip_status(body)
		var state: String = String(status.get("status", ""))
		if state == "paid":
			var paid_id: String = _order_id
			cancel()
			tip_paid.emit(paid_id)
		elif state == "expired" or state == "failed":
			cancel()
			tip_failed.emit(state)
