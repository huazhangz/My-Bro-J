# 打赏支付架构与安全审查

桌宠只负责展示收款码并轮询**自有后端**。支付宝 / 微信的商户密钥、证书、回调验签全部留在服务器，不得写进 GDScript、场景或导出包。

客户端成功时只致谢，**不加代币、不改存档余额**。

---

## 已落地的客户端契约

| 项 | 约定 |
|----|------|
| 通道 | `STEVE_TIP_API_URL` 或 `user://tip_config.json` 的 `url` |
| 可选鉴权 | `STEVE_TIP_API_KEY` / `user://tip_api_key.txt` / 配置里的 `key`（这是**你们后端**的访问令牌，不是微信 APIv3 / 支付宝应用私钥） |
| 下单 | `POST {url}/create`  JSON `{channel, amount_fen, client}` |
| 查单 | `GET {url}/status?order_id=` |
| `channel` | `alipay` / `wechat` |
| 金额 | 660 / 1660 / 6660 分（展示 6.6 / 16.6 / 66.6） |
| 下单成功 | `{order_id, status, qr_png_base64?, qr_url?, code_url?, message?}` |
| 查单 | `{order_id, status}`，`pending` / `paid` / `expired` / `failed` |
| 传输 | 生产必须 HTTPS。仅 `http://127.0.0.1` / `localhost` 允许本地联调。 |

桌宠**不会**调用 `pay.weixin.qq.com`、`openapi.alipay.com` 或任何商户网关。

---

## 必须由运营方提供（当前仓库没有，无法替你开通收款）

没有下列材料时，菜单里点「生成收款码」只会显示「还没接上收款后端…」，这是刻意的安全失败，不是占位成功。

### 1. 公网 HTTPS 后端

- 可被用户设备访问的 `https://你的域名/...`
- 可被微信 / 支付宝回调的 **notify URL**（必须公网、TLS、验签）
- 谁托管（自建 / 云函数）、谁持有域名证书

### 2. 微信支付 Native（扫码）

- 已认证的微信支付商户号 `mch_id`
- 商户 API 证书序列号、`apiclient_key.pem`、平台证书
- APIv3 密钥
- 绑定的公众号 / 小程序 / 开放平台 `appid`
- Native 下单权限与结算账户

### 3. 支付宝当面付 / 预下单（扫码）

- 开放平台应用 `app_id`（已签约当面付或电脑网站支付）
- 应用私钥 + 支付宝公钥（RSA2）
- 签约商户 PID、结算账户

### 4. 主体资质

- 营业执照 / 对公账户（个人收款码**不能**当正规商户扫码接入，也没有可信异步通知）
- 软件著作权或 ICP 若平台审核要求

把以上任一项写进桌宠仓库或导出包都会构成密钥泄露。请只把它们配到服务器环境变量 / 密钥托管。

---

## 服务端必须做的事

1. 用商户证书向微信 Native / 支付宝预下单，拿到 `code_url`，在**服务器**生成二维码图，再返回给桌宠。
2. 只认支付平台的异步 notify：验签、核对 `mch_id` / `app_id`、金额、商户订单号、支付状态。
3. 查单接口只读你们库里的订单状态，**不要**把客户端「我付过了」当成功。
4. 幂等：同一 `order_id` 只入账一次。
5. 限流、金额白名单（桌宠只发那三档分）、过期关单。
6. 日志打码：禁止打印 APIv3、应用私钥、证书。
7. 若以后要给玩家发货，必须在服务端入账后再通知客户端；本桌宠当前**没有**内购币。

推荐参考官方文档，不要用个人码、不要用第三方不明聚合、不要在客户端写「支付成功就加币」。

- 微信 Native：[https://pay.weixin.qq.com/doc/v3/merchant/4012791877](https://pay.weixin.qq.com/doc/v3/merchant/4012791877)
- 支付宝预创建：[https://opendocs.alipay.com/open/02ekfg](https://opendocs.alipay.com/open/02ekfg)

---

## 明确不做 / 已拒绝的做法

| 做法 | 原因 |
|------|------|
| 商户密钥进 Godot 或 `user://` | 导出包可被反编译 |
| 客户端本地判定付款成功并 `add_coins` | 任意改内存即可刷币 |
| 个人微信/支付宝收款码当正式通道 | 无验签、无订单、违反平台经营规则 |
| HTTP 明文（非本机） | 中间人可换收款码 |
| 桌宠直连微信/支付宝网关 | 密钥必须离开用户机器 |

---

## 联调

```
set STEVE_TIP_API_URL=https://your.example/v1/tips
set STEVE_TIP_API_KEY=backend-access-token
```

或写 `user://tip_config.json`：`{"url":"https://your.example/v1/tips","key":"..."}`。

未配置时 UI 展示 `TIP_NEED_BACKEND_TEXT`，并列明缺后端与商户资料。
