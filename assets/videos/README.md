# 动态立绘视频说明

## ⚠️ Godot 4 只能播 Ogg Theora（`.ogv`）

Godot 4 内置的 `VideoStreamPlayer` **只有 `VideoStreamTheora` 一种实现**，
`.mp4` 不能直接当 `VideoStream` 加载，必须转成 `.ogv`。

约定的绿幕源文件：

`C:\Users\ASUS\My-Bro-J\steve3.mp4`

双击仓库根目录的 `convert_video.bat`（需要 FFmpeg 在 PATH 里）即可写成
`assets/videos/steve.ogv`。运行时若根目录仍有 mp4，脚本会**强制**转出大于 80KB 的
正规 Theora；仓库自带的 70KB / 4 秒测试片会被拒绝，不再当人物动画。
转码失败时回落 `Steve2.jpg`，不会默默播占位片。

## 一、手动转码

```bat
convert_video.bat
```

或：

```powershell
ffmpeg -y -i "steve3.mp4" -vf "fps=24,scale=460:-2" -c:v libtheora -q:v 8 -an "assets\videos\steve.ogv"
```

立绘可用区域大约是 **230 × 240** 逻辑像素。

## 二、场景绑定

`scenes/steve.tscn` 里 `PetVideo.stream` 指向 `res://assets/videos/steve.ogv`。
绿幕抠像默认打开：`chroma_key_enabled = true`，`key_color = #00FF00`，
`similarity = 0.40`，`smoothness = 0.10`，`spill_suppression = 0.30`。
着色器：`res://assets/shaders/chroma_key.gdshader`，挂在 `PetFrame` 与 `InventoryBg`。
请在场景根节点 Steve 上调导出参数，不要只改材质检查器。

## 三、日志

前缀 `[Steve/Video]`。色度键开关会 `print_verbose`：`chroma key ON/OFF`。
