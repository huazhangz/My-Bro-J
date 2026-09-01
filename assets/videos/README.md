# 动态立绘视频说明

## Godot 4 只能播 Ogg Theora（`.ogv`）

`VideoStreamPlayer` 只有 `VideoStreamTheora`。`.mp4` 必须先转 `.ogv`。

约定绿幕源：`C:\Users\ASUS\My-Bro-J\steve3.mp4`

双击仓库根目录 `convert_video.bat`（FFmpeg 在 PATH）写成 `assets/videos/steve.ogv`。
输出必须大于 80KB，否则会被当成测试占位片拒绝。失败时回落 `Steve2.jpg`。

```powershell
ffmpeg -y -i "steve3.mp4" -vf "fps=24,scale=460:-2" -c:v libtheora -q:v 8 -an "assets\videos\steve.ogv"
```

场景**不要**把占位 `steve.ogv` 挂进 `PetVideo.stream`（二进制 NUL 会导致启动解析失败）。
运行时由 `steve.gd` 查找本机转码结果再赋值。

## 色度键

着色器：`res://assets/shaders/chroma_key.gdshader`，挂在 `PetFrame`（以及跑路空盆）。
不要挂在菜单按钮或库存背景上——那些界面已改为无贴图 / Emoji。

参数改 Steve 根节点导出项：`chroma_key_*`、`chroma_spill_suppression`。

日志前缀 `[Steve/Video]`。
