extends RefCounted

## 充值通道骨架。下单 / 验单故意留空：客户端不得擅自加币。
## 美国走 Stripe（或后续 Steam IAP），中国大陆走微信 / 支付宝持牌聚合。

const STATUS_NOT_CONNECTED: String = "not_connected"
const STATUS_UNSUPPORTED_REGION: String = "unsupported_region"
const STATUS_UNKNOWN_SKU: String = "unknown_sku"


func supported_regions() -> PackedStringArray:
	return PackedStringArray([GameData.RECHARGE_REGION_US, GameData.RECHARGE_REGION_CN])


func sku_for(sku_id: String) -> Dictionary:
	for entry: Dictionary in GameData.RECHARGE_SKUS:
		if String(entry.get("id", "")) == sku_id:
			return entry
	return {}


func price_label(sku: Dictionary, region: String) -> String:
	if region == GameData.RECHARGE_REGION_CN:
		return "¥%s" % String(sku.get("cny", "—"))
	return "$%s" % String(sku.get("usd", "—"))


func create_order(sku_id: String, region: String) -> Dictionary:
	## 预留：向自家 HTTPS 后端要预下单参数。禁止在此写密钥或直接加币。
	if not supported_regions().has(region):
		return {
			"ok": false,
			"reason": STATUS_UNSUPPORTED_REGION,
		}
	if sku_for(sku_id).is_empty():
		return {
			"ok": false,
			"reason": STATUS_UNKNOWN_SKU,
		}
	return {
		"ok": false,
		"reason": STATUS_NOT_CONNECTED,
	}


func verify_receipt(_order_id: String, _payload: Dictionary) -> Dictionary:
	## 预留：把支付商回执交给服务端验签。客户端回执不可信。
	return {
		"ok": false,
		"reason": STATUS_NOT_CONNECTED,
	}


func grant_coins(_order_id: String, _coins: int) -> bool:
	## 预留：仅服务端验单成功后的回执可调用。当前永久关闭。
	return false
