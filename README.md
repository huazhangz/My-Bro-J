# 孙哥桌宠小游戏 · My-Bro-J

> 2D Idle / 放置类**桌面悬浮窗**小游戏（桌宠）
> Godot Engine **4.7.2 stable** · GDScript (Godot 4.x 语法)

透明无边框窗口常驻桌面，孙哥自动洗内裤：**45 秒洗一条 → 进仓库（上限 10）→ 60 秒自动晾干进收藏**。
内裤分普通 / 稀有 / 史诗 / 大红四档品质，穿戴品质越高，"孙哥跑路"的冷却时间缩减越多。

---

## 快速开始

1. 用 Godot **4.7.x** 打开本仓库根目录（含 `project.godot`）。
2. 直接按 **F5** 运行，桌宠会出现在屏幕右下角。

### 操作方式

| 操作 | 效果 |
|------|------|
| 在桌宠/空白处按住左键拖动 | 移动桌宠窗口（按在按钮上不会误拖） |
| 「免费加速」 | 少洗 15 秒，但有 **25% 概率**孙哥跑路 |
| 「付费加速 10币」 | 扣 10 金币立刻洗完当前这条；金币不足时按钮置灰 |
| 「图鉴 / 换装」 | 打开图鉴弹层，穿戴 / 脱下已解锁品质 |
| 右上角 `×` | 退出程序（无边框窗口没有系统关闭按钮） |
| `ESC` | 图鉴开着时先关图鉴，否则退出程序 |
| `空格` | 调试快捷键，等价于点一次「免费加速」 |
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
│                                #   ├── PetVisual    动态立绘（VideoStreamPlayer）+ 几何占位兜底
│                                #   ├── QualityFlash 出货品质闪光特效
│                                #   └── UILayer      CanvasLayer 悬浮中文 UI
│                                #        ├── HudPanel      代币 / 状态倒计时 / 进度条 / 仓库挂起
│                                #        ├── ToastLabel    底部飘字反馈
│                                #        ├── ButtonBar     免费加速 / 付费加速 / 图鉴换装
│                                #        ├── RunawayBanner 跑路期间的冷却提示条
│                                #        └── CodexPanel    图鉴 / 换装弹层
│
├── scripts/                     # 全部 .gd 脚本
│   ├── sun_pet.gd               # 主场景脚本：窗口拖拽 + 洗涤/晾干/满仓/跑路状态机 + 中文 UI 信号绑定
│   ├── sun_pet.gd.uid           # Godot 4.4+ 资源 UID（需随仓库提交）
│   ├── GameData.gd              # 全局 Autoload 单例：数值常量、仓库、图鉴、CD 算法、存档接口
│   └── GameData.gd.uid
│
├── assets/                      # 美术与字体资源
│   ├── icon.svg                 # 应用图标
│   ├── images/                  # 孙哥立绘、内裤贴图（Day 4 填充）
│   ├── fonts/                   # 中文字体与 UI 主题（引擎默认字体不含 CJK 字形）
│   │   ├── NotoSansSC-Regular-Subset.ttf  # Noto Sans SC，GB2312 子集，2.3 MB
│   │   ├── sun_pet_theme.tres             # 全局主题：中文字体 + 按钮/面板/进度条样式
│   │   ├── OFL.txt                        # SIL Open Font License 1.1
│   │   └── README.md                      # 字体来源与子集重生成脚本
│   └── videos/                  # 动态立绘视频
│       ├── sun_pet.ogv                    # 需自备：Godot 4 只认 Ogg Theora
│       ├── video_key.gdshader             # 抠像着色器（Theora 无 Alpha 通道）
│       └── README.md                      # mp4 -> ogv 转换命令与抠像参数说明
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
| `scenes/sun_pet.tscn` → `ext_resource` | `res://scripts/sun_pet.gd`、`res://assets/fonts/sun_pet_theme.tres` |
| `project.godot` → `gui/theme/custom` | `res://assets/fonts/sun_pet_theme.tres` |

移动任何场景 / 脚本 / 资源后，务必同步修正上表，并执行
`godot --headless --path . --import` 确认无报错。

---

## 动态立绘视频（重要）

桌宠中间的立绘由 `VideoStreamPlayer` 循环播放。**Godot 4 只支持 Ogg Theora（`.ogv`）**，
`.mp4` / `.webm` 拖进项目不会被识别，必须先转码：

```powershell
ffmpeg -i "你的视频.mp4" -vf "fps=24,scale=460:-2" -c:v libtheora -q:v 8 -an "assets\videos\sun_pet.ogv"
```

放进 `assets/videos/sun_pet.ogv` 就会自动播放，**不用在编辑器里连任何节点**。
目录里没有 `.ogv` 时会自动回落到 `ColorRect` 几何占位，项目照常能跑。

Theora 没有 Alpha 通道，想保住透明背景要用抠像：在主场景根节点 `SunPet` 的检查器里
把「视频立绘 → `video_key_mode`」调成 `CHROMA`（绿幕/纯色底）、`DARK`（黑底）
或 `BRIGHT`（白底）。详见 [`assets/videos/README.md`](assets/videos/README.md)。

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
- [x] **Day 3** 中文字体 + 悬浮 UI（代币 / 状态倒计时 / 仓库挂起 / 加速按钮 / 图鉴换装弹层）
- [ ] **Day 4** 换装展示系统（动态立绘 `VideoStreamPlayer` 已完成，换装立绘与大红特效待做）
- [ ] **Day 5** 本地持久化 `save_data.json` + 整体打包测试
