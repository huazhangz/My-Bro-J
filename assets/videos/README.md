# 动态立绘视频说明

## ⚠️ Godot 4 只能播 Ogg Theora（`.ogv`）

Godot 4 内置的 `VideoStreamPlayer` **只有 `VideoStreamTheora` 一种实现**，
`ResourceLoader` 认得的视频扩展名只有 `.ogv`：

```gdscript
ResourceLoader.get_recognized_extensions_for_type("VideoStream")
# -> ["ogv", "tres", "res"]
```

也就是说 **`.mp4` / `.webm` / `.mov` 直接拖进项目是不会被识别的**（引擎连导入都不会做），
必须先转码成 `.ogv`。

## 一、把视频转成 `.ogv`

需要 [FFmpeg](https://ffmpeg.org/download.html)（Windows 可用 `winget install Gyan.FFmpeg`）。

最简版（保持原分辨率、去掉音轨）：

```powershell
ffmpeg -i "C:\Users\ASUS\Desktop\1995b34184dfa977183dd6c7f60eff92.mp4" `
       -c:v libtheora -q:v 8 -an `
       "<仓库目录>\assets\videos\sun_pet.ogv"
```

推荐版（限制帧率与分辨率，桌宠常驻后台，能省不少 CPU）：

```powershell
ffmpeg -i "C:\Users\ASUS\Desktop\1995b34184dfa977183dd6c7f60eff92.mp4" `
       -vf "fps=24,scale=460:-2" `
       -c:v libtheora -q:v 8 -an `
       "<仓库目录>\assets\videos\sun_pet.ogv"
```

- `-q:v` 取 0–10，数字越大越清晰、文件越大，8 基本够用。
- `scale=460:-2` 是横版视频用的（宽 460，高度自动保持比例并对齐到偶数）；
  竖版视频请改成 `scale=-2:320`。立绘可用区域是 **230 × 160** 逻辑像素，
  给到 2 倍分辨率在高 DPI 屏上更锐利。
- `-an` 去掉音轨。想保留声音就去掉它，同时把场景里 `PetVideo` 的
  `volume_db` 从 `-80` 调回 `0`（默认静音，桌宠常驻时不吵人）。

## 二、放进项目

文件名固定为 **`sun_pet.ogv`**，放在本目录（`res://assets/videos/sun_pet.ogv`）即可，
**不需要在编辑器里连任何节点**：`scripts/sun_pet.gd` 启动时会自动找到并播放。

- 用别的文件名也行：脚本找不到 `sun_pet.ogv` 时，会自动取本目录下第一个 `.ogv`。
- 一个 `.ogv` 都没有时，会打印一条 `push_warning` 并自动回落到原来的
  `ColorRect` 几何占位，项目照常运行，不会报错。
- 视频按自身宽高比在 **230 × 160** 区域里居中内接，不会被拉伸变形，
  也不会盖住顶部 HUD 和底部按钮。

## 三、启动日志与排错

每次运行都会在输出面板打印一段 `[SunPet/Video]` 日志，**不需要加任何命令行参数**。

成功时：

```
[SunPet/Video] 已加载动态立绘：res://assets/videos/sun_pet.ogv
[SunPet/Video]   资源类型=VideoStreamTheora  时长=4.00s  autoplay=true  loop=true  静音=true
[SunPet/Video]   画面已就绪：源 640×360，按比例摆放为 230×129
```

失败时会说清楚**为什么**以及**怎么修**，并附一条可直接复制的 ffmpeg 命令（用的是
你机器上的真实路径）。常见几种：

| 日志里的原因 | 实际情况 | 怎么修 |
|-------------|---------|-------|
| `没找到任何 .ogv 文件。目录里现在有：xxx.mp4` | 素材放进来了但还没转码 | 照着日志里的 ffmpeg 命令转一次 |
| `这其实是 MP4/MOV 容器，只是文件名改成了 .ogv` | **只改了扩展名，没真转码** | 改回 `.mp4`，再用 ffmpeg 转 |
| `这其实是 Matroska/WebM 容器…` | 同上，WebM 改名 | 同上 |
| `连续 45 帧解不出任何画面` | 是合法 Ogg，但里面没有 Theora 视频轨（比如纯音频 .ogg），或文件损坏 | 重新转码，确认带 `-c:v libtheora` |
| `文件是空的 / 只有 N 字节` | 拷贝没完成或转码中断 | 重新拷贝 / 重新转码 |

> ⚠️ **最容易踩的坑**：把 `.mp4` 直接改名成 `.ogv`。
> 这种文件 `ResourceLoader.load()` **不会返回 null** —— 它会返回一个内部解码失败的
> `VideoStreamTheora`，`is_playing()` 甚至是 `true`，只有 `get_stream_length()` 是 `0`、
> 视频贴图是 `0×0`。所以脚本会用「时长 + 能否解出第一帧」双重校验，
> 确认能播之前不会撤掉几何占位，不会出现「视频没播、占位也没了」的空白。

## 四、透明背景怎么办（重要）

**Ogg Theora 没有 Alpha 通道**，视频一定会画成一块不透明矩形。
桌宠要保持透明背景，只能靠抠像。项目里已经带了
`assets/videos/video_key.gdshader`，挂在 `PetVideo` 节点上，
参数由主场景根节点 `SunPet` 检查器里的 **「视频立绘」** 分组驱动：

| `video_key_mode` | 适用素材 | 说明 |
|------------------|---------|------|
| `OFF`（默认） | 任意 | 不抠像，视频原样显示，背景是不透明矩形 |
| `CHROMA` | 绿幕 / 纯色背景 | 抠掉接近 `video_key_color` 的像素 |
| `DARK` | 黑底视频 | 抠掉亮度低于 `video_key_threshold` 的像素 |
| `BRIGHT` | 白底视频 | 抠掉亮度高于 `video_key_threshold` 的像素 |

`video_key_threshold` 调抠除范围，`video_key_softness` 调边缘羽化
（太小有锯齿，太大会把主体啃掉）。改完直接 F5 看效果即可。

> 如果你的素材本身带 Alpha（比如带透明通道的 MOV / WebM），转成 Theora 会丢掉
> 透明信息。这种情况更好的做法是导出成**带 Alpha 的 PNG 序列帧**，用
> `AnimatedSprite2D` + `SpriteFrames` 播放，能完美保留透明；代价是资源体积更大。
