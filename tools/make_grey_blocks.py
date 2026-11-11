#!/usr/bin/env python3
"""Draws the grey block set for levels: game/art/blocks/grey_blocks.png.

Three 64 px tiles in one row, silhouette style, no texture:
  0 block   - the plain blockout block (same colors as levels/blockout/gray_block.png)
  1 surface - a block with a light edge on top, for floors and platform tops
  2 hatch   - a darker block with diagonal strokes, for the body of the ground

Run from the repository root:  python3 tools/make_grey_blocks.py
The colors are placeholders: the final look comes with the chosen style (K2-K4).
"""
from pathlib import Path

from PIL import Image, ImageDraw

TILE = 64
FILL = (61, 67, 75, 255)
BORDER = (89, 96, 107, 255)
EDGE = (174, 182, 194, 255)
HATCH_FILL = (52, 58, 65, 255)
HATCH_LINE = (66, 73, 82, 255)
OUT = Path(__file__).resolve().parent.parent / "game" / "art" / "blocks" / "grey_blocks.png"


def block(draw: ImageDraw.ImageDraw, x: int, fill: tuple) -> None:
    draw.rectangle([x, 0, x + TILE - 1, TILE - 1], fill=fill, outline=BORDER)


def main() -> None:
    image = Image.new("RGBA", (TILE * 3, TILE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    block(draw, 0, FILL)
    block(draw, TILE, FILL)
    draw.rectangle([TILE + 1, 1, TILE * 2 - 2, 4], fill=EDGE)
    hatch = Image.new("RGBA", (TILE, TILE), HATCH_FILL)
    hatch_draw = ImageDraw.Draw(hatch)
    for offset in range(-TILE, TILE, 10):
        hatch_draw.line([offset, TILE, offset + TILE, 0], fill=HATCH_LINE, width=2)
    hatch_draw.rectangle([0, 0, TILE - 1, TILE - 1], outline=BORDER)
    image.paste(hatch, (TILE * 2, 0))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
