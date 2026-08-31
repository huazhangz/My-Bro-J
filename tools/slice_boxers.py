#!/usr/bin/env python3
"""Slice boxers.png / boxers1.png (5x5 grids) or bake 50 unique cutouts."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "images" / "underwear"
GRID = 5
CELL = 128
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


def chroma_key(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    corners = [
        pixels[2, 2],
        pixels[width - 3, 2],
        pixels[2, height - 3],
        pixels[width - 3, height - 3],
    ]
    green_hits = 0
    for r, g, b, _a in corners:
        if g > 140 and g > r + 40 and g > b + 40:
            green_hits += 1
    use_green = green_hits >= 2
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            if use_green and g > 90 and g > r + 28 and g > b + 28:
                spill = max(0, g - max(r, b))
                alpha = max(0, 255 - int(spill * 1.8))
                if g > 150 and r < 140 and b < 140:
                    alpha = 0
                pixels[x, y] = (r, min(g, max(r, b) + 12), b, alpha)
                continue
            if not use_green:
                luma = 0.299 * r + 0.587 * g + 0.114 * b
                if luma > 232 and abs(r - g) < 18 and abs(g - b) < 18:
                    pixels[x, y] = (r, g, b, 0)
    return rgba


def trim_cell(image: Image.Image) -> Image.Image:
    bbox = image.getbbox()
    if bbox is None:
        return image
    cropped = image.crop(bbox)
    square = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    scale = min(CELL / cropped.width, CELL / cropped.height) * 0.92
    size = (max(1, int(cropped.width * scale)), max(1, int(cropped.height * scale)))
    resized = cropped.resize(size, Image.Resampling.LANCZOS)
    square.paste(resized, ((CELL - size[0]) // 2, (CELL - size[1]) // 2), resized)
    return square


def slice_sheet(path: Path, start_index: int) -> int:
    sheet = chroma_key(Image.open(path))
    width, height = sheet.size
    cell_w = width // GRID
    cell_h = height // GRID
    written = 0
    for row in range(GRID):
        for col in range(GRID):
            left = col * cell_w
            top = row * cell_h
            cell = sheet.crop((left, top, left + cell_w, top + cell_h))
            cell = trim_cell(chroma_key(cell))
            index = start_index + row * GRID + col
            dest = OUT_DIR / f"{index + 1:02d}.png"
            cell.save(dest, "PNG")
            written += 1
    print(f"sliced {path} -> {written} cells from index {start_index}")
    return written


def _brief_mask(x: int, y: int, width: int, height: int) -> bool:
    nx = (x / width) * 2.0 - 1.0
    ny = y / height
    if ny < 0.08 or ny > 0.94:
        return False
    if ny < 0.22:
        return abs(nx) < 0.78
    body = 0.74 - (ny - 0.22) * 0.16
    if ny > 0.62:
        hole_x = 0.34
        hole_y = (ny - 0.70) / 0.24
        left = nx + hole_x
        right = nx - hole_x
        if hole_y > 0.0 and (
            left * left + hole_y * hole_y < 0.08 or right * right + hole_y * hole_y < 0.08
        ):
            return False
        body -= (ny - 0.62) * 0.34
    return abs(nx) < body


def bake_style(index: int) -> Image.Image:
    image = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    hue = (index * 47) % 360
    sat = 0.38 + (index % 5) * 0.10
    val = 0.72 + (index % 4) * 0.06
    base = _hsv(hue, sat, val)
    band = _hsv(hue, sat * 0.7, min(1.0, val + 0.18))
    stitch = _hsv(hue, sat, max(0.2, val - 0.28))
    pattern = index % 10
    for y in range(CELL):
        for x in range(CELL):
            if not _brief_mask(x, y, CELL, CELL):
                continue
            color = band if y < 28 else base
            color = _pattern(color, stitch, x, y, pattern, index)
            if 28 <= y <= 31:
                color = stitch
            image.putpixel((x, y), color + (255,))
    # waistband highlight
    draw.rounded_rectangle((28, 14, 100, 28), radius=6, outline=stitch + (255,), width=2)
    # fly
    draw.line((64, 36, 64, 70), fill=stitch + (220,), width=2)
    return image.filter(ImageFilter.SMOOTH)


def _pattern(color: tuple[int, int, int], stitch: tuple[int, int, int], x: int, y: int, pattern: int, seed: int) -> tuple[int, int, int]:
    if y < 28:
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
    if pattern == 7 and y > 90:
        return _mix(color, stitch, 0.4)
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
    sheets = []
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
