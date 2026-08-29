# Steve 桌宠小游戏 · 产品需求文档 (PRD)

> Steam Project · 单机基础版
> 引擎：Godot Engine **4.7.2 stable** · 语言：GDScript (Godot 4.x 语法)
> 最后更新：2026-08-29

---

## 一、项目定位

2D Idle / 放置类**桌面悬浮窗**小游戏（桌宠）。窗口透明、无边框、总在最前，
常驻桌面右下角，可用鼠标左键任意拖拽。玩家离线挂机看 Steve 自动洗内裤，
收集不同品质的内裤图鉴，用代币或"免费加速（带跑路风险）"推进循环。

- 渲染后端：`gl_compatibility`（兼容老显卡，2D 小游戏够用）
- 窗口尺寸：**250 × 350**
- 主场景：`res://scenes/steve.tscn`

---

## 二、核心业务逻辑与功能清单

| # | 功能 | 说明 | 状态 |
|---|------|------|------|
| 1 | 基础洗涤循环 | Steve 自动洗内裤，正常速度 **45 秒 / 条** | ✅ 已实现 |
| 2 | 自动晾干机制 | 洗完的内裤放置 **60 秒**后自动晾干进收藏 | ✅ 已实现 |
| 3 | 仓库存储上限 | 未晾干内裤进仓库，容量 **10**，满后暂停洗涤，有空位自动恢复 | ✅ 已实现 |
| 4 | 品质与收藏图鉴 | 普通 / 稀有 / 史诗 / 大红(传说)，大红带特效 | ✅ 数据层 + 图鉴弹层完成，特效待做 (Day 4) |
| 5 | 付费加速 | 已下线（`PAID_SPEEDUP_ENABLED = false`） | ⬜ 已禁用 |
| 6 | 免费加速与风险触发 | 有概率触发"Steve 随机跑路" | ✅ 已实现 |
| 7 | 跑路与冷却机制 | 跑路后隐藏桌宠 + 冷却倒计时，结束后自动回归 | ✅ 已实现 |
| 8 | 换装与展示 | 图鉴 / 换装 UI 已下线（`CODEX_ENABLED = false`） | ⬜ 已禁用 |
| 11 | 动态立绘 | `VideoStreamPlayer` 循环播放 Steve 视频，跑路时隐藏并暂停 | ✅ 已实现（需自备 `.ogv` 素材） |
| 9 | 品质 CD 缩减算法 | 穿戴品质越高，跑路冷却缩减越多 | ✅ 已实现 |
| 10 | 本地持久化 | `save_data.json` 存读档 | ⬜ 待做 (Day 5)，`GameData` 已预留序列化接口 |

---

## 三、数据结构与数值设定

全部常量集中在 `scripts/GameData.gd`（Autoload 单例名 `GameData`），业务脚本禁止硬编码。

### 3.1 时间与容量

| 常量 | 值 | 含义 |
|------|-----|------|
| `WASH_DURATION` | `45.0` 秒 | 洗完一条内裤的正常耗时 |
| `DRY_DURATION` | `60.0` 秒 | 洗完后自动晾干耗时 |
| `WAREHOUSE_CAPACITY` | `10` | 未晾干仓库容量上限，满即暂停洗涤 |
| `RUNAWAY_BASE_COOLDOWN` | `120.0` 秒 | 跑路冷却基础时长（未穿戴时） |
| `FREE_SPEEDUP_RUNAWAY_CHANCE` | `0.075` | 免费加速触发跑路的概率（7.5%） |
| `FREE_SPEEDUP_SECONDS` | `20.0` 秒 | 免费加速成功时扣减的洗涤时间 |
| `PAID_SPEEDUP_ENABLED` | `false` | 付费加速已下线 |
| `CODEX_ENABLED` | `false` | 图鉴 / 换装 UI 已下线 |

### 3.2 品质表 `enum Quality`

| 品质 | Enum 值 | UI 中文名 | 掉率权重 | CD 缩减系数 | 晾干代币奖励 | 主色 |
|------|---------|----------|---------|------------|------------|------|
| 普通 NORMAL | 0 | 普通 | 70 | `0.00` | 1 | 浅灰 |
| 稀有 RARE | 1 | 稀有 | 20 | `0.15` | 3 | 蓝 |
| 史诗 EPIC | 2 | 史诗 | 8 | `0.30` | 8 | 紫 |
| 大红 RED_GOLD | 3 | 大红 | 2 | `0.50` | 25 | 红（带特效） |

英文名 `QUALITY_NAMES` 只用于调试日志，UI 一律用 `QUALITY_NAMES_CN`。

掉率按权重随机（`roll_quality()`，权重总和 100，不必凑整）。

### 3.3 内裤条目结构

未晾干仓库 `wet_warehouse: Array[Dictionary]`（上限 10）与
已晾干收藏 `dry_collection: Array[Dictionary]` 中，每个条目为：

```gdscript
{
    "id": 1,                      # int，自增唯一 ID
    "quality": Quality.RARE,      # int，品质枚举
    "washed_at": 1756400000.0,    # float，洗完的 Unix 时间戳
    "dry_deadline": 1756400060.0, # float，应晾干的 Unix 时间戳（= washed_at + 60）
    "dried_at": 1756400061.0,     # float，实际晾干时间（仅已晾干条目有）
}
```

其他运行时字段：`coins: int`、`equipped_quality: int`（`-1` = 未穿戴）、
`codex_counts: Dictionary`（品质 → 累计获得数，用于图鉴）。

### 3.4 品质 CD 缩减算法

```
图鉴附加缩减 = min(已收藏条数 × 0.005, 0.10)            # 每条 +0.5%，上限 10%
总缩减比例   = clamp(品质缩减系数 + 图鉴附加缩减, 0, 0.80)  # 总上限 80%
跑路冷却     = max(基础冷却 × (1 − 总缩减比例), 10.0)      # 绝对下限 10 秒
```

对应 API：

```gdscript
GameData.get_cd_reduction(quality := 当前穿戴) -> float
GameData.get_calculated_cooldown(base_seconds := 120.0, quality := 当前穿戴) -> float
```

实测（基础 120 秒、已收藏 1 条 → 图鉴附加 0.5%）：

| 穿戴品质 | 总缩减 | 实际冷却 |
|---------|-------|---------|
| 未穿戴 | 0.5% | 119.40 s |
| 普通 | 0.5% | 119.40 s |
| 稀有 | 15.5% | 101.40 s |
| 史诗 | 30.5% | 83.40 s |
| 大红 | 50.5% | 59.40 s |

### 3.5 洗涤状态机（`steve.gd`）

```
        ┌──────────────► WASHING ◄──────────────┐
        │              (45s 倒计时)              │
        │                  │                    │
仓库出现空位          洗完一条 → 进仓库          冷却结束
        │            + 启动 60s 晾干 Timer       │
        │                  │                    │
        │            仓库满 10 条                │
        │                  ▼                    │
        └────────────  PAUSED_FULL          RUNAWAY
                                          (隐藏 + CD 倒计时)
                                               ▲
                                    免费加速 7.5% 概率触发
```

- 每条内裤持有**独立的 60 秒 one-shot `Timer` 节点**（`_dry_timers: item_id → Timer`），
  超时后调用 `GameData.dry_item(id)`，节点自动 `queue_free()`。
- `GameData.warehouse_changed` 信号触发 `_try_resume_wash()`，实现"有空位自动恢复洗涤"。
- 跑路期间调用 `_set_pet_hidden(true)`：隐藏全部可见节点 + 开启
  `WINDOW_FLAG_MOUSE_PASSTHROUGH`（整窗鼠标穿透），视觉与交互上等于窗口消失，
  不用 `minimize` 以免抢占任务栏焦点。

---

## 四、窗口与拖拽实现要点（Day 1）

`project.godot` 中已自动写好，**无需在编辑器里手动勾选**：

```ini
[display]
window/size/viewport_width=250
window/size/viewport_height=350
window/size/borderless=true
window/size/transparent=true
window/size/always_on_top=true
window/per_pixel_transparency/allowed=true
```

运行时 `steve.gd::_apply_window_setup()` 再次以 `DisplayServer` 兜底设置
`WINDOW_FLAG_TRANSPARENT / BORDERLESS / ALWAYS_ON_TOP`，并设 `get_window().transparent_bg = true`，
最后把窗口摆到屏幕右下角。

**拖拽算法**（彻底避免抖动与 `Embedded windows can't be moved`）：

```gdscript
# 按下：记录鼠标相对窗口左上角的偏移
_drag_offset = DisplayServer.mouse_get_position() - DisplayServer.window_get_position()
# 每帧：全局鼠标位置 − 偏移，再 clamp 进屏幕可用区
DisplayServer.window_set_position(clamp_to_screen(DisplayServer.mouse_get_position() - _drag_offset))
```

- 全程只用 `DisplayServer`，**不碰 `Window.position`**。
- 用全局鼠标坐标而非 `event.relative` 累加，避免窗口移动反过来影响局部坐标。
- 松手事件在全局 `_input()` 里收（鼠标可能已经拖到窗口外）。
- `_is_embedded_in_editor()` 检测命令行 `--wid` 参数；若编辑器内嵌运行游戏窗口，
  会 `push_warning` 提示关闭内嵌。项目已通过 `.godot/editor/project_metadata.cfg`
  设置 `game_view/embed_on_play=false` 默认关闭内嵌。

---

## 五、中文字体与悬浮 UI（Day 3）

### 5.1 字体方案

引擎内置默认字体不含 CJK 字形，中文会渲染成方块。解决方案：

| 项 | 内容 |
|----|------|
| 字体 | `assets/fonts/GlowSansSC-Regular-Subset.otf`（Glow Sans SC / 未来荧黑（圆体），OFL 1.1） |
| 处理 | 按 **GB2312 全字符集 + ASCII + 常用标点**子集化：完整 OTF ~9 MB → **约 2.0 MB** |
| 主题 | `assets/fonts/steve_theme.tres`，`default_font` 指向该字体 |
| 挂载 | `project.godot` → `gui/theme/custom`（覆盖 Tooltip 等引擎内建 UI）+ `steve.tscn` 根节点 `theme` |

因此**新增任何 Label / Button 都自动是中文字体**，不需要逐节点 `theme_override_fonts/font`。
主题内还定义了一组类型变体（`TitleLabel` / `SmallLabel` / `CoinLabel` / `FloatLabel` /
`SolidPanel` / `ChipPanel` / `RiskButton` / `CoinButton` / `CodexButton` / `EquipButton` /
`CloseButton`），差异化配色靠 `theme_type_variation` 取用，不散写 StyleBox。
字体来源、许可与子集重生成脚本见 `assets/fonts/README.md`。

### 5.2 UI 结构

默认**不显示任何 HUD / CanvasLayer**。画面只有 `PetVisual`（视频或几何占位）。

- **ExitPopup**（根节点下，默认隐藏）：在立绘上 **右键** 弹出居中确认框
  - `Quit App`：退出进程
  - `Cancel` / 点弹窗外 / `ESC`：关闭
- 左键拖拽仍走根 `Control` + `DisplayServer`，与右键互不抢事件
- 洗涤 / 仓库 / 跑路在后台继续跑，不再有状态文字、进度条、图鉴或加速按钮

### 5.3 信号 → UI 绑定

倒计时类文本每帧刷新，其余全部由 `GameData` 信号驱动（闭包 `Callable` 连接）：

| 信号 | 刷新的 UI |
|------|----------|
| `coins_changed` | 金币 Label、付费加速按钮可用态 |
| `warehouse_changed` | `未晾干: n/10`，并触发 `_try_resume_wash()` |
| `collection_changed` | `图鉴 n`、图鉴弹层各行收藏数与 CD 文本 |
| `equipped_changed` | `已穿 xx`、立绘上的品质色补丁、图鉴行按钮态 |
| `item_washed` | 品质闪光 + 飘字「洗出【稀有】内裤」 |
| `item_dried` | 品质闪光 + 飘字「晾干【稀有】 +3 金币」 |
| 每帧 `_process` | `正在洗涤 xxs` / `Steve跑路中 CD: xxs` 与洗涤进度条 |

---

## 五之二、动态立绘（VideoStreamPlayer）

### 关键约束：Godot 4 只能播 Ogg Theora

`VideoStream` 在 Godot 4 里**只有 `VideoStreamTheora` 一个子类**，
`ResourceLoader.get_recognized_extensions_for_type("VideoStream")` 返回
`["ogv", "tres", "res"]`。**`.mp4` / `.webm` 拖进项目不会被识别**，
必须先用 FFmpeg 转码，命令见 `assets/videos/README.md`。

### 节点与回落策略

```
PetVisual (Control, IGNORE)
├── PetVideo (VideoStreamPlayer, IGNORE)   # stream 直接挂 steve.ogv，编辑器可预览
├── PetFrame (TextureRect, IGNORE, 默认隐藏)  # 色度键：喂 get_video_texture()
├── PlaceholderVisual (Control, IGNORE, 默认隐藏)  # 仅运行时校验失败才打开
│   └── Head / EyeLeft / EyeRight / Body / Basin
└── EquippedMark (ColorRect, IGNORE)       # 换装色块，视频模式下贴到立绘底部
```

`PetVideo.stream` **在场景里直接挂** `res://assets/videos/steve.ogv`（`VideoStreamTheora`），
编辑器视口就能预览视频帧；`PlaceholderVisual` 默认 `visible = false`。
运行时 `_setup_pet_video()` 仍会校验，失败才把占位图打开。全过程无条件打印
`[Steve/Video]` 日志（不用加 `--petlog`）：

1. **找文件**：`C:/Users/ASUS/Desktop/Steve1.mp4`（存在则 FFmpeg 转 `user://steve.ogv`）
   → 否则 `FileAccess.file_exists(res://assets/videos/steve.ogv)` → 否则场景 stream
   → 否则取目录下第一个 `.ogv`。
2. **体检文件头**：Ogg 必须以 `OggS` 开头。识别 MP4/MOV（`ftyp`）、Matroska/WebM
   （`1A 45 DF A3`）、AVI（`RIFF`）、FLV，直接点名「这其实是 XX 容器，只是改了扩展名」。
3. **加载**：`ResourceLoader.load(path, "VideoStream", CACHE_MODE_REPLACE)`
   （`REPLACE` 是为了换素材后不吃旧缓存）；资源系统查不到时兜底用
   `VideoStreamTheora.new()` + `file = path` 直接读盘，绕开文件系统扫描。
4. **校验能不能真播**：见下方「坏流检测」。
5. 任何一步失败 → 显示几何占位 + 打印原因和可直接复制的 ffmpeg 命令，
   **项目照常运行不报错**。

### 坏流检测（Day 4 修复的坑）

把 `.mp4` 改名成 `.ogv` 时，`ResourceLoader.load()` **不返回 null**，
而是返回一个内部解码失败的 `VideoStreamTheora`，`play()` 后 `is_playing()` 甚至是 `true`。
只按「stream != null」判断成功，就会出现**视频没播、占位也被撤掉的空白画面**。
实测下来可靠的区分信号只有两个：

| 信号 | 好流 | 坏流 |
|------|------|------|
| `get_stream_length()` | `4.00` | `0.00` |
| `get_video_texture().get_size()` | `(640, 360)` | `(0, 0)` |
| `is_playing()` / `load()` 返回值 | 都正常 | **也都正常，不能用** |

所以采用双重校验：时长 > 0 立刻确认；否则给 `VIDEO_PROBE_FRAMES = 45` 帧宽限期等第一帧，
**确认可播之前不撤几何占位**，超时仍无画面就判定素材有问题并回落。

### 排版、拖拽与鼠标穿透

| 事项 | 处理 |
|------|------|
| 可用区域 | `VIDEO_AREA = Rect2(10, 92, 230, 240)`，HUD 以下铺满 |
| 缩放 | 第一帧解出后按视频宽高比在该区域内**居中内接**（`_fit_video_rect()`），不拉伸变形 |
| 拖拽 | `PetVideo.mouse_filter = IGNORE`，点击穿到根 `Control` 的 `_gui_input`，拖拽逻辑零改动 |
| 鼠标穿透 | 跑路时仍走原有的 `WINDOW_FLAG_MOUSE_PASSTHROUGH`，视频不参与输入 |
| 音量 | `volume_db = -80`（默认静音，桌宠常驻不吵人），要声音就调回 `0` |

### 状态联动

| 状态 | 视频 |
|------|------|
| `WASHING` / `PAUSED_FULL` | 显示 + 循环播放（`autoplay = true`、`loop = true`） |
| `RUNAWAY` 触发 | `_set_video_playing(false)`：隐藏节点 + `paused = true`，停止解码省 CPU |
| 冷却结束 | `_set_video_playing(true)`：恢复显示 + `paused = false` 原地续播 |

### 透明背景：色度键抠像

Theora **没有 Alpha 通道**，视频必然是一块不透明矩形。项目带了
`assets/videos/video_key.gdshader`，**只挂在 `PetFrame`（TextureRect）** 上。
打开 `chroma_key_enabled` 后：`PetFrame.visible = true`，
`PetFrame.texture = PetVideo.get_video_texture()`，播放器 `modulate.a = 0`。
着色器参数：

| 参数 | 默认 | 说明 |
|------|------|------|
| `chroma_key_enabled` | `true` | 默认开启绿幕抠像 |
| `chroma_key_color` / `key_color` | `#00FF00` | 绿幕；也可改白 `#FFFFFF` / 黑 `#000000` |
| `chroma_key_similarity` | `0.35` | 颜色容差（建议 0.3–0.4） |
| `chroma_key_smoothness` | `0.10` | 边缘羽化，避免锯齿 |

运行时：`set_chroma_key_enabled(bool)`、`apply_chroma_key(color, similarity, smoothness)`。
启动与开关时都会 `print_verbose` 是否正在抠背景。
素材本身带 Alpha 时，更好的做法是导出 PNG 序列帧走 `AnimatedSprite2D`，能完美保留透明。

---

## 六、文件结构

```
My-Bro-J/
├── project.godot           # 透明/无边框/置顶/250x350 + GameData Autoload
├── README.md               # 仓库说明与目录树
├── .cursorrules            # AI 编码规则（强制 Godot 4.x 语法、DisplayServer、闭包信号）
├── .gitignore              # 忽略 .godot/ 导入缓存与导出产物
├── scenes/
│   └── steve.tscn        # 主场景：根节点 Control，全屏铺满，背景全透明
├── scripts/
│   ├── steve.gd          # 窗口拖拽 + 洗涤/晾干/跑路状态机 + 中文 UI 绑定
│   └── GameData.gd         # 全局数据单例（常量、仓库、图鉴、CD 算法、存档接口）
├── assets/
│   ├── icon.svg            # 应用图标
│   ├── images/             # Steve 立绘、内裤贴图（Day 4）
│   ├── fonts/
│   │   ├── GlowSansSC-Regular-Subset.otf  # 中文字体（GB2312 子集，2.3 MB）
│   │   ├── steve_theme.tres             # 全局 UI 主题（字体 + 按钮/面板样式）
│   │   ├── OFL.txt                        # 字体许可（SIL OFL 1.1）
│   │   └── README.md                      # 字体来源与子集重生成脚本
│   └── videos/
│       ├── steve.ogv                    # 动态立绘视频（需自备，Ogg Theora）
│       ├── video_key.gdshader             # 视频抠像着色器（Theora 无 Alpha）
│       └── README.md                      # mp4 -> ogv 转换命令与抠像说明
└── docs/
    └── PRD.md              # 本文档
```

场景节点树：

```
Steve (Control, 铺满窗口, MOUSE_FILTER_STOP —— 负责接收拖拽, theme = steve_theme)
├── PetVisual (Control, IGNORE)
│   ├── PetVideo (VideoStreamPlayer)     # stream = steve.ogv，autoplay + loop + expand
│   ├── PetFrame (TextureRect)           # 色度键抠像，默认隐藏
│   ├── PlaceholderVisual (Control)      # 默认隐藏，仅校验失败才显示
│   │   └── Head / EyeLeft / EyeRight / Body / Basin (ColorRect)
│   └── EquippedMark (ColorRect)         # 换装品质色标记
├── QualityFlash (ColorRect, IGNORE)     # 出货品质闪光特效
└── UILayer (CanvasLayer)
    └── UIRoot (Control, IGNORE)
        ├── HudPanel (PanelContainer, IGNORE)
        │   └── Rows (VBox)
        │       ├── HeaderRow: TitleLabel / CoinLabel
        │       ├── StatusLabel            # 正在洗涤 32s
        │       ├── WashBar (ProgressBar)
        │       └── InfoRow: WarehouseLabel / EquippedLabel
        ├── ToastLabel (Label, IGNORE)     # 底部飘字反馈
        ├── ContextMenu (PanelContainer, 默认隐藏)
        │   └── ButtonBar: 免费加速 / 付费加速 / 图鉴 / 退出
        ├── RunawayBanner (PanelContainer) # 跑路期间唯一可见的冷却提示条
        └── CodexPanel (PanelContainer)    # 图鉴 / 换装弹层，行由脚本动态生成
```

> ✅ Day 3 已接入中文字体，UI 文本全部为中文；`CodexList` 的每一行按
> `GameData.Quality` 动态生成，加品质不用改场景。

---

## 七、当前操作方式

| 操作 | 效果 |
|------|------|
| 在桌宠/空白处按住左键拖动 | 移动桌宠窗口 |
| 在立绘上右键 | 打开上下文菜单 |
| 菜单「免费加速」 | `-15s`，25% 概率 Steve 跑路 |
| 菜单「付费加速 10币」 | 扣 10 金币立刻洗完当前这条 |
| 菜单「图鉴 / 换装」 | 打开图鉴弹层 |
| 菜单「退出」 | 退出程序 |
| 点击菜单外 | 关闭上下文菜单 |
| `ESC` | 先关菜单，再关图鉴，否则退出 |
| `空格` | 调试快捷键，等价于「免费加速」 |
| 命令行加 `-- --petlog` | 输出状态机日志 |

> 洗涤/闲置时画面上不常驻交互按钮，避免挡住立绘。

---

## 八、开发进度

- [x] **Day 1**：透明无边框窗口配置 + 桌面悬浮窗基础搭建 + 鼠标拖拽移动功能
  - [x] `project.godot` 写入 transparent / borderless / always_on_top / per_pixel_transparency
  - [x] 视口尺寸 250×350
  - [x] `steve.tscn` 根节点改为 `Control`，铺满窗口，背景完全透明
  - [x] 基于 `DisplayServer.mouse_get_position()` + `window_set_position()` 的拖拽
  - [x] 修复 "无法移动" / "embedded can't be moved"（禁用编辑器内嵌 + 运行时检测提示）
- [x] **Day 2**：核心数据单例 (`GameData.gd`) + 洗涤/晾干状态机逻辑
  - [x] 品质 Enum + CD 缩减系数 + 掉率权重
  - [x] 未晾干仓库（上限 10）+ 已晾干收藏数组 + 图鉴计数
  - [x] `get_calculated_cooldown()` CD 缩减算法
  - [x] `GameData.gd` 注册为全局 Autoload 单例
  - [x] 45 秒自动洗涤循环
  - [x] 洗完入仓库 + 每条独立 60 秒晾干 Timer
  - [x] 仓库满 10 条自动暂停，有空位自动恢复
  - [x] `trigger_free_speedup()`：概率跑路（隐藏窗口 + 进 CD）/ 成功加速
  - [x] 引擎实跑验证：45s 出货、60s 晾干、容量上限 10、CD 缩减数值全部正确
- [x] **Day 3**：桌面 UI 控件搭建（加速按钮、仓库/图鉴界面、代币显示）
  - [x] 接入中文字体：Glow Sans SC 圆体子集化到约 2.0 MB，OFL 许可随仓库提交
  - [x] `steve_theme.tres` 主题（字体 + 按钮/面板/进度条样式 + 11 个类型变体），
        挂到 `gui/theme/custom` 与场景根节点，全场景 Label / Button 默认中文
  - [x] `CanvasLayer` 悬浮 UI 层，与桌宠立绘分层，面板 `MOUSE_FILTER_IGNORE` 不吃拖拽
  - [x] 代币 Label：`金币: 37`，随 `coins_changed` 刷新
  - [x] 状态与倒计时 Label：`正在洗涤 32s` / `已暂停 - 仓库已满` / `Steve跑路中 CD: 85s`
  - [x] 仓库挂起 Label `未晾干: 3/10` + 洗涤进度条
  - [x] 悬浮 HUD / 图鉴 / 加速按钮已拆除，默认只留角色立绘
  - [x] 右键退出确认：`ExitPopup`（Quit App / Cancel）
  - [x] 引擎实跑验证：中文字形零缺失、四种状态文案、信号驱动刷新、满仓暂停与恢复
- [ ] **Day 4**：换装展示系统 + 跑路冷却与 CD 缩减算法对接
  - [x] `VideoStreamPlayer` 动态立绘：autoplay + loop、宽高比内接、鼠标穿透不影响拖拽、
        跑路隐藏并暂停 / 冷却结束续播、缺素材自动回落几何占位、抠像着色器还原透明背景
  - [ ] Steve 立绘美术资源替换 ColorRect 占位
  - [ ] 换装面板调用 `GameData.equip_quality()`
  - [ ] 大红品质特效
  - [ ] 跑路期间的冷却倒计时可视化
- [ ] **Day 5**：本地数据持久化保存 (`save_data.json`) + 整体打包测试
  - [ ] `user://save_data.json` 读写（`GameData.to_save_dict()` / `load_from_dict()` 已就绪）
  - [ ] 离线时间结算（用条目里的 `dry_deadline` 时间戳补算晾干）
  - [ ] Windows 导出预设与打包测试

---

## 九、已知限制 / 后续注意

1. 字体是 **GB2312 子集**，出现该范围外的生僻字会显示方块；按
   `assets/fonts/README.md` 的脚本把字加进 `EXTRA` 重新生成即可。
2. 动态立绘需自备 `.ogv` 素材（Godot 4 不支持 mp4 / webm）；仓库里没有素材时
   显示 `ColorRect` 几何占位。Theora 无 Alpha 通道，透明背景要靠抠像着色器。
3. 跑路时用「隐藏内容 + 整窗鼠标穿透」模拟窗口消失，未真正 `hide()` 主窗口；
   为了让玩家知道 Steve 何时回来，保留一条半透明的 `Steve跑路中 CD: xxs` 提示条。
4. 离线收益未结算：条目已存 `dry_deadline` 时间戳，Day 5 读档时按现实时间补算。
5. 拖拽已 clamp 在 `screen_get_usable_rect()` 内，多显示器场景待 Day 5 实测。
