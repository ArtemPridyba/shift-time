#!/usr/bin/env python3
"""Builds two SVG frames of one Shift Time room: normal time and reverse time.

Usage: make_concept.py <out_dir>
Colours follow docs/setting.md: graphite silhouettes, ochre haze, rust only on
edges, cyan only for time-tied mechanisms.
"""
import math
import random
import sys
from pathlib import Path

W, H = 1920, 1080
GRAPHITE = "#1B1A19"
MID = "#2B2521"
FAR = "#5A4631"
OCHRE = "#8C6A3F"
DARK_AIR = "#2A2420"
RUST = "#A04B22"
CYAN = "#7FE8FF"
DUST = "#E0B878"


def jag(x0, x1, y, amp, step, rng, chip=0.14):
    """Chipped top edge: list of (x, y) points from x0 to x1."""
    pts = [(x0, y)]
    x = x0
    while x < x1:
        x = min(x + rng.randint(step // 2, step), x1)
        dy = rng.uniform(-amp, amp)
        if rng.random() < chip:
            dy += rng.uniform(8, 20)
        pts.append((x, y + dy))
    pts[-1] = (x1, y)
    return pts


def poly(points, fill, extra=""):
    d = " ".join(f"{x:.1f},{y:.1f}" for x, y in points)
    return f'<polygon points="{d}" fill="{fill}" {extra}/>'


def platform(x0, x1, top, bottom, rng, fill=GRAPHITE, amp=1.3):
    top_pts = jag(x0, x1, top, amp, 70, rng, chip=0.02)
    return poly(top_pts + [(x1, bottom), (x0, bottom)], fill), top_pts


def rust_streaks(top_pts, rng, count, alpha=0.9):
    out = []
    for _ in range(count):
        x, y = rng.choice(top_pts[1:-1])
        w = rng.uniform(2.5, 8)
        h = rng.uniform(30, 170)
        out.append(
            f'<rect x="{x - w / 2:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" '
            f'fill="url(#rustfade)" opacity="{alpha * rng.uniform(0.55, 1):.2f}"/>'
        )
    return "".join(out)


def rust_stains(anchors, rng, count, alpha=0.4):
    """Wide soft rust sheets under an edge."""
    out = []
    for _ in range(count):
        x, y = rng.choice(anchors[1:-1])
        w, h = rng.uniform(22, 54), rng.uniform(70, 190)
        out.append(
            f'<rect x="{x - w / 2:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" '
            f'fill="url(#rustfade)" opacity="{alpha * rng.uniform(0.5, 1):.2f}" filter="url(#soft)"/>'
        )
    return "".join(out)


def _catmull(pts, n=12):
    out = []
    P = [pts[0]] + list(pts) + [pts[-1]]
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for k in range(n):
            t = k / n
            t2, t3 = t * t, t * t * t
            x = 0.5 * (2 * p1[0] + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2
                       + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
            y = 0.5 * (2 * p1[1] + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2
                       + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            out.append((x, y))
    out.append(tuple(pts[-1]))
    return out


def ribbon(pts, w0, w1, n=12):
    """Tapered ribbon along a smooth curve through pts: a polygon."""
    c = _catmull(pts, n)
    left, right, m = [], [], len(c)
    for i, (x, y) in enumerate(c):
        a, b = c[max(i - 1, 0)], c[min(i + 1, m - 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / ln, dx / ln
        w = (w0 + (w1 - w0) * i / (m - 1)) / 2
        left.append((x + nx * w, y + ny * w))
        right.append((x - nx * w, y - ny * w))
    return left + right[::-1]


def dust(rng, reverse):
    out = []
    for _ in range(150):
        x, y = rng.uniform(0, W), rng.uniform(80, H - 60)
        r = rng.uniform(0.9, 2.6)
        a = rng.uniform(0.18, 0.55)
        out.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r:.1f}" fill="{DUST}" opacity="{a:.2f}"/>')
    # short motion streaks: the bright head shows the way the dust moves
    for _ in range(34):
        x, y = rng.uniform(40, W - 40), rng.uniform(140, H - 200)
        ln = rng.uniform(16, 34)
        if reverse:
            y_tail, y_head = y + ln, y
        else:
            y_tail, y_head = y - ln, y
        out.append(
            f'<line x1="{x:.1f}" y1="{y_tail:.1f}" x2="{x:.1f}" y2="{y_head:.1f}" '
            f'stroke="{DUST}" stroke-width="1.6" opacity="0.28" stroke-linecap="round"/>'
            f'<circle cx="{x:.1f}" cy="{y_head:.1f}" r="2.1" fill="#FFE2A8" opacity="0.7"/>'
        )
    return "".join(out)


def drops(reverse):
    """Water stream from the ceiling pipe into the pit."""
    out = []
    x = 960
    y0, y1 = 190, 930
    out.append(
        f'<rect x="{x - 2}" y="{y0}" width="4" height="{y1 - y0}" fill="#9FC7D0" opacity="0.28"/>'
    )
    for i in range(11):
        y = y0 + 60 + i * 66
        if reverse:
            out.append(
                f'<path d="M{x},{y + 20} C{x - 5},{y + 8} {x - 4},{y + 2} {x},{y - 8} '
                f'C{x + 4},{y + 2} {x + 5},{y + 8} {x},{y + 20}Z" fill="#CDEFF5" opacity="0.8"/>'
            )
        else:
            out.append(
                f'<path d="M{x},{y - 20} C{x - 5},{y - 8} {x - 4},{y - 2} {x},{y + 8} '
                f'C{x + 4},{y - 2} {x + 5},{y - 8} {x},{y - 20}Z" fill="#CDEFF5" opacity="0.8"/>'
            )
    return "".join(out)


def build(reverse: bool, seed: int = 11) -> str:
    rng = random.Random(seed)
    parts = []

    defs = f"""
<defs>
  <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="{DARK_AIR}"/>
    <stop offset="0.5" stop-color="{OCHRE}"/>
    <stop offset="1" stop-color="#3A2E25"/>
  </linearGradient>
  <radialGradient id="sun" cx="0.68" cy="0.30" r="0.45">
    <stop offset="0" stop-color="#F0C57A" stop-opacity="0.75"/>
    <stop offset="1" stop-color="#F0C57A" stop-opacity="0"/>
  </radialGradient>
  <linearGradient id="rustfade" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="{RUST}" stop-opacity="0.95"/>
    <stop offset="1" stop-color="{RUST}" stop-opacity="0"/>
  </linearGradient>
  <linearGradient id="shaft" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#FFE3A8" stop-opacity="0.28"/>
    <stop offset="1" stop-color="#FFE3A8" stop-opacity="0"/>
  </linearGradient>
  <linearGradient id="doorway" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#D9AE6B"/>
    <stop offset="1" stop-color="#7A5B35"/>
  </linearGradient>
  <radialGradient id="vignette" cx="0.5" cy="0.5" r="0.75">
    <stop offset="0.55" stop-color="#000" stop-opacity="0"/>
    <stop offset="1" stop-color="#000" stop-opacity="{0.62 if reverse else 0.28}"/>
  </radialGradient>
  <filter id="glow" x="-60%" y="-60%" width="220%" height="220%">
    <feGaussianBlur stdDeviation="7" result="b"/>
    <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
  <filter id="soft" x="-20%" y="-20%" width="140%" height="140%">
    <feGaussianBlur stdDeviation="2.2"/>
  </filter>
  <filter id="grain" x="0" y="0" width="100%" height="100%">
    <feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves="2" seed="4"/>
    <feColorMatrix values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 0.55 -0.12"/>
  </filter>
  <pattern id="scan" width="6" height="6" patternUnits="userSpaceOnUse">
    <rect width="6" height="2" fill="#000" opacity="0.16"/>
  </pattern>
</defs>"""

    # 1. air and far layers
    parts.append(f'<rect width="{W}" height="{H}" fill="url(#sky)"/>')
    parts.append(f'<rect width="{W}" height="{H}" fill="url(#sun)"/>')

    far = []
    # cooling towers
    far.append(poly([(1180, 740), (1230, 330), (1300, 330), (1350, 740)], FAR, 'opacity="0.55"'))
    far.append(poly([(1450, 740), (1480, 420), (1530, 420), (1560, 740)], FAR, 'opacity="0.5"'))
    # gantry lattice
    for i in range(14):
        x = 120 + i * 62
        far.append(
            f'<line x1="{x}" y1="470" x2="{x + 62}" y2="560" stroke="{FAR}" stroke-width="5" opacity="0.5"/>'
            f'<line x1="{x + 62}" y1="470" x2="{x}" y2="560" stroke="{FAR}" stroke-width="5" opacity="0.5"/>'
        )
    far.append(f'<rect x="100" y="462" width="900" height="9" fill="{FAR}" opacity="0.55"/>')
    far.append(f'<rect x="100" y="558" width="900" height="9" fill="{FAR}" opacity="0.55"/>')
    # distant flying platforms (ambient tech: warm lights, never cyan)
    for (x, y, w) in [(1650, 300, 120), (1380, 250, 80), (1790, 410, 70)]:
        far.append(
            f'<rect x="{x}" y="{y}" width="{w}" height="12" rx="6" fill="{FAR}" opacity="0.7"/>'
            f'<ellipse cx="{x + w / 2}" cy="{y + 18}" rx="{w / 3}" ry="4" fill="#F0C57A" opacity="0.35"/>'
        )
    parts.append("".join(far))

    # 2. light shafts from the hole in the ceiling
    parts.append(
        '<g opacity="0.9">'
        + poly([(1000, 0), (1160, 0), (1400, 900), (1080, 900)], "url(#shaft)")
        + poly([(1200, 0), (1260, 0), (1620, 900), (1470, 900)], "url(#shaft)")
        + "</g>"
    )

    # 3. mid layer
    mid = []
    mid.append(f'<rect x="300" y="170" width="120" height="900" fill="{MID}" opacity="0.92"/>')
    mid.append(f'<rect x="1090" y="120" width="86" height="960" fill="{MID}" opacity="0.92"/>')
    mid.append(
        poly([(0, 380), (760, 250), (760, 300), (0, 440)], MID, 'opacity="0.95"')
    )
    mid.append(f'<rect x="0" y="470" width="410" height="34" fill="{MID}" opacity="0.95"/>')
    for x, y1, y2 in [(520, 0, 210), (780, 0, 150), (1330, 0, 260), (1740, 0, 190)]:
        mid.append(
            f'<path d="M{x},{y1} C{x - 30},{(y1 + y2) // 2} {x + 30},{(y1 + y2) // 2 + 20} {x},{y2}" '
            f'stroke="{MID}" stroke-width="8" fill="none"/>'
        )
    parts.append("".join(mid))

    # 4. foreground silhouettes
    fg = []
    # ceiling band with a broken hole
    ceil_l = jag(0, 1000, 118, 6, 60, rng)
    ceil_r = jag(1330, W, 118, 6, 60, rng)
    fg.append(poly([(0, 0)] + ceil_l + [(1000, 0)], GRAPHITE))
    fg.append(poly([(1330, 0)] + ceil_r + [(W, 0)], GRAPHITE))
    fg.append(poly([(1000, 0), (1030, 70), (1080, 40), (1120, 98), (1160, 30), (1200, 76), (1330, 0)], GRAPHITE))
    # left platform
    pl_svg, pl_top = platform(0, 710, 760, H, rng)
    fg.append(pl_svg)
    # right block with a doorway
    r_top = jag(1250, W, 650, 1.3, 70, rng, chip=0.02)
    fg.append(poly(r_top + [(W, H), (1250, H)], GRAPHITE))
    fg.append(f'<rect x="1500" y="120" width="{W - 1500}" height="540" fill="{GRAPHITE}"/>')
    # panel seams so the dark masses are not flat slabs
    seam = "#2C2825"
    for x in (1720, 1830):
        fg.append(f'<rect x="{x}" y="132" width="3" height="520" fill="{seam}"/>')
    for y in (250, 360, 560):
        fg.append(f'<rect x="1500" y="{y}" width="{W - 1500}" height="3" fill="{seam}"/>')
    for y in (860, 960):
        fg.append(f'<rect x="0" y="{y}" width="710" height="3" fill="{seam}"/>')
    for x in (240, 480):
        fg.append(f'<rect x="{x}" y="780" width="3" height="300" fill="{seam}"/>')
    for x in (1330, 1480):
        fg.append(f'<rect x="{x}" y="680" width="3" height="400" fill="{seam}"/>')
    # doorway cut-out (bright haze behind)
    fg.append(f'<rect x="1560" y="440" width="104" height="210" fill="url(#doorway)"/>')
    # pit floor
    fg.append(poly([(710, 1000), (760, 980), (1190, 990), (1250, 1010), (1250, H), (710, H)], GRAPHITE))
    # catwalk rail on the left platform
    fg.append(f'<rect x="40" y="690" width="320" height="6" fill="{GRAPHITE}"/>')
    for x in range(40, 361, 64):
        fg.append(f'<rect x="{x}" y="690" width="6" height="70" fill="{GRAPHITE}"/>')
    # pipe from the ceiling
    fg.append(f'<rect x="936" y="112" width="48" height="84" fill="{GRAPHITE}"/>')
    fg.append(f'<rect x="926" y="184" width="68" height="16" rx="3" fill="{GRAPHITE}"/>')
    parts.append("".join(fg))

    # water in the pit
    parts.append(
        f'<rect x="740" y="930" width="480" height="70" fill="#2F4A52" opacity="0.9"/>'
        f'<rect x="740" y="930" width="480" height="4" fill="{CYAN}" opacity="0.55"/>'
    )
    parts.append(drops(reverse))

    # rust, only on edges and streaks; temporal objects stay cleaner in reverse
    rust = rust_streaks(pl_top, rng, 34) + rust_streaks(r_top, rng, 38)
    rust += rust_stains(pl_top, rng, 7) + rust_stains(r_top, rng, 8)
    rust += rust_streaks(ceil_l, rng, 16, alpha=0.75) + rust_streaks(ceil_r, rng, 12, alpha=0.75)
    wall = [(rng.uniform(1510, 1910), y) for y in (130, 250, 360, 560) for _ in range(5)]
    rust += rust_streaks(wall, rng, 16, alpha=0.8)
    rust += rust_streaks([(0, 0), (944, 200), (960, 200), (976, 200), (0, 0)], rng, 4, alpha=0.8)
    rust += (
        f'<rect x="1500" y="300" width="5" height="190" fill="url(#rustfade)" opacity="0.8"/>'
        f'<rect x="1640" y="250" width="4" height="150" fill="url(#rustfade)" opacity="0.7"/>'
    )
    parts.append(f'<g>{rust}</g>')

    # 5. time-tied mechanisms (cyan lives only here)
    mech = []
    # floating platform and its motion trail
    px, py, pw, ph = 880, 690, 230, 26
    if reverse:
        ghosts = [(px + 70, 0.30), (px + 140, 0.18), (px + 210, 0.09)]
    else:
        ghosts = [(px - 60, 0.28), (px - 120, 0.16), (px - 180, 0.08)]
    for gx, ga in ghosts:
        mech.append(
            f'<rect x="{gx}" y="{py}" width="{pw}" height="{ph}" rx="8" fill="none" '
            f'stroke="{CYAN}" stroke-width="2" opacity="{ga:.2f}"/>'
        )
    mech.append(
        f'<ellipse cx="{px + pw / 2}" cy="{py + ph + 18}" rx="{pw / 2.4}" ry="9" fill="{CYAN}" '
        f'opacity="0.55" filter="url(#glow)"/>'
    )
    mech.append(f'<rect x="{px}" y="{py}" width="{pw}" height="{ph}" rx="8" fill="{GRAPHITE}"/>')
    mech.append(f'<rect x="{px + 14}" y="{py + 11}" width="{pw - 28}" height="4" rx="2" fill="{CYAN}" filter="url(#glow)"/>')
    # door panel; reverse frame shows it opening (higher) with a cleaner surface
    door_bottom = 470 if reverse else 548
    mech.append(f'<rect x="1560" y="440" width="104" height="{door_bottom - 440}" fill="#24211F"/>')
    mech.append(
        f'<rect x="1568" y="448" width="88" height="{door_bottom - 456}" fill="none" stroke="{CYAN}" '
        f'stroke-width="3" filter="url(#glow)" opacity="0.9"/>'
    )
    if reverse:
        for k, a in [(500, 0.30), (540, 0.18), (590, 0.1)]:
            mech.append(
                f'<rect x="1560" y="440" width="104" height="{k - 440}" fill="none" stroke="{CYAN}" '
                f'stroke-width="2" opacity="{a}"/>'
            )
    else:
        mech.append(
            f'<path d="M1612,{door_bottom + 12} l-9,-14 h18 z" fill="{CYAN}" filter="url(#glow)"/>'
        )
    # lever near the player
    mech.append(f'<rect x="610" y="738" width="30" height="22" rx="3" fill="{GRAPHITE}"/>')
    mech.append(f'<line x1="625" y1="740" x2="646" y2="694" stroke="{GRAPHITE}" stroke-width="7" stroke-linecap="round"/>')
    mech.append(f'<circle cx="646" cy="694" r="10" fill="none" stroke="{CYAN}" stroke-width="3" filter="url(#glow)"/>')
    # thin link line from lever to door (appears while Shift is held)
    if reverse:
        mech.append(
            f'<path d="M646,694 C900,470 1300,420 1560,520" fill="none" stroke="{CYAN}" stroke-width="2" '
            f'stroke-dasharray="3 9" opacity="0.75" filter="url(#glow)"/>'
        )
    parts.append("".join(mech))

    # 6. the player: simple silhouette, crouched to the lever, short arms, long scarf
    g = GRAPHITE
    scarf, scarf_d = "#C2562A", "#8F3E1C"
    pl = []
    limb = 'fill="none" stroke-linecap="round" stroke-linejoin="round"'
    pl.append(f'<polyline points="552,652 530,676 512,702" {limb} stroke="{g}" stroke-width="10"/>')
    pl.append(f'<polyline points="552,698 530,728 520,754" {limb} stroke="{g}" stroke-width="12"/>')
    pl.append(f'<polyline points="566,698 598,722 588,752" {limb} stroke="{g}" stroke-width="12"/>')
    pl.append(poly([(506, 752), (528, 750), (534, 760), (506, 760)], g))
    pl.append(poly([(574, 748), (596, 752), (606, 758), (606, 760), (572, 760), (572, 748)], g))
    pl.append(f'<path d="M548,646 Q574,634 584,650 L574,698 L544,700 Q536,672 548,646 Z" fill="{g}"/>')
    pl.append(f'<polyline points="576,650 604,672 640,698" {limb} stroke="{g}" stroke-width="10"/>')
    pl.append(f'<circle cx="640" cy="698" r="7" fill="{g}"/>')
    pl.append(f'<circle cx="588" cy="618" r="14" fill="{g}"/>')
    # scarf: one long tail and one short tail stream back
    pl.append(poly(ribbon([(578, 632), (548, 622), (520, 636), (490, 622), (462, 630), (436, 616)], 11, 3), scarf))
    pl.append(poly(ribbon([(578, 638), (552, 648), (530, 662), (504, 656)], 9, 3), scarf_d))
    pl.append(f'<g transform="rotate(-14 580 632)"><ellipse cx="580" cy="632" rx="14" ry="7" fill="{scarf}"/></g>')
    # wrist device on the reaching arm
    pl.append(f'<circle cx="617" cy="682" r="15" fill="none" stroke="{CYAN}" stroke-width="2" opacity="0.35" filter="url(#glow)"/>')
    pl.append(f'<g transform="translate(617 682) rotate(36)"><rect x="-12" y="-7" width="24" height="14" rx="4" fill="{CYAN}" filter="url(#glow)"/>')
    if reverse:
        pl.append(f'<path d="M-8,0 l6,-4.5 v9 z M1,0 l6,-4.5 v9 z" fill="{g}"/></g>')
    else:
        pl.append(f'<path d="M-3.5,-4.5 l8,4.5 l-8,4.5 z" fill="{g}"/></g>')
    parts.append("".join(pl))

    # 7. particles and finish
    parts.append(dust(rng, reverse))
    parts.append(f'<rect width="{W}" height="{H}" filter="url(#grain)" opacity="0.5"/>')
    parts.append(f'<rect width="{W}" height="{H}" fill="url(#vignette)"/>')
    if reverse:
        parts.append(f'<rect width="{W}" height="{H}" fill="url(#scan)"/>')
        parts.append(
            f'<rect x="6" y="6" width="{W - 12}" height="{H - 12}" fill="none" stroke="{CYAN}" '
            f'stroke-width="3" opacity="0.28" filter="url(#soft)"/>'
        )

    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
        + defs
        + "".join(parts)
        + "</svg>"
    )


def main() -> None:
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    (out / "01_normal.svg").write_text(build(False), encoding="utf-8")
    (out / "02_reverse.svg").write_text(build(True), encoding="utf-8")
    print("ok")


if __name__ == "__main__":
    main()
