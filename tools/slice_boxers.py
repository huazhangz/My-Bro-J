#!/usr/bin/env python3
"""Slice bx1.png / bx2.png with absolute cell rects, or bake 50 unique cutouts.

Cell bounds are the user-measured pixel table on a 1536x975 reference sheet,
scaled to the actual image size. Flood-fill transparency from the edges only.
This does not use Steve's global chroma-key settings.
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
SHEET_REF_W = 1536
SHEET_REF_H = 975
SHEET_X = (0, 290, 610, 925, 1225, 1536)
SHEET_Y = (0, 190, 380, 565, 760, 975)
# Left/right keep SHEET_X. Shrink each cell bottom so it does not eat the next row's top.
SHEET_INSET_BOTTOM = 27
KEY_DIST = 0.045
KEY_GREEN_DIST = 0.085
SHEET_NAMES = ("bx1.png", "bx2.png", "BX1.png", "BX2.png")
SEARCH_DIRS = (
    ROOT / "assets" / "images" / "underwear" / "sheets",
    ROOT / "assets" / "images" / "underwear",
    ROOT / "assets" / "images",
    ROOT,
    Path("/mnt/c/Users/ASUS/My-Bro-J/assets/images"),
    Path("/mnt/c/Users/ASUS/My-Bro-J"),
    Path("C:/Users/ASUS/My-Bro-J/assets/images"),
    Path("C:/Users/ASUS/My-Bro-J"),
)


def find_sheet(name: str) -> Path | None:
    for folder in SEARCH_DIRS:
        path = folder / name
        if path.is_file():
            return path
    return None


def cell_box(width: int, height: int, col: int, row: int) -> tuple[int, int, int, int]:
    sx = width / float(SHEET_REF_W)
    sy = height / float(SHEET_REF_H)
    left = max(0, int(round(SHEET_X[col] * sx)))
    right = min(width, int(round(SHEET_X[col + 1] * sx)))
    top = max(0, int(round(SHEET_Y[row] * sy)))
    raw_bottom = min(height, int(round(SHEET_Y[row + 1] * sy)))
    inset = 0
    if row < GRID - 1:
        inset = max(1, int(round(SHEET_INSET_BOTTOM * sy)))
    bottom = max(top + 1, raw_bottom - inset)
    if right - left < 8 or bottom - top < 8:
        return (0, 0, 0, 0)
    return (left, top, right, bottom)


def _luma(r: int, g: int, b: int) -> float:
    return (0.299 * r + 0.587 * g + 0.114 * b) / 255.0


def _is_backdrop(r: int, g: int, b: int, a: int) -> bool:
    if a < 20:
        return True
    luma = _luma(r, g, b)
    if luma > 0.96 and abs(r - g) < 10 and abs(g - b) < 10:
        return True
    if g > 158 and g > r + 72 and g > b + 72:
        return True
    return False


def _matches_backdrop(px: tuple[int, int, int, int], key: tuple[int, int, int, int]) -> bool:
    r, g, b, a = px
    if a < 20:
        return True
    kr, kg, kb, _ka = key
    dist = math.sqrt((r - kr) ** 2 + (g - kg) ** 2 + (b - kb) ** 2) / 255.0
    if dist <= KEY_DIST:
        return True
    if kg > 140 and g > 176 and g > r + 90 and g > b + 90:
        return dist <= KEY_GREEN_DIST
    if _luma(kr, kg, kb) > 0.96 and _luma(r, g, b) > 0.98 and abs(r - g) < 6 and abs(g - b) < 6:
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
    written = 0
    for row in range(GRID):
        for col in range(GRID):
            box = cell_box(width, height, col, row)
            if box[2] <= box[0] or box[3] <= box[1]:
                continue
            cell = flood_key_from_edges(sheet.crop(box))
            cell = trim_cell(cell)
            index = start_index + row * GRID + col
            dest = OUT_DIR / f"{index + 1:02d}.png"
            cell.save(dest, "PNG")
            written += 1
    print(
        f"sliced {path} {width}x{height} -> {written} cells from index {start_index} "
        f"(absolute grid vs {SHEET_REF_W}x{SHEET_REF_H})"
    )
    return written


def _brief_mask() -> Image.Image:
    mask = Image.new("L", (CELL, CELL), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((18, 6, 110, 66), radius=10, fill=255)
    draw.rounded_rectangle((18, 44, 60, 108), radius=16, fill=255)
    draw.rounded_rectangle((68, 44, 110, 108), radius=16, fill=255)
    draw.polygon([(40, 54), (88, 54), (80, 88), (48, 88)], fill=255)
    draw.ellipse((24, 84, 60, 132), fill=0)
    draw.ellipse((68, 84, 104, 132), fill=0)
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
    leftover = [
        p for p in OUT_DIR.glob("*.png") if not p.name[:2].isdigit()
    ]
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
        print("bx1.png / bx2.png not in workspace; keeping existing 01-50 or baking")
        existing = list(OUT_DIR.glob("[0-9][0-9].png"))
        if len(existing) < 50:
            for index in range(50):
                dest = OUT_DIR / f"{index + 1:02d}.png"
                if dest.is_file():
                    continue
                bake_style(index).save(dest, "PNG")
                written += 1
        else:
            written = len(existing)
    print(f"wrote {written} files to {OUT_DIR}")


if __name__ == "__main__":
    main()
