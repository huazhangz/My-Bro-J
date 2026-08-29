# 动态立绘视频说明

## ⚠️ Godot 4 只能播 Ogg Theora（`.ogv`）

Godot 4 内置的 `VideoStreamPlayer` **只有 `VideoStreamTheora` 一种实现**，
`.mp4` 不能直接当 `VideoStream` 加载，必须转成 `.ogv`。

约定的绿幕源文件：

`C:\Users\ASUS\My-Bro-J\Steve1.mp4`

双击仓库根目录的 `convert_video.bat`（需要 FFmpeg 在 PATH 里）即可写成
`assets/videos/steve.ogv`。运行时若根目录仍有 mp4，脚本也会尝试转 `user://steve.ogv`。

## 一、手动转码

```bat
convert_video.bat
```

或：

```powershell
ffmpeg -y -i "Steve1.mp4" -c:v theora -qscale:v 7 -an "assets\videos\steve.ogv"
```

立绘可用区域大约是 **230 × 240** 逻辑像素。

## 二、场景绑定

`scenes/steve.tscn` 里 `PetVideo.stream` 指向 `res://assets/videos/steve.ogv`。
绿幕抠像默认打开：`chroma_key_enabled = true`，`key_color = #00FF00`，
`similarity = 0.35`，`smoothness = 0.10`。着色器挂在 `PetFrame` 上。

## 三、日志

前缀 `[Steve/Video]`。色度键开关会 `print_verbose`：`chroma key ON/OFF`。
