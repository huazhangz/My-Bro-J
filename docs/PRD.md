# 孙哥桌宠小游戏 · 产品需求文档 (PRD)

> Steam Project · 单机基础版
> 引擎：Godot Engine **4.7.2 stable** · 语言：GDScript (Godot 4.x 语法)
> 最后更新：2026-08-29

---

## 一、项目定位

2D Idle / 放置类**桌面悬浮窗**小游戏（桌宠）。窗口透明、无边框、总在最前，
常驻桌面右下角，可用鼠标左键任意拖拽。玩家离线挂机看孙哥自动洗内裤，
收集不同品质的内裤图鉴，用代币或"免费加速（带跑路风险）"推进循环。

- 渲染后端：`gl_compatibility`（兼容老显卡，2D 小游戏够用）
- 窗口尺寸：**250 × 350**
- 主场景：`res://sun_pet.tscn`

---

## 二、核心业务逻辑与功能清单

| # | 功能 | 说明 | 状态 |
|---|------|------|------|
| 1 | 基础洗涤循环 | 孙哥自动洗内裤，正常速度 **45 秒 / 条** | ✅ 已实现 |
| 2 | 自动晾干机制 | 洗完的内裤放置 **60 秒**后自动晾干进收藏 | ✅ 已实现 |
| 3 | 仓库存储上限 | 未晾干内裤进仓库，容量 **10**，满后暂停洗涤，有空位自动恢复 | ✅ 已实现 |
| 4 | 品质与收藏图鉴 | 普通 / 稀有 / 史诗 / 大红(传说)，大红带特效 | 🟡 数据层完成，图鉴 UI 待做 (Day 3) |
| 5 | 付费加速 | 消耗代币直接扣减洗涤倒计时，无风险 | 🟡 逻辑完成，按钮待做 (Day 3) |
| 6 | 免费加速与风险触发 | 有概率触发"孙哥随机跑路" | ✅ 已实现 |
| 7 | 跑路与冷却机制 | 跑路后隐藏桌宠 + 冷却倒计时，结束后自动回归 | ✅ 已实现 |
| 8 | 换装与展示 | 选择已解锁品质给孙哥穿上展示 | 🟡 数据层完成，立绘/UI 待做 (Day 4) |
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
| `FREE_SPEEDUP_RUNAWAY_CHANCE` | `0.25` | 免费加速触发跑路的概率 |
| `FREE_SPEEDUP_SECONDS` | `15.0` 秒 | 免费加速成功时扣减的洗涤时间 |
| `PAID_SPEEDUP_COST` / `PAID_SPEEDUP_SECONDS` | `10` 币 / `20.0` 秒 | 付费加速 |

### 3.2 品质表 `enum Quality`

| 品质 | Enum 值 | 掉率权重 | CD 缩减系数 | 晾干代币奖励 | 主色 |
|------|---------|---------|------------|------------|------|
| 普通 NORMAL | 0 | 70 | `0.00` | 1 | 浅灰 |
| 稀有 RARE | 1 | 20 | `0.15` | 3 | 蓝 |
| 史诗 EPIC | 2 | 8 | `0.30` | 8 | 紫 |
| 大红 RED_GOLD | 3 | 2 | `0.50` | 25 | 红（带特效） |

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

### 3.5 洗涤状态机（`sun_pet.gd`）

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
                                    免费加速 25% 概率触发
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

运行时 `sun_pet.gd::_apply_window_setup()` 再次以 `DisplayServer` 兜底设置
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

## 五、文件结构

```
My-Bro-J/
├── project.godot           # 透明/无边框/置顶/250x350 + GameData Autoload
├── README.md               # 仓库说明与目录树
├── .cursorrules            # AI 编码规则（强制 Godot 4.x 语法、DisplayServer、闭包信号）
├── .gitignore              # 忽略 .godot/ 导入缓存与导出产物
├── scenes/
│   └── sun_pet.tscn        # 主场景：根节点 Control，全屏铺满，背景全透明
├── scripts/
│   ├── sun_pet.gd          # 窗口拖拽 + 洗涤/晾干/跑路状态机
│   └── GameData.gd         # 全局数据单例（常量、仓库、图鉴、CD 算法、存档接口）
├── assets/
│   ├── icon.svg            # 应用图标
│   ├── images/             # 孙哥立绘、内裤贴图（Day 4）
│   └── fonts/              # 中文字体（Day 3）
└── docs/
    └── PRD.md              # 本文档
```

场景节点树：

```
SunPet (Control, 铺满窗口, MOUSE_FILTER_STOP —— 负责接收拖拽)
├── PetVisual (Control, IGNORE)      # 孙哥占位立绘（Day 4 换真实美术）
│   ├── Head / EyeLeft / EyeRight / Body / Basin (ColorRect)
│   └── NameLabel (Label "SUN BRO")
├── QualityFlash (ColorRect, IGNORE) # 出货品质闪光特效
└── StatusLabel (Label, IGNORE)      # 调试状态文本（Day 3 换正式 UI）
```

> ⚠️ 引擎内置默认字体不含中文字形，因此场景内可见文本暂用英文；
> 中文仅出现在注释与文档中。Day 3 接入中文字体后再改回中文 UI。

---

## 六、当前操作方式（临时，Day 3 会换成正式 UI 按钮）

| 操作 | 效果 |
|------|------|
| 鼠标左键按住拖动 | 移动桌宠窗口 |
| `空格` | 触发一次免费加速（25% 概率跑路） |
| `ESC` 或鼠标右键 | 退出程序（无边框窗口没有关闭按钮） |
| 命令行加 `-- --petlog` | 输出状态机日志，便于无 UI 调试 |

---

## 七、开发进度

- [x] **Day 1**：透明无边框窗口配置 + 桌面悬浮窗基础搭建 + 鼠标拖拽移动功能
  - [x] `project.godot` 写入 transparent / borderless / always_on_top / per_pixel_transparency
  - [x] 视口尺寸 250×350
  - [x] `sun_pet.tscn` 根节点改为 `Control`，铺满窗口，背景完全透明
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
- [ ] **Day 3**：桌面 UI 控件搭建（加速按钮、仓库/图鉴界面、代币显示）
  - [ ] 接入中文字体（默认字体无 CJK 字形）
  - [ ] 免费/付费加速按钮，替换空格键调试入口
  - [ ] 仓库进度条 + 代币显示 + 图鉴弹窗
  - [ ] 正式退出/设置菜单，替换 ESC / 右键调试入口
- [ ] **Day 4**：换装展示系统 + 跑路冷却与 CD 缩减算法对接
  - [ ] 孙哥立绘美术资源替换 ColorRect 占位
  - [ ] 换装面板调用 `GameData.equip_quality()`
  - [ ] 大红品质特效
  - [ ] 跑路期间的冷却倒计时可视化
- [ ] **Day 5**：本地数据持久化保存 (`save_data.json`) + 整体打包测试
  - [ ] `user://save_data.json` 读写（`GameData.to_save_dict()` / `load_from_dict()` 已就绪）
  - [ ] 离线时间结算（用条目里的 `dry_deadline` 时间戳补算晾干）
  - [ ] Windows 导出预设与打包测试

---

## 八、已知限制 / 后续注意

1. 场景内文本暂为英文，原因是引擎默认字体不含中文字形（Day 3 修复）。
2. 孙哥立绘为 `ColorRect` 几何占位，等美术资源（Day 4 替换）。
3. 跑路时用「隐藏内容 + 整窗鼠标穿透」模拟窗口消失，未真正 `hide()` 主窗口。
4. 离线收益未结算：条目已存 `dry_deadline` 时间戳，Day 5 读档时按现实时间补算。
5. 拖拽已 clamp 在 `screen_get_usable_rect()` 内，多显示器场景待 Day 5 实测。
