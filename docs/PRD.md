# Steve 桌宠小游戏 · 产品需求文档 (PRD)

> Steam Project · 单机基础版
> 引擎：Godot Engine **4.7.2 stable** · 语言：GDScript (Godot 4.x)
> 最后更新：2026-08-31

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
| 8 | 右键 4 倍菜单；烘干机/抽屉用 Emoji 按钮 | ✅ |
| 9 | 聊聊天（白字黑边，发/回自动滚底）+ 运势选择器 | ✅ |
| 10 | 看电影：关菜单停下载；约 2.5MB 先播；进度条随加载伸长；「这部好无聊呀哥哥~」换片 | ✅ |
| 11 | 动态立绘 Theora + 色度键；失败回落 Steve2 | ✅ |
| 12 | `user://save_data.json` | ✅ 已接 |
| 13 | 付费加速 / 图鉴换装 UI | ⬜ 已禁用 |
| 14 | 离线烘干补算、Windows 导出包 | ⬜ |

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
| `MOVIE_BUTTON_TEXT` | `哥请你看个电影吧` |
| `MOVIE_SKIP_TEXT` | `这部好无聊呀哥哥~` |
| `MOVIE_PLAY_AFTER_BYTES` | 2 500 000 |
| `MOVIE_STALL_SECONDS` | 18 |
| `DRY_QUALITY_DOWN_PERMILLE` | 150（烘干 15% 降一级） |
| `DRYER_HINT_TEXT` | 烘干机可能会把内裤烤坏的… |
| `UNDERWEAR_ART_COUNT` | 50 |
| `UNDERWEAR_SHEET_COLUMNS/ROWS` | 5 × 5 |

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

烘干完成时 15% 品质降一级（不低于一次性）。烘干机标题旁圆形「?」，悬停显示 `DRYER_HINT_TEXT`。

洗出一条时 `art_index = randi_range(0, 49)`，贴图为对应切图。旧存档缺字段时用 `id` 映射到 0–49。

### 3.3 内裤贴图

- 本机 `boxers.png`、`boxers1.png`（各 25 格，5×5）：切格先内缩（左右 1/12、上 1/16、下 1/8），再从边角 flood-fill 抠底。不套用 Steve 立绘全局色度键。
- 写入 `user://underwear/`，能写仓库时同时覆盖 `res://assets/images/underwear/%02d.png`。
- 仓库已提交 50 张切图；本机表优先覆盖。
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
- `能不能给我洗快点` / `聊聊天` / `哥来帮你算算运势~` / `哥请你看个电影吧` / `约个饭` / `充值`
- 设置：置顶、体型；`晚点再洗` 存档退出；`×` 关闭
- **关闭菜单时**若电影窗未打开，则 `cancel_fetch()`，不在后台继续下片

### 库存 `InventoryPopup`

- 无任何背景贴图，仅 `OVERLAY_CHROME_COLOR` 底板
- 标题色条：烘干机紫 / 抽屉金；标题实时为「xx条内裤」
- 烘干机标题旁圆形「?」悬停说明烘干可能降品
- 4 列卡片（贴图高 63 = 旧 42×1.5），格子随贴图放大，列间距避免重叠
- 卡片底色随品质：灰 / 绿 / 蓝 / 紫 / 金 / 红
- 品质词后写「内裤」；图为 50 款内裤切图 + 磨损
- 「收拾一下」绿色 EquipButton；删除不减生涯计数
- 滚动条隐藏，滚轮仍可滚

### 聊聊天 / 运势 / 电影

- 聊聊天：7 天历史；OpenAI 兼容；`CHAT_SYSTEM_PROMPT` 孙哥口吻；发/回自动滚底
- 运势：强制公历年/月/日/时辰，禁止口头改期
- 电影：Internet Archive 白名单 Theora（2009+ 美/中可公开片）。metadata 直链；下到 `MOVIE_PLAY_AFTER_BYTES` 且文件头 `OggS` 就开播，剩余继续写入同一缓存。完整下完后重开 stream，进度条按已下载字节估算总时长。关菜单未开播则取消。缓存命中秒开。顶栏「这部好无聊呀哥哥~」排除当前片再抓一部。片单仍排除院线盗链。

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
├── assets/images/container.jpg
├── assets/images/steve2.jpg
├── assets/images/underwear/01.png … 50.png
├── assets/images/underwear/README.md
├── assets/fonts/YuanRou-P-Bold.ttf
├── assets/fonts/steve_theme.tres
├── assets/shaders/chroma_key.gdshader
├── assets/videos/README.md
├── tools/slice_boxers.py
└── docs/PRD.md
```

场景树（摘要）：

```
Steve (Control, theme = steve_theme)
├── PetVisual → PetVideo / PetFrame / BasinFrame / PlaceholderVisual
├── ExitPopup → 统计气泡 + Emoji 按钮 + 功能按钮 + 设置
├── RunawayBanner
├── InventoryPopup → InventoryChrome（无贴图底）+ Grid 4 列 + DryerHintButton
├── ChatPopup / FortunePopup / MoviePopup
```

色度键只挂 `PetFrame` 与跑路空盆，不再挂库存背景或菜单图标。

---

## 七、操作

| 操作 | 效果 |
|------|------|
| 左键拖 | 移窗 |
| 立绘悬停 1s | 洗涤水条 |
| 立绘右键 | 菜单 |
| 🧺 烘干机 / 🗄️ 抽屉 | 库存；标题 xx条内裤；烘干机可悬停问号 |
| 哥请你看个电影吧 | 包场文案；关菜单停加载；顶栏可换片 |
| 聊聊天 | 白字黑边会话，发/回滚到底 |
| ESC | 先关弹层否则退出 |

---

## 八、进度

- [x] Day 1：透明窗 + DisplayServer 拖拽
- [x] Day 2：GameData + 洗涤/烘干/仓库
- [x] Day 3：中文字体、右键菜单、库存、压力催洗、跑路
- [x] 聊聊天 / 运势 / 电影 / 50 款内裤切图 / Emoji 菜单按钮
- [x] 聊聊天滚底、电影进度随加载、库存品质底色 / 1.5× 贴图、烘干 15% 降品
- [x] 存档 `save_data.json`
- [ ] 离线烘干补算
- [ ] Windows 导出与打包
- [ ] 换装面板 / 大红特效（图鉴 UI 仍禁用）

---

## 九、已知限制

1. Godot 4 只播 Ogg Theora。电影「边下边播」依赖播放器读取仍在增长的缓存文件；下完后会重开 stream 以刷新时长，下载中用字节比估算进度条上限。
2. `boxers.png` / `boxers1.png` 若未放进本机目录，使用仓库内已提交的 50 张切图。切格内缩 + 边角 flood-fill，不改 Steve 全局抠像。
3. 70KB 级 `steve.ogv` 占位片一律拒绝。需要本机 `steve3.mp4` + FFmpeg。
4. 看电影仅白名单可公开 Theora（Pioneer One 2010 US、Silent Hall of Fame 2015 US）。
5. 聊聊天 / 运势无 `STEVE_CHAT_API_URL` 时走本地占位回复。
