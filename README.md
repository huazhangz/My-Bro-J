# Steve 桌宠小游戏 · My-Bro-J

> 2D Idle / 放置类**桌面悬浮窗**小游戏（桌宠）
> Godot Engine **4.7.2 stable** · GDScript (Godot 4.x 语法)

透明无边框窗口常驻桌面，Steve 自动洗内裤：**45 秒洗一条 → 进仓库（上限 10）→ 60 秒自动晾干进收藏**。
内裤分一次性 / 涤纶 / 纯棉 / 真丝 / 奢华 / 火星科技六档品质，创建时再掷一档磨损前缀。
穿戴品质越高，"Steve 跑路"的冷却时间缩减越多。

---

## 快速开始

1. 本机必须检出 PR #8 分支（`main` 还是旧版，没有烘干机/抽屉）：
   ```bat
   git fetch origin
   git checkout cursor/qualities-wear-dryer-drawer-0edd
   git pull origin cursor/qualities-wear-dryer-drawer-0edd
   ```
   不要执行 `git reset --hard origin/main`，那会回到没有新 UI 的旧代码。
2. 用 Godot **4.7.x** 打开本仓库根目录（含 `project.godot`）。主场景已锁定为 `res://scenes/steve.tscn`。
3. 把 `Steve1.mp4`、`dryer.jpg`、`Steve2.jpg` 放到仓库根目录。
4. 双击 `convert_video.bat`（需已安装 FFmpeg 并加入 PATH），把 `Steve1.mp4` 转成 `assets/videos/steve.ogv`。
5. 用 **F5** 跑主场景 `steve.tscn`。Game 面板关掉 *Embed Game on Play*。

### 操作方式

| 操作 | 效果 |
|------|------|
| 鼠标在立绘上停留 1.5 秒 | 头顶显示洗涤水条与进度文字 |
| 左键拖动 | 移动桌宠窗口 |
| **在立绘上右键** | 打开菜单：烘干机 / 抽屉 / 退出游戏 |
| 点「烘干机」/「抽屉」 | 打开 2.5× 滚动网格（晾干中 / 已收藏） |
| 点关闭、再右键或 `ESC` | 关闭弹层 |
| `ESC` | 弹窗开着则关闭，否则退出 |
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
│   └── steve.tscn             # 主场景，根节点 Steve (Control)
│
├── scripts/
│   ├── steve.gd               # 窗口拖拽 + 状态机 + 右键菜单 + 视频/色度键
│   ├── GameData.gd
│   └── GameData.gd.uid
│
├── assets/
│   ├── images/
│   │   ├── dryer.jpg
│   │   └── steve2.jpg
│   ├── fonts/
│   │   ├── RenOuFangSong-16.ttf
│   │   ├── steve_theme.tres
│   │   └── RenOuFangSong-OFL.txt
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
| `project.godot` → `gui/theme/custom_font` | `res://assets/fonts/RenOuFangSong-16.ttf` |
| `scenes/steve.tscn` → script / theme / video | `steve.gd` / `steve_theme.tres` / `steve.ogv` |

---

## 动态立绘视频

源文件：`C:\Users\ASUS\My-Bro-J\Steve1.mp4`（绿幕）。Godot 4 只播 `.ogv`，
启动时若找到该 mp4 会用 FFmpeg 转到 `user://steve.ogv`。
色度键默认开启：绿 `#00FF00`，similarity `0.35`，smoothness `0.10`。
日志前缀 `[Steve/Video]`。详见 [`assets/videos/README.md`](assets/videos/README.md)。

---

## 核心数值

| 常量 | 值 | 含义 |
|------|-----|------|
| `WASH_DURATION` | 45 s | 洗完一条内裤 |
| `DRY_DURATION_BASE` | 90 s | 烘干基础时长；品质每级 +10 s |
| `WAREHOUSE_CAPACITY` | 10 | 未晾干仓库上限，满则暂停洗涤 |
| `RUNAWAY_BASE_COOLDOWN` | 120 s | 跑路冷却基础时长 |
| `FREE_SPEEDUP_RUNAWAY_CHANCE` | 7.5% | 免费加速触发跑路的概率 |
| `FREE_SPEEDUP_SECONDS` | 20 s | 免费加速成功时扣减的洗涤时间 |
| `PAID_SPEEDUP_COST` | 10 币 | 付费加速：花 10 金币直接洗完当前这条 |

详见 [`docs/PRD.md`](docs/PRD.md)。
