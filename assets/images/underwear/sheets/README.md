# 内裤原表

把本机 `bx1.png` / `bx2.png`（各 5×5）放在 `assets/images/`，或这个目录、仓库根目录。

`tools/slice_boxers.py` 与运行时 `UnderwearArt` 会：

1. 按 `UNDERWEAR_SHEET_X/Y` 绝对切格（参考 1536×975）缩放后裁切；左右用 X，底边内收 `UNDERWEAR_SHEET_INSET_BOTTOM`（30），避免裁进下一行顶边。
2. 只从边角 flood-fill 抠底（`UNDERWEAR_KEY_*`），**不**套 Steve 立绘的 `chroma_key.gdshader`。
3. 写出仓库内 `../01.png` … `../50.png`。

原表不要跟切图混放在 `underwear/` 根目录。
