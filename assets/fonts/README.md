# 中文字体说明

## hanyiyongzixiaoxiongmao.ttf

默认 UI 字体（**汉仪永字小熊猫**）。项目方已获授权，可将该 TTF 提交到本 GitHub 仓库，
见 `HAN-YI-LICENSE.md`。

| 项 | 内容 |
|----|------|
| 文件名 | `hanyiyongzixiaoxiongmao.ttf`（也识别 `HYYongZiXiaoXiongMao-W.ttf`） |
| 入库路径 | `assets/fonts/hanyiyongzixiaoxiongmao.ttf` |
| 本机兜底 | 仓库根目录 / `C:\Users\ASUS\My-Bro-J\` / `C:\Windows\Fonts` |
| 挂载 | 运行时 `_apply_ui_font()` 设为 Theme `default_font`；找到后拷进入库路径 |

云端构建机读不到本机盘时，把授权副本放进仓库根目录再 F5 或跑 `convert_video.bat`。
找不到该文件时回落到人偶仿宋。

## RenOuFangSong-16.ttf

回落 UI 字体（**人偶仿宋 16** / RenOu FangSong，像素仿宋）。

| 项 | 内容 |
|----|------|
| 原字体 | [yzdnn/RenOuFangSong](https://github.com/yzdnn/RenOuFangSong) |
| 许可 | SIL Open Font License 1.1，见 `RenOuFangSong-OFL.txt` |
| 主题 | `steve_theme.tres` 的编译期 `default_font` 指向本文件（Hanyi 未入库时的回落） |
| 挂载 | `project.godot` → `gui/theme/custom` + `gui/theme/custom_font`，以及 `steve.tscn` 根节点 |

## GlowSansSC-Regular-Subset.otf

圆体备选（思源黑体圆角衍生 **Glow Sans SC / 未来荧黑** Regular 的 GB2312 子集，OFL 1.1）。

## steve_theme.tres

全局 UI 主题，类型变体与原先一致（`TitleLabel` / `RiskButton` / `SolidPanel` 等）。
