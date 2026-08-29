# 孙哥桌宠小游戏 · My-Bro-J

> 2D Idle / 放置类**桌面悬浮窗**小游戏（桌宠）
> Godot Engine **4.7.2 stable** · GDScript (Godot 4.x 语法)

透明无边框窗口常驻桌面，孙哥自动洗内裤：**45 秒洗一条 → 进仓库（上限 10）→ 60 秒自动晾干进收藏**。
内裤分普通 / 稀有 / 史诗 / 大红四档品质，穿戴品质越高，"孙哥跑路"的冷却时间缩减越多。

---

## 快速开始

1. 用 Godot **4.7.x** 打开本仓库根目录（含 `project.godot`）。
2. 直接按 **F5** 运行，桌宠会出现在屏幕右下角。

### 当前操作方式（临时，Day 3 换成正式 UI 按钮）

| 操作 | 效果 |
|------|------|
| 鼠标左键按住拖动 | 移动桌宠窗口 |
| `空格` | 触发一次免费加速（25% 概率触发跑路） |
| `ESC` / 鼠标右键 | 退出程序（无边框窗口没有关闭按钮） |
| 命令行加 `-- --petlog` | 输出状态机日志，便于无 UI 调试 |

> 若窗口拖不动，说明编辑器把游戏窗口**内嵌**运行了。仓库内已提交
> `.godot/editor/project_metadata.cfg`（`embed_on_play=false`）默认关闭内嵌；
> 如仍被内嵌，在 Godot 的 **Game** 面板关掉 *Embed Game on Play* 即可。

---

## 工程目录树

```
My-Bro-J/
├── project.godot                # 项目配置：透明/无边框/置顶/250x350 + GameData Autoload
├── README.md                    # 本文件
├── .cursorrules                 # AI 编码规则：强制 Godot 4.x 语法、DisplayServer、闭包信号
├── .gitignore                   # 忽略 .godot/ 导入缓存与导出产物
│
├── scenes/                      # 全部 .tscn 场景
│   └── sun_pet.tscn             # 主场景（root/main_scene）：根节点 Control，铺满窗口、背景全透明
│                                #   ├── PetVisual    孙哥占位立绘 + 洗衣盆
│                                #   ├── QualityFlash 出货品质闪光特效
│                                #   └── StatusLabel  调试状态文本（Day 3 换正式 UI）
│
├── scripts/                     # 全部 .gd 脚本
│   ├── sun_pet.gd               # 主场景脚本：DisplayServer 窗口拖拽 + 洗涤/晾干/满仓/跑路状态机
│   ├── sun_pet.gd.uid           # Godot 4.4+ 资源 UID（需随仓库提交）
│   ├── GameData.gd              # 全局 Autoload 单例：数值常量、仓库、图鉴、CD 算法、存档接口
│   └── GameData.gd.uid
│
├── assets/                      # 美术与字体资源
│   ├── icon.svg                 # 应用图标
│   ├── images/                  # 孙哥立绘、内裤贴图（Day 4 填充）
│   └── fonts/                   # 中文字体（Day 3 接入，引擎默认字体不含 CJK 字形）
│
└── docs/
    └── PRD.md                   # 产品需求文档：完整需求、数据结构、数值表、CD 算法、开发进度
```

### 路径引用约定

| 引用位置 | 值 |
|---------|-----|
| `project.godot` → `run/main_scene` | `res://scenes/sun_pet.tscn` |
| `project.godot` → `config/icon` | `res://assets/icon.svg` |
| `project.godot` → `[autoload] GameData` | `*res://scripts/GameData.gd` |
| `scenes/sun_pet.tscn` → `ext_resource` | `res://scripts/sun_pet.gd` |

移动任何场景 / 脚本 / 资源后，务必同步修正上表，并执行
`godot --headless --path . --import` 确认无报错。

---

## 核心数值

| 常量 | 值 | 含义 |
|------|-----|------|
| `WASH_DURATION` | 45 s | 洗完一条内裤 |
| `DRY_DURATION` | 60 s | 自动晾干 |
| `WAREHOUSE_CAPACITY` | 10 | 未晾干仓库上限，满则暂停洗涤 |
| `RUNAWAY_BASE_COOLDOWN` | 120 s | 跑路冷却基础时长 |
| `FREE_SPEEDUP_RUNAWAY_CHANCE` | 25% | 免费加速触发跑路的概率 |

品质与 CD 缩减：

| 品质 | 掉率权重 | CD 缩减 | 晾干代币 |
|------|---------|--------|---------|
| 普通 NORMAL | 70 | 0% | 1 |
| 稀有 RARE | 20 | 15% | 3 |
| 史诗 EPIC | 8 | 30% | 8 |
| 大红 RED_GOLD | 2 | 50% | 25 |

```
图鉴附加缩减 = min(已收藏条数 × 0.005, 0.10)
总缩减比例   = clamp(品质缩减 + 图鉴附加缩减, 0, 0.80)
跑路冷却     = max(基础冷却 × (1 − 总缩减比例), 10.0)
```

详见 [`docs/PRD.md`](docs/PRD.md)。

---

## 开发进度

- [x] **Day 1** 透明无边框窗口 + 桌面悬浮 + 鼠标拖拽移动
- [x] **Day 2** 核心数据单例 `GameData.gd` + 洗涤/晾干状态机
- [ ] **Day 3** 桌面 UI 控件（加速按钮、仓库/图鉴界面、代币显示、中文字体）
- [ ] **Day 4** 换装展示系统 + 跑路冷却与 CD 缩减算法对接
- [ ] **Day 5** 本地持久化 `save_data.json` + 整体打包测试
