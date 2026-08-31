#!/usr/bin/env python3
"""Slice boxers.png / boxers1.png (5x5 grids) or bake 50 unique cutouts.

Slicing insets each cell so the next row's waistband is not included, then
flood-fills transparency from the edges only. This does not use Steve's
global chroma-key settings.
"""

from __future__ import annotations

import math
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "images" / "underwear"
GRID = 5
CELL = 128
INSET_X_RATIO = 1.0 / 12.0
INSET_TOP_RATIO = 1.0 / 16.0
INSET_BOTTOM_RATIO = 1.0 / 8.0
SHEET_NAMES = ("boxers.png", "boxers1.png", "Boxers.png", "Boxers1.png")
SEARCH_DIRS = (
    ROOT,
    ROOT / "assets" / "images",
    Path("/mnt/c/Users/ASUS/My-Bro-J"),
    Path("C:/Users/ASUS/My-Bro-J"),
)


def find_sheet(name: str) -> Path | None:
    for folder in SEARCH_DIRS:
        path = folder / name
        if path.is_file():
            return path
    return None


def _luma(r: int, g: int, b: int) -> float:
    return (0.299 * r + 0.587 * g + 0.114 * b) / 255.0


def _is_backdrop(r: int, g: int, b: int, a: int) -> bool:
    if a < 20:
        return True
    luma = _luma(r, g, b)
    if luma > 0.90 and abs(r - g) < 22 and abs(g - b) < 22:
        return True
    if g > 128 and g > r + 46 and g > b + 46:
        return True
    return False


def _matches_backdrop(px: tuple[int, int, int, int], key: tuple[int, int, int, int]) -> bool:
    r, g, b, a = px
    if a < 20:
        return True
    kr, kg, kb, _ka = key
    dist = math.sqrt((r - kr) ** 2 + (g - kg) ** 2 + (b - kb) ** 2) / 255.0
    if dist <= 0.22:
        return True
    if kg > 115 and g > 122 and g > r + 50 and g > b + 50:
        return dist <= 0.38
    if _luma(kr, kg, kb) > 0.88 and _luma(r, g, b) > 0.88 and abs(r - g) < 22 and abs(g - b) < 22:
        return True
    return False


def flood_key_from_edges(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    if width < 4 or height < 4:
        return rgba
    corners = [
        pixels[1, 1],
        pixels[width - 2, 1],
        pixels[1, height - 2],
        pixels[width - 2, height - 2],
    ]
    hits = [c for c in corners if _is_backdrop(c[0], c[1], c[2], c[3])]
    if len(hits) < 2:
        return rgba
    key = hits[0]
    visited = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    def seed(x: int, y: int) -> None:
        idx = y * width + x
        if visited[idx]:
            return
        if not _matches_backdrop(pixels[x, y], key):
            return
        visited[idx] = 1
        queue.append((x, y))

    for x in range(width):
        seed(x, 0)
        seed(x, height - 1)
    for y in range(height):
        seed(0, y)
        seed(width - 1, y)
    while queue:
        x, y = queue.popleft()
        pixels[x, y] = (0, 0, 0, 0)
        if x > 0:
            seed(x - 1, y)
        if x + 1 < width:
            seed(x + 1, y)
        if y > 0:
            seed(x, y - 1)
        if y + 1 < height:
            seed(x, y + 1)
    return rgba


def trim_cell(image: Image.Image) -> Image.Image:
    bbox = image.getbbox()
    if bbox is None:
        return Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    cropped = image.crop(bbox)
    square = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    scale = min(CELL / cropped.width, CELL / cropped.height) * 0.90
    size = (max(1, int(cropped.width * scale)), max(1, int(cropped.height * scale)))
    resized = cropped.resize(size, Image.Resampling.LANCZOS)
    square.paste(resized, ((CELL - size[0]) // 2, (CELL - size[1]) // 2), resized)
    return square


def slice_sheet(path: Path, start_index: int) -> int:
    sheet = Image.open(path).convert("RGBA")
    width, height = sheet.size
    cell_w = width // GRID
    cell_h = height // GRID
    inset_x = max(4, int(round(cell_w * INSET_X_RATIO)))
    inset_top = max(4, int(round(cell_h * INSET_TOP_RATIO)))
    inset_bottom = max(6, int(round(cell_h * INSET_BOTTOM_RATIO)))
    written = 0
    for row in range(GRID):
        for col in range(GRID):
            left = col * cell_w + inset_x
            top = row * cell_h + inset_top
            right = (col + 1) * cell_w - inset_x
            bottom = (row + 1) * cell_h - inset_bottom
            cell = flood_key_from_edges(sheet.crop((left, top, right, bottom)))
            cell = trim_cell(cell)
            index = start_index + row * GRID + col
            dest = OUT_DIR / f"{index + 1:02d}.png"
            cell.save(dest, "PNG")
            written += 1
    print(f"sliced {path} -> {written} cells from index {start_index} (inset x={inset_x} top={inset_top} bottom={inset_bottom})")
    return written


def _brief_mask() -> Image.Image:
    mask = Image.new("L", (CELL, CELL), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((18, 10, 110, 70), radius=10, fill=255)
    draw.rounded_rectangle((18, 48, 60, 116), radius=16, fill=255)
    draw.rounded_rectangle((68, 48, 110, 116), radius=16, fill=255)
    draw.polygon([(40, 58), (88, 58), (80, 94), (48, 94)], fill=255)
    draw.ellipse((24, 90, 60, 140), fill=0)
    draw.ellipse((68, 90, 104, 140), fill=0)
    return mask


def bake_style(index: int) -> Image.Image:
    mask = _brief_mask()
    image = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    hue = (index * 47) % 360
    sat = 0.38 + (index % 5) * 0.10
    val = 0.72 + (index % 4) * 0.06
    base = _hsv(hue, sat, val)
    band = _hsv(hue, sat * 0.7, min(1.0, val + 0.18))
    stitch = _hsv(hue, sat, max(0.2, val - 0.28))
    pattern = index % 10
    for y in range(CELL):
        for x in range(CELL):
            if mask.getpixel((x, y)) < 128:
                continue
            color = band if y < 32 else base
            color = _pattern(color, stitch, x, y, pattern, index)
            if 28 <= y <= 31:
                color = stitch
            image.putpixel((x, y), color + (255,))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((30, 16, 98, 30), radius=6, outline=stitch + (255,), width=2)
    draw.line((64, 36, 64, 72), fill=stitch + (220,), width=2)
    return image


def _pattern(
    color: tuple[int, int, int],
    stitch: tuple[int, int, int],
    x: int,
    y: int,
    pattern: int,
    seed: int,
) -> tuple[int, int, int]:
    if y < 30:
        return color
    if pattern == 0 and (x // 6 + y // 6) % 2 == 0:
        return _mix(color, (255, 255, 255), 0.12)
    if pattern == 1 and (x + y * 2) % 8 == 0:
        return stitch
    if pattern == 2 and x % 10 < 4:
        return _mix(color, (0, 0, 0), 0.12)
    if pattern == 3 and ((x - 64) ** 2 + (y - 70) ** 2) % 53 < 8:
        return _mix(color, (255, 255, 255), 0.18)
    if pattern == 4 and int(math.sin((x + seed) / 5.0) * 8 + y) % 9 == 0:
        return stitch
    if pattern == 5 and (x // 8) % 2 == (y // 8) % 2:
        return _hsv((seed * 19) % 360, 0.55, 0.85)
    if pattern == 6 and ((x - 64) ** 2 + (y - 58) ** 2) < 90:
        return _mix(color, (255, 80, 120), 0.35)
    if pattern == 7 and y > 96:
        return _mix(color, stitch, 0.28)
    if pattern == 8 and (x + seed) % 13 < 3 and y % 11 < 3:
        return (255, 220, 80)
    if pattern == 9 and abs(x - 64) < 10:
        return _mix(color, (255, 255, 255), 0.2)
    return color


def _hsv(h: float, s: float, v: float) -> tuple[int, int, int]:
    c = v * s
    x = c * (1 - abs((h / 60.0) % 2 - 1))
    m = v - c
    if h < 60:
        r, g, b = c, x, 0
    elif h < 120:
        r, g, b = x, c, 0
    elif h < 180:
        r, g, b = 0, c, x
    elif h < 240:
        r, g, b = 0, x, c
    elif h < 300:
        r, g, b = x, 0, c
    else:
        r, g, b = c, 0, x
    return (int((r + m) * 255), int((g + m) * 255), int((b + m) * 255))


def _mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return (
        int(a[0] + (b[0] - a[0]) * t),
        int(a[1] + (b[1] - a[1]) * t),
        int(a[2] + (b[2] - a[2]) * t),
    )


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    leftover = [p for p in OUT_DIR.glob("*.png") if not p.name[:2].isdigit()]
    for path in leftover:
        path.unlink()
        print(f"removed leftover {path.name}")
    sheets: list[Path] = []
    for name in SHEET_NAMES:
        path = find_sheet(name)
        if path is not None and path not in sheets:
            sheets.append(path)
    written = 0
    if len(sheets) >= 2:
        written += slice_sheet(sheets[0], 0)
        written += slice_sheet(sheets[1], 25)
    elif len(sheets) == 1:
        written += slice_sheet(sheets[0], 0)
        for index in range(25, 50):
            bake_style(index).save(OUT_DIR / f"{index + 1:02d}.png", "PNG")
            written += 1
        print("only one sheet found; baked styles 26-50")
    else:
        print("boxers.png / boxers1.png not in workspace; baking 50 unique cutouts")
        for index in range(50):
            bake_style(index).save(OUT_DIR / f"{index + 1:02d}.png", "PNG")
            written += 1
    print(f"wrote {written} files to {OUT_DIR}")


if __name__ == "__main__":
    main()
