#!/usr/bin/env python3
"""A layout guide of a level for Gemini (D113, docs/art/gemini-kit.md, E-2b).

Flat colour zones with numbers, 16:9, built from the level's own data so it
always matches the game: the map and platforms of tools/build_<level>.gd and
the windows, lamps and concrete of `world` in game/data/levels.json. Gemini
repaints this picture instead of guessing the layout from words.

    python3 tools/layout_guide.py level_01 docs/art/gemini/layout_room.png

Colours: brown back wall, blue windows, dark grey solid ground with a thin
light line on every walkable top, a red partition above a door, a yellow and
black shutter, yellow platforms, beige concrete, a black entrance, a grey exit
with a red beacon, orange lamps on cables, a purple heroine for scale.
"""
import json
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
HEROINE_CELLS = (92 / 64.0, 44 / 64.0)

# Numbered notes per level, in cells: (x, y). The prompt names each number.
LABELS = {
    "level_01": [(1.0, 9.0), (8.1, 9.0), (11.0, 11.0), (14.5, 13.2), (15.0, 10.9),
                 (22.6, 7.9), (19.5, 14.1), (26.0, 7.4), (28.0, 11.5)],
}


def read_builder(level: str) -> dict:
    text = (ROOT / "tools" / f"build_{level}.gd").read_text(encoding="utf-8")
    rows = re.search(r"const MAP := \[(.*?)\]", text, re.S).group(1)
    data = {"map": re.findall(r'"([^"]+)"', rows), "platforms": []}
    width = re.search(r"PLATFORM_WIDTH_CELLS := (\d+)", text)
    data["platform_width"] = int(width.group(1)) if width else 3
    height = re.search(r"PLATFORM_HEIGHT := ([\d.]+)", text)
    data["platform_height"] = float(height.group(1)) / 64.0 if height else 0.5
    for x, y in re.findall(r"PLATFORM_\d+_CENTRE := Vector2\(([\d.]+), ([\d.]+)\)", text):
        data["platforms"].append((float(x), float(y)))
    entrance = re.search(r"ENTRANCE_CELLS := Rect2i\((\d+), (\d+), (\d+), (\d+)\)", text)
    data["entrance"] = tuple(int(n) for n in entrance.groups()) if entrance else None
    return data


def read_world(level: str) -> dict:
    levels = json.loads((ROOT / "game" / "data" / "levels.json").read_text(encoding="utf-8"))
    for entry in levels:
        if entry.get("id") == level:
            return entry.get("world", {})
    return {}


def main() -> None:
    level, out = sys.argv[1], Path(sys.argv[2])
    builder, world = read_builder(level), read_world(level)
    grid = builder["map"]
    cols, rows = len(grid[0]), len(grid)
    c = min(1920 // cols, 1080 // rows)
    image = Image.new("RGB", (1920, 1080), (46, 46, 50))
    room = Image.new("RGB", (cols * c, rows * c), (110, 70, 58))
    d = ImageDraw.Draw(room)

    def box(x, y, w, h, colour):
        d.rectangle([round(x * c), round(y * c), round((x + w) * c) - 1, round((y + h) * c) - 1], fill=colour)

    for piece in world.get("back", []):
        if piece.get("kind") == "window":
            x, y, w, h = piece["rect"]
            box(x, y + w / 2, w, h - w / 2, (40, 55, 105))
            d.pieslice([x * c, y * c, (x + w) * c, (y + w) * c], 180, 360, fill=(40, 55, 105))
    concrete = [tuple(r) for r in world.get("ground", {}).get("concrete", [])]
    doors = {(x, y) for y, row in enumerate(grid) for x, ch in enumerate(row) if ch == "D"}
    door_columns = {x for x, _ in doors}
    top_door = {x: min(y for dx, y in doors if dx == x) for x in door_columns}
    for y, row in enumerate(grid):
        for x, ch in enumerate(row):
            if ch != "#":
                continue
            colour = (45, 45, 50)
            if x in door_columns and 0 < y < top_door[x]:
                colour = (150, 60, 45)
            if any(rx <= x < rx + rw and ry <= y < ry + rh for rx, ry, rw, rh in concrete):
                colour = (120, 112, 98)
            box(x, y, 1, 1, colour)
    for y, row in enumerate(grid):
        for x, ch in enumerate(row):
            if ch == "#" and y > 0 and grid[y - 1][x] != "#":
                d.rectangle([x * c, y * c - 3, (x + 1) * c, y * c + 3], fill=(200, 200, 205))
    for x, y in sorted(doors):
        for i in range(4):
            colour = (230, 180, 30) if i % 2 == 0 else (20, 20, 20)
            d.rectangle([x * c + c // 5, y * c + i * c // 4, (x + 1) * c - c // 5, y * c + (i + 1) * c // 4 - 1], fill=colour)
    if builder["entrance"]:
        ex, ey, ew, eh = builder["entrance"]
        box(ex, ey, ew, eh, (5, 5, 5))
    exits = [(x, y) for y, row in enumerate(grid) for x, ch in enumerate(row) if ch == "E"]
    if exits:
        x0, y0 = min(x for x, _ in exits), min(y for _, y in exits)
        x1, y1 = max(x for x, _ in exits) + 1, max(y for _, y in exits) + 1
        box(x0, y0, x1 - x0, y1 - y0, (150, 160, 170))
        mid = (x0 + x1) / 2.0
        d.ellipse([(mid - 0.2) * c, (y0 - 0.55) * c, (mid + 0.2) * c, (y0 - 0.15) * c], fill=(230, 30, 30))
    width, thick = builder["platform_width"], builder["platform_height"]
    for x, y in builder["platforms"]:
        box(x - width / 2.0, y, width, thick, (235, 190, 40))
    for lamp in world.get("lamps", []):
        x, y = float(lamp["x"]), 1.0 + float(lamp["drop"])
        d.line([x * c, c, x * c, y * c], fill=(20, 20, 20), width=2)
        d.ellipse([x * c - c // 4, y * c - c // 7, x * c + c // 4, y * c + c // 7], fill=(255, 150, 40))
    spawn = [(x, y) for y, row in enumerate(grid) for x, ch in enumerate(row) if ch == "S"]
    if spawn:
        sx, sy = spawn[0]
        tall, wide = HEROINE_CELLS
        box(sx + 1.5, sy + 1 - tall, wide, tall, (170, 40, 200))
    font = ImageFont.truetype(FONT, max(c // 2, 14))
    for n, (x, y) in enumerate(LABELS.get(level, []), 1):
        r = c * 0.36
        d.ellipse([x * c - r, y * c - r, x * c + r, y * c + r], fill=(255, 255, 255))
        d.text((x * c, y * c), str(n), font=font, fill=(0, 0, 0), anchor="mm")
    image.paste(room, ((1920 - room.width) // 2, (1080 - room.height) // 2))
    out.parent.mkdir(parents=True, exist_ok=True)
    image.save(out)
    print(f"wrote {out} ({cols}x{rows} cells, {c} px per cell)")


if __name__ == "__main__":
    main()
