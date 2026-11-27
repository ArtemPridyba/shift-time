#!/usr/bin/env python3
"""Cover image of the itch.io page (task И1, 27.11.2026, D204): 630x500 from a
1920x1080 frame of the game (docs/itch/shots/, made by tools/itch_media.sh),
cut around the heroine, darkened at the bottom, with the game's name and one
line under it. Code, not a drawing, so it is remade in one line after the
frame changes:

    python3 tools/itch_cover.py                      # defaults below
    python3 tools/itch_cover.py --frame docs/itch/shots/level_03.jpg --center 0.55 --zoom 1

The font is DejaVu Sans Bold (free licence, commercial use allowed), or the
one given with --font. Output: docs/itch/cover.png (under 3 MB, the itch cap).
"""
import argparse
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIZE = (630, 500)
FONTS = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
    "/Library/Fonts/Arial Bold.ttf",
    "C:/Windows/Fonts/arialbd.ttf",
]
# The warm light of the lamps for the name; the time colour (cyan) belongs to
# the heroine only (D60), so it stays out of the letters.
TITLE_COLOR = (244, 226, 196)
LINE_COLOR = (214, 196, 170)


def parse():
    p = argparse.ArgumentParser()
    p.add_argument("--frame", default=os.path.join(ROOT, "docs/itch/shots/level_01.jpg"))
    p.add_argument("--out", default=os.path.join(ROOT, "docs/itch/cover.png"))
    p.add_argument("--center", type=float, default=0.6, help="x of the cut's centre, 0..1 of the frame width")
    p.add_argument("--zoom", type=float, default=1.3, help="1 = the full height of the frame; more = closer")
    p.add_argument("--middle", type=float, default=0.8, help="y of the cut's centre, 0..1 of the frame height")
    p.add_argument("--title", default="SHIFT TIME")
    p.add_argument("--line", default="Hold Shift. The world goes back. You don't.")
    p.add_argument("--font", default="")
    return p.parse_args()


def font(path, size):
    for candidate in ([path] if path else []) + FONTS:
        if candidate and os.path.exists(candidate):
            return ImageFont.truetype(candidate, size)
    raise SystemExit("no font found: give --font PATH to a .ttf")


def cut(frame, center, middle, zoom):
    """A 630:500 piece of the frame around (center, middle): the largest one at
    zoom 1, a zoom times smaller one closer."""
    w, h = frame.size
    ratio = SIZE[0] / SIZE[1]
    cw, ch = (round(h * ratio), h) if w / h > ratio else (w, round(w / ratio))
    cw, ch = round(cw / max(zoom, 1.0)), round(ch / max(zoom, 1.0))
    left = min(max(round(center * w - cw / 2), 0), w - cw)
    top = min(max(round(middle * h - ch / 2), 0), h - ch)
    return frame.crop((left, top, left + cw, top + ch)).resize(SIZE, Image.LANCZOS)


def shade(image):
    """Darkens the lower part, where the name stands, so it reads on any frame."""
    w, h = image.size
    mask = Image.new("L", (1, h))
    start = int(h * 0.52)
    for y in range(h):
        mask.putpixel((0, y), 0 if y < start else int(210 * ((y - start) / (h - start)) ** 1.2))
    black = Image.new("RGB", image.size, (8, 6, 6))
    return Image.composite(black, image, mask.resize(image.size))


def text_centered(image, y, text, face, color, glow):
    """Text centred at height y with a soft dark halo behind it."""
    draw = ImageDraw.Draw(image)
    box = draw.textbbox((0, 0), text, font=face)
    x = (image.width - (box[2] - box[0])) // 2 - box[0]
    halo = Image.new("L", image.size, 0)
    ImageDraw.Draw(halo).text((x, y), text, font=face, fill=255)
    halo = halo.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(glow))
    image.paste((0, 0, 0), (0, 0), halo.point(lambda v: int(v * 0.8)))
    draw.text((x, y), text, font=face, fill=color)
    return box[3] - box[1]


def fit(text, path, size, width):
    """The font at the largest size up to `size` that keeps the text within width."""
    while size > 10:
        face = font(path, size)
        box = ImageDraw.Draw(Image.new("L", (1, 1))).textbbox((0, 0), text, font=face)
        if box[2] - box[0] <= width:
            return face
        size -= 2
    return font(path, size)


def main():
    args = parse()
    image = shade(cut(Image.open(args.frame).convert("RGB"), args.center, args.middle, args.zoom))
    title = fit(args.title, args.font, 86, SIZE[0] - 60)
    line = fit(args.line, args.font, 22, SIZE[0] - 60)
    y = SIZE[1] - 150
    height = text_centered(image, y, args.title, title, TITLE_COLOR, 6)
    text_centered(image, y + height + 26, args.line, line, LINE_COLOR, 3)
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    image.save(args.out, optimize=True)
    size = os.path.getsize(args.out)
    print(f"cover: {os.path.relpath(args.out, ROOT)} {image.size[0]}x{image.size[1]}, {size // 1024} KB")
    if size > 3 * 1024 * 1024:
        raise SystemExit("the cover is over 3 MB")


if __name__ == "__main__":
    main()
