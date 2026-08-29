# Steve 桌宠小游戏 · My-Bro-J

> 2D Idle / 放置类**桌面悬浮窗**小游戏（桌宠）
> Godot Engine **4.7.2 stable** · GDScript (Godot 4.x 语法)

透明无边框窗口常驻桌面，Steve 自动洗内裤：**45 秒洗一条 → 进仓库（上限 10）→ 60 秒自动晾干进收藏**。
内裤分普通 / 稀有 / 史诗 / 大红四档品质，穿戴品质越高，"Steve 跑路"的冷却时间缩减越多。

---

## 快速开始

1. 用 Godot **4.7.x** 打开本仓库根目录（含 `project.godot`）。
2. 把绿幕素材放到 `C:\Users\ASUS\Desktop\Steve1.mp4`（或覆盖 `assets/videos/steve.ogv`）。
3. 直接按 **F5** 运行，桌宠会出现在屏幕右下角。

### 操作方式

| 操作 | 效果 |
|------|------|
| 在桌宠/空白处按住左键拖动 | 移动桌宠窗口 |
| **在立绘上右键** | 打开上下文菜单（加速 / 图鉴 / 退出） |
| 菜单「免费加速」 | 少洗 15 秒，但有 **25% 概率** Steve 跑路 |
| 菜单「付费加速 10币」 | 扣 10 金币立刻洗完当前这条 |
| 菜单「图鉴 / 换装」 | 打开图鉴弹层 |
| 菜单「退出」 | 退出程序 |
| 点击菜单外 / 再点空白 | 关闭上下文菜单 |
| `ESC` | 先关菜单，再关图鉴，否则退出 |
| `空格` | 调试快捷键，等价于「免费加速」 |
| 命令行加 `-- --petlog` | 输出状态机日志 |

> 若窗口拖不动，说明编辑器把游戏窗口**内嵌**运行了。在 Godot 的 **Game** 面板关掉 *Embed Game on Play*。

---

## 工程目录树

```
My-Bro-J/
├── project.godot
├── README.md
├── .cursorrules
├── .gitignore
│
├── scenes/
│   └── steve.tscn               # 主场景，根节点 Steve (Control)
│
├── scripts/
│   ├── steve.gd                 # 窗口拖拽 + 状态机 + 右键菜单 + 视频/色度键
│   ├── steve.gd.uid
│   ├── GameData.gd
│   └── GameData.gd.uid
│
├── assets/
│   ├── fonts/
│   │   ├── GlowSansSC-Regular-Subset.otf  # 圆体中文（Glow Sans SC 子集）
│   │   ├── steve_theme.tres
│   │   ├── GlowSans-OFL.txt
│   │   └── OFL.txt
│   └── videos/
│       ├── steve.ogv
│       └── video_key.gdshader
│
└── docs/
    └── PRD.md
```

### 路径引用约定

| 引用位置 | 值 |
|---------|-----|
| `project.godot` → `run/main_scene` | `res://scenes/steve.tscn` |
| `project.godot` → `gui/theme/custom` | `res://assets/fonts/steve_theme.tres` |
| `project.godot` → `gui/theme/custom_font` | `res://assets/fonts/GlowSansSC-Regular-Subset.otf` |
| `scenes/steve.tscn` → script / theme / video | `steve.gd` / `steve_theme.tres` / `steve.ogv` |

---

## 动态立绘视频

源文件：`C:\Users\ASUS\Desktop\Steve1.mp4`（绿幕）。Godot 4 只播 `.ogv`，
启动时若找到该 mp4 会用 FFmpeg 转到 `user://steve.ogv`。
色度键默认开启：绿 `#00FF00`，similarity `0.35`，smoothness `0.10`。
日志前缀 `[Steve/Video]`。详见 [`assets/videos/README.md`](assets/videos/README.md)。

---

## 核心数值

| 常量 | 值 | 含义 |
|------|-----|------|
| `WASH_DURATION` | 45 s | 洗完一条内裤 |
| `DRY_DURATION` | 60 s | 自动晾干 |
| `WAREHOUSE_CAPACITY` | 10 | 未晾干仓库上限，满则暂停洗涤 |
| `RUNAWAY_BASE_COOLDOWN` | 120 s | 跑路冷却基础时长 |
| `FREE_SPEEDUP_RUNAWAY_CHANCE` | 25% | 免费加速触发跑路的概率 |
| `FREE_SPEEDUP_SECONDS` | 15 s | 免费加速成功时扣减的洗涤时间 |
| `PAID_SPEEDUP_COST` | 10 币 | 付费加速：花 10 金币直接洗完当前这条 |

详见 [`docs/PRD.md`](docs/PRD.md)。
