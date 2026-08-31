# 内裤原表

把本机 `boxers.png` / `boxers1.png`（各 5×5）放在这个目录，或放在 `assets/images/`、仓库根目录。

`tools/slice_boxers.py` 与运行时 `UnderwearArt` 会：

1. 每格整体上移 `UNDERWEAR_CELL_SHIFT_Y_RATIO`，底部多裁、顶部不裁，避免切到下一行、丢掉本格腰边。
2. 只从边角 flood-fill 抠底（`UNDERWEAR_KEY_*`），**不**套 Steve 立绘的 `chroma_key.gdshader`。
3. 写出仓库内 `../01.png` … `../50.png`。

原表不要跟切图混放在 `underwear/` 根目录。
