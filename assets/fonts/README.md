# 中文字体

唯一 UI 字体：**YuanRou-P-Bold**（源柔ゴシック P Bold / GenJyuuGothic-P-Bold）。

| 项 | 内容 |
|----|------|
| 入库文件 | `YuanRou-P-Bold.ttf` |
| 本机压缩包 | `C:\Users\ASUS\My-Bro-J\YuanRou-P-Bold.zip`（根目录 `*.zip` 被 gitignore，仓库只提交解出的 TTF） |
| 来源 | [自家製フォント工房 · 源柔ゴシック](http://jikasei.me/font/genjyuu/)（Source Han Sans 圆角化派生） |
| 许可 | SIL Open Font License 1.1，见 `YuanRou-OFL.txt` |
| 挂载 | `steve_theme.tres` `default_font`、`project.godot` `gui/theme/custom_font`、`steve.tscn` 根节点 theme |

运行时也会查找同名 zip / `GenJyuuGothic-P-Bold.ttf`，找到 zip 就解出 Bold TTF 写进上述路径。

已删除：人偶仿宋、Glow Sans 子集、汉仪永字小熊猫。不要再加回第二套默认字体。
