# Steve 桌宠小游戏 · My-Bro-J

> 2D Idle / 放置类**桌面悬浮窗**小游戏（桌宠）
> Godot Engine **4.7.2 stable** · GDScript（Godot 4.x 语法）

透明无边框窗口常驻桌面。Steve 自动洗内裤：**3 分钟洗一条 → 未晾干仓库（上限 10）→ 基础 5 分钟烘干（品质每级再加 100/3 秒）进抽屉收藏**。
内裤有一次性 / 涤纶 / 纯棉 / 真丝 / 奢华 / 火星科技六档品质，创建时再掷一档磨损前缀，并从 **50 张抠图**里随机一张贴图。
穿戴品质越高，跑路冷却缩减越多。

---

## 快速开始

1. 用 Godot **4.7.x** 打开仓库根目录。主场景是 `res://scenes/steve.tscn`。
2. 本机素材（可选，放在 `C:\Users\ASUS\My-Bro-J` 或仓库根目录）：
   - `steve3.mp4`：绿幕立绘。双击 `convert_video.bat`（需 FFmpeg）写成 `assets/videos/steve.ogv`。
   - `Steve2.jpg` / `steve2.jpg`：没有可用视频时的静帧。
   - `bx1.png`、`bx2.png`：各 5×5=25 条内裤，优先放 `assets/images/`。按绝对切格（参考 1536×975）裁切后从边角 flood-fill 抠底，写成 `assets/images/underwear/01.png` … `50.png`。不使用 Steve 立绘全局抠像。仓库已带 50 张切图；本机表在时会覆盖。
3. UI 字体已在 `assets/fonts/YuanRou-P-Bold.ttf`。若只有 zip，F5 会自动解包。
4. **F5** 跑 `steve.tscn`。Game 面板关掉 *Embed Game on Play*。小于 80KB 的 `steve.ogv` 会被拒绝。

不要执行 `git reset --hard origin/main`。

### 操作方式

| 操作 | 效果 |
|------|------|
| 鼠标在立绘命中盒上停留 1 秒 | 头顶显示洗涤水条 |
| 左键拖动 | 移动桌宠窗口 |
| 在立绘上右键 | 打开 4 倍圆角菜单 |
| `🧺 烘干机` / `🗄️ 抽屉` | 未晾干仓库 / 已收藏，4 列格子，品质底色，标题「xx条内裤」 |
| `💦 能不能给我洗快点` | 随机扣 1 秒~12 小时；15.5% 跑路；冷却读秒 |
| `💬 聊聊天` | 孙哥口吻对话；白字黑边；发/回自动滚底 |
| `🔮 哥来帮你算算运势~` | 强制年/月/日/时辰选择器 |
| `🎬 哥请你看个电影吧` | 直接加载 Kepler；关菜单即停下载；「这部好无聊呀哥哥~」展开网址框（.ogv 或网页） |
| `💎 充值` | 一行 demo 提示，待重做 |
| 立绘上双击 | 加速洗涤 5 秒 |
| `ESC` | 先关弹层，否则退出 |

> 窗口拖不动：关掉 Game 面板的 *Embed Game on Play*。

---

## 工程目录树

```
My-Bro-J/
├── project.godot
├── README.md
├── .cursorrules
├── .gitignore
├── convert_video.bat          # steve3.mp4 → assets/videos/steve.ogv
├── scenes/steve.tscn          # 唯一主场景，根节点 Control
├── scripts/
│   ├── steve.gd               # 窗口 / 状态机 / 菜单 / 库存 / 聊天 / 电影
│   ├── GameData.gd            # Autoload 单例：常量、仓库、存档
│   ├── underwear_art.gd       # 50 张内裤切图加载与表切片
│   ├── chat_client.gd         # 聊聊天 / 运势 HTTP
│   ├── movie_client.gd        # Archive Theora + 用户 .ogv 直链
│   └── web_movie_embed.gd     # 网页片源：Windows 内嵌 Edge/Chrome
├── assets/
│   ├── icon.svg
│   ├── images/
│   │   ├── container.jpg      # 跑路空盆（绿幕）
│   │   ├── steve2.jpg         # 无视频时的静帧
│   │   └── underwear/01.png … 50.png + sheets/ + README.md
│   ├── fonts/
│   │   ├── YuanRou-P-Bold.ttf
│   │   ├── YuanRou-OFL.txt
│   │   ├── steve_theme.tres   # 白字、黑描边 4px
│   │   └── README.md
│   ├── shaders/chroma_key.gdshader
│   └── videos/README.md
├── tools/slice_boxers.py      # 本机 bx1.png / bx2.png 绝对切格
├── tools/web_movie_host.ps1   # Windows 把浏览器窗嵌进桌宠 HWND
└── docs/PRD.md
```

| 引用位置 | 值 |
|---------|-----|
| `run/main_scene` | `res://scenes/steve.tscn` |
| `gui/theme/custom` | `res://assets/fonts/steve_theme.tres` |
| `gui/theme/custom_font` | `res://assets/fonts/YuanRou-P-Bold.ttf` |
| Autoload | `GameData` → `scripts/GameData.gd` |

烘干机 / 抽屉贴图已从仓库删除，菜单按钮用 Emoji 文案，库存弹层只有半透明底板。

---

## 动态立绘

源文件：`C:\Users\ASUS\My-Bro-J\steve3.mp4`（绿幕）。Godot 4 只播 `.ogv`。
启动时若找到该 mp4 会用 FFmpeg 写出大于 80KB 的 Theora。失败回落 `Steve2.jpg` / 几何占位。
色度键只挂在 `PetFrame`（以及跑路空盆），参数在 Steve 根节点导出项。
详见 [`assets/videos/README.md`](assets/videos/README.md)。

---

## 核心数值

全部在 `scripts/GameData.gd`，业务脚本不得再写魔法数字。

| 常量 | 值 | 含义 |
|------|-----|------|
| `WASH_DURATION` | 180 s | 洗完一条（3 分钟） |
| `DRY_DURATION_BASE` | 300 s | 烘干基础 5 分钟；品质每级 +100/3 s |
| `WAREHOUSE_CAPACITY` | 10 | 未晾干上限，满则暂停 |
| `UNDERWEAR_ART_COUNT` | 50 | 随机内裤贴图数量 |
| `ITEM_CARD_SWATCH_H` | 63 | 库存贴图高（旧 42×1.5） |
| `DRY_QUALITY_DOWN_PERMILLE` | 150 | 烘干 15% 降一级 |
| `MOVIE_PLAY_AFTER_BYTES` | 2.5 MB | 电影先播阈值 |
| `MOVIE_SKIP_TEXT` | 这部好无聊呀哥哥~ | 电影顶栏粉按钮，展开网址框 |
| `MOVIE_WEB_OPEN_TEXT` | 用系统浏览器打开 | 网页内嵌失败/超时后的回退 |
| `MOVIE_BUTTON_TEXT` | 🎬 哥请你看个电影吧 | 菜单按钮 |
| `CHAT_BUTTON_TEXT` | 💬 聊聊天 | 菜单按钮 |
| `RECHARGE_DEMO_TEXT` | 充值功能演示中，待重做。 | 菜单只弹这一句 |
| `UNDERWEAR_SHEET_X/Y` | 绝对切格 | bx1/bx2 参考 1536×975 |
| `DRYER_BUTTON_TEXT` | 🧺 烘干机 | 菜单按钮 |
| `DRAWER_BUTTON_TEXT` | 🗄️ 抽屉 | 菜单按钮 |
| `UI_FONT_COLOR` / `UI_FONT_OUTLINE_*` | 白字 + 4px 黑边 | 全局文字，含聊聊天 |

详见 [`docs/PRD.md`](docs/PRD.md)。
