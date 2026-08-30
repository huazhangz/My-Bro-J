# Steve 桌宠小游戏 · My-Bro-J

> 2D Idle / 放置类**桌面悬浮窗**小游戏（桌宠）
> Godot Engine **4.7.2 stable** · GDScript (Godot 4.x 语法)

透明无边框窗口常驻桌面，Steve 自动洗内裤：**45 秒洗一条 → 进仓库（上限 10）→ 基础 90 秒烘干（品质每级 +10 秒）进收藏**。
内裤分一次性 / 涤纶 / 纯棉 / 真丝 / 奢华 / 火星科技六档品质，创建时再掷一档磨损前缀。
穿戴品质越高，"Steve 跑路"的冷却时间缩减越多。

---

## 快速开始

1. 检出当前功能分支（`main` 没有烘干机 / 抽屉）：
   ```bat
   git fetch origin
   git checkout cursor/qualities-wear-dryer-drawer-0edd
   git pull origin cursor/qualities-wear-dryer-drawer-0edd
   ```
   不要执行 `git reset --hard origin/main`。
2. 用 Godot **4.7.x** 打开本仓库根目录。主场景是 `res://scenes/steve.tscn`。
3. 把 `steve3.mp4`、`dryer.jpg`、`Steve2.jpg` 放到仓库根目录。UI 字体已在 `assets/fonts/YuanRou-P-Bold.ttf`。本机若只有 `YuanRou-P-Bold.zip`，F5 会自动解包。
4. 双击 `convert_video.bat`（需 FFmpeg 在 PATH），把 `steve3.mp4` 转成 `assets/videos/steve.ogv`（必须大于 80KB）。
5. **F5** 跑 `steve.tscn`。Game 面板关掉 *Embed Game on Play*。仓库自带的 70KB `steve.ogv` 不会当人物动画播放。

### 操作方式

| 操作 | 效果 |
|------|------|
| 鼠标在立绘上停留 1.5 秒 | 头顶显示洗涤水条与进度文字 |
| 左键拖动 | 移动桌宠窗口 |
| **在立绘上右键** | 打开 4 倍圆角菜单：抠绿图标进烘干机/抽屉，气泡看统计，设置里固定上层 |
| 点「能不能给我洗快点」 | 随机扣 1 秒~12 小时洗涤时间；独立 15.5% 跑路变空盆；冷却时按钮变灰并显示剩余「MM：SS后再压力他」（每秒读秒） |
| 点「烘干机」/「抽屉」 | 打开 2.5× 滚动网格（晾干中 / 已收藏） |
| 点关闭、再右键或 `ESC` | 关闭弹层 |
| `ESC` | 弹窗开着则关闭，否则退出 |
| 命令行加 `-- --petlog` | 输出状态机日志 |

> 窗口拖不动：编辑器把游戏窗口内嵌了。关掉 Game 面板的 *Embed Game on Play*。

---

## 工程目录树

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
├── assets/images/dryer.jpg
├── assets/images/drawer.jpg
├── assets/images/container.jpg
├── assets/images/steve2.jpg
├── assets/fonts/YuanRou-P-Bold.ttf
├── assets/fonts/YuanRou-OFL.txt
├── assets/fonts/steve_theme.tres
├── assets/shaders/chroma_key.gdshader
├── assets/videos/steve.ogv
└── docs/PRD.md
```

| 引用位置 | 值 |
|---------|-----|
| `run/main_scene` | `res://scenes/steve.tscn` |
| `gui/theme/custom` | `res://assets/fonts/steve_theme.tres` |
| `gui/theme/custom_font` | `res://assets/fonts/YuanRou-P-Bold.ttf` |

---

## 动态立绘视频

源文件：`C:\Users\ASUS\My-Bro-J\steve3.mp4`（绿幕）。Godot 4 只播 `.ogv`。
启动时若找到该 mp4 会用 FFmpeg 覆盖 `assets/videos/steve.ogv`（失败再写 `user://steve.ogv`）。
仓库里 70KB 测试占位片会被拒绝。立绘框 / 色度键默认锁定为 `GameData.PET_AREA` 与
`CHROMA_KEY_*`（`#00FF00` / `0.81` / `0.15` / `0.30`），与当前 `steve.tscn` 一致。
详见 [`assets/videos/README.md`](assets/videos/README.md)。

---

## 核心数值

| 常量 | 值 | 含义 |
|------|-----|------|
| `WASH_DURATION` | 180 s | 洗完一条内裤（3 分钟） |
| `DRY_DURATION_BASE` | 300 s | 烘干基础 5 分钟；品质每级 +100/3 s |
| `WAREHOUSE_CAPACITY` | 10 | 未晾干仓库上限，满则暂停洗涤 |
| `RUNAWAY_BASE_COOLDOWN` | 120 s | 跑路冷却基础时长 |
| `FREE_SPEEDUP_RUNAWAY_CHANCE` | 7.5% | 免费加速触发跑路的概率 |
| `FREE_SPEEDUP_SECONDS` | 20 s | 免费加速成功时扣减的洗涤时间 |
| `PAID_SPEEDUP_ENABLED` | false | 付费加速已下线，无 UI |

详见 [`docs/PRD.md`](docs/PRD.md)。
