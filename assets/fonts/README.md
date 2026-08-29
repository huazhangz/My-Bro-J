# 中文字体说明

## NotoSansSC-Regular-Subset.ttf

| 项 | 内容 |
|----|------|
| 原字体 | Noto Sans SC（思源黑体 简体中文），Google Fonts 可变字体 `NotoSansSC[wght].ttf` |
| 许可 | SIL Open Font License 1.1，全文见同目录 `OFL.txt` |
| 处理 | 先把可变字重实例化到 `wght=400`（Regular），再按 **GB2312 全字符集**（一级 3755 + 二级 3008 汉字）+ ASCII + 常用中英文标点/符号做子集化 |
| 体积 | 17.8 MB → **2.3 MB**（仓库友好，同时覆盖日常简体中文 UI 的全部用字） |

原始字体来自 <https://github.com/google/fonts/tree/main/ofl/notosanssc>。

### 重新生成子集（需要 `pip install fonttools brotli`）

```python
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
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

font = TTFont("NotoSansSC[wght].ttf")
instancer.instantiateVariableFont(font, {"wght": 400}, inplace=True, updateFontNames=True)
options = subset.Options()
options.layout_features = ["*"]
options.name_IDs = ["*"]
options.name_languages = ["*"]
options.drop_tables = ["BASE", "vhea", "vmtx", "VORG"]
sub = subset.Subsetter(options=options)
sub.populate(text=gb2312_chars() + EXTRA)
sub.subset(font)
font.save("NotoSansSC-Regular-Subset.ttf")
```

> 子集只包含 GB2312 范围内的汉字。若之后 UI 出现生僻字显示成方块，
> 把该字加进 `EXTRA` 重新生成即可（`.ttf.import` 不用动）。

## sun_pet_theme.tres

全局 UI 主题，`default_font` 指向上面的字体，同时定义了按钮/面板/进度条样式与
一组 **类型变体（Type Variation）**：

| 变体 | 基类 | 用途 |
|------|------|------|
| `TitleLabel` | Label | 标题（金色 15px） |
| `SmallLabel` | Label | 次要信息（灰色 11px） |
| `CoinLabel` | Label | 金币数（金色 14px） |
| `FloatLabel` | Label | 直接浮在透明桌面上的文字（带 5px 描边） |
| `SolidPanel` | PanelContainer | 图鉴弹层（不透明 + 金边） |
| `ChipPanel` | PanelContainer | 跑路冷却提示条 |
| `RiskButton` | Button | 免费加速（橙，带跑路风险） |
| `CoinButton` | Button | 付费加速（金） |
| `CodexButton` | Button | 图鉴 / 换装（紫） |
| `EquipButton` | Button | 图鉴行内的穿戴按钮（绿） |
| `CloseButton` | Button | 右上角退出（红） |

主题同时挂在 `project.godot` 的 `gui/theme/custom`（覆盖 Tooltip 等引擎内建 UI）
与 `scenes/sun_pet.tscn` 根节点的 `theme` 上，因此场景内所有 Label / Button
都默认使用中文字体，无需逐节点设置。
