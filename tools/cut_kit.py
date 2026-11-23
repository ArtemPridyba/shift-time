#!/usr/bin/env python3
"""Cut the Gemini pictures of the Night shop kit into game textures (task Д3, D106).

Gemini paints each piece of the kit as is (docs/art/gemini-kit.md): tiles fill
the whole picture, pieces stand on flat green, stains are white masks on black.
This script keys out the green, cuts the sheets into pieces, makes the tiles
repeat without a seam and scales everything to the size the game draws it,
`TEXEL` texture pixels per room pixel. Sizes of bricks and of the floor strip
come from `world` in game/data/look.json, so after a change there run it again.

    python3 tools/cut_kit.py              # every piece
    python3 tools/cut_kit.py brick lamp   # only these
    python3 tools/cut_kit.py --sheet      # also a contact sheet build/kit_sheet.png

Reads docs/art/gemini/raw/, writes game/assets/art/kit/. Needs Pillow and numpy.
Which picture each piece comes from and how it is cut: PIECES below.
"""

import argparse
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "docs", "art", "gemini", "raw")
OUT = os.path.join(ROOT, "game", "assets", "art", "kit")
LOOK = os.path.join(ROOT, "game", "data", "look.json")

# Texture pixels per room pixel: sharp at the start zoom x1.5, a little soft at x3.
TEXEL = 2


def world():
    with open(LOOK, encoding="utf-8") as f:
        return json.load(f)["world"]


# ---------------------------------------------------------------- loading

def load(raw, name):
    image = Image.open(os.path.join(raw, name)).convert("RGB")
    return np.asarray(image).astype(np.float32) / 255.0


def smoothstep(lo, hi, x):
    t = np.clip((x - lo) / (hi - lo), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def key_green(rgb):
    """Alpha from the flat green background; green spill taken off the edges."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    excess = g - np.maximum(r, b)
    alpha = 1.0 - smoothstep(0.12, 0.38, excess)
    out = rgb.copy()
    out[..., 1] = np.where(excess > 0.0, np.maximum(r, b), g)
    return out, alpha


def key_black(rgb):
    """A white mask on black (stains, N-11): the brightness is the alpha."""
    alpha = smoothstep(0.03, 0.97, rgb.mean(axis=2))
    return np.ones_like(rgb), alpha


def key_plaster(rgb):
    """The grey plaster patches of N-1b: low saturation, light; brick is red."""
    hi = rgb.max(axis=2)
    sat = (hi - rgb.min(axis=2)) / np.maximum(hi, 1e-3)
    alpha = (1.0 - smoothstep(0.20, 0.34, sat)) * smoothstep(0.40, 0.52, hi)
    return rgb, alpha


# ---------------------------------------------------------------- cutting

def box_px(box, shape):
    h, w = shape[:2]
    return int(box[0] * w), int(box[1] * h), int(round(box[2] * w)), int(round(box[3] * h))


def select(alpha, seed, grow):
    """The piece under `seed` (fractions): solid pixels connected to it, gaps
    of up to `grow` pixels bridged (loose bricks of a heap, glass shards)."""
    h, w = alpha.shape
    k = 4
    small = Image.fromarray(((alpha > 0.5) * 255).astype(np.uint8)).resize((w // k, h // k), Image.BOX)
    small = small.point(lambda v: 255 if v > 60 else 0)
    if grow:
        small = small.filter(ImageFilter.MaxFilter(2 * max(1, grow // k) + 1))
    sx, sy = int(seed[0] * (w // k)), int(seed[1] * (h // k))
    m = np.asarray(small)
    if m[sy, sx] == 0:
        ys, xs = np.nonzero(m)
        i = int(np.argmin((xs - sx) ** 2 + (ys - sy) ** 2))
        sx, sy = int(xs[i]), int(ys[i])
    ImageDraw.floodfill(small, (sx, sy), 128)
    sel = Image.fromarray(((np.asarray(small) == 128) * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))
    sel = np.asarray(sel.resize((w, h), Image.NEAREST)) > 0
    return alpha * sel


def crop(rgb, alpha, pad=2):
    ys, xs = np.nonzero(alpha > 0.02)
    if len(xs) == 0:
        raise SystemExit("cut_kit: an empty piece")
    y0, y1 = max(0, ys.min() - pad), min(alpha.shape[0], ys.max() + 1 + pad)
    x0, x1 = max(0, xs.min() - pad), min(alpha.shape[1], xs.max() + 1 + pad)
    return rgb[y0:y1, x0:x1], alpha[y0:y1, x0:x1]


# ---------------------------------------------------------------- tiles

def best_period(rgb, axis, lo, hi, band):
    """The shift along `axis` (pixels in [lo, hi]) at which the picture best
    repeats itself: the start of the picture matches the stretch after it."""
    lum = rgb.mean(axis=2)
    if axis == 1:
        lum = lum.T
    lum = Image.fromarray(np.ascontiguousarray(np.clip(lum, 0.0, 1.0) * 255.0).astype(np.uint8))
    lum = np.asarray(lum.filter(ImageFilter.GaussianBlur(2))).astype(np.float32)
    n = lum.shape[0]
    hi = min(hi, n - band)
    best, best_p = None, lo
    head = lum[:band]
    for p in range(lo, hi + 1):
        d = float(np.abs(head - lum[p:p + band]).mean())
        if best is None or d < best:
            best, best_p = d, p
    return best_p


def wrap(rgb, axis, period, band):
    """A tile `period` long that continues itself: its first `band` pixels
    fade from the stretch just after the period into the picture's own start,
    so the last pixel of the tile runs straight on into the first."""
    band = min(band, rgb.shape[axis] - period)
    tile = np.take(rgb, range(period), axis=axis).copy()
    if band <= 0:
        return tile
    t = smoothstep(0.0, 1.0, (np.arange(band, dtype=np.float32) + 0.5) / band)
    shape = [1, 1, 1]
    shape[axis] = band
    t = t.reshape(shape)
    head = np.take(rgb, range(band), axis=axis)
    after = np.take(rgb, range(period, period + band), axis=axis)
    index = [slice(None)] * 3
    index[axis] = slice(0, band)
    tile[tuple(index)] = after * (1.0 - t) + head * t
    return tile


def seamless(rgb, axes, ranges, band):
    """`ranges[axis]` = (lo, hi) of the period as fractions of the length."""
    for axis in axes:
        n = rgb.shape[axis]
        lo, hi = ranges[axis]
        b = max(8, int(band * n))
        p = best_period(rgb, axis, int(lo * n), int(hi * n), b)
        rgb = wrap(rgb, axis, p, b)
    return rgb


def resize(rgb, alpha, size, wrap_axes=()):
    """Scale to `size` (w, h). Along a wrapped axis the picture is scaled with
    its neighbours on both sides, so the filter sees across the seam."""
    a = np.dstack([rgb, alpha if alpha is not None else np.ones(rgb.shape[:2], np.float32)])
    reps = [1, 1, 1]
    for axis in wrap_axes:
        reps[axis] = 3
    big = np.tile(a, reps)
    out_size = (size[0] * (3 if 1 in wrap_axes else 1), size[1] * (3 if 0 in wrap_axes else 1))
    image = Image.fromarray((np.clip(big, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8), "RGBA")
    image = image.convert("RGBa").resize(out_size, Image.LANCZOS).convert("RGBA")
    if wrap_axes:
        x0 = size[0] if 1 in wrap_axes else 0
        y0 = size[1] if 0 in wrap_axes else 0
        image = image.crop((x0, y0, x0 + size[0], y0 + size[1]))
    return image


def calm_highlights(rgb, knee, keep):
    """Painted light (bright patches on the floor plates) pulled down: the
    game makes the light (D106)."""
    lum = rgb.mean(axis=2, keepdims=True)
    new = np.where(lum > knee, knee + (lum - knee) * keep, lum)
    return np.clip(rgb * new / np.maximum(lum, 1e-3), 0.0, 1.0)


# ---------------------------------------------------------------- pieces

def fit(size, width=None, height=None, longest=None):
    w, h = size
    if longest is not None:
        s = longest / max(w, h)
    elif width is not None:
        s = width / w
    else:
        s = height / h
    return max(1, int(round(w * s))), max(1, int(round(h * s)))


def piece_from(raw, spec):
    rgb = load(raw, spec["src"])
    if "box" in spec:
        x0, y0, x1, y1 = box_px(spec["box"], rgb.shape)
        rgb = rgb[y0:y1, x0:x1]
    keyer = {"green": key_green, "black": key_black, "plaster": key_plaster}[spec.get("key", "green")]
    rgb, alpha = keyer(rgb)
    if "seed" in spec:
        alpha = select(alpha, spec["seed"], spec.get("grow", 0))
    rgb, alpha = crop(rgb, alpha)
    if spec.get("rotate"):
        rgb = np.rot90(rgb, spec["rotate"]).copy()
        alpha = np.rot90(alpha, spec["rotate"]).copy()
    return rgb, alpha


def make(name, spec, raw, w):
    kind = spec["make"]
    if kind == "tile":
        rgb = load(raw, spec["src"])
        if "box" in spec:
            x0, y0, x1, y1 = box_px(spec["box"], rgb.shape)
            rgb = rgb[y0:y1, x0:x1]
        if "calm" in spec:
            rgb = calm_highlights(rgb, *spec["calm"])
        # Light concrete would outshine the dark hall: mass stays quiet.
        rgb = rgb * spec.get("shade", 1.0)
        axes = spec["axes"]
        rgb = seamless(rgb, axes, spec["period"], spec.get("band", 0.08))
        size = spec["size"](w, rgb.shape) if callable(spec["size"]) else spec["size"]
        return resize(rgb, None, size, wrap_axes=tuple(axes))
    rgb, alpha = piece_from(raw, spec)
    if kind == "strip":
        # A piece that repeats along one axis (column, truss, chain, pipe).
        axis = spec["axis"]
        # No clear margin at the ends: the pieces meet end to end.
        solid = np.nonzero(alpha.max(axis=1 - axis) > 0.5)[0]
        keep = range(int(solid.min()), int(solid.max()) + 1)
        rgb, alpha = np.take(rgb, keep, axis=axis), np.take(alpha, keep, axis=axis)
        if "trim" in spec:
            n = rgb.shape[axis]
            keep = range(int(spec["trim"][0] * n), int(spec["trim"][1] * n))
            rgb, alpha = np.take(rgb, keep, axis=axis), np.take(alpha, keep, axis=axis)
        if spec.get("blend", True):
            n = rgb.shape[axis]
            b = max(4, int(spec.get("band", 0.1) * n))
            lo, hi = spec.get("period", (0.8, 0.95))
            p = best_period(np.dstack([rgb * alpha[..., None]]), axis, int(lo * n), int(hi * n), b)
            both = wrap(np.dstack([rgb, alpha]), axis, p, b)
            rgb, alpha = both[..., :3], both[..., 3]
        cross = spec["cross"] * TEXEL
        size = fit((rgb.shape[1], rgb.shape[0]), height=cross) if axis == 1 else fit((rgb.shape[1], rgb.shape[0]), width=cross)
        return resize(rgb, alpha, size, wrap_axes=(axis,))
    size = fit((rgb.shape[1], rgb.shape[0]), **{k: v * TEXEL for k, v in spec["fit"].items()})
    return resize(rgb, alpha, size)


def brick_size(w, shape):
    bx, by = w["brick_px"]
    # 3 bricks across, 12 courses (PIECES: the period ranges pick them).
    return 3 * int(bx) * TEXEL, 12 * int(by) * TEXEL


def strip_size(height_key, width_room):
    def size(w, shape):
        return width_room * TEXEL, int(w[height_key]) * TEXEL
    return size


def edge_size(w, shape):
    h = (int(w["edge_px"]) + 4) * TEXEL
    return int(round(shape[1] * h / shape[0])), h


# What each texture is cut from. Boxes and seeds are fractions of the source
# picture; `fit` and `cross` are room pixels.
PIECES = {
    # --- tiles of the hall (Д3)
    "brick": {"make": "tile", "src": "n1_brick.jpg", "axes": [1, 0],
              "period": {1: (0.72, 0.78), 0: (0.90, 0.95)}, "band": 0.05, "size": brick_size},
    "masonry": {"make": "tile", "src": "n2c_ground.jpg", "axes": [1, 0],
                "period": {1: (0.82, 0.92), 0: (0.82, 0.92)}, "size": (256 * TEXEL, 256 * TEXEL)},
    "floor_top": {"make": "tile", "src": "n2a_floor_top.jpg", "axes": [1], "calm": (0.42, 0.35),
                  "period": {1: (0.86, 0.94)}, "size": strip_size("top_face_px", 192)},
    "floor_edge": {"make": "tile", "src": "n2b_floor_edge.jpg", "axes": [1],
                   "period": {1: (0.86, 0.94)}, "size": edge_size},
    "concrete": {"shade": 0.55, "make": "tile", "src": "n2e_concrete_top.jpg", "box": (0, 0, 1, 0.86), "axes": [1, 0],
                 "calm": (0.4, 0.4), "period": {1: (0.86, 0.94), 0: (0.86, 0.94)}, "size": (256 * TEXEL, 220 * TEXEL)},
    "concrete_top": {"shade": 0.55, "make": "tile", "src": "n2e_concrete_top.jpg", "box": (0, 0, 1, 0.86), "axes": [1],
                     "calm": (0.5, 0.5), "period": {1: (0.86, 0.94)}, "size": strip_size("top_face_px", 192)},
    "concrete_edge": {"shade": 0.55, "make": "tile", "src": "n2e_concrete_edge_v2.jpg", "axes": [1],
                      "period": {1: (0.86, 0.94)}, "size": edge_size},
    "ledge_side": {"make": "tile", "src": "n2d_ledge_side.jpg", "box": (0.33, 0, 0.52, 1), "axes": [0],
                   "period": {0: (0.86, 0.94)}, "size": lambda w, s: (int(w["edge_px"]) * TEXEL, int(round(s[0] * int(w["edge_px"]) * TEXEL / s[1])))},
    # --- pieces on the back wall (Д3)
    "window": {"make": "piece", "src": "n3_window.jpg", "fit": {"width": 80}},
    "plaster": {"make": "piece", "src": "n1b_plaster.jpg", "key": "plaster", "seed": (0.75, 0.2), "grow": 4, "fit": {"longest": 96}},
    "column": {"make": "strip", "src": "n4_iron_fixed.png", "box": (0.10, 0.05, 0.215, 0.96), "axis": 0,
               "trim": (0.12, 0.45), "cross": 20},
    "truss": {"make": "strip", "src": "n4_iron_fixed.png", "box": (0.41, 0.11, 0.96, 0.36), "axis": 1,
              "trim": (0.02, 0.47), "cross": 32},
    "crane_beam": {"make": "strip", "src": "n4_iron_fixed.png", "box": (0.41, 0.53, 0.96, 0.66), "axis": 1,
                   "trim": (0.04, 0.40), "cross": 14},
    "crane": {"make": "piece", "src": "n4_iron_fixed.png", "box": (0.60, 0.64, 0.80, 0.97), "seed": (0.5, 0.2), "grow": 6, "fit": {"width": 20}},
    "soot": {"make": "piece", "src": "n11_stains.jpg", "key": "black", "box": (0, 0, 0.5, 0.5), "fit": {"longest": 128}},
    "rust": {"make": "piece", "src": "n11_stains.jpg", "key": "black", "box": (0.5, 0, 1, 0.5), "fit": {"longest": 128}},
    "cracks": {"make": "piece", "src": "n11_stains.jpg", "key": "black", "box": (0, 0.5, 0.5, 1), "fit": {"longest": 128}},
    "stain": {"make": "piece", "src": "n11_stains.jpg", "key": "black", "box": (0.5, 0.5, 1, 1), "fit": {"longest": 128}},
    "tank": {"make": "piece", "src": "n9_machines.jpg", "seed": (0.13, 0.4), "fit": {"width": 96}},
    "hopper": {"make": "piece", "src": "n9_machines.jpg", "box": (0.26, 0.02, 0.48, 0.62), "seed": (0.5, 0.3), "fit": {"width": 80}},
    "catwalk": {"make": "piece", "src": "n9_machines.jpg", "box": (0.48, 0.02, 0.98, 0.72), "seed": (0.5, 0.4), "grow": 6, "fit": {"width": 192}},
    "conveyor": {"make": "piece", "src": "n9_machines.jpg", "box": (0.26, 0.45, 0.76, 0.84), "seed": (0.5, 0.5), "grow": 6, "fit": {"width": 160}},
    "pipe": {"make": "strip", "src": "n9_machines.jpg", "box": (0.26, 0.76, 0.57, 0.99), "axis": 0, "rotate": 1,
             "blend": False, "cross": 12},
    "pipe_elbow": {"make": "piece", "src": "n9_machines.jpg", "box": (0.58, 0.72, 0.76, 0.99), "fit": {"width": 32}},
    "pipe_tee": {"make": "piece", "src": "n9_machines.jpg", "box": (0.76, 0.72, 0.99, 0.99), "fit": {"width": 40}},
    "lamp": {"make": "piece", "src": "n8_lamps_clock_fixed.png", "box": (0.02, 0.42, 0.19, 0.87), "fit": {"width": 24}},
    "lamp_chain": {"make": "strip", "src": "n8_lamps_clock.jpg", "box": (0.08, 0.0, 0.13, 0.27), "axis": 0,
                   "period": (0.6, 0.9), "cross": 6},
    # --- pieces on the floor (Д3)
    "bricks": {"make": "piece", "src": "n10_rubble.jpg", "box": (0.01, 0.10, 0.69, 0.50), "seed": (0.5, 0.5), "grow": 40, "fit": {"width": 96}},
    "lump": {"make": "piece", "src": "n10_rubble.jpg", "box": (0.70, 0.10, 0.96, 0.43), "seed": (0.5, 0.5), "grow": 30, "fit": {"width": 32}},
    "beam": {"make": "piece", "src": "n10_rubble_fixed.png", "box": (0.02, 0.56, 0.67, 0.92), "fit": {"width": 120}},
    "glass": {"make": "piece", "src": "n10_rubble_fixed.png", "box": (0.71, 0.66, 0.96, 0.85), "fit": {"width": 60}},
    # --- objects of Д4: cut and kept, the objects still draw themselves
    "shutter_slab": {"make": "piece", "src": "n5_shutter.jpg", "box": (0.02, 0.02, 0.36, 0.98), "fit": {"longest": 256}},
    "shutter_wheel": {"make": "piece", "src": "n5_shutter.jpg", "box": (0.52, 0.02, 0.73, 0.36), "fit": {"longest": 96}},
    "shutter_gear_big": {"make": "piece", "src": "n5_shutter.jpg", "box": (0.37, 0.37, 0.70, 0.97), "fit": {"longest": 128}},
    "shutter_gear_small": {"make": "piece", "src": "n5_shutter.jpg", "box": (0.76, 0.39, 0.94, 0.69), "fit": {"longest": 64}},
    "shutter_bolt": {"make": "piece", "src": "n5_shutter.jpg", "box": (0.70, 0.74, 0.99, 0.95), "fit": {"longest": 96}},
    "exit_frame": {"make": "piece", "src": "n6a_exit_door.jpg", "box": (0.0, 0.0, 0.40, 1.0), "fit": {"longest": 256}},
    "exit_leaf": {"make": "piece", "src": "n6a_exit_door.jpg", "box": (0.41, 0.07, 0.71, 0.93), "fit": {"longest": 256}},
    "exit_wheel": {"make": "piece", "src": "n6a_exit_door.jpg", "box": (0.75, 0.04, 0.96, 0.40), "fit": {"longest": 96}},
    "exit_rail": {"make": "piece", "src": "n6a_exit_door.jpg", "box": (0.71, 0.42, 0.99, 0.61), "fit": {"longest": 192}},
    "beacon": {"make": "piece", "src": "n6a_exit_door.jpg", "box": (0.78, 0.63, 0.93, 0.93), "fit": {"longest": 48}},
    "exit_stairs": {"make": "tile", "src": "n6b_stairs.jpg", "axes": [], "period": {}, "size": (128 * TEXEL, 166 * TEXEL)},
    "platform": {"make": "piece", "src": "n7_platforms_fixed.png", "box": (0.06, 0.08, 0.94, 0.37), "fit": {"width": 128}},
    "platform_rack": {"make": "strip", "src": "n7_platforms_fixed.png", "box": (0.12, 0.38, 0.24, 0.96), "axis": 0,
                      "trim": (0.05, 0.95), "cross": 24},
    "platform_chain": {"make": "strip", "src": "n7_platforms_fixed.png", "box": (0.37, 0.61, 0.95, 0.74), "axis": 1,
                       "trim": (0.02, 0.98), "period": (0.6, 0.9), "cross": 10},
    "wall_lamp": {"make": "piece", "src": "n8_lamps_clock_fixed.png", "box": (0.19, 0.21, 0.40, 0.73), "fit": {"longest": 48}},
    "clock": {"make": "piece", "src": "n8_lamps_clock_fixed.png", "box": (0.41, 0.13, 0.82, 0.86), "fit": {"longest": 96}},
    "clock_hand_hour": {"make": "piece", "src": "n8_lamps_clock.jpg", "box": (0.84, 0.36, 0.90, 0.71), "fit": {"longest": 48}},
    "clock_hand_minute": {"make": "piece", "src": "n8_lamps_clock.jpg", "box": (0.91, 0.25, 0.97, 0.71), "fit": {"longest": 64}},
    "lever_base": {"make": "piece", "src": "n12_yellow_fixed.png", "box": (0.01, 0.15, 0.28, 0.88), "fit": {"longest": 96}},
    "lever_handle": {"make": "piece", "src": "n12_yellow_fixed.png", "box": (0.28, 0.16, 0.36, 0.76), "fit": {"longest": 64}},
    "button_base": {"make": "piece", "src": "n12_yellow_fixed.png", "box": (0.36, 0.16, 0.60, 0.42), "fit": {"longest": 64}},
    "button_cap": {"make": "piece", "src": "n12_yellow_fixed.png", "box": (0.37, 0.58, 0.59, 0.83), "fit": {"longest": 48}},
    "crate": {"make": "piece", "src": "n12_yellow_fixed.png", "box": (0.60, 0.12, 0.99, 0.88), "fit": {"longest": 128}},
}


def contact_sheet(names, path):
    cells = []
    for name in names:
        image = Image.open(os.path.join(OUT, name + ".png")).convert("RGBA")
        s = min(4.0, 200.0 / max(image.size))
        image = image.resize((max(1, int(image.width * s)), max(1, int(image.height * s))), Image.NEAREST)
        cells.append((name, image))
    cols = 6
    rows = (len(cells) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * 220, rows * 240), (70, 90, 110, 255))
    draw = ImageDraw.Draw(sheet)
    for i, (name, image) in enumerate(cells):
        x, y = (i % cols) * 220 + 10, (i // cols) * 240 + 20
        sheet.alpha_composite(image, (x, y))
        draw.text((x, y - 16), name, fill=(255, 255, 0, 255))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sheet.save(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("names", nargs="*", help="pieces to cut (default: all)")
    parser.add_argument("--raw", default=RAW, help="folder with the Gemini pictures")
    parser.add_argument("--sheet", action="store_true", help="write build/kit_sheet.png")
    args = parser.parse_args()
    names = args.names or list(PIECES)
    unknown = [n for n in names if n not in PIECES]
    if unknown:
        sys.exit("cut_kit: no such piece: " + ", ".join(unknown))
    w = world()
    os.makedirs(OUT, exist_ok=True)
    for name in names:
        image = make(name, PIECES[name], args.raw, w)
        image.save(os.path.join(OUT, name + ".png"), optimize=True)
        print("%-20s %4d x %-4d" % (name, image.width, image.height))
    if args.sheet:
        contact_sheet(names, os.path.join(ROOT, "build", "kit_sheet.png"))


if __name__ == "__main__":
    main()
