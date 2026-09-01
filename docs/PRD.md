# Steve 桌宠小游戏 · 产品需求文档 (PRD)

> Steam Project · 单机基础版
> 引擎：Godot Engine **4.7.2 stable** · 语言：GDScript (Godot 4.x)
> 最后更新：2026-09-01

---

## 一、项目定位

2D Idle / 放置类**桌面悬浮窗**小游戏（桌宠）。窗口透明、无边框、可置顶，
常驻桌面，左键拖拽。玩家挂机看 Steve 自动洗内裤，收集品质 / 磨损 / 50 款贴图。

- 渲染：`gl_compatibility`
- 窗口：**300 × 420**（立绘 ×1.2，默认再右移 5 格）
- 主场景：`res://scenes/steve.tscn`（根节点 `Control`，背景全透明）
- 常量全部在 Autoload `GameData`

---

## 二、功能清单

| # | 功能 | 状态 |
|---|------|------|
| 1 | 洗涤循环 3 分钟 / 条 | ✅ |
| 2 | 烘干基础 5 分钟 + 品质增量 | ✅ |
| 3 | 未晾干仓库上限 10 | ✅ |
| 4 | 六档品质 + 八档磨损 + 50 款内裤贴图 | ✅ |
| 5 | 烘干机 / 抽屉库存（4 列，品质底色，标题 xx条内裤） | ✅ |
| 6 | 压力催洗 + 15.5% 跑路 + 冷却读秒 | ✅ |
| 7 | 跑路空盆 `container.jpg` 抠绿 + 「已跑路...」 | ✅ |
| 8 | 右键 4 倍菜单；聊聊天及下方按钮均带 Emoji | ✅ |
| 9 | 聊聊天（白字黑边，发/回自动滚底）+ 运势选择器 | ✅ |
| 10 | 看电影：Kepler Theora；网址框双模式（.ogv 原生平 / 网页内嵌浏览器） | ✅ |
| 11 | 动态立绘 Theora + 色度键；失败回落 Steve2 | ✅ |
| 12 | `user://save_data.json` | ✅ 已接 |
| 13 | 付费加速 / 图鉴换装 UI | ⬜ 已禁用 |
| 14 | 打赏 | ✅ 菜单「💝 打赏」；HTTPS 自有后端扫码；无后端则明示缺商户资料 |
| 15 | 离线烘干补算、Windows 导出包 | ⬜ |

---

## 三、数值（`GameData`）

### 3.1 时间与容量

| 常量 | 值 |
|------|-----|
| `WASH_DURATION` | 180 s |
| `DRY_DURATION_BASE` | 300 s |
| `DRY_DURATION_PER_QUALITY` | 100/3 s |
| `WAREHOUSE_CAPACITY` | 10 |
| `RUNAWAY_BASE_COOLDOWN` | 120 s |
| `PRESSURE_RUNAWAY_PERMILLE` | 155 |
| `PRESSURE_BUTTON_COOLDOWN` | 900 s |
| `HOVER_SHOW_DELAY` | 1.0 s |
| `TAP_SPEEDUP_SECONDS` | 5 s |
| `WORK_BREAK_SECONDS` | 2700 s |
| `AFFINITY_RUNAWAY_PENALTY` | 25 |
| `PET_SIZE_SCALES` | 0.70 / 1.00 / 1.35 / 2.00 |
| `GRID_COLUMNS` × `GRID_VISIBLE_ROWS` | 4 × 4 |
| `ITEM_CARD_SIZE` | 165 × 136 |
| `ITEM_CARD_SWATCH_H` | 63（贴图相对旧 42 ×1.5） |
| `OVERLAY_CHROME_COLOR` | `(0.06, 0.07, 0.11, 0.88)` |
| `UI_FONT_SIZE` / `MENU_UI_FONT_SIZE` | 16 / 19 |
| `UI_FONT_COLOR` | 纯白 |
| `UI_FONT_OUTLINE_SIZE` | 4 |
| `UI_FONT_OUTLINE_COLOR` | 黑 |
| `DRYER_BUTTON_TEXT` | `🧺 烘干机` |
| `DRAWER_BUTTON_TEXT` | `🗄️ 抽屉` |
| `PRESSURE_BUTTON_TEXT` | `💦 能不能给我洗快点` |
| `CHAT_BUTTON_TEXT` | `💬 聊聊天` |
| `FORTUNE_BUTTON_TEXT` | `🔮 哥来帮你算算运势~` |
| `MOVIE_BUTTON_TEXT` | `🎬 哥请你看个电影吧` |
| `TIP_BUTTON_TEXT` | `💝 打赏` |
| `SETTINGS_BUTTON_TEXT` | `⚙️ 设置` |
| `QUIT_BUTTON_TEXT` | `🚪 晚点再洗` |
| `MOVIE_SKIP_TEXT` | `这部好无聊呀哥哥~` |
| `MOVIE_URL_HINT` | 粘贴想看的电影链接（网页或 .ogv 直链都可以） |
| `MOVIE_WEB_OPEN_TEXT` | 用系统浏览器打开 |
| `MOVIE_WEB_TIMEOUT_SECONDS` | 10 |
| `MOVIE_PLAY_AFTER_BYTES` | 2 500 000 |
| `MOVIE_STALL_SECONDS` | 18 |
| `DRY_QUALITY_DOWN_PERMILLE` | 150（烘干 15% 降一级） |
| `DRYER_HINT_TEXT` | 烘干机可能会把内裤烤坏的… |
| `UNDERWEAR_ART_COUNT` | 50 |
| `UNDERWEAR_SHEET_COLUMNS/ROWS` | 5 × 5 |
| `UNDERWEAR_SHEET_X` | 0 / 290 / 610 / 925 / 1225 / 1536 |
| `UNDERWEAR_SHEET_Y` | 0 / 190 / 380 / 565 / 760 / 975 |
| `UNDERWEAR_SHEET_INSET_BOTTOM` | 30（参考像素；只收底边，避免裁进下一行顶边） |
| `UNDERWEAR_CROP_VERSION` | 30（本机 `user://underwear` 世代对不上则清掉） |
| `MOVIE_WEB_ASPECT` | 16 / 9（网页/影片视口强制比例） |
| `MOVIE_PET_SCALE` | 0.52（电影舞台内 Steve 相对体型缩放） |
| `UNDERWEAR_KEY_DIST` / `GREEN` | 0.045 / 0.085（仅内裤 flood-fill） |
| `TIP_AMOUNT_FEN` | 660 / 1660 / 6660（展示 6.6 / 16.6 / 66.6） |

已删除：`dryer.jpg` / `drawer.jpg` / `drawer1.jpg` 及对应 `USER_DRYER_*`、`DRYER_ICON_*`、`DRYER_BG_ZOOM`。

### 3.2 品质

| 品质 | 掉率权重 | CD 缩减 |
|------|---------|--------|
| 一次性 | 36 | 0.00 |
| 涤纶 | 24 | 0.10 |
| 纯棉 | 18 | 0.20 |
| 真丝 | 12 | 0.30 |
| 奢华 | 7 | 0.45 |
| 火星科技 | 3 | 0.60 |

磨损前缀按 `wear_roll ∈ [0,100]` 每 12.5 一档：古神穿过的 / 香甜的 / 美味的 / 瑕疵的 / 二手的 / 破洞的 / 开裂的 / 臭的。

展示名格式：`{磨损} {品质} 内裤`，例如「瑕疵的 涤纶 内裤」。

库存格子底板按品质：一次性灰 / 涤纶绿 / 纯棉蓝 / 真丝紫 / 奢华金 / 火星科技红。

烘干完成时 15% 品质降一级（不低于一次性）。烘干机标题旁圆形「?」：无边框透明窗不用引擎 tooltip，改为每帧用 `DisplayServer.mouse_get_position()` 判断是否落在按钮矩形内，再显示自建气泡。

洗出一条时 `art_index = randi_range(0, 49)`，贴图为对应切图。旧存档缺字段时用 `id` 映射到 0–49。

### 3.3 内裤贴图

- 本机 `bx1.png`、`bx2.png`（各 25 格，5×5）优先放 `assets/images/`（用户路径 `C:\Users\ASUS\My-Bro-J\assets\images\`）。
- 切格按绝对像素表，参考分辨率 1536×975：列 0–290 / 290–610 / 610–925 / 925–1225 / 1225–1536；行 0–190 / 190–380 / 380–565 / 565–760 / 760–975。实际表按宽高缩放。左右用 X 表不改。每格底边再内收 `UNDERWEAR_SHEET_INSET_BOTTOM`（30，末行除外），避免裁进下一行内裤的顶边。仓库切图已同步为该默认；旧本地 `user://` 切图按世代清掉。
- 抠底只从边角 flood-fill（`UNDERWEAR_KEY_DIST=0.045`），**不**套用 Steve 立绘全局色度键。
- 写入 `user://underwear/`，能写仓库时同时覆盖 `res://assets/images/underwear/%02d.png`。
- 仓库已提交 50 张切图；本机表优先覆盖。原表与切图分开放。
- 切片脚本：`tools/slice_boxers.py`。说明见 `assets/images/underwear/README.md`。

---

## 四、窗口与输入

- 只允许 `DisplayServer` 移动/置顶主窗口。内嵌运行时跳过，避免 `Embedded windows can't be moved`。
- 拖拽：全局鼠标位置 − 按下时窗口内偏移。
- 装饰节点 `mouse_filter = IGNORE`。根 `Control` 不得铺不透明全屏底。
- 信号一律 `node.signal.connect(func(): ...)`。

---

## 五、UI

全局主题 `steve_theme.tres`：YuanRou-P-Bold，**白字 + 黑色描边 4px**。
`steve.gd` 的 `_apply_ui_font()` / `_unify_control_text()` 再覆盖 Label、Button、LineEdit。
聊聊天气泡不再用深色字；底板改为深色 WhatsApp 风，保证白字可读。用户发送或 Steve 回复后滚动条等到布局完成再滚到最底。

### 右键菜单 `ExitPopup`

- 统计气泡：好感 / 洗了 xx 条 / 陪伴 / 跑路
- `🧺 烘干机`、`🗄️ 抽屉`（Emoji 在文字前，无 TextureRect）
- `💦 能不能给我洗快点` / `💬 聊聊天` / `🔮 哥来帮你算算运势~` / `🎬 哥请你看个电影吧` / `💝 打赏`
- `⚙️ 设置`：置顶、体型；`🚪 晚点再洗` 存档退出；`×` 关闭
- **关闭菜单时**若电影窗未打开，则 `cancel_fetch()`，不在后台继续下片

### 库存 `InventoryPopup`

- 无任何背景贴图，仅 `OVERLAY_CHROME_COLOR` 底板
- 标题色条：烘干机紫 / 抽屉金；标题实时为「xx条内裤」
- 烘干机标题旁「?」：自建气泡，不用引擎 tooltip（透明置顶窗会吞掉默认 tooltip）
- 4 列卡片（贴图高 63 = 旧 42×1.5），格子随贴图放大，列间距避免重叠
- 卡片底色随品质：灰 / 绿 / 蓝 / 紫 / 金 / 红
- 品质词后写「内裤」；图为 50 款内裤切图 + 磨损
- 「收拾一下」绿色 EquipButton；删除不减生涯计数
- 滚动条隐藏，滚轮仍可滚

### 聊聊天 / 运势 / 电影

- 聊聊天：7 天历史；OpenAI 兼容；`CHAT_SYSTEM_PROMPT` 孙哥口吻；发/回自动滚底
- 运势：强制公历年/月/日/时辰，禁止口头改期
- 电影：点「哥请你看个电影吧」直接加载内置 Kepler Supernova Simulation（Archive Theora）。关菜单未开播则取消。顶栏「这部好无聊呀哥哥~」为粉色，点击展开网址输入框（不再随机换片）。弹窗 chrome（顶栏、拖边、关闭、粉按钮、音量/静音）保持不变。
  - **直链模式**：`.ogv` / `.ogg` 走 `VideoStreamPlayer`（Theora）。
  - **网页模式**：爱一帆 / iyf.tv 及其它站点链接切到内嵌 Edge/Chrome（Windows `SetParent`）。影片落在 `AspectRatioContainer` **16:9** 视口里，HWND 只覆盖该视口，不再拉扁。10 秒内嵌失败则显示「用系统浏览器打开」（`OS.shell_open`）。非 Windows 直接走该回退。
  - 看电影时 Steve 放在 16:9 视口下方的宿主条里（不叠黑底/网页 HWND），条内可拖；右键不开菜单。抠像只用 `PetFrame`，隐藏不透明 `VideoStreamPlayer`，避免黑方块。关闭电影后立绘回到根节点。
- 头顶气泡：按文案尺寸布局并挂 YuanRou；空摘录不显示，避免灰框无字。

### 打赏

- 菜单「💝 打赏」打开扫码窗：支付宝 / 微信 + 三档金额。
- 客户端只 `POST/GET` 自有 HTTPS 后端（`STEVE_TIP_API_URL`）。商户密钥不得进桌宠。
- 付款成功只致谢，**不加币**。未接后端时展示缺资料说明。详见 `docs/PAYMENT.md`。
- 「约个饭」已删除。

### 立绘

- `PetVideo` + `PetFrame` 色度键；场景不挂占位 `steve.ogv`，避免 Unicode NUL
- 跑路：空盆 + 横幅；冷却结束回来
- 悬停 1s 水条；双击加速水蓝 flash；45 分钟休息提醒
- 头顶气泡仅 Steve 独在且无菜单时出现

---

## 六、文件结构

```
My-Bro-J/
├── project.godot
├── README.md
├── .cursorrules
├── .gitignore
├── convert_video.bat
├── scenes/steve.tscn
├── scripts/steve.gd
├── scripts/GameData.gd
├── scripts/underwear_art.gd
├── scripts/chat_client.gd
├── scripts/movie_client.gd
├── scripts/tip_client.gd
├── scripts/web_movie_embed.gd
├── assets/images/container.jpg
├── assets/images/steve2.jpg
├── assets/images/underwear/01.png … 50.png
├── assets/images/underwear/README.md
├── assets/images/underwear/sheets/README.md
├── assets/fonts/YuanRou-P-Bold.ttf
├── assets/fonts/steve_theme.tres
├── assets/shaders/chroma_key.gdshader
├── assets/videos/README.md
├── tools/slice_boxers.py
├── tools/web_movie_host.ps1
└── docs/
    ├── PRD.md
    └── PAYMENT.md
```

场景树（摘要）：

```
Steve (Control, theme = steve_theme)
├── PetVisual → PetVideo / PetFrame / BasinFrame / PlaceholderVisual
├── ExitPopup → 统计气泡 + Emoji 按钮 + 功能按钮 + 设置
├── RunawayBanner
├── InventoryPopup → InventoryChrome（无贴图底）+ Grid 4 列 + DryerHintButton
├── ChatPopup / FortunePopup / MoviePopup / TipPopup
```

色度键只挂 `PetFrame` 与跑路空盆，不再挂库存背景或菜单图标。

---

## 七、操作

| 操作 | 效果 |
|------|------|
| 左键拖 | 移窗 |
| 立绘悬停 1s | 洗涤水条 |
| 立绘右键 | 菜单 |
| 🧺 烘干机 / 🗄️ 抽屉 | 库存；标题 xx条内裤；烘干机「?」自建气泡 |
| 🎬 哥请你看个电影吧 | 直接加载 Kepler；顶栏粉按钮展开网址框（.ogv 或网页） |
| 💬 聊聊天 | 白字黑边会话，发/回滚到底 |
| 💝 打赏 | 扫码打赏；无后端则明示缺商户 / HTTPS 接口 |
| ESC | 先关弹层否则退出 |

---

## 八、进度

- [x] Day 1：透明窗 + DisplayServer 拖拽
- [x] Day 2：GameData + 洗涤/烘干/仓库
- [x] Day 3：中文字体、右键菜单、库存、压力催洗、跑路
- [x] 聊聊天 / 运势 / 电影 / 50 款内裤切图 / Emoji 菜单按钮
- [x] 聊聊天滚底、电影进度随加载、库存品质底色 / 1.5× 贴图、烘干 15% 降品
- [x] 内裤绝对切格（bx1/bx2）、电影 Kepler + 网址框、头顶空气泡修复、充值改 demo
- [x] 电影双模式：Theora 直链 + Windows 内嵌网页播放；10 秒回退系统浏览器
- [x] 网页强制 16:9 视口；Steve 在视口下方可拖、无黑底；独立 MoviePetWindow 已删
- [x] 内裤底边再内收至 30，仓库 01–50 重烤为默认，清掉旧 user:// 切图
- [x] 打赏扫码架构（自有 HTTPS 后端）；删除约个饭
- [x] 存档 `save_data.json`
- [ ] 离线烘干补算
- [ ] Windows 导出与打包
- [ ] 换装面板 / 大红特效（图鉴 UI 仍禁用）
- [ ] 打赏：运营方提供商户号 / 证书 / 公网 notify 后才能真正收款

---

## 九、已知限制

1. Godot 4 只播 Ogg Theora。电影「边下边播」依赖播放器读取仍在增长的缓存文件；下完后会重开 stream 以刷新时长，下载中用字节比估算进度条上限。
2. `bx1.png` / `bx2.png` 若未放进 `assets/images/` 或本机目录，使用仓库内已提交的 50 张切图。绝对切格 + 边角 flood-fill，不改 Steve 全局抠像。
3. 70KB 级 `steve.ogv` 占位片一律拒绝。需要本机 `steve3.mp4` + FFmpeg。
4. 看电影内置只留 Kepler。`.ogv` 直链走 `VideoStreamPlayer`。网页站落在 16:9 `AspectRatioContainer` 视口内嵌；Windows 失败则「用系统浏览器打开」。Steve 在视口下方宿主条可拖，右键不开菜单。
5. 内裤切格左右用 `UNDERWEAR_SHEET_X`；底边内收 30 参考像素，避免（列,行）裁进下一行顶边。仓库 `01–50.png` 已按该切格重烤为默认。本机有 bx1/bx2 时 F5 会重切；旧 `user://underwear` 按 `UNDERWEAR_CROP_VERSION` 丢弃。
6. 聊聊天 / 运势无 `STEVE_CHAT_API_URL` 时走本地占位回复。
7. 打赏无 `STEVE_TIP_API_URL` 时不能下单。缺微信/支付宝商户资料与公网后端，见 `docs/PAYMENT.md`。
