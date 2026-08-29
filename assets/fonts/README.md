# 中文字体说明

## hanyiyongzixiaoxiongmao.ttf

运行时优先加载仓库根目录或 `assets/fonts/hanyiyongzixiaoxiongmao.ttf`
（汉仪永字小熊猫）。请把你本机的该文件复制进项目，**不要**从网上下载后提交到公开仓库
（汉仪字体商用需授权）。找不到该文件时回落到人偶仿宋。

## RenOuFangSong-16.ttf

默认 UI 字体（**人偶仿宋 16** / RenOu FangSong，像素仿宋）。

| 项 | 内容 |
|----|------|
| 原字体 | [yzdnn/RenOuFangSong](https://github.com/yzdnn/RenOuFangSong) |
| 许可 | SIL Open Font License 1.1，见 `RenOuFangSong-OFL.txt` |
| 主题 | `steve_theme.tres` 的 `default_font` 指向本文件 |
| 挂载 | `project.godot` → `gui/theme/custom` + `gui/theme/custom_font`，以及 `steve.tscn` 根节点 |

所有 Label / Button / 右键菜单 / 烘干机与抽屉网格都走这一套仿宋。

## GlowSansSC-Regular-Subset.otf

圆体 UI 字体（思源黑体圆角衍生 **Glow Sans SC / 未来荧黑** Regular 的 GB2312 子集）。

| 项 | 内容 |
|----|------|
| 原字体 | Glow Sans SC Normal Regular（[welai/glow-sans](https://github.com/welai/glow-sans) v0.93） |
| 许可 | SIL Open Font License 1.1，见 `GlowSans-OFL.txt`（衍生自 Source Han Sans） |
| 处理 | 按 **GB2312 全字符集** + ASCII + 常用标点做子集化 |
| 体积 | 完整 OTF ~9 MB → **约 2.0 MB** |

主题 `steve_theme.tres` 的 `default_font` 指向本文件，并挂到
`project.godot` 的 `gui/theme/custom` 与 `scenes/steve.tscn` 根节点，
因此 Label / Button / 图鉴弹层 / 右键菜单都走同一套圆体。

### 重新生成子集（需要 `pip install fonttools brotli`）

```python
from fontTools.ttLib import TTFont
from fontTools import subset

def gb2312_chars() -> str:
    out = []
    for hi in range(0xA1, 0xFF):
        for lo in range(0xA1, 0xFF):
            try:
                out.append(bytes([hi, lo]).decode("gb2312"))
            except UnicodeDecodeError:
                pass
    return "".join(out)

EXTRA = ("0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
         " !\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~"
         "·×÷—…‘’“”、。《》【】！？：；，（）％￥° ▲▼◆●○★☆→←↑↓")

font = TTFont("GlowSansSC-Normal-Regular.otf")
options = subset.Options()
options.layout_features = ["*"]
options.name_IDs = ["*"]
options.name_languages = ["*"]
options.drop_tables = ["BASE", "vhea", "vmtx", "VORG"]
sub = subset.Subsetter(options=options)
sub.populate(text=gb2312_chars() + EXTRA)
sub.subset(font)
font.save("GlowSansSC-Regular-Subset.otf")
```

## steve_theme.tres

全局 UI 主题，类型变体与原先一致（`TitleLabel` / `RiskButton` / `SolidPanel` 等）。
