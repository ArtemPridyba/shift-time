#!/usr/bin/env python3
"""Lay a Gemini picture of a whole room over the level's geometry (D131).

    python3 tools/check_backdrop.py level_01 docs/art/gemini/raw/f1_room_v1.jpg
        -> build/backdrop/level_01_check.jpg: the picture stretched over the
           room, with the collision drawn on it: cyan = tops of floors and
           ledges, green = the stairs, magenta = doorways and the gate gap,
           orange = paths of moving platforms (must stay empty), yellow
           circles = lamp bulbs. A good picture has its floors, stairs and
           ledge right on these lines.
    python3 tools/check_backdrop.py level_01 --layout
        -> docs/art/level01_layout_clean.png: the same shapes with no text, the
           picture to attach to the Gemini prompt F-1.

The picture is 16:9 and covers the room's width; the room (32x17 cells of 64
px) fills its top 1088 of 1152 px. In the game the picture may lie higher
(`rect` y of world.backdrop; level 01: 22 px, D150) so that the middle of a
painted top face, not its back edge, is on the cyan line. Reads the tile map and the nodes of
game/levels/<level>.tscn and the lamps of the level in game/data/levels.json.
"""
import base64
import json
import re
import struct
import sys
from pathlib import Path

from PIL import Image, ImageDraw

CELL = 64
W, H = 2048, 1152


def read_level(level: str) -> dict:
    text = Path(f"game/levels/{level}.tscn").read_text()
    data = base64.b64decode(re.search(r'tile_map_data = PackedByteArray\("([^"]+)"\)', text).group(1))
    cells = {struct.unpack("<hh", data[i:i + 4]) for i in range(2, len(data) - 11, 12)}
    nodes = {}
    for block in re.split(r"\n(?=\[node )", text):
        name = re.match(r'\[node name="([^"]+)"', block)
        if not name:
            continue
        props = dict(re.findall(r"^(\w+) = (.+)$", block, re.M))
        nodes[name.group(1)] = props
    levels = json.loads(Path("game/data/levels.json").read_text())
    entry = next(e for e in levels if isinstance(e, dict) and e.get("id") == level)
    return {"cells": cells, "nodes": nodes, "world": entry.get("world", {})}


def vec(text: str) -> tuple:
    inside = text[text.find("(") + 1:] if "(" in text else text
    nums = [float(n) for n in re.findall(r"-?\d+(?:\.\d+)?", inside)]
    return tuple(nums)


def draw_geometry(d: ImageDraw.ImageDraw, level: dict, solid=None, width=5) -> None:
    cells, nodes, world = level["cells"], level["nodes"], level["world"]
    ceiling = int(world.get("ceiling", 0))
    if solid:
        for (x, y) in cells:
            if y >= ceiling:
                d.rectangle([x * CELL, y * CELL, x * CELL + CELL - 1, y * CELL + CELL - 1], fill=solid)
        d.rectangle([0, 17 * CELL, W, H], fill=solid)
    stairs = nodes.get("Stairs")
    if stairs:
        sx, sy, sw, sh = vec(stairs["cells"])
        a, b = (sx * CELL, sy * CELL), ((sx + sw) * CELL, (sy + sh) * CELL)
        if solid:
            d.polygon([a, b, (a[0], b[1])], fill=solid)
        d.line([a, b], fill=(80, 255, 80, 255), width=width + 2)
    # Tops of floors: a solid cell with open space above it.
    for (x, y) in cells:
        if y > ceiling and (x, y - 1) not in cells:
            d.line([(x * CELL, y * CELL), (x * CELL + CELL, y * CELL)], fill=(0, 255, 255, 255), width=width)
        if y >= ceiling and (x - 1, y) not in cells and x > 0:
            d.line([(x * CELL, y * CELL), (x * CELL, y * CELL + CELL)], fill=(0, 255, 255, 160), width=2)
    for name, props in nodes.items():
        if "travel" in props and "width" in props:
            cx, cy = vec(props["position"])
            tx, ty = vec(props["travel"])
            half = float(props["width"]) / 2.0
            d.rectangle([min(cx, cx + tx) - half, min(cy, cy + ty) - 8, max(cx, cx + tx) + half, max(cy, cy + ty) + 8],
                        outline=(255, 140, 0, 255), width=width - 1)
    door = nodes.get("Door")
    if door:
        x, y = vec(door["position"])
        d.rectangle([x - 32, y - 64, x + 32, y + 64], outline=(255, 0, 220, 255), width=width)
    entrance = nodes.get("Entrance")
    if entrance:
        x, y = vec(entrance["position"])
        d.rectangle([x, y, x + CELL, y + 2 * CELL], outline=(255, 0, 220, 255), width=width)
    exit_node = nodes.get("Exit")
    if exit_node:
        x, y = vec(exit_node["position"])
        d.rectangle([x - 56, y - 64, x + 56, y + 64], outline=(255, 0, 220, 255), width=width)
    for lamp in world.get("lamps", []):
        cx, cy = float(lamp["x"]) * CELL, (ceiling + float(lamp["drop"])) * CELL
        if solid:
            d.line([(cx, ceiling * CELL), (cx, cy)], fill=(255, 210, 120, 255), width=2)
            d.ellipse([cx - 10, cy - 10, cx + 10, cy + 10], fill=(255, 210, 120, 255))
        else:
            d.ellipse([cx - 14, cy - 14, cx + 14, cy + 14], outline=(255, 255, 0, 255), width=4)


def main() -> None:
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    level = read_level(sys.argv[1])
    if sys.argv[2] == "--layout":
        im = Image.new("RGB", (W, H), (28, 22, 20))
        d = ImageDraw.Draw(im, "RGBA")
        d.rectangle([0, 0, W, int(level["world"].get("ceiling", 0)) * CELL], fill=(40, 34, 32))
        draw_geometry(d, level, solid=(95, 90, 88, 255), width=6)
        out = Path(f"docs/art/{sys.argv[1].replace('_', '')}_layout_clean.png")
        im.save(out)
    else:
        im = Image.open(sys.argv[2]).convert("RGB").resize((W, H))
        draw_geometry(ImageDraw.Draw(im, "RGBA"), level)
        out = Path(f"build/backdrop/{sys.argv[1]}_check.jpg")
        out.parent.mkdir(parents=True, exist_ok=True)
        im.resize((W // 2, H // 2)).save(out, quality=85)
    print(out)


if __name__ == "__main__":
    main()
