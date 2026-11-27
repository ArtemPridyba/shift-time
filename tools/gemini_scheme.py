#!/usr/bin/env python3
"""Numbered layout schemes of the levels for the Gemini room prompts (D199).

The pattern is the scheme of level 01 (docs/art/level01_layout_clean.png,
prompt F-1 v2 in docs/art/gemini-kit.md): flat colour zones built from the
level's own data, so the picture Gemini paints over it lies on the collision.

    python3 tools/gemini_scheme.py level_03     # one level
    python3 tools/gemini_scheme.py all          # every level in ITEMS
    python3 tools/gemini_scheme.py level_03 --check docs/art/gemini/raw/g03_room_v1.jpg
    python3 tools/gemini_scheme.py level_02 --check raw/g02_room_p2_v1.jpg --part 2
        -> build/backdrop/level_03_part1_check.jpg: the picture stretched over
           its rect with the lines and numbers of the scheme on top; a good
           picture has its floors on the cyan lines within half a cell

Writes into docs/art/gemini/:
    levelNN_scheme.png          the whole room with numbers (for people and the
                                prompt's list of numbers)
    levelNN_clean.png           one-screen level: the same without numbers
    levelNN_partK_scheme.png    a room wider than 16:9 is cut into screen-wide
    levelNN_partK_clean.png     parts with 2 cells of overlap; each part is one
                                Gemini picture
and prints the rect of every picture in cells, [x, y, w, h], the value for
`rect` of world.backdrop once the game lays the picture.

Colours: dark brown = the open hall, darker = the roof above `ceiling`,
grey = solid masonry, cyan lines = tops of floors (the walking surface),
green line = a flight or slope, magenta = an empty dark doorway, orange
outline = the game draws a moving thing here (paint only the back wall),
blue outline = water (the game draws it; paint a dry basin), yellow dot =
a lamp bulb (paint only its cone), white circle = a number of the prompt.

Geometry comes from game/levels/<level>.tscn (tiles, Stairs*, Rails, Pipe)
and game/data/levels.json (ceiling, lamps). The numbered things are listed
in ITEMS below from the level cards (docs/levels/NN.md); after a level is
rebuilt, check them against its card and run the script again.
"""
import base64
import json
import math
import re
import struct
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "art" / "gemini"
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
CELL = 64
OVERLAP = 2.0

HALL = (28, 22, 20)
ROOF = (40, 34, 32)
SOLID = (95, 90, 88)
CYAN = (0, 255, 255)
GREEN = (80, 255, 80)
MAGENTA = (255, 0, 220)
ORANGE = (255, 140, 0)
BLUE = (60, 140, 255)
LAMP = (255, 210, 120)

# Numbered things per level, in cells. Kinds:
#   open  [x, y, w, h]   an empty dark doorway
#   leave [x, y, w, h]   the game draws a moving or used thing here
#   water [x, y, w, h]   a water volume (the game draws the water)
#   solid [x, y, w, h]   solid made by a node, not by tiles (drawn grey)
#   note  [x, y]         only a number on the scheme
#   rails / pipe         a polyline of the scene's Rails or Pipe node
#   line  [[x, y], ...]  a polyline in cells (a path the game draws)
ITEMS = {
    "level_03": [
        ("open", [1, 11, 1, 2]),                 # 1 entrance
        ("leave", [3.8, 5.3, 1.4, 1.4]),         # 2 winch drum and chain
        ("leave", [9, 12.75, 5.8, 0.3]),         # 3 the ramp (bridge / upright)
        ("note", [11.5, 15.0]),                  # 4 the pit, open to the bottom
        ("leave", [15, 9.9, 2, 3.4]),            # 5 the lift on its rack
        ("solid", [17, 10, 8, 0.375]),           # 6 the steel mezzanine
        ("leave", [17.1, 8.4, 1.0, 1.6]),        # 7 gas burner with the torch
        ("leave", [18.5, 4.3, 3.5, 0.9]),        # 8 fire detector and sprinklers
        ("leave", [23.9, 8.4, 0.7, 0.7]),        # 9 bollard of the cage's thread
        ("leave", [25, 7, 2, 6]),                # 10 the cage in its shaft
        ("open", [27.1, 5, 1.8, 2]),             # 11 exit door on the gallery
    ],
    "level_02": [
        ("open", [1, 7, 1, 2]),                  # 1 entrance
        ("leave", [3.1, 8.5, 0.8, 0.5]),         # 2 button 1
        ("water", [5, 9, 9, 3]),                 # 3 pool 1
        ("leave", [10.5, 8.75, 3, 0.5]),         # 4 float 1
        ("leave", [14, 10, 0.5, 2]),             # 5 the sluice
        ("water", [16, 12, 10, 3]),              # 6 pool 2
        ("leave", [20.1, 14.5, 0.8, 0.5]),       # 7 the yellow valve wheel on the bottom
        ("leave", [22.5, 11.75, 3, 0.5]),        # 8 float 2
        ("pipe", None),                          # 9 the pipe with the open flange
        ("water", [32, 12, 4, 3]),               # 10 the sump
        ("leave", [36, 11, 1, 4]),               # 11 the sump's door
        ("leave", [43.1, 11.5, 0.8, 0.5]),       # 12 button 2
        ("leave", [45, 10, 1, 2]),               # 13 the tunnel's entry gate
        ("leave", [46, 5.2, 10, 3.8]),           # 14 the pump room
        ("water", [46, 12, 18, 2]),              # 15 the tunnel
        ("leave", [64, 10, 1, 2]),               # 16 the tunnel's exit gate
        ("open", [66.1, 10, 1.8, 2]),            # 17 exit
    ],
    # Level 04 on one screen (Artem, PR #122, D216-D218; session 2 adds K, Z, the wall).
    "level_04": [
        ("open", [1, 5, 1, 2]),                  # 1 entrance
        ("leave", [16, 6.8, 3, 0.25]),           # 2 plate 2 over switch 2
        ("leave", [20, 6.8, 3, 0.25]),           # 3 plate 1 over switch 1
        ("leave", [25.3, 5.2, 0.6, 1.8]),        # 4 barrier at the end of the walkway
        ("leave", [24.6, 7.7, 2.6, 1.3]),        # 5 the minecart on its hump
        ("rails", None),                         # 6 rails, switches, dead ends
        ("leave", [10.2, 7, 2.6, 2.5]),          # 7 the hopper with pig iron
        ("leave", [7, 7.95, 19, 0.35]),          # 8 the hoist's line under the walkway
        ("note", [3.5, 10.5]),                   # 9 the tunnel and the station
        ("open", [1.1, 11, 1.8, 2]),             # 10 exit
        ("note", [8, 11.0]),                     # 11 place of plate K, gate Z, the wall (session 2)
        ("note", [12, 15.5]),                    # 12 the pit, open to the bottom
    ],
    # Level 05 on one screen (Artem, PR #121, D215).
    "level_05": [
        ("open", [1, 4, 1, 2]),                  # 1 entrance on the ledge
        ("leave", [6, 4.6, 3, 1.6]),             # 2 the crane waiting at the ledge
        ("line", [[6, 4], [28, 10.4]]),          # 3 the crane's sloping rail
        ("leave", [9.8, 5, 2.8, 2.4]),           # 4 the door and the slab on two chains
        ("leave", [15, 4.6, 2, 0.8]),            # 5 ceiling chunk 1
        ("leave", [18.5, 5.7, 2, 0.8]),          # 6 ceiling chunk 2
        ("leave", [22, 6.7, 2, 0.8]),            # 7 ceiling chunk 3
        ("leave", [25, 11.4, 3, 1.6]),           # 8 the crane at its end stop
        ("note", [15, 14.4]),                    # 9 the floor where the chunks lie
    ],
}


def vec_list(text: str) -> list:
    nums = [float(n) for n in re.findall(r"-?\d+(?:\.\d+)?", text)]
    return list(zip(nums[0::2], nums[1::2]))


def read_level(level: str) -> dict:
    text = (ROOT / "game" / "levels" / f"{level}.tscn").read_text(encoding="utf-8")
    raw = base64.b64decode(re.search(r'tile_map_data = PackedByteArray\("([^"]+)"\)', text).group(1))
    cells = {struct.unpack("<hh", raw[i:i + 4]) for i in range(2, len(raw) - 11, 12)}
    stairs, rails, pipe = [], [], []
    for block in re.split(r"\n(?=\[node )", text):
        name = re.match(r'\[node name="([^"]+)"', block)
        if not name:
            continue
        name = name.group(1)
        if name.startswith("Stairs"):
            rect = re.search(r"cells = Rect2i\((\d+), (\d+), (\d+), (\d+)\)", block)
            down_right = "descends_right = false" not in block
            if rect:
                stairs.append((tuple(int(n) for n in rect.groups()), down_right))
        if name == "Rails":
            for pts in re.findall(r"PackedVector2Array\(([^)]*)\)", block):
                rails.append(vec_list(pts))
        if name == "Pipe":
            pts = re.search(r"points = PackedVector2Array\(([^)]*)\)", block)
            if pts:
                pipe.append(vec_list(pts.group(1)))
    levels = json.loads((ROOT / "game" / "data" / "levels.json").read_text(encoding="utf-8"))
    entry = next(e for e in levels if isinstance(e, dict) and e.get("id") == level)
    cols = max(x for x, _ in cells) + 1
    rows = max(y for _, y in cells) + 1
    return {"cells": cells, "stairs": stairs, "rails": rails, "pipe": pipe,
            "world": entry.get("world", {}), "cols": cols, "rows": rows}


def draw_room(level: str, lv: dict, numbers: bool, base: Image.Image = None) -> Image.Image:
    """The scheme, or with `base` only its lines over that picture (the check)."""
    cols, rows, world = lv["cols"], lv["rows"], lv["world"]
    ceiling = int(world.get("ceiling", 0))
    over = base is not None
    im = base.copy() if over else Image.new("RGB", (cols * CELL, rows * CELL), HALL)
    d = ImageDraw.Draw(im, "RGBA")
    if not over:
        d.rectangle([0, 0, cols * CELL, ceiling * CELL], fill=ROOF)
    cells = lv["cells"]
    for (x, y) in cells:
        if y >= ceiling and not over:
            d.rectangle([x * CELL, y * CELL, x * CELL + CELL - 1, y * CELL + CELL - 1], fill=SOLID)
    items = ITEMS.get(level, [])
    for kind, geo in items:
        if kind == "solid" and not over:
            x, y, w, h = geo
            d.rectangle([x * CELL, y * CELL, (x + w) * CELL, (y + h) * CELL], fill=SOLID)
    for (x, y) in cells:
        if y > ceiling and (x, y - 1) not in cells:
            d.line([(x * CELL, y * CELL), (x * CELL + CELL, y * CELL)], fill=CYAN, width=6)
    for kind, geo in items:
        if kind == "solid":
            x, y, w, _ = geo
            d.line([(x * CELL, y * CELL), ((x + w) * CELL, y * CELL)], fill=CYAN, width=6)
    for (sx, sy, sw, sh), down_right in lv["stairs"]:
        x0, x1 = sx * CELL, (sx + sw) * CELL
        top, bottom = sy * CELL, (sy + sh) * CELL
        a, b = ((x0, top), (x1, bottom)) if down_right else ((x0, bottom), (x1, top))
        foot = (x0, bottom) if down_right else (x1, bottom)
        if not over:
            d.polygon([a, b, foot], fill=SOLID)
        d.line([a, b], fill=GREEN, width=8)
    for kind, geo in items:
        if kind in ("open", "leave", "water"):
            x, y, w, h = geo
            box = [x * CELL, y * CELL, (x + w) * CELL, (y + h) * CELL]
            if kind == "open":
                d.rectangle(box, fill=None if over else (8, 6, 6), outline=MAGENTA, width=6)
            elif kind == "leave":
                d.rectangle(box, outline=ORANGE, width=5)
            else:
                d.rectangle(box, fill=None if over else (60, 140, 255, 40), outline=BLUE, width=5)
        if kind in ("rails", "pipe"):
            for line in lv[kind]:
                d.line(line, fill=ORANGE, width=8)
        if kind == "line":
            d.line([(x * CELL, y * CELL) for x, y in geo], fill=ORANGE, width=8)
    for lamp in world.get("lamps", []):
        cx, cy = float(lamp["x"]) * CELL, (ceiling + float(lamp["drop"])) * CELL
        d.line([(cx, ceiling * CELL), (cx, cy)], fill=LAMP, width=2)
        d.ellipse([cx - 10, cy - 10, cx + 10, cy + 10], fill=LAMP)
    if numbers:
        font = ImageFont.truetype(FONT, 30)
        for n, (kind, geo) in enumerate(items, 1):
            if kind in ("rails", "pipe"):
                line = lv[kind][0] if lv[kind] else [(0, 0)]
                px, py = line[len(line) // 2]
                px, py = px, py - 40
            elif kind == "line":
                (ax, ay), (bx, by) = geo[0], geo[-1]
                px, py = (ax + bx) / 2 * CELL, (ay + by) / 2 * CELL - 40
            elif kind == "note":
                px, py = geo[0] * CELL, geo[1] * CELL
            else:
                x, y, w, h = geo
                px, py = (x + w / 2) * CELL, y * CELL - 30
                if py < 30:
                    py = (y + h / 2) * CELL
            r = 24
            d.ellipse([px - r, py - r, px + r, py + r], fill=(255, 255, 255), outline=(0, 0, 0), width=3)
            d.text((px, py), str(n), font=font, fill=(0, 0, 0), anchor="mm")
    return im


def parts_of(cols: int, rows: int) -> list:
    """Rects in cells of 16:9 pictures that cover the room."""
    width = rows * 16 / 9
    if cols <= width + 0.01:
        width = max(cols, width)
        return [(0.0, 0.0, width, width * 9 / 16)]
    count = math.ceil((cols - OVERLAP) / (width - OVERLAP))
    step = (cols - width) / (count - 1)
    return [(round(i * step, 2), 0.0, round(width, 2), float(rows)) for i in range(count)]


def crop(room: Image.Image, rect: tuple) -> Image.Image:
    x, y, w, h = rect
    canvas = Image.new("RGB", (round(w * CELL), round(h * CELL)), SOLID)
    canvas.paste(room, (-round(x * CELL), -round(y * CELL)))
    return canvas.resize((1920, 1080), Image.LANCZOS)


def build(level: str) -> None:
    lv = read_level(level)
    short = level.replace("_", "")
    numbered, clean = draw_room(level, lv, True), draw_room(level, lv, False)
    parts = parts_of(lv["cols"], lv["rows"])
    OUT.mkdir(parents=True, exist_ok=True)
    whole = numbered.resize((1920, round(1920 * numbered.height / numbered.width)), Image.LANCZOS)
    whole.save(OUT / f"{short}_scheme.png")
    print(f"{level}: {lv['cols']}x{lv['rows']} cells -> {short}_scheme.png")
    if len(parts) == 1:
        crop(clean, parts[0]).save(OUT / f"{short}_clean.png")
        print(f"  {short}_clean.png  rect {list(parts[0])}")
        return
    for k, rect in enumerate(parts, 1):
        crop(numbered, rect).save(OUT / f"{short}_part{k}_scheme.png")
        crop(clean, rect).save(OUT / f"{short}_part{k}_clean.png")
        print(f"  {short}_part{k}_scheme.png / _clean.png  rect {list(rect)}")


def check(level: str, picture: str, part: int) -> None:
    """Stretch a Gemini picture over its rect and draw the geometry on it."""
    lv = read_level(level)
    rect = parts_of(lv["cols"], lv["rows"])[part - 1]
    x, y, w, h = rect
    room = Image.new("RGB", (lv["cols"] * CELL, lv["rows"] * CELL), SOLID)
    pic = Image.open(picture).convert("RGB").resize((round(w * CELL), round(h * CELL)), Image.LANCZOS)
    room.paste(pic, (round(x * CELL), round(y * CELL)))
    lined = draw_room(level, lv, True, base=room)
    lined = lined.crop((round(x * CELL), round(y * CELL), round((x + w) * CELL), round((y + h) * CELL)))
    out = ROOT / "build" / "backdrop" / f"{level}_part{part}_check.jpg"
    out.parent.mkdir(parents=True, exist_ok=True)
    lined.resize((1920, round(1920 * lined.height / lined.width)), Image.LANCZOS).save(out, quality=85)
    print(out)


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    if len(sys.argv) >= 4 and sys.argv[2] == "--check":
        part = int(sys.argv[5]) if len(sys.argv) >= 6 and sys.argv[4] == "--part" else 1
        check(sys.argv[1], sys.argv[3], part)
        return
    for level in (ITEMS if sys.argv[1] == "all" else [sys.argv[1]]):
        build(level)


if __name__ == "__main__":
    main()
