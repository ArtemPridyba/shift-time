#!/usr/bin/env python3
"""Cut the heroine's 12 parts out of the Gemini sheet (task Д5, D77).

    python3 tools/cut_heroine_parts.py

Reads docs/art/heroine/character_parts.jpg (512x286, flat grey background)
and writes one PNG per part into game/assets/art/heroine/parts/, cropped to
the part with a 2 px margin, plus parts.json with each crop's place on the
sheet and its bake factor. The grey background goes by a flood fill from the sheet's border, so
grey inside a part (sleeves, metal) stays; the edge gets a soft alpha and takes
its colour from inside the part. The indicator strip of the
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
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SHEET = ROOT / "docs/art/heroine/character_parts.jpg"
OUT = ROOT / "game/assets/art/heroine/parts"
# The same parts at sheet size, only for the showcase (not exported).
FULL = OUT / "full"
DATA = ROOT / "game/data/heroine.json"

BG = 128.0
# Sum of |RGB - grey| below this joins the background flood.
FLOOD = 22
# Soft edge: alpha grows from 0 to 1 over this range of the same distance.
EDGE_LO = 8.0
EDGE_HI = 48.0
# How far into the part the edge looks for its colour.
RING_REACH = 3
MARGIN = 2
# How magenta (min of R-G and B-G) a pixel of the strip is at full strength.
STRIP_FULL = 120.0
MIN_PIXELS = 300

# Parts by the centre of their box on the sheet, left to right, top to bottom.
NAMES = [
    ((59, 55), "head"),
    ((149, 56), "helmet"),
    ((226, 55), "respirator"),
    ((311, 60), "torso"),
    ((414, 64), "pelvis"),
    ((50, 153), "sleeve_far"),
    ((173, 155), "sleeve_near"),
    ((306, 171), "thigh"),
    ((383, 198), "shin"),
    ((114, 198), "gauntlet"),
    ((236, 196), "forearm_far"),
    ((451, 188), "battery"),
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


def _shrink(mask: np.ndarray, steps: int) -> np.ndarray:
    for _ in range(steps):
        out = mask.copy()
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            out &= np.roll(np.roll(mask, dy, axis=0), dx, axis=1)
        mask = out
    return mask


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
    tint = (pink > 18) & solid
    ys, xs = np.nonzero(magenta)
    box = [int(xs.min()), int(ys.min()), int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1)]
    mask = np.zeros(rgba.shape, dtype=np.uint8)
    mask[..., :3] = 255
    mask[..., 3] = np.where(tint, np.clip((pink - 18) / (STRIP_FULL - 18), 0, 1) * 255, 0).astype(np.uint8)
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
    baked = np.dstack([np.clip(colour, 0, 255), alpha]).round().astype(np.uint8)
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
    sheet = np.asarray(Image.open(SHEET).convert("RGB")).astype(np.float64)
    dist = np.abs(sheet - BG).sum(axis=2)
    bg = _background(dist)
    alpha = np.where(bg, np.clip((dist - EDGE_LO) / (EDGE_HI - EDGE_LO), 0.0, 1.0), 1.0)
    # Background pixels far from any part stay fully clear.
    near = np.zeros_like(bg)
    fg = ~bg
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            near |= np.roll(np.roll(fg, dy, axis=0), dx, axis=1)
    alpha = np.where(near, alpha, 0.0)
    # The outer ring of a part is grey blended with the part (and the JPG's
    # light ringing): it gets a soft alpha and the colour from inside the part.
    interior = _shrink(fg, 2)
    ring = near & ~interior
    soft = np.clip((dist - EDGE_LO) / (EDGE_HI - EDGE_LO), 0.0, 1.0)
    alpha = np.where(ring, np.minimum(alpha, soft), alpha)
    colour = sheet.copy()
    total = np.zeros_like(sheet)
    count = np.zeros(dist.shape)
    for dy in range(-RING_REACH, RING_REACH + 1):
        for dx in range(-RING_REACH, RING_REACH + 1):
            shifted = np.roll(np.roll(interior, dy, axis=0), dx, axis=1)
            total += np.roll(np.roll(sheet * interior[..., None], dy, axis=0), dx, axis=1)
            count += shifted
    inside = count > 0
    fill = ring & inside
    colour[fill] = total[fill] / count[fill][:, None]
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
