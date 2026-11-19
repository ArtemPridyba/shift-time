#!/usr/bin/env python3
"""Cut the heroine's 12 parts out of the Gemini sheet (task Д5, D77).

    python3 tools/cut_heroine_parts.py

Reads docs/art/heroine/character_parts_hq.jpg (a 2340x1080 phone screenshot of
the Gemini sheet: flat grey inside CROP_X)
and writes one PNG per part into game/assets/art/heroine/parts/, cropped to
the part with a 6 px margin, plus parts.json with each crop's place on the
sheet and its bake factor. The grey background goes by a flood fill from the sheet's border, so
grey inside a part (sleeves, metal) stays; the edge is unmixed from the grey
(`_unmix`), so hair strands lose the grey between them. The indicator strip of the
gauntlet (magenta on the sheet) is painted over with dark glass and saved as a
white mask, gauntlet_strip.png, that the game tints with the time colour (D76).
Each picture is shrunk with Lanczos to its size in the game (`scale` and the
part's `size` in game/data/heroine.json), so the game draws it 1:1 and sharp:
run the script again after changing those numbers. The parts at sheet size go
to parts/full/ for the showcase that checks the joints up close. Needs only Pillow and numpy.
"""
from __future__ import annotations

import json
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SHEET = ROOT / "docs/art/heroine/character_parts_hq.jpg"
# The grey sheet inside the phone screenshot (the dark bands at the sides go).
CROP_X = (210, 2128)
OUT = ROOT / "game/assets/art/heroine/parts"
# The same parts at sheet size, only for the showcase (not exported).
FULL = OUT / "full"
DATA = ROOT / "game/data/heroine.json"

BG = 128.0
# Sum of |RGB - grey| below this joins the background flood.
FLOOD = 22
# How far from the background the edge is unmixed, in pixels.
EDGE_REACH = 6
# Grey this close (sum of |RGB - grey|) inside a part is background.
ENCLOSED = 14
# Below this distance from grey a colour is grey-ish (metal, the sleeves).
GREYISH = 40.0
# Unsharp mask on the pictures shrunk for the game (percent, radius in px).
SHARPEN = 50
SHARPEN_RADIUS = 0.8
# The colour of the drawing's dark lines and hair.
INK = (24, 21, 20)
# A pixel this far from grey is a pure colour even at the very edge.
PURE = 260.0
# Edge alpha below this goes clear, above 1 - this goes solid.
SPECK = 0.2
MARGIN = 6
# How magenta (min of R-G and B-G) a pixel of the strip is at full strength.
STRIP_FULL = 120.0
MIN_PIXELS = 3000

# Parts by the centre of their box on the sheet, left to right, top to bottom.
NAMES = [
    ((221, 208), "head"),
    ((556, 213), "helmet"),
    ((847, 209), "respirator"),
    ((1168, 225), "torso"),
    ((1561, 243), "pelvis"),
    ((184, 580), "sleeve_far"),
    ((651, 587), "sleeve_near"),
    ((1149, 646), "thigh"),
    ((1442, 746), "shin"),
    ((424, 747), "gauntlet"),
    ((886, 741), "forearm_far"),
    ((1700, 712), "battery"),
]


def _components(mask: np.ndarray) -> list[tuple[int, int, int, int, int]]:
    h, w = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    boxes = []
    for y in range(h):
        for x in range(w):
            if not mask[y, x] or seen[y, x]:
                continue
            queue = deque([(y, x)])
            seen[y, x] = True
            count, y0, y1, x0, x1 = 0, y, y, x, x
            while queue:
                cy, cx = queue.popleft()
                count += 1
                y0, y1, x0, x1 = min(y0, cy), max(y1, cy), min(x0, cx), max(x1, cx)
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            queue.append((ny, nx))
            if count >= MIN_PIXELS:
                boxes.append((count, x0, y0, x1, y1))
    return boxes


def _background(dist: np.ndarray) -> np.ndarray:
    """Grey pixels reachable from the sheet's border."""
    h, w = dist.shape
    bg = np.zeros((h, w), dtype=bool)
    queue = deque()
    for y in range(h):
        for x in (0, w - 1):
            queue.append((y, x))
    for x in range(w):
        for y in (0, h - 1):
            queue.append((y, x))
    while queue:
        y, x = queue.popleft()
        if bg[y, x] or dist[y, x] > FLOOD:
            continue
        bg[y, x] = True
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < h and 0 <= nx < w and not bg[ny, nx]:
                queue.append((ny, nx))
    return bg


def _unmix(sheet: np.ndarray, dist: np.ndarray, clear: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Alpha and colour of every pixel: the edge is unmixed from the grey.

    A pixel near the background is taken as c = a * F + (1 - a) * grey, where F
    is the colour of a less grey pixel around it. Of those, F is the one that
    explains c best (c lies closest to the line from grey to F): a hair strand
    for a pixel between strands, the skin for the edge of the face. So thin
    strands keep their colour and lose the grey between them, and the light
    JPG ringing goes clear.
    """
    h, w = dist.shape
    grey = np.full(3, BG)
    off = sheet - grey
    near = np.zeros((h, w), dtype=bool)
    best_error = np.full((h, w), np.inf)
    best_alpha = np.ones((h, w))
    best_colour = sheet.copy()
    # A colour to unmix towards must be a pure one: inside the part (two pixels
    # from the background) or strongly coloured (a dark hair strand).
    inner = np.zeros((h, w), dtype=bool)
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            inner |= np.roll(np.roll(clear, dy, axis=0), dx, axis=1)
    pure = (~inner | (dist > PURE)) & ~clear
    solid = np.where(pure, dist, -1.0)
    for dy in range(-EDGE_REACH, EDGE_REACH + 1):
        for dx in range(-EDGE_REACH, EDGE_REACH + 1):
            near |= np.roll(np.roll(clear, dy, axis=0), dx, axis=1)
            if dy == 0 and dx == 0:
                continue
            other = np.roll(np.roll(solid, dy, axis=0), dx, axis=1)
            colour = np.roll(np.roll(sheet, dy, axis=0), dx, axis=1)
            towards = colour - grey
            length = (towards**2).sum(axis=2)
            usable = (other > dist) & (length > GREYISH**2)
            alpha = np.clip((off * towards).sum(axis=2) / np.maximum(length, 1.0), 0.0, 1.0)
            error = ((off - alpha[..., None] * towards) ** 2).sum(axis=2)
            better = usable & (error < best_error)
            best_error = np.where(better, error, best_error)
            best_alpha = np.where(better, alpha, best_alpha)
            best_colour[better] = colour[better]
    edge = near & ~clear
    # Where no pure colour is near (the faint tip of a loose strand), the pixel
    # is unmixed towards dark ink; lighter than the grey, it is JPG ringing.
    found = np.isfinite(best_error)
    ink = np.array(INK, dtype=np.float64) - grey
    ink_alpha = np.clip((off * ink).sum(axis=2) / (ink**2).sum(), 0.0, 1.0)
    lost = edge & ~found
    best_colour[lost] = INK
    edge_alpha = np.where(found, best_alpha, ink_alpha)
    found = found | lost
    # JPG noise leaves faint specks and nearly solid edge pixels: snap them.
    edge_alpha = np.where(edge_alpha < SPECK, 0.0, np.where(edge_alpha > 1.0 - SPECK, 1.0, edge_alpha))
    alpha = np.where(clear, 0.0, np.where(edge, edge_alpha, 1.0))
    unmixed = np.clip(grey + off / np.maximum(alpha, 0.05)[..., None], 0, 255)
    colour = np.where((edge & found)[..., None], 0.5 * unmixed + 0.5 * best_colour, sheet)
    return alpha, colour


def _cut_strip(rgba: np.ndarray) -> tuple[np.ndarray, list[int]]:
    """Takes the magenta strip and its glow off the gauntlet.

    Returns a white mask of the strip (its alpha is how strongly a pixel was
    magenta) and the strip's box; the gauntlet gets dark glass in its place.
    """
    rgb = rgba[..., :3]
    r, g, b = (rgb[..., i].astype(np.float64) for i in range(3))
    solid = rgba[..., 3] > 200
    pink = np.minimum(r - g, b - g)
    magenta = (pink > 60) & solid
    tint = (pink > 8) & solid
    ys, xs = np.nonzero(magenta)
    box = [int(xs.min()), int(ys.min()), int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1)]
    mask = np.zeros(rgba.shape, dtype=np.uint8)
    mask[..., :3] = 255
    mask[..., 3] = np.where(tint, np.clip((pink - 8) / (STRIP_FULL - 8), 0, 1) * 255, 0).astype(np.uint8)
    grey = rgb[tint].astype(np.float64).mean(axis=1, keepdims=True)
    rgb[tint] = np.clip(grey * 0.6, 0, 255)
    rgb[magenta] = (24, 26, 30)
    return mask, box


def _bake(rgba: np.ndarray, factor: float) -> Image.Image:
    """Shrinks a part to its size in the game: Lanczos on premultiplied colour."""
    a = rgba[..., 3:4].astype(np.float64) / 255.0
    pre = np.dstack([rgba[..., :3] * a, a * 255.0]).astype(np.float32)
    size = (max(1, round(rgba.shape[1] * factor)), max(1, round(rgba.shape[0] * factor)))
    bands = [Image.fromarray(pre[..., i], "F").resize(size, Image.LANCZOS) for i in range(4)]
    out = np.dstack([np.asarray(band) for band in bands])
    alpha = np.clip(out[..., 3], 0, 255)
    colour = np.where(alpha[..., None] > 0.5, out[..., :3] / np.maximum(alpha[..., None], 1e-3) * 255.0, 0)
    colour = np.clip(colour, 0, 255)
    if SHARPEN > 0:
        # The sheet is a soft JPG: give the small picture back some crispness.
        rgb = Image.fromarray(colour.round().astype(np.uint8), "RGB")
        rgb = rgb.filter(ImageFilter.UnsharpMask(radius=SHARPEN_RADIUS, percent=SHARPEN, threshold=1))
        colour = np.where(alpha[..., None] > 0.5, np.asarray(rgb).astype(np.float64), colour)
    baked = np.dstack([colour, alpha]).round().astype(np.uint8)
    return Image.fromarray(baked, "RGBA")


def _bake_factors() -> dict[str, float]:
    """Game pixels per sheet pixel of each picture, from data/heroine.json."""
    data = json.loads(DATA.read_text())
    factors: dict[str, float] = {}
    for part in data["parts"].values():
        factor = float(data["scale"]) * float(part.get("size", 1.0))
        factors[part["texture"]] = max(factors.get(part["texture"], 0.0), factor)
    return factors


def main() -> None:
    sheet = np.asarray(Image.open(SHEET).convert("RGB")).astype(np.float64)[:, CROP_X[0] : CROP_X[1]]
    dist = np.abs(sheet - BG).sum(axis=2)
    bg = _background(dist)
    # Pure grey shut inside a part (between hair strands, in the helmet's
    # strap) is background too.
    clear = bg | (dist < ENCLOSED)
    alpha, colour = _unmix(sheet, dist, clear)
    rgba = np.dstack([colour, alpha * 255.0]).round().astype(np.uint8)

    boxes = _components(alpha > 0.5)
    if len(boxes) != len(NAMES):
        raise SystemExit(f"expected {len(NAMES)} parts, found {len(boxes)}")
    FULL.mkdir(parents=True, exist_ok=True)
    info: dict[str, dict] = {}
    factors = _bake_factors()
    h, w = dist.shape
    for (cx, cy), name in NAMES:
        _, x0, y0, x1, y1 = min(
            boxes, key=lambda b: ((b[1] + b[3]) / 2 - cx) ** 2 + ((b[2] + b[4]) / 2 - cy) ** 2
        )
        x0, y0 = max(0, x0 - MARGIN), max(0, y0 - MARGIN)
        x1, y1 = min(w - 1, x1 + MARGIN), min(h - 1, y1 + MARGIN)
        crop = rgba[y0 : y1 + 1, x0 : x1 + 1].copy()
        factor = factors[name]
        entry = {"sheet_rect": [x0, y0, x1 - x0 + 1, y1 - y0 + 1], "bake": factor}
        if name == "gauntlet":
            mask, entry["strip_rect"] = _cut_strip(crop)
            _bake(mask, factor).save(OUT / "gauntlet_strip.png", optimize=True)
            Image.fromarray(mask, "RGBA").save(FULL / "gauntlet_strip.png", optimize=True)
        _bake(crop, factor).save(OUT / f"{name}.png", optimize=True)
        Image.fromarray(crop, "RGBA").save(FULL / f"{name}.png", optimize=True)
        info[name] = entry
    (OUT / "parts.json").write_text(json.dumps(info, indent="\t") + "\n")
    print(f"{len(info)} parts -> {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
