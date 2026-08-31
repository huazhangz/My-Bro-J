# 内裤贴图

仓库内 `01.png` … `50.png` 为库存卡片用的 128×128 抠图。

- 本机若有 `boxers.png` / `boxers1.png`（各 5×5），启动时或运行 `tools/slice_boxers.py` 会按格**内缩**后从边角 flood-fill 抠底，避免切到下一行、也避免把布料绿像素整块抠掉。
- **不要**把 Steve 立绘的 `chroma_key.gdshader` 套到这些 PNG 上。
- 没有原表时脚本会烘焙 50 款独立剪影（圆角裤脚，不截平、不带下一行腰边）。
