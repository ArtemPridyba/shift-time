import math, sys
from PIL import Image, ImageDraw, ImageFilter, ImageChops, ImageFont
def h(s): s = s.lstrip('#'); return tuple(int(s[i:i+2], 16) for i in (0, 2, 4))
def mix(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))
P_OLD = {
 'Endesga 32 (ENDESGA)': dict(far='181425', wall='262b44', band='3a4466', seam='181425', up='124e89', beam='f77622', box='b86f50', box2='743f39', lamp='feae34', lab='5a6988', glass='193c3e', cold='c0cbdc', ctop='8b9bb4', cfront='5a6988', cdark='3a4466', stop='c0cbdc', sfront='8b9bb4', haz='fee761', hazd='181425', bare='ffffff', suit='0095e9', suitd='124e89', hat='feae34', skin='e8b796', time='2ce8f5', water='124e89', fire='f77622', fire2='feae34', wood='b86f50'),
 'AAP-64 (Adigun Polack)': dict(far='141013', wall='333941', band='4a5462', seam='242234', up='285cc4', beam='fa6a0a', box='bb7547', box2='71413b', lamp='f9a31b', lab='6d758d', glass='122020', cold='dae0ea', ctop='8b93af', cfront='6d758d', cdark='4a5462', stop='dae0ea', sfront='b3b9d1', haz='ffd541', hazd='221c1a', bare='ffffff', suit='249fde', suitd='143464', hat='ffd541', skin='f4d29c', time='20d6c7', water='143464', fire='fa6a0a', fire2='ffd541', wood='bb7547'),
 'Copper Tech (Arne Jansson)': dict(far='000000', wall='262144', band='355278', seam='000000', up='1651dd', beam='c58843', box='9e5b47', box2='5f4351', lamp='f4cd72', lab='60748a', glass='000000', cold='ffffff', ctop='898989', cfront='60748a', cdark='355278', stop='bfb588', sfront='898989', haz='f4cd72', hazd='000000', bare='ffffff', suit='1651dd', suitd='262144', hat='f4cd72', skin='bfb588', time='91d9f3', water='355278', fire='dc392d', fire2='f4cd72', wood='c58843'),
 'Zughy 32 (Zughy)': dict(far='302c2e', wall='3c5956', band='4f546b', seam='302c2e', up='3978a8', beam='f47e1b', box='bf7958', box2='7a444a', lamp='f4b41b', lab='7d7071', glass='394778', cold='dff6f5', ctop='a0938e', cfront='7d7071', cdark='5a5353', stop='cfc6b8', sfront='a0938e', haz='f4b41b', hazd='302c2e', bare='dff6f5', suit='3978a8', suitd='394778', hat='f4b41b', skin='f4cca1', time='8aebf1', water='394778', fire='e6482e', fire2='f4b41b', wood='bf7958'),
}
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
W, H, FL, TOP = 960, 540, 430, 8
def gear(d, cx, cy, r, teeth, col, hub, ang=0.0):
    pts = []
    for i in range(teeth * 4):
        a = ang + i * math.pi * 2 / (teeth * 4)
        rr = r if (i % 4) in (1, 2) else r * 0.78
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d.polygon(pts, fill=col); d.ellipse([cx - r * .3, cy - r * .3, cx + r * .3, cy + r * .3], fill=hub)
def slab(d, x0, y0, x1, y1, top, front, dark, line=None, chip=None):
    d.rectangle([x0, y0 + TOP, x1, y1], fill=front)
    d.rectangle([x0, y0, x1, y0 + TOP], fill=top)
    d.line([x0, y0 + TOP, x1, y0 + TOP], fill=mix(top, (255, 255, 255), .35), width=1)
    d.rectangle([x0, y1 - 6, x1, y1], fill=dark)
    if line: d.rectangle([x0, y0 + 3, x1, y0 + 5], fill=line)
    if chip:
        for cx in range(x0 + 37, x1 - 10, 83): d.polygon([(cx, y0 + TOP), (cx + 9, y0 + TOP), (cx + 5, y0 + TOP + 4)], fill=chip)
def gear2(d, cx, cy, r, teeth, C, ang=0.0):
    def ring(rad_o, rad_i, col, grow=0):
        pts = []
        for i in range(teeth * 4):
            a = ang + i * math.pi * 2 / (teeth * 4)
            rr = (rad_o if (i % 4) in (1, 2) else rad_i) + grow
            pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
        d.polygon(pts, fill=col)
    ring(r, r * .8, C['ol'], 1.5); ring(r, r * .8, C['br2']); 
    d.pieslice([cx - r * .8, cy - r * .8, cx + r * .8, cy + r * .8], 200, 320, fill=C['br3'])
    d.ellipse([cx - r * .66, cy - r * .66, cx + r * .66, cy + r * .66], fill=C['br1'])
    for k in range(4):
        a = ang + k * math.pi / 2 + math.pi / 4; hx, hy = cx + r * .42 * math.cos(a), cy + r * .42 * math.sin(a)
        d.ellipse([hx - r * .15, hy - r * .15, hx + r * .15, hy + r * .15], fill=C['ol'])
    d.ellipse([cx - r * .26, cy - r * .26, cx + r * .26, cy + r * .26], fill=C['ol'])
    d.ellipse([cx - r * .22, cy - r * .22, cx + r * .22, cy + r * .22], fill=C['br3'])
    d.ellipse([cx - r * .08, cy - r * .08, cx + r * .08, cy + r * .08], fill=C['ol'])
def scene(c, rev=False):
    C = {k: h(v) for k, v in c.items() if not k.startswith('_')}
    fog = lambda k, t=.45: mix(C[k], C['far'], t)
    img = Image.new('RGB', (W, H), C['far']); d = ImageDraw.Draw(img)
    glow = Image.new('RGB', (W, H), (0, 0, 0)); g = ImageDraw.Draw(glow)
    d.rectangle([0, 60, W, FL], fill=fog('wall', .2)); d.rectangle([0, 300, W, FL], fill=fog('band', .3))
    for x in range(0, W, 120): d.line([x, 60, x, FL], fill=C['seam'], width=2)
    d.line([0, 300, W, 300], fill=C['seam'], width=2)
    d.rectangle([0, 30, W, 44], fill=fog('cdark', .3))
    for x in range(0, W, 40): d.line([x, 44, x + 20, 30], fill=fog('cdark', .5), width=3)
    d.rectangle([0, 72, W, 80], fill=fog('sfront', .55)); d.rectangle([0, 86, W, 100], fill=fog('cfront', .55))
    for x in range(30, W, 160): d.rectangle([x, 83, x + 8, 103], fill=fog('sfront', .45))
    for x0 in (40, 200):
        for y in (190, 280, 370):
            for bx in range(x0 + 14, x0 + 150, 46):
                d.rectangle([bx, y - 40, bx + 38, y], fill=fog('box', .5)); d.line([bx, y - 20, bx + 38, y - 20], fill=fog('box2', .5), width=2)
            d.rectangle([x0, y, x0 + 160, y + 8], fill=fog('beam', .4))
    for x in (40, 200, 360): d.rectangle([x, 120, x + 9, FL], fill=fog('up', .4))
    d.rectangle([600, 140, 880, 320], fill=fog('lab', .35)); d.rectangle([612, 152, 868, 308], fill=C['glass'])
    for i, y in enumerate(range(170, 300, 26)): d.rectangle([630, y, 630 + 60 + (i * 37) % 150, y + 6], fill=fog('cold', .25))
    g.rectangle([612, 152, 868, 308], fill=mix(C['cold'], (0, 0, 0), .78))
    for i in range(0, 120, 24): d.polygon([(890 + i, 330), (902 + i, 330), (890 + i + 22, FL), (878 + i + 22, FL)], fill=fog('haz', .45) if (i // 24) % 2 == 0 else fog('hazd', .2))
    try: f = ImageFont.load_default(28)
    except Exception: f = ImageFont.load_default()
    d.text((392, 230), 'B-07', fill=fog('stop', .55), font=f)
    for lx in (130, 450):
        d.line([lx, 100, lx, 150], fill=fog('cdark'), width=2)
        d.polygon([(lx - 30, 170), (lx - 12, 150), (lx + 12, 150), (lx + 30, 170)], fill=fog('sfront', .4))
        d.ellipse([lx - 9, 165, lx + 9, 175], fill=C['lamp'])
        g.polygon([(lx - 30, 172), (lx + 30, 172), (lx + 150, FL), (lx - 150, FL)], fill=mix(C['lamp'], (0, 0, 0), .82))
        g.ellipse([lx - 30, 150, lx + 30, 190], fill=C['lamp'])
    # foreground
    slab(d, 0, FL, W, H, C['ctop'], mix(C['cfront'], C['far'], .45), C['cdark'], C['haz'], C['bare'])
    slab(d, 800, 360, W, FL, C['ctop'], C['cfront'], C['cdark'], None, C['bare'])
    rx = 520
    # rack column: outline, body, lit left edge, teeth
    d.rectangle([rx - 10, 108, rx + 10, FL], fill=C['ol'])
    for y in range(112, FL - 8, 12):
        d.polygon([(rx - 9, y), (rx - 17, y + 2), (rx - 17, y + 6), (rx - 9, y + 9)], fill=C['ol'])
        d.polygon([(rx + 9, y), (rx + 17, y + 2), (rx + 17, y + 6), (rx + 9, y + 9)], fill=C['ol'])
        d.polygon([(rx - 9, y + 1), (rx - 16, y + 3), (rx - 16, y + 5.5), (rx - 9, y + 8)], fill=C['ir2'])
        d.polygon([(rx + 9, y + 1), (rx + 16, y + 3), (rx + 16, y + 5.5), (rx + 9, y + 8)], fill=C['ir1'])
    d.rectangle([rx - 8, 110, rx + 8, FL], fill=C['ir1']); d.rectangle([rx - 8, 110, rx - 4, FL], fill=C['ir2'])
    slab(d, 440, 300, 600, 322, C['stop'], C['sfront'], C['cdark'], None, C['bare'])
    d.rectangle([440, 300, 600, 322], outline=C['ol'])
    for i in range(0, 20, 10): d.rectangle([440 + i, 308, 445 + i, 322], fill=C['haz']); d.rectangle([595 - i, 308, 600 - i, 322], fill=C['haz'])
    # bracket from platform to gear axles
    d.polygon([(rx - 44, 322), (rx + 44, 322), (rx + 34, 336), (rx - 34, 336)], fill=C['ol']); d.polygon([(rx - 41, 323), (rx + 41, 323), (rx + 32, 334), (rx - 32, 334)], fill=C['st1'])
    for k, gx in enumerate((rx - 30, rx + 30)):
        gear2(d, gx, 344, 21, 10, C, (k * .31 + c.get('_ang', 0)) * (1 if k else -1))
        if rev: g.ellipse([gx - 27, 317, gx + 27, 371], outline=C['time'], width=10); d.arc([gx - 23, 321, gx + 23, 367], 0, 360, fill=mix(C['time'], C['br2'], .35), width=2)
    if rev:
        g.rectangle([rx - 14, 110, rx + 14, FL], fill=mix(C['time'], (0, 0, 0), .45))
        for y in range(118, FL, 36): d.rectangle([rx - 2, y, rx + 2, y + 10], fill=C['time'])
    # water trough + fire
    d.rectangle([640, FL - 30, 760, FL], fill=C['cdark']); d.rectangle([646, FL - 22, 754, FL - 2], fill=C['water'])
    d.line([646, FL - 22, 754, FL - 22], fill=mix(C['water'], (255, 255, 255), .3), width=2)
    d.rectangle([840, 330, 872, 360], fill=C['wood']); d.line([840, 345, 872, 345], fill=mix(C['wood'], (0, 0, 0), .4), width=2)
    d.polygon([(842, 330), (850, 300), (856, 318), (862, 292), (870, 330)], fill=C['fire']); d.polygon([(850, 330), (856, 312), (864, 330)], fill=C['fire2'])
    g.ellipse([820, 280, 892, 352], fill=mix(C['fire'], (0, 0, 0), .4))
    # hero
    hx, hy = 250, FL
    d.rectangle([hx - 9, hy - 30, hx - 2, hy], fill=C['suitd']); d.rectangle([hx + 2, hy - 30, hx + 9, hy], fill=C['suitd'])
    d.rectangle([hx - 11, hy - 4, hx - 1, hy], fill=C['hazd']); d.rectangle([hx + 1, hy - 4, hx + 12, hy], fill=C['hazd'])
    d.rounded_rectangle([hx - 12, hy - 58, hx + 12, hy - 26], 4, fill=C['suit'])
    d.rectangle([hx - 12, hy - 34, hx + 12, hy - 30], fill=C['suitd'])
    d.rectangle([hx + 12, hy - 54, hx + 18, hy - 32], fill=C['suit'])
    d.rectangle([hx + 12, hy - 36, hx + 19, hy - 31], fill=C['time']); g.ellipse([hx + 6, hy - 42, hx + 26, hy - 24], fill=C['time'])
    d.rectangle([hx - 12, hy - 58, hx - 4, hy - 26], fill=C['suitd']); d.ellipse([hx - 8, hy - 74, hx + 8, hy - 58], fill=C['skin'])
    d.chord([hx - 11, hy - 82, hx + 11, hy - 62], 180, 360, fill=C['hat']); d.rectangle([hx - 13, hy - 72, hx + 15, hy - 69], fill=C['hat'])
    glow = glow.filter(ImageFilter.GaussianBlur(18))
    return ImageChops.add(img, glow)
