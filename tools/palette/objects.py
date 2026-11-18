import sys, math; sys.path.insert(0, sys.argv[2])
from pal_lib import *
def lab_mix(a, b, t):
    A, B = to_lab(h(a)), to_lab(h(b)); return '%02x%02x%02x' % to_rgb(tuple(A[i] + (B[i] - A[i]) * t for i in range(3)))
def fam(key, dark, light, dk=.72, lt=.72): return (lab_mix(key, dark, dk), key, lab_mix(key, light, lt))
def F_(k, dk, lt, d=.72, l=.72): return ramp(*fam(k, dk, lt, d, l))
NAME = sys.argv[3]
if NAME == 'B':
    DK, LT = '08051c', 'f4f0ff'; f = lambda k, d=.72: F_(k, DK, LT, d)
    N = f('1e0f4a', .8); ST, BR, RU, TM, WM = f('3f5fe0'), f('c0503c'), f('8e2a7a'), f('3fe6ff'), f('ff2418'); INT = WM
    WATER = f(lab_mix('3f5fe0', '2fb0c8', .45)); WOOD = f(lab_mix('c0503c', '7a4a2a', .5)); TITLE = 'Слива и кобальт'
    SUIT, HAT, GEAR, LIGHT = ST, BR, BR, BR; SKIN_ = BR[4]
elif NAME == 'M':
    DK, LT = '0a0c14', 'fffdf6'; f = lambda k, d=.84, l=.8: F_(k, DK, LT, d, l)
    N = [h(x) for x in ('161a28', 'bfeadb', '6fa894', 'e2f6ee', 'ffffff')]
    ST, BR, RU, TM, WM = f('24357a'), f('c07a48'), f('a0144a'), f('7a3cff'), f('f0102e'); INT = f('e8207a')
    WATER = f('1f78e0'); WOOD = f('8a2e22'); TITLE = 'Мятный день'
    SUIT, HAT, GEAR, LIGHT = f('ff6420'), f('f6f4ee', .6), f('0e8a6e'), f('ffa860'); SKIN_ = h('f2c6a0')
else:
    DK, LT = '0a0504', 'fff3e0'; f = lambda k, d=.86, l=.82: F_(k, DK, LT, d, l)
    N = f('24140e', .7, .55); ST, BR, RU, TM, WM = f('9a7e6a'), f('b0643a'), f('7a1a22'), f('3ff0ff'), f('ff5a12'); INT = f('ff2e88')
    WATER = f('2e6a78'); WOOD = f('d8904a'); TITLE = 'Шоколад и неон'
    SUIT, HAT, GEAR, LIGHT = f('b04a1e'), f('f2dcb4', .7), f('9a5a2e'), f('ffd29a'); SKIN_ = h('e6b48e')
if NAME == 'X':
    DK, LT = '050405', 'fff1dc'; f = lambda k, d=.8, l=.8: F_(k, DK, LT, d, l)
    N = f('1c1a1c', .7, .45); ST, BR, RU, TM, WM = f('4a4548'), f('7a706a'), f('6a1e1e'), f('e8102a'), f('ff3a1a'); INT = f('f2e2c4', .75, .5)
    WATER = f('3a4048'); WOOD = f('5a463a'); TITLE = 'Чёрный, красный, ваниль'
    SUIT, HAT, GEAR, LIGHT = f('2e2b2e'), f('f2e2c4', .75, .5), f('7a706a'), f('ffe8c0', .7, .4); SKIN_ = h('e8c8a8')
OL = N[0]; SKIN = SKIN_; CHAR = F_('2a2226', DK, LT)
def box(d, x0, y0, x1, y1, rp, o=2, top=4, bot=4):
    d.rectangle([x0 - o, y0 - o, x1 + o, y1 + o], fill=OL); d.rectangle([x0, y0, x1, y1], fill=rp[2])
    d.rectangle([x0, y0, x1, y0 + top], fill=rp[3]); d.rectangle([x0, y1 - bot, x1, y1], fill=rp[1])
def gear(d, cx, cy, r, teeth, rp, ang=0.0):
    def ring(grow, col):
        pts = []
        for i in range(teeth * 4):
            a = ang + i * math.pi * 2 / (teeth * 4); rr = (r if (i % 4) in (1, 2) else r * .8) + grow
            pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
        d.polygon(pts, fill=col)
    ring(2, OL); ring(0, rp[2]); d.pieslice([cx - r * .8, cy - r * .8, cx + r * .8, cy + r * .8], 200, 320, fill=rp[3])
    d.ellipse([cx - r * .66, cy - r * .66, cx + r * .66, cy + r * .66], fill=rp[1])
    for k in range(4):
        a = ang + k * math.pi / 2 + math.pi / 4; hx, hy = cx + r * .42 * math.cos(a), cy + r * .42 * math.sin(a)
        d.ellipse([hx - r * .15, hy - r * .15, hx + r * .15, hy + r * .15], fill=OL)
    d.ellipse([cx - r * .26, cy - r * .26, cx + r * .26, cy + r * .26], fill=OL); d.ellipse([cx - r * .2, cy - r * .2, cx + r * .2, cy + r * .2], fill=rp[3])
def hero(d, g, x, y, s, rev=False):
    def P(x0, y0, x1, y1, col, o=.8, r=0):
        a = [x + x0 * s, y + y0 * s, x + x1 * s, y + y1 * s]
        d.rounded_rectangle([a[0] - o * s, a[1] - o * s, a[2] + o * s, a[3] + o * s], r * s + o * s, fill=OL); d.rounded_rectangle(a, r * s, fill=col)
    P(-15, -55, -10, -34, SUIT[1], r=2)                       # back arm
    P(-9, -30, -2, -5, SUIT[1]); P(2, -30, 9, -5, SUIT[2])       # legs
    for lx in (-9, 2): d.rectangle([x + lx * s, y - 15 * s, x + (lx + 7) * s, y - 12.5 * s], fill=SUIT[4])
    P(-11, -6, -1, 0, OL, r=1); P(1, -6, 12, 0, OL, r=1)    # boots
    d.rectangle([x - 11 * s, y - 1.2 * s, x - 1 * s, y], fill=N[2]); d.rectangle([x + 1 * s, y - 1.2 * s, x + 12 * s, y], fill=N[2])
    P(-12, -58, 12, -28, SUIT[2], r=3)                         # torso
    d.rectangle([x + 6 * s, y - 57 * s, x + 11.5 * s, y - 29 * s], fill=SUIT[1])
    d.rectangle([x - 11.5 * s, y - 57 * s, x - 6 * s, y - 52 * s], fill=SUIT[3])
    d.rectangle([x - 7 * s, y - 52 * s, x + 7 * s, y - 37 * s], fill=SUIT[3]); d.rectangle([x - 3 * s, y - 49 * s, x + 3 * s, y - 44 * s], fill=SUIT[2])
    d.rectangle([x - 12 * s, y - 41 * s, x + 12 * s, y - 38.5 * s], fill=SUIT[4])
    d.rectangle([x - 12 * s, y - 33 * s, x + 12 * s, y - 29 * s], fill=OL); d.rectangle([x - 2 * s, y - 32.5 * s, x + 2 * s, y - 29.5 * s], fill=GEAR[3])
    P(12, -55, 18, -36, SUIT[2], r=2); d.rectangle([x + 16 * s, y - 54 * s, x + 18 * s, y - 37 * s], fill=SUIT[1])
    P(12, -32, 19, -27, OL, r=1)                             # glove
    P(11.5, -37, 19.5, -32, TM[1]); d.rectangle([x + 13 * s, y - 36 * s, x + 18 * s, y - 34.5 * s], fill=TM[3] if not rev else TM[4])
    g.ellipse([x + 4 * s, y - 45 * s, x + 27 * s, y - 24 * s], fill=TM[2] if not rev else TM[3])
    P(-8, -74, 8, -58, SKIN, r=6); d.rectangle([x + 3 * s, y - 68 * s, x + 5 * s, y - 66 * s], fill=OL)
    d.rectangle([x - 8 * s, y - 66 * s, x - 6 * s, y - 60 * s], fill=HAT[3])
    a = [x - 11 * s, y - 84 * s, x + 11 * s, y - 62 * s]
    d.chord([a[0] - s, a[1] - s, a[2] + s, a[3] + s], 180, 360, fill=OL); d.chord(a, 180, 360, fill=HAT[2])
    d.chord([a[0] + 3 * s, a[1] + 2 * s, a[2] - 9 * s, a[3] - 8 * s], 180, 300, fill=HAT[3])
    d.rectangle([x - .5 * s, y - 84 * s, x + 1.5 * s, y - 73 * s], fill=HAT[1])
    P(-13, -73, 15, -70, HAT[1], o=.8)
CW, CH = 372, 338
img = Image.new('RGB', (1920, 1080), N[1]); d = ImageDraw.Draw(img)
glow = Image.new('RGB', img.size, (0, 0, 0)); g = ImageDraw.Draw(glow)
F = ImageFont.truetype(FONT, 18); FS = ImageFont.truetype(FONT, 13)
def card(i, title, sub=''):
    cx, cy = 12 + (i % 5) * (CW + 9), 12 + (i // 5) * (CH + 9)
    d.rectangle([cx, cy, cx + CW, cy + CH], fill=N[1]); d.rectangle([cx, cy + 250, cx + CW, cy + CH], fill=N[0])
    d.rectangle([cx, cy + 250, cx + CW, cy + 256], fill=ST[3]); d.rectangle([cx, cy + 256, cx + CW, cy + 270], fill=ST[1])
    d.text((cx + 10, cy + 284), title, fill=(240, 236, 255), font=F); d.text((cx + 10, cy + 310), sub, fill=(170, 165, 200), font=FS)
    return cx, cy + 250
# 0 hero big
x, y = card(0, 'Герой крупно', 'каска, роба, полосы, тёмные детали')
hero(d, g, x + 120, y - 6, 2.7); hero(d, g, x + 300, y, 1.6, rev=True); d.text((x + 270, y - 160), 'Shift', fill=TM[3], font=FS)
# 1 hero at game scale with scene
x, y = card(1, 'Герой в масштабе игры', 'рядом ящик и кнопка')
box(d, x + 200, y - 64, x + 264, y, WOOD); d.line([x + 200, y - 64, x + 264, y], fill=WOOD[1], width=4); d.line([x + 200, y, x + 264, y - 64], fill=WOOD[1], width=4)
for cx_ in (x + 200, x + 258):
    for cy_ in (y - 64, y - 6): d.rectangle([cx_, cy_, cx_ + 6, cy_ + 6], fill=ST[3])
hero(d, g, x + 110, y, 1.6)
# 2 button
x, y = card(2, 'Кнопка', 'отжата / нажата')
for k, bx in enumerate((x + 90, x + 260)):
    p = 10 if k else 0
    box(d, bx - 40, y - 14, bx + 40, y, ST, top=3, bot=3)
    box(d, bx - 24, y - 30 + p, bx + 24, y - 14, INT, top=4, bot=3)
    if k: g.ellipse([bx - 40, y - 40, bx + 40, y + 10], fill=mix(INT[2], (0, 0, 0), .5))
# 3 lever
x, y = card(3, 'Рычаг', 'влево / вправо')
for k, bx in enumerate((x + 100, x + 270)):
    ang = math.radians(-120 if k == 0 else -60); L = 70
    ex, ey = bx + L * math.cos(ang), y - 18 + L * math.sin(ang)
    d.line([bx, y - 18, ex, ey], fill=OL, width=12); d.line([bx, y - 18, ex, ey], fill=ST[3], width=7)
    d.ellipse([ex - 12, ey - 12, ex + 12, ey + 12], fill=OL); d.ellipse([ex - 9, ey - 9, ex + 9, ey + 9], fill=INT[2]); d.ellipse([ex - 6, ey - 7, ex, ey - 1], fill=INT[3])
    d.pieslice([bx - 34, y - 52, bx + 34, y + 16], 180, 360, fill=OL); d.pieslice([bx - 31, y - 49, bx + 31, y + 13], 180, 360, fill=GEAR[2])
    d.pieslice([bx - 31, y - 49, bx + 31, y + 13], 200, 260, fill=GEAR[3]); d.ellipse([bx - 6, y - 24, bx + 6, y - 12], fill=OL)
# 4 valve
x, y = card(4, 'Вентиль', 'на трубе, крутится — течёт вода')
box(d, x + 10, y - 150, x + 362, y - 126, ST); box(d, x + 170, y - 126, x + 194, y, ST)
for fx in (x + 60, x + 300): box(d, fx, y - 156, fx + 12, y - 120, ST, top=2, bot=2)
cx_, cy_ = x + 182, y - 175; d.line([cx_, cy_, cx_, y - 150], fill=OL, width=8)
d.ellipse([cx_ - 38, cy_ - 38, cx_ + 38, cy_ + 38], fill=OL); d.ellipse([cx_ - 34, cy_ - 34, cx_ + 34, cy_ + 34], fill=INT[2]); d.ellipse([cx_ - 26, cy_ - 26, cx_ + 26, cy_ + 26], fill=N[1])
for k in range(5):
    a = k * math.pi * 2 / 5; d.line([cx_, cy_, cx_ + 30 * math.cos(a), cy_ + 30 * math.sin(a)], fill=OL, width=9); d.line([cx_, cy_, cx_ + 30 * math.cos(a), cy_ + 30 * math.sin(a)], fill=INT[2], width=5)
d.arc([cx_ - 34, cy_ - 34, cx_ + 34, cy_ + 34], 190, 280, fill=INT[3], width=4); d.ellipse([cx_ - 9, cy_ - 9, cx_ + 9, cy_ + 9], fill=GEAR[2])
# 5 door
x, y = card(5, 'Дверь-рейка', 'рейка между двумя шестернями')
dx = x + 186; box(d, dx - 70, y - 236, dx + 70, y - 210, ST)
for k, (top, lab) in enumerate(((y - 200, ''), )):
    pass
box(d, dx - 18, y - 170, dx + 18, y, ST, top=3)
for yy in range(int(y - 160), int(y - 10), 26):
    d.polygon([(dx - 18, yy), (dx + 18, yy + 13), (dx + 18, yy + 23), (dx - 18, yy + 10)], fill=WM[2]); 
for yy in range(int(y - 240), int(y - 160), 12):
    d.polygon([(dx - 18, yy), (dx - 25, yy + 3), (dx - 25, yy + 7), (dx - 18, yy + 10)], fill=OL); d.polygon([(dx + 18, yy), (dx + 25, yy + 3), (dx + 25, yy + 7), (dx + 18, yy + 10)], fill=OL)
d.rectangle([dx - 20, y - 245, dx + 20, y - 165], fill=OL); d.rectangle([dx - 17, y - 243, dx + 17, y - 167], fill=GEAR[1]); d.rectangle([dx - 17, y - 243, dx - 10, y - 167], fill=GEAR[2])
gear(d, dx - 44, y - 195, 24, 10, GEAR, .3); gear(d, dx + 44, y - 195, 24, 10, GEAR, .6)
# 6 winch
x, y = card(6, 'Лебёдка', 'цепь на многоугольном барабане')
cx_, cy_ = x + 120, y - 200
pts = [(cx_ + 34 * math.cos(k * math.pi / 4 + .39), cy_ + 34 * math.sin(k * math.pi / 4 + .39)) for k in range(8)]
d.polygon([(px + (px - cx_) * .08, py + (py - cy_) * .08) for px, py in pts], fill=OL); d.polygon(pts, fill=GEAR[2]); d.polygon(pts[4:7] + [(cx_, cy_)], fill=GEAR[3])
d.ellipse([cx_ - 10, cy_ - 10, cx_ + 10, cy_ + 10], fill=OL); d.ellipse([cx_ - 6, cy_ - 6, cx_ + 6, cy_ + 6], fill=GEAR[3])
for yy in range(int(cy_), int(y - 70), 14):
    d.ellipse([cx_ + 28, yy, cx_ + 42, yy + 18], outline=OL, width=5); d.ellipse([cx_ + 29, yy + 1, cx_ + 41, yy + 17], outline=ST[3], width=2)
box(d, cx_ - 30, y - 74, cx_ + 140, y - 56, ST)
box(d, x + 250, y - 120, x + 340, y, ST); d.text((x + 262, y - 95), 'шлюз', fill=ST[4], font=FS)
# 7 belt platform
x, y = card(7, 'Платформа на ленте', 'лента между двумя звёздочками')
sx = x + 250
d.rounded_rectangle([sx - 30, y - 236, sx + 30, y - 10], 30, fill=OL); d.rounded_rectangle([sx - 25, y - 231, sx + 25, y - 15], 25, fill=RU[1]); d.rounded_rectangle([sx - 19, y - 225, sx + 19, y - 21], 19, fill=N[1])
gear(d, sx, y - 206, 20, 8, GEAR, .2); gear(d, sx, y - 40, 20, 8, GEAR, .6)
box(d, sx - 150, y - 128, sx - 26, y - 112, ST); d.rectangle([sx - 30, y - 132, sx - 18, y - 106], fill=OL)
# 8 water + float
x, y = card(8, 'Вода и поплавок', 'уровень + частицы, поплавок несёт героя')
lay = Image.new('RGBA', img.size, (0, 0, 0, 0)); ld = ImageDraw.Draw(lay)
ld.rectangle([x, y - 110, x + CW, y], fill=WATER[2] + (200,)); ld.rectangle([x, y - 110, x + CW, y - 104], fill=WATER[4] + (230,))
for k in range(0, CW, 46): ld.arc([x + k, y - 116, x + k + 46, y - 100], 200, 340, fill=WATER[4] + (255,), width=2)
for bx, by in ((60, 40), (140, 70), (300, 30), (230, 85)): ld.ellipse([x + bx, y - by, x + bx + 7, y - by + 7], outline=WATER[4] + (220,), width=2)
img.paste(Image.alpha_composite(img.convert('RGBA'), lay).convert('RGB')); d = ImageDraw.Draw(img)
box(d, x + 150, y - 124, x + 260, y - 100, RU, top=5); d.rectangle([x + 150, y - 114, x + 260, y - 110], fill=ST[4])
hero(d, g, x + 205, y - 126, 1.2)
# 9 wood & fire
x, y = card(9, 'Дерево и огонь', 'целое → горит → сгорело')
for k, wx in enumerate((x + 20, x + 135, x + 250)):
    if k < 2:
        for p in range(3): box(d, wx, y - 90 + p * 30, wx + 100, y - 64 + p * 30, WOOD, top=3, bot=3)
    else:
        for p in range(3): box(d, wx + 6 * (p % 2), y - 70 + p * 24, wx + 94 - 8 * p, y - 52 + p * 24, CHAR, top=2, bot=2)
        for ex in (20, 55, 80): d.ellipse([wx + ex, y - 30, wx + ex + 5, y - 25], fill=WM[3]); g.ellipse([wx + ex - 6, y - 36, wx + ex + 11, y - 19], fill=WM[2])
    if k == 1:
        for fx, fh in ((10, 70), (35, 100), (62, 80), (82, 60)):
            d.polygon([(wx + fx - 12, y - 88), (wx + fx, y - 88 - fh), (wx + fx + 12, y - 88)], fill=WM[2]); d.polygon([(wx + fx - 6, y - 88), (wx + fx, y - 88 - fh * .55), (wx + fx + 6, y - 88)], fill=WM[4])
        g.ellipse([wx - 30, y - 200, wx + 130, y - 40], fill=WM[2])
# 10 lamp
x, y = card(10, 'Лампа', 'горит / разбита (под Shift собирается)')
for k, lx in enumerate((x + 100, x + 270)):
    d.line([lx, y - 250, lx, y - 190], fill=OL, width=3)
    d.polygon([(lx - 34, y - 160), (lx - 14, y - 190), (lx + 14, y - 190), (lx + 34, y - 160)], fill=OL); d.polygon([(lx - 30, y - 162), (lx - 12, y - 187), (lx + 12, y - 187), (lx + 30, y - 162)], fill=ST[2])
    d.polygon([(lx - 12, y - 187), (lx + 2, y - 187), (lx - 16, y - 162), (lx - 30, y - 162)], fill=ST[3])
    if k == 0:
        d.ellipse([lx - 10, y - 166, lx + 10, y - 150], fill=LIGHT[4]); g.polygon([(lx - 30, y - 160), (lx + 30, y - 160), (lx + 90, y), (lx - 90, y)], fill=mix(LIGHT[3], (0, 0, 0), .55)); g.ellipse([lx - 34, y - 190, lx + 34, y - 130], fill=LIGHT[3])
    else:
        for sx_, sy_ in ((-14, 20), (6, 60), (20, 160), (-24, 158)): d.polygon([(lx + sx_, y - 150 + sy_), (lx + sx_ + 8, y - 146 + sy_), (lx + sx_ + 3, y - 140 + sy_)], fill=ST[4])
# 11 darkness
x, y = card(11, 'Тёмная комната', 'видно только освещённое')
dark = Image.new('L', img.size, 0); dd = ImageDraw.Draw(dark); dd.rectangle([x, y - 250, x + CW, y + 20], fill=200)
dd.ellipse([x + 60, y - 170, x + 260, y + 30], fill=0); dark = dark.filter(ImageFilter.GaussianBlur(25))
box(d, x + 150, y - 50, x + 210, y, WOOD); hero(d, g, x + 110, y, 1.6)
img = Image.composite(Image.new('RGB', img.size, N[0]), img, dark); d = ImageDraw.Draw(img)
d.ellipse([x + 152, y - 222, x + 170, y - 204], fill=LIGHT[4]); g.ellipse([x + 120, y - 250, x + 200, y - 170], fill=LIGHT[3])
# 12 reverse flamethrower
x, y = card(12, 'Обратный огнемёт', 'втягивает огонь; вещь времени — с цианом')
fx, fy = x + 70, y - 120
box(d, fx, fy - 14, fx + 120, fy + 14, BR); box(d, fx + 120, fy - 8, fx + 170, fy + 8, ST)
d.rectangle([fx + 20, fy + 14, fx + 40, fy + 50], fill=OL); d.rectangle([fx + 23, fy + 14, fx + 37, fy + 47], fill=RU[2])
box(d, fx + 40, fy - 30, fx + 90, fy - 14, RU); d.rectangle([fx + 50, fy - 6, fx + 110, fy + 2], fill=TM[2]); g.rectangle([fx + 45, fy - 12, fx + 115, fy + 8], fill=TM[1])
for k, (px, py) in enumerate(((270, -10), (250, 8), (300, 5), (235, -4), (285, -22))):
    d.polygon([(x + px, fy + py), (x + px + 16, fy + py - 6), (x + px + 16, fy + py + 6)], fill=WM[2 + k % 2])
g.ellipse([x + 210, fy - 50, x + 330, fy + 50], fill=WM[1])
# 13 trampoline
x, y = card(13, 'Обратный батут', 'тянет вниз, а не подкидывает')
tx = x + 186
for lx in (-70, 60): box(d, tx + lx, y - 40, tx + lx + 10, y, ST, top=2, bot=2)
d.rectangle([tx - 80, y - 52, tx + 80, y - 40], fill=OL); d.rectangle([tx - 77, y - 50, tx + 77, y - 42], fill=RU[2])
d.arc([tx - 77, y - 60, tx + 77, y - 30], 0, 180, fill=TM[2], width=3); g.arc([tx - 77, y - 60, tx + 77, y - 30], 0, 180, fill=TM[2], width=8)
for ax in (-30, 0, 30): d.polygon([(tx + ax - 7, y - 120), (tx + ax + 7, y - 120), (tx + ax, y - 104)], fill=TM[3])
# 14 palette
x, y = card(14, 'Палитра «' + TITLE + '»', 'основные цвета и их оттенки')
ROWS = ((N, 'фон'), (ST, 'сталь'), (GEAR, 'механизмы'), (SUIT, 'роба'), (HAT, 'каска'), (RU, 'ржавчина'), (TM, 'время'), (WM, 'огонь'), (INT, 'кнопки'), (WATER, 'вода'), (WOOD, 'дерево'), (LIGHT, 'свет ламп'))
for j, (rp, lab) in enumerate(ROWS):
    for q, col in enumerate(rp): d.rectangle([x + 20 + q * 44, y - 246 + j * 20, x + 60 + q * 44, y - 231 + j * 20], fill=col)
    d.text((x + 250, y - 247 + j * 20), lab, fill=(30, 30, 46) if NAME == 'M' else (220, 220, 240), font=FS)
glow = glow.filter(ImageFilter.GaussianBlur(16))
glow = glow.point(lambda v: int(v * (.4 if NAME == 'M' else 1)))
ImageChops.add(img, glow).save(sys.argv[1])
if len(sys.argv) > 4:
    import json
    hx = lambda c: '#%02x%02x%02x' % tuple(c)
    roles = dict(background=N, steel=ST, mechanism=GEAR, suit=SUIT, helmet=HAT, rust=RU, time=TM, fire=WM, interact=INT, water=WATER, wood=WOOD, lamp_light=LIGHT)
    out = {'title': TITLE, 'skin': hx(SKIN), 'ramps': {k: [hx(c) for c in v] for k, v in roles.items()}}
    json.dump(out, open(sys.argv[4], 'w'), ensure_ascii=False)
