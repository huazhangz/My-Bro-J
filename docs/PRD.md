# Steve 桌宠小游戏 · 产品需求文档 (PRD)

> Steam Project · 单机基础版
> 引擎：Godot Engine **4.7.2 stable** · 语言：GDScript (Godot 4.x 语法)
> 最后更新：2026-08-31

---

## 一、项目定位

2D Idle / 放置类**桌面悬浮窗**小游戏（桌宠）。窗口透明、无边框、总在最前，
常驻桌面右下角，可用鼠标左键任意拖拽。玩家离线挂机看 Steve 自动洗内裤，
收集不同品质的内裤图鉴，用代币或"免费加速（带跑路风险）"推进循环。

- 渲染后端：`gl_compatibility`（兼容老显卡，2D 小游戏够用）
- 窗口尺寸：**300 × 420**（立绘图像 1.2 倍；Steve 默认再右移 5 格）
- 主场景：`res://scenes/steve.tscn`

---

## 二、核心业务逻辑与功能清单

| # | 功能 | 说明 | 状态 |
|---|------|------|------|
| 1 | 基础洗涤循环 | Steve 自动洗内裤，正常速度 **3 分钟 / 条** | ✅ 已实现 |
| 2 | 自动晾干机制 | 基础 **5 分钟**，品质每高一级 **+100/3 秒**（旧 +10s 按 300/90 等比） | ✅ 已实现 |
| 3 | 仓库存储上限 | 未晾干内裤进仓库，容量 **10**，满后暂停洗涤，有空位自动恢复 | ✅ 已实现 |
| 4 | 品质、磨损与收藏 | 一次性 / 涤纶 / 纯棉 / 真丝 / 奢华 / 火星科技 + 8 档磨损前缀 | ✅ 数据层 + 烘干机 / 抽屉网格 |
| 5 | 付费加速 | 已下线（`PAID_SPEEDUP_ENABLED = false`） | ⬜ 已禁用 |
| 6 | 能不能给我洗快点 | 右键菜单按钮：随机扣 1 秒~12 小时洗涤时间，冷却 15 分钟；15.5% 跑路（与扣时完成独立） | ✅ 已实现 |
| 7 | 跑路与空盆 | 每次压力点击 15.5% 跑路：立绘换成抠绿幕空盆 + 红色「已跑路...」 | ✅ 已实现 |
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
| `WASH_DURATION` | `180` 秒 | 洗完一条内裤的正常耗时（3 分钟） |
| `DRY_DURATION_BASE` | `300` 秒 | 烘干基础时长（5 分钟，一次性） |
| `DRY_DURATION_PER_QUALITY` | `100/3` 秒 | 品质每高一级增加的烘干时间（旧 10s × 300/90） |
| `AFFINITY_RUNAWAY_PENALTY` | `25` | 每次跑路好感度 −25，最低 0 |
| `WASH_BAR_SHIFT_Y` | `9` | 水洗进度条默认再下移 9 格 |
| `CONTEXT_MENU_SCALE` | `4.0` | 右键菜单相对旧面板边长 ×4，窗口按屏幕可用区夹紧并适配位置 |
| `MENU_ICON_SIZE` | `50×50` | 烘干机/抽屉图标为旧 168 的 30% |
| `DRYER_ICON_ZOOM` | `1.85` | 烘干机图标再中心放大 85% |
| `AFFINITY_COMPANION_FULL_SECONDS` | `449280` | 陪伴对好感度贡献拉满所需秒数（旧 48h ×260%） |
| `PET_SIZE_SCALES` | `0.70 / 1.00 / 1.35 / 2.00` | 设置里 Steve 体型：小 / 中 / 大 / 超大（只改立绘窗口，不改烘干机/抽屉弹层） |
| `PET_SIZE_HUGE_SHIFT_X` | `6` | 超大档 Steve 再向右偏 6 格（累计两次各 3 格） |
| `DRYER_ICON_NUDGE_Y` | `5` | 烘干机图标在按钮内下移 5 格（按钮位置不变） |
| `DRAWER_ICON_NUDGE_Y` | `8` | 抽屉图标在按钮内下移 8 格（按钮位置不变） |
| `HOVER_SHOW_DELAY` | `1.0` 秒 | 鼠标在立绘命中盒上停留后显示洗涤水条 |
| `WAREHOUSE_CAPACITY` | `10` | 未晾干仓库容量上限，满即暂停洗涤 |
| `RUNAWAY_BASE_COOLDOWN` | `120.0` 秒 | 跑路后回归的基础冷却（品质/收藏会再缩减） |
| `PRESSURE_WASH_REDUCTION_MIN` | `1.0` 秒 | 压力按钮随机扣时下限 |
| `PRESSURE_WASH_REDUCTION_MAX` | `43200` 秒 | 压力按钮随机扣时上限（12 小时） |
| `PRESSURE_BUTTON_COOLDOWN` | `900` 秒 | 压力按钮冷却 15 分钟；灰显并写剩余「MM：SS后再压力他」（每秒刷新） |
| `UI_FONT_SIZE` | `16` | 库存等非菜单界面字号 |
| `MENU_UI_FONT_SIZE` | `19` | 仅右键菜单字号；行距为字号 ×0.3 |
| `UI_FONT_COLOR` | 纯白 | 全部文字白色加粗（YuanRou-P-Bold） |
| `IMAGE_SCALE` | `1.2` | 立绘 / 库存图等比放大 |
| `PET_SHIFT_X` | `5` | Steve 默认再向右偏 5 格 |
| `PRESSURE_RUNAWAY_PERMILLE` | `155` | 每次点击「能不能给我洗快点」的跑路概率（155/1000，与扣时是否洗完无关） |
| `PRESSURE_BUTTON_TEXT` | `能不能给我洗快点` | 催洗按钮默认文案 |
| `PAID_SPEEDUP_ENABLED` | `false` | 付费加速已下线 |
| `CODEX_ENABLED` | `false` | 图鉴 / 换装 UI 已下线 |
| `GRID_COLUMNS` | `5` | 库存网格列数 |
| `GRID_VISIBLE_ROWS` | `6` | 库存窗刚好露出 6 行，超出才竖向滚动 |
| `ITEM_CARD_SIZE` | `110 × 96` | 卡片尺寸：5×6 铺满窗口，不裁字、不留大空白 |
| `PET_AREA` | `Rect2(10, 5, 288, 408)` | Steve 默认框：原 240×340 ×1.2，再右移 5 格 |
| `CHROMA_KEY_COLOR` | `#00FF00` | 当前扣色默认 |
| `CHROMA_KEY_SIMILARITY` | `0.81` | 当前扣色容差 |
| `CHROMA_KEY_SMOOTHNESS` | `0.15` | 当前边缘羽化 |
| `DRYER_BG_ZOOM` | `1.36` | 烘干机 / 抽屉库存背景从中心放大（裁边） |
| `OVERLAY_CHROME_COLOR` | `0.06,0.07,0.11,0.88` | 烘干机 / 抽屉 / 聊聊天 / 运势展开页底板（抠绿后不再过透） |
| `CHAT_SYSTEM_PROMPT` | 孙哥口吻 | 蒸馏 `sun-yuchen-perspective` / `sun-skill`，不上整本 SKILL |
| `CHAT_CONFIG_FILE` | `user://chat_config.json` | 可选：url / key / model；环境变量优先 |
| `CHAT_HISTORY_SECONDS` | `604800` | 聊聊天历史保留 7 天 |
| `FORTUNE_WINDOW_SIZE` | `460×640` | 运势对话框；生日只能用年/月/日/时辰选择器 |
| `MOVIE_WINDOW_SIZE` | `720×480` | 看电影小窗默认尺寸；可拖边框，下限 `420×280` |
| `MOVIE_SPEEDS` | `0.75 / 1 / 1.5 / 2` | 小窗倍速；非 1× 时静音以免音画错位 |
| `MOVIE_CATALOG` | CC/公有领域白名单 | Internet Archive Theora；不含限制级；按体积从小到大抓 |
| `MOVIE_STALL_SECONDS` | `18` | 下载字节不再增加则换片，避免一直停在「给你包场」 |
| `WHATSAPP_INCOMING_COLOR` | `#FFFFFF` | 对方气泡（Steve） |
| `WHATSAPP_OUTGOING_COLOR` | `#DCF8C6` | 自己气泡 |
| `WHATSAPP_BUBBLE_TEXT` | `#111B21` | 气泡内深色字 |
| `WHATSAPP_THREAD_BG` | `#E5DDD5` | 聊聊天会话底板 |
| `TAP_SPEEDUP_SECONDS` | `5` | 双击 Steve 扣减的洗涤秒数；冷却 1 秒且不显示 |
| `DRYER_HEADLINE_COLOR` | CodexButton 紫 | 烘干机标题条底色 |
| `DRAWER_HEADLINE_COLOR` | CoinButton 金 | 抽屉标题条底色 |
| `CHROMA_SPILL_SUPPRESSION` | `0.30` | 当前溢色抑制 |

### 3.2 品质表 `enum Quality`

| 品质 | Enum 值 | UI 中文名 | 掉率权重 | CD 缩减系数 | 晾干代币奖励 | 主色 |
|------|---------|----------|---------|------------|------------|------|
| 一次性 ONEOFF | 0 | 一次性 | 36 | `0.00` | 1 | 浅灰 |
| 涤纶 POLYESTER | 1 | 涤纶 | 24 | `0.10` | 2 | 蓝 |
| 纯棉 COTTON | 2 | 纯棉 | 18 | `0.20` | 4 | 米 |
| 真丝 SILK | 3 | 真丝 | 12 | `0.30` | 8 | 紫 |
| 奢华 LUXURY | 4 | 奢华 | 7 | `0.45` | 16 | 金 |
| 火星科技 MARTIAN | 5 | 火星科技 | 3 | `0.60` | 32 | 绿 |

英文名 `QUALITY_NAMES` 只用于调试日志，UI 一律用 `QUALITY_NAMES_CN`。

掉率按权重随机（`roll_quality()`，权重总和 100，不必凑整）。

### 3.2.1 磨损前缀 `wear_from_roll()`

创建内裤时掷 `wear_roll ∈ [0.0, 100.0]`，每 `WEAR_BUCKET = 12.5` 一档（共 8 档）：

| `wear_roll` | 前缀 |
|-------------|------|
| `0.0 – 12.5` | 古神穿过的 |
| `12.5 – 25.0` | 香甜的 |
| `25.0 – 37.5` | 美味的 |
| `37.5 – 50.0` | 瑕疵的 |
| `50.0 – 62.5` | 二手的 |
| `62.5 – 75.0` | 破洞的 |
| `75.0 – 87.5` | 开裂的 |
| `87.5 – 100.0` | 臭的 |

`display_name` = `{wear}·{品质中文名}`，例如 `古神穿过的·火星科技`。

### 3.3 内裤条目结构

未晾干仓库 `wet_warehouse: Array[Dictionary]`（上限 10）与
已晾干收藏 `dry_collection: Array[Dictionary]` 中，每个条目为：

```gdscript
{
    "id": 1,                      # int，自增唯一 ID
    "quality": Quality.MARTIAN,   # int，品质枚举
    "wear_roll": 4.2,             # float，创建时掷出的磨损值 [0, 100]
    "wear": "古神穿过的",          # String，磨损前缀
    "wear_modifier": "古神穿过的", # String，与 wear 同值
    "display_name": "古神穿过的·火星科技",
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
| 一次性 | 0.5% | 119.40 s |
| 涤纶 | 10.5% | 107.40 s |
| 纯棉 | 20.5% | 95.40 s |
| 真丝 | 30.5% | 83.40 s |
| 奢华 | 45.5% | 65.40 s |
| 火星科技 | 60.5% | 47.40 s |

### 3.5 洗涤状态机（`steve.gd`）

```
        ┌──────────────► WASHING ◄──────────────┐
        │              (180s 倒计时)             │
        │                  │                    │
仓库出现空位          洗完一条 → 进仓库          冷却结束
        │            + 启动 300s+品质 烘干 Timer │
        │                  │                    │
        │            仓库满 10 条                │
        │                  ▼                    │
        └────────────  PAUSED_FULL          RUNAWAY
                                          (空盆 + 「已跑路...」+ 回归 CD)
                                               ▲
                              「能不能给我洗快点」每次点击 15.5%（千分位掷骰，与扣时完成独立）
```

- 每条内裤持有**独立的 one-shot `Timer`**（时长 `dry_duration_for(quality)`），
  超时后调用 `GameData.dry_item(id)`，节点自动 `queue_free()`。
- `GameData.warehouse_changed` 信号触发 `_try_resume_wash()`，实现"有空位自动恢复洗涤"。
- 跑路时停播立绘视频，显示 `BasinFrame`（`container.jpg` + 当前扣色参数），
  并弹出红色半透明「已跑路...」。窗口仍可拖拽。回归 CD 结束后恢复视频并重新开洗。

---

## 四、窗口与拖拽实现要点（Day 1）

`project.godot` 中已自动写好，**无需在编辑器里手动勾选**：

```ini
[display]
window/size/viewport_width=300
window/size/viewport_height=420
window/size/borderless=true
window/size/transparent=true
window/size/always_on_top=false
window/per_pixel_transparency/allowed=true
window/subwindows/embed_subwindows=false
```

运行时 `_ready()` / `_apply_window_setup()` 立刻设 `get_tree().root.gui_embed_subwindows = false`，
再用 `DisplayServer.window_set_flag(..., true, 0)` 设置无边框 / 置顶 / 透明。
立绘层 `mouse_filter = IGNORE`，根节点 `STOP`。`_gui_input` / `_input` 共用 `_process_drag_input()`：
位置用 `DisplayServer.mouse_get_position() - _drag_offset`。内嵌时不调用置顶/移动，避免刷警告。

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
  `display/window/subwindows/embed_subwindows=false` 与运行时
  `gui_embed_subwindows = false` 强制独立 OS 窗口。

---

## 五、中文字体与悬浮 UI（Day 3）

### 5.1 字体方案

引擎内置默认字体不含 CJK 字形，中文会渲染成方块。解决方案：

| 项 | 内容 |
|----|------|
| 字体 | `assets/fonts/YuanRou-P-Bold.ttf`（源柔ゴシック P Bold / GenJyuuGothic-P-Bold，OFL 1.1） |
| 本机包 | `C:\Users\ASUS\My-Bro-J\YuanRou-P-Bold.zip`（gitignore 忽略 zip；运行时解包写入上述 TTF） |
| 主题 | `assets/fonts/steve_theme.tres`，`default_font` 指向该 TTF，全部类型变体 `font_size = 16`、`font_color` 纯白 |
| 挂载 | `project.godot` → `gui/theme/custom` + `gui/theme/custom_font` + `steve.tscn` 根节点 `theme` |

因此**新增任何 Label / Button 都自动是中文字体**，不需要逐节点 `theme_override_fonts/font`。
主题内还定义了一组类型变体（`TitleLabel` / `SmallLabel` / `CoinLabel` / `FloatLabel` /
`SolidPanel` / `ChipPanel` / `RiskButton` / `CoinButton` / `CodexButton` / `EquipButton` /
`CloseButton`），按钮底色可不同，**文字一律白色加粗、字号一律 16**。
`steve.gd` 的 `_apply_ui_font()` 会再覆盖一遍，避免变体残留旧字号/旧颜色。
右键菜单单独使用 `MENU_UI_FONT_SIZE = 19` 与 `line_spacing = 字号×0.3`。
字体来源与 OFL 许可见 `assets/fonts/README.md`。仓库内不再保留第二套默认字体。

### 5.2 UI 结构

默认**不显示任何 HUD / CanvasLayer**。画面只有 `PetVisual`（视频或几何占位）。

- **ExitPopup**（根节点下，默认隐藏）：在立绘上 **右键** 弹出 **4 倍**圆角菜单，窗口放大并按屏幕位置夹紧
  - 菜单窗口可左键拖动（点在空白/气泡上拖；点按钮不拖、不关菜单）
  - 顶部气泡：❤好感度 / 「🩲  洗了 xx 条 内裤」（生涯计数，收拾删除不减） / ⏰陪伴时长（HH：MM：SS 墙钟累计） / 🏃跑路次数（高度 +65%）
  - 其下烘干机 / 抽屉：左图标右文字的 Button（高度 +35%）；抽屉图标用 `drawer1.jpg` 抠绿；库存背景统一用 `dryer.jpg`（抽屉不再使用 drawer 底图）
  - 菜单图标相对按钮框下移：烘干机 `DRYER_ICON_NUDGE_Y=5`、抽屉 `DRAWER_ICON_NUDGE_Y=8`
  - 好感度：品质 log 高权重 + 陪伴 log（满值时间 ×260%）最多 15%；每次跑路 −25，最低 0
  - `能不能给我洗快点`：随机扣洗涤时间（1s~12h）；冷却灰显读秒
  - 功能按钮顺序：`聊聊天` → `哥来帮你算算运势~` → `看电影` → `约个饭`（粉色） → `充值`
  - `聊聊天`：对话窗 + 输入/发送（Enter）+ 7 天历史；Steve 回复后主界面弹窗；OpenAI 兼容接口；system prompt 为孙哥口吻
  - `哥来帮你算算运势~`：同风格对话框；强制年/月/日/时辰选择器（无自由文本生日）；再交给大模型
  - `看电影`：从 CC/公有领域白名单自动抓一部非限制级 Theora，小窗播放；加载时按钮文案「给你包场呢妈妈，耐心等等我」
  - Demo（占位）：`约个饭` / `充值`
  - `设置`：展开时菜单窗口加高；滚动条隐藏但仍可用滚轮；固定上层 + Steve 体型（小 / 中 / 大 / 超大）
  - `晚点再洗`：存档后退出
  - 右上角 `×`：关闭并还原窗口
  - 跑路时立绘换成按比例内接的 `container.jpg` 空盆；「已跑路...」居中贴在画面顶部，z 低于菜单
  - 点弹窗外 / `ESC` / `×`：关闭菜单
- **InventoryPopup**（全屏，默认隐藏）：烘干机用 `dryer.jpg` 中心 ×1.36；抽屉空白底；底板 `OVERLAY_CHROME_COLOR` 提高不透明度
  - 窗口按 **横 5 × 竖 6** 卡片刚好铺满计算（`inventory_window_size()`，不跟 Steve 体型）
  - 左上角标题带 headline 色条（烘干机紫 / 抽屉金，与右键按钮底色一致），高度不超过第一件库存
  - 右上角「关闭」与标题条同高；「收拾一下」为绿色 EquipButton
  - 「收拾一下」：品质从高到低；只勾一组删该组，两边都勾只删同时符合的；勾选变红；不减生涯计数
  - 背景统一 `dryer.jpg` 从中心 ×1.36 并裁边；`ScrollContainer` 隐藏滚动条，滚轮仍可滚动
- **ChatPopup**：底部输入框 + 发送；左侧 Steve、右侧「你」；历史 7 天；底板加不透明；隐藏滚动条
- **FortunePopup**：强制公历年/月/日 + 时辰选择器，禁止口头报生日；结果区只读
- **MoviePopup**：Internet Archive 白名单 Theora；拖边框缩放、最大化/关闭、音量、静音、0.75/1/1.5/2 倍速
- 立绘上 **双击** 加速洗涤 5 秒，冷却 1 秒且不显示冷却
  - `ScrollContainer` + `GridContainer`：5 列 × 6 行可见，卡片完整显示；多于 30 件才滚动
  - 卡片为紫色描边占位框，显示磨损前缀 + 品质中文名（尚无内裤贴图）
  - `关闭` / `ESC` / 再右键：还原窗口尺寸并关闭弹层
- 鼠标在立绘**收紧命中盒**上停留 **1 秒**后，头顶淡入水色进度条（默认再下移 9 格）
- 双击加速：水蓝色透明 flash 显示「加速 -5秒」
- Steve 每本地停留 45 分钟弹窗：「你又工作45分钟了哦，注意休息~」
- 库存卡片用按条目 id 烘焙的内裤贴图，不再用纯色占位
- 左键拖拽仍走根 `Control` + `DisplayServer`，与右键互不抢事件
- 洗涤 / 仓库 / 跑路在后台继续跑，不再有常驻 HUD

### 5.3 信号 → UI 绑定

常驻金币 / 状态 Label / 图鉴弹层 / 加速按钮已拆除。现存绑定：

| 信号 | 实际效果 |
|------|----------|
| `warehouse_changed` | `_try_resume_wash()`；烘干机网格打开时重填 |
| `collection_changed` | 抽屉网格打开时重填 |
| `item_washed` / `item_dried` | `--petlog` 日志 |
| 悬停 1s | 头顶水条 `洗涤进度（n/100）` |

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

1. **找文件**：`C:/Users/ASUS/My-Bro-J/steve3.mp4`（或双击根目录 `convert_video.bat` 写成 `assets/videos/steve.ogv`）。
   仓库里自带的 `steve.ogv`（约 70KB / 4 秒）是测试占位片，`<= STUB_VIDEO_MAX_BYTES` **一律拒绝播放**，
   也不会因为「占位片 mtime 比 mp4 新」而跳过转码。转码成功以**目标路径**是否写出大文件为准，
   不再误查 `user://steve.ogv`。找不到可用 ogv 时回落 `Steve2.jpg` / 几何占位，并打印 ffmpeg 命令。
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
| 可用区域 | `GameData.PET_AREA`（默认 `Rect2(10, 5, 288, 408)`）；进树时用场景 PetVideo 矩形 |
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
`assets/shaders/chroma_key.gdshader`（RGB + YCbCr 距离 + 绿色溢出抑制），
强制挂到 `PetFrame` 与 `InventoryBg`。参数请改 **Steve 根节点** 的导出项
（`chroma_key_*` / `chroma_spill_suppression`），不要改 ShaderMaterial 子资源——
运行时会用导出值覆盖材质。
打开 `chroma_key_enabled` 后：`PetFrame.visible = true`，
`PetFrame.texture = PetVideo.get_video_texture()`，播放器 `modulate.a = 0`。
库存背景同样抠绿幕，只留洗衣机画面。
着色器参数：

| 参数 | 默认 | 说明 |
|------|------|------|
| `chroma_key_enabled` | `true` | 默认开启绿幕抠像 |
| `chroma_key_color` / `key_color` | `#00FF00` | 绿幕 |
| `chroma_key_similarity` | `0.81` | 容差，越大抠得越多 |
| `chroma_key_smoothness` | `0.15` | 边缘羽化 |
| `chroma_spill_suppression` | `0.30` | 去掉人物边缘残留绿边 |

运行时：`set_chroma_key_enabled(bool)`、`apply_chroma_key(color, similarity, smoothness, spill)`。
启动与开关时都会 `print_verbose` 是否正在抠背景。
素材本身带 Alpha 时，更好的做法是导出 PNG 序列帧走 `AnimatedSprite2D`，能完美保留透明。

---

## 六、文件结构

```
My-Bro-J/
├── project.godot           # 透明/无边框/置顶/300x420 + GameData Autoload
├── README.md               # 仓库说明与目录树
├── .cursorrules            # AI 编码规则（强制 Godot 4.x 语法、DisplayServer、闭包信号）
├── .gitignore              # 忽略 .godot/ 导入缓存与导出产物
├── convert_video.bat       # steve3.mp4 → assets/videos/steve.ogv
├── scenes/
│   └── steve.tscn      # 主场景：根节点 Control，全屏铺满，背景全透明
├── scripts/
│   ├── steve.gd        # 窗口拖拽 + 洗涤/晾干/跑路状态机 + 右键菜单 / 库存网格
│   ├── chat_client.gd  # 聊聊天 / 运势 HTTP 接入（无 URL 时本地占位）
│   ├── movie_client.gd # 白名单免费电影抓取（Internet Archive Theora）
│   ├── underwear_art.gd # 按条目 id 烘焙内裤贴图
│   └── GameData.gd         # 全局数据单例（常量、仓库、磨损、CD 算法、存档接口）
├── assets/
│   ├── icon.svg            # 应用图标
│   ├── images/
│   │   ├── dryer.jpg       # 烘干机 / 抽屉库存弹层背景
│   │   ├── drawer1.jpg     # 仅菜单抽屉图标（绿幕）
│   │   ├── container.jpg   # 跑路空盆（绿幕，用当前扣色）
│   │   └── steve2.jpg      # 无可用视频时的静帧回落
│   ├── fonts/
│   │   ├── YuanRou-P-Bold.ttf             # 唯一 UI 字体（源柔 P Bold）
│   │   ├── YuanRou-OFL.txt                # SIL OFL 1.1
│   │   ├── steve_theme.tres             # 全局 UI 主题
│   │   └── README.md                      # 字体来源说明
│   ├── shaders/
│   │   └── chroma_key.gdshader          # RGB+YCbCr 绿幕 + 溢色抑制
│   └── videos/
│       ├── steve.ogv                    # 动态立绘视频（需自备，Ogg Theora）
│       └── README.md                      # mp4 -> ogv 转换命令与抠像说明
└── docs/
    └── PRD.md              # 本文档
```

场景节点树：

```
Steve (Control, 铺满窗口, theme = steve_theme)
├── PetVisual (Control, IGNORE)
│   ├── PetVideo (VideoStreamPlayer)
│   ├── PetFrame (TextureRect)
│   ├── BasinFrame (TextureRect, 跑路空盆)
│   └── PlaceholderVisual (Control)
│       └── Head / EyeLeft / EyeRight / Body / Basin
├── ExitPopup (圆角 PanelContainer, 默认隐藏, 铺满放大窗口)
│   └── MenuScroll → ExitInner
│       ├── MenuHeader（×）
│       ├── StatBubbles（好感 / 内裤 / 陪伴 / 跑路）
│       ├── MenuIcons（左图标右文字的 Button）
│       ├── 能不能给我洗快点
│       ├── 聊聊天 / 哥来帮你算算运势~ / 看电影 / 约个饭 / 充值
│       ├── 设置 / 晚点再洗
│       └── SettingsPanel（固定上层）
├── RunawayBanner（贴在空盆画面顶部正中，「已跑路...」）
├── InventoryPopup (Control, 默认隐藏, 全屏)
│   ├── InventoryChrome（加不透明底板）
│   ├── InventoryBgClip → InventoryBg（烘干机中心 ×1.36）
│   └── InventoryBody
│       ├── InventoryHeader（左标题色条 + 绿色收拾一下 + 关闭）
│       ├── InventoryScroll（隐藏滚动条）→ InventoryGrid (columns = 5)
│       └── InventoryEmpty
├── ChatPopup / FortunePopup / MoviePopup（运行时补齐运势选择器与电影小窗）
```

---

## 七、当前操作方式

| 操作 | 效果 |
|------|------|
| 在桌宠/空白处按住左键拖动 | 移动桌宠窗口 |
| 鼠标在立绘命中盒上停留 1 秒 | 头顶显示洗涤水条与 `洗涤进度（n/100）` |
| 在立绘上右键 | 打开 4 倍圆角菜单（图标打开烘干机/抽屉；气泡统计；设置里固定上层） |
| 点「烘干机」 | 2.5× 弹层，5 列网格展示未晾干仓库 |
| 点「抽屉」 | 2.5× 弹层，5 列网格展示已晾干收藏 |
| 点「聊聊天」 | 打开对话窗；口吻为孙哥人设 |
| 点「哥来帮你算算运势~」 | 打开运势窗；必须用时间选择器提交生日/时辰 |
| 点「看电影」 | 按钮改为「给你包场呢妈妈，耐心等等我」并显示进度；抓到后弹出可缩放播放小窗 |
| 仅 Steve 在场时的头顶气泡 | WhatsApp 白色来信气泡盖住洗涤水条；点气泡跳转聊天 / 运势；关窗后不残留刚看过的句子 |
| 点「固定上层」 | 开/关窗口置顶 |
| 点「晚点再洗」 | 退出程序 |
| 点「关闭」/ 弹窗外 / 库存上再右键 | 关闭对应弹层并还原窗口 |
| `ESC` | 先关电影 / 运势 / 库存 / 聊天，再关菜单，否则退出 |
| 命令行加 `-- --petlog` | 输出状态机日志 |

> 洗涤/闲置时画面上不常驻交互按钮，避免挡住立绘。

---

## 八、开发进度

- [x] **Day 1**：透明无边框窗口配置 + 桌面悬浮窗基础搭建 + 鼠标拖拽移动功能
  - [x] `project.godot` 写入 transparent / borderless / always_on_top / per_pixel_transparency
  - [x] 视口尺寸 300×420（图像 ×1.2，Steve 默认右移 5 格）
  - [x] `steve.tscn` 根节点改为 `Control`，铺满窗口，背景完全透明
  - [x] 基于 `DisplayServer.mouse_get_position()` + `window_set_position()` 的拖拽
  - [x] 修复 "无法移动" / "embedded can't be moved"（禁用编辑器内嵌 + 运行时检测提示）
- [x] **Day 2**：核心数据单例 (`GameData.gd`) + 洗涤/晾干状态机逻辑
  - [x] 品质 Enum + CD 缩减系数 + 掉率权重
  - [x] 未晾干仓库（上限 10）+ 已晾干收藏数组 + 图鉴计数
  - [x] `get_calculated_cooldown()` CD 缩减算法
  - [x] `GameData.gd` 注册为全局 Autoload 单例
  - [x] 3 分钟自动洗涤循环
  - [x] 洗完入仓库 + 按品质烘干 Timer（300s + 100/3s×等级）
  - [x] 仓库满 10 条自动暂停，有空位自动恢复
  - [x] `trigger_free_speedup()`：概率跑路（隐藏窗口 + 进 CD）/ 成功加速
  - [x] 引擎实跑验证：洗涤/烘干时长、容量上限 10、CD 缩减数值全部正确
- [x] **Day 3**：右键菜单 + 库存网格（常驻 HUD / 图鉴 / 加速按钮已拆除）
  - [x] 唯一中文字体 YuanRou-P-Bold + `steve_theme.tres`
  - [x] 右键 `ExitPopup`：4 倍窗口 + 抠绿图标 + 统计气泡 + 设置（固定上层）
  - [x] 压力按钮：`randf_range(1s, 12h)` 扣洗涤时间；冷却灰显剩余「MM：SS后再压力他」并每秒刷新
  - [x] 右键菜单右上角悬浮 `×` 关闭；全界面白字加粗、字号统一 16
  - [x] 每次压力点击 15.5% 跑路：空盆 `container.jpg` 抠绿幕 + 红色「已跑路...」
  - [x] `InventoryPopup`：烘干机 / 抽屉统一 `dryer.jpg` ×1.36 + 5×6 可见网格；标题色条与菜单按钮同色
  - [x] 烘干机 / 抽屉「收拾一下」：绿色 EquipButton；品质从高到低；单组全删、双组交集；勾选变红；删除不减生涯计数
  - [x] 聊聊天主界面 + 7 天历史 + 孙哥 system prompt（sun-skill / sun-yuchen-perspective 蒸馏）；双击加速 5 秒；充值 demo
  - [x] 隐藏全部滚动条 UI，滚轮仍可滚动；烘干机 / 抽屉 / 聊聊天底板加不透明
  - [x] 运势：强制年/月/日/时辰选择器 + 大模型输出
  - [x] 看电影：Archive metadata 直链 + 卡住换片；白名单免费非限制级 Theora 小窗；拖边框 / 最大化 / 音量 / 静音 / 倍速
  - [x] 悬停 1s 头顶洗涤水条；立绘命中盒收紧；双击水蓝 flash
  - [x] Steve 发言气泡仅在独在且无菜单时出现，盖住洗涤条；WhatsApp 配色；点气泡跳转会话
  - [x] 45 分钟休息提醒；内裤贴图按 id 生成
  - [x] 品质重构为一次性 / 涤纶 / 纯棉 / 真丝 / 奢华 / 火星科技，并附加 8 档磨损前缀
- [ ] **Day 4**：换装展示系统 + 跑路冷却与 CD 缩减算法对接
  - [x] `VideoStreamPlayer` 动态立绘：autoplay + loop、宽高比内接、鼠标穿透不影响拖拽、
        跑路隐藏并暂停 / 冷却结束续播、缺素材自动回落几何占位、抠像着色器还原透明背景
  - [x] 拒绝 70KB 测试占位 `steve.ogv`；仅播 steve3 转出的正规 Theora，失败回落 Steve2
  - [ ] Steve 立绘美术资源替换 ColorRect 占位（需本机 `steve3.mp4` → `assets/videos/steve.ogv`）
  - [ ] 换装面板调用 `GameData.equip_quality()`
  - [ ] 大红品质特效
  - [ ] 跑路期间的冷却倒计时可视化
- [ ] **Day 5**：本地数据持久化保存 (`save_data.json`) + 整体打包测试
  - [x] `user://save_data.json`：内裤总计 / 陪伴时长 / 跑路次数 / 好感度累加 / 置顶偏好 + 仓库收藏
  - [ ] 离线时间结算（用条目里的 `dry_deadline` 时间戳补算晾干）
  - [ ] Windows 导出预设与打包测试

---

## 九、已知限制 / 后续注意

1. UI 字体是完整的源柔 P Bold（约 11 MB），不再做 GB2312 子集。
2. 动态立绘需自备 `.ogv` 素材（Godot 4 不支持 mp4 / webm）。仓库自带的 70KB
   `steve.ogv` 是测试占位片，运行时不会播放。启动时会扫仓库根目录 / `assets/videos` /
   用户主目录与桌面的 `steve3.mp4`，并用本机 PATH 或常见安装路径里的 FFmpeg
   （Windows 走 `where.exe` / `cmd`）转成 `assets/videos/steve.ogv`。也可双击
   `convert_video.bat`。失败时显示 `Steve2.jpg` / 几何占位。
   Theora 无 Alpha 通道，透明背景要靠抠像着色器。
3. 跑路时用「隐藏内容 + 整窗鼠标穿透」模拟窗口消失，未真正 `hide()` 主窗口；
   为了让玩家知道 Steve 何时回来，保留一条半透明的 `Steve跑路中 CD: xxs` 提示条。
4. 离线收益未结算：条目已存 `dry_deadline` 时间戳，Day 5 读档时按现实时间补算。
5. 拖拽已 clamp 在 `screen_get_usable_rect()` 内，多显示器场景待 Day 5 实测。
6. 看电影只抓 `MOVIE_CATALOG` 里的 CC / 公有领域 Theora（Internet Archive），Godot 4 不能播 mp4。
   先拉 `archive.org/metadata/{id}` 拿 `d1`+`dir` 直链，避免 `/download/` 跳转挂死；
   18 秒没有字节增长就换片。首次下载约 26–65MB，缓存在 `user://movies`。
   聊聊天 / 运势需配置 `STEVE_CHAT_API_URL` 才会走在线大模型。
   聊聊天双方气泡用 WhatsApp 经典配色（对方白 / 自己绿 / 深色字）。
